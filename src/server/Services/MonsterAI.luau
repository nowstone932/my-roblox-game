-- "숲지기" 괴물 AI
--
-- 생김새: 키 4~5미터, 사슴 두개골 얼굴과 뿔, 나뭇가지 같은 긴 팔, 검은 연기.
-- 상태:
--   Wander      배회 (가끔 플레이어 근처로 슬금슬금 옴)
--   Investigate 소리(총소리, 트럭 시동, 무전)가 난 곳을 조사하러 감
--   Chase       플레이어를 보고 추격
--   Stalk       멀리서 가만히 서서 지켜봄 → 갑자기 돌진하거나, 사라졌다가 등 뒤 어딘가에 나타남
--   Search      옷장에 숨는 걸 봤으면 옷장 앞에서 냄새를 맡음 → 확률적으로 문을 열어젖힘
--   Stunned     섬광탄/덫에 걸려 잠시 멈춤
--   Downed      체력이 0이 되어 쓰러짐 → 일정 시간 뒤 다시 일어남 (이때 봉인 말뚝 가능)
--   Sealed      봉인됨 (영구 퇴치)
-- 옷장에 숨은 플레이어는 보지 못합니다. 나무 뒤에 숨으면 시야가 가려져요.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local notify = Remotes.get("Notify")
local effect = Remotes.get("Effect")
local C = Config.Monster

local MonsterAI = {}

-- 다른 모듈이 등록하는 콜백
MonsterAI.onSealed = nil :: (() -> ())? -- 봉인됨 (GameLoop)
MonsterAI.onPlayerDowned = nil :: ((Player) -> ())? -- 플레이어 치명상 → 쓰러짐 (GameLoop)
MonsterAI.onClosetRipped = nil :: ((Player) -> ())? -- 옷장을 열어젖힘 (Hiding)

local map = nil
local running = false
local generation = 0

local model: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local eyes: { BasePart } = {}

local state = "Wander"
local hp = C.MaxHealth
local rage = 0
local stunnedUntil = 0
local downedUntil = 0
local target: Player? = nil
local lastSeenPos: Vector3? = nil
local lastSeenTime = 0
local lastAttack = 0
local investigatePos: Vector3? = nil
local investigateStart = 0

local wanderGoal: Vector3? = nil
local wanderStarted = 0

local waypoints: { PathWaypoint } = {}
local waypointIndex = 1
local lastPathTime = 0
local lastPathGoal: Vector3? = nil

local traps: { BasePart } = {}

-- 공포 연출용 상태
local lastTargetTime = 0 -- 마지막으로 누군가를 쫓은 시각 (기습 순간이동 판단)
local lastStalk = -999
local stalkUntil = 0
local stalkTarget: Player? = nil
local lastLunge = 0
local lungeUntil = 0
local searchPos: Vector3? = nil
local searchTarget: Player? = nil
local searchArrived: number? = nil

local rng = Random.new()

local function setState(newState: string)
	if state == newState then
		return
	end
	if newState == "Chase" and (state == "Wander" or state == "Investigate") and root then
		effect:FireAllClients("Scream", root.Position)
	end
	state = newState
	if model then
		model:SetAttribute("State", newState)
	end
end

---------------------------------------------------------------------------
-- 생김새
---------------------------------------------------------------------------
local BONE = Color3.fromRGB(205, 198, 180)
local BODY = Color3.fromRGB(22, 18, 16)
local EYE = Color3.fromRGB(255, 30, 30)

