-- 라운드 흐름
--
-- 대기실 서버 (보통 서버, Studio 테스트):
--   대기실(Idle) --방 카운트다운 끝--> 플레이(Playing) -> 종료(Ended) -> 대기실로 돌아감
--   (같은 서버의 숲은 한 번에 한 팀만. 순간이동 모드면 팀마다 따로 서버가 생김)
--
-- 게임 서버 (대기실에서 순간이동해 온 팀 전용 서버):
--   팀원 기다리기(Intermission) -> 플레이(Playing) -> 종료(Ended) -> 모두 대기실로 순간이동
--
-- 플레이어 속성(Attribute)
--   InLobby  : 대기실에 있음
--   InMatch  : 이번 판 참가자 (죽거나 탈출해서 관전 중이어도 true)
--   InRound  : 지금 살아서 숲을 돌아다니는 중
--
-- 플레이 중: 4가지 탈출 방법 중 아무거나로 탈출하면 성공 (Objectives.luau 참고)
-- 죽으면 그 라운드는 관전 (부활 상품으로 되살아날 수 있음). 들고 있던 탈출 부품은 떨어짐.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Inventory = require(script.Parent.Inventory)
local Pickups = require(script.Parent.Pickups)
local MonsterAI = require(script.Parent.MonsterAI)
local Monetization = require(script.Parent.Monetization)
local Objectives = require(script.Parent.Objectives)
local Hiding = require(script.Parent.Hiding)
local Events = require(script.Parent.Events)

local notify = Remotes.get("Notify")
local storyEvent = Remotes.get("StoryEvent")
local effect = Remotes.get("Effect")

local GameLoop = {}

local map = nil
local roundState = "Idle" -- "Idle"(대기실) | "Intermission" | "Playing" | "Ended"
local isMatchServer = false
local lobbySpawn: CFrame? = nil -- 대기실 서버일 때만 있음
local matchPlayers: { [Player]: boolean } = {} -- 이번 판 참가자
local expectedPlayers = 1 -- 게임 서버: 대기실에서 같이 출발한 인원

-- 이번 판 참가자에게만 메시지 (대기실에 있는 사람은 안 받음)
local function notifyMatch(text: string)
	for player in matchPlayers do
		if player.Parent == Players then
			notify:FireClient(player, text)
		end
	end
end

local function publish()
	ReplicatedStorage:SetAttribute("RoundState", roundState)
end

local function setTimeLeft(seconds: number)
	ReplicatedStorage:SetAttribute("TimeLeft", seconds)
end

local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local escapes = Instance.new("IntValue")
	escapes.Name = "탈출"
	escapes.Parent = stats
	-- TODO: DataStore로 저장하면 다시 접속해도 기록이 남아요
	stats.Parent = player
	Pickups.setupStats(player)
end

---------------------------------------------------------------------------
-- 쓰러짐 / 동료 살리기
---------------------------------------------------------------------------
local downedTokens: { [Player]: number } = {}

local function clearDowned(player: Player)
	downedTokens[player] = (downedTokens[player] or 0) + 1
	player:SetAttribute("Downed", false)
	player:SetAttribute("BleedEnds", nil)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local prompt = hrp and hrp:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
end

