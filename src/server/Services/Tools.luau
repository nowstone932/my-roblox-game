-- 제작한 도구를 진짜 Roblox Tool로 만들어 핫바(화면 아래 1~9번 칸)에 넣습니다.
-- 인벤토리 개수와 항상 맞춰집니다: 개수가 0이 되면 핫바에서 사라지고,
-- 섬광탄처럼 쌓이는 아이템은 이름 옆에 개수가 표시됩니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Items = require(ReplicatedStorage.Shared.Items)
local Inventory = require(script.Parent.Inventory)

local Tools = {}

local function decor(handle: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = handle.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = handle
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- 도구 모양 만들기. 손잡이(Handle) 기준으로 -Z가 앞쪽입니다.
local builders: { [string]: (Tool, BasePart) -> () } = {
	FlareGun = function(tool, h)
		h.Size = Vector3.new(0.35, 1, 0.5)
		h.Color = Color3.fromRGB(40, 40, 40)
		decor(h, Vector3.new(0.5, 0.6, 1.2), CFrame.new(0, 0.6, -0.2), Color3.fromRGB(200, 70, 20), Enum.Material.Plastic)
		decor(h, Vector3.new(1.6, 0.45, 0.45), CFrame.new(0, 0.65, -1.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(230, 90, 25), Enum.Material.Plastic, Enum.PartType.Cylinder)
		decor(h, Vector3.new(0.1, 0.35, 0.3), CFrame.new(0, 0.1, -0.35), Color3.fromRGB(30, 30, 30))
		tool.Grip = CFrame.new(0, -0.2, 0)
	end,
	Axe = function(tool, h)
		h.Size = Vector3.new(0.3, 3.2, 0.3)
		h.Color = Color3.fromRGB(110, 75, 45)
		h.Material = Enum.Material.Wood
		decor(h, Vector3.new(0.25, 1.1, 1.5), CFrame.new(0, 1.2, -0.6), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
		decor(h, Vector3.new(0.12, 1.3, 0.2), CFrame.new(0, 1.2, -1.4), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
		tool.Grip = CFrame.new(0, -1.1, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	end,
	Flashbang = function(tool, h)
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(1.1, 0.7, 0.7)
		h.Color = Color3.fromRGB(70, 75, 70)
		h.Material = Enum.Material.Metal
		decor(h, Vector3.new(0.2, 0.75, 0.75), CFrame.new(0.3, 0, 0), Color3.fromRGB(255, 220, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
		decor(h, Vector3.new(0.15, 0.4, 0.15), CFrame.new(0.6, 0.15, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal)
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
	end,
	Trap = function(tool, h)
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(0.3, 2, 2)
		h.Color = Color3.fromRGB(90, 90, 95)
		h.Material = Enum.Material.CorrodedMetal
		for k = 0, 5 do
			local a = k * math.pi / 3
			decor(h, Vector3.new(0.4, 0.15, 0.15), CFrame.new(0.3, math.cos(a) * 0.85, math.sin(a) * 0.85), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
		end
		tool.Grip = CFrame.Angles(0, 0, math.rad(90))
	end,
	Medkit = function(tool, h)
		h.Size = Vector3.new(1.2, 0.8, 0.6)
		h.Color = Color3.fromRGB(235, 235, 235)
		decor(h, Vector3.new(0.7, 0.2, 0.05), CFrame.new(0, 0, -0.31), Color3.fromRGB(200, 30, 30), Enum.Material.Neon)
		decor(h, Vector3.new(0.2, 0.6, 0.05), CFrame.new(0, 0, -0.31), Color3.fromRGB(200, 30, 30), Enum.Material.Neon)
		tool.Grip = CFrame.new(0, 0, 0)
	end,
	SealStake = function(tool, h)
		h.Size = Vector3.new(0.35, 3.6, 0.35)
		h.Color = Color3.fromRGB(90, 60, 40)
		h.Material = Enum.Material.Wood
		decor(h, Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, -2.1, 0), Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
		for i = 1, 3 do
			decor(h, Vector3.new(0.4, 0.12, 0.4), CFrame.new(0, -1.2 + i * 0.5, 0), Color3.fromRGB(160, 70, 255), Enum.Material.Neon)
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(160, 70, 255)
		glow.Range = 8
		glow.Brightness = 1
		glow.Parent = h
		tool.Grip = CFrame.new(0, 0.8, 0) * CFrame.Angles(math.rad(180), 0, 0) -- 뾰족한 쪽이 아래로
	end,
}

-- 직접 만든 도구 모델의 자동 크기 (가장 긴 변, 스터드)
local ASSET_SIZES = {
	FlareGun = 2,
	Axe = 3.5,
	Flashbang = 1.1,
	Trap = 2,
	Medkit = 1.3,
	SealStake = 3.8,
}

local function displayName(itemId: string, count: number): string
	local def = Items.defs[itemId]
	if def.stack then
		return ("%s x%d"):format(def.name, count)
	end
	return def.name
end

local function createTool(itemId: string, count: number): Tool
	local def = Items.defs[itemId]
	local tool = Instance.new("Tool")
	tool.Name = displayName(itemId, count)
	tool.ToolTip = def.desc
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", itemId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Material = Enum.Material.SmoothPlastic
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	-- ReplicatedStorage.Assets.Tools 에 직접 만든 모델이 있으면 그걸 붙임
	local asset = Assets.clone("Tools", itemId, ASSET_SIZES[itemId])
	if asset then
		handle.Size = Vector3.new(0.4, 0.4, 0.4)
		handle.Transparency = 1
		-- 모델의 가운데가 손잡이 위치에 오도록 이동 (방향은 그대로: 앞 = -Z)
		local center = asset:GetBoundingBox().Position
		asset:PivotTo(asset:GetPivot() - center + handle.Position)
		for _, d in asset:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = d
				weld.Parent = d
			end
		end
		asset.Parent = tool
		tool.Grip = CFrame.new()
	else
		local builder = builders[itemId]
		if builder then
			builder(tool, handle)
		end
	end
	return tool
end

local function findTool(player: Player, itemId: string): Tool?
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") == itemId then
					return child
				end
			end
		end
	end
	return nil
end

function Tools.sync(player: Player, itemId: string)
	local def = Items.defs[itemId]
	if not def or def.kind ~= "Tool" then
		return
	end
	local count = Inventory.get(player, itemId)
	local tool = findTool(player, itemId)
	if count > 0 then
		if tool then
			tool.Name = displayName(itemId, count)
		else
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				createTool(itemId, count).Parent = backpack
			end
		end
	elseif tool then
		tool:Destroy()
	end
end

function Tools.syncAll(player: Player)
	for _, itemId in Items.order do
		Tools.sync(player, itemId)
	end
end

-- 지금 손에 들고 있는 도구가 itemId 인지
function Tools.isHolding(player: Player, itemId: string): boolean
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("ItemId") == itemId
end

function Tools.init()
	Inventory.onChanged(Tools.sync)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- 캐릭터가 새로 생기면 Backpack이 비워지므로 다시 채움
			player:WaitForChild("Backpack")
			task.defer(Tools.syncAll, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Tools
