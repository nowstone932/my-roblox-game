-- 게임패스 능력의 화면 쪽 (상점에서 산 사람만 보임)
--
--   [T] 숲지기 추적기: 켜면 잠깐 동안 괴물이 벽 너머로도 빨갛게 보이고, 거리(m)가 표시됩니다.
--   [G] 숲지기 변신: 한 판에 한 번. 변신한 동안 괴물이 공격하지 않아요.
--
-- 실제 판정은 전부 서버(server/Services/Abilities.luau)가 하고, 여기서는 보여주기만 합니다.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local T = Lang.t
local S = Config.Shop

local Abilities = {}

export type Options = {
	notify: (text: string) -> (), -- 화면 안내 글
	flash: (color: Color3, startTransparency: number, duration: number) -> (), -- 화면 번쩍임
}

local options: Options
local useAbility = Remotes.get("UseAbility")

local gui: ScreenGui
local trackerLabel: TextLabel
local disguiseLabel: TextLabel
local marker: Part
local markerText: TextLabel
local highlight: Highlight
local refreshTimer = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function owns(name: string): boolean
	return player:GetAttribute("Pass_" .. name) == true
end

local function playing(): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == "Playing"
		and player:GetAttribute("InLobby") ~= true
		and player:GetAttribute("InRound") == true
		and player:GetAttribute("Escaped") ~= true
end

local function key(letter: string): string
	return if UserInputService.KeyboardEnabled then "[" .. letter .. "] " else ""
end

local function requestTracker()
	if not (owns("Tracker") and playing()) then
		return
	end
	local wait = (player:GetAttribute("TrackerReady") or 0) - now()
	if wait > 0 then
		options.notify(T("추적기 충전 중… %d초"):format(math.ceil(wait)))
		return
	end
	useAbility:FireServer("Tracker")
end

local function requestDisguise()
	if not (owns("Disguise") and playing()) then
		return
	end
	if player:GetAttribute("Disguised") == true then
		return
	end
	if (player:GetAttribute("DisguiseUsed") or 0) >= S.DisguisePerRound then
		options.notify("이번 판에는 이미 변신했다")
		return
	end
	useAbility:FireServer("Disguise")
end

-- 게임패스를 가진 사람만 키(모바일은 화면 버튼)가 생김
local function bind(name: string, title: string, passName: string, callback: () -> (), keyCode: Enum.KeyCode)
	local function rebind()
		ContextActionService:UnbindAction(name)
		if owns(passName) then
			ContextActionService:BindAction(name, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					callback()
				end
				return Enum.ContextActionResult.Pass
			end, true, keyCode)
			ContextActionService:SetTitle(name, title)
		end
	end
	player:GetAttributeChangedSignal("Pass_" .. passName):Connect(rebind)
	rebind()
end

local function refreshLabels()
	local show = playing()
	local t = now()

	trackerLabel.Visible = show and owns("Tracker")
	if trackerLabel.Visible then
		local left = (player:GetAttribute("TrackerEnds") or 0) - t
		local wait = (player:GetAttribute("TrackerReady") or 0) - t
		if left > 0 then
			trackerLabel.Text = key("T") .. T("추적기 작동 중 %d초"):format(math.ceil(left))
			trackerLabel.TextColor3 = Color3.fromRGB(255, 110, 90)
		elseif wait > 0 then
			trackerLabel.Text = key("T") .. T("추적기 충전 중… %d초"):format(math.ceil(wait))
			trackerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		else
			trackerLabel.Text = key("T") .. T("추적기 준비됨")
			trackerLabel.TextColor3 = Color3.fromRGB(225, 215, 195)
		end
	end

	disguiseLabel.Visible = show and owns("Disguise")
	if disguiseLabel.Visible then
		local left = (player:GetAttribute("DisguiseEnds") or 0) - t
		if player:GetAttribute("Disguised") == true and left > 0 then
			disguiseLabel.Text = T("숲지기로 변신 중 %d초 — 괴물이 공격하지 않는다"):format(math.ceil(left))
			disguiseLabel.TextColor3 = Color3.fromRGB(170, 255, 190)
		elseif (player:GetAttribute("DisguiseUsed") or 0) >= S.DisguisePerRound then
			disguiseLabel.Text = key("G") .. T("변신: 이번 판에 사용함")
			disguiseLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		else
			disguiseLabel.Text = key("G") .. T("숲지기 변신 준비됨")
			disguiseLabel.TextColor3 = Color3.fromRGB(225, 215, 195)
		end
	end
