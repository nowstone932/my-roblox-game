-- 화면 UI(HUD)를 코드로 만듭니다.
-- 나중에 Studio에서 예쁜 UI를 직접 만들면 이 파일을 교체하면 돼요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local topLabel: TextLabel
local inventoryLabel: TextLabel
local crosshair: TextLabel
local notifyList: Frame
local craftPanel: Frame
local dangerFrame: Frame
local flashFrame: Frame
local deadPanel: Frame

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(230, 230, 230)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 18
	l.TextStrokeTransparency = 0.5
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 16
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	for k, v in props do
		(b :: any)[k] = v
	end
	return b
end

local function costText(cost: { [string]: number }): string
	local parts = {}
	for key, amount in cost do
		table.insert(parts, ("%s %d"):format(Config.ItemNames[key] or key, amount))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

export type Callbacks = {
	craft: (recipeId: string) -> (),
	buyProduct: (productId: number) -> (),
}

function Hud.init(callbacks: Callbacks)
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	dangerFrame = Instance.new("Frame")
	dangerFrame.Name = "Danger"
	dangerFrame.Size = UDim2.fromScale(1, 1)
	dangerFrame.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	dangerFrame.BackgroundTransparency = 1
	dangerFrame.BorderSizePixel = 0
	dangerFrame.Parent = gui

	flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 10
	flashFrame.Parent = gui

	topLabel = label({
		Name = "Round",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(500, 30),
		TextSize = 22,
		Parent = gui,
	})

	crosshair = label({
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		Text = "+",
		TextSize = 26,
		Parent = gui,
	})

	inventoryLabel = label({
		Name = "Inventory",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -60),
		Size = UDim2.fromOffset(260, 220),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextSize = 17,
		Parent = gui,
	})

	label({
		Name = "Controls",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(700, 24),
		Text = "[E] 줍기   [C] 제작   [1~4] 빠른 제작   [클릭] 발사   [F] 손전등   [G] 섬광탄   [H] 붕대",
		TextSize = 14,
		TextTransparency = 0.3,
		Parent = gui,
	})

	notifyList = Instance.new("Frame")
	notifyList.Name = "Notifications"
	notifyList.AnchorPoint = Vector2.new(1, 0)
	notifyList.Position = UDim2.new(1, -16, 0, 90)
	notifyList.Size = UDim2.fromOffset(360, 300)
	notifyList.BackgroundTransparency = 1
	notifyList.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 4)
	layout.Parent = notifyList

	-- 제작 창
	craftPanel = Instance.new("Frame")
	craftPanel.Name = "Craft"
	craftPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	craftPanel.Position = UDim2.fromScale(0.5, 0.5)
	craftPanel.Size = UDim2.fromOffset(440, 380)
	craftPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	craftPanel.BackgroundTransparency = 0.1
	craftPanel.Visible = false
	craftPanel.ZIndex = 5
	craftPanel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = craftPanel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = craftPanel
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Padding = UDim.new(0, 8)
	panelLayout.Parent = craftPanel

	label({
		Text = "제작  (C로 닫기)",
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 22,
		LayoutOrder = 0,
		ZIndex = 6,
		Parent = craftPanel,
	})

	for i, recipe in Recipes.list do
		local b = button({
			Name = recipe.id,
			Size = UDim2.new(1, 0, 0, 52),
			Text = ("%d. %s  —  %s\n%s"):format(i, recipe.name, costText(recipe.cost), recipe.desc),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = craftPanel,
		})
		b.Activated:Connect(function()
			callbacks.craft(recipe.id)
		end)
	end

	-- 상점 버튼 (ID가 설정된 것만 보임)
	local M = Config.Monetization
	if M.FlashbangPackProductId ~= 0 then
		local shop = button({
			Name = "BuyFlashbangs",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(0, 120, 60),
			Text = "섬광탄 3개 구매 (로벅스)",
			LayoutOrder = 100,
			ZIndex = 6,
			Parent = craftPanel,
		})
		shop.Activated:Connect(function()
			callbacks.buyProduct(M.FlashbangPackProductId)
		end)
	end

	-- 이 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다 (Modal)
	local close = button({
		Name = "Close",
		Size = UDim2.new(1, 0, 0, 34),
		Text = "닫기",
		Modal = true,
		LayoutOrder = 200,
		ZIndex = 6,
		Parent = craftPanel,
	})
	close.Activated:Connect(function()
		Hud.setCraftOpen(false)
	end)

	-- 죽었을 때 화면
	deadPanel = Instance.new("Frame")
	deadPanel.Name = "Dead"
	deadPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	deadPanel.Position = UDim2.fromScale(0.5, 0.4)
	deadPanel.Size = UDim2.fromOffset(420, 140)
	deadPanel.BackgroundTransparency = 1
	deadPanel.Visible = false
	deadPanel.Parent = gui
	label({
		Size = UDim2.new(1, 0, 0, 50),
		Text = "괴물에게 당했다...",
		TextColor3 = Color3.fromRGB(220, 40, 40),
		TextSize = 34,
		Parent = deadPanel,
	})
	label({
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "다음 라운드에 다시 시작합니다",
		Parent = deadPanel,
	})
	if M.ReviveProductId ~= 0 then
		local revive = button({
			Position = UDim2.fromOffset(110, 90),
			Size = UDim2.fromOffset(200, 40),
			BackgroundColor3 = Color3.fromRGB(0, 120, 60),
			Text = "지금 부활하기 (로벅스)",
			Modal = true,
			Parent = deadPanel,
		})
		revive.Activated:Connect(function()
			callbacks.buyProduct(M.ReviveProductId)
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	Hud.refresh()
end

function Hud.refresh()
	-- 라운드 정보
	local state = ReplicatedStorage:GetAttribute("RoundState") or "Intermission"
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local timeText = ("%d:%02d"):format(timeLeft // 60, timeLeft % 60)
	if state == "Playing" then
		local placed = ReplicatedStorage:GetAttribute("FusesPlaced") or 0
		local required = ReplicatedStorage:GetAttribute("FusesRequired") or 3
		local goal = if ReplicatedStorage:GetAttribute("GateOpen")
			then "탈출문 열림! 북쪽으로!"
			else ("퓨즈 %d/%d"):format(placed, required)
		local status = if player:GetAttribute("Escaped") then "  (탈출 성공)" else ""
		topLabel.Text = ("%s   ·   %s%s"):format(timeText, goal, status)
	elseif state == "Intermission" then
		topLabel.Text = "곧 라운드가 시작됩니다... " .. timeText
	else
		topLabel.Text = "라운드 종료"
	end

	-- 인벤토리
	local lines = {}
	for _, key in Config.InventoryKeys do
		local amount = player:GetAttribute(key) or 0
		if amount > 0 then
			if key == "FlareGun" then
				table.insert(lines, Config.ItemNames[key])
			else
				table.insert(lines, ("%s  x%d"):format(Config.ItemNames[key], amount))
			end
		end
	end
	inventoryLabel.Text = if #lines > 0 then table.concat(lines, "\n") else "(빈 가방)"
end

local notifyCount = 0
local function nextOrder(): number
	notifyCount += 1
	return notifyCount
end

function Hud.notify(text: string)
	local item = label({
		Size = UDim2.fromOffset(360, 26),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 18,
		LayoutOrder = nextOrder(),
		Parent = notifyList,
	})
	task.delay(4, function()
		local tween = TweenService:Create(item, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		item:Destroy()
	end)
	-- 너무 많이 쌓이지 않게
	local labels = {}
	for _, child in notifyList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 8 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
end

function Hud.isCraftOpen(): boolean
	return craftPanel.Visible
end

function Hud.setCraftOpen(open: boolean)
	craftPanel.Visible = open
end

-- 0(안전) ~ 1(괴물 바로 옆)
function Hud.setDanger(amount: number)
	dangerFrame.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * 0.35
end

function Hud.flash(color: Color3, startTransparency: number, duration: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = startTransparency
	TweenService:Create(flashFrame, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

function Hud.hitMarker()
	crosshair.TextColor3 = Color3.fromRGB(255, 60, 60)
	task.delay(0.15, function()
		crosshair.TextColor3 = Color3.fromRGB(230, 230, 230)
	end)
end

function Hud.setDead(dead: boolean)
	deadPanel.Visible = dead
end

return Hud
