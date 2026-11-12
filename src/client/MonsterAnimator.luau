-- 괴물 움직임 연출 (각 플레이어 화면에서만 계산)
-- 서버가 만든 괴물의 관절(Motor6D)을 매 프레임 살짝 비틀어서
-- 걷기, 팔 뻗기, 고개 꺾기 같은 동작을 만듭니다.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonsterAnimator = {}

local phase = 0
local twitch = CFrame.new()
local nextTwitch = 0

local function joint(model: Model, name: string): Motor6D?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("Motor6D") then
		return found
	end
	return nil
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

		phase += dt * speed * 0.32
		local walk = math.min(speed / 18, 1)
		local swing = math.sin(phase) * 0.75 * walk

		local leftHip, rightHip = joint(model, "LeftHip"), joint(model, "RightHip")
		local leftArm, rightArm = joint(model, "LeftShoulder"), joint(model, "RightShoulder")
		local neck, rootJoint = joint(model, "Neck"), joint(model, "RootJoint")

		if state == "Downed" or state == "Sealed" then
			return
		end

		-- 다리
		if leftHip then
			leftHip.Transform = CFrame.Angles(swing, 0, 0)
		end
		if rightHip then
			rightHip.Transform = CFrame.Angles(-swing, 0, 0)
		end

		-- 몸통: 쫓을 땐 앞으로 숙임
		if rootJoint then
			local lean = if state == "Chase" then -0.35 else -0.12
			rootJoint.Transform = CFrame.Angles(lean + math.sin(phase * 2) * 0.04 * walk, 0, math.sin(phase) * 0.05 * walk)
		end

		-- 팔
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
					cf = CFrame.Angles(-1.25 + swing * side * 0.25, 0, side * -0.15) -- 앞으로 뻗음
				else
					cf = CFrame.Angles(-swing * side * 0.5 + math.sin(now * 1.3 + i) * 0.05, 0, side * 0.08)
				end
				arm.Transform = cf
			end
		end

		-- 고개: 가끔 뚝 꺾임
		if now > nextTwitch then
			nextTwitch = now + math.random() * 2.5 + 0.5
			twitch = CFrame.Angles((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.8, (math.random() - 0.5) * 0.9)
		end
		if neck then
			local base = if state == "Stunned" then CFrame.Angles(0.6, 0, 0) else CFrame.new()
			neck.Transform = neck.Transform:Lerp(base * twitch, math.min(dt * 12, 1))
		end
	end)
end

return MonsterAnimator
