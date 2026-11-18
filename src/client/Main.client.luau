-- 클라이언트(플레이어 컴퓨터) 시작점
-- 각 기능 모듈을 켜고, 키 입력과 서버가 보낸 효과를 연결합니다.
--
--   Flashlight  손전등과 건전지            Lights      깜빡이는 등불, 정전
--   Immersion   화면 가장자리 어둠, 걸음 출렁임   Weather     비, 번개, 안개
--   Scares      공포 연출 (발소리, 형체…)      MonsterAnimator 괴물 움직임
--   Audio       소리와 배경음악             Hud         화면 글씨/창
--   Settings    설정 창 (언어, 소리 크기)      MapUi       지도
--   Shop        로벅스 상점 (대기실 왼쪽)      Abilities   게임패스 능력 (추적기, 변신)
--
-- 조작: [F] 손전등  [R] 건전지 교체  [Shift] 달리기  [Ctrl] 웅크리기  [C] 제작  [Q] 목표 보기
--       [M] 지도  [P] 설정  [E] 쪽지 닫기  [Enter] 대기실에서 지금 출발  [B] 대기실 상점
--       게임패스가 있으면: [T] 숲지기 추적기  [G] 숲지기 변신
--       핸드폰/태블릿은 키 대신 화면 버튼 (TouchControls)

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)
local Audio = require(script.Parent.Audio)
local Flashlight = require(script.Parent.Flashlight)
local Hud = require(script.Parent.Hud)
local Immersion = require(script.Parent.Immersion)
local Lights = require(script.Parent.Lights)
local MapUi = require(script.Parent.MapUi)
local MonsterAnimator = require(script.Parent.MonsterAnimator)
local Scares = require(script.Parent.Scares)
local Settings = require(script.Parent.Settings)
local Shop = require(script.Parent.Shop)
local Abilities = require(script.Parent.Abilities)
local Spectate = require(script.Parent.Spectate)
local TouchControls = require(script.Parent.TouchControls)
local Weather = require(script.Parent.Weather)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local craftRemote = Remotes.get("Craft")
local useToolRemote = Remotes.get("UseTool")

-- 대기실에 있을 때는 숲에서 벌어지는 일(다른 팀 메시지, 효과)을 무시
local function inLobby(): boolean
	return player:GetAttribute("InLobby") == true
end

-- 숲에서 살아서 움직이는 중인지
local function inRound(): boolean
	return ReplicatedStorage:GetAttribute("RoundState") == "Playing"
		and player:GetAttribute("InRound") == true
		and player:GetAttribute("Escaped") ~= true
end

-- 살아 있는 괴물의 몸통 (쓰러졌거나 봉인됐으면 nil)
local function monsterRoot(): (BasePart?, string?)
	local monster = Workspace:FindFirstChild("Monster")
	local root = monster and monster:FindFirstChild("HumanoidRootPart")
	if monster and root and root:IsA("BasePart") then
		local state = monster:GetAttribute("State")
		if state ~= "Downed" and state ~= "Sealed" then
			return root, state
		end
	end
	return nil, nil
end

---------------------------------------------------------------------------
-- 모듈 켜기
---------------------------------------------------------------------------
Hud.init({
	craft = function(recipeId)
		craftRemote:FireServer(recipeId)
	end,
	buyProduct = function(productId)
		MarketplaceService:PromptProductPurchase(player, productId)
	end,
	lobbyStart = function()
		Remotes.get("LobbyStart"):FireServer()
	end,
})
Audio.init()
Settings.init() -- Audio 다음에 (소리 크기를 적용해야 하므로)
MapUi.init()
Shop.init()
Abilities.start({ notify = Hud.notify, flash = Hud.flash })
-- 마우스로 눌러야 하는 창이 떠 있을 때만 커서를 보여줌. 그 밖에는 1인칭이라 숨김
Immersion.wantCursor = function()
	return Settings.isActive() or Shop.isActive() or Hud.wantsCursor() or Spectate.isActive()
