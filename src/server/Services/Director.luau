-- 공포 연출 감독 (Director)
--
-- 1) 밤의 흐름(막)을 관리합니다. ReplicatedStorage 의 "Act" 속성으로 공개돼요.
--      1막 정적: 숲지기가 둥지 근처에만 있음. 비가 조금 오고 기척만 느껴짐
--      2막 사냥: 숲지기가 숲 전체를 돌아다님 (시작 후 Config.Monster.StartGrace 초 뒤)
--      3막 폭풍: 탈출 장치를 켜거나(정문/트럭/무전) 시간이 얼마 안 남으면 시작.
--                폭풍이 몰아치고 숲지기가 더 빠르고 집요해짐
--
-- 2) 플레이어마다 "지금 상황에 어울리는" 무서운 일을 골라서 일으킵니다.
--      숨어 있을 때  : 문 긁는 소리, 바로 앞의 숨소리
--      집 안에 있을 때: 벽 두드리는 소리, 지붕 위 발소리, 등불이 꺼짐
--      숲에 있을 때  : 등 뒤 발소리(돌아보면 멈춤), 나무 사이의 형체, 죽은 사람 목소리 흉내
--    진짜 괴물이 가까이 있거나 쫓기는 중에는 가짜 연출을 하지 않습니다.
--    (진짜가 충분히 무섭고, 가짜와 헷갈리면 억울하니까요)
--
-- 실제 연출(소리, 형체)은 클라이언트(client/Scares.luau)가 만듭니다.
-- 간격/빈도는 Config.Director 에서 바꿀 수 있어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local MonsterAI = require(script.Parent.MonsterAI)

local effect = Remotes.get("Effect")
local D = Config.Director

local Director = {}

local map = nil
local running = false
local generation = 0
local act = 1
local startedAt = 0
local rng = Random.new()

local nextScare: { [Player]: number } = {}
local lastKind: { [Player]: string } = {}
local lastChased: { [Player]: number } = {}

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function setAct(newAct: number)
	if act == newAct then
		return
	end
	act = newAct
	ReplicatedStorage:SetAttribute("Act", act)
	MonsterAI.setFinale(act >= 3)
	if running then
		effect:FireAllClients("Act", act)
	end
end

local function rootOf(player: Player): BasePart?
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true or player:GetAttribute("Downed") == true then
		return nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function isIndoors(pos: Vector3): boolean
	for _, b in map.Buildings or {} do
		local rel = b.cf:PointToObjectSpace(pos)
		if math.abs(rel.X) < b.size.X / 2 and math.abs(rel.Z) < b.size.Z / 2 and rel.Y > -3 and rel.Y < b.size.Y + 2 then
			return true
		end
	end
	return false
end

local function isAlone(player: Player, pos: Vector3): boolean
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local hrp = rootOf(other)
			if hrp and (hrp.Position - pos).Magnitude < 45 then
				return false
			end
		end
	end
	return true
end

-- 가중치 표에서 하나 고름 (직전에 한 것은 빼고)
local function pick(player: Player, options: { { any } }): string
	local total = 0
	for _, option in options do
		if option[1] ~= lastKind[player] then
			total += option[2]
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, option in options do
		if option[1] ~= lastKind[player] then
			roll -= option[2]
			if roll <= 0 then
				return option[1]
			end
		end
	end
	return options[1][1]
end

