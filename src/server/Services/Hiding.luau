-- 옷장에 숨기
-- 숨어 있는 동안 괴물은 그 플레이어를 보지 못합니다.
-- 단, 괴물이 바로 근처(BlockedRange)에 있으면 숨을 수 없고, 오래 있으면 숨이 차서 나옵니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonsterAI = require(script.Parent.MonsterAI)
local Sfx = require(script.Parent.Sfx)

local notify = Remotes.get("Notify")
local H = Config.Hiding

local Hiding = {}

type ClosetState = { model: Model, hidePoint: CFrame, prompt: ProximityPrompt, occupant: Player?, token: number }
local closets: { ClosetState } = {}
local playerCloset: { [Player]: ClosetState } = {}

local function exitPoint(closet: ClosetState): CFrame
	local front = (closet.model.PrimaryPart :: BasePart).CFrame
	return front * CFrame.new(0, -0.5, -2.5)
end

function Hiding.release(player: Player, message: string?)
	local closet = playerCloset[player]
	if not closet then
		return
	end
	playerCloset[player] = nil
	closet.occupant = nil
	closet.token += 1
	closet.prompt.ActionText = "숨기"
	player:SetAttribute("Hiding", false)
	player:SetAttribute("HideEnds", nil)
	Sfx.all("ClosetDoor", exitPoint(closet).Position)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if char and hrp and hrp:IsA("BasePart") then
		hrp.Anchored = false
		char:PivotTo(exitPoint(closet))
	end
	if message then
		notify:FireClient(player, message)
	end
end

local function hide(player: Player, closet: ClosetState)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hum.Health > 0 and hrp and hrp:IsA("BasePart")) then
		return
	end
	if player:GetAttribute("InRound") ~= true or player:GetAttribute("Downed") == true then
		return
	end
	if MonsterAI.distanceTo(hrp.Position) < H.BlockedRange then
		notify:FireClient(player, "괴물이 너무 가까워서 숨을 수 없다!")
		return
	end
	hum:UnequipTools()
	closet.occupant = player
	closet.token += 1
	closet.prompt.ActionText = "나오기"
	playerCloset[player] = closet
	Sfx.all("ClosetDoor", exitPoint(closet).Position)
	char:PivotTo(closet.hidePoint)
	hrp.Anchored = true
	player:SetAttribute("Hiding", true)
	player:SetAttribute("HideEnds", os.time() + H.MaxTime)

	-- 쫓기던 중이었다면 괴물이 옷장을 뒤지러 옴
	MonsterAI.notifyHide(player, exitPoint(closet).Position)

	local myToken = closet.token
	task.delay(H.MaxTime, function()
		if closet.token == myToken and closet.occupant == player then
			Hiding.release(player, "숨이 차서 뛰쳐나왔다!")
		end
	end)
end

function Hiding.init(mapInfo)
	-- 괴물이 옷장 문을 뜯어냈을 때
	MonsterAI.onClosetRipped = function(player: Player)
		Hiding.release(player, "숲지기가 옷장 문을 뜯어냈다!")
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			Remotes.get("Effect"):FireClient(player, "Hurt", nil)
			if hum.Health - Config.Monster.ClosetSearchDamage <= 0 and MonsterAI.onPlayerDowned then
				MonsterAI.onPlayerDowned(player)
			else
				hum:TakeDamage(Config.Monster.ClosetSearchDamage)
			end
		end
	end

	for _, entry in mapInfo.Closets do
		local promptPart = entry.model.PrimaryPart
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "숨기"
		prompt.ObjectText = "옷장"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart
		local closet: ClosetState = { model = entry.model, hidePoint = entry.hidePoint, prompt = prompt, occupant = nil, token = 0 }
		table.insert(closets, closet)

		prompt.Triggered:Connect(function(player)
			if closet.occupant == player then
				Hiding.release(player)
			elseif closet.occupant ~= nil then
				notify:FireClient(player, "누군가 이미 숨어 있다")
			elseif not playerCloset[player] then
				hide(player, closet)
			end
		end)
	end

	local function cleanup(player: Player)
		local closet = playerCloset[player]
		if closet then
			playerCloset[player] = nil
			closet.occupant = nil
			closet.token += 1
			closet.prompt.ActionText = "숨기"
		end
		player:SetAttribute("Hiding", false)
	end
	Players.PlayerRemoving:Connect(cleanup)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			cleanup(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

function Hiding.releaseAll()
	for player in playerCloset do
		Hiding.release(player)
	end
end

return Hiding
