-- 괴물 AI
-- 상태: Wander(배회) -> Chase(추격) -> Stunned(기절) -> Dead(쓰러짐, 잠시 후 부활)
-- 눈으로 보거나(시야 + 가림 없음) 가까이서 소리를 들으면(HearRange) 쫓아옵니다.
-- 나무 뒤에 숨으면 시야가 막혀서 따돌릴 수 있어요.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local notify = Remotes.get("Notify")
local effect = Remotes.get("Effect")
local C = Config.Monster

local MonsterAI = {}

local map = nil
local running = false
local generation = 0

local model: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local eyes: { BasePart } = {}

local state = "Wander"
local stunnedUntil = 0
local target: Player? = nil
local lastSeenPos: Vector3? = nil
local lastSeenTime = 0
local lastAttack = 0

local wanderGoal: Vector3? = nil
local wanderStarted = 0

local waypoints: { PathWaypoint } = {}
local waypointIndex = 1
local lastPathTime = 0
local lastPathGoal: Vector3? = nil

local rng = Random.new()

-- 파트만으로 괴물 모양을 만듭니다. (나중에 Studio에서 만든 모델로 바꿔도 됨)
local function buildModel(position: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Monster"

	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = collide
		p.Massless = not collide
		p.CFrame = CFrame.new(position) * offset
		p.Parent = m
		return p
	end

	local black = Color3.fromRGB(15, 12, 12)
	local hrp = part("HumanoidRootPart", Vector3.new(3, 5, 2), CFrame.new(), black, false)
	hrp.Transparency = 1
	local torso = part("Torso", Vector3.new(3, 5, 2), CFrame.new(), black, true)
	local head = part("Head", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 3.6, 0), black, false)
	local legL = part("LeftLeg", Vector3.new(1, 3.5, 1), CFrame.new(-0.9, -4.25, 0), black, false)
	local legR = part("RightLeg", Vector3.new(1, 3.5, 1), CFrame.new(0.9, -4.25, 0), black, false)
	local armL = part("LeftArm", Vector3.new(0.8, 6, 0.8), CFrame.new(-2, -1, 0), black, false)
	local armR = part("RightArm", Vector3.new(0.8, 6, 0.8), CFrame.new(2, -1, 0), black, false)

	local eyeColor = Color3.fromRGB(255, 30, 30)
	local eyeL = part("EyeL", Vector3.new(0.4, 0.3, 0.2), CFrame.new(-0.5, 3.8, -1.1), eyeColor, false)
	local eyeR = part("EyeR", Vector3.new(0.4, 0.3, 0.2), CFrame.new(0.5, 3.8, -1.1), eyeColor, false)
	eyeL.Material = Enum.Material.Neon
	eyeR.Material = Enum.Material.Neon
	eyes = { eyeL, eyeR }

	local glow = Instance.new("PointLight")
	glow.Color = eyeColor
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = head

	for _, p in { torso, head, legL, legR, armL, armR, eyeL, eyeR } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = p
		weld.Parent = hrp
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.RequiresNeck = false
	hum.HipHeight = 3.5 -- 다리 길이만큼 띄움 (몸통 아래쪽이 지면에서 3.5 위)
	hum.MaxHealth = C.MaxHealth
	hum.Health = C.MaxHealth
	hum.WalkSpeed = C.WanderSpeed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.Parent = m

	m.PrimaryPart = hrp
	m:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	m.Parent = Workspace
	hrp:SetNetworkOwner(nil) -- 서버가 직접 움직이도록
	return m
end

