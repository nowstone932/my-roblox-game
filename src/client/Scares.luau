-- 공포 연출을 실제로 보여주는 곳 (각자 화면에서만 보이고 들립니다)
-- 언제 무엇을 할지는 서버의 Services/Director.luau 가 상황을 보고 정해서 알려줘요.
--
--   Snap            등 뒤에서 나뭇가지 부러지는 소리
--   Steps           등 뒤에서 따라오는 발소리 (돌아보면 뚝 멈춤)
--   Breath          바로 뒤(숨어 있을 땐 문 바로 앞)에서 들리는 숨소리
--   Figure          나무 사이에 키 큰 형체가 서 있음. 똑바로 쳐다보거나 다가가면 스르륵 물러남
--   Ghost           사라진 벌목꾼이 등을 돌리고 서 있음
--   Mimic           숲 어딘가에서 죽은 사람 목소리가 부름 (따라가면 안 됨)
--   Knock           (집 안) 누가 벽을 두드림
--   RoofSteps       (집 안) 지붕 위를 걸어가는 무거운 발소리
--   LampOut         가까운 등불이 치직거리다 꺼짐
--   Scratch         (옷장 안) 문을 긁는 소리
--   Whisper         환청
--   Blackout        숲 전체 불빛이 한동안 꺼짐
--   LightningFigure 번개가 번쩍하는 순간, 바로 저 앞에 무언가가 서 있음

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Audio)
local Flashlight = require(script.Parent.Flashlight)
local Hud = require(script.Parent.Hud)
local Immersion = require(script.Parent.Immersion)
local Lights = require(script.Parent.Lights)
local Weather = require(script.Parent.Weather)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Scares = {}

local SHADOW = Color3.fromRGB(14, 12, 11)
local EYE_DARK = Color3.fromRGB(14, 12, 10)
local EYE_SHINE = Color3.fromRGB(200, 255, 215)

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function randomDir(): Vector3
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function ghostPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end

-- 카메라 기준 angle(라디안)만큼 옆, dist 만큼 떨어진 땅 위의 한 점. 건물에 가려져 안 보이면 nil
local function groundSpot(angle: number, dist: number): Vector3?
	local camPos = camera.CFrame.Position
	local dir = CFrame.Angles(0, angle, 0) * flat(camera.CFrame.LookVector)
	local pos = camPos + dir * dist
	local down = Workspace:Raycast(Vector3.new(pos.X, 70, pos.Z), Vector3.new(0, -90, 0))
	if not down or math.abs(down.Position.Y - (camPos.Y - 5)) > 6 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local chest = down.Position + Vector3.new(0, 8, 0)
	if Workspace:Raycast(camPos, chest - camPos, params) then
		return nil -- 벽이나 나무에 완전히 가려짐
	end
	return down.Position
end

---------------------------------------------------------------------------
-- 형체 (숲지기의 실루엣)
---------------------------------------------------------------------------
local function buildFigure(ground: Vector3): (Model, { BasePart })
	local camPos = camera.CFrame.Position
	local base = CFrame.lookAt(ground, Vector3.new(camPos.X, ground.Y, camPos.Z))
	local m = Instance.new("Model")
	m.Name = "Figure"
	local eyes = {}
	local function p(size: Vector3, cf: CFrame)
		return ghostPart(m, size, base * cf, SHADOW)
	end
	for _, side in { -1, 1 } do
		p(Vector3.new(0.7, 3.4, 0.7), CFrame.new(side * 0.7, 5, -0.5) * CFrame.Angles(0.38, 0, 0)) -- 허벅지
		p(Vector3.new(0.5, 3.6, 0.5), CFrame.new(side * 0.7, 1.7, -0.6) * CFrame.Angles(-0.38, 0, 0)) -- 정강이
		p(Vector3.new(0.5, 8.4, 0.5), CFrame.new(side * 1.75, 6.2, -1) * CFrame.Angles(0.12, 0, side * 0.05)) -- 긴 팔
		-- 뿔
		local len = if side < 0 then 4 else 2
		p(Vector3.new(0.24, len, 0.24), CFrame.new(side * 0.5, 13.3, -1.6) * CFrame.Angles(-0.3, 0, side * -0.55) * CFrame.new(0, len / 2, 0))
		local eye = ghostPart(m, Vector3.new(0.17, 0.17, 0.17), base * CFrame.new(side * 0.42, 12.7, -2.75), EYE_DARK, Enum.Material.Neon)
		eye.Shape = Enum.PartType.Ball
		table.insert(eyes, eye)
	end
	p(Vector3.new(2.3, 4.2, 1.2), CFrame.new(0, 8.6, -0.7) * CFrame.Angles(-0.3, 0, 0)) -- 굽은 몸통
	p(Vector3.new(3.4, 0.7, 1.1), CFrame.new(0, 10.4, -1.1)) -- 어깨
	p(Vector3.new(1.3, 1.4, 1.6), CFrame.new(0, 12.6, -1.9)) -- 머리
	p(Vector3.new(0.9, 0.7, 1.4), CFrame.new(0, 12.3, -3.2)) -- 주둥이
	m.Parent = Workspace
	return m, eyes
