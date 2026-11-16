-- 파트로 소품(나무, 오두막, 상자 등)을 만드는 도우미 함수 모음.
-- MapBuilder가 이 함수들로 맵을 조립합니다.
-- 위치는 CFrame으로 받고, 소품의 "앞"은 CFrame의 LookVector(-Z) 방향입니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)

local Build = {}

Build.rng = Random.new()

local Colors = {
	Wood = Color3.fromRGB(78, 55, 38),
	DarkWood = Color3.fromRGB(50, 36, 26),
	Plank = Color3.fromRGB(96, 70, 48),
	Roof = Color3.fromRGB(45, 42, 40),
	Metal = Color3.fromRGB(85, 85, 90),
	Rust = Color3.fromRGB(110, 60, 35),
	Stone = Color3.fromRGB(80, 82, 80),
	Leaves = Color3.fromRGB(18, 34, 22),
	Bark = Color3.fromRGB(42, 30, 22),
	Straw = Color3.fromRGB(150, 128, 78),
	Bone = Color3.fromRGB(200, 192, 172),
}
Build.Colors = Colors

local UP = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥(축이 X)을 세울 때 곱함
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
-- 장식: 부딪히지 않음 / 장식+: 부딪히지도 않고 레이(시야, 총알)도 통과
local DECOR = { CanCollide = false, CanTouch = false }
local GHOST = { CanCollide = false, CanTouch = false, CanQuery = false }

-- 기본 파트 생성. props에 Shape가 있으면 먼저 적용하고, Parent는 마지막에 넣습니다.
function Build.part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?,
	className: string?
): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props and props.Shape then
		(p :: any).Shape = props.Shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for key, value in props do
			if key ~= "Shape" then
				(p :: any)[key] = value
			end
		end
	end
	p.Parent = parent
	return p
end

function Build.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Build.light(parent: BasePart, color: Color3, range: number, brightness: number, flicker: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = true
	light.Parent = parent
	if flicker then
		parent:SetAttribute("Flicker", true) -- 클라이언트가 깜빡이게 만듦
	end
	return light
end

-- ReplicatedStorage.Assets.Props 에 같은 이름의 모델이 있으면 그걸 세움 (높이에 맞춰 크기 조절).
-- 없으면 false → 파트로 직접 만듦
local assetMissing: { [string]: boolean } = {}
local function placeAsset(parent: Instance, name: string, cf: CFrame, height: number): boolean
	if assetMissing[name] then
		return false
	end
	local model = Assets.clone("Props", name)
	if not model then
		assetMissing[name] = true
		return false
	end
	local size = model:GetExtentsSize()
	if size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
		end
	end
	local boxCf, boxSize = model:GetBoundingBox()
	local bottom = boxCf.Position - Vector3.new(0, boxSize.Y / 2, 0)
	model:PivotTo(cf * CFrame.new(model:GetPivot().Position - bottom))
	model.Parent = parent
	return true
end

---------------------------------------------------------------------------
-- 지형 (진짜 Roblox Terrain: 풀, 흙, 바위 질감이 실제처럼 보임)
---------------------------------------------------------------------------

-- 땅 표면(높이 0)에 material 을 depth 만큼 깔기. cf 의 Y 는 무시됨
function Build.ground(cf: CFrame, sizeX: number, sizeZ: number, material: Enum.Material, depth: number?)
	local d = depth or 4
	local flat = CFrame.new(cf.Position.X, -d / 2, cf.Position.Z) * (cf - cf.Position)
	Workspace.Terrain:FillBlock(flat, Vector3.new(sizeX, d, sizeZ), material)
end

-- 땅에 반쯤 묻힌 바위
function Build.boulder(pos: Vector3, radius: number, material: Enum.Material?)
	Workspace.Terrain:FillBall(Vector3.new(pos.X, radius * 0.2, pos.Z), radius, material or Enum.Material.Rock)
end

-- 표지판 글씨
function Build.text(part: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.SpecialElite
	label.TextColor3 = color or Color3.fromRGB(220, 210, 190)
	label.Parent = gui
	gui.Parent = part
end

---------------------------------------------------------------------------
-- 자연물
---------------------------------------------------------------------------

-- 소나무: 아래쪽은 맨 줄기, 위쪽은 아래로 처진 가지가 층층이 달림
-- simple = true 면 가지 수를 줄인 가벼운 버전 (숲 가장자리용)
function Build.pine(parent: Instance, x: number, z: number, scale: number, simple: boolean?)
	local rng = Build.rng
	local height = 34 * scale
	local yaw = rng:NextNumber(0, 6.28)
	if placeAsset(parent, "Pine", CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0), height) then
		return
	end
	local base = CFrame.new(x, 0, z) * CFrame.Angles(math.rad(rng:NextNumber(-2.5, 2.5)), yaw, math.rad(rng:NextNumber(-2.5, 2.5)))
	local d = 1.6 * scale + 0.8
	local bark = Colors.Bark:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
	Build.part(parent, Vector3.new(height * 0.72, d, d), base * CFrame.new(0, height * 0.36, 0) * UP, bark, Enum.Material.Wood, { Shape = CYL })
	Build.part(parent, Vector3.new(height * 0.3, d * 0.55, d * 0.55), base * CFrame.new(0, height * 0.84, 0) * UP, bark, Enum.Material.Wood, {
		Shape = CYL,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	local counts = if simple then { 5, 4, 4 } else { 6, 5, 5, 4, 4 }
	local tiers = #counts
	for i, n in counts do
		local t = (i - 1) / (tiers - 1)
		local y = height * (0.4 + 0.52 * t)
		local reach = (10 - 6.5 * t) * scale
		local thick = (2.4 - 1.1 * t) * scale
		local width = 2 * reach * math.tan(math.pi / n) * 0.7
		local turn = rng:NextNumber(0, 6.28)
		for k = 1, n do
			local a = turn + (k / n) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local droop = math.rad(rng:NextNumber(14, 30))
			local len = reach * rng:NextNumber(0.8, 1.1)
			-- 웨지: 두꺼운 쪽이 줄기, 얇은 끝이 바깥 아래를 향함
			Build.part(
				parent,
				Vector3.new(width, thick, len),
				base * CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(-droop, 0, 0) * CFrame.new(0, 0, -len / 2),
				Colors.Leaves:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.35)),
				Enum.Material.Grass,
				{ CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = not simple },
				"WedgePart"
			)
		end
	end

	-- 아래쪽 줄기에 남은 죽은 가지 몇 개
	if not simple then
		for _ = 1, rng:NextInteger(0, 3) do
			local len = rng:NextNumber(2, 5) * scale
			local at = base
				* CFrame.new(0, rng:NextNumber(height * 0.12, height * 0.36), 0)
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				* CFrame.Angles(math.rad(rng:NextNumber(-15, 25)), 0, 0)
			Build.part(parent, Vector3.new(0.35 * scale, 0.35 * scale, len), at * CFrame.new(0, 0, -len / 2 - d * 0.4), bark, Enum.Material.Wood, GHOST)
		end
	end
end

-- 가지 하나 (at 의 +Y 방향으로 뻗음)
local function limb(parent: Instance, at: CFrame, len: number, dia: number, color: Color3, collide: boolean?)
	Build.part(parent, Vector3.new(len, dia, dia), at * CFrame.new(0, len / 2, 0) * UP, color, Enum.Material.Wood, {
		Shape = CYL,
		CanCollide = collide == true,
		CanTouch = false,
	})
end

-- 말라 죽은 나무 (앙상한 가지가 갈라져 뻗은 회색 나무)
function Build.deadTree(parent: Instance, x: number, z: number, scale: number)
	local rng = Build.rng
	local height = 22 * scale
	local yaw = rng:NextNumber(0, 6.28)
	if placeAsset(parent, "DeadTree", CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0), height) then
		return
	end
	local color = Color3.fromRGB(54, 49, 45):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
	local base = CFrame.new(x, 0, z) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), yaw, math.rad(rng:NextNumber(-6, 6)))
	local d = 1.9 * scale
	limb(parent, base, height * 0.6, d, color, true)
	local top = base * CFrame.new(0, height * 0.58, 0) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
	limb(parent, top, height * 0.42, d * 0.6, color)
	for _ = 1, rng:NextInteger(3, 5) do
		local len = rng:NextNumber(6, 11) * scale
		local at = base
			* CFrame.new(0, rng:NextNumber(height * 0.4, height * 0.9), 0)
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(35, 75)))
		limb(parent, at, len, 0.6 * scale, color)
		-- 잔가지
		local twig = at * CFrame.new(0, len * rng:NextNumber(0.45, 0.75), 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(30, 65)))
		limb(parent, twig, len * rng:NextNumber(0.35, 0.6), 0.32 * scale, color)
	end
