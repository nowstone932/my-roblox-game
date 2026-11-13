-- 클라이언트(플레이어 컴퓨터) 시작점
-- 도구 사용 입력, 손전등, 달리기, 효과, 괴물 접근 시 화면 연출을 담당합니다.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)
local MonsterAnimator = require(script.Parent.MonsterAnimator)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local craftRemote = Remotes.get("Craft")
local useToolRemote = Remotes.get("UseTool")

Hud.init({
	craft = function(recipeId)
		craftRemote:FireServer(recipeId)
	end,
	buyProduct = function(productId)
		MarketplaceService:PromptProductPurchase(player, productId)
	end,
})
MonsterAnimator.start()

player.AttributeChanged:Connect(Hud.refresh)
ReplicatedStorage.AttributeChanged:Connect(Hud.refresh)
Remotes.get("Notify").OnClientEvent:Connect(Hud.notify)
Remotes.get("ShowNote").OnClientEvent:Connect(Hud.showNote)
Remotes.get("StoryEvent").OnClientEvent:Connect(function(kind: string, endingId: string?)
	if kind == "Intro" then
		Hud.showIntro()
	elseif kind == "Ending" and endingId then
		Hud.showEnding(endingId)
	end
end)

-- 소리 (Config.Sounds 에 ID를 넣으면 켜짐) -----------------------------
local function makeSound(id: number, volume: number, looped: boolean): Sound?
	if id == 0 then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = volume
	s.Looped = looped
	s.Parent = SoundService
	return s
end
local ambience = makeSound(Config.Sounds.Ambience, 0.4, true)
if ambience then
	ambience:Play()
end
local heartbeat = makeSound(Config.Sounds.Heartbeat, 0, true)
if heartbeat then
	heartbeat:Play()
end
local screamSound = makeSound(Config.Sounds.MonsterScream, 0.8, false)
local gunSound = makeSound(Config.Sounds.Gunshot, 0.7, false)
local flashSound = makeSound(Config.Sounds.Flashbang, 0.9, false)

-- 손전등 ------------------------------------------------------------------
local flashlightPart = Instance.new("Part")
flashlightPart.Name = "Flashlight"
flashlightPart.Size = Vector3.new(0.2, 0.2, 0.2)
flashlightPart.Transparency = 1
flashlightPart.Anchored = true
flashlightPart.CanCollide = false
flashlightPart.CanQuery = false
flashlightPart.CanTouch = false
flashlightPart.Parent = Workspace

local spot = Instance.new("SpotLight")
spot.Range = 60
spot.Angle = 45
spot.Brightness = 3
spot.Shadows = true
spot.Color = Color3.fromRGB(255, 240, 210)
spot.Parent = flashlightPart

-- 1인칭에서도 팔과 들고 있는 도구가 보이게
local VISIBLE_IN_FIRST_PERSON = {
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	["Right Arm"] = true, ["Left Arm"] = true,
}

RunService.RenderStepped:Connect(function()
	flashlightPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, 0)
	local char = player.Character
	if char then
		for _, part in char:GetChildren() do
			if part:IsA("BasePart") and VISIBLE_IN_FIRST_PERSON[part.Name] then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end)

-- 깜빡이는 불빛 / 빙글 도는 탈출 부품 ---------------------------------------
-- (매 프레임 맵 전체를 뒤지면 느려지므로, Flicker 표시가 있는 불빛만 목록으로 모아둠)
local flickerLights: { [PointLight]: number } = {}
local function registerFlicker(part: Instance)
	if part:IsA("BasePart") and part:GetAttribute("Flicker") then
		local light = part:FindFirstChildOfClass("PointLight") or part:WaitForChild("PointLight", 2)
		if light and light:IsA("PointLight") then
			flickerLights[light] = light.Brightness
		end
	end
end
task.spawn(function()
	local forest = Workspace:WaitForChild("BlackpineForest")
	for _, d in forest:GetDescendants() do
		registerFlicker(d)
	end
	forest.DescendantAdded:Connect(function(d)
		task.defer(registerFlicker, d)
	end)
end)

