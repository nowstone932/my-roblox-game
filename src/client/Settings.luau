-- 설정 창 (화면 오른쪽): 언어, 효과음 크기, 배경음 크기
--
--   대기실에서는 항상 오른쪽에 보여요. 숲에서는 [P]를 눌러야 나옵니다.
--   [P]를 누르면 "조작 중"이 되어 마우스 커서가 나타나고, 버튼과 막대를 누를 수 있어요.
--   다시 [P](또는 닫기 버튼)를 누르면 커서가 사라지고 게임으로 돌아갑니다.
--   화면을 터치하는 기기에서는 [P] 없이 바로 누를 수 있어요.
--
-- 바꾼 설정은 서버(server/Services/Settings.luau)가 저장해서 다음에 접속해도 그대로예요.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local T = Lang.t

local Settings = {}

local STEP = 5 -- 막대 한 칸 (%)

local values = {
	lang = "ko",
	sfx = Audio.DefaultPercent,
	music = Audio.DefaultPercent,
}

local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local closeButton: TextButton
local langButtons: { [string]: TextButton } = {}
local rowLabels: { [string]: TextLabel } = {}
local sliders: { [string]: { track: TextButton, fill: Frame, knob: Frame, value: TextLabel } } = {}

local active = false -- 조작 중 (커서가 보임)
local opened = false -- 숲에서 [P]로 열어 둠
local dragging: string? = nil
local saveToken = 0

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

local function apply()
	Audio.setVolume("Effects", values.sfx)
	Audio.setVolume("Music", values.music)
	Lang.set(values.lang)
end

-- 조금 기다렸다가 한 번만 서버에 저장 (막대를 끄는 동안 계속 보내지 않게)
local function saveSoon()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			Remotes.get("SaveSettings"):FireServer(values.lang, values.sfx, values.music)
		end
	end)
end

local function redraw()
	if not gui then
		return
	end
	local lobby = player:GetAttribute("InLobby") == true
	panel.Visible = lobby or opened or active
	titleLabel.Text = T("설정")
	if not UserInputService.KeyboardEnabled then
		hintLabel.Text = ""
	elseif active then
		hintLabel.Text = T("[P] 닫기")
	else
		hintLabel.Text = T("[P] 마우스로 조작")
	end
	closeButton.Text = T("닫기")
	closeButton.Visible = active
	rowLabels.lang.Text = T("언어")
	rowLabels.sfx.Text = T("효과음")
	rowLabels.music.Text = T("배경음")
	for code, b in langButtons do
		local selected = values.lang == code
		b.BackgroundColor3 = if selected then Color3.fromRGB(150, 72, 30) else Color3.fromRGB(44, 40, 38)
		b.TextTransparency = if selected then 0 else 0.35
	end
	for key, slider in sliders do
		local fraction = (values :: any)[key] / 100
		slider.fill.Size = UDim2.fromScale(fraction, 1)
		slider.knob.Position = UDim2.fromScale(fraction, 0.5)
		slider.value.Text = ("%d%%"):format((values :: any)[key])
	end
	panel.BackgroundTransparency = if active then 0.12 else 0.45
end

local function setValue(key: string, value: any)
	if (values :: any)[key] == value then
		return
	end
	(values :: any)[key] = value
	apply()
	redraw()
	saveSoon()
end

local function dragTo(key: string, screenX: number)
	local track = sliders[key].track
	local fraction = math.clamp((screenX - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
	setValue(key, math.floor(fraction * 100 / STEP + 0.5) * STEP)
end

local function row(order: number, key: string): Frame
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = order, Parent = panel })
	rowLabels[key] = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(225, 215, 195),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return frame
end

local function sliderRow(order: number, key: string)
	local frame = row(order, key)
	local value = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(60, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 200, 130),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	-- 누르기 쉽게 막대보다 넓은 투명 버튼을 깔아 둠
	local track = make("TextButton", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = frame,
	})
	local bar = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(20, 18, 16), BorderSizePixel = 0, Parent = track })
	corner(bar, 4)
	local fill = make("Frame", { Size = UDim2.fromScale(0.7, 1), BackgroundColor3 = Color3.fromRGB(200, 110, 50), BorderSizePixel = 0, Parent = bar })
	corner(fill, 4)
	local knob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.7, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(245, 225, 190), BorderSizePixel = 0, Parent = bar })
	corner(knob, 8)
	sliders[key] = { track = track, fill = fill, knob = knob, value = value }

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = key
			dragTo(key, input.Position.X)
		end
	end)
end

function Settings.isActive(): boolean
	return active
end

-- [P]: 조작 시작/끝
function Settings.toggle()
	active = not active
	opened = active
	dragging = nil
	redraw()
end

function Settings.close()
	if active or opened then
		active = false
		opened = false
		dragging = nil
		redraw()
	end
end

function Settings.init()
	gui = make("ScreenGui", { Name = "Settings", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })

	panel = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, -40),
		Size = UDim2.fromOffset(250, 258),
		BackgroundColor3 = Color3.fromRGB(16, 14, 12),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 10)
	make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = panel })
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = panel })

	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel })
	titleLabel = make("TextLabel", {
		Size = UDim2.fromScale(0.4, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(240, 228, 205),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	hintLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.6, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 190, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	-- 언어
	local langRow = row(1, "lang")
	for i, info in Lang.Languages do
		local b = make("TextButton", {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 3, 0, 22),
			Size = UDim2.new(0.5, -3, 0, 28),
			BackgroundColor3 = Color3.fromRGB(44, 40, 38),
			TextColor3 = Color3.fromRGB(240, 240, 240),
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			Text = info.name,
			Parent = langRow,
		})
		corner(b, 6)
		b.Activated:Connect(function()
			setValue("lang", info.code)
		end)
		langButtons[info.code] = b
	end

	sliderRow(2, "sfx")
	sliderRow(3, "music")

	-- Modal 버튼이 보이는 동안은 1인칭에서도 마우스가 풀립니다 (조작 중일 때만 보임)
	closeButton = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(44, 40, 38),
		TextColor3 = Color3.fromRGB(240, 240, 240),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		Modal = true,
		Visible = false,
		LayoutOrder = 9,
		Parent = panel,
	})
	corner(closeButton, 6)
	closeButton.Activated:Connect(Settings.close)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragTo(dragging, input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	-- 대기실 ↔ 숲을 오갈 때는 조작을 끝내고 커서를 숨김
	player:GetAttributeChangedSignal("InLobby"):Connect(function()
		active = false
		opened = false
		dragging = nil
		redraw()
	end)
	Lang.onChanged(redraw)

	-- 처음 접속: 저장된 설정이 없으면 Roblox 언어가 한국어일 때만 한국어, 아니면 영어로 시작
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and typeof(locale) == "string" and locale:sub(1, 2) ~= "ko" then
		values.lang = "en"
	end
	apply()
	redraw()

	-- 서버가 저장해 둔 설정 불러오기
	task.spawn(function()
		local deadline = os.clock() + 8
		while player:GetAttribute("OptLoaded") ~= true and os.clock() < deadline do
			task.wait(0.2)
		end
		local lang = player:GetAttribute("OptLang")
		local sfx = player:GetAttribute("OptSfx")
		local music = player:GetAttribute("OptMusic")
		if lang == "ko" or lang == "en" then
			values.lang = lang
		end
		if typeof(sfx) == "number" then
			values.sfx = math.clamp(sfx, 0, 100)
		end
		if typeof(music) == "number" then
			values.music = math.clamp(music, 0, 100)
		end
		apply()
		redraw()
	end)
end

return Settings
