-- 로벅스 상점 (대기실 화면 왼쪽)
--
--   평소에는 닫혀 있고, 대기실 왼쪽에 작은 "상점 [B]" 꼬리표만 보여요.
--   [B]를 누르면 상점 창이 왼쪽에서 밀려 나오고 마우스 커서가 나타납니다.
--   다시 [B](또는 오른쪽 위 X)를 누르면 닫히고 커서가 사라져요.
--   핸드폰/태블릿에서는 오른쪽 위 "상점" 버튼으로 열고 닫아요.
--   숲에서는 상점이 보이지 않습니다 (부활 버튼만 죽었을 때 따로 나옴).
--
--   창 구성: 제목 줄 / 분류 탭(전체, 게임패스, 소모품) / 물건 카드(그림, 이름, 설명, 가격 버튼)
--
-- 물건 목록과 설명: Config.Shop.Items / 물건 ID: Config.Monetization
-- 실제 지급은 서버(server/Services/Monetization.luau)가 합니다.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local T = Lang.t

local Shop = {}

local ROBUX = utf8.char(0xE002) -- Roblox 글꼴에 들어 있는 로벅스 그림 글자
local CARD_HEIGHT = 158
local PANEL_WIDTH = 580

local BG = Color3.fromRGB(18, 15, 13)
local CARD = Color3.fromRGB(34, 29, 25)
local CARD_STROKE = Color3.fromRGB(78, 64, 50)
local AMBER = Color3.fromRGB(230, 150, 60)
local CREAM = Color3.fromRGB(240, 228, 205)
local MUTED = Color3.fromRGB(190, 180, 164)
local GREEN = Color3.fromRGB(38, 160, 84)
local GREY = Color3.fromRGB(58, 52, 47)
local ORANGE = Color3.fromRGB(190, 96, 36)

local TABS = {
	{ id = "All", name = "전체" },
	{ id = "Pass", name = "게임패스" },
	{ id = "Product", name = "소모품" },
}

type Card = {
	item: any,
	frame: Frame,
	stroke: UIStroke,
	name: TextLabel,
	kind: TextLabel,
	tag: TextLabel,
	desc: TextLabel,
	stock: TextLabel,
	action: TextButton,
}

local gui: ScreenGui
local panel: Frame
local launcher: TextButton
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local footerLabel: TextLabel
local list: ScrollingFrame
local grid: UIGridLayout
local tabButtons: { [string]: TextButton } = {}
local cards: { Card } = {}
local prices: { [string]: number } = {} -- 불러온 진짜 가격 (물건 id -> 로벅스)

local active = false -- 열려 있음 (커서가 보임)
local tab = "All"
local shownActive = false

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

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

-- 위는 밝고 아래는 어두운 은은한 광택
local function shade(parent: Instance, bottom: number)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom)),
		Parent = parent,
	})
end

local function inLobby(): boolean
	return player:GetAttribute("InLobby") == true
end

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
			return T("색: %s"):format(T(Config.Shop.LightColors[colorIndex()].name)) .. "  ▸", true, ORANGE
		end
		return "✓  " .. T("보유 중"), false, GREY
	end
	if assetId(item) == 0 then
		return T("준비 중"), false, GREY
	end
	if item.id == "Revive" then
		return T("쓰러졌을 때 구매"), false, GREY -- 부활은 숲에서 죽거나 쓰러졌을 때 뜨는 버튼으로 삼
	end
	return ("%s %d"):format(ROBUX, prices[item.id] or item.price), true, GREEN
end

