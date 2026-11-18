-- 게임패스 능력 (상점에서 산 사람만 숲에서 쓸 수 있음)
--
--   [T] 숲지기 추적기: Config.Shop.TrackerTime 초 동안 괴물 위치를 알려 줌. 쓰고 나면 한동안 못 씀.
--       켜져 있는 동안 삑삑 소리가 나서 가까이 있는 괴물이 소리 난 곳을 살피러 옵니다.
--   [G] 숲지기 변신: 한 판에 한 번, Config.Shop.DisguiseTime 초 동안 숲지기 모습이 됨.
--       ReplicatedStorage.Assets.Monster (직접 만든 숲지기 모델)가 있으면 그 모델 그대로 변신하고,
--       걷기/달리기 애니메이션(Config.MonsterModel.Animations)도 똑같이 재생합니다.
--       모델이 없을 때만 예전의 블록 분장(뿔, 해골)으로 대신해요.
--       변신 중에는 화면이 3인칭으로 바뀝니다 (client/Abilities.luau).
--       그동안 괴물은 나를 동족으로 착각해서 쫓지 않아요 (MonsterAI 가 Disguised 속성을 봄).
--       대신 변신 중에는 도구(총, 도끼…)를 쓸 수 없습니다 (Combat).
--
-- 클라이언트(client/Abilities.luau)가 읽는 플레이어 속성:
--   TrackerEnds / TrackerReady (서버 시각), TrackerPos (괴물 위치),
--   Disguised, DisguiseEnds (서버 시각), DisguiseUsed (이번 판에 쓴 횟수)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Monetization = require(script.Parent.Monetization)
local MonsterAI = require(script.Parent.MonsterAI)
local Sfx = require(script.Parent.Sfx)

local S = Config.Shop
local notify = Remotes.get("Notify")

local Abilities = {}

local trackerTokens: { [Player]: number } = {}
local disguiseTokens: { [Player]: number } = {}
-- 변신하면서 바꿔 둔 것들 (끝나면 되돌림)
type Saved = { inst: Instance, prop: string, value: any }
local savedLooks: { [Player]: { Saved } } = {}
-- 변신한 사람 몸에 붙여 둔 숲지기 모델 (Workspace.Disguises 안)
local meshModels: { [Player]: Model } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function aliveInRound(player: Player): (Model?, Humanoid?, BasePart?)
	if ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" then
		return nil, nil, nil
	end
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Escaped") == true or player:GetAttribute("Downed") == true then
		return nil, nil, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if char and hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
		return char, hum, hrp
	end
	return nil, nil, nil
end

---------------------------------------------------------------------------
-- 추적기
---------------------------------------------------------------------------
local function useTracker(player: Player)
	if not Monetization.owns(player, "Tracker") then
		return
	end
	local _, _, hrp = aliveInRound(player)
	if not hrp then
		return
	end
	if now() < (player:GetAttribute("TrackerReady") or 0) then
		return
	end
	local token = (trackerTokens[player] or 0) + 1
	trackerTokens[player] = token
	player:SetAttribute("TrackerReady", now() + S.TrackerCooldown)
	player:SetAttribute("TrackerEnds", now() + S.TrackerTime)

	task.spawn(function()
		local elapsed = 0
		local nextBeep = 0
		while elapsed < S.TrackerTime and trackerTokens[player] == token do
			local _, _, root = aliveInRound(player)
			if not root then
				break
			end
			player:SetAttribute("TrackerPos", MonsterAI.getPosition())
			if elapsed >= nextBeep then
				nextBeep += 1
				Sfx.all("TrackerBeep", root.Position)
				MonsterAI.noise(root.Position, S.TrackerNoise)
			end
			elapsed += task.wait(0.2)
		end
		if trackerTokens[player] == token and player.Parent == Players then
			player:SetAttribute("TrackerEnds", 0)
			player:SetAttribute("TrackerPos", nil)
		end
	end)
end

