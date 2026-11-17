-- 대기실 = 수색대 야영지. 숲 입구의 공터에 모닥불을 피워 놓고 출발을 기다리는 곳이에요.
-- 숲과 멀리 떨어진 하늘 위(ORIGIN)에 지어서 괴물/숲과 섞이지 않아요.
--
--              (어두운 숲길 · 장승 · 금줄)
--                        |
--        [천막2]                  [천막3]
--   [천막1]                            [천막4]     <- 천막 안에 들어서면 그 조에 들어간 것
--
--    게시판          (모닥불)           보급품
--                   통나무 의자
--
--                    (시작 지점)
--
-- 만드는 방법: 먼저 (0, 0, 0) 둘레에 평지인 것처럼 짓고, 마지막에 통째로 ORIGIN 으로 옮깁니다.
-- 그래서 Build 의 나무/장승/등불 함수를 숲과 똑같이 쓸 수 있어요. (북쪽 = -Z)

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Build = require(script.Parent.Build)

local C = Build.Colors
local LobbyBuilder = {}

export type RoomInfo = {
	index: number,
	center: CFrame, -- 천막 바닥 한가운데 (바닥 높이). 앞(LookVector) = 모닥불 쪽
	halfSize: Vector3, -- 이 상자 안에 있으면 천막 안에 있는 것
	outside: CFrame, -- 천막이 꽉 찼을 때 밀어낼 위치 (천막 앞)
	lamp: PointLight, -- 천막 등불 (사람이 있으면 밝아짐)
}

export type LobbyInfo = {
	spawn: CFrame,
	rooms: { RoomInfo },
}

local ORIGIN = Vector3.new(0, 300, 1600) -- 숲(가운데 0,0 / 한 변 640)과 멀리 떨어진 곳
local RADIUS = 96 -- 공터 + 둘러싼 숲의 반지름
local WALL_RADIUS = 74 -- 이 밖으로는 못 나감 (보이지 않는 벽)
local TENT_RADIUS = 46 -- 모닥불에서 천막까지 거리
local TENT_W, TENT_D, TENT_H = 20, 18, 11 -- 천막 너비 / 깊이 / 높이

local UP = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥(축이 X)을 세울 때 곱함
local CYL = Enum.PartType.Cylinder
local GHOST = { CanCollide = false, CanTouch = false, CanQuery = false }

-- 천막마다 다른 깃발 색 (어두운 숲에 어울리게 탁한 색)
local TENT_COLORS = {
	Color3.fromRGB(150, 52, 44), -- 빨강
	Color3.fromRGB(52, 84, 140), -- 파랑
	Color3.fromRGB(58, 112, 66), -- 초록
	Color3.fromRGB(172, 140, 52), -- 노랑
	Color3.fromRGB(120, 70, 150),
	Color3.fromRGB(170, 96, 44),
}
local CANVAS = Color3.fromRGB(76, 80, 60)

-- 안내판 글씨 (클라이언트가 언어에 맞춰 내용을 채움)
local function signLabel(part: BasePart, text: string): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.25 -- 어두워도 읽을 수 있게
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.RichText = true
	label.Font = Enum.Font.SpecialElite
	label.TextColor3 = Color3.fromRGB(235, 222, 196)
	label.Parent = gui
	return label
end

