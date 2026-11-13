-- 흑송 벌목장 맵을 코드로 조립합니다. (북쪽 = -Z)
--
--                 [정문]  [발전기 오두막]
--                    |
--   [헬기장]         |              [제단 + 돌무덤]
--      |             |
--   [감시탑] ---- [벌목 캠프 / 제재소 / 트럭] ---- [폐주유소 + 고물장]
--                    |
--                    |
--               [고장난 차 = 시작]
--
-- Studio에서 직접 꾸미고 싶으면 Workspace.BlackpineForest 안을 수정해도 되지만,
-- 게임을 시작할 때마다 다시 만들어지므로 이 파일을 고쳐야 영구적으로 바뀝니다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local C = Build.Colors
local MapBuilder = {}

export type MapInfo = {
	Folder: Folder,
	Spots: { [string]: { Vector3 } },
	NoteSpots: { [string]: Vector3 },
	Closets: { { model: Model, hidePoint: CFrame, kind: string } }, -- kind: "Closet" 옷장 / "Vehicle" 차 밑
	Buildings: { { cf: CFrame, size: Vector3 } }, -- 오두막/창고 (괴물이 몸을 숙이고 들어감)
	GateDoor: BasePart,
	GateLamp: BasePart,
	ExitZone: BasePart,
	Generator: BasePart,
	Truck: Model,
	Radio: BasePart,
	Helipad: BasePart,
	SafeRoom: BasePart,
	MonsterSpawn: Vector3,
	HalfSize: number,
	isOpenSpot: (Vector3) -> boolean,
}

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(14, 14, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(26, 26, 38)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(8, 9, 14)
	Lighting.FogStart = 8
	Lighting.FogEnd = 120

	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.35
	cc.Contrast = 0.15
	cc.TintColor = Color3.fromRGB(215, 225, 255)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end

function MapBuilder.build(): MapInfo
	setupLighting()

	for _, name in { "Baseplate", "SpawnLocation", "BlackpineForest" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "BlackpineForest"
	local size = Config.Map.Size
	local half = size / 2
	local rng = Build.rng

	local spots: { [string]: { Vector3 } } = {}
	local function addSpot(place: string, pos: Vector3)
		spots[place] = spots[place] or {}
		table.insert(spots[place], pos)
	end
	local function addSpots(dict: { [string]: { Vector3 } })
		for place, list in dict do
			for _, pos in list do
				addSpot(place, pos)
			end
		end
	end
	local noteSpots: { [string]: Vector3 } = {}
	local closets = {}
	local buildings = {}
	local function addBuilding(cf: CFrame)
		table.insert(buildings, { cf = cf, size = Build.CabinSize })
	end

	-- 나무를 심으면 안 되는 구역 (중심, 반지름)
	local clearings: { { Vector3 | number } } = {}
	local function clear(center: Vector3, radius: number)
		table.insert(clearings, { center, radius })
	end

	-----------------------------------------------------------------------
	-- 바닥, 경계
	-----------------------------------------------------------------------
	Build.part(folder, Vector3.new(size + 200, 2, size + 200), CFrame.new(0, -1, 0), Color3.fromRGB(26, 34, 22), Enum.Material.Grass, { Name = "Ground" })
	for _ = 1, 25 do
		local r = rng:NextNumber(15, 40)
		Build.part(folder, Vector3.new(r, 0.1, r * rng:NextNumber(0.6, 1.4)), CFrame.new(rng:NextNumber(-half, half), 0.03, rng:NextNumber(-half, half)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(40, 36, 28), Enum.Material.Mud, {
			CanCollide = false,
			CanQuery = false,
		})
	end
	-- 맵 경계: 눈에 보이는 높은 통나무 울타리 + 그 위로 아주 높은 투명 벽 (넘어갈 수 없음)
	local walls = Instance.new("Folder")
	walls.Name = "BoundaryWalls"
	walls.Parent = folder
	local wallH = 26
	local corners = { Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half), Vector3.new(half, 0, half), Vector3.new(-half, 0, half) }
	for i = 1, 4 do
		local a, b = corners[i], corners[(i % 4) + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + 4
		local cf = CFrame.lookAt(mid, b)
		Build.part(walls, Vector3.new(3, wallH, len), cf * CFrame.new(0, wallH / 2, 0), Color3.fromRGB(38, 28, 20), Enum.Material.WoodPlanks, { Name = "BoundaryWall" })
		-- 통나무 기둥
		local posts = math.floor(len / 8)
		for k = 0, posts do
			local p = a:Lerp(b, k / posts)
			Build.part(walls, Vector3.new(wallH + 4, 2.2, 2.2), CFrame.new(p + Vector3.new(0, (wallH + 4) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.Bark, Enum.Material.Wood, {
				Shape = Enum.PartType.Cylinder,
				CanQuery = false,
			})
		end
		-- 투명 벽 (높이 300) : 아무리 높이 올라가도 못 넘어감
		Build.part(walls, Vector3.new(6, 300, len), cf * CFrame.new(0, 150, 0), Color3.new(), nil, { Transparency = 1, Name = "Boundary", CanQuery = false })
	end

	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder

	-----------------------------------------------------------------------
	-- 길
	-----------------------------------------------------------------------
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = folder
	local mainRoad = { Vector3.new(0, 0, half), Vector3.new(0, 0, 220), Vector3.new(-12, 0, 160), Vector3.new(0, 0, 110), Vector3.new(6, 0, 20), Vector3.new(-6, 0, -120), Vector3.new(0, 0, -260), Vector3.new(0, 0, -half + 12) }
	for i = 1, #mainRoad - 1 do
		Build.road(roads, mainRoad[i], mainRoad[i + 1], 14)
	end
	Build.road(roads, Vector3.new(0, 0, 100), Vector3.new(-120, 0, 40), 10) -- 서쪽: 감시탑
	Build.road(roads, Vector3.new(-120, 0, 40), Vector3.new(-205, 0, -30), 10)
	Build.road(roads, Vector3.new(-205, 0, -30), Vector3.new(-205, 0, -140), 8) -- 헬기장
	Build.road(roads, Vector3.new(0, 0, 100), Vector3.new(120, 0, 70), 10) -- 동쪽: 주유소
	Build.road(roads, Vector3.new(120, 0, 70), Vector3.new(210, 0, 60), 10)
	Build.road(roads, Vector3.new(210, 0, 60), Vector3.new(230, 0, 140), 8) -- 고물장
	-- 제단으로 가는 길은 일부러 없음 (숲을 헤쳐 가야 함)

	Build.sign(props, CFrame.lookAt(Vector3.new(10, 0, 95), Vector3.new(10, 0, 120)), "← 감시탑   주유소 →")
	Build.sign(props, CFrame.lookAt(Vector3.new(10, 0, 30), Vector3.new(10, 0, 60)), "↑ 정문")
	Build.sign(props, CFrame.lookAt(Vector3.new(-12, 0, 230), Vector3.new(-12, 0, 260)), "흑송 벌목장  ↑")
	Build.sign(props, CFrame.lookAt(Vector3.new(140, 0, -80), Vector3.new(130, 0, -60)), "출입 금지")

	-----------------------------------------------------------------------
	-- 시작 지점: 고장난 수색대 차
	-----------------------------------------------------------------------
	local carCf = CFrame.new(10, 0, 272) * CFrame.Angles(0, math.rad(8), 0)
	local carHide, carHidePoint = Build.carHulk(props, carCf, Color3.fromRGB(40, 60, 45))
	table.insert(closets, { model = carHide, hidePoint = carHidePoint, kind = "Vehicle" })
	local hazard = Build.part(props, Vector3.new(0.6, 0.6, 0.6), carCf * CFrame.new(0, 3.2, -6), Color3.fromRGB(255, 120, 0), Enum.Material.Neon)
	Build.light(hazard, Color3.fromRGB(255, 120, 0), 18, 1.2, true)
	noteSpots.Car = (carCf * CFrame.new(0, 3.05, -4)).Position -- 보닛 위
	clear(Vector3.new(0, 0, 268), 30)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 262), Vector3.new(0, 0.5, 200))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	-----------------------------------------------------------------------
	-- 벌목 캠프 (중앙)
	-----------------------------------------------------------------------
	local camp = Instance.new("Folder")
	camp.Name = "LoggingCamp"
	camp.Parent = folder
	clear(Vector3.new(0, 0, 100), 62)
	clear(Vector3.new(-60, 0, 205), 8) -- 숲길 옆 시신 자리

	local cabinCfs = {
		CFrame.lookAt(Vector3.new(-38, 0, 128), Vector3.new(0, 0, 100)),
		CFrame.lookAt(Vector3.new(-44, 0, 78), Vector3.new(0, 0, 100)),
		CFrame.lookAt(Vector3.new(36, 0, 132), Vector3.new(0, 0, 100)),
	}
	for i, cf in cabinCfs do
		local _, cabinSpots, closetCf, doorFront = Build.cabin(camp, cf, "Cabin" .. i)
		addSpots(cabinSpots)
		addBuilding(cf)
		local closet, hidePoint = Build.closet(camp, closetCf)
		table.insert(closets, { model = closet, hidePoint = hidePoint, kind = "Closet" })
		Build.lanternPost(camp, doorFront * CFrame.new(4, -1, 0))
		if i == 1 then
			noteSpots.Camp = (cf * CFrame.new(-4, 4.25, 2)).Position -- 반장 오두막 탁자
		end
	end

	-- 모닥불
	Build.part(camp, Vector3.new(0.6, 7, 7), CFrame.new(0, 0.3, 100) * CFrame.Angles(0, 0, math.rad(90)), C.Stone, Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
	local embers = Build.part(camp, Vector3.new(2, 1, 2), CFrame.new(0, 0.8, 100), Color3.fromRGB(255, 90, 30), Enum.Material.Neon)
	Build.light(embers, Color3.fromRGB(255, 110, 40), 28, 2, true)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = embers
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		Build.part(camp, Vector3.new(6, 1.2, 1.2), CFrame.new(math.cos(a) * 7, 0.6, 100 + math.sin(a) * 7) * CFrame.Angles(0, -a, 0), C.Wood, Enum.Material.Wood)
	end
	addSpot("Campfire", Vector3.new(8, 0, 94))
	addSpot("Campfire", Vector3.new(-9, 0, 107))
	addSpot("Camp", Vector3.new(6, 0, 92))

	-- 빨랫줄, 화약 상자, 시신
	for _, pos in Build.clothesline(camp, CFrame.lookAt(Vector3.new(-14, 0, 152), Vector3.new(0, 0, 152))) do
		addSpot("Clothesline", pos)
	end
	addSpot("ExplosiveCrate", Build.explosivesCrate(camp, CFrame.lookAt(Vector3.new(26, 0, 152), Vector3.new(0, 0, 120))))
	addSpot("Corpse", Build.corpse(camp, CFrame.new(-24, 0, 62) * CFrame.Angles(0, 1.2, 0)))

	-- 제재소 (지붕만 있는 작업장)
	local sawCf = CFrame.lookAt(Vector3.new(48, 0, 76), Vector3.new(0, 0, 76))
	for _, x in { -10, 10 } do
		for _, z in { -7, 7 } do
			Build.part(camp, Vector3.new(1.2, 12, 1.2), sawCf * CFrame.new(x, 6, z), C.Bark, Enum.Material.Wood)
		end
	end
	Build.part(camp, Vector3.new(24, 1, 18), sawCf * CFrame.new(0, 12.5, 0) * CFrame.Angles(math.rad(6), 0, 0), C.Roof, Enum.Material.CorrodedMetal)
	Build.part(camp, Vector3.new(16, 3, 4), sawCf * CFrame.new(0, 1.5, 0), C.Metal, Enum.Material.Metal) -- 톱 작업대
	local blade = Build.part(camp, Vector3.new(0.3, 5, 5), sawCf * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
	})
	blade.CFrame = sawCf * CFrame.new(0, 4, 0)
	for _, pileCf in { sawCf * CFrame.new(0, 0, 14), sawCf * CFrame.new(-16, 0, -2) * CFrame.Angles(0, math.rad(90), 0) } do
		Build.logPile(camp, pileCf)
		addSpot("LogPile", (pileCf * CFrame.new(0, 5.6, 0)).Position)
		addSpot("LogPile", (pileCf * CFrame.new(3.5, 0, 2.5)).Position)
	end
	Build.lanternPost(camp, sawCf * CFrame.new(11, 0, -8))
	for _, p in { Vector3.new(-6, 3, 0), Vector3.new(8, 0, -5), Vector3.new(-8, 0, 5), Vector3.new(4, 0, 9) } do
		addSpot("SawmillFloor", (sawCf * CFrame.new(p)).Position)
	end
	for _, pos in Build.workbench(camp, sawCf * CFrame.new(-6, 0, -6)) do
		addSpot("Workbench", pos)
	end
	-- 제재소 기둥의 전기함
	addSpot("FuseBox", Build.fuseBox(camp, sawCf * CFrame.new(10, 4.5, -7.6)))
	noteSpots.Sawmill = (sawCf * CFrame.new(5, 3, 0)).Position

	-- 벌목 트럭 (북쪽을 바라봄)
	local truck, truckHide, truckHidePoint = Build.truck(camp, CFrame.new(18, 0, 50))
	table.insert(closets, { model = truckHide, hidePoint = truckHidePoint, kind = "Vehicle" })

	for _, pos in { Vector3.new(-20, 0, 60), Vector3.new(24, 0, 112), Vector3.new(-14, 0, 140) } do
		Build.crate(camp, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
		Build.barrel(camp, CFrame.new(pos + Vector3.new(4, 0, 2)) * CFrame.Angles(math.rad(90), 0, 0))
	end

	-----------------------------------------------------------------------
	-- 레인저 감시탑 (서쪽)
	-----------------------------------------------------------------------
	local towerPos = Vector3.new(-210, 0, -40)
	local tower = Instance.new("Folder")
	tower.Name = "RangerTower"
	tower.Parent = folder
	clear(towerPos, 28)
	local towerH = 30
	for _, x in { -6, 6 } do
		for _, z in { -6, 6 } do
			Build.part(tower, Vector3.new(1.5, towerH, 1.5), CFrame.new(towerPos + Vector3.new(x, towerH / 2, z)), C.Bark, Enum.Material.Wood)
		end
	end
	for y = 8, towerH - 4, 9 do
		for _, z in { -6, 6 } do
			Build.part(tower, Vector3.new(13, 0.8, 0.8), CFrame.new(towerPos + Vector3.new(0, y, z)) * CFrame.Angles(0, 0, math.rad(35)), C.Wood, Enum.Material.Wood, { CanCollide = false })
		end
	end
	Build.part(tower, Vector3.new(16, 1, 16), CFrame.new(towerPos + Vector3.new(0, towerH, 0)), C.Plank, Enum.Material.WoodPlanks)
	-- 난간 (남쪽은 사다리 자리만 비움)
	Build.part(tower, Vector3.new(16, 4, 0.6), CFrame.new(towerPos + Vector3.new(0, towerH + 2.5, -8)), C.Wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		Build.part(tower, Vector3.new(6.5, 4, 0.6), CFrame.new(towerPos + Vector3.new(side * 4.75, towerH + 2.5, 8)), C.Wood, Enum.Material.WoodPlanks)
		Build.part(tower, Vector3.new(0.6, 4, 16), CFrame.new(towerPos + Vector3.new(side * 8, towerH + 2.5, 0)), C.Wood, Enum.Material.WoodPlanks)
	end
	Build.part(tower, Vector3.new(18, 1, 18), CFrame.new(towerPos + Vector3.new(0, towerH + 9, 0)), C.Roof, Enum.Material.Slate)
	for _, x in { -7.5, 7.5 } do
		for _, z in { -7.5, 7.5 } do
			Build.part(tower, Vector3.new(0.6, 8, 0.6), CFrame.new(towerPos + Vector3.new(x, towerH + 4.5, z)), C.Bark, Enum.Material.Wood)
		end
	end
	-- 사다리 (남쪽 면) - 난간을 뚫고 올라가도록 위 난간 일부를 비움
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, towerH + 4, 2)
	ladder.CFrame = CFrame.new(towerPos + Vector3.new(0, (towerH + 4) / 2, 9.2))
	ladder.Color = C.DarkWood
	ladder.Material = Enum.Material.Wood
	ladder.Parent = tower
	local radioTable = Build.part(tower, Vector3.new(5, 0.5, 3), CFrame.new(towerPos + Vector3.new(-4, towerH + 3, -5)), C.Plank, Enum.Material.Wood)
	local radio = Build.part(tower, Vector3.new(2.4, 1.6, 1.4), radioTable.CFrame * CFrame.new(0, 1.05, 0), Color3.fromRGB(60, 65, 55), Enum.Material.Metal, { Name = "Radio" })
	local radioLamp = Build.part(tower, Vector3.new(0.3, 0.3, 0.1), radio.CFrame * CFrame.new(0.8, 0.4, -0.75), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	Build.light(radioLamp, Color3.fromRGB(255, 40, 40), 8, 1, true)
	for _, offset in { Vector3.new(-10, 0, 8), Vector3.new(-12, 0, 4), Vector3.new(10, 0, -10) } do
		Build.crate(tower, CFrame.new(towerPos + offset) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
		addSpot("TowerCrate", towerPos + offset + Vector3.new(0, 3, 0))
	end
	addSpot("TowerCrate", towerPos + Vector3.new(4, 0, 3))
	Build.barrel(tower, CFrame.new(towerPos + Vector3.new(10, 0, 6)))
	addSpot("ExplosiveCrate", Build.explosivesCrate(tower, CFrame.lookAt(towerPos + Vector3.new(-12, 0, -10), towerPos)))
	-- 탑 다리에 붙은 전기함
	local leg = towerPos + Vector3.new(6, 4.5, 6.75)
	addSpot("FuseBox", Build.fuseBox(tower, CFrame.lookAt(leg, leg + Vector3.new(0, 0, 10))))
	addSpot("Corpse", Build.corpse(tower, CFrame.new(towerPos + Vector3.new(-6, 0, 18)) * CFrame.Angles(0, -0.5, 0)))
	noteSpots.Tower = towerPos + Vector3.new(2, 0, 14)
	Build.lanternPost(tower, CFrame.new(towerPos + Vector3.new(5, 0, 16)))

	-----------------------------------------------------------------------
	-- 헬기장 (북서쪽 공터)
	-----------------------------------------------------------------------
	local heliPos = Vector3.new(-205, 0, -155)
	clear(heliPos, 34)
	local helipad = Build.part(folder, Vector3.new(1, 36, 36), CFrame.new(heliPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 70, 72), Enum.Material.Concrete, {
		Shape = Enum.PartType.Cylinder,
		Name = "Helipad",
	})
	Build.part(folder, Vector3.new(2, 0.2, 12), CFrame.new(heliPos + Vector3.new(-4, 0.75, 0)), Color3.fromRGB(200, 200, 190), Enum.Material.SmoothPlastic)
	Build.part(folder, Vector3.new(2, 0.2, 12), CFrame.new(heliPos + Vector3.new(4, 0.75, 0)), Color3.fromRGB(200, 200, 190), Enum.Material.SmoothPlastic)
	Build.part(folder, Vector3.new(6, 0.2, 2), CFrame.new(heliPos + Vector3.new(0, 0.75, 0)), Color3.fromRGB(200, 200, 190), Enum.Material.SmoothPlastic)
	-- 헬기장 가장자리의 보급 상자들
	for _, pos in { Vector3.new(-20, 0, -14), Vector3.new(20, 0, 16), Vector3.new(-16, 0, 20) } do
		Build.crate(folder, CFrame.new(heliPos + pos) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
		addSpot("Helipad", heliPos + pos + Vector3.new(0, 3, 0))
	end
	addSpot("Helipad", heliPos + Vector3.new(14, 0.7, -8))

	-----------------------------------------------------------------------
	-- 폐주유소 + 고물장 (동쪽)
	-----------------------------------------------------------------------
	local gas = Instance.new("Folder")
	gas.Name = "GasStation"
	gas.Parent = folder
	local gasPos = Vector3.new(210, 0, 60)
	clear(gasPos, 40)
	clear(Vector3.new(232, 0, 140), 34)
	-- 캐노피
	for _, x in { -12, 12 } do
		Build.part(gas, Vector3.new(1.5, 14, 1.5), CFrame.new(gasPos + Vector3.new(x, 7, -14)), C.Metal, Enum.Material.Metal)
	end
	Build.part(gas, Vector3.new(30, 1.5, 14), CFrame.new(gasPos + Vector3.new(0, 14.5, -14)) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(150, 140, 120), Enum.Material.CorrodedMetal)
	local sign = Build.part(gas, Vector3.new(14, 3, 0.5), CFrame.new(gasPos + Vector3.new(0, 16.8, -20.8)), Color3.fromRGB(140, 30, 25), Enum.Material.Metal)
	Build.text(sign, Enum.NormalId.Front, "흑송 주유소")
	Build.text(sign, Enum.NormalId.Back, "흑송 주유소")
	for _, x in { -5, 5 } do
		Build.part(gas, Vector3.new(2.5, 5, 1.6), CFrame.new(gasPos + Vector3.new(x, 2.5, -14)), Color3.fromRGB(170, 40, 30), Enum.Material.Metal)
	end
	local flicker = Build.part(gas, Vector3.new(6, 0.3, 1), CFrame.new(gasPos + Vector3.new(0, 13.6, -14)), Color3.fromRGB(220, 240, 255), Enum.Material.Neon)
	Build.light(flicker, Color3.fromRGB(200, 230, 255), 30, 1.5, true)
	-- 창고 건물
	local shedCf = CFrame.lookAt(gasPos + Vector3.new(0, 0, 10), gasPos + Vector3.new(0, 0, -10))
	local _, shedSpots, shedCloset = Build.cabin(gas, shedCf, "GasShed")
	addSpots(shedSpots)
	addBuilding(shedCf)
	local closet, hidePoint = Build.closet(gas, shedCloset)
	table.insert(closets, { model = closet, hidePoint = hidePoint, kind = "Closet" })
	for _, x in { -7.5, -2.5, 2.5, 7.5 } do
		addSpot("Pumps", gasPos + Vector3.new(x, 0, -11.5))
	end
	for _, pos in Build.shelf(gas, CFrame.lookAt(gasPos + Vector3.new(14, 0, -6), gasPos + Vector3.new(0, 0, -6))) do
		addSpot("Shelf", pos)
	end
	for _, pos in Build.workbench(gas, CFrame.lookAt(gasPos + Vector3.new(-15, 0, -4), gasPos + Vector3.new(0, 0, -4))) do
		addSpot("Workbench", pos)
	end
	addSpot("ExplosiveCrate", Build.explosivesCrate(gas, CFrame.lookAt(gasPos + Vector3.new(-17, 0, 8), gasPos)))
	addSpot("ExplosiveCrate", Build.explosivesCrate(gas, CFrame.lookAt(Vector3.new(250, 0, 118), Vector3.new(232, 0, 140))))
	addSpot("FuseBox", Build.fuseBox(gas, CFrame.lookAt(gasPos + Vector3.new(12, 6, -13.25), gasPos + Vector3.new(12, 6, -5))))
	addSpot("Corpse", Build.corpse(gas, CFrame.new(gasPos + Vector3.new(-8, 0, -22)) * CFrame.Angles(0, 2.2, 0)))
	noteSpots.GasShed = (shedCf * CFrame.new(-4, 4.25, 2)).Position
	-- 고물장
	local junkPos = Vector3.new(232, 0, 140)
	local junkColors = { Color3.fromRGB(90, 40, 30), Color3.fromRGB(40, 50, 70), Color3.fromRGB(80, 80, 60), Color3.fromRGB(50, 70, 50) }
	for i = 1, 6 do
		local pos = junkPos + Vector3.new(rng:NextNumber(-22, 22), 0, rng:NextNumber(-22, 22))
		local carCf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local junkHide, junkHidePoint = Build.carHulk(gas, carCf, junkColors[(i % #junkColors) + 1])
		table.insert(closets, { model = junkHide, hidePoint = junkHidePoint, kind = "Vehicle" })
		addSpot("CarHood", (carCf * CFrame.new(0, 3.05, -4)).Position)
		addSpot("Junk", (carCf * CFrame.new(4.5, 0, rng:NextNumber(-4, 4))).Position)
	end
	for _ = 1, 8 do
		Build.barrel(gas, CFrame.new(junkPos + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))))
	end
	Build.fence(gas, junkPos + Vector3.new(-28, 0, 28), junkPos + Vector3.new(28, 0, 28), 8)
	Build.fence(gas, junkPos + Vector3.new(28, 0, -28), junkPos + Vector3.new(28, 0, 28), 8)
	Build.lanternPost(gas, CFrame.new(junkPos + Vector3.new(-20, 0, -24)))
	addSpot("Corpse", Build.corpse(gas, CFrame.new(junkPos + Vector3.new(15, 0, 18)) * CFrame.Angles(0, 0.7, 0)))

	-----------------------------------------------------------------------
	-- 옛 제단 (북동쪽, 괴물의 둥지)
	-----------------------------------------------------------------------
	local altarFolder = Instance.new("Folder")
	altarFolder.Name = "Altar"
	altarFolder.Parent = folder
	local altarPos = Vector3.new(185, 0, -175)
	clear(altarPos, 40)
	for k = 0, 7 do
		local a = k * math.pi / 4
		local pos = altarPos + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)
		local h = rng:NextNumber(10, 16)
		Build.part(altarFolder, Vector3.new(4, h, 2.5), CFrame.lookAt(pos, altarPos) * CFrame.new(0, h / 2 - 0.5, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, 0), C.Stone, Enum.Material.Slate)
	end
	local altar = Build.part(altarFolder, Vector3.new(10, 3, 5), CFrame.new(altarPos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(60, 60, 58), Enum.Material.Slate, { Name = "AltarStone" })
	-- 베어진 거대한 고목 그루터기
	Build.part(altarFolder, Vector3.new(4, 14, 14), CFrame.new(altarPos + Vector3.new(0, 2, 10)) * CFrame.Angles(0, 0, math.rad(90)), C.Bark, Enum.Material.Wood, {
		Shape = Enum.PartType.Cylinder,
	})
	Build.part(altarFolder, Vector3.new(4, 30, 4), CFrame.new(altarPos + Vector3.new(-14, 2, 30)) * CFrame.Angles(math.rad(80), 0, math.rad(30)), C.Bark, Enum.Material.Wood)
	for _, x in { -3.5, 3.5 } do
		local candle = Build.part(altarFolder, Vector3.new(0.4, 1, 0.4), altar.CFrame * CFrame.new(x, 2, 0), Color3.fromRGB(255, 80, 60), Enum.Material.Neon)
		Build.light(candle, Color3.fromRGB(255, 50, 40), 14, 1.2, true)
	end
	-- 동물 뼈
	for _ = 1, 10 do
		Build.part(altarFolder, Vector3.new(0.4, 0.4, rng:NextNumber(1.5, 3)), CFrame.new(altarPos + Vector3.new(rng:NextNumber(-14, 14), 0.2, rng:NextNumber(-14, 14))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(210, 205, 190), Enum.Material.SmoothPlastic, {
			CanCollide = false,
		})
	end
	addSpot("Altar", altar.Position + Vector3.new(-2, 1.5, 0))
	addSpot("Altar", altarPos + Vector3.new(12, 0, -12))
	addSpot("Altar", altarPos + Vector3.new(-14, 0, 6))
	addSpot("Corpse", Build.corpse(altarFolder, CFrame.new(altarPos + Vector3.new(8, 0, 14)) * CFrame.Angles(0, 2.8, 0)))
	noteSpots.Altar = altarPos + Vector3.new(0, 0, -14)
	-- 돌무덤 (룬 조각 자리)
	for _ = 1, 7 do
		local pos = altarPos + Vector3.new(rng:NextNumber(-90, 60), 0, rng:NextNumber(-40, 110))
		pos = Vector3.new(math.clamp(pos.X, -half + 30, half - 30), 0, math.clamp(pos.Z, -half + 40, half - 30))
		for i = 0, 3 do
			Build.rock(altarFolder, pos + Vector3.new(0, i * 1.4, 0), 3.4 - i * 0.6)
		end
		addSpot("Cairn", pos + Vector3.new(2.6, 0, 0))
		clear(pos, 6)
	end

	-----------------------------------------------------------------------
	-- 정문 + 발전기 오두막 (북쪽)
	-----------------------------------------------------------------------
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "Gate"
	gateFolder.Parent = folder
	local fenceZ = -half + 28
	local gateWidth = 16
	Build.fence(gateFolder, Vector3.new(-half, 0, fenceZ), Vector3.new(-gateWidth / 2 - 2, 0, fenceZ), 14)
	Build.fence(gateFolder, Vector3.new(gateWidth / 2 + 2, 0, fenceZ), Vector3.new(half, 0, fenceZ), 14)
	for _, side in { -1, 1 } do
		Build.part(gateFolder, Vector3.new(3, 20, 3), CFrame.new(side * (gateWidth / 2 + 1.5), 10, fenceZ), Color3.fromRGB(60, 60, 64), Enum.Material.Concrete)
	end
	local arch = Build.part(gateFolder, Vector3.new(gateWidth + 6, 3, 2), CFrame.new(0, 21.5, fenceZ), Color3.fromRGB(60, 60, 64), Enum.Material.Concrete)
	Build.text(arch, Enum.NormalId.Back, "출 구")
	local gateDoor = Build.part(gateFolder, Vector3.new(gateWidth, 18, 1), CFrame.new(0, 9, fenceZ), Color3.fromRGB(90, 25, 22), Enum.Material.DiamondPlate, { Name = "GateDoor" })
	local gateLamp = Build.part(gateFolder, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 23.6, fenceZ), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, { Name = "GateLamp" })
	Build.light(gateLamp, Color3.fromRGB(255, 40, 40), 30, 2)
	local exitZone = Build.part(gateFolder, Vector3.new(gateWidth * 2, 12, 14), CFrame.new(0, 6, fenceZ - 12), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, {
		Name = "ExitZone",
		Transparency = 1,
		CanCollide = false,
	})
	clear(Vector3.new(0, 0, fenceZ), 20)

	local genCf = CFrame.lookAt(Vector3.new(42, 0, fenceZ + 30), Vector3.new(0, 0, fenceZ + 30))
	clear(genCf.Position, 22)
	local _, genSpots, genCloset = Build.cabin(gateFolder, genCf, "GeneratorShed")
	addBuilding(genCf)
	genSpots.FuseBox = nil -- 발전기 바로 옆이라 퓨즈를 두지 않음
	addSpots(genSpots)
	local closet2, hide2 = Build.closet(gateFolder, genCloset)
	table.insert(closets, { model = closet2, hidePoint = hide2, kind = "Closet" })
	local generator = Build.part(gateFolder, Vector3.new(5, 4, 3.5), genCf * CFrame.new(2, 3, 3), Color3.fromRGB(70, 80, 60), Enum.Material.Metal, { Name = "Generator" })
	for i = 1, Config.Escape.FusesRequired do
		local slot = Build.part(gateFolder, Vector3.new(0.6, 0.9, 0.2), generator.CFrame * CFrame.new(-1.5 + (i - 1) * 1.5, 0.8, -1.85), Color3.fromRGB(40, 40, 40), Enum.Material.Neon, {
			Name = "FuseSlot" .. i,
		})
		slot:SetAttribute("Slot", i)
	end
	noteSpots.Generator = genSpots.CabinTable[1]
	addSpot("Corpse", Build.corpse(gateFolder, CFrame.new(-20, 0, fenceZ + 16) * CFrame.Angles(0, -0.8, 0)))

	-----------------------------------------------------------------------
	-- 숲: 소나무, 고목, 바위, 덤불
	-----------------------------------------------------------------------
	local function isClear(pos: Vector3, margin: number): boolean
		for _, c in clearings do
			if (Vector3.new(pos.X, 0, pos.Z) - (c[1] :: Vector3)).Magnitude < (c[2] :: number) + margin then
				return false
			end
		end
		-- 길 근처 비우기 (주 도로)
		if math.abs(pos.X) < 12 then
			return false
		end
		if pos.Z < fenceZ + 6 then
			return false
		end
		return true
	end

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	local function randomForestPos(): Vector3
		return Vector3.new(rng:NextNumber(-half + 6, half - 6), 0, rng:NextNumber(fenceZ + 8, half - 6))
	end
	for _ = 1, Config.Map.TreeCount do
		local pos = randomForestPos()
		if isClear(pos, 4) then
			Build.pine(trees, pos.X, pos.Z, rng:NextNumber(0.8, 1.5))
		end
	end
	for _ = 1, Config.Map.DeadTreeCount do
		local pos = randomForestPos()
		if isClear(pos, 2) then
			Build.deadTree(trees, pos.X, pos.Z, rng:NextNumber(0.8, 1.4))
		end
	end
	-- 제단 주변은 고목을 더 많이
	for _ = 1, 20 do
		local pos = altarPos + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-60, 70))
		if isClear(pos, 0) and math.abs(pos.X) < half - 6 and math.abs(pos.Z) < half - 6 then
			Build.deadTree(trees, pos.X, pos.Z, rng:NextNumber(1, 1.6))
		end
	end
	-- 약초 군락
	local herbs = Instance.new("Folder")
	herbs.Name = "HerbPatches"
	herbs.Parent = folder
	local herbCount = 0
	for _ = 1, 60 do
		local pos = randomForestPos()
		if herbCount < 18 and isClear(pos, 0) then
			herbCount += 1
			addSpot("HerbPatch", Build.herbPatch(herbs, pos))
		end
	end
	-- 숲길 옆 시신 하나
	addSpot("Corpse", Build.corpse(props, CFrame.new(-60, 0, 205) * CFrame.Angles(0, 0.3, 0)))

	for _ = 1, Config.Map.RockCount do
		local pos = randomForestPos()
		if isClear(pos, 0) then
			Build.rock(props, pos, rng:NextNumber(2, 6))
		end
	end
	for _ = 1, Config.Map.BushCount do
		local pos = randomForestPos()
		if isClear(pos, -2) then
			Build.bush(props, pos, rng:NextNumber(3, 6))
		end
	end
	-- 숲 가장자리를 빽빽하게 (벽이 안 보이게)
	for i = 0, 60 do
		local t = i / 60
		for _, edge in {
			Vector3.new(-half + 8, 0, -half + 30 + t * (size - 40)),
			Vector3.new(half - 8, 0, -half + 30 + t * (size - 40)),
			Vector3.new(-half + 20 + t * (size - 40), 0, half - 8),
		} do
			if math.abs(edge.X) > 14 then
				Build.pine(trees, edge.X + rng:NextNumber(-4, 4), edge.Z + rng:NextNumber(-4, 4), rng:NextNumber(1.2, 1.7))
			end
		end
	end

	-----------------------------------------------------------------------
	-- 탈출자 대기실 (하늘 위)
	-----------------------------------------------------------------------
	local safeRoom = Build.part(folder, Vector3.new(40, 1, 40), CFrame.new(0, 600, 0), Color3.fromRGB(200, 200, 200), Enum.Material.SmoothPlastic, { Name = "SafeRoom" })
	for _, w in { { Vector3.new(40, 10, 1), Vector3.new(0, 5, 20) }, { Vector3.new(40, 10, 1), Vector3.new(0, 5, -20) }, { Vector3.new(1, 10, 40), Vector3.new(20, 5, 0) }, { Vector3.new(1, 10, 40), Vector3.new(-20, 5, 0) } } do
		Build.part(folder, w[1], safeRoom.CFrame * CFrame.new(w[2]), Color3.fromRGB(200, 200, 200), nil, { Transparency = 0.7 })
	end
	Build.light(safeRoom, Color3.new(1, 1, 1), 40, 2)

	folder.Parent = Workspace

	-- 재료/배회 지점이 될 수 있는 곳
	local function isOpenSpot(pos: Vector3): boolean
		return math.abs(pos.X) < half - 10 and pos.Z > fenceZ + 8 and pos.Z < half - 10 and (pos - Vector3.new(0, pos.Y, 262)).Magnitude > 25
	end

	return {
		Folder = folder,
		Spots = spots,
		NoteSpots = noteSpots,
		Closets = closets,
		Buildings = buildings,
		GateDoor = gateDoor,
		GateLamp = gateLamp,
		ExitZone = exitZone,
		Generator = generator,
		Truck = truck,
		Radio = radio,
		Helipad = helipad,
		SafeRoom = safeRoom,
		-- 괴물 처음 위치: 제단 뒤쪽 (시작 지점에서 가장 먼 북동쪽). 처음 Config.Monster.StartGrace 초 동안은 이 근처만 돌아다님
		MonsterSpawn = altarPos + Vector3.new(20, 4, -28),
		HalfSize = half,
		isOpenSpot = isOpenSpot,
	}
end

return MapBuilder