end
Immersion.start()
Weather.start()
Lights.start(function()
	local root = monsterRoot()
	return root
end)
Flashlight.start({
	onClick = function()
		Audio.play("FlashlightClick")
	end,
	onEmpty = function()
		if (player:GetAttribute("Cell") or 0) > 0 then
			Hud.notify("손전등 건전지가 다 닳았다 — [R] 건전지 교체")
		else
			Hud.notify("손전등 건전지가 다 닳았다… 건전지를 찾아야 한다")
		end
	end,
})
MonsterAnimator.start({ isLightOn = Flashlight.isOn })
Spectate.start()

player.AttributeChanged:Connect(Hud.refresh)
ReplicatedStorage.AttributeChanged:Connect(Hud.refresh)

Remotes.get("LobbyNotify").OnClientEvent:Connect(Hud.notify)
Remotes.get("Notify").OnClientEvent:Connect(function(text: string)
	if not inLobby() then
		Hud.notify(text)
	end
end)
---------------------------------------------------------------------------
-- 쪽지: [E]로 닫기 (1인칭이라 마우스 커서가 없으므로 키보드로 닫음)
---------------------------------------------------------------------------
local noteOpenedAt: Vector3? = nil

-- 쪽지를 읽는 동안에는 줍기/읽기 표시(E)를 꺼 둠. 안 그러면 E를 눌러 닫자마자 쪽지를 또 읽게 됨
Hud.onNoteClosed = function()
	noteOpenedAt = nil
	ContextActionService:UnbindAction("CloseNote")
	task.delay(0.3, function()
		if not Hud.isNoteOpen() then
			ProximityPromptService.Enabled = true
		end
	end)
end