local function scare(player: Player, hrp: BasePart)
	local pos = hrp.Position
	local kind: string
	if player:GetAttribute("Hiding") == true then
		kind = pick(player, { { "Scratch", 3 }, { "Breath", 2 }, { "Whisper", 1 } })
	elseif isIndoors(pos) then
		kind = pick(player, { { "Knock", 3 }, { "RoofSteps", 3 }, { "LampOut", 2 }, { "Mimic", 1.5 }, { "Whisper", 1 } })
	else
		local alone = isAlone(player, pos)
		kind = pick(player, {
			{ "Steps", 3 },
			{ "Snap", 2.5 },
			{ "Figure", if act >= 2 then 3 else 1.5 },
			{ "Mimic", if act >= 2 then 2.5 else 0.5 },
			{ "Ghost", 1.2 },
			{ "Breath", if alone then 2 else 0.5 },
			{ "Whisper", 1 },
		})
	end
	lastKind[player] = kind

	if kind == "Whisper" then
		effect:FireClient(player, "Scare", kind, Story.Whispers[rng:NextInteger(1, #Story.Whispers)])
	elseif kind == "Mimic" then
		-- 목소리는 "진짜 괴물이 있는 쪽"에서 들려옵니다. 따라가면 안 돼요.
		local from: Vector3? = nil
		local monsterPos = MonsterAI.getPosition()
		if monsterPos and (monsterPos - pos).Magnitude < 170 then
			from = monsterPos
		end
		effect:FireClient(player, "Scare", kind, Story.Mimic[rng:NextInteger(1, #Story.Mimic)], from)
	else
		effect:FireClient(player, "Scare", kind)
	end
end

local function interval(): number
	return between(D.Interval) * (if act >= 3 then D.FinaleFactor else 1)
end

local function tick(now: number)
	if act == 1 and now - startedAt > Config.Monster.StartGrace then
		setAct(2)
	end
	for _, player in Players:GetPlayers() do
		local hrp = rootOf(player)
		if not hrp then
			nextScare[player] = nil
			continue
		end
		if not nextScare[player] then
			nextScare[player] = now + between(D.FirstDelay)
		end
		if MonsterAI.isAfter(player) then
			lastChased[player] = now
		end
		if now >= nextScare[player] then
			local near = MonsterAI.distanceTo(hrp.Position) < D.MonsterNearRange
			local calm = now - (lastChased[player] or -999) < D.CalmAfterChase
			if near or calm then
				nextScare[player] = now + 8 -- 진짜가 근처에 있으면 미룸
			else
				scare(player, hrp)
				nextScare[player] = now + interval()
			end
		end
	end
end

function Director.init(mapInfo)
	map = mapInfo
	ReplicatedStorage:SetAttribute("Act", 1)
	Players.PlayerRemoving:Connect(function(player)
		nextScare[player] = nil
		lastKind[player] = nil
		lastChased[player] = nil
	end)
end

function Director.start()
	Director.stop()
	running = true
	startedAt = os.clock()
	table.clear(nextScare)
	table.clear(lastKind)
	table.clear(lastChased)
	local myGeneration = generation

	task.spawn(function()
		while running and generation == myGeneration do
			local ok, err = pcall(tick, os.clock())
			if not ok then
				warn("[Director]", err)
			end
			task.wait(1)
		end
	end)

	-- 숲 전체 정전 (2막부터)
	task.spawn(function()
		while running and generation == myGeneration do
			task.wait(between(D.BlackoutInterval))
			if running and generation == myGeneration and act >= 2 then
				effect:FireAllClients("Scare", "Blackout", rng:NextNumber(5, 9))
			end
		end
	end)

	-- 번개가 번쩍이는 순간 멀리 무언가가 서 있음 (숲에 있는 사람에게만)
	task.spawn(function()
		while running and generation == myGeneration do
			task.wait(between(D.LightningRevealInterval) * (if act >= 3 then 0.5 else 1))
			if not (running and generation == myGeneration) then
				return
			end
			for _, player in Players:GetPlayers() do
				local hrp = rootOf(player)
				if hrp and player:GetAttribute("Hiding") ~= true and not isIndoors(hrp.Position) and not MonsterAI.isAfter(player) then
					effect:FireClient(player, "Scare", "LightningFigure")
				end
			end
		end
	end)
end

function Director.stop()
	running = false
	generation += 1
	act = 1
	ReplicatedStorage:SetAttribute("Act", 1)
	MonsterAI.setFinale(false)
end

-- 3막(폭풍) 시작. 탈출 장치를 켰을 때(Objectives)나 시간이 얼마 안 남았을 때(GameLoop) 부름
function Director.triggerFinale()
	if running and act < 3 then
		setAct(3)
	end
end

function Director.getAct(): number
	return act
end

return Director