end

-- 추적기: 괴물 위치에 표시를 띄움
local function updateTracker()
	local pos = player:GetAttribute("TrackerPos")
	local on = playing() and typeof(pos) == "Vector3" and (player:GetAttribute("TrackerEnds") or 0) > now()
	if not on then
		if marker.Parent then
			marker.Parent = nil
			highlight.Adornee = nil
			highlight.Enabled = false
		end
		return
	end
	local monster = Workspace:FindFirstChild("Monster")
	local root = monster and monster:FindFirstChild("HumanoidRootPart")
	-- 괴물이 내 화면에 있으면 그 위치를 쓰고(부드럽게 따라감), 없으면 서버가 알려준 위치를 씀
	local target: Vector3 = if root and root:IsA("BasePart") then root.Position else pos
	marker.Position = target + Vector3.new(0, 11, 0)
	if not marker.Parent then
		marker.Parent = Workspace
	end
	markerText.Text = ("▼\n%dm"):format(math.floor((target - camera.CFrame.Position).Magnitude / 3.5 + 0.5))
	highlight.Adornee = monster
	highlight.Enabled = monster ~= nil
end

-- 변신 중 1인칭에서도 내 발톱은 보이게
local function showClaws()
	if player:GetAttribute("Disguised") ~= true then
		return
	end
	local char = player.Character
	local costume = char and char:FindFirstChild("Disguise")
	if costume then
		for _, part in costume:GetChildren() do
			if part.Name == "Claw" and part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

function Abilities.start(opts: Options)
	options = opts

	gui = Instance.new("ScreenGui")
	gui.Name = "Abilities"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4

	local function line(y: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(18, y)
		label.Size = UDim2.fromOffset(420, 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 15
		label.TextStrokeTransparency = 0.5
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Visible = false
		label.Parent = gui
		return label
	end
	trackerLabel = line(250)
	disguiseLabel = line(272)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 괴물 위치 표시 (내 화면에만 있음)
	marker = Instance.new("Part")
	marker.Name = "TrackerMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(0.2, 0.2, 0.2)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(120, 60)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 100000
	board.Parent = marker
	markerText = Instance.new("TextLabel")
	markerText.Size = UDim2.fromScale(1, 1)
	markerText.BackgroundTransparency = 1
	markerText.Font = Enum.Font.GothamBold
	markerText.TextSize = 20
	markerText.TextColor3 = Color3.fromRGB(255, 70, 60)
	markerText.TextStrokeTransparency = 0.3
	markerText.Parent = board

	highlight = Instance.new("Highlight")
	highlight.Name = "TrackerHighlight"
	highlight.FillColor = Color3.fromRGB(255, 40, 30)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(255, 90, 70)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = marker

	bind("AbilityTracker", "추적", "Tracker", requestTracker, Enum.KeyCode.T)
	bind("AbilityDisguise", "변신", "Disguise", requestDisguise, Enum.KeyCode.G)

	player:GetAttributeChangedSignal("Disguised"):Connect(function()
		if player:GetAttribute("Disguised") == true then
			options.flash(Color3.fromRGB(10, 30, 16), 0.1, 1.4)
			options.notify("숲지기의 가죽을 뒤집어썼다… 괴물이 나를 동족으로 본다")
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		updateTracker()
		showClaws()
		refreshTimer -= dt
		if refreshTimer <= 0 then
			refreshTimer = 0.2
			refreshLabels()
		end
	end)
	Lang.onChanged(refreshLabels)
end

return Abilities
