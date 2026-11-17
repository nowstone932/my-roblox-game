-- 지도 화면 ([M])
--
-- 숲 한가운데 벌목 캠프의 게시판에서 지도를 챙기면(E) 그때부터 [M]으로 언제든 펼쳐 볼 수 있어요.
-- 지도에는 장소와 길, 내 위치(주황 세모)와 동료 위치(흰 점)가 보입니다. 괴물은 안 보여요.
-- 지도를 펴고 있어도 걸어 다닐 수 있지만 화면 가운데가 가려지니 조심!
-- 장소와 길 좌표는 shared/MapData.luau 에 있습니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage.Shared.Lang)
local MapData = require(ReplicatedStorage.Shared.MapData)

local player = Players.LocalPlayer
local T = Lang.t

local MapUi = {}

local MAP_PIXELS = 500
local INK = Color3.fromRGB(60, 38, 26)
local KIND_COLOR = {
	Start = Color3.fromRGB(60, 90, 140),
	Camp = Color3.fromRGB(150, 72, 30),
	Exit = Color3.fromRGB(40, 110, 60),
	Place = INK,
	Danger = Color3.fromRGB(160, 30, 30),
}

local gui: ScreenGui
local panel: Frame
local mapArea: Frame
local titleLabel: TextLabel
local legendLabel: TextLabel
local meMarker: TextLabel
local placeLabels: { { label: TextLabel, name: string } } = {}
local mateDots: { Frame } = {}

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

-- 숲 좌표 (x, z) → 지도 위 위치 (0~1). 북쪽(-Z)이 위
local function toMap(x: number, z: number): (number, number)
	local size = MapData.Size
	return math.clamp((x + size / 2) / size, 0, 1), math.clamp((z + size / 2) / size, 0, 1)
end

local function applyTexts()
	if not gui then
		return
	end
	titleLabel.Text = T("흑송 벌목장 지도")
	legendLabel.Text = T("▲ 나   ● 동료   초록 = 탈출 장소   [M] 닫기")
	for _, item in placeLabels do
		item.label.Text = T(item.name)
	end
end

local function build()
	gui = make("ScreenGui", { Name = "Map", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MAP_PIXELS + 40, MAP_PIXELS + 96),
		BackgroundColor3 = Color3.fromRGB(214, 200, 164),
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = panel })
	-- 화면이 작으면 통째로 줄어듦
	local scale = make("UIScale", { Parent = panel })
	local function fit()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 720
		scale.Scale = math.clamp((height - 40) / (MAP_PIXELS + 96), 0.45, 1)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	titleLabel = make("TextLabel", {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 26,
		TextColor3 = INK,
		Parent = panel,
	})
	legendLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -8),
		Size = UDim2.new(1, -40, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = INK,
		Parent = panel,
	})
	mapArea = make("Frame", {
		Position = UDim2.fromOffset(20, 48),
		Size = UDim2.fromOffset(MAP_PIXELS, MAP_PIXELS),
		BackgroundColor3 = Color3.fromRGB(196, 184, 148),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})
	make("UIStroke", { Color = INK, Thickness = 2, Parent = mapArea })
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 22,
		TextColor3 = INK,
		Text = "N\n↑",
		LineHeight = 0.8,
		Parent = mapArea,
	})

	-- 길
	for _, road in MapData.Roads do
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			local ax, ay = toMap(a[1], a[2])
			local bx, by = toMap(b[1], b[2])
			local dx, dy = (bx - ax) * MAP_PIXELS, (by - ay) * MAP_PIXELS
			make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2),
				Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + road.width, road.width),
				Rotation = math.deg(math.atan2(dy, dx)),
				BackgroundColor3 = Color3.fromRGB(140, 118, 86),
				BorderSizePixel = 0,
				Parent = mapArea,
			})
		end
	end

	-- 장소
	for _, place in MapData.Places do
		local u, v = toMap(place.x, place.z)
		local color = KIND_COLOR[place.kind] or INK
		local dot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(u, v),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = mapArea,
		})
		make("UICorner", { CornerRadius = UDim.new(0, if place.kind == "Exit" then 2 else 5), Parent = dot })
		-- 글씨는 점 아래에 (side = "right" 면 오른쪽에). 지도 가장자리에서는 안쪽으로 당김
		local below = v < 0.9
		local right = place.side == "right"
		local name = make("TextLabel", {
			AnchorPoint = if right then Vector2.new(0, 0.5) else Vector2.new(math.clamp(u * 1.5 - 0.25, 0, 1), if below then 0 else 1),
			Position = if right then UDim2.new(u, 9, v, 0) else UDim2.new(u, 0, v, if below then 6 else -6),
			Size = UDim2.fromOffset(170, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = color,
			TextXAlignment = if right or u < 0.2 then Enum.TextXAlignment.Left elseif u > 0.8 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = mapArea,
		})
		table.insert(placeLabels, { label = name, name = place.name })
	end

	meMarker = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Text = "▲",
		TextColor3 = Color3.fromRGB(235, 110, 30),
		TextStrokeColor3 = Color3.fromRGB(40, 20, 10),
		TextStrokeTransparency = 0,
		ZIndex = 6,
		Parent = mapArea,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	applyTexts()
end

local function rootOf(who: Player): BasePart?
	local char = who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function update()
	if not panel.Visible then
		return
	end
	local camera = Workspace.CurrentCamera
	local me = rootOf(player)
	if me and camera then
		local u, v = toMap(me.Position.X, me.Position.Z)
		local look = camera.CFrame.LookVector
		meMarker.Position = UDim2.fromScale(u, v)
		meMarker.Rotation = math.deg(math.atan2(look.X, -look.Z))
		meMarker.Visible = true
	else
		meMarker.Visible = false
	end
	-- 같이 온 동료 (숲에 살아 있는 사람만)
	local used = 0
	for _, other in Players:GetPlayers() do
		local root = if other ~= player and other:GetAttribute("InRound") == true and other:GetAttribute("Escaped") ~= true then rootOf(other) else nil
		if root then
			used += 1
			local dot = mateDots[used]
			if not dot then
				dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(250, 250, 245), BorderSizePixel = 0, ZIndex = 5, Parent = mapArea })
				make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
				make("UIStroke", { Color = Color3.fromRGB(40, 30, 20), Thickness = 1.5, Parent = dot })
				mateDots[used] = dot
			end
			local u, v = toMap(root.Position.X, root.Position.Z)
			dot.Position = UDim2.fromScale(u, v)
			dot.Visible = true
		end
	end
	for i = used + 1, #mateDots do
		mateDots[i].Visible = false
	end
end

function MapUi.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

function MapUi.hasMap(): boolean
	return player:GetAttribute("HasMap") == true
end

function MapUi.close()
	if panel then
		panel.Visible = false
	end
end

-- 지도를 펼침. 지도가 없거나 숲이 아니면 false
function MapUi.open(): boolean
	if not MapUi.hasMap() or player:GetAttribute("InLobby") == true then
		return false
	end
	panel.Visible = true
	update()
	return true
end

function MapUi.init()
	build()
	Lang.onChanged(applyTexts)
	RunService.RenderStepped:Connect(update)
	-- 지도를 잃으면(대기실로 돌아감, 새 판) 닫음
	local function check()
		if not MapUi.hasMap() or player:GetAttribute("InLobby") == true then
			MapUi.close()
		end
	end
	player:GetAttributeChangedSignal("HasMap"):Connect(check)
	player:GetAttributeChangedSignal("InLobby"):Connect(check)
end

return MapUi