end

local function shineEyes(eyes: { BasePart })
	local camPos = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local lit = Flashlight.isOn()
	for _, eye in eyes do
		local offset = eye.Position - camPos
		local shine = 0
		if lit and offset.Magnitude < 100 then
			shine = math.clamp((look:Dot(offset.Unit) - 0.9) / 0.07, 0, 1)
		end
		eye.Color = EYE_DARK:Lerp(EYE_SHINE, shine)
	end
end

-- 스르륵 옆으로 물러나며 사라짐
local function withdraw(model: Model)
	local side = camera.CFrame.RightVector * (if math.random() < 0.5 then 7 else -7)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = d.CFrame + side, Transparency = 1 }):Play()
		end
	end
	task.delay(0.45, function()
		model:Destroy()
	end)
end

local function figure(): boolean
	local ground: Vector3? = nil
	for _ = 1, 10 do
		local angle = math.rad(math.random(18, 48)) * (if math.random() < 0.5 then 1 else -1)
		ground = groundSpot(angle, math.random(34, 52))
		if ground then
			break
		end
	end
	if not ground then
		return false
	end
	local model, eyes = buildFigure(ground)
	local head = ground + Vector3.new(0, 12, 0)
	local start = os.clock()
	local stared = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		shineEyes(eyes)
		local toHead = head - camera.CFrame.Position
		local facing = toHead.Unit:Dot(camera.CFrame.LookVector)
		if facing > 0.985 then
			stared += dt
		end
		local age = os.clock() - start
		if stared > 0.5 or toHead.Magnitude < 24 then
			conn:Disconnect()
			withdraw(model)
		elseif age > 11 and facing < 0.6 then
			conn:Disconnect()
			model:Destroy() -- 안 보는 사이에 없어짐
		elseif age > 16 then
			conn:Disconnect()
			withdraw(model)
		end
	end)
	return true
end

-- 번개가 번쩍하는 순간에만 보이는 형체
local function lightningFigure()
	local ground: Vector3? = nil
	for _ = 1, 8 do
		ground = groundSpot(math.rad(math.random(-16, 16)), math.random(26, 40))
		if ground then
			break
		end
	end
	local duration = Weather.strike(1)
	if not ground then
		return
	end
	local model, _ = buildFigure(ground)
	Audio.play("Stinger", nil, 0.6)
	task.delay(duration + 0.1, function()
		model:Destroy() -- 다시 캄캄해지면 이미 없음
	end)
end

-- 사라진 벌목꾼: 등을 돌리고 서 있다가, 다가가거나 오래 쳐다보면 사라짐
local function ghost(): boolean
	local ground: Vector3? = nil
	for _ = 1, 8 do
		ground = groundSpot(math.rad(math.random(-30, 30)), math.random(30, 46))
		if ground then
			break
		end
	end
	if not ground then
		return false
	end
	local camPos = camera.CFrame.Position
	-- 나에게 등을 보이고 서 있음
	local base = CFrame.lookAt(ground, ground + flat(ground - camPos))
	local m = Instance.new("Model")
	m.Name = "Apparition"
	local cloth = Color3.fromRGB(58, 50, 44)
	local skin = Color3.fromRGB(120, 125, 128)
	local function p(size: Vector3, cf: CFrame, color: Color3)
		ghostPart(m, size, base * cf, color, Enum.Material.Fabric).Transparency = 0.15
	end
	p(Vector3.new(0.8, 2.6, 0.8), CFrame.new(-0.5, 1.3, 0), cloth)
	p(Vector3.new(0.8, 2.6, 0.8), CFrame.new(0.5, 1.3, 0), cloth)
	p(Vector3.new(2, 2.4, 1), CFrame.new(0, 3.8, 0), Color3.fromRGB(96, 62, 48))
	p(Vector3.new(0.7, 2.6, 0.7), CFrame.new(-1.35, 3.6, 0), cloth)
	p(Vector3.new(0.7, 2.6, 0.7), CFrame.new(1.35, 3.6, 0), cloth)
	p(Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 5.55, 0) * CFrame.Angles(0, 0, 0.3), skin)
	p(Vector3.new(1.35, 0.45, 1.4), CFrame.new(0.12, 6.2, 0) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(150, 122, 40))
	m.Parent = Workspace
	local start = os.clock()
	local stared = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local toGhost = (ground + Vector3.new(0, 4, 0)) - camera.CFrame.Position
		if toGhost.Unit:Dot(camera.CFrame.LookVector) > 0.97 then
			stared += dt
		end
		if os.clock() - start > 9 or stared > 1.6 or toGhost.Magnitude < 20 then
			conn:Disconnect()
			m:Destroy()
		end
	end)
	return true
