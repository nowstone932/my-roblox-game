-- 화면 UI(HUD)를 코드로 만듭니다.
--   왼쪽 위: 목표(탈출 루트 4개 진행 상황)
--   왼쪽 아래: 가방 (재료, 탈출 부품)
--   화면 아래: 핫바 (Roblox 기본 - 제작한 도구가 들어감)
--   가운데: 제작 창(C), 쪽지, 인트로/엔딩

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Story = require(ReplicatedStorage.Shared.Story)

local player = Players.LocalPlayer

local Hud = {}

local gui: ScreenGui
local topLabel: TextLabel
local objectivesLabel: TextLabel
local bagFrame: Frame
local hidingLabel: TextLabel
local crosshair: TextLabel
local notifyList: Frame
local craftPanel: Frame
local craftButtons: { [string]: TextButton } = {}
local notePanel: Frame
local noteTitle: TextLabel
local noteBody: TextLabel
local storyFrame: Frame
local storyTitle: TextLabel
local storyText: TextLabel
local dangerFrame: Frame
local flashFrame: Frame
local deadPanel: Frame
local staminaBar: Frame

local FONT = Enum.Font.GothamMedium
local STORY_FONT = Enum.Font.SpecialElite

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

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		Font = FONT,
		TextSize = 18,
		TextStrokeTransparency = 0.5,
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	return make("TextLabel", props)
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Color3.fromRGB(40, 40, 48),
		TextColor3 = Color3.fromRGB(240, 240, 240),
		Font = FONT,
		TextSize = 16,
		AutoButtonColor = true,
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local b = make("TextButton", props)
	corner(b, 6)
	return b
end

local function costText(cost: { [string]: number }): string
	local parts = {}
	for key, amount in cost do
		table.insert(parts, ("%s %d"):format(Items.defs[key].name, amount))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function count(key: string): number
	return player:GetAttribute(key) or 0
end

export type Callbacks = {
	craft: (recipeId: string) -> (),
	buyProduct: (productId: number) -> (),
}

