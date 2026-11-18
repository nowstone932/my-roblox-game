-- 로벅스 상점 창 (화면 왼쪽)
--
--   대기실에서는 항상 왼쪽에 보여요. [B]를 누르면 "조작 중"이 되어 마우스 커서가 나타나고
--   구매 버튼을 누를 수 있어요. 다시 [B](또는 닫기 버튼)를 누르면 커서가 사라집니다.
--   화면을 터치하는 기기에서는 [B] 없이 바로 누를 수 있어요.
--   숲에서는 상점이 보이지 않습니다 (부활 버튼만 죽었을 때 따로 나옴).
--
-- 물건 목록과 설명: Config.Shop.Items / 물건 ID: Config.Monetization
-- 실제 지급은 서버(server/Services/Monetization.luau)가 합니다.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local T = Lang.t

local Shop = {}

local CARD_HEIGHT = 84
local GREEN = Color3.fromRGB(0, 120, 66)
local GREY = Color3.fromRGB(44, 40, 38)
local ORANGE = Color3.fromRGB(150, 72, 30)

type Card = { item: any, name: TextLabel, price: TextLabel, desc: TextLabel, action: TextButton }

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local closeButton: TextButton
local cards: { Card } = {}
local prices: { [string]: number } = {} -- 불러온 진짜 가격 (물건 id -> 로벅스)

local active = false -- 조작 중 (커서가 보임)

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function inLobby(): boolean
	return player:GetAttribute("InLobby") == true
end

local function assetId(item: any): number
	return (Config.Monetization :: any)[item.idKey] or 0
end

local function ownsPass(item: any): boolean
	return player:GetAttribute("Pass_" .. item.id) == true
end

local function colorIndex(): number
	local current = player:GetAttribute("LightColor")
	for i, info in Config.Shop.LightColors do
		if info.id == current then
			return i
		end
	end
	return 1
end

-- 버튼에 쓸 글씨, 누를 수 있는지, 색
local function actionState(item: any): (string, boolean, Color3)
	if item.kind == "Pass" and ownsPass(item) then
		if item.id == "LightColor" then
			return T("색: %s"):format(T(Config.Shop.LightColors[colorIndex()].name)), true, ORANGE
		end
		return T("보유 중"), false, GREY
	end
	if assetId(item) == 0 then
		return T("준비 중"), false, GREY
	end
	if item.id == "Revive" then
		return T("죽었을 때"), false, GREY -- 부활은 숲에서 죽거나 쓰러졌을 때 뜨는 버튼으로 삼
	end
	return T("구매"), true, GREEN
end

local function priceText(item: any): string
	local text = ("R$ %d"):format(prices[item.id] or item.price)
	if item.kind == "Product" and item.id ~= "Revive" then
		local stock = player:GetAttribute("Stock_" .. item.id) or 0
		if stock > 0 then
			text = T("보관 %d개"):format(stock) .. "  ·  " .. text
		end
	end
	return text
end

local function redraw()
	if not gui then
		return
	end
	local lobby = inLobby()
	if not lobby then
		active = false
	end
	panel.Visible = lobby
	panel.BackgroundTransparency = if active then 0.12 else 0.45
	titleLabel.Text = T("상점")
	if not UserInputService.KeyboardEnabled then
		hintLabel.Text = ""
	elseif active then
		hintLabel.Text = T("[B] 닫기")
	else
		hintLabel.Text = T("[B] 마우스로 구매")
	end
	closeButton.Text = T("닫기")
	closeButton.Visible = active
	for _, card in cards do
		card.name.Text = T(card.item.name)
		card.desc.Text = T(card.item.desc)
		card.price.Text = priceText(card.item)
		local text, enabled, color = actionState(card.item)
		card.action.Text = text
		card.action.Active = enabled
		card.action.AutoButtonColor = enabled
		card.action.BackgroundColor3 = color
		card.action.TextTransparency = if enabled then 0 else 0.4
	end
end

local function onAction(item: any)
	local _, enabled = actionState(item)
	if not enabled then
		return
	end
	if item.kind == "Pass" and ownsPass(item) then
		-- 손전등 색: 누를 때마다 다음 색
		local list = Config.Shop.LightColors
		local nextInfo = list[colorIndex() % #list + 1]
		Remotes.get("ShopSet"):FireServer("LightColor", nextInfo.id)
		return
	end
	local id = assetId(item)
	if item.kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

local function buildCard(list: Instance, order: number, item: any)
	local frame = make("Frame", {
		Size = UDim2.new(1, -6, 0, CARD_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(30, 27, 24),
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = list,
	})
	corner(frame, 8)
	make("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingBottom = UDim.new(0, 7), Parent = frame })
	local name = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(240, 228, 205),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local desc = make("TextLabel", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(200, 192, 176),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local price = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -100, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 200, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local action = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(94, 24),
		BackgroundColor3 = GREEN,
		TextColor3 = Color3.fromRGB(245, 245, 245),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Parent = frame,
	})
	corner(action, 6)
	action.Activated:Connect(function()
		onAction(item)
	end)
	table.insert(cards, { item = item, name = name, price = price, desc = desc, action = action })
end

-- Creator Hub에서 정한 진짜 가격을 불러옴 (못 불러오면 Config 의 숫자를 그대로 보여줌)
local function loadPrices()
	for _, item in Config.Shop.Items do
		local id = assetId(item)
		if id ~= 0 then
			task.spawn(function()
				local infoType = if item.kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, infoType)
				end)
				if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
					prices[item.id] = info.PriceInRobux
					redraw()
				end
			end)
		end
	end
end

function Shop.isActive(): boolean
	return active
end

-- [B]: 조작 시작/끝 (대기실에서만)
function Shop.toggle()
	if not inLobby() then
		return
	end
	active = not active
	redraw()
end

function Shop.close()
	if active then
		active = false
		redraw()
	end
end

function Shop.init()
	gui = make("ScreenGui", { Name = "Shop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

	panel = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 10),
		Size = UDim2.new(0, 300, 0.76, 0),
		BackgroundColor3 = Color3.fromRGB(16, 14, 12),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 10)
	make("UISizeConstraint", { MaxSize = Vector2.new(300, 64 + 40 + #Config.Shop.Items * (CARD_HEIGHT + 6)), Parent = panel })
	make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = panel })

	titleLabel = make("TextLabel", {
		Size = UDim2.new(0.4, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(240, 228, 205),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	hintLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		Size = UDim2.new(0.6, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 190, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34 - 38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = list })
	for i, item in Config.Shop.Items do
		buildCard(list, i, item)
	end

	-- Modal 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다 (조작 중일 때만 보임)
	closeButton = make("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -4, 0, 30),
		BackgroundColor3 = GREY,
		TextColor3 = Color3.fromRGB(240, 240, 240),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		Modal = true,
		Visible = false,
		Parent = panel,
	})
	corner(closeButton, 6)
	closeButton.Activated:Connect(Shop.close)

	gui.Parent = player:WaitForChild("PlayerGui")

	player.AttributeChanged:Connect(function(name: string)
		if name == "InLobby" then
			active = false
			redraw()
		elseif name == "LightColor" or name:sub(1, 5) == "Pass_" or name:sub(1, 6) == "Stock_" then
			redraw()
		end
	end)
	Lang.onChanged(redraw)
	redraw()
	loadPrices()
end

return Shop
