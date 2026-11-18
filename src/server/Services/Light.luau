-- 손전등의 서버 쪽 처리
--
-- 손전등 빛 자체는 각자 화면(client/Flashlight.luau)에서 만들지만, 서버는 두 가지를 맡아요.
--   1) 누가 손전등을 켜고 있는지 기록 (플레이어 속성 LightOn)
--      → 괴물은 불을 켠 사람을 훨씬 멀리서 알아봅니다 (MonsterAI).
--      → 다른 사람 눈에도 내 손전등 빛이 보입니다 (머리에 달린 TeamLight).
--   2) 건전지 교체: 가방의 건전지(Cell) 1개를 쓰고 CellCharge 숫자를 올려줌
--      → 클라이언트가 그걸 보고 배터리를 가득 채웁니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Sfx = require(script.Parent.Sfx)

local Light = {}

local function teamLight(player: Player): SpotLight?
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local light = head:FindFirstChild("TeamLight")
	if not (light and light:IsA("SpotLight")) then
		light = Instance.new("SpotLight")
		light.Name = "TeamLight"
		light.Face = Enum.NormalId.Front
		light.Color = Color3.fromRGB(255, 240, 210)
		light.Range = math.min(Config.Flashlight.Range, 50)
		light.Angle = Config.Flashlight.Angle
		light.Brightness = Config.Flashlight.TeamBrightness
		light.Shadows = true
		light.Parent = head
	end
	return light :: SpotLight
end

-- 상점의 "손전등 불빛 색" 게임패스를 가진 사람이 고른 색
local function lightColor(player: Player): Color3
	if player:GetAttribute("Pass_LightColor") == true then
		local id = player:GetAttribute("LightColor")
		for _, info in Config.Shop.LightColors do
			if info.id == id then
				return info.color
			end
		end
	end
	return Color3.fromRGB(255, 240, 210)
end

local function apply(player: Player)
	local light = teamLight(player)
	if light then
		light.Color = lightColor(player)
		light.Enabled = player:GetAttribute("LightOn") ~= false and player:GetAttribute("InRound") == true
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		player:SetAttribute("LightOn", true)
		character:WaitForChild("Head", 5)
		apply(player)
	end)
	for _, name in { "InRound", "LightColor", "Pass_LightColor" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			apply(player)
		end)
	end
	if player.Character then
		apply(player)
	end
end

function Light.init()
	Remotes.get("SetLight").OnServerEvent:Connect(function(player: Player, on: any)
		if typeof(on) == "boolean" then
			player:SetAttribute("LightOn", on)
			apply(player)
		end
	end)

	Remotes.get("UseCell").OnServerEvent:Connect(function(player: Player)
		if player:GetAttribute("InRound") ~= true then
			return
		end
		if Inventory.take(player, { Cell = 1 }) then
			player:SetAttribute("CellCharge", (player:GetAttribute("CellCharge") or 0) + 1)
			Sfx.to(player, "BatteryLoad")
		end
	end)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return Light