local function newPart(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide == true
	p.Massless = collide ~= true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- 장식 파트를 부모에 붙임 (offset은 부모 기준)
local function attach(m: Model, parent: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = newPart(m, "Detail", size, parent.CFrame * offset, color, material)
	p.CanQuery = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	part1.CFrame = part0.CFrame * c0 * c1:Inverse()
end

local function buildModel(position: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Monster"
	local base = CFrame.new(position)

	local hrp = newPart(m, "HumanoidRootPart", Vector3.new(2.6, 4.5, 1.4), base, BODY)
	hrp.Transparency = 1
	local torso = newPart(m, "Torso", Vector3.new(2.6, 4.5, 1.4), base, BODY, Enum.Material.Slate, true)
	motor("RootJoint", hrp, torso, CFrame.new(), CFrame.new())

	-- 갈비뼈, 굽은 등
	for i = 0, 3 do
		attach(m, torso, Vector3.new(2.2 - i * 0.2, 0.18, 0.2), CFrame.new(0, 1.4 - i * 0.55, -0.72), BONE)
	end
	attach(m, torso, Vector3.new(0.4, 3.8, 0.4), CFrame.new(0, 0.2, 0.75), BONE) -- 등뼈
	attach(m, torso, Vector3.new(3.4, 1.2, 1.8), CFrame.new(0, 1.9, 0.1), BODY, Enum.Material.Slate) -- 어깨

	-- 머리: 사슴 두개골
	local head = newPart(m, "Head", Vector3.new(1.5, 1.8, 1.8), base, BONE)
	motor("Neck", torso, head, CFrame.new(0, 2.5, -0.3), CFrame.new(0, -0.9, 0.2))
	attach(m, head, Vector3.new(1, 0.9, 1.6), CFrame.new(0, -0.45, -1.4), BONE) -- 주둥이
	attach(m, head, Vector3.new(0.8, 0.2, 0.3), CFrame.new(0, -0.85, -2.05), Color3.fromRGB(30, 25, 20)) -- 이빨 자리
	for _, side in { -1, 1 } do
		attach(m, head, Vector3.new(0.5, 0.45, 0.2), CFrame.new(side * 0.42, 0.15, -0.86), Color3.new(0, 0, 0)) -- 눈구멍
		table.insert(eyes, attach(m, head, Vector3.new(0.22, 0.22, 0.1), CFrame.new(side * 0.42, 0.15, -0.95), EYE, Enum.Material.Neon))
		-- 뿔
		local beamCf = CFrame.new(side * 0.55, 0.8, 0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(side * -30))
		local beam = attach(m, head, Vector3.new(0.28, 4, 0.28), beamCf * CFrame.new(0, 2, 0), Color3.fromRGB(150, 140, 120), Enum.Material.Wood)
		for t = 0, 2 do
			attach(m, beam, Vector3.new(0.2, 1.6 - t * 0.3, 0.2), CFrame.new(0, -1 + t * 1.1, 0) * CFrame.Angles(math.rad(-40), 0, math.rad(side * 45)) * CFrame.new(0, 0.7, 0), Color3.fromRGB(150, 140, 120), Enum.Material.Wood)
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = head

	-- 긴 팔과 갈고리 손톱
	for _, side in { -1, 1 } do
		local arm = newPart(m, if side < 0 then "LeftArm" else "RightArm", Vector3.new(0.6, 8, 0.6), base, BODY, Enum.Material.Wood)
		motor(if side < 0 then "LeftShoulder" else "RightShoulder", torso, arm, CFrame.new(side * 1.9, 1.9, 0), CFrame.new(0, 3.7, 0))
		attach(m, arm, Vector3.new(0.75, 0.6, 0.75), CFrame.new(0, 0.3, 0), BODY, Enum.Material.Slate) -- 팔꿈치
		for k = -1, 1 do
			attach(m, arm, Vector3.new(0.12, 1.6, 0.12), CFrame.new(k * 0.22, -4.4, -0.2) * CFrame.Angles(math.rad(25), 0, math.rad(k * 10)), BONE)
		end
		local leg = newPart(m, if side < 0 then "LeftLeg" else "RightLeg", Vector3.new(0.8, 6.5, 0.8), base, BODY, Enum.Material.Wood)
		motor(if side < 0 then "LeftHip" else "RightHip", torso, leg, CFrame.new(side * 0.8, -2.25, 0), CFrame.new(0, 3.25, 0))
		attach(m, leg, Vector3.new(0.9, 0.5, 1.6), CFrame.new(0, -3.1, -0.4), BODY, Enum.Material.Slate) -- 발굽
	end

	-- 몸에서 피어오르는 검은 연기
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 10, 12))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Rate = 10
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.LightInfluence = 1
	smoke.Parent = torso

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.RequiresNeck = false
	hum.HipHeight = 6.5 -- 다리 길이
	hum.MaxHealth = math.huge -- 체력은 스크립트(hp)로 따로 관리
	hum.Health = math.huge
	hum.WalkSpeed = C.WanderSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = m

	m.PrimaryPart = hrp
	m:SetAttribute("State", "Wander")
	m:PivotTo(base + Vector3.new(0, 6, 0))
	m.Parent = Workspace
	hrp:SetNetworkOwner(nil)
	return m
end

---------------------------------------------------------------------------
-- 감각
---------------------------------------------------------------------------
local function aliveCharacter(player: Player): (Model?, BasePart?)
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true or player:GetAttribute("Hiding") == true then
		return nil, nil
	end
	if player:GetAttribute("Downed") == true then
		return nil, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and hrp then
		return char, hrp :: BasePart
	end
	return nil, nil
end

local function canSee(char: Model, hrp: BasePart): boolean
	if not (model and root) then
		return false
	end
	local origin = root.Position + Vector3.new(0, 4, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(origin, hrp.Position - origin, params)
	return result == nil or result.Instance:IsDescendantOf(char)
end

local function findTarget(): (Player?, BasePart?)
	if not root then
		return nil, nil
	end
	local best, bestPart, bestDist = nil, nil, C.SightRange
	for _, player in Players:GetPlayers() do
		local char, hrp = aliveCharacter(player)
		if char and hrp then
			local dist = (hrp.Position - root.Position).Magnitude
			if dist < bestDist and (dist < C.HearRange or canSee(char, hrp)) then
				best, bestPart, bestDist = player, hrp, dist
			end
		end
	end
	return best, bestPart
end

---------------------------------------------------------------------------
-- 이동
---------------------------------------------------------------------------
local function moveTo(goal: Vector3)
	if not (humanoid and root) then
		return
	end
	local now = os.clock()
	if (goal - root.Position).Magnitude < 20 then
		waypoints = {}
		humanoid:MoveTo(goal)
		return
	end

	local interval = if state == "Chase" then 0.8 else 2.5
	local goalMoved = lastPathGoal == nil or (goal - lastPathGoal).Magnitude > 8
	if now - lastPathTime > interval and (goalMoved or #waypoints == 0 or now - lastPathTime > 3) then
		lastPathTime = now
		lastPathGoal = goal
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 14,
			AgentCanJump = false,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			waypointIndex = math.min(2, #waypoints)
		else
			waypoints = {}
		end
		if not (humanoid and root) then
			return
		end
	end

	if #waypoints == 0 then
		humanoid:MoveTo(goal)
		return
	end
	local wp = waypoints[waypointIndex]
	local flat = Vector3.new(wp.Position.X - root.Position.X, 0, wp.Position.Z - root.Position.Z)
	if flat.Magnitude < 4 and waypointIndex < #waypoints then
		waypointIndex += 1
		wp = waypoints[waypointIndex]
	end
	humanoid:MoveTo(wp.Position)
end

local function chaseSpeed(): number
	return C.ChaseSpeed + rage * C.RagePerStage
end

local function tryAttack()
	if not root or os.clock() - lastAttack < C.AttackCooldown then
		return
	end
	for _, player in Players:GetPlayers() do
		local char, hrp = aliveCharacter(player)
		if char and hrp then
			local flat = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z)
			if flat.Magnitude <= C.AttackRange and math.abs(hrp.Position.Y - root.Position.Y) < 12 then
				lastAttack = os.clock()
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					if model then
						model:SetAttribute("AttackAt", os.clock())
					end
					local head = model and model:FindFirstChild("Head")
					local facePos = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 5, 0)
					effect:FireClient(player, "Hurt", facePos)
					if hum.Health - C.AttackDamage <= 0 and MonsterAI.onPlayerDowned then
						-- 바로 죽지 않고 쓰러짐. 괴물은 다른 먹잇감을 찾아 떠남
						MonsterAI.onPlayerDowned(player)
						target = nil
						setState("Wander")
						wanderGoal = nil
					else
						hum:TakeDamage(C.AttackDamage)
					end
				end
				return
			end
		end
	end
end

local function setEyes(color: Color3)
	for _, eye in eyes do
		if eye.Parent then
			eye.Color = color
		end
	end
end

local function pickWanderGoal(): Vector3
	-- 일정 확률로 아무 플레이어 근처로 (긴장감)
	if rng:NextNumber() < C.NearPlayerWanderChance then
		local candidates = {}
		for _, player in Players:GetPlayers() do
			local _, hrp = aliveCharacter(player)
			if hrp then
				table.insert(candidates, hrp.Position)
			end
		end
		if #candidates > 0 then
			local p = candidates[rng:NextInteger(1, #candidates)]
			local offset = Vector3.new(rng:NextNumber(-50, 50), 0, rng:NextNumber(-50, 50))
			return p + offset
		end
	end
	local half = map.HalfSize - 30
	return Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half + 30, half))
end

local function checkTraps()
	if not root then
		return
	end
	for i = #traps, 1, -1 do
		local trap = traps[i]
		if not trap.Parent then
			table.remove(traps, i)
		else
			local flat = Vector3.new(trap.Position.X - root.Position.X, 0, trap.Position.Z - root.Position.Z)
			if flat.Magnitude < 3.5 then
				table.remove(traps, i)
				trap.Color = Color3.fromRGB(150, 20, 20)
				task.delay(Config.Tools.Trap.HoldTime, function()
					trap:Destroy()
				end)
				MonsterAI.stun(Config.Tools.Trap.HoldTime)
				notify:FireAllClients("괴물이 곰덫에 걸렸다!")
				return
			end
		end
	end
end

local function revive()
	if not (model and humanoid and root) then
		return
	end
	hp = C.MaxHealth
	humanoid.PlatformStand = false
	model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 8, 0)))
	setEyes(EYE)
	setState("Wander")
	wanderGoal = nil
	notify:FireAllClients("숲지기가 다시 일어났다…!")
