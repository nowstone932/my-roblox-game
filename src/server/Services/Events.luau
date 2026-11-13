-- 랜덤 공포 이벤트
-- 라운드 중 일정 간격으로 한 명(또는 모두)에게 무서운 일이 일어납니다.
--   Whisper    : 환청 (그 사람에게만 속삭임)
--   Apparition : 멀리 창백한 벌목꾼 유령이 서 있다가 사라짐 (그 사람에게만 보임)
--   Blackout   : 숲 전체의 불빛이 몇 초간 꺼짐 (모두)
--   Snap       : 등 뒤에서 나뭇가지 부러지는 소리 + 화면 흔들림
-- 실제 연출은 클라이언트(Main.client.luau)에서 합니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Story = require(ReplicatedStorage.Shared.Story)

local effect = Remotes.get("Effect")

local Events = {}

local running = false
local generation = 0
local rng = Random.new()

local function activePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InRound") == true and player:GetAttribute("Escaped") ~= true and player:GetAttribute("Downed") ~= true then
			table.insert(list, player)
		end
	end
	return list
end

local function fireRandom()
	local players = activePlayers()
	if #players == 0 then
		return
	end
	local victim = players[rng:NextInteger(1, #players)]
	local roll = rng:NextNumber()
	if roll < 0.3 then
		effect:FireClient(victim, "Whisper", Story.Whispers[rng:NextInteger(1, #Story.Whispers)])
	elseif roll < 0.6 then
		effect:FireClient(victim, "Apparition")
	elseif roll < 0.8 then
		effect:FireClient(victim, "Snap")
	else
		effect:FireAllClients("Blackout", 6)
	end
end

function Events.start()
	Events.stop()
	running = true
	local myGeneration = generation
	task.spawn(function()
		task.wait(40) -- 시작하자마자는 조용히
		while running and generation == myGeneration do
			fireRandom()
			task.wait(rng:NextNumber(Config.Events.Interval[1], Config.Events.Interval[2]))
		end
	end)
end

function Events.stop()
	running = false
	generation += 1
end

return Events
