-- 제작, 총 발사, 아이템 사용을 서버에서 처리합니다.
-- 클라이언트는 "이거 하고 싶어요"라고 요청만 하고, 진짜 판정은 전부 서버가 합니다.
-- (클라이언트를 믿으면 해킹으로 무한 탄약 같은 게 가능해지기 때문)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local MonsterAI = require(script.Parent.MonsterAI)

local notify = Remotes.get("Notify")
local effect = Remotes.get("Effect")

local Combat = {}

local lastFire: { [Player]: number } = {}

local function aliveParts(player: Player): (Model?, Humanoid?, BasePart?)
	if player:GetAttribute("InRound") ~= true then
		return nil, nil, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if char and hum and hum.Health > 0 and head and head:IsA("BasePart") then
		return char, hum, head
	end
	return nil, nil, nil
end

local function onCraft(player: Player, recipeId: any)
	if typeof(recipeId) ~= "string" then
		return
	end
	local recipe = Recipes.byId[recipeId]
	if not recipe or player:GetAttribute("InRound") ~= true then
		return
	end
	if recipe.unique and Inventory.get(player, recipe.item) > 0 then
		notify:FireClient(player, "이미 " .. recipe.name .. "을(를) 가지고 있어요")
		return
	end
	if not Inventory.take(player, recipe.cost) then
		notify:FireClient(player, "재료가 부족해요")
		return
	end
	Inventory.add(player, recipe.item, recipe.amount)
	notify:FireClient(player, "제작 완료: " .. recipe.name)
end

local function onFire(player: Player, origin: any, direction: any)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.01 or direction.Magnitude ~= direction.Magnitude then
		return
	end
	local char, _, head = aliveParts(player)
	if not (char and head) then
		return
	end
	if Inventory.get(player, "FlareGun") < 1 then
		return
	end
	local now = os.clock()
	if now - (lastFire[player] or 0) < Config.Weapon.FireCooldown then
		return
	end
	if Inventory.get(player, "Ammo") < 1 then
		notify:FireClient(player, "탄약이 없어요! (고철 1 + 화약 1)")
		return
	end
	lastFire[player] = now
	Inventory.add(player, "Ammo", -1)

	-- 클라이언트가 보낸 시작점이 머리에서 너무 멀면 머리 위치를 대신 씀
	if (origin - head.Position).Magnitude > 8 then
		origin = head.Position
	end
	local ray = direction.Unit * Config.Weapon.Range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = Workspace:Raycast(origin, ray, params)

	local hitPos = if result then result.Position else origin + ray
	if result and MonsterAI.isMonsterPart(result.Instance) then
		MonsterAI.damage(Config.Weapon.Damage, player)
		effect:FireClient(player, "HitMarker")
	end
	effect:FireAllClients("Shot", origin, hitPos)
end

local function onUseItem(player: Player, itemName: any)
	local char, hum, head = aliveParts(player)
	if not (char and hum and head) then
		return
	end

	if itemName == "Flashbang" then
		if not Inventory.take(player, { Flashbang = 1 }) then
			notify:FireClient(player, "섬광탄이 없어요")
			return
		end
		effect:FireAllClients("Flash", head.Position, Config.Flashbang.Radius)
		if MonsterAI.distanceTo(head.Position) <= Config.Flashbang.Radius then
			MonsterAI.stun(Config.Flashbang.StunTime)
			notify:FireClient(player, ("괴물이 %d초 동안 기절했다!"):format(Config.Flashbang.StunTime))
		end
	elseif itemName == "Medkit" then
		if hum.Health >= hum.MaxHealth then
			notify:FireClient(player, "체력이 이미 가득해요")
			return
		end
		if not Inventory.take(player, { Medkit = 1 }) then
			notify:FireClient(player, "붕대가 없어요")
			return
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + Config.Medkit.Heal)
		notify:FireClient(player, "체력 회복!")
	end
end

function Combat.init()
	Remotes.get("Craft").OnServerEvent:Connect(onCraft)
	Remotes.get("Fire").OnServerEvent:Connect(onFire)
	Remotes.get("UseItem").OnServerEvent:Connect(onUseItem)
	Players.PlayerRemoving:Connect(function(player)
		lastFire[player] = nil
	end)
end

return Combat