Remotes.get("ShowNote").OnClientEvent:Connect(function(noteId: string)
	Audio.play("NoteOpen")
	if noteId == "Map" then
		-- 중앙 캠프 게시판의 지도
		Hud.closeNote()
		Hud.setCraftOpen(false)
		MapUi.open()
		return
	end
	if not Hud.showNote(noteId) then
		return
	end
	MapUi.close()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	noteOpenedAt = if root and root:IsA("BasePart") then root.Position else nil
	ProximityPromptService.Enabled = false
	ContextActionService:BindActionAtPriority("CloseNote", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Hud.closeNote()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
end)

-- 쪽지를 펴 둔 채로 멀리 걸어가면 저절로 접힘
RunService.Heartbeat:Connect(function()
	if noteOpenedAt and Hud.isNoteOpen() then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or (root.Position - noteOpenedAt).Magnitude > 14 then
			Hud.closeNote()
		end
	end
end)

-- 영어로 바꿨을 때 줍기/읽기 표시(E)의 글씨도 번역
type PromptText = { action: string, object: string, shownAction: string, shownObject: string }
local promptTexts: { [ProximityPrompt]: PromptText } = setmetatable({}, { __mode = "k" }) :: any
ProximityPromptService.PromptShown:Connect(function(prompt)
	local saved = promptTexts[prompt]
	-- 처음 보는 표시이거나, 서버가 글씨를 바꿨으면(숨기 ↔ 나오기 등) 지금 글씨를 한국어 원문으로 삼음
	if not saved or (prompt.ActionText ~= saved.action and prompt.ActionText ~= saved.shownAction) or (prompt.ObjectText ~= saved.object and prompt.ObjectText ~= saved.shownObject) then
		saved = { action = prompt.ActionText, object = prompt.ObjectText, shownAction = "", shownObject = "" }
		promptTexts[prompt] = saved
	end
	saved.shownAction = Lang.t(saved.action)
	saved.shownObject = Lang.t(saved.object)
	prompt.ActionText = saved.shownAction
	prompt.ObjectText = saved.shownObject
end)
Remotes.get("StoryEvent").OnClientEvent:Connect(function(kind: string, endingId: string?)
	if inLobby() then
		return
	end
	if kind == "Intro" then
		Audio.play("RoundStart")
		Hud.showIntro()
	elseif kind == "Ending" and endingId then
		Audio.duckMusic(8)
		Audio.play(if endingId == "Dead" or endingId == "Timeout" then "Defeat" else "Victory")
		Hud.showEnding(endingId)
	end
end)

---------------------------------------------------------------------------
-- 매 프레임: 손전등, 1인칭 팔, 빙글 도는 탈출 부품
---------------------------------------------------------------------------
-- 1인칭에서도 팔과 들고 있는 도구가 보이게
local VISIBLE_IN_FIRST_PERSON = {
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	["Right Arm"] = true, ["Left Arm"] = true,
}

RunService.RenderStepped:Connect(function(dt)
	-- 숲지기가 가까이 오거나 정전이면 손전등이 치직거림
	local interference = 0
	local mRoot = monsterRoot()
	if mRoot then
		local d = (mRoot.Position - camera.CFrame.Position).Magnitude
		interference = math.clamp(1 - d / 42, 0, 1)
	end
	if Lights.isBlackout() then
		interference = math.max(interference, 0.6)
	end
	Flashlight.update(dt, interference, inRound() and not inLobby())
	Hud.setBattery(Flashlight.battery(), Flashlight.isOn())

	local char = player.Character
	if char then
		for _, part in char:GetChildren() do
			if part:IsA("BasePart") and VISIBLE_IN_FIRST_PERSON[part.Name] then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local pickups = Workspace:FindFirstChild("Pickups")
	if pickups then
		for _, item in pickups:GetChildren() do
			if item:IsA("Model") and item:GetAttribute("Spin") then
				item:PivotTo(item:GetPivot() * CFrame.Angles(0, dt * 1.5, 0))
			end
		end
	end
end)

---------------------------------------------------------------------------
-- 괴물 소리: 발소리(걸음마다 땅이 울림), 숨소리, 가끔 으르렁
---------------------------------------------------------------------------
local stepTimer = 0
local breathRoot: BasePart? = nil
local breathSound: Sound? = nil
local growlTimer = 8
local BREATH_BY_STATE = { Chase = 1, Hunt = 0.9, Wander = 0.6, Investigate = 0.7, Search = 0.8, Stalk = 0.3, Retreat = 0.4, Stunned = 0.3 }

RunService.Heartbeat:Connect(function(dt)
	local mRoot, state = monsterRoot()
	if not mRoot then
		return
	end
	local frozen = mRoot.Parent ~= nil and mRoot.Parent:GetAttribute("Frozen") == true

	-- 발소리 (소리는 괴물 위치에서 3D로 → 방향을 알 수 있음)
	local v = mRoot.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed >= 2 then
		stepTimer -= dt
		if stepTimer <= 0 then
			stepTimer = math.clamp(9 / speed, 0.25, 0.9)
			local d = (mRoot.Position - camera.CFrame.Position).Magnitude
			if d < 70 then
				-- 살금살금 다가올 때(Stalk)는 발소리가 아주 작음
				local volume = if state == "Stalk" then 0.25 elseif speed > 15 then 1.2 else 0.8
				Audio.play("MonsterFootstep", mRoot.Position, volume)
				if state ~= "Stalk" then
					Immersion.shake(0.012 * (1 - d / 70), 0.2)
				end
			end
		end
	end

	-- 숨소리 (몸에 붙어 따라다님). 굳어 있을 때는 숨도 멈춤
	if mRoot ~= breathRoot then
		breathRoot = mRoot
		breathSound = Audio.loop("MonsterBreath", mRoot)
	end
	Audio.fade(breathSound, if frozen then 0 else (BREATH_BY_STATE[state or "Wander"] or 0), dt, 2)
	growlTimer -= dt
	if growlTimer <= 0 then
		growlTimer = math.random(7, 15)
		if state == "Wander" or state == "Investigate" or state == "Hunt" or state == "Search" then
			Audio.play("MonsterGrowl", mRoot, 1)
		end
	end
end)

---------------------------------------------------------------------------
-- 움직임: 달리기(Shift), 웅크리기(Ctrl) + 분위기(음악, 화면)
---------------------------------------------------------------------------
local P = Config.Player
local stamina = 1
local sprinting = false
local crouching = false

RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	local alive = hum ~= nil and hum.Health > 0
	local downed = player:GetAttribute("Downed") == true
	local running = false

	if hum and alive then
		if downed then
			-- 쓰러짐: 기어다니기만 가능
			hum.WalkSpeed = 2.5
			hum.JumpHeight = 0
			crouching = false
		else
			local moving = hum.MoveDirection.Magnitude > 0.1
			if sprinting and moving and stamina > 0 then
				stamina = math.max(0, stamina - dt / P.SprintTime)
				hum.WalkSpeed = P.SprintSpeed
				crouching = false
				running = true
			else
				if stamina <= 0 then
					sprinting = false
				end
				stamina = math.min(1, stamina + dt / P.SprintRecover)
				hum.WalkSpeed = if crouching then P.CrouchSpeed else P.WalkSpeed
			end
			hum.JumpHeight = if crouching then 0 else 7.2
		end
	end
	Hud.setStamina(stamina)

	-- 괴물과의 거리 → 긴장감. 관전 중이면 보고 있는 동료 기준
	local subject = Spectate.subjectRoot()
	if not subject and alive and myRoot and myRoot:IsA("BasePart") then
		subject = myRoot
	end
	local danger = 0
	local chasing = false
	local mRoot, state = monsterRoot()
	if mRoot and subject then
		local d = (mRoot.Position - subject.Position).Magnitude
		chasing = state == "Chase" and d < 110
		-- 쫓길 때는 멀리서도, 평소에는 아주 가까워야 느껴짐 (어디 있는지 알려주는 레이더가 되지 않게)
		danger = math.clamp(1 - d / (if chasing then 80 else 45), 0, 1)
	end
	Hud.setDanger(danger)

	local lowHealth = 0
	if hum and alive then
		lowHealth = math.clamp((0.45 - hum.Health / hum.MaxHealth) / 0.45, 0, 1) -- 체력 45% 아래부터 심장 소리
	end
	if downed then
		lowHealth = 1
	end
	local playing = inRound()
	Audio.update(dt, {
		playing = playing,
		danger = danger,
		chasing = chasing,
		lowHealth = lowHealth,
		alive = alive,
		storm = (ReplicatedStorage:GetAttribute("Act") or 1) >= 3,
	})
	Immersion.set({
		active = playing and alive,
		fear = danger,
		lowHealth = if playing and alive then lowHealth else 0,
		crouching = crouching and alive and not downed,
		sprinting = running,
		downed = downed and alive,
	})
end)

