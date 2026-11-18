-- 핸드폰/태블릿(화면 터치) 조작 버튼
--
-- 키보드가 없는 기기에서만 나타나요. 컴퓨터에서는 아무것도 만들지 않습니다.
--   오른쪽 아래(점프 버튼 둘레): 달리기, 손전등, 웅크리기, 건전지, 추적, 변신 같은 "행동" 버튼
--   오른쪽 위: 목표, 제작, 지도, 상점, 설정 같은 "창" 버튼
--
-- Main.client.luau 가 버튼 목록을 넘겨주면, 이 모듈은 버튼을 그리고
-- 지금 쓸 수 있는 버튼만(visible) 보여줍니다. 켜져 있는 버튼(isOn)은 밝게 표시돼요.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Lang = require(game:GetService("ReplicatedStorage").Shared.Lang)

local TouchControls = {}

export type Button = {
	id: string,
	text: string, -- 한국어 원문 (Lang.t 로 번역해서 보여줌)
	group: string, -- "action" (점프 버튼 둘레) 또는 "menu" (오른쪽 위)
	onPress: () -> (),
	visible: (() -> boolean)?,
	isOn: (() -> boolean)?,
}

type Made = { def: Button, ui: TextButton }

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local actionFrame: Frame
local menuFrame: Frame
local made: { Made } = {}

-- 키보드 없이 화면만 터치하는 기기인지 (컴퓨터, 노트북 터치스크린은 해당 안 됨)
function TouchControls.isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local OFF_COLOR = Color3.fromRGB(30, 28, 26)
local ON_COLOR = Color3.fromRGB(150, 72, 30)

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

local function smallScreen(): boolean
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.min(size.X, size.Y) <= 500
end

-- Roblox 기본 점프 버튼의 가운데와 반지름 (Roblox 가 쓰는 크기와 같게 계산)
-- 화면 오른쪽 아래 모서리에서 얼마나 떨어져 있는지로 돌려줌
local function jumpButton(): (Vector2, number)
	if smallScreen() then
		return Vector2.new(60, 55), 35
	end
	return Vector2.new(110, 150), 60
end

-- 점프 버튼 둘레에 버튼 자리를 만듦. 각도: 180 = 왼쪽, 90 = 위
local RINGS = {
	{ 180, 135, 90 },
	{ 180, 150, 120, 90 },
}

local function layoutActions(visible: { Made })
	local center, radius = jumpButton()
	local size = if smallScreen() then 54 else 66
	local gap = 10
	local slot = 0
	for ring, angles in RINGS do
		local distance = radius + gap + size / 2 + (ring - 1) * (size + gap)
		for _, angle in angles do
			slot += 1
			local item = visible[slot]
			if not item then
				return
			end
			local rad = math.rad(angle)
			-- 오른쪽 아래 모서리 기준 위치 (x는 왼쪽으로, y는 위로 갈수록 커짐)
			local fromRight = center.X - math.cos(rad) * distance
			local fromBottom = center.Y + math.sin(rad) * distance
			item.ui.Size = UDim2.fromOffset(size, size)
			item.ui.Position = UDim2.new(1, -fromRight, 1, -fromBottom)
		end
	end
end

local function refresh()
	if not gui then
		return
	end
	local visibleActions: { Made } = {}
	for _, item in made do
		local show = item.def.visible == nil or (item.def.visible :: () -> boolean)()
		item.ui.Visible = show
		if show then
			local on = item.def.isOn ~= nil and (item.def.isOn :: () -> boolean)()
			item.ui.BackgroundColor3 = if on then ON_COLOR else OFF_COLOR
			item.ui.Text = Lang.t(item.def.text)
			if item.def.group == "action" then
				table.insert(visibleActions, item)
			end
		end
	end
	layoutActions(visibleActions)
end

function TouchControls.start(buttons: { Button })
	if not TouchControls.isTouchOnly() or gui then
		return
	end
	local screen = make("ScreenGui", {
		Name = "TouchControls",
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- 위쪽 Roblox 메뉴 줄 아래부터 그림
		DisplayOrder = 3,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gui = screen
	actionFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	menuFrame = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.new(0.7, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = menuFrame,
	})

	for i, def in buttons do
		local isAction = def.group == "action"
		local ui = make("TextButton", {
			Name = def.id,
			AnchorPoint = if isAction then Vector2.new(0.5, 0.5) else Vector2.zero,
			Size = if isAction then UDim2.fromOffset(60, 60) else UDim2.fromOffset(52, 34),
			AutomaticSize = if isAction then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			BackgroundColor3 = OFF_COLOR,
			BackgroundTransparency = if isAction then 0.35 else 0.25,
			TextColor3 = Color3.fromRGB(240, 235, 225),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextScaled = isAction, -- 둥근 버튼은 글이 길면(영어) 글씨가 작아짐
			Text = Lang.t(def.text),
			AutoButtonColor = true,
			LayoutOrder = i,
			Parent = if isAction then actionFrame else menuFrame,
		})
		make("UICorner", { CornerRadius = if isAction then UDim.new(1, 0) else UDim.new(0, 8), Parent = ui })
		if isAction then
			make("UITextSizeConstraint", { MaxTextSize = 15, Parent = ui })
			make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = ui })
		else
			make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = ui })
		end
		make("UIStroke", { Color = Color3.fromRGB(240, 235, 225), Transparency = 0.6, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ui })
		ui.Activated:Connect(function()
			def.onPress()
			refresh()
		end)
		table.insert(made, { def = def, ui = ui })
	end

	refresh()
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer -= dt
		if timer <= 0 then
			timer = 0.25
			refresh()
		end
	end)
	Lang.onChanged(refresh)
end

return TouchControls
