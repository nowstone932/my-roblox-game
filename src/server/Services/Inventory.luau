-- 플레이어 인벤토리.
-- 아이템 개수는 플레이어의 Attribute(속성)에 저장합니다.
-- 서버가 Attribute를 바꾸면 클라이언트에 자동으로 전달되어 HUD가 바로 갱신돼요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Inventory = {}

function Inventory.get(player: Player, key: string): number
	return player:GetAttribute(key) or 0
end

function Inventory.add(player: Player, key: string, amount: number)
	player:SetAttribute(key, math.max(0, Inventory.get(player, key) + amount))
end

function Inventory.has(player: Player, cost: { [string]: number }): boolean
	for key, amount in cost do
		if Inventory.get(player, key) < amount then
			return false
		end
	end
	return true
end

-- 재료가 충분하면 빼고 true, 부족하면 아무것도 안 빼고 false
function Inventory.take(player: Player, cost: { [string]: number }): boolean
	if not Inventory.has(player, cost) then
		return false
	end
	for key, amount in cost do
		Inventory.add(player, key, -amount)
	end
	return true
end

function Inventory.reset(player: Player)
	for _, key in Config.InventoryKeys do
		player:SetAttribute(key, 0)
	end
end

return Inventory
