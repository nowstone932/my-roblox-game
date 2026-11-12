-- 주울 수 있는 것들
--   재료: 숲 곳곳에 무작위, 주우면 일정 시간 뒤 다른 곳에 다시 생김
--   탈출 부품: Story.QuestItems 의 장소 후보 중 매 라운드 무작위 위치 (리스폰 없음)
--   쪽지: 고정 위치. E로 읽으면 화면에 내용이 뜸
-- 플레이어가 죽으면 들고 있던 탈출 부품은 그 자리에 떨어집니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Inventory = require(script.Parent.Inventory)

local notify = Remotes.get("Notify")
local showNote = Remotes.get("ShowNote")

local Pickups = {}

local map = nil
local folder: Folder? = nil
local generation = 0
local rng = Random.new()

-- 아이템마다 모양을 조금씩 다르게
local SHAPES: { [string]: { size: Vector3, shape: Enum.PartType? } } = {
	Fuse = { size = Vector3.new(1.4, 0.6, 0.6), shape = Enum.PartType.Cylinder },
	Battery = { size = Vector3.new(1.6, 1.2, 1) },
	FuelCan = { size = Vector3.new(1.2, 1.8, 0.8) },
	CarKey = { size = Vector3.new(0.6, 0.15, 0.3) },
	Antenna = { size = Vector3.new(0.25, 2.2, 0.25) },
	Rune = { size = Vector3.new(0.9, 1.3, 0.4) },
	Wood = { size = Vector3.new(2, 0.6, 0.6), shape = Enum.PartType.Cylinder },
	Scrap = { size = Vector3.new(1.2, 0.5, 1) },
	Herb = { size = Vector3.new(0.9, 0.9, 0.9), shape = Enum.PartType.Ball },
	Gunpowder = { size = Vector3.new(0.9, 1, 0.9) },
	Cloth = { size = Vector3.new(1.3, 0.3, 1.1) },
}

local function randomForestSpot(): Vector3
	local half = map.HalfSize - 15
	for _ = 1, 30 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if map.isOpenSpot(pos) then
			-- 바닥 높이 찾기 (지붕 위나 나무 위는 피함)
			local result = Workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -80, 0))
			if result and result.Position.Y < 2 then
				return result.Position + Vector3.new(0, 0.6, 0)
			end
		end
	end
	return Vector3.new(0, 0.6, 150)
end

local function spawnItem(itemId: string, position: Vector3, respawn: boolean)
	if not folder then
		return
	end
	local def = Items.defs[itemId]
	local look = SHAPES[itemId] or { size = Vector3.new(1, 1, 1) }
	local isQuest = def.kind == "Quest"
	local myGeneration = generation

	local part = Instance.new("Part")
	part.Name = itemId
	if look.shape then
		part.Shape = look.shape
	end
	part.Size = look.size
	part.Anchored = true
	part.CanCollide = false
	part.Color = def.color
	part.Material = if isQuest then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	part:SetAttribute("Spin", isQuest) -- 클라이언트가 탈출 부품을 빙글빙글 돌림

	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = if isQuest then 16 else 6
	light.Brightness = if isQuest then 1.5 else 0.8
	light.Parent = part

	if isQuest then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(def.color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.2)
		sparkle.Lifetime = NumberRange.new(1)
		sparkle.Rate = 4
		sparkle.Speed = NumberRange.new(1)
		sparkle.Parent = part
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "줍기"
	prompt.ObjectText = def.name
	prompt.HoldDuration = if isQuest then 0.6 else 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player: Player)
		if part.Parent == nil or player:GetAttribute("InRound") ~= true or player:GetAttribute("Hiding") == true then
			return
		end
		part:Destroy()
		Inventory.add(player, itemId, 1)
		if isQuest then
			notify:FireClient(player, ("%s 획득! — %s"):format(def.name, def.desc))
		else
			notify:FireClient(player, def.name .. " +1")
		end
		if respawn then
			local matDef = Config.Materials[itemId]
			task.delay(matDef and matDef.RespawnTime or 60, function()
				if generation == myGeneration then
					spawnItem(itemId, randomForestSpot(), true)
				end
			end)
		end
	end)

	part.Parent = folder
end

local function shuffled(list: { Vector3 }): { Vector3 }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function spawnNotes()
	local notes = Instance.new("Folder")
	notes.Name = "Notes"
	for _, note in Story.Notes do
		local pos = map.NoteSpots[note.place]
		if pos then
			local paper = Instance.new("Part")
			paper.Name = "Note_" .. note.id
			paper.Size = Vector3.new(1.2, 0.05, 1.6)
			paper.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			paper.Color = Color3.fromRGB(235, 225, 190)
			paper.Material = Enum.Material.Fabric
			paper.Anchored = true
			paper.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 240, 200)
			light.Range = 5
			light.Brightness = 0.6
			light.Parent = paper
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "읽기"
			prompt.ObjectText = note.title
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = paper
			prompt.Triggered:Connect(function(player)
				showNote:FireClient(player, note.id)
			end)
			paper.Parent = notes
		end
	end
	notes.Parent = map.Folder
end

function Pickups.init(mapInfo)
	map = mapInfo
	spawnNotes()
end

-- 라운드 시작: 모두 지우고 새로 뿌림
function Pickups.reset()
	Pickups.clear()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Pickups"
	newFolder.Parent = Workspace
	folder = newFolder

	-- 탈출 부품 (장소 후보에서 겹치지 않게)
	for itemId, rule in Story.QuestItems do
		local candidates = {}
		for _, place in rule.places do
			for _, pos in map.Spots[place] or {} do
				table.insert(candidates, pos)
			end
		end
		candidates = shuffled(candidates)
		for i = 1, rule.count do
			local pos = candidates[i] or randomForestSpot()
			spawnItem(itemId, pos + Vector3.new(0, 0.4, 0), false)
		end
	end

	-- 재료
	for itemId, rule in Config.Materials do
		for _ = 1, rule.Count do
			spawnItem(itemId, randomForestSpot(), true)
		end
	end
	-- 캠프/건물 안에 재료 조금 더
	for _, place in { "Cabin", "Sawmill", "GasShed", "Junk", "Camp" } do
		for _, pos in map.Spots[place] or {} do
			if rng:NextNumber() < 0.5 then
				local mats = { "Scrap", "Wood", "Gunpowder", "Cloth", "Herb" }
				spawnItem(mats[rng:NextInteger(1, #mats)], pos + Vector3.new(rng:NextNumber(-1, 1), 0.3, rng:NextNumber(-1, 1)), false)
			end
		end
	end
end

function Pickups.clear()
	generation += 1
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- 죽은 자리에 탈출 부품 떨어뜨리기
function Pickups.dropQuestItems(player: Player, position: Vector3)
	for _, itemId in Items.order do
		if Items.defs[itemId].kind == "Quest" then
			local count = Inventory.get(player, itemId)
			for _ = 1, count do
				spawnItem(itemId, position + Vector3.new(rng:NextNumber(-3, 3), 0.8, rng:NextNumber(-3, 3)), false)
			end
			if count > 0 then
				Inventory.set(player, itemId, 0)
				notify:FireAllClients(("%s이(가) %s을(를) 떨어뜨렸다"):format(player.DisplayName, Items.defs[itemId].name))
			end
		end
	end
end

return Pickups