end

-- 돌 (돌무덤용. 숲의 큰 바위는 Build.boulder 로 지형에 만듦)
function Build.rock(parent: Instance, pos: Vector3, size: number)
	local rng = Build.rng
	Build.part(
		parent,
		Vector3.new(size * rng:NextNumber(0.8, 1.4), size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.8, 1.3)),
		CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Colors.Stone:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)),
		Enum.Material.Slate
	)
end

-- 덤불: 크기가 다른 공 몇 개가 뭉친 모양. 뒤에 숨으면 괴물 시야가 가려짐
function Build.bush(parent: Instance, pos: Vector3, size: number)
	local rng = Build.rng
	if placeAsset(parent, "Bush", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), size) then
		return
	end
	local color = Color3.fromRGB(20, 38, 22):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3))
	for i = 1, 3 do
		local s = size * (if i == 1 then 1 else rng:NextNumber(0.5, 0.8))
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.5, 0.5) * size, 0, rng:NextNumber(-0.5, 0.5) * size)
		Build.part(parent, Vector3.one * s, CFrame.new(pos + offset + Vector3.new(0, s * 0.28, 0)), color, Enum.Material.Grass, {
			Shape = BALL,
			CanCollide = false,
			CanTouch = false,
		})
	end
end

-- 그루터기 (베어낸 나무 밑동)
function Build.stump(parent: Instance, pos: Vector3, scale: number)
	local rng = Build.rng
	local d = rng:NextNumber(2.4, 4) * scale
	local h = rng:NextNumber(1.1, 2.4)
	if placeAsset(parent, "Stump", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), h) then
		return
	end
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	Build.part(parent, Vector3.new(h, d, d), cf * CFrame.new(0, h / 2, 0) * UP, Colors.Bark, Enum.Material.Wood, { Shape = CYL })
	-- 잘린 면 (밝은 속살)
	Build.part(parent, Vector3.new(0.12, d * 0.9, d * 0.9), cf * CFrame.new(0, h + 0.03, 0) * UP, Color3.fromRGB(118, 92, 62), Enum.Material.Wood, {
		Shape = CYL,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	-- 뿌리
	for k = 0, 2 do
		local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
		Build.part(
			parent,
			Vector3.new(d * 0.35, h * 0.6, d * 0.7),
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, h * 0.3, -d * 0.6),
			Colors.Bark,
			Enum.Material.Wood,
			GHOST,
			"WedgePart"
		)
	end
end

-- 쓰러진 통나무 (이끼가 낌)
function Build.fallenLog(parent: Instance, pos: Vector3)
	local rng = Build.rng
	local len = rng:NextNumber(12, 22)
	local d = rng:NextNumber(1.8, 3)
	local cf = CFrame.new(pos + Vector3.new(0, d / 2 - 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-3, 3)))
	Build.part(parent, Vector3.new(len, d, d), cf, Colors.Bark:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood, { Shape = CYL })
	Build.part(parent, Vector3.new(len * rng:NextNumber(0.4, 0.7), 0.25, d * 0.7), cf * CFrame.new(rng:NextNumber(-2, 2), d / 2 - 0.05, 0), Color3.fromRGB(34, 52, 30), Enum.Material.Grass, GHOST)
	-- 부러진 가지 그루
	for _ = 1, rng:NextInteger(1, 3) do
		local at = cf * CFrame.new(rng:NextNumber(-len / 2 + 1, len / 2 - 1), 0, 0) * CFrame.Angles(rng:NextNumber(-1.2, 1.2), 0, 0)
		limb(parent, at, rng:NextNumber(2, 4.5), 0.4, Colors.Bark)
	end
end

-- 바닥에 깔리는 옅은 안개 (손전등 불빛에 비쳐 보임)
function Build.fogBank(parent: Instance, pos: Vector3, radius: number)
	local holder = Build.part(parent, Vector3.new(radius * 2, 1.5, radius * 2), CFrame.new(pos + Vector3.new(0, 1.6, 0)), Color3.new(), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Name = "FogBank",
	})
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Color = ColorSequence.new(Color3.fromRGB(120, 130, 145))
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 17) })
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.88),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	fog.Lifetime = NumberRange.new(9, 14)
	fog.Rate = 2.5
	fog.Speed = NumberRange.new(0.2, 0.9)
	fog.SpreadAngle = Vector2.new(80, 80)
	fog.Rotation = NumberRange.new(0, 360)
	fog.RotSpeed = NumberRange.new(-6, 6)
	fog.Acceleration = Vector3.new(0.25, 0, 0.15)
	fog.LightInfluence = 1
	fog.LightEmission = 0
	fog.Parent = holder
end

---------------------------------------------------------------------------
-- 소품
---------------------------------------------------------------------------

function Build.crate(parent: Instance, cf: CFrame, size: number?)
	local s = size or 3
	Build.part(parent, Vector3.one * s, cf * CFrame.new(0, s / 2, 0), Colors.Plank, Enum.Material.WoodPlanks)
end

function Build.barrel(parent: Instance, cf: CFrame, color: Color3?)
	Build.part(parent, Vector3.new(4, 2.8, 2.8), cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color or Colors.Rust, Enum.Material.CorrodedMetal, {
		Shape = Enum.PartType.Cylinder,
	})
end