function Hud.init(callbacks: Callbacks)
	gui = make("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

	dangerFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	flashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })

	topLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(500, 30), TextSize = 22, Parent = gui })
	crosshair = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Text = "·", TextSize = 34, Parent = gui })
	hidingLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(500, 30), TextSize = 20, TextColor3 = Color3.fromRGB(180, 200, 255), Visible = false, Parent = gui })

	-- 달리기 기력
	local staminaBack = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(160, 5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = gui })
	staminaBar = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 200, 160), BorderSizePixel = 0, Parent = staminaBack })

	-- 목표 패널
	local objFrame = make("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(300, 150), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = gui })
	corner(objFrame, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = objFrame })
	objectivesLabel = label({ Size = UDim2.new(1, -10, 1, -8), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 15, RichText = true, Parent = objFrame })

	-- 가방
	bagFrame = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -90), Size = UDim2.fromOffset(250, 260), BackgroundTransparency = 1, Parent = gui })
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 3), Parent = bagFrame })

	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(420, 60),
		Text = "[E] 줍기/사용   [C] 제작   [1~9] 도구 들기   [클릭] 도구 사용\n[F] 손전등   [Shift] 달리기",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.35,
		Parent = gui,
	})

	notifyList = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 90), Size = UDim2.fromOffset(420, 300), BackgroundTransparency = 1, Parent = gui })
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), Parent = notifyList })

	-- 제작 창
	craftPanel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 520),
		BackgroundColor3 = Color3.fromRGB(18, 16, 14),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	corner(craftPanel, 10)
	make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = craftPanel })
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = craftPanel })
	label({ Text = "제작대  (C로 닫기)", Font = STORY_FONT, Size = UDim2.new(1, 0, 0, 28), TextSize = 24, LayoutOrder = 0, ZIndex = 6, Parent = craftPanel })
	for i, recipe in Recipes.list do
		local b = button({
			Name = recipe.id,
			Size = UDim2.new(1, 0, 0, 52),
			Text = ("  %s  —  %s\n  %s"):format(recipe.name, costText(recipe.cost), recipe.desc),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = craftPanel,
		})
		b.Activated:Connect(function()
			callbacks.craft(recipe.id)
		end)
		craftButtons[recipe.id] = b
	end
	local M = Config.Monetization
	if M.FlashbangPackProductId ~= 0 then
		local shop = button({ Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(0, 110, 60), Text = "섬광탄 3개 구매 (로벅스)", LayoutOrder = 100, ZIndex = 6, Parent = craftPanel })
		shop.Activated:Connect(function()
			callbacks.buyProduct(M.FlashbangPackProductId)
		end)
	end
	-- Modal 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다
	local close = button({ Size = UDim2.new(1, 0, 0, 32), Text = "닫기", Modal = true, LayoutOrder = 200, ZIndex = 6, Parent = craftPanel })
	close.Activated:Connect(function()
		Hud.setCraftOpen(false)
	end)

	-- 쪽지
	notePanel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 440),
		BackgroundColor3 = Color3.fromRGB(226, 214, 180),
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})
	corner(notePanel, 4)
	make("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), Parent = notePanel })
	noteTitle = label({ Size = UDim2.new(1, 0, 0, 34), Font = STORY_FONT, TextSize = 26, TextColor3 = Color3.fromRGB(60, 30, 20), TextStrokeTransparency = 1, ZIndex = 9, Parent = notePanel })
	noteBody = label({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -110),
		Font = STORY_FONT,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(40, 30, 25),
		TextStrokeTransparency = 1,
		ZIndex = 9,
		Parent = notePanel,
	})
	local noteClose = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(140, 34), Text = "닫기", Modal = true, ZIndex = 9, Parent = notePanel })
	noteClose.Activated:Connect(function()
		notePanel.Visible = false
	end)

	-- 인트로/엔딩
	storyFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Parent = gui })
	storyTitle = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.8, 0, 0, 60), Font = STORY_FONT, TextSize = 44, TextColor3 = Color3.fromRGB(230, 60, 50), ZIndex = 16, Parent = storyFrame })
	storyText = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(0.7, 0, 0, 120), Font = STORY_FONT, TextSize = 22, TextWrapped = true, ZIndex = 16, Parent = storyFrame })

	-- 죽었을 때
	deadPanel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(420, 140), BackgroundTransparency = 1, Visible = false, Parent = gui })
	label({ Size = UDim2.new(1, 0, 0, 50), Text = "숲지기에게 당했다…", Font = STORY_FONT, TextColor3 = Color3.fromRGB(220, 40, 40), TextSize = 34, Parent = deadPanel })
	label({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), Text = "다음 라운드에 다시 시작합니다", Parent = deadPanel })
	if M.ReviveProductId ~= 0 then
		local revive = button({ Position = UDim2.fromOffset(110, 90), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = Color3.fromRGB(0, 110, 60), Text = "지금 부활하기 (로벅스)", Modal = true, Parent = deadPanel })
		revive.Activated:Connect(function()
			callbacks.buyProduct(M.ReviveProductId)
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	Hud.refresh()
end

---------------------------------------------------------------------------
-- 갱신
---------------------------------------------------------------------------
local function check(done: boolean): string
	return if done then '<font color="#7CFF8A">✔</font>' else '<font color="#777777">·</font>'
end

local function objectivesText(): string
	local A = function(name: string): any
		return ReplicatedStorage:GetAttribute(name)
	end
	local lines = { '<font size="17"><b>탈출 방법</b></font>' }

	-- 정문
	if A("GateOpen") then
		table.insert(lines, '<font color="#7CFF8A">정문: 열림! 북쪽 출구로</font>')
	else
		table.insert(lines, ("정문: 발전기 퓨즈 %d/%d"):format(A("FusesPlaced") or 0, A("FusesRequired") or 3))
	end

	-- 트럭
	local truck = A("TruckState")
	if truck == "Starting" then
		table.insert(lines, ('<font color="#FFD84A">트럭: 출발까지 %d초! 근처에 있어라</font>'):format(A("TruckTimer") or 0))
	elseif truck == "Ready" then
		table.insert(lines, '<font color="#7CFF8A">트럭: 수리 완료 — 시동 가능</font>')
	elseif truck == "Gone" then
		table.insert(lines, '<font color="#777777">트럭: 떠났다</font>')
	else
		table.insert(lines, ("트럭: %s배터리 %s연료 %s열쇠"):format(check(A("TruckBattery")), check(A("TruckFuel")), check(A("TruckKey"))))
	end

	-- 무전
	local radio = A("RadioState")
	if radio == "Calling" then
		table.insert(lines, ('<font color="#FFD84A">무전: 헬기 도착까지 %d초</font>'):format(A("RescueTimer") or 0))
	elseif radio == "Arrived" then
		table.insert(lines, ('<font color="#7CFF8A">무전: 헬기 도착! 헬기장으로 (%d초)</font>'):format(A("RescueTimer") or 0))
	elseif radio == "Ready" then
		table.insert(lines, '<font color="#7CFF8A">무전: 수리 완료 — 구조 요청 가능</font>')
	elseif radio == "Gone" then
		table.insert(lines, '<font color="#777777">무전: 헬기가 떠났다</font>')
	else
		table.insert(lines, ("무전: 안테나 %d/%d"):format(A("AntennaPlaced") or 0, A("AntennaRequired") or 2))
	end

	-- 봉인
	if count("SealStake") > 0 then
		table.insert(lines, '<font color="#C08CFF">봉인: 말뚝 준비됨 — 괴물을 쓰러뜨려라</font>')
	else
		table.insert(lines, ("봉인: 룬 조각 %d/%d → 봉인 말뚝 제작"):format(count("Rune"), Config.Escape.RunesRequired))
	end
	return table.concat(lines, "\n")
end

local function refreshBag()
	for _, child in bagFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local any = false
	for i, key in Items.order do
		local def = Items.defs[key]
		local n = count(key)
		if def.kind ~= "Tool" and n > 0 then
			any = true
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = if def.kind == "Quest" then 0.35 else 0.6, LayoutOrder = i, Parent = bagFrame })
			corner(row, 4)
			local swatch = make("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = def.color, Parent = row })
			corner(swatch, 3)
			label({
				Position = UDim2.fromOffset(24, 0),
				Size = UDim2.new(1, -28, 1, 0),
				Text = ("%s  x%d"):format(def.name, n),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 15,
				TextColor3 = if def.kind == "Quest" then Color3.fromRGB(255, 225, 120) else Color3.fromRGB(225, 225, 225),
				Parent = row,
			})
		end
	end
	if not any then
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = bagFrame })
		label({ Size = UDim2.fromScale(1, 1), Text = "가방이 비었다", TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.4, TextSize = 15, Parent = row })
	end
