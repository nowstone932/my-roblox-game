-- 날씨: 비, 번개, 안개, 바람 (각자 화면에서 만듭니다)
--
-- 밤이 깊어질수록(1막 → 2막 → 3막) 날씨가 사나워져요. 세기는 Config.Weather / Config.Atmosphere.
--   비   : 카메라를 따라다니는 빗줄기. 손전등 빛에 비치면 반짝입니다. 지붕 아래에서는 그칩니다.
--   번개 : 가끔 숲 전체가 번쩍 밝아졌다가 다시 캄캄해지고, 조금 뒤 천둥이 울립니다.
--          (그 순간에만 멀리까지 보여요. 무엇이 서 있는지도…)
--   안개 : 막이 오를수록 짙어집니다. 대기실에서는 옅게.
-- 빗소리/천둥 소리는 src/shared/SoundList.luau 의 Rain / Thunder / Wind 에 ID를 넣어야 납니다.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Audio = require(script.Parent.Audio)
local Immersion = require(script.Parent.Immersion)

local W = Config.Weather
local A = Config.Atmosphere
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Weather = {}

local rainPart: Part
local rain: ParticleEmitter
local rainSound: Sound? = nil
local windSound: Sound? = nil

local indoors = false
local roofCheck = 0
local nextLightning = 0
local rng = Random.new()

-- 번개: 시간에 따른 밝기 (0~1). 두세 번 깜빡이다 꺼짐
local FLASH = { { 0, 1 }, { 0.07, 0.25 }, { 0.13, 0.9 }, { 0.24, 0.12 }, { 0.32, 0.55 }, { 0.6, 0 } }
local FLASH_TIME = 0.6
local flashStart = -10
local flashScale = 1
local flashing = false
local baseBrightness = 0
local baseExposure = 0
local baseOutdoor = Color3.new()
local FLASH_AMBIENT = Color3.fromRGB(150, 165, 200)

local function act(): number
	return math.clamp(ReplicatedStorage:GetAttribute("Act") or 1, 1, 3)
end

local function inForest(): boolean
	return player:GetAttribute("InLobby") ~= true
end

local function flashLevel(now: number): number
	local t = now - flashStart
	if t < 0 or t >= FLASH_TIME then
		return 0
	end
	for i = 1, #FLASH - 1 do
		local a, b = FLASH[i], FLASH[i + 1]
		if t >= a[1] and t < b[1] then
			local alpha = (t - a[1]) / (b[1] - a[1])
			return (a[2] + (b[2] - a[2]) * alpha) * flashScale
		end
	end
	return 0
end

-- 번개를 지금 한 번 침. 번쩍이는 시간(초)을 돌려줌
function Weather.strike(scale: number?): number
	if not flashing then
		-- 평소 밝기를 기억해 뒀다가 번개가 끝나면 되돌림
		flashing = true
		baseBrightness = Lighting.Brightness
		baseExposure = Lighting.ExposureCompensation
		baseOutdoor = Lighting.OutdoorAmbient
	end
	flashStart = os.clock()
	flashScale = scale or 1
	local delay = rng:NextNumber(0.5, 2.6) -- 멀수록 천둥이 늦게 옴
	task.delay(delay, function()
		if inForest() then
			Audio.play("Thunder", nil, math.clamp(1.2 - delay * 0.25, 0.4, 1) * (if indoors then 0.6 else 1))
			Immersion.shake(0.012 / delay, 0.9)
		end
	end)
	return FLASH_TIME
end

local function update(dt: number)
	local now = os.clock()
	local stage = act()
	local forest = inForest()
	local camPos = camera.CFrame.Position

	-- 지붕 아래인지 (0.3초마다 확인)
	if now - roofCheck > 0.3 then
		roofCheck = now
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { rainPart }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		indoors = Workspace:Raycast(camPos, Vector3.new(0, 45, 0), params) ~= nil
	end

	-- 비
	local wind = W.Wind[stage]
	rainPart.CFrame = CFrame.new(camPos + Vector3.new(0, 30, 0) + camera.CFrame.LookVector * Vector3.new(12, 0, 12))
	rain.Enabled = forest and not indoors and W.RainRate[stage] > 0
	rain.Rate = W.RainRate[stage]
	rain.Acceleration = Vector3.new(wind * 1.6, 0, wind * 0.8)

	-- 소리 (ID가 들어 있을 때만)
	if rainSound == nil and Audio.has("Rain") then
		rainSound = Audio.loop("Rain")
	end
	if windSound == nil and Audio.has("Wind") then
		windSound = Audio.loop("Wind")
	end
	local rainLevel = if not forest or W.RainRate[stage] <= 0 then 0 else (0.45 + stage * 0.18) * (if indoors then 0.45 else 1)
	Audio.fade(rainSound, rainLevel, dt, 1.5)
	Audio.fade(windSound, if forest then (stage - 1) * 0.5 * (if indoors then 0.5 else 1) else 0, dt, 0.6)

	-- 안개와 바람
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local density = if forest then A.Density[stage] else A.LobbyDensity
		local haze = if forest then A.Haze[stage] else 0.5
		atmosphere.Density += (density - atmosphere.Density) * math.min(1, dt * 0.25)
		atmosphere.Haze += (haze - atmosphere.Haze) * math.min(1, dt * 0.25)
	end
	local gust = 1 + math.noise(now * 0.2, 3.1) * 0.6
	Workspace.GlobalWind = Vector3.new(wind * gust, 0, wind * 0.5 * gust)

	-- 번개
	if forest and ReplicatedStorage:GetAttribute("RoundState") == "Playing" then
		if nextLightning == 0 then
			nextLightning = now + rng:NextNumber(20, 45)
		elseif now >= nextLightning then
			local range = W.LightningInterval[stage]
			nextLightning = now + rng:NextNumber(range[1], range[2])
			Weather.strike(rng:NextNumber(0.6, 1))
		end
	else
		nextLightning = 0
	end
	if flashing then
		local level = if forest then flashLevel(now) else 0
		Lighting.Brightness = baseBrightness + level * 4.5
		Lighting.ExposureCompensation = baseExposure + level * 1.5
		Lighting.OutdoorAmbient = baseOutdoor:Lerp(FLASH_AMBIENT, level)
		if now - flashStart >= FLASH_TIME then
			flashing = false
		end
	end
end

function Weather.start()
	rainPart = Instance.new("Part")
	rainPart.Name = "RainCloud"
	rainPart.Size = Vector3.new(56, 1, 56)
	rainPart.Transparency = 1
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Parent = Workspace

	rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Size = NumberSequence.new(0.32)
	rain.Squash = NumberSequence.new(2.6) -- 길쭉하게 늘려서 빗줄기처럼
	rain.Color = ColorSequence.new(Color3.fromRGB(205, 215, 230))
	rain.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.8) })
	rain.LightInfluence = 1 -- 손전등/번개 빛을 받으면 밝게 보임
	rain.LightEmission = 0.2
	rain.Lifetime = NumberRange.new(0.45, 0.6)
	rain.Speed = NumberRange.new(80, 95)
	rain.SpreadAngle = Vector2.new(3, 3)
	rain.Rate = 0
	rain.Enabled = false
	rain.Parent = rainPart

	RunService.RenderStepped:Connect(update)
end

function Weather.isIndoors(): boolean
	return indoors
end

return Weather
