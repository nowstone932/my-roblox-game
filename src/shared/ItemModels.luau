-- 바닥에 떨어진 아이템의 모양
-- ReplicatedStorage.Assets.Items 에 같은 이름의 모델이 있으면 그걸 쓰고,
-- 없으면 여기서 파트 여러 개를 조합해 그럴듯한 모양을 만듭니다.
-- 모든 모델은 "바닥 가운데"가 기준점(Root)입니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = require(ReplicatedStorage.Shared.Assets)
local Items = require(ReplicatedStorage.Shared.Items)

local ItemModels = {}

-- 아이템별 대략적인 크기 (에셋 자동 크기 맞춤에 사용)
ItemModels.Sizes = {
	Fuse = 1.4,
	Battery = 1.8,
	FuelCan = 2,
	CarKey = 1.2,
	Antenna = 2.6,
	Rune = 1.4,
	DogTag = 1,
	Scrap = 1.8,
	Wood = 2.2,
	Herb = 1.2,
	Gunpowder = 1.3,
	Cloth = 1.5,
}

local METAL = Color3.fromRGB(150, 150, 155)
local DARK = Color3.fromRGB(35, 35, 38)

type Ctx = { model: Model, part: (Vector3, CFrame, Color3, Enum.Material?, Enum.PartType?) -> Part }

