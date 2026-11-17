-- 화면 UI(HUD)를 코드로 만듭니다.
--   왼쪽 위: 목표(탈출 루트 4개 진행 상황) - 바뀔 때만 잠깐 뜨고 사라짐. [Q]로 다시 보기
--   오른쪽 아래: 손전등 건전지
--   왼쪽 아래: 가방 (재료, 탈출 부품)
--   화면 아래: 핫바 (Roblox 기본 - 제작한 도구가 들어감)
--   가운데: 제작 창(C), 쪽지([E]로 닫기), 인트로/엔딩
--   대기실: 화면 위 안내 글, "지금 출발" 버튼, 천막 앞 안내판 글씨
--
-- 글은 전부 한국어로 쓰고, 보여주기 직전에 T(...) 로 번역합니다 (shared/Lang.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Story = require(ReplicatedStorage.Shared.Story)

local player = Players.LocalPlayer
local T = Lang.t

local Hud = {}

-- 쪽지가 닫힐 때 불리는 함수 (Main 이 넣어 줌)
Hud.onNoteClosed = nil :: (() -> ())?

local gui: ScreenGui
local topLabel: TextLabel
local objectivesLabel: TextLabel
local bagFrame: Frame
local objFrame: Frame
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
local downedPanel: Frame
local downedText: TextLabel
local whisperLabel: TextLabel
local batteryBack: Frame
local batteryBar: Frame
local batteryLabel: TextLabel
local startButton: TextButton

-- 한 번 써 두면 안 바뀌는 글씨들. 언어를 바꾸면 여기 적힌 한국어 원문으로 다시 번역함
local staticTexts: { [Instance]: string } = {}
local function tr(inst: any, text: string): any
	staticTexts[inst] = text
	inst.Text = T(text)
	return inst
end

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
		table.insert(parts, ("%s %d"):format(T(Items.defs[key].name), amount))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function count(key: string): number
	return player:GetAttribute(key) or 0
end

local function craftText(recipe: any): string
	return ("  %s  —  %s\n  %s"):format(T(recipe.name), costText(recipe.cost), T(recipe.desc))
end

export type Callbacks = {
	craft: (recipeId: string) -> (),
	buyProduct: (productId: number) -> (),
	lobbyStart: () -> (), -- 대기실 "지금 출발" 버튼
}

function Hud.init(callbacks: Callbacks)
	gui = make("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

	dangerFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	flashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })

	topLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(760, 30), TextSize = 22, Parent = gui })
	crosshair = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Text = "", TextSize = 34, Parent = gui })
	hidingLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(500, 30), TextSize = 20, TextColor3 = Color3.fromRGB(180, 200, 255), Visible = false, Parent = gui })

	-- 달리기 기력
	local staminaBack = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(160, 5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = gui })
	staminaBar = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 200, 160), BorderSizePixel = 0, Parent = staminaBack })

	-- 목표 패널
	objFrame = make("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(320, 178), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = gui })
	corner(objFrame, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = objFrame })
	objectivesLabel = label({ Size = UDim2.new(1, -10, 1, -8), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 15, RichText = true, Parent = objFrame })

	-- 가방
	bagFrame = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -90), Size = UDim2.fromOffset(250, 260), BackgroundTransparency = 1, Parent = gui })
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 3), Parent = bagFrame })

	tr(
		label({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.fromOffset(560, 60),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 0.35,
			Parent = gui,
		}),
		"[E] 줍기/사용   [C] 제작   [1~9] 도구 들기   [클릭] 도구 사용   [M] 지도\n[F] 손전등   [R] 건전지 교체   [Shift] 달리기   [Ctrl] 웅크리기   [Q] 목표   [P] 설정"
	)

	-- 대기실: 카운트다운이 어느 정도 지나면 나타나는 "지금 출발" 버튼 (키보드는 Enter)
	startButton = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(300, 46),
		BackgroundColor3 = Color3.fromRGB(150, 72, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		Visible = false,
		Parent = gui,
	})
	tr(startButton, if UserInputService.KeyboardEnabled then "[Enter] 지금 출발" else "지금 출발")
	startButton.Activated:Connect(function()
		callbacks.lobbyStart()
	end)

	-- 손전등 건전지
	batteryBack = make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -80), Size = UDim2.fromOffset(120, 6), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = gui })
	batteryBar = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(230, 220, 170), BorderSizePixel = 0, Parent = batteryBack })
	batteryLabel = label({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -90), Size = UDim2.fromOffset(260, 18), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 0.25, Parent = gui })

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
	tr(label({ Font = STORY_FONT, Size = UDim2.new(1, 0, 0, 28), TextSize = 24, LayoutOrder = 0, ZIndex = 6, Parent = craftPanel }), "제작대  (C로 닫기)")
	for i, recipe in Recipes.list do
		local b = button({
			Name = recipe.id,
			Size = UDim2.new(1, 0, 0, 52),
			Text = craftText(recipe),
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
		local shop = tr(button({ Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(0, 110, 60), LayoutOrder = 100, ZIndex = 6, Parent = craftPanel }), "섬광탄 3개 구매 (로벅스)")
		shop.Activated:Connect(function()
			callbacks.buyProduct(M.FlashbangPackProductId)
		end)
	end
	-- Modal 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다 (커서는 Immersion 이 보여줌)
	local close = tr(button({ Size = UDim2.new(1, 0, 0, 32), Modal = true, LayoutOrder = 200, ZIndex = 6, Parent = craftPanel }), "닫기")
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
	-- 쪽지는 마우스 없이 닫아요: 키보드 [E], 게임패드 B. (1인칭이라 마우스 커서가 안 보이기 때문)
	-- 화면을 터치하는 기기에서만 닫기 버튼이 보입니다.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local noteClose = tr(button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(140, 34), ZIndex = 9, Parent = notePanel }), "닫기")
		noteClose.Activated:Connect(function()
			Hud.closeNote()
		end)
	else
		tr(
			label({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.new(1, 0, 0, 26),
				Font = FONT,
				TextSize = 17,
				TextColor3 = Color3.fromRGB(90, 50, 35),
				TextStrokeTransparency = 1,
				ZIndex = 9,
				Parent = notePanel,
			}),
			"[E] 닫기"
		)
	end

	-- 인트로/엔딩
	storyFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Parent = gui })
	storyTitle = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.8, 0, 0, 60), Font = STORY_FONT, TextSize = 44, TextColor3 = Color3.fromRGB(230, 60, 50), ZIndex = 16, Parent = storyFrame })
	storyText = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(0.7, 0, 0, 120), Font = STORY_FONT, TextSize = 22, TextWrapped = true, ZIndex = 16, Parent = storyFrame })

	-- 죽었을 때
	deadPanel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromOffset(420, 140), BackgroundTransparency = 1, Visible = false, Parent = gui })
	tr(label({ Size = UDim2.new(1, 0, 0, 50), Font = STORY_FONT, TextColor3 = Color3.fromRGB(220, 40, 40), TextSize = 34, Parent = deadPanel }), "숲지기에게 당했다…")
	tr(label({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), Parent = deadPanel }), "살아있는 동료를 관전합니다 — 모두 끝나면 라운드 종료")
	if M.ReviveProductId ~= 0 then
		local revive = tr(button({ Position = UDim2.fromOffset(110, 90), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = Color3.fromRGB(0, 110, 60), Modal = true, Parent = deadPanel }), "지금 부활하기 (로벅스)")
		revive.Activated:Connect(function()
			callbacks.buyProduct(M.ReviveProductId)
		end)
	end

	-- 쓰러졌을 때
	downedPanel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(460, 150), BackgroundTransparency = 1, Visible = false, Parent = gui })
	tr(label({ Size = UDim2.new(1, 0, 0, 46), Font = STORY_FONT, TextColor3 = Color3.fromRGB(230, 50, 40), TextSize = 36, Parent = downedPanel }), "쓰러졌다!")
	downedText = label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 26), Text = "", Parent = downedPanel })
	if M.ReviveProductId ~= 0 then
		local selfRevive = tr(button({ Position = UDim2.fromOffset(130, 90), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = Color3.fromRGB(0, 110, 60), Modal = true, Parent = downedPanel }), "스스로 일어나기 (로벅스)")
		selfRevive.Activated:Connect(function()
			callbacks.buyProduct(M.ReviveProductId)
		end)
	end

	-- 환청 글씨
	whisperLabel = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.new(0.8, 0, 0, 40),
		Font = STORY_FONT,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(200, 190, 210),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	Lang.onChanged(Hud.applyLanguage)
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
	local lines = { '<font size="17"><b>' .. T("탈출 방법") .. "</b></font>" }

	-- 정문
	if A("GateOpen") then
		table.insert(lines, '<font color="#7CFF8A">' .. T("정문: 열림! 북쪽 출구로") .. "</font>")
	elseif A("GateOpening") then
		table.insert(lines, '<font color="#FFD84A">' .. T("정문: 올라가는 중… %d초 버텨라"):format(A("GateTimer") or 0) .. "</font>")
	else
		table.insert(lines, T("정문: 발전기 퓨즈 %d/%d"):format(A("FusesPlaced") or 0, A("FusesRequired") or 3))
	end

	-- 트럭
	local truck = A("TruckState")
	if truck == "Starting" then
		table.insert(lines, '<font color="#FFD84A">' .. T("트럭: 출발까지 %d초! 근처에 있어라"):format(A("TruckTimer") or 0) .. "</font>")
	elseif truck == "Ready" then
		table.insert(lines, '<font color="#7CFF8A">' .. T("트럭: 수리 완료 — 시동 가능") .. "</font>")
	elseif truck == "Gone" then
		table.insert(lines, '<font color="#777777">' .. T("트럭: 떠났다") .. "</font>")
	else
		table.insert(lines, T("트럭: %s배터리 %s연료 %s열쇠"):format(check(A("TruckBattery")), check(A("TruckFuel")), check(A("TruckKey"))))
	end

	-- 무전
	local radio = A("RadioState")
	if radio == "Calling" then
		table.insert(lines, '<font color="#FFD84A">' .. T("무전: 헬기 도착까지 %d초"):format(A("RescueTimer") or 0) .. "</font>")
	elseif radio == "Arrived" then
		table.insert(lines, '<font color="#7CFF8A">' .. T("무전: 헬기 도착! 헬기장으로 (%d초)"):format(A("RescueTimer") or 0) .. "</font>")
	elseif radio == "Ready" then
		table.insert(lines, '<font color="#7CFF8A">' .. T("무전: 수리 완료 — 구조 요청 가능") .. "</font>")
	elseif radio == "Gone" then
		table.insert(lines, '<font color="#777777">' .. T("무전: 헬기가 떠났다") .. "</font>")
	else
		table.insert(lines, T("무전: 안테나 %d/%d"):format(A("AntennaPlaced") or 0, A("AntennaRequired") or 2))
	end

	-- 봉인
	if count("SealStake") > 0 then
		table.insert(lines, '<font color="#C08CFF">' .. T("봉인: 말뚝 준비됨 — 괴물을 쓰러뜨려라") .. "</font>")
	else
		table.insert(lines, T("봉인: 룬 조각 %d/%d → 봉인 말뚝 제작"):format(count("Rune"), Config.Escape.RunesRequired))
	end
	local tags = math.max(A("TeamDogTags") or 0, count("DogTag"))
	if tags >= #Story.Loggers then
		table.insert(lines, '<font color="#C08CFF">' .. T("실종자 인식표 모두 거둠 — 이제 봉인하면…") .. "</font>")
	else
		table.insert(lines, '<font color="#AAAAAA">' .. T("실종자 인식표 %d/%d"):format(tags, #Story.Loggers) .. "</font>")
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
				Text = ("%s  x%d"):format(T(def.name), n),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 15,
				TextColor3 = if def.kind == "Quest" then Color3.fromRGB(255, 225, 120) else Color3.fromRGB(225, 225, 225),
				Parent = row,
			})
		end
	end
	if not any then
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = bagFrame })
		label({ Size = UDim2.fromScale(1, 1), Text = T("가방이 비었다"), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.4, TextSize = 15, Parent = row })
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

