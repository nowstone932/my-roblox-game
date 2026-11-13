-- 탈출 루트 4가지의 장치들
--   정문: 발전기에 퓨즈 3개 → 정문이 올라감 → 출구 구역 통과
--   트럭: 배터리/연료통/열쇠 설치 → 시동(큰 소리) → 20초 버티기 → 근처에 있던 사람만 탈출
--   무전: 안테나 2개 설치 → 구조 요청(큰 소리) → 90초 뒤 헬기 도착 → 헬기장에 서 있으면 탈출
--   봉인: (Combat + MonsterAI 에서 처리) 쓰러진 괴물에 봉인 말뚝 → 살아있는 전원 탈출
--
-- 진행 상황은 ReplicatedStorage의 Attribute로 공개되어 HUD의 목표 패널에 표시됩니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local MonsterAI = require(script.Parent.MonsterAI)
local Sfx = require(script.Parent.Sfx)

local notify = Remotes.get("Notify")
local E = Config.Escape

local Objectives = {}

local map = nil
local escapeCallback: ((Player, string) -> ())? = nil
local active = false
local generation = 0
local rageStage = 0

local gateClosedCf: CFrame
local truckHome: CFrame
local helicopter: Model? = nil

local truckPrompt: ProximityPrompt
local radioPrompt: ProximityPrompt
local generatorPrompt: ProximityPrompt

