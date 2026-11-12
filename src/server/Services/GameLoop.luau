-- 라운드 흐름
-- 대기(Intermission) -> 플레이(Playing) -> 종료(Ended) -> 다시 대기 ...
--
-- 플레이 중 목표: 숲에서 퓨즈 3개를 찾아 탈출문 옆 퓨즈 박스에 넣고, 열린 문으로 탈출!
-- 죽으면 그 라운드는 관전(부활 상품으로 되살아날 수 있음).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local MaterialSpawner = require(script.Parent.MaterialSpawner)
local MonsterAI = require(script.Parent.MonsterAI)
local Monetization = require(script.Parent.Monetization)

local notify = Remotes.get("Notify")

local GameLoop = {}

local map = nil
local roundState = "Intermission"
local fusesPlaced = 0
local gateOpen = false

-- 클라이언트 HUD가 읽을 수 있게 ReplicatedStorage의 Attribute로 상태를 공개
local function publish()
	ReplicatedStorage:SetAttribute("RoundState", roundState)
	ReplicatedStorage:SetAttribute("FusesPlaced", fusesPlaced)
	ReplicatedStorage:SetAttribute("FusesRequired", Config.Escape.FusesRequired)
	ReplicatedStorage:SetAttribute("GateOpen", gateOpen)
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

local function setGate(open: boolean)
	gateOpen = open
	local door = map.GateDoor
	door.CanCollide = not open
	door.Transparency = if open then 0.85 else 0
	door.Color = if open then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(120, 20, 20)
	local light = map.FuseBox:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = if open then Color3.fromRGB(60, 255, 90) else Color3.fromRGB(255, 60, 60)
	end
	publish()
end

local function playersInRound(): { Player }
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
	player:LoadCharacter()
	Monetization.applyRoundPerks(player)
end

local function startRound()
	fusesPlaced = 0
	roundState = "Playing"
	setGate(false)
	MaterialSpawner.reset()
	MonsterAI.start()
	for _, player in Players:GetPlayers() do
		spawnIntoRound(player)
	end
	notify:FireAllClients(("퓨즈 %d개를 찾아 탈출문을 열어라!"):format(Config.Escape.FusesRequired))
end

local function endRound()
	roundState = "Ended"
	publish()
	MonsterAI.stop()
	MaterialSpawner.clear()

	local escaped = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Escaped") == true then
			table.insert(escaped, player.DisplayName)
		end
		player:SetAttribute("InRound", false)
	end
	if #escaped > 0 then
		notify:FireAllClients("탈출 성공: " .. table.concat(escaped, ", "))
	else
		notify:FireAllClients("아무도 탈출하지 못했다...")
	end
end

local function onFuseBox(player: Player)
	if roundState ~= "Playing" or gateOpen then
		return
	end
	local have = Inventory.get(player, "Fuse")
	if have < 1 then
		notify:FireClient(player, "퓨즈가 없어요. 숲에서 노란 빛을 찾아보세요")
		return
	end
	local needed = Config.Escape.FusesRequired - fusesPlaced
	local used = math.min(have, needed)
	Inventory.add(player, "Fuse", -used)
	fusesPlaced += used
	publish()
	if fusesPlaced >= Config.Escape.FusesRequired then
		setGate(true)
		notify:FireAllClients("탈출문이 열렸다! 북쪽 문으로 도망쳐!")
	else
		notify:FireAllClients(("퓨즈 %d/%d"):format(fusesPlaced, Config.Escape.FusesRequired))
	end
end

local function onExitTouched(hit: BasePart)
	if roundState ~= "Playing" or not gateOpen then
		return
	end
	local char = hit:FindFirstAncestorOfClass("Model")
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player or player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true then
		return
	end
	player:SetAttribute("Escaped", true)
	addEscape(player)
	notify:FireAllClients(player.DisplayName .. " 탈출 성공!")
	-- 안전한 방으로 이동
	char:PivotTo(map.SafeRoom.CFrame + Vector3.new(0, 4, 0))
end

local function onCharacterAdded(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		if roundState == "Playing" and player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true then
			player:SetAttribute("InRound", false)
			notify:FireAllClients(player.DisplayName .. "이(가) 괴물에게 당했다...")
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

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "퓨즈 넣기"
	prompt.ObjectText = "퓨즈 박스"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = map.FuseBox
	prompt.Triggered:Connect(onFuseBox)

	map.ExitZone.Touched:Connect(onExitTouched)

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
		-- 죽었거나 탈출한 사람 모두 시작 지점으로
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
		t = Config.Round.RoundTime
		while t > 0 and #playersInRound() > 0 do
			setTimeLeft(t)
			task.wait(1)
			t -= 1
		end
		setTimeLeft(0)

		-- 종료
		endRound()
		task.wait(6)
	end
end

return GameLoop
