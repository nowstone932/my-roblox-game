-- 플레이어 인벤토리.
-- 아이템 개수는 플레이어의 Attribute(속성)에 저장합니다.
-- 서버가 Attribute를 바꾸면 클라이언트에 자동으로 전달되어 가방 UI가 바로 갱신돼요.
-- 도구(Tool) 종류는 Tools.luau 가 개수에 맞춰 핫바에 실제 아이템을 넣고 뺍니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)

local Inventory = {}

local listeners: { (Player, string) -> () } = {}

-- 개수가 바뀔 때마다 불릴 함수 등록
function Inventory.onChanged(callback: (Player, string) -> ())
	table.insert(listeners, callback)
end

function Inventory.get(player: Player, key: string): number
	return player:GetAttribute(key) or 0
end

function Inventory.set(player: Player, key: string, amount: number)
	player:SetAttribute(key, math.max(0, amount))
	for _, callback in listeners do
		task.spawn(callback, player, key)
	end
end

function Inventory.add(player: Player, key: string, amount: number)
	Inventory.set(player, key, Inventory.get(player, key) + amount)
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
	for _, key in Items.order do
		Inventory.set(player, key, 0)
	end
end

return Inventory