local function set(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end
local function get(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

local function escape(player: Player, route: string)
	if escapeCallback then
		escapeCallback(player, route)
	end
end

local function aliveInRound(player: Player, allowDowned: boolean?): BasePart?
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true then
		return nil
	end
	if not allowDowned and player:GetAttribute("Downed") == true then
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

-- 탈출 진행도가 오를 때마다 괴물이 조금씩 빨라짐
local function progress(message: string?)
	rageStage += 1
	MonsterAI.setRage(rageStage)
	if message then
		notify:FireAllClients(message)
	end
	if rageStage % 3 == 0 then
		notify:FireAllClients("숲이 술렁인다… 숲지기가 더 빨라졌다")
	end
end

---------------------------------------------------------------------------
-- 정문
---------------------------------------------------------------------------
local function refreshFuseSlots()
	local placed = get("FusesPlaced") or 0
	for _, child in map.Generator.Parent:GetChildren() do
		local slot = child:GetAttribute("Slot")
		if slot then
			child.Color = if slot <= placed then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(40, 40, 40)
		end
	end
end

local function openGate()
	set("GateOpen", true)
	generatorPrompt.Enabled = false
	map.GateLamp.Color = Color3.fromRGB(60, 255, 90)
	local lamp = map.GateLamp:FindFirstChildOfClass("PointLight")
	if lamp then
		lamp.Color = Color3.fromRGB(60, 255, 90)
	end
	Sfx.all("Generator", map.Generator.Position)
	Sfx.all("GateOpen", map.GateDoor.Position)
	TweenService:Create(map.GateDoor, TweenInfo.new(4, Enum.EasingStyle.Quad), { CFrame = gateClosedCf + Vector3.new(0, 17, 0) }):Play()
	map.ExitZone.Transparency = 0.85
	MonsterAI.noise(map.Generator.Position, Config.Noise.Generator)
	notify:FireAllClients("발전기 가동! 북쪽 정문이 열린다!")
end

local function onGenerator(player: Player)
	if not active or get("GateOpen") then
		return
	end
	local have = Inventory.get(player, "Fuse")
	if have < 1 then
		notify:FireClient(player, ("퓨즈가 필요하다 (%d/%d)"):format(get("FusesPlaced"), E.FusesRequired))
		return
	end
	local used = math.min(have, E.FusesRequired - get("FusesPlaced"))
	Inventory.add(player, "Fuse", -used)
	set("FusesPlaced", get("FusesPlaced") + used)
	refreshFuseSlots()
	Sfx.all("Install", map.Generator.Position)
	if get("FusesPlaced") >= E.FusesRequired then
		progress()
		openGate()
	else
		progress(("퓨즈 %d/%d"):format(get("FusesPlaced"), E.FusesRequired))
	end
end

---------------------------------------------------------------------------
-- 트럭
---------------------------------------------------------------------------
local TRUCK_PARTS = { { key = "TruckBattery", item = "Battery" }, { key = "TruckFuel", item = "FuelCan" }, { key = "TruckKey", item = "CarKey" } }

local function truckReady(): boolean
	for _, p in TRUCK_PARTS do
		if not get(p.key) then
			return false
		end
	end
	return true
end

local function setHeadlights(on: boolean)
	for _, d in map.Truck:GetDescendants() do
		if d:IsA("SpotLight") then
			d.Enabled = on
		elseif d:IsA("BasePart") and d.Name == "Headlight" then
			d.Color = if on then Color3.fromRGB(255, 250, 220) else Color3.fromRGB(60, 60, 50)
			d.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		end
	end
end

local function driveAway(myGeneration: number)
	set("TruckState", "Gone")
	truckPrompt.Enabled = false
	local truckPos = map.Truck:GetPivot().Position
	for _, player in Players:GetPlayers() do
		local hrp = aliveInRound(player)
		if hrp and (hrp.Position - truckPos).Magnitude <= E.TruckBoardRadius then
			escape(player, "Truck")
		end
	end
	notify:FireAllClients("트럭이 출발했다!")
	-- 북쪽 길로 달려 나가는 연출
	local start = map.Truck:GetPivot()
	for i = 1, 60 do
		if generation ~= myGeneration then
			return
		end
		map.Truck:PivotTo(start * CFrame.new(0, 0, -i * 1.5))
		task.wait(0.05)
	end
	map.Truck:PivotTo(start + Vector3.new(0, -100, 0)) -- 화면 밖으로 치움
	Sfx.detach(map.Truck)
end

local function onTruck(player: Player)
	if not active then
		return
	end
	local state = get("TruckState")
	if state == "Broken" then
		local installed = {}
		for _, p in TRUCK_PARTS do
			if not get(p.key) and Inventory.get(player, p.item) > 0 then
				Inventory.add(player, p.item, -1)
				set(p.key, true)
				table.insert(installed, p.item)
			end
		end
		if #installed == 0 then
			notify:FireClient(player, "트럭에 필요한 것: 배터리, 연료통, 열쇠")
			return
		end
		Sfx.all("Install", map.Truck:GetPivot().Position)
		progress("트럭 부품 설치!")
		if truckReady() then
			set("TruckState", "Ready")
			truckPrompt.ActionText = "시동 걸기"
			truckPrompt.HoldDuration = 3
			notify:FireAllClients("트럭 수리 완료! 시동을 걸 수 있다 (소리가 크다)")
		end
	elseif state == "Ready" then
		set("TruckState", "Starting")
		truckPrompt.Enabled = false
		setHeadlights(true)
		Sfx.attach("TruckEngine", map.Truck)
		MonsterAI.noise(map.Truck:GetPivot().Position, Config.Noise.TruckStart)
		progress(("엔진이 굉음을 낸다! %d초 뒤 출발 — 트럭 근처를 지켜라!"):format(E.TruckWarmup))
		local myGeneration = generation
		task.spawn(function()
			for t = E.TruckWarmup, 1, -1 do
				if generation ~= myGeneration then
					return
				end
				set("TruckTimer", t)
				task.wait(1)
			end
			if generation == myGeneration then
				set("TruckTimer", 0)
				driveAway(myGeneration)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 무전 / 헬기
---------------------------------------------------------------------------
local function buildHelicopter(): Model
	local m = Instance.new("Model")
	m.Name = "RescueHelicopter"
	local base = map.Helipad.CFrame.Position + Vector3.new(0, 14, 0)
	local function p(size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.CFrame = CFrame.new(base + offset)
		part.Color = color
		part.Material = mat or Enum.Material.Metal
		part.Parent = m
		return part
	end
	local green = Color3.fromRGB(50, 70, 50)
	local body = p(Vector3.new(8, 7, 14), Vector3.zero, green)
	p(Vector3.new(2, 2, 16), Vector3.new(0, 1.5, 14), green)
	p(Vector3.new(0.4, 5, 3), Vector3.new(0, 3, 21), green)
	p(Vector3.new(40, 0.3, 1.2), Vector3.new(0, 4.5, 0), Color3.fromRGB(30, 30, 30)).Name = "Rotor"
	p(Vector3.new(1.2, 0.3, 40), Vector3.new(0, 4.5, 0), Color3.fromRGB(30, 30, 30)).Name = "Rotor"
	p(Vector3.new(0.5, 0.5, 14), Vector3.new(-3, -4.5, 0), Color3.fromRGB(30, 30, 30))
	p(Vector3.new(0.5, 0.5, 14), Vector3.new(3, -4.5, 0), Color3.fromRGB(30, 30, 30))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 40
	spot.Angle = 70
	spot.Brightness = 5
	spot.Parent = body
	local beacon = p(Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, -3.8, -6), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	beacon:SetAttribute("Flicker", true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 30
	light.Parent = beacon
	m.Parent = map.Folder
	return m
end

local function runRescue(myGeneration: number)
	for t = E.RescueWait, 1, -1 do
		if generation ~= myGeneration then
			return
		end
		set("RescueTimer", t)
		task.wait(1)
	end
	if generation ~= myGeneration then
		return
	end
	set("RadioState", "Arrived")
	helicopter = buildHelicopter()
	Sfx.attach("Helicopter", helicopter)
	notify:FireAllClients(("구조 헬기 도착! 서쪽 헬기장으로! (%d초 대기)"):format(E.RescueWindow))
	MonsterAI.noise(map.Helipad.Position, Config.Noise.RadioCall)
	local center = map.Helipad.Position
	for t = E.RescueWindow, 1, -1 do
		if generation ~= myGeneration then
			return
		end
		set("RescueTimer", t)
		for _, player in Players:GetPlayers() do
			local hrp = aliveInRound(player)
			if hrp then
				local flat = Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z)
				if flat.Magnitude < 17 and hrp.Position.Y < 12 then
					escape(player, "Radio")
				end
			end
		end
		task.wait(1)
	end
	if generation == myGeneration then
		set("RadioState", "Gone")
		set("RescueTimer", 0)
		if helicopter then
			helicopter:Destroy()
			helicopter = nil
		end
		notify:FireAllClients("헬기가 떠났다…")
	end
end

local function onRadio(player: Player)
	if not active then
		return
	end
	local state = get("RadioState")
	if state == "Broken" then
		local have = Inventory.get(player, "Antenna")
		if have < 1 then
			notify:FireClient(player, ("안테나 부품이 필요하다 (%d/%d)"):format(get("AntennaPlaced"), E.AntennaRequired))
			return
		end
		local used = math.min(have, E.AntennaRequired - get("AntennaPlaced"))
		Inventory.add(player, "Antenna", -used)
		set("AntennaPlaced", get("AntennaPlaced") + used)
		Sfx.all("Install", map.Radio.Position)
		if get("AntennaPlaced") >= E.AntennaRequired then
			set("RadioState", "Ready")
			radioPrompt.ActionText = "구조 요청"
			radioPrompt.HoldDuration = 2
			progress("무전기 수리 완료! 구조를 요청할 수 있다")
		else
			progress(("안테나 %d/%d"):format(get("AntennaPlaced"), E.AntennaRequired))
		end
	elseif state == "Ready" then
		set("RadioState", "Calling")
		radioPrompt.Enabled = false
		Sfx.all("RadioCall", map.Radio.Position)
		MonsterAI.noise(map.Radio.Position, Config.Noise.RadioCall)
		progress(("\"여기는 수색대! 흑송 벌목장 헬기장으로 구조 바람!\" — %d초 뒤 헬기 도착"):format(E.RescueWait))
		task.spawn(runRescue, generation)
	end
end

---------------------------------------------------------------------------
-- 초기화 / 라운드 리셋
---------------------------------------------------------------------------
local function makePrompt(parent: BasePart, action: string, object: string, hold: number, callback: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(callback)
	return prompt
end

function Objectives.init(mapInfo, onEscape: (Player, string) -> ())
	map = mapInfo
	escapeCallback = onEscape
	gateClosedCf = map.GateDoor.CFrame
	truckHome = map.Truck:GetPivot()

	generatorPrompt = makePrompt(map.Generator, "퓨즈 넣기", "발전기", 0.6, onGenerator)
	truckPrompt = makePrompt(map.Truck.PrimaryPart, "부품 설치", "벌목 트럭", 0.8, onTruck)
	radioPrompt = makePrompt(map.Radio, "안테나 설치", "무전기", 0.8, onRadio)

	map.ExitZone.Touched:Connect(function(hit)
		if not active or not get("GateOpen") then
			return
		end
		local char = hit:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		if player and aliveInRound(player) then
			escape(player, "Gate")
		end
	end)

	set("FusesRequired", E.FusesRequired)
	set("AntennaRequired", E.AntennaRequired)
	Objectives.reset()
end

function Objectives.reset()
	generation += 1
	rageStage = 0
	set("FusesPlaced", 0)
	set("GateOpen", false)
	set("TruckBattery", false)
	set("TruckFuel", false)
	set("TruckKey", false)
	set("TruckState", "Broken")
	set("TruckTimer", 0)
	set("AntennaPlaced", 0)
	set("RadioState", "Broken")
	set("RescueTimer", 0)
	set("MonsterSealed", false)

	map.GateDoor.CFrame = gateClosedCf
	map.GateLamp.Color = Color3.fromRGB(255, 40, 40)
	local lamp = map.GateLamp:FindFirstChildOfClass("PointLight")
	if lamp then
		lamp.Color = Color3.fromRGB(255, 40, 40)
	end
	map.ExitZone.Transparency = 1
	generatorPrompt.Enabled = true
	refreshFuseSlots()

	map.Truck:PivotTo(truckHome)
	Sfx.detach(map.Truck)
	setHeadlights(false)
	truckPrompt.Enabled = true
	truckPrompt.ActionText = "부품 설치"
	truckPrompt.HoldDuration = 0.8

	radioPrompt.Enabled = true
	radioPrompt.ActionText = "안테나 설치"
	radioPrompt.HoldDuration = 0.8
	if helicopter then
		helicopter:Destroy()
		helicopter = nil
	end
end

function Objectives.setActive(isActive: boolean)
	active = isActive
end

-- 괴물이 봉인되면 GameLoop가 부름
function Objectives.onSealed()
	set("MonsterSealed", true)
	for _, player in Players:GetPlayers() do
		if aliveInRound(player, true) then
			escape(player, "Seal")
		end
	end
end

return Objectives
