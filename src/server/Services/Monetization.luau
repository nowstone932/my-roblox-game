-- 수익화(로벅스 상점)의 서버 쪽
--
--   게임패스   : 한 번 사면 계속 가짐 (스타터 키트, 추적기, 변신, 손전등 색)
--   개발자 상품: 살 때마다 1개 (부활, 섬광탄 묶음, 건전지 묶음, 팀 보급 상자)
--
-- 대기실 서버에서 산 소모품은 숲(전용 서버)에서 써야 하므로 "보관함"에 저장해 둡니다 (DataStore).
--   - 판이 시작되면 보관함에서 종류마다 1개씩 꺼내 줍니다 (한 판에 한 묶음).
--   - 판 도중에 사면 바로 줍니다. 이번 판에 이미 그 종류를 받았으면 다음 판으로 넘어가요.
--   - 산 물건은 서버가 바뀌어도, 게임을 껐다 켜도 남아 있어요.
--
-- 클라이언트가 읽는 플레이어 속성:
--   Pass_StarterKit / Pass_Tracker / Pass_Disguise / Pass_LightColor (true = 가짐)
--   Stock_Flashbang / Stock_Cell / Stock_Crate (보관함 개수)
--   LightColor (불빛 색 이름), RevivesUsed (이번 판에 쓴 로벅스 부활), RoundSerial (판에 들어갈 때마다 +1)
--
-- Config.Monetization 의 ID가 0인 물건은 꺼져 있습니다. ID 만드는 법: docs/상점_설정.md
-- Studio에서는 "게임 설정 > 보안 > Studio의 API 서비스 접근 허용"을 켜야 보관함이 저장돼요.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)

local M = Config.Monetization
local S = Config.Shop
local notify = Remotes.get("LobbyNotify") -- 구매 안내는 대기실에서도 보이게

local Monetization = {}

local PASSES = {
	StarterKit = M.StarterKitPassId,
	Tracker = M.TrackerPassId,
	Disguise = M.DisguisePassId,
	LightColor = M.LightColorPassId,
}
local PASS_NAMES = {
	StarterKit = "스타터 키트",
	Tracker = "숲지기 추적기",
	Disguise = "숲지기 변신",
	LightColor = "손전등 불빛 색",
}
local STOCK_KEYS = { "Flashbang", "Cell", "Crate" }
local MAX_RECEIPTS = 40 -- 중복 지급을 막으려고 기억해 두는 최근 영수증 수

type Data = { stock: { [string]: number }, lightColor: string, receipts: { string } }

local store: DataStore? = nil
local cache: { [Player]: Data } = {}
local loaded: { [Player]: boolean } = {}
local owns: { [Player]: { [string]: boolean } } = {}
local usedThisRound: { [Player]: { [string]: boolean } } = {}
-- 저장소를 못 쓸 때(Studio 등) 이 서버에서만 기억하는 영수증
local sessionReceipts: { [string]: boolean } = {}

local reviveHandler: ((Player) -> boolean)? = nil

local function studioOwnsAll(): boolean
	return M.StudioOwnsAllPasses == true and RunService:IsStudio()
end

local function validColor(id: any): boolean
	for _, info in S.LightColors do
		if info.id == id then
			return true
		end
	end
	return false
end

-- 저장된 값이 이상해도 항상 올바른 모양으로 고쳐서 돌려줌
local function sanitize(raw: any): Data
	local data: Data = { stock = {}, lightColor = "Default", receipts = {} }
	local rawStock = if typeof(raw) == "table" and typeof(raw.stock) == "table" then raw.stock else {}
	for _, key in STOCK_KEYS do
		local n = rawStock[key]
		data.stock[key] = if typeof(n) == "number" and n == n then math.clamp(math.floor(n), 0, 9999) else 0
	end
	if typeof(raw) == "table" then
		if validColor(raw.lightColor) then
			data.lightColor = raw.lightColor
		end
		if typeof(raw.receipts) == "table" then
			for _, id in raw.receipts do
				if typeof(id) == "string" then
					table.insert(data.receipts, id)
				end
			end
		end
	end
	return data
end

local function storeKey(userId: number): string
	return "shop_" .. userId
end

local function publish(player: Player)
	local data = cache[player]
	if not data or player.Parent ~= Players then
		return
	end
	for _, key in STOCK_KEYS do
		player:SetAttribute("Stock_" .. key, data.stock[key])
	end
	player:SetAttribute("LightColor", data.lightColor)
end

-- 저장소의 값을 안전하게 바꿈. change 가 false 를 돌려주면 아무것도 안 바꿈.
-- 돌려주는 값: 저장소와 통신이 됐는지, change 가 실제로 적용됐는지
local function update(userId: number, change: (Data) -> boolean): (boolean, boolean)
	if not store then
		return false, false
	end
	local applied = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(storeKey(userId), function(old)
			local data = sanitize(old)
			applied = change(data)
			if applied then
				return data
			end
			return nil
		end)
	end)
	if not ok then
		warn("[상점] 저장소 오류:", err)
		return false, false
	end
	return true, applied
