-- 소리와 배경음악을 실제로 트는 곳 (플레이어 컴퓨터에서 실행)
-- 어떤 소리를 쓸지는 src/shared/SoundList.luau 에서 정합니다. 이 파일은 고칠 필요 없어요.
--
--   Audio.play("Pickup")                  -- 그냥 들리는 소리 (2D)
--   Audio.play("MonsterGrowl", position)  -- 그 위치에서 나는 소리 (3D)
--   Audio.play("MonsterGrowl", part)      -- 그 파트에 붙어서 따라다니는 소리 (3D)
--   Audio.update(dt, mood)                -- 매 프레임: 상황에 맞게 BGM 크기 조절

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundList = require(ReplicatedStorage.Shared.SoundList)

local Audio = {}

local folder: Folder
local templates: { [string]: Sound } = {}
local failed: { [string]: boolean } = {}

local function makeGroup(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = volume
	return g :: SoundGroup
end

function Audio.init()
	folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService

	local musicGroup = makeGroup("Music", SoundList.MasterVolume.Music)
	local effectsGroup = makeGroup("Effects", SoundList.MasterVolume.Effects)

	local namesById: { [string]: { string } } = {}
	local toLoad = {}
	for name, def in SoundList.Sounds do
		local soundId = SoundList.toSoundId(def.id)
		if soundId then
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = soundId
			s.Volume = def.volume or 1
			s.PlaybackSpeed = def.pitch or 1
			s.Looped = def.looped == true
			s.SoundGroup = if def.music then musicGroup else effectsGroup
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 8
			s.RollOffMaxDistance = def.range or 150
			s:SetAttribute("BaseVolume", s.Volume)
			s.Parent = folder
			templates[name] = s
			namesById[soundId] = namesById[soundId] or {}
			table.insert(namesById[soundId], name)
			table.insert(toLoad, s)
		end
	end

	-- 미리 불러오기. 못 불러온 소리는 조용히 빼고, 출력 창에 한 번만 알려줌
	task.spawn(function()
		local bad = {}
		local ok = pcall(function()
			ContentProvider:PreloadAsync(toLoad, function(contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
					for _, name in namesById[contentId] or {} do
						if not failed[name] then
							failed[name] = true
							table.insert(bad, name)
						end
					end
				end
			end)
		end)
		if ok and #bad > 0 then
			table.sort(bad)
			warn("[소리] 불러오지 못한 소리가 있어요 (그 소리만 꺼집니다). src/shared/SoundList.luau 에서 ID를 바꿔보세요: " .. table.concat(bad, ", "))
		end
	end)
end

function Audio.has(name: string): boolean
	return templates[name] ~= nil and not failed[name]
end

local function cleanupLater(s: Sound, holder: Instance?)
	local function done()
		if holder then
			holder:Destroy()
		else
			s:Destroy()
		end
	end
	s.Ended:Once(done)
	task.delay(60, function()
		if s.Parent then
			done()
		end
	end)
end

-- 한 번 재생. where: 없으면 2D, Vector3면 그 위치, BasePart면 그 파트에 붙음
-- volumeScale: 크기 배수 (기본 1)
function Audio.play(name: string, where: (Vector3 | BasePart)?, volumeScale: number?): Sound?
	local template = templates[name]
	if not template or failed[name] then
		return nil
	end
	local s = template:Clone()
	s.Looped = false
	s.Volume = template.Volume * (volumeScale or 1)
	local holder: Instance? = nil
	if typeof(where) == "Vector3" then
		local att = Instance.new("Attachment")
		att.Name = "SoundSpot"
		att.Parent = Workspace.Terrain
		att.WorldPosition = where
		s.Parent = att
		holder = att
	elseif typeof(where) == "Instance" and where:IsA("BasePart") then
		s.Parent = where
	else
		s.Parent = folder
	end
	s:Play()
	cleanupLater(s, holder)
	return s
end

-- 반복 소리 하나 만들기 (처음엔 볼륨 0). parent가 파트면 3D로 따라다님
function Audio.loop(name: string, parent: Instance?): Sound?
	local template = templates[name]
	if not template or failed[name] then
		return nil
	end
	local s = template:Clone()
	s.Looped = true
	s.Volume = 0
	s.Parent = parent or folder
	s:Play()
	return s
end

-- 반복 소리의 크기를 부드럽게 target(0~1, 원래 볼륨 기준 배수)으로
function Audio.fade(s: Sound?, target: number, dt: number, speed: number?)
	if not s then
		return
	end
	local base = s:GetAttribute("BaseVolume") or 1
	local goal = base * target
	s.Volume += (goal - s.Volume) * math.min(1, dt * (speed or 2))
	if s.Volume < 0.005 and goal == 0 then
		s.Volume = 0
	end
end

---------------------------------------------------------------------------
-- 배경음악 연출
---------------------------------------------------------------------------
local music: { [string]: Sound? } = {}
local chaseHold = 0
local muteUntil = 0

-- 엔딩 음악 같은 걸 틀 때 배경음악을 잠깐 줄임
function Audio.duckMusic(seconds: number)
	muteUntil = os.clock() + seconds
end

export type Mood = {
	playing: boolean, -- 라운드 진행 중인지
	danger: number, -- 0~1, 괴물이 가까울수록 1
	chasing: boolean, -- 괴물이 쫓아오는 중인지
	lowHealth: number, -- 0~1, 체력이 낮을수록 1
	alive: boolean,
}

function Audio.update(dt: number, mood: Mood)
	for _, name in { "LobbyMusic", "ForestAmbience", "TensionMusic", "ChaseMusic", "Heartbeat" } do
		if music[name] == nil and templates[name] and not failed[name] then
			music[name] = Audio.loop(name)
		end
	end

	if mood.chasing then
		chaseHold = 4 -- 추격이 끝나도 4초간 음악 유지
	else
		chaseHold = math.max(0, chaseHold - dt)
	end
	local chase = mood.playing and mood.alive and chaseHold > 0
	local muted = os.clock() < muteUntil

	local lobby = if mood.playing or muted then 0 else 1
	local ambience = if muted then 0.2 elseif mood.playing then 1 - mood.danger * 0.4 else 0.35
	local tension = if not mood.playing or muted or not mood.alive then 0 elseif chase then mood.danger * 0.3 else mood.danger ^ 1.2
	local chaseVol = if chase and not muted then 1 else 0
	local fear = if mood.playing and mood.alive then math.max(mood.danger, mood.lowHealth) else 0

	Audio.fade(music.LobbyMusic, lobby, dt, 1)
	Audio.fade(music.ForestAmbience, ambience, dt, 1)
	Audio.fade(music.TensionMusic, tension, dt, 1.5)
	Audio.fade(music.ChaseMusic, chaseVol, dt, if chaseVol > 0 then 4 else 0.8)
	Audio.fade(music.Heartbeat, fear, dt, 3)
	if music.Heartbeat then
		music.Heartbeat.PlaybackSpeed = 1 + fear * 0.6
	end
end

return Audio
