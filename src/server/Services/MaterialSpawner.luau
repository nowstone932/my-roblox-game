-- 숲 곳곳에 재료를 뿌리고, 플레이어가 E키(ProximityPrompt)로 주울 수 있게 합니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local notify = Remotes.get("Notify")

local MaterialSpawner = {}

local map = nil
local folder: Folder? = nil
local generation = 0 -- 라운드가 바뀌면 증가. 이전 라운드의 리스폰 예약을 무시하기 위함
local rng = Random.new()

local function randomSpot(): Vector3
	local half = map.HalfSize - 15
	for _ = 1, 20 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0.6, rng:NextNumber(-half, half))
		if map.isOpenSpot(pos) then
			return pos
		end
	end
	return Vector3.new(0, 0.6, 0)
end

local function spawnOne(name: string)
	local def = Config.Materials[name]
	local myGeneration = generation
	if not folder then
		return
	end

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = if name == "Fuse" then Vector3.new(0.8, 1.6, 0.8) else Vector3.new(1.4, 1, 1.4)
	part.Color = def.Color
	part.Material = Enum.Material.Neon
	part.Position = randomSpot()
	part.Orientation = Vector3.new(0, rng:NextNumber(0, 360), 0)

	-- 어두워도 찾을 수 있게 은은하게 빛나게
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = if name == "Fuse" then 14 else 7
	light.Brightness = 1
	light.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "줍기"
	prompt.ObjectText = Config.ItemNames[name]
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player: Player)
		if part.Parent == nil or player:GetAttribute("InRound") ~= true then
			return
		end
		part:Destroy()
		Inventory.add(player, name, 1)
		notify:FireClient(player, Config.ItemNames[name] .. " +1")

		task.delay(def.RespawnTime, function()
			if generation == myGeneration then
				spawnOne(name)
			end
		end)
	end)

	part.Parent = folder
end

function MaterialSpawner.init(mapInfo)
	map = mapInfo
end

-- 라운드 시작: 기존 재료를 지우고 새로 뿌립니다.
function MaterialSpawner.reset()
	MaterialSpawner.clear()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Materials"
	newFolder.Parent = Workspace
	folder = newFolder

	for name, def in Config.Materials do
		for _ = 1, def.Count do
			spawnOne(name)
		end
	end
end

function MaterialSpawner.clear()
	generation += 1
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return MaterialSpawner
