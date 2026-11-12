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

local t0 = os.clock()
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock() - t0
	for light, base in flickerLights do
		if not light.Parent then
			flickerLights[light] = nil
		else
			local n = math.noise(t * 3, base * 7.3)
			light.Brightness = if math.random() < 0.01 then 0 else base * (0.75 + n * 0.6)
		end
	end
	local pickups = Workspace:FindFirstChild("Pickups")
	if pickups then
		for _, part in pickups:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("Spin") then
				part.CFrame = part.CFrame * CFrame.Angles(0, dt * 1.5, 0)
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
		spot.Enabled = not spot.Enabled
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
		Hud.flash(Color3.fromRGB(200, 0, 0), 0.35, 0.7)
		shake(0.06, 0.4)
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
	elseif kind == "Sealed" then
		tempLight(a, Color3.fromRGB(160, 70, 255), 80, 8, 2.5)
		Hud.flash(Color3.fromRGB(160, 70, 255), 0.4, 2)
		shake(0.05, 1.5)
	end
end)