-- 내가 쓰러졌을 때
player:GetAttributeChangedSignal("Downed"):Connect(function()
	if player:GetAttribute("Downed") == true then
		Audio.play("Downed")
	end
end)

---------------------------------------------------------------------------
-- 캐릭터가 생길 때
---------------------------------------------------------------------------
local function onCharacter(character: Model)
	Hud.setDead(false)
	stamina = 1
	crouching = false
	Flashlight.reset()
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		Hud.setDead(true)
		Hud.setCraftOpen(false)
	end)
	-- 도구를 쓰면(클릭) 서버에 요청
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and not child:GetAttribute("Hooked") then
			child:SetAttribute("Hooked", true)
			child.Activated:Connect(function()
				if Hud.isCraftOpen() or player:GetAttribute("Disguised") == true then
					return
				end
				local itemId = child:GetAttribute("ItemId")
				if itemId then
					useToolRemote:FireServer(itemId, camera.CFrame.Position, camera.CFrame.LookVector)
				end
			end)
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------------------
-- 키 입력 (핸드폰 화면 버튼은 아래 TouchControls 에서 따로 만듦)
---------------------------------------------------------------------------
local function bind(name: string, title: string, callback: (began: boolean) -> (), sink: boolean, ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			callback(true)
		elseif inputState == Enum.UserInputState.End then
			callback(false)
		end
		return if sink then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, false, ...)
	ContextActionService:SetTitle(name, title)
end

local function reload()
	if not Flashlight.reload() then
		if (player:GetAttribute("Cell") or 0) < 1 then
			Hud.notify("건전지가 없다")
		end
	end
end

local function toggleCraft()
	if Hud.isNoteOpen() then
		Hud.closeNote()
	else
		MapUi.close()
		Hud.setCraftOpen(not Hud.isCraftPanelOpen())
	end
end

local function toggleMap()
	if inLobby() then
		return
	end
	if MapUi.isOpen() then
		MapUi.close()
	elseif MapUi.hasMap() then
		Hud.closeNote()
		Hud.setCraftOpen(false)
		MapUi.open()
	else
		Hud.notify("지도가 없다 — 벌목 캠프 한가운데 게시판에서 챙길 수 있다")
	end