-- 괴물 근처의 불빛은 꺼지고, 정전 이벤트 때는 전부 꺼짐
local blackoutUntil = 0
local function monsterRoot(): BasePart?
	local monster = Workspace:FindFirstChild("Monster")
	local root = monster and monster:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local state = monster:GetAttribute("State")
		if state ~= "Downed" and state ~= "Sealed" then
			return root
		end
	end
	return nil
end

local t0 = os.clock()
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock() - t0
	local mRoot = monsterRoot()
	local blackout = os.clock() < blackoutUntil
	for light, base in flickerLights do
		local part = light.Parent
		if not part then
			flickerLights[light] = nil
		elseif blackout then
			light.Brightness = if math.random() < 0.02 then base * 0.5 else 0
		else
			local n = math.noise(t * 3, base * 7.3)
			local brightness = if math.random() < 0.01 then 0 else base * (0.75 + n * 0.6)
			if mRoot and part:IsA("BasePart") then
				local d = (part.Position - mRoot.Position).Magnitude
				if d < 35 then
					-- 괴물이 가까울수록 더 자주 꺼짐
					brightness = if math.random() < (1 - d / 35) * 0.9 then 0 else brightness * (d / 35)
				end
			end
			light.Brightness = brightness
		end
	end
	local pickups = Workspace:FindFirstChild("Pickups")
	if pickups then
		for _, item in pickups:GetChildren() do
			if item:IsA("Model") and item:GetAttribute("Spin") then
				item:PivotTo(item:GetPivot() * CFrame.Angles(0, dt * 1.5, 0))
			end
		end
	end
end)

-- 손전등 깜빡임 (괴물이 가깝거나 정전일 때)
local flashlightOn = true
RunService.Heartbeat:Connect(function()
	local flicker = false
	local mRoot = monsterRoot()
	if mRoot then
		local d = (mRoot.Position - camera.CFrame.Position).Magnitude
		if d < 45 and math.random() < (1 - d / 45) * 0.5 then
			flicker = true
		end
	end
	if os.clock() < blackoutUntil and math.random() < 0.3 then
		flicker = true
	end
	spot.Enabled = flashlightOn and not flicker
end)

-- 괴물 발소리: 걸음마다 화면이 살짝 울림
local footstepSound = makeSound(Config.Sounds.Footstep, 1, false)
local stepTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local mRoot = monsterRoot()
	if not mRoot then
		return
	end
	local v = mRoot.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < 2 then
		return
	end
	stepTimer -= dt
	if stepTimer <= 0 then
		stepTimer = math.clamp(9 / speed, 0.25, 0.9)
		local d = (mRoot.Position - camera.CFrame.Position).Magnitude
		if d < 60 then
			local strength = (1 - d / 60)
			camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * 0.02 * strength, 0, (math.random() - 0.5) * 0.015 * strength)
			if footstepSound then
				footstepSound.Volume = strength
				footstepSound:Play()
			end
		end
	end
end)

-- 괴물이 가까우면 화면이 붉어지고 심장 소리 ---------------------------------
RunService.Heartbeat:Connect(function()
	local monster = Workspace:FindFirstChild("Monster")
	local root = monster and monster:FindFirstChild("HumanoidRootPart")
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	local danger = 0
	if root and myRoot and root:IsA("BasePart") and myRoot:IsA("BasePart") then
		local state = monster:GetAttribute("State")
		if state ~= "Downed" and state ~= "Sealed" then
			danger = math.clamp(1 - (root.Position - myRoot.Position).Magnitude / 70, 0, 1)
		end
	end
	Hud.setDanger(danger)
	if heartbeat then
		heartbeat.Volume = danger * 1.2
		heartbeat.PlaybackSpeed = 1 + danger * 0.6
	end
end)

-- 달리기 (Shift) ----------------------------------------------------------
local stamina = 1
local sprinting = false
RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if player:GetAttribute("Downed") == true then
		-- 쓰러짐: 기어다니기만 가능, 시점이 낮아짐
		hum.WalkSpeed = 2.5
		hum.JumpHeight = 0
		hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.new(0, -2.6, 0), 0.1)
		Hud.setStamina(stamina)
		return
	end
	hum.JumpHeight = 7.2
	hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, 0.15)
	local moving = hum.MoveDirection.Magnitude > 0.1
	if sprinting and moving and stamina > 0 then
		stamina = math.max(0, stamina - dt / 5) -- 5초 달리기
		hum.WalkSpeed = 23
	else
		if stamina <= 0 then
			sprinting = false
		end
		stamina = math.min(1, stamina + dt / 8)
		hum.WalkSpeed = 15
	end
	Hud.setStamina(stamina)