end

-- 모든 플레이어에게서 안 보이는지 (머리 → 지점 레이가 막히면 안 보임)
local function hiddenFromEveryone(pos: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local char, hrp = aliveCharacter(player)
		if char and hrp then
			local head = char:FindFirstChild("Head")
			local from = if head and head:IsA("BasePart") then head.Position else hrp.Position
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char, model :: Instance }
			local dir = (pos + Vector3.new(0, 6, 0)) - from
			if dir.Magnitude < 25 or not Workspace:Raycast(from, dir, params) then
				return false
			end
		end
	end
	return true
end

local function groundAt(pos: Vector3): Vector3?
	local result = Workspace:Raycast(Vector3.new(pos.X, 80, pos.Z), Vector3.new(0, -100, 0))
	if result and result.Position.Y < 2 and math.abs(pos.X) < map.HalfSize - 15 and math.abs(pos.Z) < map.HalfSize - 15 then
		return result.Position
	end
	return nil
end

local function teleportTo(pos: Vector3)
	if not (model and root) then
		return
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 9, 0)))
	waypoints = {}
	lastPathGoal = nil
end

-- 플레이어 등 뒤, 시야 밖 어딘가로 순간이동
local function ambush(): boolean
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local _, hrp = aliveCharacter(player)
		if hrp then
			table.insert(candidates, { player = player, hrp = hrp })
		end
	end
	if #candidates == 0 then
		return false
	end
	local pick = candidates[rng:NextInteger(1, #candidates)]
	local look = pick.hrp.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	for _ = 1, 10 do
		local dist = rng:NextNumber(C.AmbushDistance[1], C.AmbushDistance[2])
		local angle = rng:NextNumber(-0.9, 0.9)
		local dir = (CFrame.Angles(0, angle, 0) * -look)
		local ground = groundAt(pick.hrp.Position + dir * dist)
		if ground and hiddenFromEveryone(ground) then
			teleportTo(ground)
			investigatePos = pick.hrp.Position
			investigateStart = os.clock()
			setState("Investigate")
			return true
		end
	end
	return false
end

-- 연기처럼 사라졌다가 먼 곳에 나타남
local function vanish()
	if not root then
		return
	end
	effect:FireAllClients("Vanish", root.Position)
	for _ = 1, 15 do
		local half = map.HalfSize - 40
		local ground = groundAt(Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half)))
		if ground and hiddenFromEveryone(ground) then
			teleportTo(ground)
			break
		end
	end
	wanderGoal = nil
	setState("Wander")
	lastTargetTime = os.clock() - C.AmbushAfter * 0.5 -- 잠시 뒤 다시 기습하러 옴