-- 모닥불: 돌 두른 자리 + 세워 쌓은 장작 + 불 + 불티
local function campfire(parent: Instance)
	for k = 1, 11 do
		local a = k / 11 * math.pi * 2
		Build.rock(parent, Vector3.new(math.cos(a) * 3.6, 0.4, math.sin(a) * 3.6), 1.5)
	end
	Build.part(parent, Vector3.new(0.3, 6.4, 6.4), CFrame.new(0, 0.15, 0) * UP, Color3.fromRGB(26, 22, 20), Enum.Material.Slate, { Shape = CYL, CanCollide = false })
	-- 원뿔 모양으로 기대 세운 장작
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + 0.3
		Build.part(
			parent,
			Vector3.new(4.6, 0.7, 0.7),
			CFrame.new(math.cos(a) * 1.1, 1.7, math.sin(a) * 1.1) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(118)), -- 위쪽 끝이 가운데로 모임
			C.Bark:Lerp(Color3.new(0, 0, 0), 0.35),
			Enum.Material.Wood,
			{ Shape = CYL, CanCollide = false }
		)
	end
	local embers = Build.part(parent, Vector3.new(2.6, 0.7, 2.6), CFrame.new(0, 0.6, 0), Color3.fromRGB(230, 80, 25), Enum.Material.Neon, GHOST)
	embers.Name = "Campfire"
	local light = Build.light(embers, Color3.fromRGB(255, 138, 58), 60, 2.6, true)
	light.Shadows = true
	local fire = Instance.new("Fire")
	fire.Size = 9
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 130, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = embers
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(60, 60, 64)
	smoke.Opacity = 0.12
	smoke.Size = 3
	smoke.RiseVelocity = 7
	smoke.Parent = embers
	-- 위로 날아오르는 불티
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(1.4, 3)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Acceleration = Vector3.new(0, 2.5, 0)
	sparks.Drag = 0.6
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.04) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 80, 20))
	sparks.LightEmission = 1
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = embers
	-- 둘러앉는 통나무 의자
	for k = 0, 4 do
		local a = math.rad(35 + k * 72)
		Build.part(parent, Vector3.new(7.5, 1.7, 1.7), CFrame.new(math.cos(a) * 11.5, 0.75, math.sin(a) * 11.5) * CFrame.Angles(0, -a + math.rad(90), 0), C.Bark, Enum.Material.Wood, { Shape = CYL })
	end
end

-- A자 군용 천막. cf = 바닥 한가운데, 앞(LookVector) = 입구. 등불(PointLight)을 돌려줌
local function tent(parent: Instance, cf: CFrame, color: Color3): PointLight
	local halfW = TENT_W / 2
	local slope = math.sqrt(halfW * halfW + TENT_H * TENT_H)
	local angle = math.atan2(TENT_H, halfW)
	for _, side in { -1, 1 } do
		-- 비스듬한 천 (양쪽)
		local lean = cf * CFrame.new(side * halfW / 2, TENT_H / 2, 0) * CFrame.Angles(0, 0, -side * angle)
		Build.part(parent, Vector3.new(slope, 0.3, TENT_D), lean, CANVAS, Enum.Material.Fabric)
		-- 입구 쪽 버팀목
		Build.part(parent, Vector3.new(slope + 1, 0.5, 0.5), lean * CFrame.new(0, 0, -TENT_D / 2 - 0.2), C.DarkWood, Enum.Material.Wood, GHOST)
		-- 뒤쪽 막힌 면 (세모 두 장)
		Build.part(
			parent,
			Vector3.new(0.3, TENT_H, halfW),
			cf * CFrame.new(side * halfW / 2, TENT_H / 2, TENT_D / 2) * CFrame.Angles(0, -side * math.rad(90), 0),
			CANVAS:Lerp(Color3.new(0, 0, 0), 0.15),
			Enum.Material.Fabric,
			nil,
			"WedgePart"
		)
		-- 팽팽하게 당긴 줄과 말뚝
		Build.part(parent, Vector3.new(0.5, 1.2, 0.5), cf * CFrame.new(side * (halfW + 3), 0.5, -TENT_D / 2 + 1) * CFrame.Angles(0, 0, side * math.rad(20)), C.DarkWood, Enum.Material.Wood, GHOST)
	end
	-- 용마루 장대
	Build.part(parent, Vector3.new(0.5, 0.5, TENT_D + 2), cf * CFrame.new(0, TENT_H, 0), C.DarkWood, Enum.Material.Wood, GHOST)
	-- 바닥 깔개 (이 위가 "천막 안")
	local pad = Build.part(parent, Vector3.new(TENT_W - 3, 0.2, TENT_D - 1), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(52, 48, 42):Lerp(color, 0.25), Enum.Material.Fabric, GHOST)
	pad.Name = "Pad"
	-- 입구 위 깃발 (조 색깔)
	Build.part(parent, Vector3.new(3.2, 2, 0.08), cf * CFrame.new(0, TENT_H - 1.6, -TENT_D / 2 - 0.5), color, Enum.Material.Fabric, GHOST)
	-- 안쪽 침낭과 상자
	Build.part(parent, Vector3.new(2.4, 0.5, 6), cf * CFrame.new(-4.5, 0.4, 4), Color3.fromRGB(48, 62, 50), Enum.Material.Fabric, GHOST)
	Build.part(parent, Vector3.new(2.4, 0.5, 6), cf * CFrame.new(4.5, 0.4, 4), Color3.fromRGB(64, 52, 44), Enum.Material.Fabric, GHOST)
	Build.crate(parent, cf * CFrame.new(0, 0, TENT_D / 2 - 2.2), 2.4)
	-- 용마루에 매단 등불
	Build.part(parent, Vector3.new(0.08, 1.4, 0.08), cf * CFrame.new(0, TENT_H - 0.9, -2), C.Metal, Enum.Material.Metal, GHOST)
	local lantern = Build.part(parent, Vector3.new(0.7, 1, 0.7), cf * CFrame.new(0, TENT_H - 2.1, -2), Color3.fromRGB(255, 176, 90), Enum.Material.Neon, GHOST)
	lantern.Name = "Lantern"
	local light = Build.light(lantern, Color3.fromRGB(255, 160, 80):Lerp(color, 0.2), 26, 0.9)
	light.Shadows = false
	return light