local function revivePlayer(player: Player, by: Player?)
	if player:GetAttribute("Downed") ~= true then
		return
	end
	clearDowned(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = math.max(hum.Health, Config.Downed.ReviveHealth)
	end
	effect:FireClient(player, "Heal")
	if by then
		notifyMatch(("%s이(가) %s을(를) 일으켜 세웠다!"):format(by.DisplayName, player.DisplayName))
	end
end

-- 괴물에게 치명상을 입으면 바로 죽지 않고 쓰러짐
local function downPlayer(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hum.Health > 0 and hrp) or player:GetAttribute("Downed") == true then
		return
	end
	Hiding.release(player)
	hum:UnequipTools()
	hum.Health = math.min(hum.Health, 10)
	downedTokens[player] = (downedTokens[player] or 0) + 1
	local myToken = downedTokens[player]
	player:SetAttribute("Downed", true)
	player:SetAttribute("BleedEnds", os.time() + Config.Downed.BleedOutTime)
	notifyMatch(("%s이(가) 쓰러졌다! %d초 안에 가서 살려라"):format(player.DisplayName, Config.Downed.BleedOutTime))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "살리기"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.Downed.ReviveHoldTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = hrp
	prompt.Triggered:Connect(function(helper: Player)
		if helper == player or helper:GetAttribute("InRound") ~= true or helper:GetAttribute("Downed") == true then
			return
		end
		revivePlayer(player, helper)
	end)

	task.delay(Config.Downed.BleedOutTime, function()
		if downedTokens[player] == myToken and player:GetAttribute("Downed") == true then
			clearDowned(player)
			if hum.Parent then
				hum.Health = 0
			end
		end
	end)
end

local function addEscape(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local escapes = stats and stats:FindFirstChild("탈출")
	if escapes and escapes:IsA("IntValue") then
		escapes.Value += 1
	end
end

-- 탈출 처리 (Objectives가 부름)
local function onEscape(player: Player, route: string)
	if roundState ~= "Playing" or player:GetAttribute("Escaped") == true then
		return
	end
	Hiding.release(player)
	player:SetAttribute("Escaped", true)
	player:SetAttribute("EscapeRoute", route)
	addEscape(player)
	notifyMatch(("%s 탈출 성공! (%s)"):format(player.DisplayName, Story.Endings[route].title))
	storyEvent:FireClient(player, "Ending", route)
	clearDowned(player)
	local char = player.Character
	if char then
		char:PivotTo(map.SafeRoom.CFrame + Vector3.new(0, 4, 0))
	end
end

local function activePlayers(): { Player }
	local list = {}
	for player in matchPlayers do
		if player.Parent == Players and player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true then
			table.insert(list, player)
		end
	end
	return list
end

local function joinMatch(player: Player)
	matchPlayers[player] = true
	player:SetAttribute("InLobby", false)
	player:SetAttribute("LobbyRoom", nil)
	player:SetAttribute("InMatch", true)
end

local function spawnIntoRound(player: Player)
	joinMatch(player)
	Inventory.reset(player)
	player:SetAttribute("InRound", true)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("EscapeRoute", nil)
	player:LoadCharacter()
	Monetization.applyRoundPerks(player)
end

---------------------------------------------------------------------------
-- 대기실로 보내기 (대기실 서버)
---------------------------------------------------------------------------
local function sendToLobby(player: Player)
	if player.Parent ~= Players then
		return
	end
	matchPlayers[player] = nil
	Hiding.release(player)
	clearDowned(player)
	player:SetAttribute("InMatch", false)
	player:SetAttribute("InRound", false)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("EscapeRoute", nil)
	player:SetAttribute("InLobby", true)
	Inventory.reset(player) -- 숲에서 주운 물건은 대기실로 못 가져감
	player:LoadCharacter()
	local char = player.Character
	if char and lobbySpawn then
		local offset = Vector3.new(math.random(-8, 8), 0, math.random(-4, 4))
		char:PivotTo(lobbySpawn + offset)
	end
end

-- 대기실로 순간이동 (게임 서버). 실패하면 조금 뒤 다시 시도
local function teleportToLobby(list: { Player })
	if #list == 0 then
		return
	end
	notifyMatch("대기실로 돌아갑니다…")
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, list)
	end)
	if not ok then
		warn("[게임 서버] 대기실로 이동 실패:", err)
	end
end

---------------------------------------------------------------------------
-- 라운드
---------------------------------------------------------------------------
local function beginRound(players: { Player })
	roundState = "Playing"
	publish()
	Objectives.reset()
	Pickups.reset()
	MonsterAI.start()
	Events.start()
	Objectives.setActive(true)
	for _, player in players do
		if player.Parent == Players then
			joinMatch(player)
			task.spawn(function()
				spawnIntoRound(player)
				storyEvent:FireClient(player, "Intro")
			end)
		end
	end
end

local function endRound(timedOut: boolean)
	roundState = "Ended"
	publish()
	Objectives.setActive(false)
	Hiding.releaseAll()
	for player in matchPlayers do
		clearDowned(player)
	end
	MonsterAI.stop()
	Events.stop()
	Pickups.clear()

	local escaped = 0
	for player in matchPlayers do
		if player.Parent ~= Players then
			continue
		end
		if player:GetAttribute("Escaped") == true then
			escaped += 1
		else
			-- 탈출 못 한 사람에게 엔딩
			storyEvent:FireClient(player, "Ending", if timedOut and player:GetAttribute("InRound") == true then "Timeout" else "Dead")
		end
		player:SetAttribute("InRound", false)
	end
	notifyMatch(("라운드 종료 — %d명 탈출"):format(escaped))
end