end

local function faceTowards(pos: Vector3)
	if root then
		local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

---------------------------------------------------------------------------
-- 매 0.2초마다 실행
---------------------------------------------------------------------------
local function update()
	if not (model and humanoid and root) or state == "Sealed" then
		return
	end
	local now = os.clock()

	if state == "Downed" then
		if now >= downedUntil then
			revive()
		end
		return
	end

	if now < stunnedUntil then
		humanoid.WalkSpeed = 0
		humanoid:MoveTo(root.Position)
		return
	elseif state == "Stunned" then
		setEyes(EYE)
		setState("Wander")
	end

	checkTraps()
	model:SetAttribute("Searching", false)

	-- 옷장 뒤지기
	if state == "Search" and searchPos then
		if not searchArrived then
			humanoid.WalkSpeed = chaseSpeed()
			moveTo(searchPos)
			if (Vector3.new(searchPos.X, root.Position.Y, searchPos.Z) - root.Position).Magnitude < 7 then
				searchArrived = now
			end
			if now - investigateStart > 15 then
				setState("Wander")
			end
		else
			humanoid.WalkSpeed = 0
			humanoid:MoveTo(root.Position)
			faceTowards(searchPos)
			model:SetAttribute("Searching", true)
			if now - searchArrived > 3.5 then
				local victim = searchTarget
				searchArrived = nil
				searchPos = nil
				searchTarget = nil
				if victim and victim:GetAttribute("Hiding") == true and rng:NextNumber() < C.ClosetSearchChance and MonsterAI.onClosetRipped then
					MonsterAI.onClosetRipped(victim)
					effect:FireAllClients("Scream", root.Position)
				else
					wanderGoal = nil
					setState("Wander")
				end
			end
		end
		return
	end

	-- 지켜보기
	if state == "Stalk" then
		humanoid.WalkSpeed = 0
		humanoid:MoveTo(root.Position)
		local hrp: BasePart? = nil
		if stalkTarget then
			local _, found = aliveCharacter(stalkTarget)
			hrp = found
		end
		if not hrp then
			vanish()
			return
		end
		faceTowards(hrp.Position)
		local dist = (hrp.Position - root.Position).Magnitude
		if now > stalkUntil or dist < 22 then
			if rng:NextNumber() < 0.5 then
				target = stalkTarget
				lastSeenPos = hrp.Position
				lastSeenTime = now
				setState("Chase")
				lungeUntil = now + C.LungeTime
				lastLunge = now
			else
				vanish()
			end
		end
		return
	end

	local player, hrp = findTarget()
	if player and hrp then
		local dist = (hrp.Position - root.Position).Magnitude
		local canStalk = (state == "Wander" or state == "Investigate")
			and dist > C.StalkMinDistance
			and now - lastStalk > C.StalkCooldown
			and rng:NextNumber() < C.StalkChance
		if canStalk then
			stalkTarget = player
			stalkUntil = now + rng:NextNumber(C.StalkTime[1], C.StalkTime[2])
			lastStalk = now
			setState("Stalk")
			return
		end
		target = player
		lastSeenPos = hrp.Position
		lastSeenTime = now
		lastTargetTime = now
		setState("Chase")
	elseif state == "Chase" and now - lastSeenTime > C.LoseSightTime then
		target = nil
		wanderGoal = nil
		setState("Wander")
	end

	if state == "Chase" and lastSeenPos then
		lastTargetTime = now
		-- 돌진
		local dist = (lastSeenPos - root.Position).Magnitude
		if dist > 12 and dist < 30 and now - lastLunge > C.LungeCooldown and rng:NextNumber() < 0.3 then
			lastLunge = now
			lungeUntil = now + C.LungeTime
			effect:FireAllClients("Scream", root.Position)
		end
		local speed = chaseSpeed()
		if now < lungeUntil then
			speed *= C.LungeSpeedMultiplier
		elseif math.sin(now * 1.7) > 0.85 then
			speed *= 0.6 -- 가끔 멈칫하며 고개를 꺾음 (단조롭지 않게)
		end
		humanoid.WalkSpeed = speed
		-- 정면으로만 오지 않고 살짝 옆으로 돌아 들어옴
		local side = Vector3.new(math.sin(now * 0.6), 0, math.cos(now * 0.6)) * math.min(dist * 0.15, 6)
		moveTo(lastSeenPos + (if dist > 15 then side else Vector3.zero))
	elseif state == "Investigate" and investigatePos then
		humanoid.WalkSpeed = chaseSpeed() * 0.85
		moveTo(investigatePos)
		if (investigatePos - root.Position).Magnitude < 12 or now - investigateStart > 18 then
			wanderGoal = nil
			setState("Wander")
		end
	else
		-- 오래 아무도 못 찾았으면 기습
		if now - lastTargetTime > C.AmbushAfter then
			lastTargetTime = now
			if ambush() then
				return
			end
		end
		humanoid.WalkSpeed = C.WanderSpeed + rage * 0.5
		local reached = wanderGoal ~= nil and (wanderGoal - root.Position).Magnitude < 10
		if wanderGoal == nil or reached or now - wanderStarted > 20 then
			wanderGoal = pickWanderGoal()
			wanderStarted = now
		end
		moveTo(wanderGoal :: Vector3)
	end
	tryAttack()
