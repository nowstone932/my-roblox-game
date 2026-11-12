-- 어두운 숲 맵을 코드로 만듭니다.
-- 처음엔 Studio에서 직접 맵을 안 만들어도 바로 플레이해볼 수 있게 하려는 용도예요.
-- 나중에 Studio에서 맵을 직접 꾸미고 싶으면 이 파일의 나무 생성 부분만 빼면 됩니다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

export type MapInfo = {
	Folder: Folder,
	SpawnLocation: SpawnLocation,
	GateDoor: BasePart,
	ExitZone: BasePart,
	FuseBox: BasePart,
	SafeRoom: BasePart,
	MonsterSpawn: Vector3,
	HalfSize: number,
	-- 재료/배회 지점을 고를 때 피해야 하는 영역 판단용
	isOpenSpot: (Vector3) -> boolean,
}

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(12, 12, 18)
	Lighting.OutdoorAmbient = Color3.fromRGB(22, 22, 32)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(6, 6, 10)
	Lighting.FogStart = 5
	Lighting.FogEnd = 110

	-- Atmosphere가 있으면 Fog 설정이 무시되므로 지웁니다.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
end

function MapBuilder.build(): MapInfo
	setupLighting()

	-- 기본 Baseplate 템플릿의 바닥/스폰은 지웁니다.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local old = Workspace:FindFirstChild("DarkForest")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "DarkForest"

	local size = Config.Map.Size
	local half = size / 2
	local rng = Random.new()

	-- 바닥
	makePart({
		Name = "Ground",
		Size = Vector3.new(size, 2, size),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(28, 38, 24),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	-- 바깥 벽 (안 보이게)
	local wallHeight = 60
	local walls = {
		{ Vector3.new(size, wallHeight, 2), Vector3.new(0, wallHeight / 2, -half) },
		{ Vector3.new(size, wallHeight, 2), Vector3.new(0, wallHeight / 2, half) },
		{ Vector3.new(2, wallHeight, size), Vector3.new(-half, wallHeight / 2, 0) },
		{ Vector3.new(2, wallHeight, size), Vector3.new(half, wallHeight / 2, 0) },
	}
	for _, w in walls do
		makePart({
			Name = "Boundary",
			Size = w[1],
			Position = w[2],
			Transparency = 1,
			Parent = folder,
		})
	end

	-- 북쪽 울타리 + 탈출문. 울타리 너머가 탈출 구역입니다.
	local fenceZ = -half + 20
	local gateWidth = 14
	local fenceHeight = 16
	local sideLength = (size - gateWidth) / 2
	for _, sign in { -1, 1 } do
		makePart({
			Name = "Fence",
			Size = Vector3.new(sideLength, fenceHeight, 2),
			Position = Vector3.new(sign * (gateWidth / 2 + sideLength / 2), fenceHeight / 2, fenceZ),
			Color = Color3.fromRGB(45, 40, 35),
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})
	end

	local gateDoor = makePart({
		Name = "GateDoor",
		Size = Vector3.new(gateWidth, fenceHeight, 1.5),
		Position = Vector3.new(0, fenceHeight / 2, fenceZ),
		Color = Color3.fromRGB(120, 20, 20),
		Material = Enum.Material.DiamondPlate,
		Parent = folder,
	})

	local exitZone = makePart({
		Name = "ExitZone",
		Size = Vector3.new(gateWidth * 2, 10, 12),
		Position = Vector3.new(0, 5, fenceZ - 9),
		Transparency = 0.85,
		Color = Color3.fromRGB(80, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})

	local fuseBox = makePart({
		Name = "FuseBox",
		Size = Vector3.new(3, 5, 2),
		Position = Vector3.new(gateWidth / 2 + 5, 2.5, fenceZ + 4),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	local fuseLight = Instance.new("PointLight")
	fuseLight.Color = Color3.fromRGB(255, 60, 60)
	fuseLight.Range = 12
	fuseLight.Brightness = 2
	fuseLight.Parent = fuseBox

	-- 탈출한 사람이 기다리는 안전한 방 (하늘 위)
	local safeRoom = makePart({
		Name = "SafeRoom",
		Size = Vector3.new(40, 1, 40),
		Position = Vector3.new(0, 500, 0),
		Color = Color3.fromRGB(200, 200, 200),
		Parent = folder,
	})
	local safeLight = Instance.new("PointLight")
	safeLight.Range = 40
	safeLight.Brightness = 2
	safeLight.Parent = safeRoom

	-- 시작 지점
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, half - 40)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	local monsterSpawn = Vector3.new(0, 6, 0)

	local function isOpenSpot(pos: Vector3): boolean
		if (pos - spawn.Position).Magnitude < 30 then
			return false
		end
		if pos.Z < fenceZ + 10 then
			return false
		end
		return true
	end

	-- 나무
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	for _ = 1, Config.Map.TreeCount do
		local x = rng:NextNumber(-half + 10, half - 10)
		local z = rng:NextNumber(fenceZ + 12, half - 10)
		local pos = Vector3.new(x, 0, z)
		if isOpenSpot(pos) then
			local height = rng:NextNumber(18, 34)
			local width = rng:NextNumber(2, 4)
			makePart({
				Name = "Trunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, width, width),
				CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(40, 28, 20),
				Material = Enum.Material.Wood,
				Parent = trees,
			})
			local leaves = rng:NextNumber(10, 16)
			makePart({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(leaves, leaves, leaves),
				Position = Vector3.new(x, height, z),
				Color = Color3.fromRGB(15, 30, 15),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = trees,
			})
		end
	end

	folder.Parent = Workspace

	return {
		Folder = folder,
		SpawnLocation = spawn,
		GateDoor = gateDoor,
		ExitZone = exitZone,
		FuseBox = fuseBox,
		SafeRoom = safeRoom,
		MonsterSpawn = monsterSpawn,
		HalfSize = half,
		isOpenSpot = isOpenSpot,
	}
end

return MapBuilder
