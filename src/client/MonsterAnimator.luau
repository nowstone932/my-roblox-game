-- 괴물 움직임 연출 (각 플레이어 화면에서 따로 계산)
--
-- 1) 기본 괴물: 서버(MonsterAI)가 만든 관절(Motor6D)을 매 프레임 비틀어서 동작을 만듭니다.
--    관절: Waist(허리) Neck(목) Jaw(턱) + Left/Right Shoulder, Elbow, Hip, Knee
--    - 굽은 등, 꺾인 무릎으로 걷기/달리기. 쫓을 때는 긴 팔을 앞으로 뻗음
--    - 울부짖을 때 팔을 벌리고 턱이 벌어짐, 공격할 때 내리찍음
--    - 지켜보기(Stalk): 내가 쳐다보는 동안(Frozen)은 걷던 자세 그대로 돌처럼 굳고,
--      고개만 아주 천천히 나를 따라옵니다. 눈을 떼면 낮게 기어옴
--    - 손전등 빛이 눈에 닿으면 짐승 눈처럼 번쩍임
--    - 옷장 뒤지기(Search): 숙여서 킁킁
-- 2) 직접 만든 괴물 에셋(Assets.Monster)에 "Animations" 폴더가 있으면
--    그 안의 Idle / Walk / Run / Attack / Stunned / Scream 애니메이션을 재생합니다.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonsterAnimator = {}

local camera = Workspace.CurrentCamera

local EYE_DARK = Color3.fromRGB(14, 12, 10)
local EYE_SHINE = Color3.fromRGB(200, 255, 215)
local ATTACK_TIME = 0.45
local SCREAM_TIME = 1.2

-- 지금 보고 있는 괴물 모델에 대한 정보
local boundModel: Model? = nil
local joints: { [string]: Motor6D } = {}
local eyes: { BasePart } = {}
local lastBind = 0

local phase = 0
local twitch = CFrame.new()
local nextTwitch = 0
local stutterUntil = 0
local lastAttack = 0
local lastScream = 0
local attackStart = -10
local screamStart = -10
local heldLean = -0.3

local isLightOn: () -> boolean = function()
	return true
end

local function bind(model: Model, now: number)
	local fresh = boundModel ~= model
	if not fresh and (joints.Waist or now - lastBind < 0.5) then
		return
	end
	boundModel = model
	lastBind = now
	joints = {}
	eyes = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		elseif d:IsA("BasePart") and d.Name:lower():find("eye") then
			table.insert(eyes, d)
		end
	end
	if fresh then
		lastAttack = model:GetAttribute("AttackCount") or 0
		lastScream = model:GetAttribute("ScreamCount") or 0
		attackStart, screamStart = -10, -10
	end
end

-- 서버가 올린 횟수(AttackCount/ScreamCount)가 바뀌면 그 순간부터 동작을 시작
local function pollEvents(model: Model, now: number): (boolean, boolean)
	local attackCount = model:GetAttribute("AttackCount") or 0
	local attacked = attackCount ~= lastAttack
	if attacked then
		lastAttack = attackCount
		attackStart = now
	end
	local screamCount = model:GetAttribute("ScreamCount") or 0
	local screamed = screamCount ~= lastScream
	if screamed then
		lastScream = screamCount
		screamStart = now
	end
	return attacked, screamed
end

-- 에셋 애니메이션 -----------------------------------------------------------
local trackModel: Model? = nil
local tracks: { [string]: AnimationTrack } = {}
local playing: string? = nil

local function loadTracks(model: Model): boolean
	if trackModel == model then
		return next(tracks) ~= nil
	end
	trackModel = model
	tracks = {}
	playing = nil
	local folder = model:FindFirstChild("Animations")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (folder and hum) then
		return false
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, anim in folder:GetChildren() do
		if anim:IsA("Animation") then
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				tracks[anim.Name] = track
			end
		end
	end
	return next(tracks) ~= nil
end

local function play(name: string, speed: number?)
	local track = tracks[name] or tracks.Walk or tracks.Idle
	if not track then
		return
	end
	if playing ~= name then
		for n, t in tracks do
			if n ~= name and t.IsPlaying and n ~= "Attack" and n ~= "Scream" then
				t:Stop(0.25)
			end
		end
		track.Looped = name ~= "Attack" and name ~= "Scream"
		track:Play(0.25)
		playing = name
	end
	if speed then
		track:AdjustSpeed(speed)
	end
end

local function animateAsset(model: Model, state: string?, speed: number, now: number)
	local attacked, screamed = pollEvents(model, now)
	if attacked and tracks.Attack then
		tracks.Attack:Play(0.05)
	end
	if screamed and tracks.Scream then
		tracks.Scream:Play(0.1)
	end
	local frozen = model:GetAttribute("Frozen") == true
	if state == "Stunned" or state == "Downed" or state == "Sealed" then
		play("Stunned")
	elseif frozen then
		play("Idle", 0) -- 쳐다보는 동안은 그대로 멈춤
	elseif speed > 14 then
		play("Run", speed / 20)
	elseif speed > 1 then
		play("Walk", speed / 10)
	else
		play("Idle", 1)
	end