end

-- ReplicatedStorage.Assets.Monster 가 있으면 그 모델을 사용
local function buildFromAsset(position: Vector3): Model?
	local m = Assets.clone("Monster", "Monster", 15)
	if not m then
		return nil
	end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart") and hum) then
		warn("[MonsterAI] Assets.Monster 에 HumanoidRootPart 와 Humanoid 가 필요해요. 기본 괴물을 사용합니다.")
		m:Destroy()
		return nil
	end
	m.Name = "Monster"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = d == hrp
			d.Massless = d ~= hrp
			if d.Name:lower():find("eye") then
				table.insert(eyes, d)
			end
		end
	end
	hrp.Transparency = 1
	m.PrimaryPart = hrp
	-- 다리 길이(HipHeight) 자동 계산
	local cf, size = m:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	hum.HipHeight = math.max(0.1, (hrp.Position.Y - hrp.Size.Y / 2) - bottom)
	hum.RequiresNeck = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.WalkSpeed = C.WanderSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	m:SetAttribute("State", "Wander")
	m:SetAttribute("IsAsset", true)
	m:PivotTo(CFrame.new(position + Vector3.new(0, size.Y / 2 + 2, 0)))
	m.Parent = Workspace
	hrp:SetNetworkOwner(nil)
	return m