function Build.logPile(parent: Instance, cf: CFrame)
	for row = 0, 2 do
		for i = 0, 3 - row do
			local x = (i - (3 - row) / 2) * 2.1
			Build.part(
				parent,
				Vector3.new(12, 2, 2),
				cf * CFrame.new(x, 1 + row * 1.8, 0) * CFrame.Angles(0, math.rad(90), 0),
				Colors.Wood,
				Enum.Material.Wood,
				{ Shape = Enum.PartType.Cylinder }
			)
		end
	end
end

-- 깜빡이는 석유등 기둥 (기둥 + 팔 + 매달린 등)
function Build.lanternPost(parent: Instance, cf: CFrame)
	Build.part(parent, Vector3.new(0.55, 9, 0.55), cf * CFrame.new(0, 4.5, 0), Colors.DarkWood, Enum.Material.Wood)
	Build.part(parent, Vector3.new(0.3, 0.3, 2.2), cf * CFrame.new(0, 8.6, -0.9), Colors.DarkWood, Enum.Material.Wood, DECOR)
	Build.part(parent, Vector3.new(0.08, 0.7, 0.08), cf * CFrame.new(0, 8.2, -1.8), Colors.Metal, Enum.Material.Metal, GHOST)
	Build.part(parent, Vector3.new(0.9, 0.18, 0.9), cf * CFrame.new(0, 7.85, -1.8), Color3.fromRGB(45, 45, 48), Enum.Material.Metal, GHOST)
	Build.part(parent, Vector3.new(0.8, 0.18, 0.8), cf * CFrame.new(0, 6.75, -1.8), Color3.fromRGB(45, 45, 48), Enum.Material.Metal, GHOST)
	local lamp = Build.part(parent, Vector3.new(0.55, 0.95, 0.55), cf * CFrame.new(0, 7.3, -1.8), Color3.fromRGB(255, 170, 80), Enum.Material.Neon, GHOST)
	Build.light(lamp, Color3.fromRGB(255, 150, 70), 24, 1.3, true)
end

function Build.sign(parent: Instance, cf: CFrame, text: string)
	Build.part(parent, Vector3.new(0.5, 6, 0.5), cf * CFrame.new(0, 3, 0), Colors.DarkWood, Enum.Material.Wood)
	local board = Build.part(parent, Vector3.new(6, 2, 0.3), cf * CFrame.new(0, 5.2, 0), Colors.Plank, Enum.Material.WoodPlanks)
	Build.text(board, Enum.NormalId.Front, text)
	Build.text(board, Enum.NormalId.Back, text)
end

-- 숨을 수 있는 옷장. 숨는 위치(CFrame)를 돌려줍니다.
function Build.closet(parent: Instance, cf: CFrame): (Model, CFrame)
	local m = Build.model(parent, "Closet")
	local c = Colors.DarkWood
	local w, h, d = 4.4, 8, 3.4
	Build.part(m, Vector3.new(w, h, 0.3), cf * CFrame.new(0, h / 2, d / 2), c, Enum.Material.WoodPlanks)
	Build.part(m, Vector3.new(0.3, h, d), cf * CFrame.new(-w / 2, h / 2, 0), c, Enum.Material.WoodPlanks)
	Build.part(m, Vector3.new(0.3, h, d), cf * CFrame.new(w / 2, h / 2, 0), c, Enum.Material.WoodPlanks)
	Build.part(m, Vector3.new(w, 0.3, d), cf * CFrame.new(0, h, 0), c, Enum.Material.WoodPlanks)
	-- 문 두 짝 (사이 틈으로 밖이 보임)
	for _, side in { -1, 1 } do
		Build.part(m, Vector3.new(w / 2 - 0.25, h - 0.4, 0.2), cf * CFrame.new(side * (w / 4 + 0.12), h / 2, -d / 2), c:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood, {
			CanCollide = false,
		})
	end
	local hidePoint = cf * CFrame.new(0, 3, 0)
	local promptPart = Build.part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 4, -d / 2 - 0.3), c, nil, {
		Transparency = 1,
		CanCollide = false,
		Name = "PromptPart",
	})
	m.PrimaryPart = promptPart
	return m, hidePoint
end

-- 오두막 크기 (가로, 높이, 세로). 괴물 AI가 "건물 안/근처"를 알아낼 때 씀
Build.CabinSize = Vector3.new(20, 14, 16)