end

-- 기본 괴물 (관절 직접 조작) ---------------------------------------------------
local function set(name: string, goal: CFrame, alpha: number)
	local j = joints[name]
	if j then
		j.Transform = j.Transform:Lerp(goal, math.min(alpha, 1))
	end
end

-- 괴물 머리에서 내 카메라를 바라보는 각도 (좌우, 위아래)
local function lookAngles(root: BasePart): (number, number)
	local rel = root.CFrame:PointToObjectSpace(camera.CFrame.Position) - Vector3.new(0, 4.5, -1.5)
	local yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.2, 1.2)
	local pitch = math.clamp(math.atan2(rel.Y, Vector3.new(rel.X, 0, rel.Z).Magnitude), -0.9, 0.5)
	return yaw, pitch
end

local function headGoal(lean: number, yaw: number, pitch: number, roll: number): CFrame
	-- 허리가 숙여진 만큼 고개를 들어서 앞을 보게 한 다음, 좌우/위아래로 돌림
	return CFrame.Angles(-lean * 0.7, 0, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
end

local function updateEyes()
	local camPos = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local lit = isLightOn()
	for _, eye in eyes do
		if eye.Parent then
			local shine = 0
			local offset = eye.Position - camPos
			local dist = offset.Magnitude
			if lit and dist > 1 and dist < 110 then
				local dir = offset.Unit
				local inBeam = math.clamp((look:Dot(dir) - 0.9) / 0.07, 0, 1) -- 손전등 빛줄기 안에 있는지
				local facing = math.clamp(eye.CFrame.LookVector:Dot(-dir) * 2, 0, 1) -- 괴물이 이쪽을 보고 있는지
				shine = inBeam * facing * math.clamp(1.25 - dist / 110, 0, 1)
			end
			eye.Color = EYE_DARK:Lerp(EYE_SHINE, shine)
		end
	end
end

local function animateRig(model: Model, root: BasePart, state: string?, speed: number, dt: number, now: number)
	if not joints.Waist then
		return
	end
	pollEvents(model, now)
	updateEyes()

	-- 쳐다보는 동안: 걷던 자세 그대로 굳음. 고개만 아주 천천히 따라옴
	if model:GetAttribute("Frozen") == true then
		local yaw, pitch = lookAngles(root)
		set("Neck", headGoal(heldLean, yaw, pitch, 0.32), dt * 1.2)
		return
	end

	local attackT = now - attackStart
	local screamT = now - screamStart
	local attacking = attackT < ATTACK_TIME
	local scream = if screamT < SCREAM_TIME and not attacking then math.sin(screamT / SCREAM_TIME * math.pi) else 0

	-- 가끔 뚝 끊기듯 멈칫 (기괴한 느낌)
	if now < stutterUntil then
		return
	end
	if not attacking and scream == 0 and math.random() < 0.005 then
		stutterUntil = now + math.random() * 0.22 + 0.06
	end

	local crouch = model:GetAttribute("Crouch") == true
	local searching = model:GetAttribute("Searching") == true
	local fast = dt * 14

	phase += dt * speed * 0.3
	local walk = math.min(speed / 16, 1)
	local s = math.sin(phase)
	local c = math.cos(phase)

	-- 허리: 굽은 등
	local lean = -0.28
	if crouch then
		lean = -1.05
	elseif state == "Stunned" then
		lean = 0.12
	elseif searching then
		lean = -0.8 + math.sin(now * 3) * 0.06
	elseif state == "Chase" then
		lean = -0.55
	elseif state == "Stalk" then
		lean = -0.5 -- 낮게 기어옴
	end
	lean += (0.2 - lean) * scream * 0.8 -- 울부짖을 때 몸을 일으킴
	heldLean = lean
	local breath = math.sin(now * 1.7) * 0.025
	set("Waist", CFrame.Angles(lean + breath + math.sin(phase * 2) * 0.04 * walk, s * 0.08 * walk, s * 0.05 * walk), fast)

	for i, prefix in { "Left", "Right" } do
		local side = if i == 1 then -1 else 1
		local swing = s * side -- 이 다리가 앞으로 나가는 정도 (-1 ~ 1)
		local lift = math.max(0, c * side) -- 발을 들어 옮기는 구간

		-- 다리: 평소에도 무릎이 꺾여 있음
		if crouch then
			set(prefix .. "Hip", CFrame.Angles(1.2 + swing * 0.22, 0, side * 0.14), fast)
			set(prefix .. "Knee", CFrame.Angles(-2.48 + lift * 0.15, 0, 0), fast)
		else
			set(prefix .. "Hip", CFrame.Angles(0.38 + swing * 0.5 * walk, 0, 0), fast)
			set(prefix .. "Knee", CFrame.Angles(-0.76 - lift * 0.55 * walk, 0, 0), fast)
		end

		-- 팔: 어깨(앞뒤), 팔꿈치(굽힘), 옆으로 벌림
		local armSwing = -swing
		local shoulder, elbow, out
		if state == "Stunned" then
			shoulder, elbow, out = 2.3, 1.7, -0.35 -- 얼굴을 가림
		elseif attacking then
			local p = attackT / ATTACK_TIME
			shoulder, elbow, out = 3 - 2 * p * p, 0.3 + 0.7 * p, 0.25 - 0.4 * p -- 위에서 내리찍음
		elseif crouch then
			shoulder, elbow, out = 1.3 + armSwing * 0.3, 0.35, 0.2 -- 바닥을 짚으며 기어감
		elseif state == "Chase" then
			shoulder, elbow, out = 1.75 + armSwing * 0.25 * walk, 0.45 + math.sin(now * 7 + i) * 0.08, 0.12 -- 앞으로 뻗음
		elseif searching then
			shoulder, elbow, out = 1.2 + math.sin(now * 4 + i) * 0.25, 0.7, -0.1 -- 옷장을 더듬음
		elseif state == "Stalk" then
			shoulder, elbow, out = 0.8 + armSwing * 0.2 * walk, 0.25, 0.1
		else
			shoulder = -lean * 0.8 + armSwing * 0.3 * walk + math.sin(now * 1.1 + i) * 0.04 -- 축 늘어뜨림
			elbow, out = 0.2 + 0.1 * walk, 0.06
		end
		if scream > 0 then
			shoulder += (-0.45 - shoulder) * scream
			elbow += (0.5 - elbow) * scream
			out += (0.75 - out) * scream
		end
		local armRate = if attacking then dt * 30 else fast
		set(prefix .. "Shoulder", CFrame.Angles(shoulder, 0, side * out), armRate)
		set(prefix .. "Elbow", CFrame.Angles(elbow, 0, 0), armRate)
	end

	-- 고개
	if now > nextTwitch then
		nextTwitch = now + math.random() * 2.5 + 0.4
		twitch = CFrame.Angles((math.random() - 0.5) * 0.3, (math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.8)
	end
	local goal: CFrame
	if state == "Stunned" then
		goal = headGoal(lean, math.sin(now * 23) * 0.15, -0.6, 0)
	elseif searching then
		goal = headGoal(lean, math.sin(now * 2) * 0.6, -0.3 + math.sin(now * 9) * 0.08, 0) -- 킁킁
	elseif state == "Chase" or state == "Stalk" or state == "Search" then
		local yaw, pitch = lookAngles(root)
		local roll = if state == "Stalk" then math.sin(now * 0.7) * 0.35 else 0 -- 나를 보며 갸웃
		goal = headGoal(lean, yaw, pitch + scream * 0.5, roll) * twitch
	else
		-- 아무도 못 봤을 때: 천천히 두리번거림
		goal = headGoal(lean, math.sin(now * 0.45) * 0.55, math.sin(now * 0.31) * 0.12 + scream * 0.5, 0) * twitch
	end
	if scream > 0 then
		goal *= CFrame.Angles(0, 0, math.sin(now * 38) * 0.06 * scream)
	end
	set("Neck", goal, dt * 9)

	-- 턱
	local jaw = 0.03 + breath
	if attacking then
		jaw = 0.7
	elseif state == "Chase" then
		jaw = 0.22 + math.sin(now * 8) * 0.06 -- 헐떡임
	elseif searching then
		jaw = 0.1 + math.sin(now * 9) * 0.05
	end
	jaw += scream * 0.85
	set("Jaw", CFrame.Angles(-jaw, 0, 0), dt * 18)
end

-- options.isLightOn: 내 손전등이 켜져 있는지 알려주는 함수 (눈 번쩍임 계산용)
-- 가까이 있을 때만 몸 윤곽이 희미하게 보임 (어두워도 "저기 뭔가 서 있다"는 건 알아볼 수 있게)
local function updateOutline(model: Model, root: BasePart)
	local found = model:FindFirstChild("Presence")
	local outline: Highlight
	if found and found:IsA("Highlight") then
		outline = found
	else
		outline = Instance.new("Highlight")
		outline.Name = "Presence"
		outline.FillTransparency = 1
		outline.OutlineColor = Color3.fromRGB(170, 180, 205)
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Adornee = model
		outline.Parent = model
	end
	local d = (root.Position - camera.CFrame.Position).Magnitude
	outline.OutlineTransparency = 1 - 0.55 * (1 - math.clamp((d - 25) / 45, 0, 1))
end

function MonsterAnimator.start(options: { isLightOn: (() -> boolean)? }?)
	if options and options.isLightOn then
		isLightOn = options.isLightOn
	end
	RunService.RenderStepped:Connect(function(dt)
		local model = Workspace:FindFirstChild("Monster")
		if not model or not model:IsA("Model") then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		updateOutline(model, root)
		local state = model:GetAttribute("State")
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local now = os.clock()

		if model:GetAttribute("IsAsset") and loadTracks(model) then
			bind(model, now)
			updateEyes() -- 에셋 괴물도 이름에 Eye 가 들어간 파트는 손전등 빛에 번쩍임
			animateAsset(model, state, speed, now)
			return
		end
		if state == "Downed" or state == "Sealed" then
			return
		end
		bind(model, now)
		animateRig(model, root, state, speed, dt, now)
	end)
end

return MonsterAnimator
