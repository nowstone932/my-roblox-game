-- 주울 수 있는 것들
--   재료: 어울리는 장소(Config.Materials의 places) + 일부는 숲 바닥. 주우면 잠시 뒤 다른 곳에 다시 생김
--   탈출 부품: Story.QuestItems 의 장소 중 매 라운드 무작위 (전기함 속 퓨즈, 열쇠걸이의 열쇠 …)
--   인식표: 실종자 시신 옆. 주우면 그 사람의 마지막 기록이 뜨고 "인식표" 기록이 쌓임
--   쪽지: 고정 위치. E로 읽으면 화면에 내용이 뜸
-- 플레이어가 죽으면 들고 있던 탈출 부품은 그 자리에 떨어집니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
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
local taken: { [string]: boolean } = {} -- 이미 아이템이 놓인 자리

local function key(pos: Vector3): string
	return ("%.1f,%.1f,%.1f"):format(pos.X, pos.Y, pos.Z)
end

local function randomForestSpot(): Vector3
	local half = map.HalfSize - 15
	for _ = 1, 30 do
		local pos = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		if map.isOpenSpot(pos) then
			-- 바닥 높이 찾기 (지붕/나무 위는 피함)
			local result = Workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -80, 0))
			if result and result.Position.Y < 1 then
				return result.Position
			end
		end
	end
	return Vector3.new(0, 0, 150)
end

-- places 중 비어 있는 자리 하나 (없으면 nil)
local function freeSpot(places: { string }): Vector3?
	local candidates = {}
	for _, place in places do
		for _, pos in map.Spots[place] or {} do
			if not taken[key(pos)] then
				table.insert(candidates, pos)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function onPicked(player: Player, itemId: string)
	local def = Items.defs[itemId]
	if def.kind == "Quest" then
		notify:FireClient(player, ("%s 획득! — %s"):format(def.name, def.desc))
	else
		notify:FireClient(player, def.name .. " +1")
	end
end

-- 아이템 하나 놓기. spot은 "표면 위치" (모델 바닥이 여기 닿음)
local function spawnItem(itemId: string, spot: Vector3, onTaken: ((Player) -> ())?, markSpot: boolean?)
	if not folder then
		return
	end
	local def = Items.defs[itemId]
	local isSpecial = def.kind == "Quest" or def.kind == "Collect"
	local model = ItemModels.create(itemId)
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(spot + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
	model:SetAttribute("Spin", def.kind == "Quest")
	if markSpot then
		taken[key(spot)] = true
	end

	-- 어두워도 찾을 수 있게 은은한 빛 (탈출 부품은 더 밝게 + 반짝임)
	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = if isSpecial then 14 else 6
	light.Brightness = if isSpecial then 1.2 else 0.6
	light.Parent = root
	if isSpecial then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(def.color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.15)
		sparkle.Lifetime = NumberRange.new(1)
		sparkle.Rate = 3
		sparkle.Speed = NumberRange.new(0.8)
		sparkle.Parent = root
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "줍기"
	prompt.ObjectText = def.name
	prompt.HoldDuration = if isSpecial then 0.6 else 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		if model.Parent == nil or player:GetAttribute("InRound") ~= true then
			return
		end
		if player:GetAttribute("Hiding") == true or player:GetAttribute("Downed") == true then
			return
		end
		model:Destroy()
		taken[key(spot)] = nil
		if onTaken then
			onTaken(player)
		else
			Inventory.add(player, itemId, 1)
			onPicked(player, itemId)
		end
	end)

	model.Parent = folder
end

local function spawnMaterial(itemId: string)
	local rule = Config.Materials[itemId]
	local spot: Vector3? = nil
	if rng:NextNumber() >= (rule.forest or 0) then
		spot = freeSpot(rule.places or {})
	end
	local markSpot = spot ~= nil
	spot = spot or randomForestSpot()
	local myGeneration = generation
	spawnItem(itemId, spot :: Vector3, function(player)
		Inventory.add(player, itemId, 1)
		onPicked(player, itemId)
		task.delay(rule.RespawnTime, function()
			if generation == myGeneration then
				spawnMaterial(itemId)
			end
		end)
	end, markSpot)
end

local function spawnDogTags()
	local spots = map.Spots.Corpse or {}
	for i, spot in spots do
		local logger = Story.Loggers[i]
		if logger then
			spawnItem("DogTag", spot, function(player)
				Inventory.add(player, "DogTag", 1)
				local stats = player:FindFirstChild("leaderstats")
				local tags = stats and stats:FindFirstChild("인식표")
				if tags and tags:IsA("IntValue") then
					tags.Value += 1
				end
				showNote:FireClient(player, "Logger" .. i)
				notify:FireClient(player, ("인식표 발견: %s (%d/%d)"):format(logger.name, i, #Story.Loggers))
			end, true)
		end
	end
end

local function makeNotePaper(parent: Instance, pos: Vector3, title: string, onRead: (Player) -> ())
	local paper = Instance.new("Part")
	paper.Name = "Note"
	paper.Size = Vector3.new(1.2, 0.05, 1.6)
	paper.CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
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
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = paper
	prompt.Triggered:Connect(onRead)
	paper.Parent = parent
end

function Pickups.init(mapInfo)
	map = mapInfo
	local notes = Instance.new("Folder")
	notes.Name = "Notes"
	for _, note in Story.Notes do
		local pos = map.NoteSpots[note.place]
		if pos then
			makeNotePaper(notes, pos, note.title, function(player)
				showNote:FireClient(player, note.id)
			end)
		end
	end
	notes.Parent = map.Folder
end

-- 라운드 시작: 모두 지우고 새로 뿌림
function Pickups.reset()
	Pickups.clear()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Pickups"
	newFolder.Parent = Workspace
	folder = newFolder

	-- 탈출 부품: 어울리는 장소에만
	for itemId, rule in Story.QuestItems do
		for _ = 1, rule.count do
			local spot = freeSpot(rule.places)
			if spot then
				spawnItem(itemId, spot, nil, true)
			else
				warn(("[Pickups] %s 놓을 자리가 부족합니다 (%s)"):format(itemId, table.concat(rule.places, ", ")))
				spawnItem(itemId, randomForestSpot(), nil, false)
			end
		end
	end

	spawnDogTags()

	for itemId, rule in Config.Materials do
		for _ = 1, rule.Count do
			spawnMaterial(itemId)
		end
	end
end

function Pickups.clear()
	generation += 1
	taken = {}
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- 죽은 자리에 탈출 부품 떨어뜨리기
function Pickups.dropQuestItems(player: Player, position: Vector3)
	local ground = Workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0))
	local base = if ground then ground.Position else Vector3.new(position.X, 0, position.Z)
	for _, itemId in Items.order do
		if Items.defs[itemId].kind == "Quest" then
			local count = Inventory.get(player, itemId)
			for _ = 1, count do
				spawnItem(itemId, base + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), nil, false)
			end
			if count > 0 then
				Inventory.set(player, itemId, 0)
				notify:FireAllClients(("%s이(가) %s을(를) 떨어뜨렸다"):format(player.DisplayName, Items.defs[itemId].name))
			end
		end
	end
end

function Pickups.setupStats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if stats and not stats:FindFirstChild("인식표") then
		local tags = Instance.new("IntValue")
		tags.Name = "인식표"
		tags.Parent = stats
	end
end


return Pickups