end)

-- 죽음 화면 ---------------------------------------------------------------
local function onCharacter(character: Model)
	Hud.setDead(false)
	stamina = 1
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		Hud.setDead(true)
		Hud.setCraftOpen(false)
	end)
	-- 도구를 쓰면(클릭) 서버에 요청
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and not child:GetAttribute("Hooked") then
			child:SetAttribute("Hooked", true)
			child.Activated:Connect(function()
				if Hud.isCraftOpen() then
					return
				end
				local itemId = child:GetAttribute("ItemId")
				if itemId then
					useToolRemote:FireServer(itemId, camera.CFrame.Position, camera.CFrame.LookVector)
				end
			end)
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- 키 입력 -----------------------------------------------------------------
ContextActionService:BindAction("Flashlight", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		flashlightOn = not flashlightOn
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)
ContextActionService:SetTitle("Flashlight", "빛")

ContextActionService:BindAction("CraftMenu", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Hud.setCraftOpen(not Hud.isCraftOpen())
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("CraftMenu", "제작")

ContextActionService:BindAction("Sprint", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprinting = stamina > 0.1
	elseif inputState == Enum.UserInputState.End then
		sprinting = false
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Sprint", "달리기")

-- 효과 --------------------------------------------------------------------
local function tempLight(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = p
	p.Parent = Workspace
	task.delay(duration, function()
		p:Destroy()
	end)
end

local function shake(strength: number, duration: number)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > duration then
			conn:Disconnect()
			return
		end
		local s = strength * (1 - t / duration)
		camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end)
end

local function myPosition(): Vector3?
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if myRoot and myRoot:IsA("BasePart") then
		return myRoot.Position
	end
	return nil
end

local whisperSound = makeSound(Config.Sounds.Whisper, 0.8, false)

-- 공격당하는 순간 카메라가 괴물 얼굴로 확 돌아감
local function jumpscare(facePos: Vector3)
	local start = os.clock()
	RunService:BindToRenderStep("Jumpscare", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		if t > 0.45 then
			RunService:UnbindFromRenderStep("Jumpscare")
			return
		end
		local camPos = camera.CFrame.Position
		local look = CFrame.lookAt(camPos, facePos)
		local alpha = math.min(t / 0.08, 1)
		camera.CFrame = camera.CFrame:Lerp(look, alpha) * CFrame.Angles((math.random() - 0.5) * 0.05, (math.random() - 0.5) * 0.05, 0)
	end)
end

local function smokeBurst(pos: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 10, 4)
	p.Position = pos + Vector3.new(0, 4, 0)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 10, 12))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(2, 6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 0
	smoke.Parent = p
	p.Parent = Workspace
	smoke:Emit(60)
	task.delay(3, function()
		p:Destroy()
	end)
end

-- 멀리 창백한 벌목꾼 유령: 쳐다보거나 가까이 가면 사라짐
local function apparition()
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local pos = camera.CFrame.Position + flat.Unit * math.random(40, 60) + camera.CFrame.RightVector * math.random(-15, 15)
	local ground = Workspace:Raycast(Vector3.new(pos.X, 60, pos.Z), Vector3.new(0, -80, 0))
	if not ground then
		return
	end
	local base = CFrame.lookAt(ground.Position, Vector3.new(camera.CFrame.Position.X, ground.Position.Y, camera.CFrame.Position.Z))
	local ghost = Instance.new("Model")
	ghost.Name = "Apparition"
	local pale = Color3.fromRGB(200, 210, 220)
	local function gp(size: Vector3, cf: CFrame, color: Color3?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = base * cf
		p.Color = color or pale
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.45
		p.Parent = ghost
	end
	gp(Vector3.new(0.8, 2.6, 0.8), CFrame.new(-0.5, 1.3, 0))
	gp(Vector3.new(0.8, 2.6, 0.8), CFrame.new(0.5, 1.3, 0))
	gp(Vector3.new(2, 2.4, 1), CFrame.new(0, 3.8, 0), Color3.fromRGB(170, 120, 90))
	gp(Vector3.new(0.7, 2.6, 0.7), CFrame.new(-1.35, 3.6, 0))
	gp(Vector3.new(0.7, 2.6, 0.7), CFrame.new(1.35, 3.6, 0))
	gp(Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, 0.35))
	gp(Vector3.new(1.4, 0.5, 1.4), CFrame.new(0.1, 6.3, 0) * CFrame.Angles(0, 0, 0.35), Color3.fromRGB(200, 170, 60))
	ghost.Parent = Workspace
	local start = os.clock()
	local watched = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local toGhost = (ground.Position + Vector3.new(0, 4, 0)) - camera.CFrame.Position
		if toGhost.Unit:Dot(camera.CFrame.LookVector) > 0.97 then
			watched += dt
		end
		if os.clock() - start > 6 or watched > 1.2 or toGhost.Magnitude < 25 then
			conn:Disconnect()
			ghost:Destroy()
		end
	end)
