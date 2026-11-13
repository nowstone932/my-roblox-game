-- 파트로 소품(나무, 오두막, 상자 등)을 만드는 도우미 함수 모음.
-- MapBuilder가 이 함수들로 맵을 조립합니다.
-- 위치는 CFrame으로 받고, 소품의 "앞"은 CFrame의 LookVector(-Z) 방향입니다.

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
}
Build.Colors = Colors

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

-- 각진 소나무: 줄기 + 웨지 4개로 만든 피라미드 2~3단
function Build.pine(parent: Instance, x: number, z: number, scale: number)
	local rng = Build.rng
	local height = 26 * scale
	local trunkW = 2.4 * scale
	Build.part(parent, Vector3.new(trunkW, height, trunkW), CFrame.new(x, height / 2, z), Colors.Bark, Enum.Material.Wood)

	local tiers = 3
	for i = 1, tiers do
		local w = (16 - i * 3.5) * scale
		local h = 9 * scale
		local y = height * 0.35 + (i - 1) * h * 0.7 + h / 2
		local center = Vector3.new(x, y, z)
		local turn = rng:NextNumber(0, math.pi / 2)
		for k = 0, 3 do
			local angle = turn + k * math.pi / 2
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local pos = center + dir * (w / 4)
			Build.part(
				parent,
				Vector3.new(w, h, w / 2),
				CFrame.lookAt(pos, pos + dir),
				Colors.Leaves:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)),
				Enum.Material.Grass,
				{ CanCollide = false, CastShadow = true },
				"WedgePart"
			)
		end
	end
end

-- 말라 죽은 나무 (가지가 뻗은 회색 나무)
function Build.deadTree(parent: Instance, x: number, z: number, scale: number)
	local rng = Build.rng
	local height = 22 * scale
	local color = Color3.fromRGB(58, 52, 48)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-6, 6)))
	local base = CFrame.new(x, 0, z) * lean
	Build.part(parent, Vector3.new(2 * scale, height, 2 * scale), base * CFrame.new(0, height / 2, 0), color, Enum.Material.Wood)
	for _ = 1, rng:NextInteger(2, 4) do
		local len = rng:NextNumber(6, 11) * scale
		local at = base
			* CFrame.new(0, rng:NextNumber(height * 0.45, height * 0.9), 0)
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(35, 70)))
		Build.part(parent, Vector3.new(0.7 * scale, len, 0.7 * scale), at * CFrame.new(0, len / 2, 0), color, Enum.Material.Wood, { CanCollide = false })
	end
end

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

function Build.bush(parent: Instance, pos: Vector3, size: number)
	Build.part(parent, Vector3.one * size, CFrame.new(pos + Vector3.new(0, size * 0.3, 0)), Color3.fromRGB(20, 40, 22), Enum.Material.Grass, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
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

-- 깜빡이는 랜턴 기둥
function Build.lanternPost(parent: Instance, cf: CFrame)
	Build.part(parent, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(0, 4, 0), Colors.DarkWood, Enum.Material.Wood)
	local lamp = Build.part(parent, Vector3.new(1, 1.4, 1), cf * CFrame.new(0, 8.4, 0), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
	Build.light(lamp, Color3.fromRGB(255, 150, 70), 22, 1.4, true)
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

-- 오두막: 앞(-Z)에 문이 있음. 내부에 아이템 놓을 자리들을 돌려줍니다.
function Build.cabin(parent: Instance, cf: CFrame, name: string): (Model, { [string]: { Vector3 } }, CFrame, CFrame)
	local m = Build.model(parent, name)
	local w, d, h = 20, 16, 10
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
	-- 앞벽 + 문 구멍
	local doorW, doorH = 5, 7.5
	local sideW = (w - doorW) / 2
	for _, side in { -1, 1 } do
		Build.part(m, Vector3.new(sideW, h, 1), cf * CFrame.new(side * (doorW / 2 + sideW / 2), h / 2 + 1, -d / 2), wall, mat)
	end
	Build.part(m, Vector3.new(doorW, h - doorH, 1), cf * CFrame.new(0, doorH + 1 + (h - doorH) / 2, -d / 2), wall, mat)
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

	local lamp = Build.part(m, Vector3.new(0.8, 1, 0.8), cf * CFrame.new(-4, 4.75, 3), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
	Build.light(lamp, Color3.fromRGB(255, 140, 60), 16, 1, true)

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
function Build.truck(parent: Instance, cf: CFrame): Model
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
	return m
end

-- 버려진 자동차 껍데기
function Build.carHulk(parent: Instance, cf: CFrame, color: Color3)
	Build.part(parent, Vector3.new(6, 2.5, 12), cf * CFrame.new(0, 1.8, 0), color, Enum.Material.CorrodedMetal)
	Build.part(parent, Vector3.new(5.6, 2.2, 6), cf * CFrame.new(0, 4.1, 1), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.CorrodedMetal)
	for _, x in { -3, 3 } do
		for _, z in { -4, 4 } do
			Build.part(parent, Vector3.new(1, 2.4, 2.4), cf * CFrame.new(x, 1.2, z), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end
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

-- 흙길
function Build.road(parent: Instance, from: Vector3, to: Vector3, width: number)
	local a = Vector3.new(from.X, 0.06, from.Z)
	local b = Vector3.new(to.X, 0.06, to.Z)
	local len = (b - a).Magnitude
	Build.part(parent, Vector3.new(width, 0.12, len + width * 0.5), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(62, 48, 36), Enum.Material.Ground, {
		CanCollide = false,
		CanQuery = false,
	})
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

return Build