end

local function refreshCraft()
	for _, recipe in Recipes.list do
		local b = craftButtons[recipe.id]
		local affordable = true
		for key, amount in recipe.cost do
			if count(key) < amount then
				affordable = false
			end
		end
		if recipe.unique and count(recipe.item) > 0 then
			b.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
			b.TextTransparency = 0.5
		elseif affordable then
			b.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
			b.TextTransparency = 0
		else
			b.BackgroundColor3 = Color3.fromRGB(45, 40, 40)
			b.TextTransparency = 0.25
		end
	end
end

function Hud.refresh()
	local state = ReplicatedStorage:GetAttribute("RoundState") or "Intermission"
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local timeText = ("%d:%02d"):format(timeLeft // 60, timeLeft % 60)
	if state == "Playing" then
		local status = if player:GetAttribute("Escaped") then "   ·   탈출 성공! 다른 사람을 기다리는 중" else ""
		topLabel.Text = "남은 시간 " .. timeText .. status
	elseif state == "Intermission" then
		topLabel.Text = "곧 수색이 시작됩니다… " .. timeText
	else
		topLabel.Text = "라운드 종료"
	end

	objectivesLabel.Text = objectivesText()
	refreshBag()
	refreshCraft()

	local hiding = player:GetAttribute("Hiding") == true
	hidingLabel.Visible = hiding
	if hiding then
		local ends = player:GetAttribute("HideEnds") or os.time()
		hidingLabel.Text = ("옷장에 숨어 있다… 숨 참기 %d초  (E로 나오기)"):format(math.max(0, ends - os.time()))
	end
end

---------------------------------------------------------------------------
-- 효과/패널
---------------------------------------------------------------------------
local notifyCount = 0

function Hud.notify(text: string)
	notifyCount += 1
	local item = label({ Size = UDim2.fromOffset(420, 26), Text = text, TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18, LayoutOrder = notifyCount, Parent = notifyList })
	task.delay(5, function()
		local tween = TweenService:Create(item, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		item:Destroy()
	end)
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
	return craftPanel.Visible or notePanel.Visible
end

function Hud.setCraftOpen(open: boolean)
	craftPanel.Visible = open
	if open then
		notePanel.Visible = false
	end
end

function Hud.showNote(noteId: string)
	for _, note in Story.Notes do
		if note.id == noteId then
			noteTitle.Text = note.title
			noteBody.Text = note.body
			craftPanel.Visible = false
			notePanel.Visible = true
			return
		end
	end
end

local storyToken = 0
local function showStory(title: string, lines: { string }, holdTime: number)
	storyToken += 1
	local myToken = storyToken
	storyFrame.Visible = true
	storyFrame.BackgroundTransparency = 0.05
	storyTitle.Text = title
	storyText.Text = ""
	task.spawn(function()
		for _, line in lines do
			if storyToken ~= myToken then
				return
			end
			storyText.Text = line
			storyText.TextTransparency = 1
			TweenService:Create(storyText, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
			task.wait(holdTime)
		end
		if storyToken ~= myToken then
			return
		end
		local tween = TweenService:Create(storyFrame, TweenInfo.new(1.5), { BackgroundTransparency = 1 })
		TweenService:Create(storyTitle, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
		TweenService:Create(storyText, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
		tween:Play()
		tween.Completed:Wait()
		if storyToken == myToken then
			storyFrame.Visible = false
			storyTitle.TextTransparency = 0
		end
	end)
end

function Hud.showIntro()
	showStory("흑송 벌목장", Story.Intro, 2.6)
end

function Hud.showEnding(endingId: string)
	local ending = Story.Endings[endingId]
	if ending then
		showStory(ending.title, { ending.text }, 7)
	end
end

function Hud.setDanger(amount: number)
	dangerFrame.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * 0.35
end

function Hud.flash(color: Color3, startTransparency: number, duration: number)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = startTransparency
	TweenService:Create(flashFrame, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

function Hud.hitMarker()
	crosshair.Text = "✕"
	crosshair.TextColor3 = Color3.fromRGB(255, 60, 60)
	task.delay(0.15, function()
		crosshair.Text = "·"
		crosshair.TextColor3 = Color3.fromRGB(230, 230, 230)
	end)
end

function Hud.setStamina(fraction: number)
	staminaBar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaBar.Parent.Visible = fraction < 0.999
end

function Hud.setDead(dead: boolean)
	deadPanel.Visible = dead
end

return Hud