end

---------------------------------------------------------------------------
-- 소리 연출
---------------------------------------------------------------------------
local function snap()
	local behind = -flat(camera.CFrame.LookVector)
	Audio.play("TwigSnap", camera.CFrame.Position + behind * math.random(9, 14) + camera.CFrame.RightVector * math.random(-5, 5))
end

-- 등 뒤에서 따라오는 발소리. 소리 나는 쪽을 돌아보면 뚝 멈춤
local function steps()
	local behind = -flat(camera.CFrame.LookVector)
	task.spawn(function()
		local count = math.random(5, 9)
		for i = 1, count do
			if flat(camera.CFrame.LookVector):Dot(behind) > 0.35 then
				return -- 돌아봤다. 아무도 없다.
			end
			local dist = math.max(5, 17 - i * 1.5)
			Audio.play("FakeStep", camera.CFrame.Position + behind * dist - Vector3.new(0, 4, 0), 0.55 + i * 0.06)
			task.wait(0.45)
		end
	end)
end

-- 카메라를 따라다니는 숨소리 (offset: 카메라 기준 위치)
local function breath(offset: CFrame, seconds: number)
	local holder = ghostPart(Workspace, Vector3.new(0.2, 0.2, 0.2), camera.CFrame * offset, SHADOW)
	holder.Transparency = 1
	Audio.play("MonsterBreath", holder, 0.9)
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		holder.CFrame = camera.CFrame * offset
		if os.clock() - start > seconds then
			conn:Disconnect()
			holder:Destroy() -- 뚝 끊김
		end
	end)
end

local function knock()
	local pos = camera.CFrame.Position + randomDir() * 9
	task.spawn(function()
		for i = 1, 3 do
			Audio.play("Knock", pos, 0.7 + i * 0.1)
			task.wait(0.3)
		end
		task.wait(1.1)
		for _ = 1, 2 do
			Audio.play("Knock", pos, 1.3)
			Immersion.shake(0.008, 0.2)
			task.wait(0.22)
		end
	end)
end

local function roofSteps()
	local dir = randomDir()
	local start = camera.CFrame.Position + Vector3.new(0, 9, 0) - dir * 9
	task.spawn(function()
		for i = 0, 6 do
			Audio.play("MonsterFootstep", start + dir * (i * 3), 0.9)
			Immersion.shake(0.006, 0.25)
			task.wait(0.55)
		end
	end)
end

local function lampOut()
	local pos = Lights.killNearest(camera.CFrame.Position)
	if pos then
		Audio.play("Blackout", nil, 0.35)
	else
		knock()
	end
end

local function scratch()
	local front = camera.CFrame.Position + camera.CFrame.LookVector * 2.5
	task.spawn(function()
		for i = 1, 3 do
			Audio.play("Scratch", front, 0.6 + i * 0.15)
			Immersion.shake(0.005, 0.3)
			task.wait(0.9)
		end
		breath(CFrame.new(0, 0.3, -2.5), 3)
	end)
end

local function mimic(text: string?, from: Vector3?)
	local camPos = camera.CFrame.Position
	local dir = if from then flat(from - camPos) else randomDir()
	local dist = if from then math.clamp((from - camPos).Magnitude, 30, 60) else 45
	Audio.play("Mimic", camPos + dir * dist)
	if text then
		Hud.whisper(text)
	end
end

---------------------------------------------------------------------------
function Scares.play(kind: string, a: any, b: any)
	if player:GetAttribute("InLobby") == true then
		return
	end
	if kind == "Snap" then
		snap()
	elseif kind == "Steps" then
		steps()
	elseif kind == "Breath" then
		if player:GetAttribute("Hiding") == true then
			breath(CFrame.new(0, 0.3, -2.5), 3.5)
		else
			breath(CFrame.new(if math.random() < 0.5 then 1.2 else -1.2, 0.5, 2.6), 3.5)
		end
	elseif kind == "Figure" then
		if not figure() then
			snap()
		end
	elseif kind == "Ghost" then
		if not ghost() then
			steps()
		end
	elseif kind == "Mimic" then
		mimic(if typeof(a) == "string" then a else nil, if typeof(b) == "Vector3" then b else nil)
	elseif kind == "Knock" then
		knock()
	elseif kind == "RoofSteps" then
		roofSteps()
	elseif kind == "LampOut" then
		lampOut()
	elseif kind == "Scratch" then
		scratch()
	elseif kind == "Whisper" then
		if typeof(a) == "string" then
			Hud.whisper(a)
		end
		Audio.play("Whisper")
		Immersion.pulse(0.7)
	elseif kind == "Blackout" then
		Lights.blackout(if typeof(a) == "number" then a else 6)
		Audio.play("Blackout")
	elseif kind == "LightningFigure" then
		lightningFigure()
	end
end

return Scares
