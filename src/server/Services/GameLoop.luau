-- 라운드 흐름
-- 대기(Intermission) -> 플레이(Playing) -> 종료(Ended) -> 다시 대기 ...
--
-- 플레이 중: 4가지 탈출 방법 중 아무거나로 탈출하면 성공 (Objectives.luau 참고)
-- 죽으면 그 라운드는 관전 (부활 상품으로 되살아날 수 있음). 들고 있던 탈출 부품은 떨어짐.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Inventory = require(script.Parent.Inventory)
local Pickups = require(script.Parent.Pickups)
local MonsterAI = require(script.Parent.MonsterAI)
local Monetization = require(script.Parent.Monetization)
local Objectives = require(script.Parent.Objectives)
local Hiding = require(script.Parent.Hiding)

local notify = Remotes.get("Notify")
local storyEvent = Remotes.get("StoryEvent")

local GameLoop = {}

local map = nil
local roundState = "Intermission"

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
	notify:FireAllClients(("%s 탈출 성공! (%s)"):format(player.DisplayName, Story.Endings[route].title))
	storyEvent:FireClient(player, "Ending", route)
	local char = player.Character
	if char then
		char:PivotTo(map.SafeRoom.CFrame + Vector3.new(0, 4, 0))
	end
end

local function activePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true then
			table.insert(list, player)
		end
	end
	return list
end

local function spawnIntoRound(player: Player)
	Inventory.reset(player)
	player:SetAttribute("InRound", true)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("EscapeRoute", nil)
	player:LoadCharacter()
	Monetization.applyRoundPerks(player)
end

local function startRound()
	roundState = "Playing"
	publish()
	Objectives.reset()
	Pickups.reset()
	MonsterAI.start()
	Objectives.setActive(true)
	for _, player in Players:GetPlayers() do
		task.spawn(spawnIntoRound, player)
	end
	storyEvent:FireAllClients("Intro")
end

local function endRound(timedOut: boolean)
	roundState = "Ended"
	publish()
	Objectives.setActive(false)
	Hiding.releaseAll()
	MonsterAI.stop()
	Pickups.clear()

	local escaped = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Escaped") == true then
			escaped += 1
		elseif player:GetAttribute("InRound") ~= nil then
			-- 탈출 못 한 사람에게 엔딩
			storyEvent:FireClient(player, "Ending", if timedOut and player:GetAttribute("InRound") == true then "Timeout" else "Dead")
		end
		player:SetAttribute("InRound", false)
	end
	notify:FireAllClients(("라운드 종료 — %d명 탈출"):format(escaped))
end

local function onCharacterAdded(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		if roundState == "Playing" and player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true then
			player:SetAttribute("InRound", false)
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				Pickups.dropQuestItems(player, hrp.Position)
			end
			notify:FireAllClients(player.DisplayName .. "이(가) 숲지기에게 당했다…")
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
	if roundState == "Playing" then
		spawnIntoRound(player) -- 중간에 들어와도 바로 참가
		storyEvent:FireClient(player, "Intro")
	else
		player:SetAttribute("InRound", false)
		player:LoadCharacter()
	end
end

-- 부활 상품 구매 시 Monetization이 부름. 부활시켰으면 true
function GameLoop.revive(player: Player): boolean
	if roundState ~= "Playing" or player:GetAttribute("Escaped") == true then
		return false
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
	notify:FireAllClients(player.DisplayName .. "이(가) 되살아났다!")
	return true
end

function GameLoop.init(mapInfo)
	map = mapInfo
	Players.CharacterAutoLoads = false -- 죽으면 라운드 끝날 때까지 관전

	Objectives.init(map, onEscape)
	MonsterAI.onSealed = Objectives.onSealed

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	publish()
end

function GameLoop.run()
	while true do
		-- 대기
		roundState = "Intermission"
		publish()
		for _, player in Players:GetPlayers() do
			task.spawn(player.LoadCharacter, player)
		end
		local t = Config.Round.IntermissionTime
		while t > 0 do
			setTimeLeft(t)
			task.wait(1)
			if #Players:GetPlayers() >= Config.Round.MinPlayers then
				t -= 1
			end
		end

		-- 플레이
		startRound()
		task.wait(2) -- 캐릭터가 생길 시간
		t = Config.Round.RoundTime
		while t > 0 and #activePlayers() > 0 do
			setTimeLeft(t)
			task.wait(1)
			t -= 1
		end
		setTimeLeft(0)

		-- 종료
		endRound(t <= 0)
		task.wait(10)
	end
end

return GameLoop