local function redraw()
	if not gui then
		return
	end
	local lobby = inLobby()
	if not lobby then
		active = false
	end

	-- 열고 닫을 때 왼쪽에서 밀려 나오고 들어감
	if active ~= shownActive then
		shownActive = active
		if active then
			panel.Position = UDim2.new(0, -PANEL_WIDTH, 0.5, 0)
			panel.Visible = true
			TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 16, 0.5, 0) }):Play()
		else
			panel.Visible = false
		end
	end
	launcher.Visible = lobby and not active and not touchOnly()
	launcher.Text = if UserInputService.KeyboardEnabled then "🛒  " .. T("상점") .. "  [B]" else "🛒  " .. T("상점")

	titleLabel.Text = T("상점")
	subtitleLabel.Text = T("수색대 보급소")
	footerLabel.Text = if UserInputService.KeyboardEnabled then T("[B] 닫기   ·   소모품은 다음 판을 시작할 때 받아요") else T("소모품은 다음 판을 시작할 때 받아요")
	for _, info in TABS do
		local b = tabButtons[info.id]
		local selected = tab == info.id
		b.Text = T(info.name)
		b.BackgroundColor3 = if selected then ORANGE else GREY
		b.TextTransparency = if selected then 0 else 0.3
	end

	for _, card in cards do
		local item = card.item
		card.frame.Visible = tab == "All" or tab == item.kind
		card.name.Text = T(item.name)
		card.desc.Text = T(item.desc)
		card.kind.Text = if item.kind == "Pass" then T("게임패스 · 한 번 사면 계속") else T("소모품 · 살 때마다 1개")
		card.tag.Visible = item.tag ~= nil
		if item.tag then
			card.tag.Text = T(item.tag)
		end
		local stock = if item.kind == "Product" and item.id ~= "Revive" then (player:GetAttribute("Stock_" .. item.id) or 0) else 0
		card.stock.Visible = stock > 0
		card.stock.Text = T("보관 %d개"):format(stock)

		local text, enabled, color = actionState(item)
		card.action.Text = text
		card.action.Active = enabled
		card.action.AutoButtonColor = enabled
		card.action.BackgroundColor3 = color
		card.action.TextTransparency = if enabled then 0 else 0.35
		card.stroke.Color = if item.kind == "Pass" and ownsPass(item) then GREEN else CARD_STROKE
	end
end

local function onAction(item: any)
	local _, enabled = actionState(item)
	if not enabled then
		return
	end
	if item.kind == "Pass" and ownsPass(item) then
		-- 손전등 색: 누를 때마다 다음 색
		local colors = Config.Shop.LightColors
		local nextInfo = colors[colorIndex() % #colors + 1]
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

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = if props.BackgroundTransparency == nil then 1 else props.BackgroundTransparency
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or CREAM
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function buildCard(order: number, item: any)
	local frame = make("Frame", { BackgroundColor3 = CARD, LayoutOrder = order, Parent = list })
	corner(frame, 12)
	shade(frame, 0.78)
	local cardStroke = stroke(frame, CARD_STROKE, 1.5)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = frame })

	-- 그림 칸
	local icon = make("Frame", { Size = UDim2.fromOffset(58, 58), BackgroundColor3 = item.tint or ORANGE, Parent = frame })
	corner(icon, 12)
	shade(icon, 0.45)
	text({ Size = UDim2.fromScale(1, 1), Text = item.icon or "", TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = icon })

	local name = text({ Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -68, 0, 20), Font = Enum.Font.GothamBold, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local kind = text({ Position = UDim2.fromOffset(68, 21), Size = UDim2.new(1, -68, 0, 14), TextSize = 11, TextColor3 = AMBER, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })

	-- 딱지(추천, 인기…)와 보관 개수는 그림 아래 줄에 나란히
	local badges = make("Frame", { Position = UDim2.fromOffset(68, 38), Size = UDim2.new(1, -68, 0, 18), BackgroundTransparency = 1, Parent = frame })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = badges })
	local function badge(color: Color3, order: number): TextLabel
		local b = text({
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = order,
			Visible = false,
			Parent = badges,
		})
		corner(b, 9)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
		return b
	end
	local tag = badge(Color3.fromRGB(200, 60, 50), 1)
	local stock = badge(Color3.fromRGB(60, 110, 170), 2)

	local desc = text({
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = MUTED,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})

	local action = make("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = GREEN,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Parent = frame,
	})
	corner(action, 8)
	shade(action, 0.72)
	action.Activated:Connect(function()
		onAction(item)
	end)

	local card: Card = { item = item, frame = frame, stroke = cardStroke, name = name, kind = kind, tag = tag, desc = desc, stock = stock, action = action }
	-- 마우스를 올리면 테두리가 밝아짐
	frame.MouseEnter:Connect(function()
		cardStroke.Color = AMBER
	end)
	frame.MouseLeave:Connect(function()
		cardStroke.Color = if item.kind == "Pass" and ownsPass(item) then GREEN else CARD_STROKE
	end)
	table.insert(cards, card)
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