end

-- 나무를 심으면 안 되는 자리인지
local function isClear(pos: Vector3, clearings: { { Vector3 | number } }): boolean
	for _, c in clearings do
		if (pos - (c[1] :: Vector3)).Magnitude < (c[2] :: number) then
			return false
		end
	end
	return true
end

function LobbyBuilder.build(): LobbyInfo
	local old = Workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local rng = Build.rng

	-----------------------------------------------------------------------
	-- 땅
	-----------------------------------------------------------------------
	Build.part(folder, Vector3.new(6, RADIUS * 2, RADIUS * 2), CFrame.new(0, -3, 0) * UP, Color3.fromRGB(28, 40, 27), Enum.Material.Grass, { Shape = CYL, Name = "Ground" })
	-- 밟아 다져진 흙바닥 (모닥불 둘레, 숲길)
	Build.part(folder, Vector3.new(0.2, 56, 56), CFrame.new(0, 0, 0) * UP, Color3.fromRGB(58, 48, 38), Enum.Material.Ground, { Shape = CYL, CanCollide = false, CanQuery = false })
	Build.part(folder, Vector3.new(11, 0.2, 70), CFrame.new(0, 0.02, -60), Color3.fromRGB(54, 45, 36), Enum.Material.Ground, GHOST)
	Build.part(folder, Vector3.new(9, 0.2, 26), CFrame.new(0, 0.02, 38), Color3.fromRGB(54, 45, 36), Enum.Material.Ground, GHOST)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 70)
		local d = rng:NextNumber(10, 22)
		Build.part(folder, Vector3.new(0.2, d, d), CFrame.new(math.cos(a) * r, -0.02, math.sin(a) * r) * UP, Color3.fromRGB(40, 36, 28), Enum.Material.LeafyGrass, { Shape = CYL, CanCollide = false, CanQuery = false })
	end

	-- 보이지 않는 벽 (숲 속으로는 못 들어감)
	local segments = 28
	local segLen = 2 * WALL_RADIUS * math.tan(math.pi / segments) + 1
	for k = 1, segments do
		local a = k / segments * math.pi * 2
		local pos = Vector3.new(math.cos(a) * WALL_RADIUS, 40, math.sin(a) * WALL_RADIUS)
		Build.part(folder, Vector3.new(segLen, 86, 2), CFrame.lookAt(pos, Vector3.new(0, 40, 0)), Color3.new(), nil, { Transparency = 1, Name = "Boundary", CanQuery = false })
	end

	local clearings: { { Vector3 | number } } = { { Vector3.zero, 30 } }

	-----------------------------------------------------------------------
	-- 모닥불
	-----------------------------------------------------------------------
	campfire(folder)

	-----------------------------------------------------------------------
	-- 천막
	-----------------------------------------------------------------------
	local count = Config.Lobby.RoomCount
	local rooms: { RoomInfo } = {}
	local shift = CFrame.new(ORIGIN)
	-- 북쪽 숲길을 가운데 두고 좌우로 부채꼴처럼 늘어섬
	local spread = math.rad(42)
	for i = 1, count do
		local angle = (i - (count + 1) / 2) * spread
		local pos = Vector3.new(math.sin(angle) * TENT_RADIUS, 0, -math.cos(angle) * TENT_RADIUS)
		local cf = CFrame.lookAt(pos, Vector3.zero)
		local color = TENT_COLORS[(i - 1) % #TENT_COLORS + 1]
		local model = Instance.new("Model")
		model.Name = "Tent" .. i
		model.Parent = folder
		local lamp = tent(model, cf, color)
		table.insert(clearings, { pos, 17 })

		-- 천막 앞 안내판 (모닥불 쪽을 바라봄)
		local postCf = cf * CFrame.new(TENT_W / 2 + 2.5, 0, -TENT_D / 2 - 2)
		Build.part(model, Vector3.new(0.5, 6.5, 0.5), postCf * CFrame.new(0, 3.25, 0), C.DarkWood, Enum.Material.Wood)
		local board = Build.part(model, Vector3.new(7.5, 4.2, 0.3), postCf * CFrame.new(0, 6.6, -0.1), Color3.fromRGB(34, 27, 21), Enum.Material.WoodPlanks)
		board.Name = "Sign"
		Build.part(model, Vector3.new(7.9, 0.35, 0.4), postCf * CFrame.new(0, 8.85, -0.1), color, Enum.Material.Wood, GHOST)
		signLabel(board, tostring(i))

		table.insert(rooms, {
			index = i,
			center = shift * cf,
			halfSize = Vector3.new(TENT_W / 2 - 1.5, 40, TENT_D / 2 - 0.5),
			outside = shift * cf * CFrame.new(0, 3, -TENT_D / 2 - 8),
			lamp = lamp,
		})
	end

	-----------------------------------------------------------------------
	-- 북쪽 숲길: 장승 한 쌍과 금줄. 그 너머는 어둠
	-----------------------------------------------------------------------
	local folk = Instance.new("Folder")
	folk.Name = "Trail"
	folk.Parent = folder
	Build.jangseung(folk, CFrame.lookAt(Vector3.new(-8, 0, -62), Vector3.new(-3, 0, 0)), "天下大將軍")
	Build.jangseung(folk, CFrame.lookAt(Vector3.new(8, 0, -62), Vector3.new(3, 0, 0)), "地下女將軍")
	Build.geumjul(folk, Vector3.new(-8, 0, -66), Vector3.new(8, 0, -66))
	Build.sign(folk, CFrame.lookAt(Vector3.new(6.5, 0, -72.5), Vector3.new(0, 0, 0)), "흑송 벌목장  ↑")
	-- 숲길 저 안쪽, 안개 속에 서 있는 것 (가까이 갈 수 없음)
	Build.effigy(folk, CFrame.lookAt(Vector3.new(2, 0, -88), Vector3.new(0, 0, 0)), true)
	table.insert(clearings, { Vector3.new(0, 0, -62), 12 })
	table.insert(clearings, { Vector3.new(0, 0, -84), 9 })

	-----------------------------------------------------------------------
	-- 야영지 소품
	-----------------------------------------------------------------------
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	-- 석유등 기둥
	for _, p in { Vector3.new(-20, 0, 14), Vector3.new(20, 0, 14), Vector3.new(-9, 0, -30), Vector3.new(9, 0, -30) } do
		Build.lanternPost(props, CFrame.lookAt(p, Vector3.zero))
	end
	-- 보급품 (동쪽)
	Build.logPile(props, CFrame.new(34, 0, 22) * CFrame.Angles(0, math.rad(70), 0))
	Build.crate(props, CFrame.new(27, 0, 12) * CFrame.Angles(0, 0.4, 0), 3)
	Build.crate(props, CFrame.new(30.5, 0, 10.5) * CFrame.Angles(0, 1.1, 0), 2.4)
	Build.crate(props, CFrame.new(27.6, 3, 12.2) * CFrame.Angles(0, 0.9, 0), 2)
	Build.barrel(props, CFrame.new(31, 0, 15) * CFrame.Angles(math.rad(90), 0, 0))
	Build.barrel(props, CFrame.new(24, 0, 17) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(60, 70, 58))
	table.insert(clearings, { Vector3.new(31, 0, 17), 12 })
	-- 게시판 (서쪽): 수색대 수칙
	local noticeCf = CFrame.lookAt(Vector3.new(-30, 0, 14), Vector3.new(0, 0, 4))
	for _, x in { -4.4, 4.4 } do
		Build.part(props, Vector3.new(0.6, 8, 0.6), noticeCf * CFrame.new(x, 4, 0), C.DarkWood, Enum.Material.Wood)
	end
	Build.part(props, Vector3.new(10, 0.5, 1.6), noticeCf * CFrame.new(0, 8.2, 0) * CFrame.Angles(math.rad(8), 0, 0), C.Roof, Enum.Material.Wood, GHOST)
	local notice = Build.part(props, Vector3.new(8.4, 5, 0.3), noticeCf * CFrame.new(0, 5.2, 0), Color3.fromRGB(34, 27, 21), Enum.Material.WoodPlanks)
	notice.Name = "Notice"
	signLabel(notice, "")
	table.insert(clearings, { Vector3.new(-30, 0, 14), 9 })
	-- 그루터기, 쓰러진 통나무, 덤불
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(30, 66)
		if isClear(pos, clearings) then
			Build.stump(props, pos, rng:NextNumber(0.8, 1.2))
		end
	end
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(50, 68)
		if isClear(pos, clearings) then
			Build.fallenLog(props, pos)
		end
	end
	for _ = 1, 34 do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(34, 80)
		if isClear(pos, clearings) then
			Build.bush(props, pos, rng:NextNumber(2.5, 5))
		end
	end

	-----------------------------------------------------------------------
	-- 둘러싼 숲 (공터 가장자리부터 빽빽하게)
	-----------------------------------------------------------------------
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	local placed: { Vector3 } = {}
	for _ = 1, 400 do
		if #placed >= 72 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(56, RADIUS - 4)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = isClear(pos, clearings) and math.abs(pos.X) > 7 -- 북쪽 숲길과 남쪽 길은 비워 둠
		if ok then
			for _, other in placed do
				if (other - pos).Magnitude < 9 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(placed, pos)
			if rng:NextNumber() < 0.14 then
				Build.deadTree(trees, pos.X, pos.Z, rng:NextNumber(0.9, 1.3))
			else
				Build.pine(trees, pos.X, pos.Z, rng:NextNumber(0.85, 1.35), r > WALL_RADIUS)
			end
		end
	end

	-----------------------------------------------------------------------
	-- 다 지었으면 통째로 하늘 위 제자리로 옮김
	-----------------------------------------------------------------------
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = shift * d.CFrame
		end
	end

	-- 시작 지점: 모닥불 남쪽에서 불과 천막을 바라봄
	local spawnPos = ORIGIN + Vector3.new(0, 3, 24)
	local spawn = CFrame.lookAt(spawnPos, ORIGIN + Vector3.new(0, 3, 0))

	folder.Parent = Workspace
	return {
		spawn = spawn,
		rooms = rooms,
	}
end

return LobbyBuilder