end

local function load(player: Player)
	local data = sanitize(nil)
	if store then
		local ok, raw = pcall(function()
			return (store :: DataStore):GetAsync(storeKey(player.UserId))
		end)
		if ok then
			data = sanitize(raw)
		else
			warn("[상점] 보관함을 불러오지 못했어요:", raw)
		end
	end
	if player.Parent ~= Players then
		return
	end
	-- 불러오는 사이에 산 물건이 있으면 더해 줌
	local early = cache[player]
	if early then
		for _, key in STOCK_KEYS do
			data.stock[key] = math.max(data.stock[key], early.stock[key])
		end
	end
	cache[player] = data
	loaded[player] = true
	publish(player)
end

local function checkPasses(player: Player)
	local mine: { [string]: boolean } = {}
	owns[player] = mine
	for id, passId in PASSES do
		local has = false
		if studioOwnsAll() then
			has = true
		elseif passId ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			has = ok and result == true
		end
		if player.Parent ~= Players then
			return
		end
		mine[id] = has
		player:SetAttribute("Pass_" .. id, has)
	end
end

-- 게임패스를 가졌는지 ("StarterKit" | "Tracker" | "Disguise" | "LightColor")
function Monetization.owns(player: Player, passName: string): boolean
	local mine = owns[player]
	return mine ~= nil and mine[passName] == true
end

---------------------------------------------------------------------------
-- 보관함 물건 꺼내 쓰기
---------------------------------------------------------------------------
local function roundPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InRound") == true and p:GetAttribute("Escaped") ~= true then
			table.insert(list, p)
		end
	end
	return list
end

local function inLiveRound(player: Player): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == "Playing" and player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true
end

local function give(player: Player, key: string)
	if key == "Flashbang" then
		Inventory.add(player, "Flashbang", S.FlashbangPack)
		notify:FireClient(player, ("상점: 섬광탄 %d개를 받았다"):format(S.FlashbangPack))
	elseif key == "Cell" then
		Inventory.add(player, "Cell", S.CellPack)
		notify:FireClient(player, ("상점: 건전지 %d개를 받았다"):format(S.CellPack))
	elseif key == "Crate" then
		for _, mate in roundPlayers() do
			Inventory.add(mate, "Medkit", S.CrateMedkit)
			Inventory.add(mate, "Cell", S.CrateCell)
			notify:FireClient(mate, ("%s의 보급 상자: 붕대 %d개 + 건전지 %d개"):format(player.DisplayName, S.CrateMedkit, S.CrateCell))
		end
	end
end

-- 보관함에서 1개 꺼냄 (저장까지 성공해야 true)
local function consume(player: Player, key: string): boolean
	local data = cache[player]
	if not data or data.stock[key] < 1 then
		return false
	end
	data.stock[key] -= 1 -- 먼저 빼 둠 (저장하는 사이에 두 번 꺼내지 않게)
	publish(player)
	if not store then
		return true
	end
	local ok, applied = update(player.UserId, function(saved)
		if saved.stock[key] < 1 then
			return false
		end
		saved.stock[key] -= 1
		return true
	end)
	if ok and applied then
		return true
	end
	if cache[player] == data then
		-- 저장 실패: 되돌려 놓음. 저장소에 실제로 없었던 경우(applied = false)는 0으로 맞춤
		data.stock[key] = if ok then 0 else data.stock[key] + 1
		publish(player)
	end
	return false
end

-- 이번 판에 아직 안 받은 종류면 보관함에서 꺼내 바로 줌
local function tryUse(player: Player, key: string): boolean
	if not inLiveRound(player) then
		return false
	end
	local used = usedThisRound[player]
	if not used then
		used = {}
		usedThisRound[player] = used
	end
	if used[key] then
		return false
	end
	used[key] = true
	if not consume(player, key) then
		used[key] = nil
		return false
	end
	if player.Parent == Players and inLiveRound(player) then
		give(player, key)
	end
	return true
end

-- 라운드가 시작될 때(숲에 들어갈 때) GameLoop가 불러줍니다.
function Monetization.applyRoundPerks(player: Player)
	usedThisRound[player] = {}
	player:SetAttribute("RevivesUsed", 0)
	local serial = (player:GetAttribute("RoundSerial") or 0) + 1
	player:SetAttribute("RoundSerial", serial)

	if Monetization.owns(player, "StarterKit") then
		Inventory.add(player, "FlareGun", 1)
		Inventory.add(player, "Axe", 1)
		Inventory.add(player, "Ammo", M.StarterKitAmmo)
		notify:FireClient(player, ("스타터 키트: 조명탄 총 + 손도끼 + 조명탄 %d발"):format(M.StarterKitAmmo))
	end

	task.spawn(function()
		-- 보관함을 다 불러올 때까지 잠깐 기다림 (숲 서버에 막 도착했을 때)
		local deadline = os.clock() + 10
		while not loaded[player] and os.clock() < deadline and player.Parent == Players do
			task.wait(0.25)
		end
		if player:GetAttribute("RoundSerial") ~= serial then
			return
		end
		tryUse(player, "Flashbang")
		tryUse(player, "Cell")
		-- 보급 상자는 팀원이 모두 숲에 들어온 뒤에 나눠 줌
		task.wait(3)
		if player:GetAttribute("RoundSerial") == serial then
			tryUse(player, "Crate")
		end
	end)
