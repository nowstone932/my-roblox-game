-- 관전 모드
-- 내가 죽었거나 먼저 탈출했으면, 아직 숲에 살아있는 동료의 등 뒤에서 화면을 보여줍니다.
-- [Q] / [E] 또는 화면의 ◀ ▶ 버튼으로 보는 사람을 바꿀 수 있어요.
-- 라운드는 모두 죽거나 탈출해야 끝납니다. (서버 GameLoop.luau)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Spectate = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local active = false
local index = 1
local subject: Player? = nil
local subjectRoot: BasePart? = nil
local camCf: CFrame? = nil

local gui: ScreenGui
local nameLabel: TextLabel

local function isAlive(p: Player): BasePart?
	if p:GetAttribute("InMatch") ~= true or p:GetAttribute("InRound") ~= true or p:GetAttribute("Escaped") == true then
		return nil
	end
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

-- 지금 관전해야 하는 상황인지 (라운드 중 + 이번 판 참가자 + 죽었거나 탈출함)
local function shouldSpectate(): boolean
	if ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" then
		return false
	end
	if player:GetAttribute("InMatch") ~= true then
		return false
	end
	return player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true
end

local function candidates(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and isAlive(p) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function cycle(step: number)
	local list = candidates()
	if #list == 0 then
		return
	end
	local current = table.find(list, subject :: Player) or index
	index = ((current - 1 + step) % #list) + 1
	subject = list[index]
	camCf = nil
end

local function stop()
	if not active then
		return
	end
	active = false
	subject = nil
	subjectRoot = nil
	camCf = nil
	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Spectate"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -40)
	bar.Size = UDim2.fromOffset(420, 54)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BackgroundTransparency = 0.45
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar

	nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(60, 0)
	nameLabel.Size = UDim2.new(1, -120, 1, 0)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	nameLabel.Text = ""
	nameLabel.Parent = bar

	for _, info in { { text = "◀", x = 6, step = -1 }, { text = "▶", x = 366, step = 1 } } do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(info.x, 5)
		b.Size = UDim2.fromOffset(48, 44)
		b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		b.TextColor3 = Color3.fromRGB(240, 240, 240)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 22
		b.Text = info.text
		b.Modal = true -- 1인칭 고정 중에도 마우스로 누를 수 있게
		b.Parent = bar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = b
		b.Activated:Connect(function()
			cycle(info.step)
		end)
	end
end

local function update()
	if not shouldSpectate() then
		stop()
		return
	end
	local list = candidates()
	if #list == 0 then
		-- 볼 사람이 없음 (모두 죽었거나 탈출) → 라운드가 곧 끝남
		stop()
		return
	end
	if not subject or not table.find(list, subject) then
		index = math.clamp(index, 1, #list)
		subject = list[index]
		camCf = nil
	end
	local root = isAlive(subject :: Player)
	if not root then
		return
	end
	if not active then
		active = true
		gui.Enabled = true
	end
	subjectRoot = root
	camera.CameraType = Enum.CameraType.Scriptable
	nameLabel.Text = ("관전 중: %s   [Q] / [E] 바꾸기"):format((subject :: Player).DisplayName)

	-- 동료의 어깨 뒤에서 동료가 보는 방향을 같이 봄
	local char = (subject :: Player).Character
	local head = char and char:FindFirstChild("Head")
	local focus = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local wanted = focus - look * 7 + Vector3.new(0, 2.2, 0) + root.CFrame.RightVector * 1.5

	-- 벽에 카메라가 파묻히지 않게
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if char then
		table.insert(ignore, char)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(focus, wanted - focus, params)
	if hit then
		wanted = hit.Position + (focus - hit.Position).Unit * 0.8
	end

	local goal = CFrame.lookAt(wanted, focus + look * 10)
	camCf = if camCf then camCf:Lerp(goal, 0.2) else goal
	camera.CFrame = camCf :: CFrame
end

-- 관전 중인 동료의 몸 (없으면 nil). 화면 붉어짐/음악 계산에 씀
function Spectate.subjectRoot(): BasePart?
	if active then
		return subjectRoot
	end
	return nil
end

function Spectate.isActive(): boolean
	return active
end

function Spectate.start()
	buildGui()
	RunService:BindToRenderStep("Spectate", Enum.RenderPriority.Camera.Value + 2, update)
	ContextActionService:BindAction("SpectateSwitch", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or not active then
			return Enum.ContextActionResult.Pass
		end
		cycle(if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
end

return Spectate
