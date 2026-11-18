-- 플레이어 설정(언어, 효과음/배경음 크기)을 기억해 두는 곳
--
-- 설정은 클라이언트(client/Settings.luau)가 바꾸고, 여기서는 저장만 해요.
-- 대기실 서버에서 바꾼 설정이 숲(전용 서버)으로 넘어가도, 다음에 다시 접속해도 그대로 남습니다.
--   플레이어 속성: OptLang("en"/"ko"/"es"/"pt"), OptSfx(0~100), OptMusic(0~100), OptLoaded(불러오기 끝남)
--
-- Studio에서는 "게임 설정 > 보안 > Studio의 API 서비스 접근 허용"을 켜지 않으면 저장이 안 돼요.
-- 그래도 게임은 정상으로 돌아가고, 설정만 그 판 동안만 유지됩니다.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Settings = {}

local store: DataStore? = nil
local dirty: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

local function key(player: Player): string
	return "settings_" .. player.UserId
end

local function validPercent(value: any): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function load(player: Player)
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok and typeof(data) == "table" and player.Parent == Players then
			if Lang.isSupported(data.lang) then
				player:SetAttribute("OptLang", data.lang)
			end
			local sfx, music = validPercent(data.sfx), validPercent(data.music)
			if sfx then
				player:SetAttribute("OptSfx", sfx)
			end
			if music then
				player:SetAttribute("OptMusic", music)
			end
		elseif not ok then
			warn("[설정] 불러오지 못했어요 (기본값으로 시작):", data)
		end
	end
	if player.Parent == Players then
		player:SetAttribute("OptLoaded", true)
	end
end

local function save(player: Player)
	if not store or not dirty[player] then
		return
	end
	dirty[player] = nil
	local data = {
		lang = player:GetAttribute("OptLang"),
		sfx = player:GetAttribute("OptSfx"),
		music = player:GetAttribute("OptMusic"),
	}
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), data)
	end)
	if not ok then
		warn("[설정] 저장하지 못했어요:", err)
	end
end

-- 바뀔 때마다 바로 저장하지 않고, 몇 초 모았다가 한 번만 저장
local function saveSoon(player: Player)
	dirty[player] = true
	if saving[player] then
		return
	end
	saving[player] = true
	task.delay(4, function()
		saving[player] = nil
		if player.Parent == Players then
			save(player)
		end
	end)
end

function Settings.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerSettings_v1")
	end)
	if ok then
		store = result
	else
		warn("[설정] 저장소를 열 수 없어요 (설정이 저장되지 않습니다):", result)
	end

	Remotes.get("SaveSettings").OnServerEvent:Connect(function(player: Player, lang: any, sfx: any, music: any)
		if not Lang.isSupported(lang) then
			return
		end
		local sfxValue, musicValue = validPercent(sfx), validPercent(music)
		if not sfxValue or not musicValue then
			return
		end
		player:SetAttribute("OptLang", lang)
		player:SetAttribute("OptSfx", sfxValue)
		player:SetAttribute("OptMusic", musicValue)
		saveSoon(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		dirty[player] = nil
		saving[player] = nil
	end)
end

return Settings
