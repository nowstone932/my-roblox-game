-- 서버에서 "이 소리 내줘"라고 클라이언트에게 알리는 도우미.
-- 소리 번호는 전부 src/shared/SoundList.luau 에 있어요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundList = require(ReplicatedStorage.Shared.SoundList)

local effect = Remotes.get("Effect")

local Sfx = {}

-- 모든 플레이어에게. position을 주면 그 자리에서 나는 3D 소리
function Sfx.all(name: string, position: Vector3?)
	effect:FireAllClients("Sfx", name, position)
end

-- 한 플레이어에게만
function Sfx.to(player: Player, name: string, position: Vector3?)
	effect:FireClient(player, "Sfx", name, position)
end

-- 움직이는 물체(트럭, 헬기)에 반복 소리를 붙임. 서버에서 틀면 모두에게 3D로 들림
function Sfx.attach(name: string, target: Instance): Sound?
	local def = SoundList.Sounds[name]
	local soundId = def and SoundList.toSoundId(def.id)
	if not soundId then
		return nil
	end
	local part = if target:IsA("BasePart") then target else target:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. name
	s.SoundId = soundId
	s.Volume = (def.volume or 1) * SoundList.MasterVolume.Effects
	s.PlaybackSpeed = def.pitch or 1
	s.Looped = def.looped == true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = def.range or 150
	s.Parent = part
	s:Play()
	return s
end

-- attach로 붙인 소리를 전부 끔
function Sfx.detach(target: Instance)
	for _, d in target:GetDescendants() do
		if d:IsA("Sound") and d.Name:sub(1, 4) == "Sfx_" then
			d:Destroy()
		end
	end
end

return Sfx
