-- 수익화(로벅스) 연결부
-- 게임패스: 한 번 사면 영구 (예: 스타터 키트)
-- 개발자 상품: 여러 번 살 수 있는 소모품 (예: 부활, 섬광탄 묶음)
--
-- Config.Monetization 의 ID가 0이면 아무 것도 하지 않습니다.
-- ID 만드는 법은 docs/시작하기.md 의 "수익화" 부분을 보세요.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local M = Config.Monetization
local notify = Remotes.get("Notify")

local Monetization = {}

local ownsStarterKit: { [Player]: boolean } = {}
-- 같은 서버에서 같은 영수증을 두 번 처리하지 않도록 기록
-- TODO: 실제 출시 전에는 DataStore에 저장해서 서버가 바뀌어도 중복 지급이 안 되게 하세요.
local processedReceipts: { [string]: boolean } = {}

local reviveHandler: ((Player) -> boolean)? = nil

local function checkPass(player: Player)
	if M.StarterKitPassId == 0 then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, M.StarterKitPassId)
	ownsStarterKit[player] = ok and owns == true
end

-- 라운드가 시작될 때 GameLoop가 불러줍니다.
function Monetization.applyRoundPerks(player: Player)
	if ownsStarterKit[player] then
		Inventory.add(player, "FlareGun", 1)
		Inventory.add(player, "Axe", 1)
		Inventory.add(player, "Ammo", M.StarterKitAmmo)
		notify:FireClient(player, "스타터 키트: 조명탄 총 + 손도끼 + 조명탄 " .. M.StarterKitAmmo .. "발")
	end
end

-- 상품 ID -> 지급 함수. true를 돌려주면 "지급 완료"
local productHandlers: { [number]: (Player) -> boolean } = {}

if M.FlashbangPackProductId ~= 0 then
	productHandlers[M.FlashbangPackProductId] = function(player)
		Inventory.add(player, "Flashbang", 3)
		notify:FireClient(player, "섬광탄 3개를 받았어요!")
		return true
	end
end

if M.ReviveProductId ~= 0 then
	productHandlers[M.ReviveProductId] = function(player)
		if reviveHandler and reviveHandler(player) then
			return true
		end
		-- 부활할 상황이 아니면(이미 살아있거나 라운드 밖) 대신 섬광탄을 줍니다.
		Inventory.add(player, "Flashbang", 2)
		notify:FireClient(player, "부활할 수 없는 상황이라 섬광탄 2개로 바꿔드렸어요")
		return true
	end
end

local function processReceipt(info)
	if processedReceipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local handler = productHandlers[info.ProductId]
	if not player or not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(handler, player)
	if ok and granted then
		processedReceipts[info.PurchaseId] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Monetization.init(options: { onRevive: (Player) -> boolean })
	reviveHandler = options.onRevive

	Players.PlayerAdded:Connect(checkPass)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPass, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownsStarterKit[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == M.StarterKitPassId then
			ownsStarterKit[player] = true
			notify:FireClient(player, "스타터 키트 구매 완료! 다음 라운드부터 적용돼요")
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return Monetization
