-- 제작과 도구 사용을 서버에서 처리합니다.
-- 클라이언트는 "이 도구를 이 방향으로 쓰고 싶어요"라고 요청만 하고, 진짜 판정은 전부 서버가 합니다.
-- (클라이언트를 믿으면 해킹으로 무한 탄약 같은 게 가능해지기 때문)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local MonsterAI = require(script.Parent.MonsterAI)
local Sfx = require(script.Parent.Sfx)
local Tools = require(script.Parent.Tools)

local notify = Remotes.get("Notify")
local effect = Remotes.get("Effect")
local T = Config.Tools

local Combat = {}

local cooldowns: { [Player]: { [string]: number } } = {}

local function ready(player: Player, key: string, seconds: number): boolean
	cooldowns[player] = cooldowns[player] or {}
	local now = os.clock()
	if now - (cooldowns[player][key] or 0) < seconds then
		return false
	end
	cooldowns[player][key] = now
	return true
end

local function alive(player: Player): (Model?, Humanoid?, BasePart?)
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Hiding") == true or player:GetAttribute("Downed") == true then
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

local function raycast(char: Model, origin: Vector3, direction: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return Workspace:Raycast(origin, direction, params)
end

local function swingAnim(char: Model)
	-- 기본 Animate 스크립트가 "toolanim" 값을 보면 휘두르는 동작을 재생합니다.
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.5, function()
			anim:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- 도구별 동작
---------------------------------------------------------------------------
local handlers: { [string]: (Player, Model, Humanoid, BasePart, Vector3, Vector3) -> () } = {}

handlers.FlareGun = function(player, char, _, head, origin, look)
	if not ready(player, "FlareGun", T.FlareGun.Cooldown) then
		return
	end
	if Inventory.get(player, "Ammo") < 1 then
		notify:FireClient(player, "조명탄이 없어요! (제작: 고철 1 + 화약 1)")
		return
	end
	Inventory.add(player, "Ammo", -1)
	local ray = look * T.FlareGun.Range
	local result = raycast(char, origin, ray)
	local hitPos = if result then result.Position else origin + ray
	if result and MonsterAI.isMonsterPart(result.Instance) then
		MonsterAI.damage(T.FlareGun.Damage, player)
		effect:FireClient(player, "HitMarker")
	end
	effect:FireAllClients("Shot", head.Position, hitPos)
	MonsterAI.noise(head.Position, Config.Noise.Gunshot)
end

handlers.Axe = function(player, char, _, _, origin, look)
	if not ready(player, "Axe", T.Axe.Cooldown) then
		return
	end
	swingAnim(char)
	Sfx.all("AxeSwing", origin)
	local result = raycast(char, origin, look * T.Axe.Range)
	if result and MonsterAI.isMonsterPart(result.Instance) then
		MonsterAI.damage(T.Axe.Damage, player)
		effect:FireClient(player, "HitMarker")
	elseif MonsterAI.distanceTo(origin) < T.Axe.Range then
		-- 괴물이 너무 가까워서 레이가 빗나가도 맞은 걸로
		MonsterAI.damage(T.Axe.Damage, player)
		effect:FireClient(player, "HitMarker")
	end
	MonsterAI.noise(origin, Config.Noise.Axe)
end

handlers.Flashbang = function(player, char, _, head, origin, look)
	if not ready(player, "Flashbang", 0.8) then
		return
	end
	if not Inventory.take(player, { Flashbang = 1 }) then
		return
	end
	-- 던지기: 물리로 날아가다가 1.2초 뒤 폭발
	local can = Instance.new("Part")
	can.Shape = Enum.PartType.Cylinder
	can.Size = Vector3.new(1, 0.6, 0.6)
	can.Color = Color3.fromRGB(70, 75, 70)
	can.Material = Enum.Material.Metal
	can.CFrame = CFrame.new(head.Position + look * 2)
	can.CanTouch = false
	can.Parent = Workspace
	can:SetNetworkOwner(nil)
	can.AssemblyLinearVelocity = look * T.Flashbang.ThrowSpeed + Vector3.new(0, 15, 0)
	swingAnim(char)
	task.delay(T.Flashbang.FuseTime, function()
		local pos = can.Position
		can:Destroy()
		effect:FireAllClients("Flash", pos, T.Flashbang.Radius)
		if MonsterAI.distanceTo(pos) <= T.Flashbang.Radius then
			MonsterAI.stun(T.Flashbang.StunTime)
			notify:FireAllClients(("괴물이 빛에 눈이 멀었다! (%d초)"):format(T.Flashbang.StunTime))
		end
	end)
end

handlers.Trap = function(player, char, _, head, _, look)
	if not ready(player, "Trap", 1) then
		return
	end
	-- 앞쪽 바닥에 설치
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local ahead = head.Position + flatLook.Unit * 5
	local down = raycast(char, ahead + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0))
	if not down then
		notify:FireClient(player, "여기엔 설치할 수 없어요")
		return
	end
	if not Inventory.take(player, { Trap = 1 }) then
		return
	end
	local trap = Instance.new("Part")
	trap.Name = "BearTrap"
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.3, 3, 3)
	trap.CFrame = CFrame.new(down.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trap.Color = Color3.fromRGB(110, 110, 115)
	trap.Material = Enum.Material.CorrodedMetal
	trap.Anchored = true
	trap.CanCollide = false
	trap.Parent = Workspace
	MonsterAI.addTrap(trap)
	Sfx.all("TrapSet", trap.Position)
	notify:FireClient(player, "곰덫 설치!")
end

handlers.Medkit = function(player, _, hum, _, _, _)
	if hum.Health >= hum.MaxHealth then
		notify:FireClient(player, "체력이 이미 가득해요")
		return
	end
	if not ready(player, "Medkit", 1) or not Inventory.take(player, { Medkit = 1 }) then
		return
	end
	hum.Health = math.min(hum.MaxHealth, hum.Health + T.Medkit.Heal)
	effect:FireClient(player, "Heal")
end

handlers.SealStake = function(player, _, _, head, _, _)
	if not ready(player, "SealStake", 1) then
		return
	end
	if not MonsterAI.isDowned() then
		notify:FireClient(player, "괴물이 쓰러져 있을 때만 박을 수 있다")
		return
	end
	if MonsterAI.distanceTo(head.Position) > T.SealStake.Range then
		notify:FireClient(player, "더 가까이 가야 한다")
		return
	end
	if Inventory.take(player, { SealStake = 1 }) then
		MonsterAI.seal()
	end
end

---------------------------------------------------------------------------
-- 원격 요청 처리
---------------------------------------------------------------------------
local function onUseTool(player: Player, itemId: any, origin: any, look: any)
	if typeof(itemId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(look) ~= "Vector3" then
		return
	end
	local handler = handlers[itemId]
	if not handler or look.Magnitude < 0.01 or look.Magnitude ~= look.Magnitude then
		return
	end
	local char, hum, head = alive(player)
	if not (char and hum and head) then
		return
	end
	if not Tools.isHolding(player, itemId) or Inventory.get(player, itemId) < 1 then
		return
	end
	-- 클라이언트가 보낸 시작점이 머리에서 너무 멀면 머리 위치를 대신 씀
	if (origin - head.Position).Magnitude > 8 then
		origin = head.Position
	end
	handler(player, char, hum, head, origin, look.Unit)
end

local function onCraft(player: Player, recipeId: any)
	if typeof(recipeId) ~= "string" or player:GetAttribute("InRound") ~= true then
		return
	end
	local recipe = Recipes.byId[recipeId]
	if not recipe then
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
	Sfx.to(player, "Craft")
	local def = Items.defs[recipe.item]
	if def.kind == "Tool" then
		notify:FireClient(player, "제작 완료: " .. recipe.name .. " (핫바에 들어갔어요)")
	else
		notify:FireClient(player, "제작 완료: " .. recipe.name)
	end
end

function Combat.init()
	Remotes.get("Craft").OnServerEvent:Connect(onCraft)
	Remotes.get("UseTool").OnServerEvent:Connect(onUseTool)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return Combat
