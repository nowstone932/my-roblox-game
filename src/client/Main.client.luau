-- 클라이언트(플레이어 컴퓨터) 시작점
-- 입력 처리, 손전등, 총 쏘는 효과, 괴물이 가까울 때 화면 붉어짐 등을 담당합니다.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local craftRemote = Remotes.get("Craft")
local fireRemote = Remotes.get("Fire")
local useItemRemote = Remotes.get("UseItem")

Hud.init({
	craft = function(recipeId)
		craftRemote:FireServer(recipeId)
	end,
	buyProduct = function(productId)
		MarketplaceService:PromptProductPurchase(player, productId)
	end,
})

-- HUD 갱신: 인벤토리나 라운드 정보가 바뀔 때마다
player.AttributeChanged:Connect(Hud.refresh)
ReplicatedStorage.AttributeChanged:Connect(Hud.refresh)

Remotes.get("Notify").OnClientEvent:Connect(Hud.notify)

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
spot.Angle = 50
spot.Brightness = 3
spot.Shadows = true
spot.Color = Color3.fromRGB(255, 240, 210)
spot.Parent = flashlightPart

RunService.RenderStepped:Connect(function()
	flashlightPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.5, 0)
end)

-- 괴물이 가까우면 화면이 붉어짐 ------------------------------------------
RunService.Heartbeat:Connect(function()
	local monster = Workspace:FindFirstChild("Monster")
	local root = monster and monster:FindFirstChild("HumanoidRootPart")
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if root and myRoot and root:IsA("BasePart") and myRoot:IsA("BasePart") then
		local dist = (root.Position - myRoot.Position).Magnitude
		Hud.setDanger(1 - dist / 60)
	else
		Hud.setDanger(0)
	end
end)

-- 죽음 화면 ---------------------------------------------------------------
local function onCharacter(character: Model)
	Hud.setDead(false)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		Hud.setDead(true)
		Hud.setCraftOpen(false)
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- 입력 --------------------------------------------------------------------
-- ContextActionService에 true를 넘기면 모바일에서 화면 버튼이 자동으로 생깁니다.
local function onFire(_, inputState)
	if inputState ~= Enum.UserInputState.Begin or Hud.isCraftOpen() then
		return Enum.ContextActionResult.Pass
	end
	if (player:GetAttribute("FlareGun") or 0) < 1 then
		Hud.notify("총이 없어요. 제작(C)에서 조명탄 총을 만드세요")
		return Enum.ContextActionResult.Pass
	end
	fireRemote:FireServer(camera.CFrame.Position, camera.CFrame.LookVector)
	return Enum.ContextActionResult.Pass
end

local function onFlashlight(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		spot.Enabled = not spot.Enabled
	end
	return Enum.ContextActionResult.Sink
end

local function onFlashbang(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		useItemRemote:FireServer("Flashbang")
	end
	return Enum.ContextActionResult.Sink
end

local function onMedkit(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		useItemRemote:FireServer("Medkit")
	end
	return Enum.ContextActionResult.Sink
end

local function onCraftMenu(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Hud.setCraftOpen(not Hud.isCraftOpen())
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Fire", onFire, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("Flashlight", onFlashlight, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)
ContextActionService:BindAction("Flashbang", onFlashbang, true, Enum.KeyCode.G, Enum.KeyCode.ButtonL2)
ContextActionService:BindAction("Medkit", onMedkit, true, Enum.KeyCode.H, Enum.KeyCode.DPadDown)
ContextActionService:BindAction("CraftMenu", onCraftMenu, true, Enum.KeyCode.C, Enum.KeyCode.ButtonY)

ContextActionService:SetTitle("Fire", "발사")
ContextActionService:SetTitle("Flashlight", "빛")
ContextActionService:SetTitle("Flashbang", "섬광")
ContextActionService:SetTitle("Medkit", "회복")
ContextActionService:SetTitle("CraftMenu", "제작")

-- 숫자키 1~4: 빠른 제작
local quickKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	for i, key in quickKeys do
		if input.KeyCode == key and Recipes.list[i] then
			craftRemote:FireServer(Recipes.list[i].id)
		end
	end
end)

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
		tempLight(hitPos, Color3.fromRGB(255, 120, 40), 16, 3, 0.4)
	elseif kind == "Flash" then
		local position: Vector3, radius: number = a, b
		tempLight(position, Color3.new(1, 1, 1), radius, 10, 0.3)
		local char = player.Character
		local myRoot = char and char:FindFirstChild("HumanoidRootPart")
		if myRoot and myRoot:IsA("BasePart") and (myRoot.Position - position).Magnitude < radius then
			Hud.flash(Color3.new(1, 1, 1), 0.2, 1.2)
		end
	elseif kind == "Hurt" then
		Hud.flash(Color3.fromRGB(200, 0, 0), 0.4, 0.6)
	elseif kind == "HitMarker" then
		Hud.hitMarker()
	end
end)
