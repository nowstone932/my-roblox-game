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
function Build.cabin(parent: Instance, cf: CFrame, name: string): (Model, { Vector3 }, CFrame, CFrame)
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
	local spots = {
		(cf * CFrame.new(-4, 4.8, 4)).Position, -- 탁자 위
		(cf * CFrame.new(7, 3, 5)).Position, -- 침대 위
		(cf * CFrame.new(-7, 4, -5)).Position, -- 상자 위
		(cf * CFrame.new(0, 1.6, 5)).Position, -- 바닥
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

return Build