-- 오두막: 앞(-Z)에 문이 있음. 내부에 아이템 놓을 자리들을 돌려줍니다.
function Build.cabin(parent: Instance, cf: CFrame, name: string): (Model, { [string]: { Vector3 } }, CFrame, CFrame)
	local m = Build.model(parent, name)
	local w, d, h = Build.CabinSize.X, Build.CabinSize.Z, 10
	local wall = Colors.Wood
	local mat = Enum.Material.WoodPlanks
	Build.part(m, Vector3.new(w, 1, d), cf * CFrame.new(0, 0.5, 0), Colors.Plank, mat)
	-- 뒤, 좌, 우 벽 (좌우에 창문 구멍)
	Build.part(m, Vector3.new(w, h, 1), cf * CFrame.new(0, h / 2 + 1, d / 2), wall, mat)
	for _, side in { -1, 1 } do
		local x = side * (w / 2)
		Build.part(m, Vector3.new(1, h, 5), cf * CFrame.new(x, h / 2 + 1, -d / 2 + 2.5), wall, mat)
		Build.part(m, Vector3.new(1, h, 5), cf * CFrame.new(x, h / 2 + 1, d / 2 - 2.5), wall, mat)
		Build.part(m, Vector3.new(1, 4, 6), cf * CFrame.new(x, 3, 0), wall, mat)
		Build.part(m, Vector3.new(1, 2.5, 6), cf * CFrame.new(x, h - 0.25, 0), wall, mat)
	end
	-- 앞벽 + 문 구멍 (괴물이 몸을 숙이고 지나갈 수 있는 크기)
	local doorW, doorH = 6, 8
	local sideW = (w - doorW) / 2
	for _, side in { -1, 1 } do
		Build.part(m, Vector3.new(sideW, h, 1), cf * CFrame.new(side * (doorW / 2 + sideW / 2), h / 2 + 1, -d / 2), wall, mat)
	end
	Build.part(m, Vector3.new(doorW, h - doorH, 1), cf * CFrame.new(0, doorH + 1 + (h - doorH) / 2, -d / 2), wall, mat)
	-- 문턱 경사로 (괴물과 길찾기가 바닥 턱에 걸리지 않게)
	Build.part(m, Vector3.new(doorW, 1, 2.5), cf * CFrame.new(0, 0.5, -d / 2 - 1), Colors.Plank, Enum.Material.WoodPlanks, nil, "WedgePart")
	-- 반쯤 열린 문짝
	Build.part(m, Vector3.new(0.4, doorH, doorW - 0.4), cf * CFrame.new(-doorW / 2 + 0.2, 1 + doorH / 2, -d / 2 - doorW / 2 + 0.6), Colors.DarkWood, Enum.Material.Wood)
	-- 지붕 (박공)
	local roofLen = math.sqrt((w / 2) ^ 2 + 4 ^ 2) + 1.5
	local roofAngle = math.atan2(4, w / 2)
	for _, side in { -1, 1 } do
		Build.part(
			m,
			Vector3.new(roofLen, 0.8, d + 3),
			cf * CFrame.new(side * w / 4, h + 3, 0) * CFrame.Angles(0, 0, side * -roofAngle),
			Colors.Roof,
			Enum.Material.Slate
		)
	end
	-- 박공 삼각 벽 (웨지 2개)
	for _, zSide in { -1, 1 } do
		for _, side in { -1, 1 } do
			Build.part(
				m,
				Vector3.new(0.8, 4, w / 2),
				cf * CFrame.new(side * w / 4, h + 3, zSide * d / 2) * CFrame.Angles(0, side * math.rad(-90), 0),
				wall,
				mat,
				nil,
				"WedgePart"
			)
		end
	end
	-- 가구
	Build.part(m, Vector3.new(6, 0.5, 4), cf * CFrame.new(-4, 4, 3), Colors.Plank, Enum.Material.Wood) -- 탁자
	for _, x in { -6.5, -1.5 } do
		for _, z in { 1.5, 4.5 } do
			Build.part(m, Vector3.new(0.4, 3, 0.4), cf * CFrame.new(x, 2.5, z), Colors.DarkWood, Enum.Material.Wood)
		end
	end
	Build.part(m, Vector3.new(4, 1.5, 8), cf * CFrame.new(7, 1.75, 3), Color3.fromRGB(70, 60, 55), Enum.Material.Fabric) -- 침대
	Build.crate(m, cf * CFrame.new(-7, 1, -5), 2.5)

	-- 탁자 위 석유등
	Build.part(m, Vector3.new(0.7, 0.25, 0.7), cf * CFrame.new(-4, 4.38, 3), Color3.fromRGB(45, 45, 48), Enum.Material.Metal, GHOST)
	Build.part(m, Vector3.new(0.6, 0.2, 0.6), cf * CFrame.new(-4, 5.3, 3), Color3.fromRGB(45, 45, 48), Enum.Material.Metal, GHOST)
	local lamp = Build.part(m, Vector3.new(0.45, 0.75, 0.45), cf * CFrame.new(-4, 4.85, 3), Color3.fromRGB(255, 170, 80), Enum.Material.Neon, GHOST)
	Build.light(lamp, Color3.fromRGB(255, 140, 60), 18, 1, true)

	-- 창살(십자 나무살). 절반쯤은 누군가 바깥에서 판자로 막아놨음
	for _, side in { -1, 1 } do
		local x = side * (w / 2)
		Build.part(m, Vector3.new(0.3, 3.5, 0.3), cf * CFrame.new(x, 6.75, 0), Colors.DarkWood, Enum.Material.Wood, GHOST)
		Build.part(m, Vector3.new(0.3, 0.3, 6), cf * CFrame.new(x, 6.75, 0), Colors.DarkWood, Enum.Material.Wood, GHOST)
		if Build.rng:NextNumber() < 0.5 then
			for _, y in { 5.8, 7.5 } do
				Build.part(
					m,
					Vector3.new(0.25, 0.9, 6.8),
					cf * CFrame.new(x + side * 0.65, y, 0) * CFrame.Angles(math.rad(Build.rng:NextNumber(-7, 7)), 0, 0),
					Colors.Plank:Lerp(Color3.new(0, 0, 0), 0.25),
					Enum.Material.WoodPlanks,
					DECOR
				)
			end
		end
	end
	-- 굴뚝 + 무쇠 난로
	Build.part(m, Vector3.new(2.4, h + 7, 2.2), cf * CFrame.new(3.3, (h + 7) / 2, d / 2 + 1.6), Color3.fromRGB(86, 52, 44), Enum.Material.Brick)
	Build.part(m, Vector3.new(2, 2.6, 1.7), cf * CFrame.new(3.3, 2.3, d / 2 - 1.4), Color3.fromRGB(32, 32, 34), Enum.Material.CorrodedMetal)
	Build.part(m, Vector3.new(1.2, 0.9, 0.1), cf * CFrame.new(3.3, 2.1, d / 2 - 2.3), Color3.fromRGB(20, 20, 22), Enum.Material.Metal, GHOST)
	Build.part(m, Vector3.new(h - 3, 0.6, 0.6), cf * CFrame.new(3.3, 3.6 + (h - 3) / 2, d / 2 - 1.2) * UP, Color3.fromRGB(38, 38, 40), Enum.Material.CorrodedMetal, {
		Shape = CYL,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	-- 넘어진 의자, 벽 달력
	Build.part(m, Vector3.new(1.6, 0.25, 1.6), cf * CFrame.new(-1.2, 1.9, -1.5) * CFrame.Angles(0, 0.5, math.rad(78)), Colors.DarkWood, Enum.Material.Wood, GHOST)
	Build.part(m, Vector3.new(1.6, 2.6, 0.25), cf * CFrame.new(-1.9, 1.5, -1.9) * CFrame.Angles(0, 0.5, math.rad(78)), Colors.DarkWood, Enum.Material.Wood, GHOST)
	local calendar = Build.part(m, Vector3.new(1.7, 2.2, 0.06), cf * CFrame.new(-8, 6.6, d / 2 - 0.56), Color3.fromRGB(215, 205, 180), Enum.Material.Fabric, GHOST)
	Build.text(calendar, Enum.NormalId.Front, "1998\n10월", Color3.fromRGB(120, 25, 20))

	local closetCf = cf * CFrame.new(5, 1, -4) * CFrame.Angles(0, math.rad(90), 0) -- 문이 방 안쪽을 보게

	-- 뒷벽 열쇠걸이 + 작은 선반
	local board = Build.part(m, Vector3.new(2.4, 1.2, 0.2), cf * CFrame.new(-1, 6.2, d / 2 - 0.6), Colors.Plank, Enum.Material.Wood)
	Build.text(board, Enum.NormalId.Front, "열쇠", Color3.fromRGB(60, 40, 30))
	Build.part(m, Vector3.new(2.4, 0.15, 0.8), cf * CFrame.new(-1, 5.2, d / 2 - 0.9), Colors.DarkWood, Enum.Material.Wood)
	for _, x in { -1.8, -1, -0.2 } do
		Build.part(m, Vector3.new(0.1, 0.1, 0.4), cf * CFrame.new(x, 5.9, d / 2 - 0.8), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	end

	-- 바깥 앞벽의 전기함
	local fuseSpot = Build.fuseBox(m, cf * CFrame.new(-7, 4.5, -d / 2 - 0.5))

	-- 장소 이름별 아이템 자리 (높이 = 그 표면 위)
	local function P(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, z)).Position
	end
	local spots = {
		CabinTable = { P(-5.5, 4.25, 3), P(-2.5, 4.25, 4) },
		Bed = { P(7, 2.5, 5), P(7, 2.5, 1) },
		CabinFloor = { P(-7, 3.5, -5), P(1, 1, 5.5), P(-3, 1, -4) },
		KeyHook = { P(-1, 5.28, d / 2 - 0.9) },
		FuseBox = { fuseSpot },
	}
	return m, spots, closetCf, cf * CFrame.new(0, 1, -d / 2 - 3)
end

-- 벌목 트럭. 앞 = LookVector
function Build.truck(parent: Instance, cf: CFrame): (Model, Model, CFrame)
	local m = Build.model(parent, "LoggingTruck")
	local body = Color3.fromRGB(120, 30, 25)
	local root = Build.part(m, Vector3.new(7, 1.5, 22), cf * CFrame.new(0, 2.5, 0), Colors.Metal, Enum.Material.DiamondPlate, { Name = "Chassis" })
	Build.part(m, Vector3.new(7, 5, 6), cf * CFrame.new(0, 5.75, -7.5), body, Enum.Material.Metal) -- 운전석
	Build.part(m, Vector3.new(6.6, 2, 0.2), cf * CFrame.new(0, 7, -10.55), Color3.fromRGB(30, 40, 50), Enum.Material.Glass, { Transparency = 0.3 })
	Build.part(m, Vector3.new(7, 2.5, 4), cf * CFrame.new(0, 4.5, -12.5), body, Enum.Material.Metal) -- 보닛
	for _, x in { -2.6, 2.6 } do
		local light = Build.part(m, Vector3.new(1, 0.8, 0.2), cf * CFrame.new(x, 4.8, -14.55), Color3.fromRGB(60, 60, 50), Enum.Material.Glass, {
			Name = "Headlight",
		})
		local spot = Instance.new("SpotLight")
		spot.Name = "Beam"
		spot.Face = Enum.NormalId.Front
		spot.Range = 50
		spot.Angle = 50
		spot.Brightness = 4
		spot.Enabled = false
		spot.Parent = light
	end
	-- 짐칸 + 통나무
	for _, x in { -3.3, 3.3 } do
		for _, z in { -2, 4, 10 } do
			Build.part(m, Vector3.new(0.5, 5, 0.5), cf * CFrame.new(x, 5.75, z), Colors.Metal, Enum.Material.Metal)
		end
	end
	for row = 0, 1 do
		for i = -1, 1 do
			Build.part(m, Vector3.new(14, 2, 2), cf * CFrame.new(i * 2.1, 4.25 + row * 1.9, 4) * CFrame.Angles(0, math.rad(90), 0), Colors.Wood, Enum.Material.Wood, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end
	-- 바퀴
	for _, x in { -3.6, 3.6 } do
		for _, z in { -8, 4, 8 } do
			Build.part(m, Vector3.new(1.4, 3.6, 3.6), cf * CFrame.new(x, 1.8, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end
	m.PrimaryPart = root
	-- 트럭 밑 숨는 자리 (앞바퀴와 가운데 바퀴 사이)
	local hideModel, hidePoint = Build.underVehicleHide(m, cf, 1, -1.5, 0.75, 5.5)
	return m, hideModel, hidePoint
end

-- 차 밑 숨는 자리. cf = 차의 CFrame, side = 1(오른쪽)/-1(왼쪽), z = 차 길이 방향 위치
-- 엎드려서 바깥쪽을 내다보는 자세로 숨습니다. (Hiding.luau 가 사용)
function Build.underVehicleHide(parent: Instance, cf: CFrame, side: number, z: number, lieHeight: number, promptOut: number): (Model, CFrame)
	local m = Build.model(parent, "HideUnder")
	local outward = cf:VectorToWorldSpace(Vector3.new(side, 0, 0))
	local base = (cf * CFrame.new(side * 0.6, lieHeight, z)).Position
	-- 엎드림: 머리 = 바깥쪽, 얼굴 = 땅
	local hidePoint = CFrame.lookAt(base, base + outward) * CFrame.Angles(math.rad(-90), 0, 0)
	local promptPos = (cf * CFrame.new(side * promptOut, 3.5, z)).Position
	-- 프롬프트 파트의 앞(-Z)이 차 바깥쪽을 보게 → 나올 때 차 옆으로 나옴
	local promptPart = Build.part(m, Vector3.new(1, 1, 1), CFrame.lookAt(promptPos, promptPos + outward), Colors.Metal, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Name = "PromptPart",
	})
	m.PrimaryPart = promptPart
	return m, hidePoint
end

-- 버려진 자동차 껍데기 (차체를 살짝 띄워서 밑에 숨을 수 있음). 숨는 자리를 돌려줍니다.
function Build.carHulk(parent: Instance, cf: CFrame, color: Color3): (Model, CFrame)
	Build.part(parent, Vector3.new(6, 1.4, 12), cf * CFrame.new(0, 2.35, 0), color, Enum.Material.CorrodedMetal)
	Build.part(parent, Vector3.new(5.6, 2.2, 6), cf * CFrame.new(0, 4.1, 1), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.CorrodedMetal)
	for _, x in { -3, 3 } do
		for _, z in { -4, 4 } do
			Build.part(parent, Vector3.new(1, 2.4, 2.4), cf * CFrame.new(x, 1.2, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end
	return Build.underVehicleHide(parent, cf, 1, 0, 0.7, 4.5)
end

-- 나무 울타리 한 칸
function Build.fence(parent: Instance, from: Vector3, to: Vector3, height: number)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to)
	Build.part(parent, Vector3.new(1, height, len), cf * CFrame.new(0, height / 2, 0), Colors.DarkWood, Enum.Material.WoodPlanks)
	local posts = math.max(1, math.floor(len / 10))
	for i = 0, posts do
		local p = from:Lerp(to, i / posts)
		Build.part(parent, Vector3.new(1.4, height + 2, 1.4), CFrame.new(p + Vector3.new(0, (height + 2) / 2, 0)), Colors.Bark, Enum.Material.Wood)
	end
end

-- 흙길 (지형에 흙을 깖)
function Build.road(_parent: Instance?, from: Vector3, to: Vector3, width: number)
	local a = Vector3.new(from.X, 0, from.Z)
	local b = Vector3.new(to.X, 0, to.Z)
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	Build.ground(CFrame.lookAt((a + b) / 2, b), width, len + width * 0.5, Enum.Material.Ground)
end

-- 벽에 붙은 전기함 (문이 열려 있음). cf의 앞(-Z)이 바깥쪽. 안쪽 바닥 위치를 돌려줌
function Build.fuseBox(parent: Instance, cf: CFrame): Vector3
	local grey = Color3.fromRGB(95, 100, 95)
	local w, h, d = 2.2, 2.4, 1.1
	Build.part(parent, Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, 0.05), grey, Enum.Material.Metal)
	Build.part(parent, Vector3.new(0.1, h, d), cf * CFrame.new(-w / 2, 0, -d / 2), grey, Enum.Material.Metal)
	Build.part(parent, Vector3.new(0.1, h, d), cf * CFrame.new(w / 2, 0, -d / 2), grey, Enum.Material.Metal)
	Build.part(parent, Vector3.new(w, 0.1, d), cf * CFrame.new(0, h / 2, -d / 2), grey, Enum.Material.Metal)
	Build.part(parent, Vector3.new(w, 0.1, d), cf * CFrame.new(0, -h / 2, -d / 2), grey, Enum.Material.Metal)
	-- 열린 문짝 (경고 표시)
	local door = Build.part(parent, Vector3.new(w, h, 0.08), cf * CFrame.new(-w / 2, 0, -d) * CFrame.Angles(0, math.rad(-110), 0) * CFrame.new(w / 2, 0, 0), grey, Enum.Material.Metal)
	Build.text(door, Enum.NormalId.Front, "⚡ 위험", Color3.fromRGB(230, 200, 40))
	Build.text(door, Enum.NormalId.Back, "⚡ 위험", Color3.fromRGB(230, 200, 40))
	-- 안쪽 배선
	for i = -1, 1 do
		Build.part(parent, Vector3.new(0.08, h - 0.3, 0.08), cf * CFrame.new(i * 0.5, 0.1, -0.15), Color3.fromRGB(150 + i * 50, 40, 40), Enum.Material.Plastic)
	end
	return (cf * CFrame.new(0, -h / 2 + 0.05, -d / 2)).Position
end

-- 철제 선반 3단. 각 칸의 위치들을 돌려줌
function Build.shelf(parent: Instance, cf: CFrame): { Vector3 }
	local grey = Color3.fromRGB(80, 82, 85)
	local spots = {}
	for _, x in { -2.4, 2.4 } do
		for _, z in { -0.9, 0.9 } do
			Build.part(parent, Vector3.new(0.2, 7, 0.2), cf * CFrame.new(x, 3.5, z), grey, Enum.Material.Metal)
		end
	end
	for i, y in { 0.8, 3, 5.2 } do
		Build.part(parent, Vector3.new(5, 0.15, 2), cf * CFrame.new(0, y, 0), grey, Enum.Material.DiamondPlate)
		table.insert(spots, (cf * CFrame.new(-1.2, y + 0.08, 0)).Position)
		table.insert(spots, (cf * CFrame.new(1.2, y + 0.08, 0)).Position)
		-- 잡동사니
		if i ~= 2 then
			Build.part(parent, Vector3.new(0.6, 0.8, 0.6), cf * CFrame.new(2, y + 0.48, -0.4), Color3.fromRGB(120, 110, 90), Enum.Material.Cardboard)
		end
	end
	return spots
end

-- 화약 상자 (뚜껑 열림). 위 표면 위치를 돌려줌
function Build.explosivesCrate(parent: Instance, cf: CFrame): Vector3
	local box = Build.part(parent, Vector3.new(3.2, 2, 2.2), cf * CFrame.new(0, 1, 0), Color3.fromRGB(100, 75, 45), Enum.Material.WoodPlanks)
	Build.text(box, Enum.NormalId.Front, "화약 위험", Color3.fromRGB(180, 30, 20))
	Build.text(box, Enum.NormalId.Back, "화약 위험", Color3.fromRGB(180, 30, 20))
	Build.part(parent, Vector3.new(3.2, 0.2, 2.2), cf * CFrame.new(0, 2.6, 1.6) * CFrame.Angles(math.rad(-70), 0, 0), Color3.fromRGB(90, 65, 40), Enum.Material.WoodPlanks)
	return (cf * CFrame.new(0, 2, 0)).Position
end

-- 작업대 (공구가 널려 있음)
function Build.workbench(parent: Instance, cf: CFrame): { Vector3 }
	Build.part(parent, Vector3.new(6, 0.4, 2.6), cf * CFrame.new(0, 3, 0), Colors.Plank, Enum.Material.Wood)
	for _, x in { -2.7, 2.7 } do
		for _, z in { -1.1, 1.1 } do
			Build.part(parent, Vector3.new(0.3, 3, 0.3), cf * CFrame.new(x, 1.5, z), Colors.DarkWood, Enum.Material.Wood)
		end
	end
	Build.part(parent, Vector3.new(0.8, 0.2, 0.2), cf * CFrame.new(1.8, 3.3, 0.5) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(150, 30, 30), Enum.Material.Plastic) -- 망치 손잡이
	Build.part(parent, Vector3.new(0.25, 0.25, 0.5), cf * CFrame.new(2.2, 3.35, 0.7) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(120, 120, 125), Enum.Material.Metal)
	return { (cf * CFrame.new(-1.5, 3.2, 0)).Position, (cf * CFrame.new(0.5, 3.2, -0.5)).Position }
end

-- 빨랫줄 + 바구니. 바구니/바닥 위치를 돌려줌
function Build.clothesline(parent: Instance, cf: CFrame): { Vector3 }
	for _, x in { -6, 6 } do
		Build.part(parent, Vector3.new(0.4, 7, 0.4), cf * CFrame.new(x, 3.5, 0), Colors.Bark, Enum.Material.Wood)
	end
	Build.part(parent, Vector3.new(12, 0.05, 0.05), cf * CFrame.new(0, 6.6, 0), Color3.fromRGB(200, 200, 190), Enum.Material.Fabric)
	local colors = { Color3.fromRGB(150, 140, 120), Color3.fromRGB(110, 50, 45), Color3.fromRGB(70, 80, 100) }
	for i = -2, 2 do
		Build.part(parent, Vector3.new(1.6, 2.4, 0.05), cf * CFrame.new(i * 2.2, 5.4, 0) * CFrame.Angles(0, 0, math.rad(i * 3)), colors[(i % 3) + 1], Enum.Material.Fabric, { CanCollide = false })
	end
	Build.part(parent, Vector3.new(2.2, 1.2, 1.6), cf * CFrame.new(3, 0.6, 2), Color3.fromRGB(140, 110, 70), Enum.Material.Fabric)
	return { (cf * CFrame.new(3, 1.2, 2)).Position, (cf * CFrame.new(-3, 0, 1.5)).Position }
end

-- 약초 군락 (작은 덤불 + 버섯)
function Build.herbPatch(parent: Instance, pos: Vector3): Vector3
	local rng = Build.rng
	for _ = 1, 4 do
		local p = pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		Build.part(parent, Vector3.new(0.25, 0.6, 0.25), CFrame.new(p + Vector3.new(0, 0.3, 0)), Color3.fromRGB(210, 200, 180), Enum.Material.SmoothPlastic, { CanCollide = false })
		Build.part(parent, Vector3.new(0.3, 0.7, 0.7), CFrame.new(p + Vector3.new(0, 0.65, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 60, 50), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
	end
	return pos
end

-- 쓰러진 벌목꾼 시신. 인식표 놓을 자리를 돌려줌
function Build.corpse(parent: Instance, cf: CFrame): Vector3
	local m = Build.model(parent, "Corpse")
	local jacket = Color3.fromRGB(150, 70, 30)
	local pants = Color3.fromRGB(40, 45, 60)
	local skin = Color3.fromRGB(170, 160, 150)
	Build.part(m, Vector3.new(4.5, 0.05, 3.5), cf * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(60, 10, 10), Enum.Material.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
	}) -- 핏자국
	Build.part(m, Vector3.new(2, 1, 1.2), cf * CFrame.new(0, 0.55, 0), jacket, Enum.Material.Fabric) -- 몸통 (엎드림)
	Build.part(m, Vector3.new(1.1, 1.1, 1.1), cf * CFrame.new(0, 0.55, -1.25), skin, Enum.Material.SmoothPlastic)
	Build.part(m, Vector3.new(1.3, 0.5, 1.3), cf * CFrame.new(0, 1.05, -1.35), Color3.fromRGB(220, 180, 30), Enum.Material.Plastic) -- 안전모
	for _, x in { -0.5, 0.5 } do
		Build.part(m, Vector3.new(0.9, 0.9, 2.2), cf * CFrame.new(x, 0.45, 1.7) * CFrame.Angles(0, x * 0.3, 0), pants, Enum.Material.Fabric)
	end
	Build.part(m, Vector3.new(0.8, 0.8, 2), cf * CFrame.new(-1.4, 0.4, -1) * CFrame.Angles(0, 0.6, 0), jacket, Enum.Material.Fabric)
	Build.part(m, Vector3.new(0.8, 0.8, 2), cf * CFrame.new(1.5, 0.4, 0.2) * CFrame.Angles(0, -1.2, 0), jacket, Enum.Material.Fabric)
	-- 긁힌 자국
	for i = -1, 1 do
		Build.part(m, Vector3.new(0.15, 0.06, 3), cf * CFrame.new(i * 0.5 + 2.6, 0.05, -1) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(40, 10, 10), Enum.Material.SmoothPlastic, {
			CanCollide = false,
			CanQuery = false,
		})
	end
	return (cf * CFrame.new(1.6, 0.06, -2.2)).Position
end

---------------------------------------------------------------------------
-- 서낭당 / 장승 / 금줄 / 솟대 / 허수아비 (강원도 산골 느낌)
---------------------------------------------------------------------------

-- 세로로 쓴 글씨판
local function verticalText(parent: Instance, cf: CFrame, text: string, color: Color3)
	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	local board = Build.part(parent, Vector3.new(1.1, #chars * 1.1, 0.06), cf, Color3.new(), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
	Build.text(board, Enum.NormalId.Front, table.concat(chars, "\n"), color)
end

-- 장승: 얼굴을 새긴 나무 기둥. 앞 = LookVector
function Build.jangseung(parent: Instance, cf: CFrame, text: string)
	local wood = Color3.fromRGB(70, 52, 38)
	local h = 11
	Build.part(parent, Vector3.new(h, 1.7, 1.7), cf * CFrame.new(0, h / 2, 0) * UP, wood, Enum.Material.Wood, { Shape = CYL })
	Build.part(parent, Vector3.new(2.3, 0.7, 2.3), cf * CFrame.new(0, h + 0.2, 0), Colors.DarkWood, Enum.Material.Wood, DECOR) -- 갓
	Build.part(parent, Vector3.new(1.3, 1.1, 1.3), cf * CFrame.new(0, h + 1, 0), Colors.DarkWood, Enum.Material.Wood, DECOR)
	-- 부릅뜬 눈, 긴 코, 이를 드러낸 입
	for _, side in { -1, 1 } do
		Build.part(parent, Vector3.new(0.75, 0.22, 0.3), cf * CFrame.new(side * 0.42, 9.75, -0.8) * CFrame.Angles(0, 0, side * math.rad(-22)), Colors.DarkWood, Enum.Material.Wood, GHOST)
		Build.part(parent, Vector3.one * 0.5, cf * CFrame.new(side * 0.4, 9.3, -0.72), Color3.fromRGB(205, 200, 185), Enum.Material.SmoothPlastic, { Shape = BALL, CanCollide = false, CanTouch = false, CanQuery = false })
		Build.part(parent, Vector3.one * 0.22, cf * CFrame.new(side * 0.4, 9.3, -0.95), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { Shape = BALL, CanCollide = false, CanTouch = false, CanQuery = false })
	end
	Build.part(parent, Vector3.new(0.35, 1.3, 0.45), cf * CFrame.new(0, 8.75, -0.95), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood, GHOST)
	Build.part(parent, Vector3.new(1.15, 0.5, 0.2), cf * CFrame.new(0, 7.75, -0.8), Color3.fromRGB(15, 10, 8), Enum.Material.SmoothPlastic, GHOST)
	for i = -2, 2 do
		Build.part(parent, Vector3.new(0.17, 0.3, 0.1), cf * CFrame.new(i * 0.21, 7.85, -0.88), Color3.fromRGB(205, 200, 185), Enum.Material.SmoothPlastic, GHOST)
	end
	verticalText(parent, cf * CFrame.new(0, 4, -0.9), text, Color3.fromRGB(25, 18, 14))
end

-- 솟대: 긴 장대 끝에 나무 새
function Build.sotdae(parent: Instance, cf: CFrame)
	local h = Build.rng:NextNumber(13, 17)
	Build.part(parent, Vector3.new(h, 0.4, 0.4), cf * CFrame.new(0, h / 2, 0) * UP, Colors.DarkWood, Enum.Material.Wood, { Shape = CYL })
	Build.part(parent, Vector3.new(0.45, 0.5, 1.7), cf * CFrame.new(0, h + 0.2, 0) * CFrame.Angles(math.rad(8), 0, 0), Colors.Wood, Enum.Material.Wood, GHOST)
	Build.part(parent, Vector3.new(0.3, 0.9, 0.35), cf * CFrame.new(0, h + 0.75, -0.75) * CFrame.Angles(math.rad(-25), 0, 0), Colors.Wood, Enum.Material.Wood, GHOST)
	Build.part(parent, Vector3.new(0.18, 0.18, 0.6), cf * CFrame.new(0, h + 1.1, -1.15), Colors.DarkWood, Enum.Material.Wood, GHOST)
end

-- 금줄: 두 기둥 사이에 친 새끼줄 + 흰 종이. 아래로 지나갈 수 있음
function Build.geumjul(parent: Instance, from: Vector3, to: Vector3, noPosts: boolean?)
	local rng = Build.rng
	local a = Vector3.new(from.X, 6.2, from.Z)
	local b = Vector3.new(to.X, 6.2, to.Z)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	if not noPosts then
		for _, p in { from, to } do
			Build.part(parent, Vector3.new(7, 0.6, 0.6), CFrame.new(p.X, 3.5, p.Z) * UP, Colors.Bark, Enum.Material.Wood, { Shape = CYL })
		end
	end
	Build.part(parent, Vector3.new(0.14, 0.14, len), cf, Colors.Straw, Enum.Material.Fabric, GHOST)
	local n = math.max(2, math.floor(len / 1.6))
	for i = 1, n - 1 do
		local z = -len / 2 + (i / n) * len
		local hLen = rng:NextNumber(0.9, 1.6)
		local color = if i % 4 == 0 then Color3.fromRGB(120, 30, 25) else Color3.fromRGB(215, 210, 195)
		Build.part(parent, Vector3.new(0.04, hLen, 0.35), cf * CFrame.new(0, -hLen / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), color, Enum.Material.Fabric, GHOST)
	end
end

-- 허수아비(제웅): 숲에 세워둔 짚 인형. 어둠 속에서는 사람처럼 보임. antlers = true 면 나뭇가지 뿔
function Build.effigy(parent: Instance, cf: CFrame, antlers: boolean?)
	local rng = Build.rng
	local rag = Color3.fromRGB(58, 52, 46)
	Build.part(parent, Vector3.new(0.4, 8.4, 0.4), cf * CFrame.new(0, 4.2, 0), Colors.DarkWood, Enum.Material.Wood)
	Build.part(parent, Vector3.new(5.4, 0.35, 0.35), cf * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Colors.DarkWood, Enum.Material.Wood, DECOR)
	Build.part(parent, Vector3.new(1.6, 2.8, 1), cf * CFrame.new(0, 5.1, 0), Colors.Straw:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric, DECOR)
	Build.part(parent, Vector3.one * 1.35, cf * CFrame.new(0, 7.6, 0), Colors.Straw:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric, { Shape = BALL, CanCollide = false, CanTouch = false })
	-- 팔과 몸에 걸친 넝마
	for _, x in { -2.2, -1.2, 1.3, 2.3 } do
		local len = rng:NextNumber(1.2, 2.6)
		Build.part(parent, Vector3.new(0.7, len, 0.06), cf * CFrame.new(x, 6.2 - len / 2, 0) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), rag, Enum.Material.Fabric, GHOST)
	end
	Build.part(parent, Vector3.new(1.9, 2.4, 0.08), cf * CFrame.new(0, 3.2, -0.3) * CFrame.Angles(math.rad(6), 0, 0), rag, Enum.Material.Fabric, GHOST)
	if antlers then
		for _, side in { -1, 1 } do
			local beam = cf * CFrame.new(side * 0.4, 8.1, 0) * CFrame.Angles(0, 0, math.rad(side * -28))
			limb(parent, beam, 2.6, 0.16, Colors.Bone)
			limb(parent, beam * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(side * -45)), 1.2, 0.12, Colors.Bone)
			limb(parent, beam * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(side * 40)), 0.9, 0.1, Colors.Bone)
		end
	else
		-- 벌목꾼 안전모
		Build.part(parent, Vector3.new(1.5, 0.55, 1.5), cf * CFrame.new(0, 8.25, 0), Color3.fromRGB(175, 145, 35), Enum.Material.Plastic, GHOST)
	end
end

-- 서낭당: 앞이 트인 작은 당집. 앞 = LookVector. 제물상 위 자리들과 쪽지 자리를 돌려줌
Build.ShrineSize = Vector3.new(12, 9, 10)
function Build.shrine(parent: Instance, cf: CFrame): ({ Vector3 }, Vector3)
	local m = Build.model(parent, "Shrine")
	local red = Color3.fromRGB(104, 42, 36)
	local w, d, h = 12, 10, 7.5
	Build.part(m, Vector3.new(w + 2, 0.6, d + 2), cf * CFrame.new(0, 0.3, 0), Colors.Stone, Enum.Material.Slate)
	Build.part(m, Vector3.new(w + 2, 0.6, 2.5), cf * CFrame.new(0, 0.3, -d / 2 - 2), Colors.Stone, Enum.Material.Slate, nil, "WedgePart") -- 앞 경사
	Build.part(m, Vector3.new(w, h, 0.8), cf * CFrame.new(0, 0.6 + h / 2, d / 2 - 0.4), red, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		Build.part(m, Vector3.new(0.8, h, d), cf * CFrame.new(side * (w / 2 - 0.4), 0.6 + h / 2, 0), red, Enum.Material.WoodPlanks)
		Build.part(m, Vector3.new(0.9, h, 0.9), cf * CFrame.new(side * (w / 2 - 0.45), 0.6 + h / 2, -d / 2 + 0.45), Colors.DarkWood, Enum.Material.Wood)
	end
	-- 기와지붕 (양쪽 경사 + 용마루)
	local roofLen = math.sqrt((w / 2 + 1.5) ^ 2 + 3 ^ 2)
	local roofAngle = math.atan2(3, w / 2 + 1.5)
	for _, side in { -1, 1 } do
		Build.part(m, Vector3.new(roofLen, 0.7, d + 3.5), cf * CFrame.new(side * (w / 4 + 0.75), 0.6 + h + 1.6, 0) * CFrame.Angles(0, 0, side * -roofAngle), Color3.fromRGB(38, 38, 42), Enum.Material.Slate)
	end
	Build.part(m, Vector3.new(0.9, 0.9, d + 4), cf * CFrame.new(0, 0.6 + h + 3.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Slate, DECOR)
	for _, zSide in { -1, 1 } do
		for _, side in { -1, 1 } do
			Build.part(m, Vector3.new(0.6, 3, w / 2), cf * CFrame.new(side * w / 4, 0.6 + h + 1.5, zSide * (d / 2 - 0.4)) * CFrame.Angles(0, side * math.rad(-90), 0), red, Enum.Material.WoodPlanks, DECOR, "WedgePart")
		end
	end
	-- 제물상 + 촛불 + 산신도
	local tableTop = Build.part(m, Vector3.new(5.5, 0.5, 2.4), cf * CFrame.new(0, 3.1, d / 2 - 2.4), Color3.fromRGB(70, 70, 72), Enum.Material.Slate)
	for _, x in { -2.2, 2.2 } do
		Build.part(m, Vector3.new(0.7, 2.5, 2), cf * CFrame.new(x, 1.85, d / 2 - 2.4), Color3.fromRGB(64, 64, 66), Enum.Material.Slate)
		local candle = Build.part(m, Vector3.new(0.3, 0.9, 0.3), tableTop.CFrame * CFrame.new(x, 0.7, 0.5), Color3.fromRGB(255, 190, 110), Enum.Material.Neon, GHOST)
		Build.light(candle, Color3.fromRGB(255, 150, 80), 14, 1, true)
	end
	Build.part(m, Vector3.new(1.3, 0.35, 1.3), tableTop.CFrame * CFrame.new(0, 0.42, 0.3), Color3.fromRGB(150, 140, 120), Enum.Material.Slate, { Shape = CYL, CanCollide = false, CanTouch = false, CanQuery = false })
	local painting = Build.part(m, Vector3.new(3.2, 3.8, 0.08), cf * CFrame.new(0, 6, d / 2 - 0.86), Color3.fromRGB(196, 180, 140), Enum.Material.Fabric, GHOST)
	Build.text(painting, Enum.NormalId.Front, "山\n神", Color3.fromRGB(70, 20, 15))
	-- 처마에 매단 오색천
	local cloths = { Color3.fromRGB(60, 80, 120), Color3.fromRGB(200, 195, 180), Color3.fromRGB(130, 40, 35), Color3.fromRGB(30, 30, 32), Color3.fromRGB(170, 150, 60) }
	for i = 1, 9 do
		local len = Build.rng:NextNumber(2, 3.6)
		Build.part(m, Vector3.new(0.5, len, 0.05), cf * CFrame.new(-w / 2 + i * (w / 10), 0.6 + h - len / 2, -d / 2 - 0.4) * CFrame.Angles(0, Build.rng:NextNumber(-0.4, 0.4), 0), cloths[(i % #cloths) + 1], Enum.Material.Fabric, GHOST)
	end
	local top = tableTop.CFrame
	local spots = { (top * CFrame.new(-1.4, 0.25, -0.5)).Position, (top * CFrame.new(1.4, 0.25, -0.5)).Position, (cf * CFrame.new(3.5, 0.6, 1)).Position }
	return spots, (cf * CFrame.new(-3.2, 0.6, -1)).Position
end

return Build