end

local function spawnMonster()
	eyes = {}
	model = buildFromAsset(map.MonsterSpawn) or buildModel(map.MonsterSpawn)
	humanoid = (model :: Model):FindFirstChildOfClass("Humanoid")
	root = (model :: Model).PrimaryPart
	hp = C.MaxHealth
	state = "Wander"
	stunnedUntil = 0
	target = nil
	wanderGoal = nil
	investigatePos = nil
	waypoints = {}
	traps = {}
	lastTargetTime = os.clock()
	lastStalk = os.clock() - C.StalkCooldown + 15
	stalkTarget = nil
	searchPos, searchTarget, searchArrived = nil, nil, nil
end

---------------------------------------------------------------------------
-- 외부에서 쓰는 함수들
---------------------------------------------------------------------------
function MonsterAI.init(mapInfo)
	map = mapInfo
end

function MonsterAI.start()
	MonsterAI.stop()
	running = true
	rage = 0
	local myGeneration = generation
	spawnMonster()
	task.spawn(function()
		while running and generation == myGeneration do
			local ok, err = pcall(update)
			if not ok then
				warn("[MonsterAI]", err)
			end
			task.wait(0.2)
		end
	end)
end

function MonsterAI.stop()
	running = false
	generation += 1
	if model then
		model:Destroy()
	end
	model, humanoid, root = nil, nil, nil
	state = "Wander"
	for _, trap in traps do
		trap:Destroy()
	end
	traps = {}