end

Remotes.get("Effect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "Shot" then
		local origin: Vector3, hitPos: Vector3 = a, b
		local length = (hitPos - origin).Magnitude
		local tracer = Instance.new("Part")
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.CanTouch = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 120, 40)
		tracer.Size = Vector3.new(0.15, 0.15, length)
		tracer.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, -0.4, -length / 2)
		tracer.Parent = Workspace
		task.delay(0.08, function()
			tracer:Destroy()
		end)
		tempLight(hitPos, Color3.fromRGB(255, 120, 40), 24, 4, 1.2) -- 조명탄이라 한동안 밝힘
		tempLight(origin, Color3.fromRGB(255, 160, 80), 14, 3, 0.08)
		if gunSound then
			gunSound:Play()
		end
	elseif kind == "Flash" then
		local position: Vector3, radius: number = a, b
		tempLight(position, Color3.new(1, 1, 1), radius * 1.5, 12, 0.35)
		local me = myPosition()
		if me and (me - position).Magnitude < radius then
			Hud.flash(Color3.new(1, 1, 1), 0.15, 1.2)
		end
		if flashSound then
			flashSound:Play()
		end
	elseif kind == "Hurt" then
		Hud.flash(Color3.fromRGB(200, 0, 0), 0.25, 0.8)
		shake(0.08, 0.5)
		if typeof(a) == "Vector3" then
			jumpscare(a)
		end
	elseif kind == "Heal" then
		Hud.flash(Color3.fromRGB(80, 255, 120), 0.75, 0.6)
	elseif kind == "HitMarker" then
		Hud.hitMarker()
	elseif kind == "MonsterHit" then
		tempLight(a, Color3.fromRGB(255, 60, 40), 10, 2, 0.15)
	elseif kind == "Scream" then
		local me = myPosition()
		if me and (me - (a :: Vector3)).Magnitude < 100 then
			shake(0.04, 0.8)
			Hud.flash(Color3.fromRGB(90, 0, 0), 0.6, 0.8)
			if screamSound then
				screamSound:Play()
			end
		end
	elseif kind == "Vanish" then
		smokeBurst(a)
	elseif kind == "Whisper" then
		Hud.whisper(a)
		Hud.flash(Color3.new(0, 0, 0), 0.5, 2)
		if whisperSound then
			whisperSound:Play()
		end
	elseif kind == "Apparition" then
		apparition()
	elseif kind == "Snap" then
		Hud.notify("(등 뒤에서 나뭇가지 부러지는 소리…)")
		shake(0.03, 0.3)
	elseif kind == "Blackout" then
		blackoutUntil = os.clock() + (b or a or 5)
		Hud.notify("…불빛이 모두 꺼졌다")
	elseif kind == "Sealed" then
		tempLight(a, Color3.fromRGB(160, 70, 255), 80, 8, 2.5)
		Hud.flash(Color3.fromRGB(160, 70, 255), 0.4, 2)
		shake(0.05, 1.5)
	end
end)