end

---------------------------------------------------------------------------
-- 개발자 상품 영수증 처리
---------------------------------------------------------------------------
local PRODUCT_NAMES = { Flashbang = "섬광탄 묶음", Cell = "건전지 묶음", Crate = "팀 보급 상자" }

-- 상품 ID -> 종류 ("Revive" 또는 보관함 이름)
local products: { [number]: string } = {}
for productId, kind in { [M.ReviveProductId] = "Revive", [M.FlashbangPackProductId] = "Flashbang", [M.CellPackProductId] = "Cell", [M.SupplyCrateProductId] = "Crate" } do
	if productId ~= 0 then
		products[productId] = kind
	end
end

-- 보관함에 1개 넣음. 같은 영수증은 한 번만 처리. 돌려주는 값: 지급이 끝났는지(이미 처리된 영수증 포함)
local function addStock(userId: number, key: string, purchaseId: string): boolean
	local player = Players:GetPlayerByUserId(userId)
	local isNew = false
	if store then
		local ok, applied = update(userId, function(saved)
			if table.find(saved.receipts, purchaseId) then
				return false
			end
			saved.stock[key] += 1
			table.insert(saved.receipts, purchaseId)
			while #saved.receipts > MAX_RECEIPTS do
				table.remove(saved.receipts, 1)
			end
			return true
		end)
		if not ok then
			return false -- 저장 실패: Roblox가 나중에 다시 물어봄
		end
		isNew = applied
	else
		if not player then
			return false
		end
		isNew = not sessionReceipts[purchaseId]
		sessionReceipts[purchaseId] = true
	end
	if isNew and player then
		local data = cache[player]
		if not data then
			data = sanitize(nil)
			cache[player] = data
		end
		data.stock[key] += 1
		publish(player)
		if not tryUse(player, key) then
			notify:FireClient(player, ("상점: %s을(를) 보관함에 넣었다. 다음 판을 시작할 때 받는다"):format(PRODUCT_NAMES[key]))
		end
	end
	return true
end

local function processReceipt(info)
	local kind = products[info.ProductId]
	if not kind then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)

	if kind == "Revive" then
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if sessionReceipts[purchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local used = player:GetAttribute("RevivesUsed") or 0
		if used < S.RevivesPerRound and reviveHandler then
			local ok, revived = pcall(reviveHandler, player)
			if ok and revived then
				sessionReceipts[purchaseId] = true
				player:SetAttribute("RevivesUsed", used + 1)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		-- 부활할 수 없는 상황(이미 살아 있음, 판이 끝남, 이번 판에 이미 부활함): 섬광탄 묶음으로 바꿔 줌
		if addStock(info.PlayerId, "Flashbang", purchaseId) then
			notify:FireClient(player, "부활할 수 없는 상황이라 섬광탄 묶음으로 바꿔 드렸어요")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if addStock(info.PlayerId, kind, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------
-- 손전등 불빛 색 고르기
---------------------------------------------------------------------------
local function onShopSet(player: Player, what: any, value: any)
	if what ~= "LightColor" or not validColor(value) or not Monetization.owns(player, "LightColor") then
		return
	end
	local data = cache[player]
	if not data or data.lightColor == value then
		return
	end
	data.lightColor = value
	publish(player)
	task.delay(3, function()
		-- 여러 번 눌렀으면 마지막 색만 저장
		if cache[player] == data and data.lightColor == value then
			update(player.UserId, function(saved)
				if saved.lightColor == value then
					return false
				end
				saved.lightColor = value
				return true
			end)
		end
	end)
end

function Monetization.init(options: { onRevive: (Player) -> boolean })
	reviveHandler = options.onRevive

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Shop_v1")
	end)
	if ok then
		store = result
	else
		warn("[상점] 저장소를 열 수 없어요 (산 소모품이 이 서버에서만 유지됩니다):", result)
	end

	local function onPlayer(player: Player)
		cache[player] = cache[player] or sanitize(nil)
		task.spawn(checkPasses, player)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		loaded[player] = nil
		owns[player] = nil
		usedThisRound[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for id, configuredId in PASSES do
			if configuredId ~= 0 and configuredId == passId then
				local mine = owns[player]
				if mine then
					mine[id] = true
				end
				player:SetAttribute("Pass_" .. id, true)
				notify:FireClient(player, ("%s 구매 완료!"):format(PASS_NAMES[id]))
			end
		end
	end)

	Remotes.get("ShopSet").OnServerEvent:Connect(onShopSet)
	MarketplaceService.ProcessReceipt = processReceipt
end

return Monetization
