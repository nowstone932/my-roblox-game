-- 괴물 움직임 연출 (각 플레이어 화면에서 따로 계산)
--
-- 1) 기본 괴물: 서버가 만든 관절(Motor6D)을 매 프레임 비틀어서 동작을 만듭니다.
--    - 걷기/달리기, 쫓을 때 팔 뻗기, 공격, 기절 시 얼굴 가리기
--    - 고개가 "보고 있는 나"를 따라 돌아감 (각자 화면에서 자기를 쳐다봄)
--    - 가끔 뚝뚝 끊기듯 멈칫 (기괴한 느낌)
--    - 지켜보기(Stalk): 가만히 서서 고개를 천천히 갸웃
--    - 옷장 뒤지기(Search): 숙여서 킁킁
-- 2) 직접 만든 괴물 에셋(Assets.Monster)에 "Animations" 폴더가 있으면
--    그 안의 Idle / Walk / Run / Attack / Stunned / Scream 애니메이션을 재생합니다.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonsterAnimator = {}

local camera = Workspace.CurrentCamera

local phase = 0
local twitch = CFrame.new()
local nextTwitch = 0
local freezeUntil = 0

local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("Motor6D") then
		return found
	end
	return nil
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

local lastAttackSeen = 0
local function animateAsset(model: Model, state: string?, speed: number)
	local attackAt = model:GetAttribute("AttackAt") or 0
	if attackAt ~= lastAttackSeen and tracks.Attack then
		lastAttackSeen = attackAt
		tracks.Attack:Play(0.05)
	end
	if state == "Stunned" then
		play("Stunned")
	elseif state == "Downed" or state == "Sealed" then
		play("Stunned")
	elseif speed > 14 then
		play("Run", speed / 20)
	elseif speed > 1 then
		play("Walk", speed / 10)
	else
		play("Idle")
	end
end

-- 기본 괴물 (관절 직접 조작) ---------------------------------------------------
local function lookAtCamera(model: Model): CFrame
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return CFrame.new()
	end
	local rel = torso.CFrame:PointToObjectSpace(camera.CFrame.Position) - Vector3.new(0, 2.5, 0)
	local yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.3, 1.3)
	local pitch = math.clamp(math.atan2(rel.Y, Vector3.new(rel.X, 0, rel.Z).Magnitude), -0.7, 0.7)
	return CFrame.Angles(pitch, yaw, 0)
end

local function animateRig(model: Model, state: string?, speed: number, dt: number, now: number)
	local leftHip, rightHip = joint(model, "LeftHip"), joint(model, "RightHip")
	local leftArm, rightArm = joint(model, "LeftShoulder"), joint(model, "RightShoulder")
	local neck, rootJoint = joint(model, "Neck"), joint(model, "RootJoint")
	if not (leftHip or leftArm or neck) then
		return
	end

	-- 가끔 뚝 끊기듯 멈춤
	if now < freezeUntil then
		return
	end
	if math.random() < 0.006 then
		freezeUntil = now + math.random() * 0.25 + 0.08
	end

	phase += dt * speed * 0.32
	local walk = math.min(speed / 18, 1)
	local swing = math.sin(phase) * 0.75 * walk
	local searching = model:GetAttribute("Searching") == true

	if leftHip then
		leftHip.Transform = CFrame.Angles(swing, 0, 0)
	end
	if rightHip then
		rightHip.Transform = CFrame.Angles(-swing, 0, 0)
	end

	if rootJoint then
		local lean = -0.12
		if state == "Chase" then
			lean = -0.4
		elseif searching then
			lean = -0.55 + math.sin(now * 3) * 0.08
		elseif state == "Stalk" then
			lean = -0.05
		end
		rootJoint.Transform = CFrame.Angles(lean + math.sin(phase * 2) * 0.05 * walk, 0, math.sin(phase) * 0.06 * walk)
	end

	local attackAt = model:GetAttribute("AttackAt") or 0
	local attacking = now - attackAt < 0.35
	for i, arm in { leftArm, rightArm } do
		if arm then
			local side = if i == 1 then -1 else 1
			local cf
			if state == "Stunned" then
				cf = CFrame.Angles(-2.5, 0, side * -0.4) -- 얼굴을 가림
			elseif attacking then
				cf = CFrame.Angles(-1.9 + math.sin(now * 30) * 0.3, 0, side * -0.2)
			elseif state == "Chase" then
				cf = CFrame.Angles(-1.3 + swing * side * 0.25, 0, side * -0.15) -- 앞으로 뻗음
			elseif searching then
				cf = CFrame.Angles(-0.9 + math.sin(now * 4 + i) * 0.25, 0, side * -0.3) -- 옷장을 더듬음
			elseif state == "Stalk" then
				cf = CFrame.Angles(math.sin(now * 0.7 + i) * 0.04, 0, side * 0.05) -- 축 늘어뜨림
			else
				cf = CFrame.Angles(-swing * side * 0.5 + math.sin(now * 1.3 + i) * 0.05, 0, side * 0.08)
			end
			arm.Transform = cf
		end
	end

	if neck then
		if now > nextTwitch then
			nextTwitch = now + math.random() * 2.5 + 0.4
			twitch = CFrame.Angles((math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.5, (math.random() - 0.5) * 1.0)
		end
		local goal
		if state == "Stunned" then
			goal = CFrame.Angles(0.6, 0, 0)
		elseif searching then
			goal = CFrame.Angles(0.5 + math.sin(now * 9) * 0.1, math.sin(now * 2) * 0.6, 0) -- 킁킁
		elseif state == "Stalk" then
			goal = lookAtCamera(model) * CFrame.Angles(0, 0, math.sin(now * 0.8) * 0.6) -- 나를 보며 갸웃
		else
			goal = lookAtCamera(model) * twitch
		end
		neck.Transform = neck.Transform:Lerp(goal, math.min(dt * 10, 1))
	end
end

function MonsterAnimator.start()
	RunService.RenderStepped:Connect(function(dt)
		local model = Workspace:FindFirstChild("Monster")
		if not model or not model:IsA("Model") then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local state = model:GetAttribute("State")
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local now = os.clock()

		if model:GetAttribute("IsAsset") and loadTracks(model) then
			animateAsset(model, state, speed)
			return
		end
		if state == "Downed" or state == "Sealed" then
			return
		end
		animateRig(model, state, speed, dt, now)
	end)
end

return MonsterAnimator
