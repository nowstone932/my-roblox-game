-- 화면 몰입 연출 (빨간 화면 같은 "게임 같은" 표시 대신, 몸으로 느끼는 연출)
--   - 화면 가장자리가 어두움(비네트). 숲지기가 가까우면 시야가 더 좁아짐
--   - 걸을 때 화면이 살짝 출렁임, 달리면 시야가 넓어짐, 웅크리면 시점이 낮아짐
--   - 겁에 질리면(괴물이 가까움) 색이 빠지고, 다치면 화면이 흐려짐
--   - 충격(울부짖음, 피격) 때 화면 흔들림
-- 세기는 Config.Screen 에서 바꿀 수 있어요 (멀미가 나면 HeadBob 을 0으로).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.Screen
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Immersion = {}

export type State = {
	active: boolean, -- 숲에서 살아 움직이는 중인지
	fear: number, -- 0~1 (괴물이 가까울수록)
	lowHealth: number, -- 0~1
	crouching: boolean,
	sprinting: boolean,
	downed: boolean,
}

local state: State = { active = false, fear = 0, lowHealth = 0, crouching = false, sprinting = false, downed = false }

local BASE_FOV = 70
local gradients: { UIGradient } = {}
local shownVignette = -1
local fearColor: ColorCorrectionEffect
local blur: BlurEffect

local bobPhase = 0
local pulse = 0 -- 순간적으로 시야가 좁아지는 정도 (천천히 풀림)
local hurt = 0 -- 순간적으로 흐려지는 정도
local shakeStrength = 0
local shakeUntil = 0
local shakeLength = 1

local function edge(gui: ScreenGui, size: UDim2, position: UDim2, anchor: Vector2, rotation: number)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new(1)
	gradient.Parent = frame
	table.insert(gradients, gradient)
end

local function setVignette(strength: number)
	strength = math.clamp(strength, 0, 1)
	if math.abs(strength - shownVignette) < 0.01 then
		return
	end
	shownVignette = strength
	-- 가장자리(0)는 어둡고 화면 안쪽(1)으로 갈수록 투명
	local seq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - strength),
		NumberSequenceKeypoint.new(0.55, 1 - strength * 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, gradient in gradients do
		gradient.Transparency = seq
	end
end

local function render(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local now = os.clock()

	pulse = math.max(0, pulse - dt * 0.5)
	hurt = math.max(0, hurt - dt * 0.9)

	local fear = if state.active then state.fear else 0
	local vignette = 0
	if player:GetAttribute("InLobby") ~= true then
		vignette = S.Vignette + fear * S.FearVignette + pulse * 0.3 + state.lowHealth * 0.2
	end
	setVignette(vignette)

	fearColor.Saturation = -0.35 * fear - 0.4 * state.lowHealth
	fearColor.Contrast = 0.08 * fear
	fearColor.Brightness = -0.03 * fear
	blur.Size = state.lowHealth * 5 + hurt * 14 + (if state.downed then 6 else 0)

	-- 시야각: 달리면 넓어지고, 겁에 질리면 살짝 좁아짐
	local fov = BASE_FOV + (if state.sprinting then 6 else 0) - fear * 3 - (if state.crouching then 2 else 0)
	camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 5)

	if hum then
		-- 시점 높이: 웅크리기 / 쓰러짐
		local offset = Vector3.zero
		if state.downed then
			offset = Vector3.new(0, -2.6, 0)
		elseif state.crouching then
			offset = Vector3.new(0, -1.7, 0)
		end
		hum.CameraOffset = hum.CameraOffset:Lerp(offset, math.min(1, dt * 8))

		-- 걸음에 맞춰 화면이 출렁임
		if state.active and S.HeadBob > 0 then
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local speed = 0
			if root and root:IsA("BasePart") then
				local v = root.AssemblyLinearVelocity
				speed = Vector3.new(v.X, 0, v.Z).Magnitude
			end
			bobPhase += dt * speed * 0.55
			local amount = math.min(speed / 16, 1.4) * S.HeadBob
			local breath = math.sin(now * (1.4 + fear * 2.2)) * (0.0025 + fear * 0.004) -- 숨이 가빠짐
			camera.CFrame *= CFrame.new(math.cos(bobPhase * 0.5) * 0.035 * amount, math.abs(math.sin(bobPhase * 0.5)) * -0.07 * amount, 0)
				* CFrame.Angles(breath, 0, math.sin(bobPhase * 0.5) * 0.006 * amount)
		end
	end

	if now < shakeUntil then
		local s = shakeStrength * ((shakeUntil - now) / shakeLength)
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s * 0.5)
	end
end

function Immersion.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Immersion"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5 -- HUD 글씨 아래
	edge(gui, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90) -- 위
	edge(gui, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90) -- 아래
	edge(gui, UDim2.fromScale(0.36, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0) -- 왼쪽
	edge(gui, UDim2.fromScale(0.36, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180) -- 오른쪽
	gui.Parent = player:WaitForChild("PlayerGui")

	fearColor = Instance.new("ColorCorrectionEffect")
	fearColor.Name = "FearColor"
	fearColor.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "HurtBlur"
	blur.Size = 0
	blur.Parent = Lighting

	-- 기본 카메라가 자리를 잡은 직후에 덧붙임
	RunService:BindToRenderStep("Immersion", Enum.RenderPriority.Camera.Value + 1, render)
end

function Immersion.set(newState: State)
	state = newState
end

-- 화면 흔들림 (strength: 0.02 약함 ~ 0.1 강함)
function Immersion.shake(strength: number, duration: number)
	local now = os.clock()
	if now < shakeUntil and shakeStrength > strength then
		return
	end
	shakeStrength = strength
	shakeLength = duration
	shakeUntil = now + duration
end

-- 순간적으로 시야가 좁아짐 (속삭임, 울부짖음)
function Immersion.pulse(amount: number)
	pulse = math.max(pulse, amount)
end

-- 맞았을 때 화면이 순간 흐려짐
function Immersion.hurt()
	hurt = 1
end

return Immersion