-- 목표 패널: 내용이 바뀌면 잠깐 떴다가 사라짐. [Q]로 다시 볼 수 있음
local objectivesShownUntil = 0
local lastObjectives = ""

function Hud.showObjectives()
	objectivesShownUntil = os.clock() + Config.Screen.ObjectiveShowTime
	objFrame.Visible = player:GetAttribute("InLobby") ~= true
	task.delay(Config.Screen.ObjectiveShowTime + 0.1, function()
		if os.clock() >= objectivesShownUntil then
			objFrame.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- 대기실: 천막 상태 글씨 (화면 위, 천막 앞 안내판, 게시판)
---------------------------------------------------------------------------
local L = Config.Lobby

-- 천막 i 의 (인원, 상태 글, 지금 출발 가능?)
local function tentStatus(i: number): (number, string, boolean)
	local key = "LobbyRoom" .. i
	local n = ReplicatedStorage:GetAttribute(key .. "Count") or 0
	local status = ReplicatedStorage:GetAttribute(key .. "Status") or "Empty"
	local left = ReplicatedStorage:GetAttribute(key .. "Left") or 0
	local canStart = ReplicatedStorage:GetAttribute(key .. "Start") == true
	local text: string
	if status == "Counting" then
		if canStart then
			text = T("%d초 후 출발"):format(left)
		else
			text = T("%d초 후 출발 · 출발 버튼까지 %d초"):format(left, math.max(0, left - (L.Countdown - L.StartAfter)))
		end
	elseif status == "Waiting" then
		text = T("다른 팀이 숲에 있어요. 끝나면 출발")
	elseif status == "Launching" then
		text = T("출발!")
	elseif n >= L.MaxPlayers then
		text = T("꽉 참")
	else
		text = T("들어오면 출발 준비")
	end
	return n, text, canStart
end

local function boardLabel(part: Instance?): TextLabel?
	local board = part and part:FindFirstChild("Board")
	local found = board and board:FindFirstChild("Label")
	return if found and found:IsA("TextLabel") then found else nil
end

local function setText(target: TextLabel?, text: string)
	if target and target.Text ~= text then
		target.Text = text
	end
end

local NOTICE = "<b>수색대 수칙</b>\n1. 천막에 들어가면 같은 조가 된다 (최대 %d명)\n2. 불빛은 아껴 써라. 그것은 빛을 본다\n3. 뛰지 마라. 그것은 소리를 듣는다\n4. 숲에서 누가 불러도 대답하지 마라"

local function refreshLobbySigns()
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	for i = 1, L.RoomCount do
		local tent = lobby:FindFirstChild("Tent" .. i)
		local n, text = tentStatus(i)
		setText(
			boardLabel(tent and tent:FindFirstChild("Sign")),
			('%s   <font color="%s">%d / %d</font>\n%s'):format(T("%d번 천막"):format(i), if n >= L.MaxPlayers then "#ff6060" else "#ffffff", n, L.MaxPlayers, text)
		)
	end
	local props = lobby:FindFirstChild("Props")
	setText(boardLabel(props and props:FindFirstChild("Notice")), T(NOTICE):format(L.MaxPlayers))
end

function Hud.canLobbyStart(): boolean
	return startButton.Visible
end

function Hud.refresh()
	local state = ReplicatedStorage:GetAttribute("RoundState") or "Intermission"
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local timeText = ("%d:%02d"):format(timeLeft // 60, timeLeft % 60)
	local lobby = player:GetAttribute("InLobby") == true
	bagFrame.Visible = not lobby
	if lobby then
		if craftPanel.Visible then
			Hud.setCraftOpen(false)
		end
		local roomIndex = player:GetAttribute("LobbyRoom")
		local canStart = false
		if typeof(roomIndex) == "number" then
			local n, text, start = tentStatus(roomIndex)
			canStart = start
			topLabel.Text = T("%d번 천막 · %d/%d명 · %s"):format(roomIndex, n, L.MaxPlayers, text)
		elseif player:GetAttribute("Teleporting") == true then
			topLabel.Text = T("숲으로 이동하는 중…")
		else
			topLabel.Text = T("수색대 야영지 — 천막 안에 들어가면 출발 준비 (천막 하나 최대 %d명)"):format(L.MaxPlayers)
		end
		startButton.Visible = canStart
		refreshLobbySigns()
	elseif state == "Playing" then
		local status = if player:GetAttribute("Escaped") then "   ·   " .. T("탈출 성공! 다른 사람을 기다리는 중") else ""
		topLabel.Text = T("새벽까지 %s"):format(timeText) .. status
	elseif state == "Intermission" then
		topLabel.Text = T("같이 출발한 수색대원을 기다리는 중… %s"):format(timeText)
	else
		topLabel.Text = T("라운드 종료")
	end
	if not lobby then
		startButton.Visible = false
		if notePanel.Visible and state ~= "Playing" then
			Hud.closeNote()
		end
	elseif notePanel.Visible then
		Hud.closeNote()
	end

	local text = objectivesText()
	objectivesLabel.Text = text
	if text ~= lastObjectives then
		lastObjectives = text
		if not lobby then
			Hud.showObjectives()
		end
	end
	if lobby then
		objFrame.Visible = false
	end
	refreshBag()
	refreshCraft()

	local downed = player:GetAttribute("Downed") == true
	downedPanel.Visible = downed
	if downed then
		local ends = player:GetAttribute("BleedEnds") or os.time()
		downedText.Text = T("동료가 와서 살려줘야 한다… %d초"):format(math.max(0, ends - os.time()))
	end

	local hiding = player:GetAttribute("Hiding") == true
	hidingLabel.Visible = hiding
	if hiding then
		local ends = player:GetAttribute("HideEnds") or os.time()
		local fmt = if player:GetAttribute("HideKind") == "Vehicle" then "차 밑에 숨어 있다… 숨 참기 %d초  (E로 나오기)" else "옷장에 숨어 있다… 숨 참기 %d초  (E로 나오기)"
		hidingLabel.Text = T(fmt):format(math.max(0, ends - os.time()))
	end
end

---------------------------------------------------------------------------
-- 효과/패널
---------------------------------------------------------------------------
local notifyCount = 0

function Hud.notify(text: string)
	text = Lang.message(text)
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

-- 제작 창이나 쪽지가 화면을 가리고 있는지 (그동안은 도구를 쓰지 않음)
function Hud.isCraftOpen(): boolean
	return craftPanel.Visible or notePanel.Visible
end

function Hud.isCraftPanelOpen(): boolean
	return craftPanel.Visible
end

function Hud.isNoteOpen(): boolean
	return notePanel.Visible
end

function Hud.closeNote()
	if not notePanel.Visible then
		return
	end
	notePanel.Visible = false
	if Hud.onNoteClosed then
		Hud.onNoteClosed()
	end
end

-- 마우스로 눌러야 하는 것이 화면에 있는지 (있으면 1인칭이어도 커서를 보여줌)
function Hud.wantsCursor(): boolean
	if craftPanel.Visible then
		return true
	end
	return Config.Monetization.ReviveProductId ~= 0 and (deadPanel.Visible or downedPanel.Visible)
end

function Hud.setCraftOpen(open: boolean)
	if player:GetAttribute("InLobby") == true then
		open = false -- 대기실에서는 제작 창을 열지 않음 (숲에 들어갈 때 가방이 비워짐)
	end
	craftPanel.Visible = open
	if open then
		Hud.closeNote()
	end
end

function Hud.whisper(text: string)
	text = T(text)
	whisperLabel.Text = text
	whisperLabel.TextTransparency = 1
	TweenService:Create(whisperLabel, TweenInfo.new(1.2), { TextTransparency = 0.1 }):Play()
	task.delay(3, function()
		if whisperLabel.Text == text then
			TweenService:Create(whisperLabel, TweenInfo.new(2), { TextTransparency = 1 }):Play()
		end
	end)
end

-- 쪽지를 펼침. 펼쳤으면 true
function Hud.showNote(noteId: string): boolean
	local loggerIndex = tonumber(noteId:match("^Logger(%d+)$"))
	if loggerIndex then
		local logger = Story.Loggers[loggerIndex]
		if logger then
			noteTitle.Text = T("인식표 — %s"):format(T(logger.name))
			noteBody.Text = T("인식표 뒷면에 칼로 긁어 쓴 글씨:\n\n\"%s\""):format(T(logger.words))
			craftPanel.Visible = false
			notePanel.Visible = true
			return true
		end
		return false
	end
	for _, note in Story.Notes do
		if note.id == noteId then
			noteTitle.Text = T(note.title)
			noteBody.Text = T(note.body)
			craftPanel.Visible = false
			notePanel.Visible = true
			return true
		end
	end
	return false
end

local storyToken = 0
local function showStory(title: string, lines: { string }, holdTime: number)
	storyToken += 1
	local myToken = storyToken
	storyFrame.Visible = true
	storyFrame.BackgroundTransparency = 0.05
	storyTitle.Text = T(title)
	storyText.Text = ""
	task.spawn(function()
		for _, line in lines do
			if storyToken ~= myToken then
				return
			end
			storyText.Text = T(line)
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
	dangerFrame.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * Config.Screen.DangerRed
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
		crosshair.Text = "" -- 평소에는 가운데 점을 보이지 않음
		crosshair.TextColor3 = Color3.fromRGB(230, 230, 230)
	end)
end

function Hud.setStamina(fraction: number)
	staminaBar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaBar.Parent.Visible = fraction < 0.999
end

-- 손전등 건전지 표시 (매 프레임 불려도 바뀔 때만 다시 그림)
local lastBattery = -1
local lastLightOn: boolean? = nil
local lastCells = -1

function Hud.setBattery(fraction: number, on: boolean)
	local lobby = player:GetAttribute("InLobby") == true
	batteryBack.Visible = not lobby
	batteryLabel.Visible = not lobby
	local cells = count("Cell")
	if math.abs(fraction - lastBattery) < 0.005 and on == lastLightOn and cells == lastCells then
		return
	end
	lastBattery, lastLightOn, lastCells = fraction, on, cells
	batteryBar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	batteryBar.BackgroundColor3 = if fraction < Config.Flashlight.LowBattery then Color3.fromRGB(220, 80, 60) else Color3.fromRGB(230, 220, 170)
	batteryBar.BackgroundTransparency = if on then 0 else 0.55
	local status = if fraction <= 0 then "방전" elseif on then "켜짐" else "꺼짐"
	batteryLabel.Text = T("손전등 %s · 건전지 x%d"):format(T(status), cells)
end

function Hud.setDead(dead: boolean)
	deadPanel.Visible = dead
	if dead then
		Hud.closeNote()
	end
end

-- 언어가 바뀌었을 때: 써 둔 글씨를 전부 새 언어로 다시 씀
function Hud.applyLanguage()
	for inst, text in staticTexts do
		(inst :: any).Text = T(text)
	end
	for _, recipe in Recipes.list do
		local b = craftButtons[recipe.id]
		if b then
			b.Text = craftText(recipe)
		end
	end
	lastObjectives = ""
	lastBattery = -1
	Hud.refresh()
end

return Hud