end

function MonsterAI.isMonsterPart(instance: Instance): boolean
	return model ~= nil and instance:IsDescendantOf(model)
end

function MonsterAI.isDowned(): boolean
	return state == "Downed"
end

function MonsterAI.getPosition(): Vector3?
	return root and root.Position
end

function MonsterAI.damage(amount: number, byPlayer: Player?)
	if not (humanoid and root) or state == "Downed" or state == "Sealed" then
		return
	end
	hp -= amount
	effect:FireAllClients("MonsterHit", root.Position)
	if hp <= 0 then
		setState("Downed")
		downedUntil = os.clock() + C.DownedTime
		humanoid.PlatformStand = true
		humanoid:MoveTo(root.Position)
		setEyes(Color3.fromRGB(60, 10, 10))
		notify:FireAllClients(("숲지기가 쓰러졌다! %d초 안에 봉인 말뚝을 박아라!"):format(C.DownedTime))
		return
	end
	-- 공격당하면 쏜 사람을 쫓아감
	if byPlayer and state ~= "Stunned" then
		local _, hrp = aliveCharacter(byPlayer)
		if hrp then
			target = byPlayer
			lastSeenPos = hrp.Position
			lastSeenTime = os.clock()
			setState("Chase")
		end
	end
end

function MonsterAI.stun(seconds: number)
	if not humanoid or state == "Downed" or state == "Sealed" then
		return
	end
	setState("Stunned")
	stunnedUntil = math.max(stunnedUntil, os.clock() + seconds)
	setEyes(Color3.fromRGB(80, 80, 255))
end

-- 소리가 나면 조사하러 옴 (추격 중이면 무시)
function MonsterAI.noise(position: Vector3, range: number)
	if not root or state == "Chase" or state == "Stunned" or state == "Downed" or state == "Sealed" or state == "Search" then
		return
	end
	if (position - root.Position).Magnitude <= range then
		investigatePos = position
		investigateStart = os.clock()
		setState("Investigate")
	end
end

-- 탈출 진행도가 오를수록 빨라짐
function MonsterAI.setRage(level: number)
	rage = level
end

-- 플레이어가 옷장에 숨었을 때 Hiding이 부름. 쫓던 중이었다면 옷장을 뒤지러 옴
function MonsterAI.notifyHide(player: Player, closetFront: Vector3)
	if not root or state ~= "Chase" or target ~= player then
		return
	end
	if (closetFront - root.Position).Magnitude > 45 then
		return
	end
	searchPos = closetFront
	searchTarget = player
	searchArrived = nil
	investigateStart = os.clock()
	setState("Search")
end

function MonsterAI.addTrap(trap: BasePart)
	table.insert(traps, trap)
end

-- 쓰러진 상태에서만 성공
function MonsterAI.seal(): boolean
	if state ~= "Downed" or not model then
		return false
	end
	setState("Sealed")
	running = false
	generation += 1
	local m = model
	model, humanoid, root = nil, nil, nil
	effect:FireAllClients("Sealed", m:GetPivot().Position)
	task.delay(2.5, function()
		m:Destroy()
	end)
	if MonsterAI.onSealed then
		task.spawn(MonsterAI.onSealed)
	end
	return true
end

function MonsterAI.distanceTo(position: Vector3): number
	if root and state ~= "Sealed" then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

return MonsterAI