local function newCtx(name: string): Ctx
	local model = Instance.new("Model")
	model.Name = name
	local ctx = { model = model } :: any
	ctx.part = function(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	return ctx
end

local function text(part: BasePart, face: Enum.NormalId, value: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥을 세움

local builders: { [string]: (Ctx) -> () } = {
	-- 유리관 퓨즈: 양쪽 금속 캡 + 빛나는 필라멘트
	Fuse = function(c)
		c.part(Vector3.new(1.1, 0.42, 0.42), at(0, 0.21, 0), Color3.fromRGB(220, 230, 240), Enum.Material.Glass, CYL).Transparency = 0.45
		c.part(Vector3.new(0.9, 0.06, 0.06), at(0, 0.21, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon, CYL)
		for _, x in { -0.62, 0.62 } do
			c.part(Vector3.new(0.22, 0.48, 0.48), at(x, 0.24, 0), Color3.fromRGB(190, 160, 80), Enum.Material.Metal, CYL)
		end
	end,
	-- 자동차 배터리: 몸통 + 단자(빨강/검정) + 손잡이
	Battery = function(c)
		c.part(Vector3.new(1.6, 1, 0.9), at(0, 0.5, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Plastic)
		local label = c.part(Vector3.new(1.62, 0.35, 0.92), at(0, 0.6, 0), Color3.fromRGB(40, 90, 200), Enum.Material.Plastic)
		text(label, Enum.NormalId.Front, "12V", Color3.new(1, 1, 1))
		c.part(Vector3.new(0.18, 0.2, 0.18), at(-0.55, 1.1, 0), Color3.fromRGB(200, 30, 30), Enum.Material.Metal, CYL).CFrame = at(-0.55, 1.1, 0) * UPRIGHT
		c.part(Vector3.new(0.18, 0.2, 0.18), at(0.55, 1.1, 0), DARK, Enum.Material.Metal, CYL).CFrame = at(0.55, 1.1, 0) * UPRIGHT
		c.part(Vector3.new(0.9, 0.08, 0.1), at(0, 1.35, 0), DARK)
		for _, x in { -0.42, 0.42 } do
			c.part(Vector3.new(0.08, 0.35, 0.1), at(x, 1.18, 0), DARK)
		end
	end,
	-- 빨간 제리캔
	FuelCan = function(c)
		local body = c.part(Vector3.new(1.2, 1.5, 0.55), at(0, 0.75, 0), Color3.fromRGB(170, 25, 20), Enum.Material.Metal)
		text(body, Enum.NormalId.Front, "연료", Color3.fromRGB(255, 230, 180))
		-- 옆면 X자 무늬
		for _, a in { 30, -30 } do
			c.part(Vector3.new(1.1, 0.08, 0.57), at(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(a)), Color3.fromRGB(140, 20, 15), Enum.Material.Metal)
		end
		c.part(Vector3.new(0.9, 0.12, 0.2), at(-0.1, 1.68, 0), Color3.fromRGB(150, 20, 15), Enum.Material.Metal) -- 손잡이
		for _, x in { -0.5, 0.3 } do
			c.part(Vector3.new(0.1, 0.2, 0.2), at(x, 1.57, 0), Color3.fromRGB(150, 20, 15), Enum.Material.Metal)
		end
		c.part(Vector3.new(0.5, 0.22, 0.22), at(0.55, 1.65, 0) * CFrame.Angles(0, 0, math.rad(40)), DARK, Enum.Material.Metal, CYL) -- 주둥이
	end,
	-- 열쇠고리: 고리 + 열쇠 + 종이 꼬리표
	CarKey = function(c)
		c.part(Vector3.new(0.05, 0.6, 0.6), at(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 180, 185), Enum.Material.Metal, CYL)
		c.part(Vector3.new(0.4, 0.06, 0.35), at(0.4, 0.04, 0), Color3.fromRGB(40, 40, 40), Enum.Material.Plastic) -- 열쇠 머리
		c.part(Vector3.new(0.6, 0.04, 0.12), at(0.85, 0.03, 0), Color3.fromRGB(200, 180, 90), Enum.Material.Metal) -- 열쇠 날
		for i = 0, 2 do
			c.part(Vector3.new(0.08, 0.05, 0.06), at(0.7 + i * 0.12, 0.03, 0.08), Color3.fromRGB(200, 180, 90), Enum.Material.Metal)
		end
		local tag = c.part(Vector3.new(0.5, 0.03, 0.32), at(-0.45, 0.02, 0.15) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(230, 220, 190), Enum.Material.Fabric)
		text(tag, Enum.NormalId.Top, "트럭", Color3.fromRGB(150, 20, 20))
	end,
	-- 안테나: 받침 + 마디 막대 + 가지 + 빨간 끝
	Antenna = function(c)
		c.part(Vector3.new(0.7, 0.3, 0.5), at(0, 0.15, 0), Color3.fromRGB(60, 65, 60), Enum.Material.Metal)
		c.part(Vector3.new(0.12, 2.1, 0.12), at(0, 1.35, 0), METAL, Enum.Material.Metal)
		for i, y in { 1.0, 1.5, 2.0 } do
			c.part(Vector3.new(0.8 - i * 0.15, 0.06, 0.06), at(0, y, 0), METAL, Enum.Material.Metal)
		end
		c.part(Vector3.new(0.18, 0.18, 0.18), at(0, 2.45, 0), Color3.fromRGB(255, 50, 40), Enum.Material.Neon, BALL)
		c.part(Vector3.new(0.4, 0.05, 0.3), at(0.15, 0.31, 0), Color3.fromRGB(30, 30, 30)) -- 커넥터
	end,
	-- 룬 돌: 거친 돌판 + 빛나는 문양
	Rune = function(c)
		local stone = c.part(Vector3.new(0.9, 1.3, 0.3), at(0, 0.65, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(4)), Color3.fromRGB(70, 70, 75), Enum.Material.Slate)
		text(stone, Enum.NormalId.Front, "ᛟ", Color3.fromRGB(190, 110, 255), Enum.Font.Arcade)
		text(stone, Enum.NormalId.Back, "ᛉ", Color3.fromRGB(190, 110, 255), Enum.Font.Arcade)
		c.part(Vector3.new(0.5, 0.2, 0.4), at(0.2, 1.25, 0.05) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(60, 60, 65), Enum.Material.Slate)
	end,
	-- 군번줄 인식표
	DogTag = function(c)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			c.part(Vector3.new(0.06, 0.06, 0.2), at(math.cos(a) * 0.35, 0.03, math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0), METAL, Enum.Material.Metal)
		end
		local tag = c.part(Vector3.new(0.45, 0.04, 0.3), at(0.5, 0.03, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		text(tag, Enum.NormalId.Top, "흑송", DARK)
	end,
	-- 고철: 휜 판 몇 장 + 파이프
	Scrap = function(c)
		local rust = Color3.fromRGB(120, 70, 45)
		c.part(Vector3.new(1.2, 0.08, 0.8), at(0, 0.1, 0) * CFrame.Angles(0, 0.4, math.rad(8)), rust, Enum.Material.CorrodedMetal)
		c.part(Vector3.new(0.9, 0.08, 0.6), at(0.15, 0.25, 0.1) * CFrame.Angles(0.3, -0.5, math.rad(-15)), METAL, Enum.Material.CorrodedMetal)
		c.part(Vector3.new(1.3, 0.22, 0.22), at(-0.1, 0.35, -0.2) * CFrame.Angles(0, 1.1, 0.2), Color3.fromRGB(90, 90, 95), Enum.Material.Metal, CYL)
		c.part(Vector3.new(0.3, 0.3, 0.3), at(0.4, 0.2, -0.3), rust, Enum.Material.CorrodedMetal)
	end,
	-- 장작 세 개
	Wood = function(c)
		local bark = Color3.fromRGB(90, 62, 40)
		c.part(Vector3.new(1.8, 0.5, 0.5), at(0, 0.25, -0.27), bark, Enum.Material.Wood, CYL)
		c.part(Vector3.new(1.8, 0.5, 0.5), at(0.05, 0.25, 0.27), bark, Enum.Material.Wood, CYL)
		c.part(Vector3.new(1.7, 0.48, 0.48), at(-0.05, 0.68, 0), bark:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood, CYL)
	end,
	-- 약초: 줄기 + 잎 여러 장 + 작은 흰 꽃
	Herb = function(c)
		local green = Color3.fromRGB(50, 150, 70)
		c.part(Vector3.new(0.06, 0.7, 0.06), at(0, 0.35, 0), Color3.fromRGB(60, 110, 50), Enum.Material.Grass)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			c.part(Vector3.new(0.5, 0.04, 0.22), at(math.cos(a) * 0.22, 0.15 + i * 0.1, math.sin(a) * 0.22) * CFrame.Angles(0, -a, math.rad(25)), green, Enum.Material.Grass)
		end
		for i = 0, 2 do
			c.part(Vector3.new(0.12, 0.12, 0.12), at(math.cos(i * 2.1) * 0.08, 0.75, math.sin(i * 2.1) * 0.08), Color3.fromRGB(240, 240, 220), Enum.Material.Neon, BALL)
		end
	end,
	-- 화약 상자
	Gunpowder = function(c)
		local box = c.part(Vector3.new(1, 0.7, 0.7), at(0, 0.35, 0), Color3.fromRGB(110, 80, 50), Enum.Material.WoodPlanks)
		text(box, Enum.NormalId.Front, "화약", Color3.fromRGB(190, 30, 20))
		text(box, Enum.NormalId.Back, "화약", Color3.fromRGB(190, 30, 20))
		c.part(Vector3.new(1.05, 0.1, 0.75), at(0, 0.75, 0.05) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(40, 35, 30), Enum.Material.Wood)
		c.part(Vector3.new(0.3, 0.12, 0.3), at(0.25, 0.85, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Sand) -- 흘린 가루
	end,
	-- 개어둔 천 + 둘둘 만 천
	Cloth = function(c)
		c.part(Vector3.new(1.1, 0.18, 0.8), at(0, 0.09, 0), Color3.fromRGB(190, 175, 140), Enum.Material.Fabric)
		c.part(Vector3.new(1, 0.16, 0.75), at(0.03, 0.26, 0.02) * CFrame.Angles(0, 0.15, 0), Color3.fromRGB(120, 60, 50), Enum.Material.Fabric)
		c.part(Vector3.new(0.9, 0.3, 0.3), at(0, 0.5, 0), Color3.fromRGB(220, 215, 200), Enum.Material.Fabric, CYL)
	end,
	-- 조명탄 묶음 (거의 안 쓰이지만 혹시 몰라)
	Ammo = function(c)
		for i = -1, 1 do
			c.part(Vector3.new(0.7, 0.25, 0.25), at(0, 0.13, i * 0.27), Color3.fromRGB(230, 90, 25), Enum.Material.Plastic, CYL)
		end
	end,
}

-- 아이템 모델 생성. 반환되는 모델의 PrimaryPart(Root)가 "바닥 가운데"
function ItemModels.create(itemId: string): Model
	local asset = Assets.clone("Items", itemId, ItemModels.Sizes[itemId])
	local model: Model
	if asset then
		model = asset
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		-- 바닥 가운데를 원점으로 옮김
		local cf, size = model:GetBoundingBox()
		local offset = cf.Position - Vector3.new(0, size.Y / 2, 0)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = d.CFrame - offset
			end
		end
	else
		local ctx = newCtx(itemId)
		local builder = builders[itemId]
		if builder then
			builder(ctx)
		else
			local def = Items.defs[itemId]
			ctx.part(Vector3.new(1, 1, 1), at(0, 0.5, 0), def and def.color or Color3.new(1, 1, 1))
		end
		model = ctx.model
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.CFrame = CFrame.new() -- 바닥 가운데
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	model.Name = itemId
	return model
end

return ItemModels