-- 플레이 → 종료 → 대기실로
local function playRound()
	task.wait(2) -- 캐릭터가 생길 시간
	local t = Config.Round.RoundTime
	while t > 0 and #activePlayers() > 0 do
		setTimeLeft(t)
		task.wait(1)
		t -= 1
	end
	setTimeLeft(0)
	endRound(t <= 0)

	task.wait(Config.Lobby.ReturnDelay)
	if isMatchServer then
		teleportToLobby(Players:GetPlayers())
	else
		for player in matchPlayers do
			task.spawn(sendToLobby, player)
		end
		table.clear(matchPlayers)
		roundState = "Idle"
		publish()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	clearDowned(player)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		clearDowned(player)
		if roundState == "Playing" and player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true then
			player:SetAttribute("InRound", false)
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				Pickups.dropQuestItems(player, hrp.Position)
			end
			notifyMatch(player.DisplayName .. "이(가) 숲지기에게 당했다…")
		elseif player:GetAttribute("InLobby") == true then
			-- 대기실에서 죽으면(리셋 등) 대기실에서 다시 태어남
			task.delay(2, function()
				if player.Parent == Players and player:GetAttribute("InLobby") == true and player.Character == character then
					sendToLobby(player)
				end
			end)
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	setupLeaderstats(player)
	Inventory.reset(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if not isMatchServer then
		sendToLobby(player)
		return
	end

	-- 게임 서버: 대기실에서 몇 명이 같이 출발했는지 확인
	local joinData = player:GetJoinData()
	local data = joinData and joinData.TeleportData
	if typeof(data) == "table" and typeof(data.expected) == "number" then
		expectedPlayers = math.max(expectedPlayers, data.expected)
	end
	if roundState == "Playing" then
		spawnIntoRound(player) -- 늦게 도착해도 바로 참가
		storyEvent:FireClient(player, "Intro")
	elseif roundState == "Ended" then
		teleportToLobby({ player })
	else
		joinMatch(player)
		player:SetAttribute("InRound", false)
		player:LoadCharacter()
	end
end

-- 부활 상품 구매 시 Monetization이 부름. 부활시켰으면 true
function GameLoop.revive(player: Player): boolean
	if roundState ~= "Playing" or player:GetAttribute("InMatch") ~= true or player:GetAttribute("Escaped") == true then
		return false
	end
	if player:GetAttribute("Downed") == true then
		revivePlayer(player, nil)
		notifyMatch(player.DisplayName .. "이(가) 스스로 일어났다!")
		return true
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and player:GetAttribute("InRound") == true then
		return false -- 이미 살아있음
	end
	local deathSpot = char and char:GetPivot()
	player:SetAttribute("InRound", true)
	player:LoadCharacter()
	if deathSpot and player.Character then
		player.Character:PivotTo(deathSpot + Vector3.new(0, 3, 0))
	end
	notifyMatch(player.DisplayName .. "이(가) 되살아났다!")
	return true
end

-- 대기실: 지금 이 서버의 숲에서 새 판을 시작할 수 있는지
function GameLoop.canStartMatch(): boolean
	return not isMatchServer and roundState == "Idle"
end

-- 대기실: 한 방의 사람들로 이 서버의 숲에서 판 시작
function GameLoop.startMatch(players: { Player }): boolean
	if not GameLoop.canStartMatch() then
		return false
	end
	local list = {}
	for _, player in players do
		if player.Parent == Players then
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return false
	end
	table.clear(matchPlayers)
	beginRound(list)
	task.spawn(playRound)
	return true
end

-- options.lobbySpawn: 대기실 서버면 대기실 시작 위치, 게임 서버면 nil
function GameLoop.init(mapInfo, options: { matchServer: boolean, lobbySpawn: CFrame? })
	map = mapInfo
	isMatchServer = options.matchServer
	lobbySpawn = options.lobbySpawn
	roundState = if isMatchServer then "Intermission" else "Idle"
	Players.CharacterAutoLoads = false -- 죽으면 라운드 끝날 때까지 관전

	Objectives.init(map, onEscape)
	MonsterAI.onSealed = Objectives.onSealed
	MonsterAI.onPlayerDowned = downPlayer
	Players.PlayerRemoving:Connect(function(player)
		downedTokens[player] = nil
		matchPlayers[player] = nil
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	publish()
end

-- 게임 서버: 팀원이 모이면 한 판 하고 대기실로 돌려보냄
function GameLoop.runMatchServer()
	roundState = "Intermission"
	publish()
	local t = Config.Round.IntermissionTime
	while true do
		local present = #Players:GetPlayers()
		if present > 0 and (present >= expectedPlayers or t <= 0) then
			break
		end
		setTimeLeft(math.max(t, 0))
		task.wait(1)
		if present > 0 then
			t -= 1
		end
	end
	beginRound(Players:GetPlayers())
	playRound()

	-- 아직 남은 사람이 있으면 계속 다시 보내기 (3번 실패하면 내보냄)
	for _ = 1, 3 do
		task.wait(10)
		teleportToLobby(Players:GetPlayers())
	end
	task.wait(10)
	for _, player in Players:GetPlayers() do
		player:Kick("대기실로 이동하지 못했어요. 게임에 다시 들어와 주세요.")
	end
end

return GameLoop