end

bind("Flashlight", "빛", function(began)
	if began then
		Flashlight.toggle()
	end
end, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)

bind("Reload", "건전지", function(began)
	if began then
		reload()
	end
end, true, Enum.KeyCode.R, Enum.KeyCode.DPadRight)

bind("CraftMenu", "제작", function(began)
	if began then
		toggleCraft()
	end
end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonY)

bind("Map", "지도", function(began)
	if began then
		toggleMap()
	end
end, true, Enum.KeyCode.M, Enum.KeyCode.DPadDown)

-- 설정 창 조작 시작/끝 (터치 기기는 창을 바로 누르면 되므로 화면 버튼을 만들지 않음)
ContextActionService:BindAction("Settings", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Shop.close()
		Settings.toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.P)

-- 대기실 상점 조작 시작/끝
ContextActionService:BindAction("Shop", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Settings.close()
		Shop.toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.B)

-- 대기실: "지금 출발" (버튼이 떠 있을 때만)
ContextActionService:BindAction("LobbyStart", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and Hud.canLobbyStart() then
		Remotes.get("LobbyStart"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonX)

bind("Sprint", "달리기", function(began)
	sprinting = began and stamina > 0.1
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

bind("Crouch", "웅크리기", function(began)
	if began then
		crouching = not crouching
	end
end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("ShowObjectives", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Hud.showObjectives()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.DPadLeft)

---------------------------------------------------------------------------
-- 핸드폰/태블릿: 화면 버튼 (키보드가 없는 기기에서만 나타남)
---------------------------------------------------------------------------
local function aliveInRound(): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return inRound() and hum ~= nil and hum.Health > 0
end

local function standing(): boolean
	return aliveInRound() and player:GetAttribute("Downed") ~= true
end

TouchControls.start({
	-- 점프 버튼 둘레 (가까운 자리부터: 자주 쓰는 것)
	{
		id = "Sprint",
		text = "달리기",
		group = "action",
		-- 터치는 누르고 있기 어려워서 한 번 누르면 켜지고, 다시 누르거나 기운이 다 떨어지면 꺼짐
		onPress = function()
			sprinting = not sprinting and stamina > 0.1
		end,
		visible = standing,
		isOn = function()
			return sprinting
		end,
	},
	{
		id = "Flashlight",
		text = "손전등",
		group = "action",
		onPress = Flashlight.toggle,
		visible = aliveInRound,
		isOn = Flashlight.isOn,
	},
	{
		id = "Crouch",
		text = "웅크리기",
		group = "action",
		onPress = function()
			crouching = not crouching
		end,
		visible = standing,
		isOn = function()
			return crouching
		end,
	},
	{
		id = "Reload",
		text = "건전지",
		group = "action",
		onPress = reload,
		visible = aliveInRound,
	},
	{
		id = "Tracker",
		text = "추적",
		group = "action",
		onPress = Abilities.requestTracker,
		visible = function()
			return aliveInRound() and Abilities.owns("Tracker")
		end,
	},
	{
		id = "Disguise",
		text = "변신",
		group = "action",
		onPress = Abilities.requestDisguise,
		visible = function()
			return standing() and Abilities.owns("Disguise")
		end,
		isOn = function()
			return player:GetAttribute("Disguised") == true
		end,
	},
	-- 오른쪽 위 창 버튼
	{
		id = "Objectives",
		text = "목표",
		group = "menu",
		onPress = Hud.showObjectives,
		visible = inRound,
	},
	{
		id = "Craft",
		text = "제작",
		group = "menu",
		onPress = toggleCraft,
		visible = aliveInRound,
		isOn = Hud.isCraftPanelOpen,
	},
	{
		id = "Map",
		text = "지도",
		group = "menu",
		onPress = toggleMap,
		visible = aliveInRound,
		isOn = MapUi.isOpen,
	},
	{
		id = "Shop",
		text = "상점",
		group = "menu",
		onPress = function()
			Settings.close()
			Shop.toggle()
		end,
		visible = inLobby,
		isOn = Shop.isActive,
	},
	{
		id = "Settings",
		text = "설정",
		group = "menu",
		onPress = function()
			Shop.close()
			Settings.toggle()
		end,
		isOn = Settings.isActive,
	},
})

---------------------------------------------------------------------------
-- 서버가 보낸 효과
---------------------------------------------------------------------------
local function tempLight(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = p
	p.Parent = Workspace
	task.delay(duration, function()
		p:Destroy()
	end)
end

local function myPosition(): Vector3?
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if myRoot and myRoot:IsA("BasePart") then
		return myRoot.Position
	end
	return nil
end

-- 공격당하는 순간 시선이 괴물 쪽으로 살짝 끌려갔다가 원래대로 돌아옴
-- (예전처럼 카메라를 완전히 돌려놓지 않아서, 맞은 뒤에도 바로 도망칠 수 있어요)
local function jumpscare(facePos: Vector3)
	Immersion.glance(facePos)
end

Remotes.get("Effect").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
	if inLobby() then
		return
	end
	if kind == "Shot" then
		local origin: Vector3, hitPos: Vector3 = a, b
		local length = (hitPos - origin).Magnitude
		local tracer = Instance.new("Part")
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.CanTouch = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 120, 40)
		tracer.Size = Vector3.new(0.15, 0.15, length)
		tracer.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, -0.4, -length / 2)
		tracer.Parent = Workspace
		task.delay(0.08, function()
			tracer:Destroy()
		end)
		tempLight(hitPos, Color3.fromRGB(255, 120, 40), 30, 4, 2.5) -- 조명탄이라 한동안 주변을 밝힘
		tempLight(origin, Color3.fromRGB(255, 160, 80), 14, 3, 0.08)
		Audio.play("FlareGun", origin)
	elseif kind == "Flash" then
		local position: Vector3, radius: number = a, b
		tempLight(position, Color3.new(1, 1, 1), radius * 1.5, 12, 0.35)
		local me = myPosition()
		if me and (me - position).Magnitude < radius then
			Hud.flash(Color3.new(1, 1, 1), 0.15, 1.2)
		end
		Audio.play("Flashbang", position)
	elseif kind == "Hurt" then
		Hud.flash(Color3.fromRGB(120, 0, 0), 0.45, 0.9)
		Immersion.hurt()
		Immersion.shake(0.08, 0.5)
		Audio.play("PlayerHurt")
		if typeof(a) == "Vector3" then
			jumpscare(a)
		end
	elseif kind == "Heal" then
		Hud.flash(Color3.fromRGB(80, 255, 120), 0.8, 0.6)
		Audio.play("Heal")
	elseif kind == "HitMarker" then
		Hud.hitMarker()
	elseif kind == "MonsterHit" then
		tempLight(a, Color3.fromRGB(255, 60, 40), 10, 2, 0.15)
		Audio.play("MonsterHurt", a)
	elseif kind == "Scream" then
		Audio.play("MonsterScream", a :: Vector3) -- 멀리서도 들리지만 작게
		local me = myPosition()
		if me and (me - (a :: Vector3)).Magnitude < 100 then
			Immersion.shake(0.04, 0.9)
			Immersion.pulse(1)
		end
	elseif kind == "Scare" then
		-- 공포 연출 (a = 종류). 살아서 숲에 있을 때만
		if typeof(a) == "string" and inRound() and not Spectate.isActive() then
			Scares.play(a, b, c)
		end
	elseif kind == "Act" then
		-- 밤의 다음 막이 시작됨
		local line = Story.ActLines[a]
		if line then
			Hud.whisper(line)
		end
		if a == 3 then
			Weather.strike(1)
			Audio.play("Stinger", nil, 0.7)
		end
	elseif kind == "Sealed" then
		tempLight(a, Color3.fromRGB(160, 70, 255), 80, 8, 2.5)
		Hud.flash(Color3.fromRGB(160, 70, 255), 0.4, 2)
		Immersion.shake(0.05, 1.5)
		Audio.play("MonsterSealed", a)
	elseif kind == "Sfx" then
		-- 서버가 보낸 효과음 (a = 이름, b = 위치 또는 nil)
		if typeof(a) == "string" then
			Audio.play(a, if typeof(b) == "Vector3" then b else nil)
		end
	end
end)