-- 창이 좁으면(핸드폰 세로 등) 카드를 한 줄에 하나씩
local function layoutGrid()
	local width = list.AbsoluteSize.X
	if width < 430 then
		grid.CellSize = UDim2.new(1, -8, 0, CARD_HEIGHT)
	else
		grid.CellSize = UDim2.new(0.5, -9, 0, CARD_HEIGHT)
	end
end

function Shop.isActive(): boolean
	return active
end

-- [B]: 열기/닫기 (대기실에서만)
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
	gui = make("ScreenGui", { Name = "Shop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

	-- 닫혀 있을 때 대기실 왼쪽에 보이는 꼬리표
	launcher = make("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, -40),
		Size = UDim2.fromOffset(140, 44),
		BackgroundColor3 = ORANGE,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Visible = false,
		Parent = gui,
	})
	corner(launcher, 22)
	shade(launcher, 0.65)
	stroke(launcher, AMBER, 1.5)
	launcher.Activated:Connect(Shop.toggle)

	panel = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.new(1, -32, 0.86, 0),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 16)
	stroke(panel, Color3.fromRGB(150, 90, 40), 2)
	make("UISizeConstraint", { MaxSize = Vector2.new(PANEL_WIDTH, 660), Parent = panel })

	-- 제목 줄
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(120, 58, 22), Parent = panel })
	corner(header, 16)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.3, 0.3, 0.3)),
		Parent = header,
	})
	-- 아래쪽 모서리는 각지게 덮음
	make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = BG, BorderSizePixel = 0, Parent = header })
	text({ Position = UDim2.fromOffset(18, 6), Size = UDim2.fromOffset(40, 40), Text = "🛒", TextSize = 28, Parent = header })
	titleLabel = text({ Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -120, 0, 28), Font = Enum.Font.SpecialElite, TextSize = 28, Parent = header })
	subtitleLabel = text({ Position = UDim2.fromOffset(62, 32), Size = UDim2.new(1, -120, 0, 14), TextSize = 12, TextColor3 = Color3.fromRGB(255, 205, 150), Parent = header })

	-- Modal 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다 (창이 열려 있을 때만 보임)
	local closeButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(170, 50, 40),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Text = "X",
		Modal = true,
		Parent = header,
	})
	corner(closeButton, 8)
	closeButton.Activated:Connect(Shop.close)

	-- 분류 탭
	local tabs = make("Frame", { Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 30), BackgroundTransparency = 1, Parent = panel })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	for i, info in TABS do
		local b = make("TextButton", {
			Size = UDim2.fromOffset(104, 30),
			BackgroundColor3 = GREY,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			LayoutOrder = i,
			Parent = tabs,
		})
		corner(b, 15)
		b.Activated:Connect(function()
			tab = info.id
			list.CanvasPosition = Vector2.zero
			redraw()
		end)
		tabButtons[info.id] = b
	end

	-- 물건 카드
	list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 98),
		Size = UDim2.new(1, -22, 1, -98 - 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = AMBER,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), Parent = list })
	grid = make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -9, 0, CARD_HEIGHT),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	for i, item in Config.Shop.Items do
		buildCard(i, item)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)

	footerLabel = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -8),
		Size = UDim2.new(1, -32, 0, 18),
		TextSize = 12,
		TextColor3 = MUTED,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = panel,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	layoutGrid()

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