---------------------------------------------------------------------------
-- 변신
---------------------------------------------------------------------------
local HIDE = Color3.fromRGB(24, 21, 19)
local BONE = Color3.fromRGB(196, 186, 160)
local EYE = Color3.fromRGB(200, 255, 215)

local function piece(folder: Instance, base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = base.CFrame * offset
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function findPart(char: Model, ...: string): BasePart?
	for _, name in { ... } do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- 사슴 해골 머리 + 뿔 + 털가죽 + 긴 발톱을 캐릭터 몸에 붙임 (팔다리에 붙어서 같이 움직임)
local function buildCostume(char: Model): Model
	local costume = Instance.new("Model")
	costume.Name = "Disguise"

	local head = findPart(char, "Head")
	if head then
		piece(costume, head, "Skull", Vector3.new(1.5, 1.4, 1.6), CFrame.new(0, 0.1, -0.1), BONE, Enum.Material.Slate)
		piece(costume, head, "Snout", Vector3.new(0.8, 0.7, 1.3), CFrame.new(0, -0.3, -1.2) * CFrame.Angles(math.rad(-12), 0, 0), BONE, Enum.Material.Slate)
		for side = -1, 1, 2 do
			local eye = piece(costume, head, "Eye", Vector3.new(0.22, 0.22, 0.1), CFrame.new(side * 0.4, 0.25, -0.92), EYE, Enum.Material.Neon)
			local glow = Instance.new("PointLight")
			glow.Color = EYE
			glow.Range = 5
			glow.Brightness = 0.6
			glow.Parent = eye
			-- 뿔: 굵은 줄기 하나에 가지 셋
			local beam = CFrame.new(side * 0.55, 0.8, 0.1) * CFrame.Angles(math.rad(-12), 0, math.rad(-side * 28))
			piece(costume, head, "Antler", Vector3.new(0.22, 2.6, 0.22), beam * CFrame.new(0, 1.3, 0), BONE, Enum.Material.Slate)
			for i = 1, 3 do
				local tine = beam * CFrame.new(0, 0.55 + i * 0.6, 0) * CFrame.Angles(math.rad(-35), 0, math.rad(-side * 45))
				piece(costume, head, "Antler", Vector3.new(0.14, 1.1 - i * 0.15, 0.14), tine * CFrame.new(0, 0.5, 0), BONE, Enum.Material.Slate)
			end
		end
	end

	local torso = findPart(char, "UpperTorso", "Torso")
	if torso then
		piece(costume, torso, "Hump", Vector3.new(2.5, 1.6, 1.3), CFrame.new(0, 0.5, 0.55) * CFrame.Angles(math.rad(18), 0, 0), HIDE, Enum.Material.Fabric)
		for i = 0, 2 do
			piece(costume, torso, "Rib", Vector3.new(1.9 - i * 0.2, 0.14, 0.14), CFrame.new(0, 0.45 - i * 0.38, -0.56), BONE, Enum.Material.Slate)
		end
	end

	for _, names in { { "LeftHand", "Left Arm" }, { "RightHand", "Right Arm" } } do
		local hand = findPart(char, names[1], names[2])
		if hand then
			local bottom = -hand.Size.Y / 2
			for k = -1, 1 do
				piece(costume, hand, "Claw", Vector3.new(0.13, 1.3, 0.13), CFrame.new(k * 0.28, bottom - 0.55, -0.1) * CFrame.Angles(math.rad(12), 0, math.rad(k * 8)), BONE, Enum.Material.Slate)
			end
		end
	end
	return costume
end

local function restoreLook(player: Player)
	local saved = savedLooks[player]
	savedLooks[player] = nil
	if saved then
		for _, entry in saved do
			pcall(function()
				(entry.inst :: any)[entry.prop] = entry.value
			end)
		end
	end
	local char = player.Character
	local costume = char and char:FindFirstChild("Disguise")
	if costume then
		costume:Destroy()
	end
	local mesh = meshModels[player]
	meshModels[player] = nil
	if mesh then
		mesh:Destroy()
	end
end

---------------------------------------------------------------------------
-- 진짜 숲지기 모델로 변신
---------------------------------------------------------------------------
local function worldBounds(m: Model): (Vector3, Vector3)
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, half = d.CFrame, d.Size / 2
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local extent = Vector3.new(
				math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
				math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
				math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
			)
			low = low:Min(cf.Position - extent)
			high = high:Max(cf.Position + extent)
		end
	end
	return low, high
end

local function disguiseFolder(): Instance
	local folder = Workspace:FindFirstChild("Disguises")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Disguises"
		folder.Parent = Workspace
	end
	return folder
end

-- 숲지기 모델을 복제해 캐릭터 몸통(HumanoidRootPart)에 붙임. 모델이 없으면 nil
local function buildMesh(player: Player, hum: Humanoid, hrp: BasePart): Model?
	local m = Assets.clone("Monster", "Monster")
	if not m then
		return nil
	end
	local parts: { BasePart } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Humanoid") then
			d:Destroy() -- 캐릭터가 둘이 되지 않게. 애니메이션은 AnimationController 로 재생
		end
	end
	if #parts == 0 then
		m:Destroy()
		return nil
	end

	-- 키 맞추기
	local low, high = worldBounds(m)
	local height = high.Y - low.Y
	if height > 0.01 then
		m:ScaleTo(m:GetScale() * (S.DisguiseHeight / height))
		low, high = worldBounds(m)
	end

	-- 모델의 발바닥 가운데가 캐릭터 발밑에 오도록 붙임
	local feet = CFrame.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	local legLength = if hum.RigType == Enum.HumanoidRigType.R15 then hrp.Size.Y / 2 + hum.HipHeight else 3
	local base = CFrame.new(0, -legLength, 0) * CFrame.Angles(0, math.rad(Config.MonsterModel.FaceYaw), 0)
	local jointed: { [BasePart]: boolean } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") and d.Part1 then
			jointed[d.Part1] = true
		end
	end
	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if not jointed[part] then
			local weld = Instance.new("Weld")
			weld.Name = "DisguiseWeld"
			weld.Part0 = hrp
			weld.Part1 = part
			weld.C0 = base * feet:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
	end

	local controller = m:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = m
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	m.Name = tostring(player.UserId)
	m.Parent = disguiseFolder()
	return m
end

-- 움직이는 빠르기에 맞춰 서 있기 / 걷기 / 달리기 애니메이션을 바꿔 틂 (서버에서 틀면 모두에게 보임)
local function animateMesh(player: Player, m: Model, hrp: BasePart, token: number)
	local controller = m:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks: { [string]: AnimationTrack } = {}
	for _, name in { "Idle", "Walk", "Run" } do
		local id = Config.MonsterModel.Animations[name]
		if typeof(id) == "number" and id ~= 0 then
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Movement
				tracks[name] = track
			end
		end
	end
	local current: string? = nil
	while disguiseTokens[player] == token and m.Parent and hrp.Parent do
		local v = hrp.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local want = if speed > (Config.Player.WalkSpeed + Config.Player.SprintSpeed) / 2 then "Run" elseif speed > 1 then "Walk" else "Idle"
		if not tracks[want] then
			want = if tracks.Walk and want == "Run" then "Walk" else "Idle"
		end
		if want ~= current then
			if current and tracks[current] then
				tracks[current]:Stop(0.25)
			end
			current = want
			if tracks[want] then
				tracks[want]:Play(0.25)
			end
		end
		task.wait(0.15)
	end
end

local function applyLook(player: Player, char: Model, hum: Humanoid, hrp: BasePart, token: number)
	local saved: { Saved } = {}
	savedLooks[player] = saved
	local function set(inst: Instance, prop: string, value: any)
		table.insert(saved, { inst = inst, prop = prop, value = (inst :: any)[prop] });
		(inst :: any)[prop] = value
	end

	local mesh = buildMesh(player, hum, hrp)
	if mesh then
		-- 진짜 숲지기 모델: 내 캐릭터는 통째로 안 보이게 하고 이름표도 숨김
		meshModels[player] = mesh
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				set(d, "Transparency", 1)
			elseif d:IsA("Decal") then
				set(d, "Transparency", 1)
			end
		end
		set(hum, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
		task.spawn(animateMesh, player, mesh, hrp, token)
		return
	end

	-- 모델이 없을 때: 블록 분장
	for _, d in char:GetDescendants() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			set(d, "Parent", nil) -- 옷을 잠깐 벗김 (끝나면 다시 입힘)
		elseif d:IsA("Decal") and d.Name == "face" then
			set(d, "Transparency", 1)
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestorOfClass("Tool") then
			if d:FindFirstAncestorOfClass("Accessory") then
				set(d, "Transparency", 1) -- 모자, 머리카락 숨김
			else
				set(d, "Color", HIDE)
				if d:IsA("MeshPart") then
					set(d, "TextureID", "")
				end
			end
		end
	end
	buildCostume(char).Parent = char
end

local function endDisguise(player: Player)
	disguiseTokens[player] = (disguiseTokens[player] or 0) + 1
	restoreLook(player)
	if player.Parent == Players and player:GetAttribute("Disguised") == true then
		player:SetAttribute("Disguised", false)
		player:SetAttribute("DisguiseEnds", 0)
	end
end

local function useDisguise(player: Player)
	if not Monetization.owns(player, "Disguise") then
		return
	end
	local char, hum, hrp = aliveInRound(player)
	if not (char and hum and hrp) then
		return
	end
	if player:GetAttribute("Disguised") == true or player:GetAttribute("Hiding") == true then
		return
	end
	local used = player:GetAttribute("DisguiseUsed") or 0
	if used >= S.DisguisePerRound then
		notify:FireClient(player, "이번 판에는 이미 변신했다")
		return
	end
	local token = (disguiseTokens[player] or 0) + 1
	disguiseTokens[player] = token
	player:SetAttribute("DisguiseUsed", used + 1)
	player:SetAttribute("DisguiseEnds", now() + S.DisguiseTime)
	player:SetAttribute("Disguised", true)
	hum:UnequipTools()
	applyLook(player, char, hum, hrp, token)
	Sfx.all("MonsterGrowl", hrp.Position)

	hum.Died:Once(function()
		if disguiseTokens[player] == token then
			endDisguise(player)
		end
	end)
	task.delay(S.DisguiseTime, function()
		if disguiseTokens[player] == token then
			endDisguise(player)
			if player.Parent == Players then
				notify:FireClient(player, "변신이 풀렸다 — 이제 괴물이 다시 알아본다")
			end
		end
	end)
end

function Abilities.init()
	Remotes.get("UseAbility").OnServerEvent:Connect(function(player: Player, which: any)
		if which == "Tracker" then
			useTracker(player)
		elseif which == "Disguise" then
			useDisguise(player)
		end
	end)

	local function onPlayer(player: Player)
		-- 새 판에 들어갈 때마다 처음 상태로
		player:GetAttributeChangedSignal("RoundSerial"):Connect(function()
			trackerTokens[player] = (trackerTokens[player] or 0) + 1
			endDisguise(player)
			player:SetAttribute("TrackerReady", 0)
			player:SetAttribute("TrackerEnds", 0)
			player:SetAttribute("TrackerPos", nil)
			player:SetAttribute("DisguiseUsed", 0)
		end)
		-- 판에서 빠지면(죽음, 탈출, 대기실) 변신 해제
		for _, name in { "InRound", "Escaped", "Downed" } do
			player:GetAttributeChangedSignal(name):Connect(function()
				if player:GetAttribute("Disguised") == true and not aliveInRound(player) then
					endDisguise(player)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		trackerTokens[player] = nil
		disguiseTokens[player] = nil
		savedLooks[player] = nil
		local mesh = meshModels[player]
		meshModels[player] = nil
		if mesh then
			mesh:Destroy()
		end
	end)
end

return Abilities