local function aliveCharacter(player: Player): (Model?, BasePart?)
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true then
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
	local origin = root.Position + Vector3.new(0, 3.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(origin, hrp.Position - origin, params)
	return result == nil or result.Instance:IsDescendantOf(char)
end

-- 가장 가까운, 보이거나 들리는 플레이어
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

local function moveTo(goal: Vector3)
	if not (humanoid and root) then
		return
	end
	local now = os.clock()
	local direct = (goal - root.Position).Magnitude < 20
	if direct then
		waypoints = {}
		humanoid:MoveTo(goal)
		return
	end

	local interval = if state == "Chase" then 0.8 else 3
	local goalMoved = lastPathGoal == nil or (goal - lastPathGoal).Magnitude > 8
	if now - lastPathTime > interval and (goalMoved or #waypoints == 0 or now - lastPathTime > 3) then
		lastPathTime = now
		lastPathGoal = goal
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 12,
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
			return -- 경로 계산 중에 괴물이 사라졌을 수 있음
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

local function tryAttack()
	if not root or os.clock() - lastAttack < C.AttackCooldown then
		return
	end
	for _, player in Players:GetPlayers() do
		local char, hrp = aliveCharacter(player)
		if char and hrp then
			local flat = Vector3.new(hrp.Position.X - root.Position.X, 0, hrp.Position.Z - root.Position.Z)
			if flat.Magnitude <= C.AttackRange then
				lastAttack = os.clock()
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:TakeDamage(C.AttackDamage)
					effect:FireClient(player, "Hurt")
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

local function update()
	if not (model and humanoid and root) or state == "Dead" then
		return
	end
	local now = os.clock()

	if now < stunnedUntil then
		humanoid.WalkSpeed = 0
		humanoid:MoveTo(root.Position)
		return
	elseif state == "Stunned" then
		state = "Wander"
		setEyes(Color3.fromRGB(255, 30, 30))
	end

	local player, hrp = findTarget()
	if player and hrp then
		target = player
		lastSeenPos = hrp.Position
		lastSeenTime = now
		state = "Chase"
	elseif state == "Chase" and now - lastSeenTime > C.LoseSightTime then
		state = "Wander"
		target = nil
		wanderGoal = nil
	end

	if state == "Chase" and lastSeenPos then
		humanoid.WalkSpeed = C.ChaseSpeed
		moveTo(lastSeenPos)
		tryAttack()
	else
		humanoid.WalkSpeed = C.WanderSpeed
		local reached = wanderGoal ~= nil and (wanderGoal - root.Position).Magnitude < 10
		if wanderGoal == nil or reached or now - wanderStarted > 20 then
			local half = map.HalfSize - 30
			wanderGoal = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
			wanderStarted = now
		end
		moveTo(wanderGoal :: Vector3)
		tryAttack()
	end
end

local function spawnMonster()
	local myGeneration = generation
	model = buildModel(map.MonsterSpawn)
	humanoid = (model :: Model):FindFirstChildOfClass("Humanoid")
	root = (model :: Model).PrimaryPart
	state = "Wander"
	stunnedUntil = 0
	target = nil
	wanderGoal = nil
	waypoints = {}

	local deadModel = model
	;(humanoid :: Humanoid).Died:Connect(function()
		if generation ~= myGeneration then
			return
		end
		state = "Dead"
		model, humanoid, root = nil, nil, nil
		notify:FireAllClients(("괴물이 쓰러졌다! %d초 뒤에 다시 깨어난다..."):format(C.RespawnTime))
		task.delay(3, function()
			if deadModel then
				deadModel:Destroy()
			end
		end)
		task.delay(C.RespawnTime, function()
			if running and generation == myGeneration then
				spawnMonster()
				notify:FireAllClients("괴물이 다시 깨어났다!")
			end
		end)
	end)
end

function MonsterAI.init(mapInfo)
	map = mapInfo
end

function MonsterAI.start()
	MonsterAI.stop()
	running = true
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
end

-- 맞은 부분이 괴물인지
function MonsterAI.isMonsterPart(instance: Instance): boolean
	return model ~= nil and instance:IsDescendantOf(model)
end

function MonsterAI.damage(amount: number, byPlayer: Player?)
	if not humanoid or state == "Dead" then
		return
	end
	humanoid:TakeDamage(amount)
	-- 공격당하면 쏜 사람을 쫓아감
	if byPlayer and state ~= "Stunned" then
		local _, hrp = aliveCharacter(byPlayer)
		if hrp then
			target = byPlayer
			lastSeenPos = hrp.Position
			lastSeenTime = os.clock()
			state = "Chase"
		end
	end
end

function MonsterAI.stun(seconds: number)
	if not humanoid or state == "Dead" then
		return
	end
	state = "Stunned"
	stunnedUntil = os.clock() + seconds
	setEyes(Color3.fromRGB(80, 80, 255))
end

function MonsterAI.distanceTo(position: Vector3): number
	if root and state ~= "Dead" then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

return MonsterAI
