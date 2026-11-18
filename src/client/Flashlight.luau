-- 손전등 (내 화면에서 보이는 빛)
--
--   [F] 켜기/끄기   [R] 건전지 교체
--   - 빛이 카메라를 살짝 늦게 따라와서 손에 든 것처럼 흔들립니다.
--   - 켜 두면 건전지가 닳아요 (Config.Flashlight.BatteryTime 초). 거의 다 닳으면 어두워지고 깜빡입니다.
--   - 건전지(Cell)는 오두막 탁자, 선반, 감시탑 등에서 주울 수 있어요.
--   - 불을 끄면 괴물 눈에 훨씬 덜 띕니다. 대신 눈이 어둠에 익은 만큼만 희미하게 보여요.
--   - 숲지기가 가까이 오거나 정전이 되면 빛이 치직거립니다.
-- 켜짐 여부는 서버(Services/Light)에 알려서, 괴물 시야와 동료 눈에 보이는 빛에 반영됩니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local F = Config.Flashlight
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Flashlight = {}

local wantOn = true -- 플레이어가 켜 둔 상태인지
local battery = 1 -- 0 ~ 1
local reported: boolean? = nil -- 서버에 마지막으로 알린 상태
local aim = CFrame.new()
local part: Part
local beam: SpotLight
local spill: SpotLight
local nightSight: PointLight
local onClick: (() -> ())? = nil
local onEmpty: (() -> ())? = nil
local warnedEmpty = false

local setLight = Remotes.get("SetLight")
local useCell = Remotes.get("UseCell")

local BEAM_COLOR = Color3.fromRGB(255, 238, 205)
local SPILL_COLOR = Color3.fromRGB(255, 230, 190)

-- 상점의 "손전등 불빛 색" 게임패스: 고른 색으로 빛을 물들임
local function applyColor()
	if not beam then
		return
	end
	local tint: Color3? = nil
	if player:GetAttribute("Pass_LightColor") == true then
		local id = player:GetAttribute("LightColor")
		for _, info in Config.Shop.LightColors do
			if info.id == id and id ~= "Default" then
				tint = info.color
			end
		end
	end
	beam.Color = tint or BEAM_COLOR
	spill.Color = tint or SPILL_COLOR
end

local function hidden(): boolean
	return player:GetAttribute("Hiding") == true
end

-- 지금 실제로 빛이 나오고 있는지
function Flashlight.isOn(): boolean
	return wantOn and battery > 0 and not hidden()
end

function Flashlight.battery(): number
	return battery
end

function Flashlight.toggle()
	if battery <= 0 and not wantOn then
		if onEmpty then
			onEmpty()
		end
	end
	wantOn = not wantOn
	if onClick then
		onClick()
	end
end

-- 건전지 교체 요청. 가방에 건전지가 있고 배터리가 닳았을 때만
function Flashlight.reload(): boolean
	if (player:GetAttribute("Cell") or 0) < 1 or battery > 0.9 then
		return false
	end
	useCell:FireServer()
	return true
end

-- 새 캐릭터로 숲에 들어갈 때: 새 건전지로 시작
function Flashlight.reset()
	battery = 1
	wantOn = true
	warnedEmpty = false
	aim = camera.CFrame
end

export type Options = {
	onClick: (() -> ())?, -- 켜고 끌 때 (딸깍 소리)
	onEmpty: (() -> ())?, -- 건전지가 다 닳았을 때 (안내)
}

function Flashlight.start(options: Options?)
	onClick = options and options.onClick
	onEmpty = options and options.onEmpty

	part = Instance.new("Part")
	part.Name = "Flashlight"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = Workspace

	-- 가운데 밝은 빛줄기
	beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Range = F.Range
	beam.Angle = F.Angle
	beam.Brightness = F.Brightness
	beam.Shadows = true
	beam.Color = Color3.fromRGB(255, 238, 205)
	beam.Parent = part

	-- 주변으로 번지는 약한 빛
	spill = Instance.new("SpotLight")
	spill.Name = "Spill"
	spill.Range = F.Range * 0.4
	spill.Angle = math.min(F.Angle * 2, 120)
	spill.Brightness = F.Brightness * 0.16
	spill.Shadows = false
	spill.Color = Color3.fromRGB(255, 230, 190)
	spill.Parent = part

	-- 불을 껐을 때: 어둠에 익은 눈 (아주 가까운 곳만 희미하게)
	nightSight = Instance.new("PointLight")
	nightSight.Name = "NightSight"
	nightSight.Range = 16
	nightSight.Brightness = 0
	nightSight.Shadows = false
	nightSight.Color = Color3.fromRGB(120, 140, 185)
	nightSight.Parent = part

	aim = camera.CFrame

	applyColor()
	player:GetAttributeChangedSignal("LightColor"):Connect(applyColor)
	player:GetAttributeChangedSignal("Pass_LightColor"):Connect(applyColor)

	-- 서버가 건전지를 갈아 끼워 줬을 때
	player:GetAttributeChangedSignal("CellCharge"):Connect(function()
		battery = 1
		warnedEmpty = false
		wantOn = true
	end)
end

-- 매 프레임. interference: 0~1 (괴물이 가깝거나 정전일 때 빛이 치직거리는 정도), drain: 건전지를 닳게 할지
function Flashlight.update(dt: number, interference: number, drain: boolean)
	-- 빛이 시선을 살짝 늦게 따라옴 + 손떨림
	local t = os.clock()
	local sway = CFrame.Angles(math.noise(t * 0.9, 1.3) * 0.02, math.noise(t * 0.8, 7.7) * 0.02, 0)
	aim = aim:Lerp(camera.CFrame.Rotation * sway, 1 - math.exp(-dt * 13))
	part.CFrame = CFrame.new((camera.CFrame * CFrame.new(0.55, -0.45, -0.2)).Position) * aim.Rotation

	local on = Flashlight.isOn()
	if on and drain then
		battery = math.max(0, battery - dt / F.BatteryTime)
		if battery <= 0 and not warnedEmpty then
			warnedEmpty = true
			if onEmpty then
				onEmpty()
			end
		end
		on = battery > 0
	end

	-- 밝기: 건전지가 거의 닳으면 어두워지고 깜빡임
	local level = 1
	if battery < F.LowBattery then
		local low = battery / F.LowBattery
		level = 0.35 + low * 0.65
		if math.random() < (1 - low) * 0.12 then
			level *= 0.2
		end
	end
	if interference > 0 and math.random() < interference * 0.5 then
		level = 0
	end
	beam.Enabled = on
	spill.Enabled = on
	beam.Brightness = F.Brightness * level
	spill.Brightness = F.Brightness * 0.16 * level
	local night = if on or player:GetAttribute("InLobby") == true then 0 else 0.4
	nightSight.Brightness += (night - nightSight.Brightness) * math.min(1, dt * 1.2) -- 눈이 천천히 어둠에 익음

	-- 내 머리에 달린 "동료에게 보이는 빛"은 내 화면에서는 끔 (내 손전등과 겹치니까)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local teamLight = head and head:FindFirstChild("TeamLight")
	if teamLight and teamLight:IsA("SpotLight") and teamLight.Enabled then
		teamLight.Enabled = false
	end

	if reported ~= on then
		reported = on
		setLight:FireServer(on)
	end
end

return Flashlight
