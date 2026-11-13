-- 대기실(로비) 방 관리
--
-- 1. 방 바닥에 올라서면 그 방에 들어감 (꽉 찼으면 방 앞으로 밀려남)
-- 2. 첫 사람이 들어오면 카운트다운 시작 (Config.Lobby.Countdown 초)
-- 3. 0초가 되면 그 방에 있는 사람들만 함께 출발
--      - 게시된 게임: 그 방 사람들만 새 전용 서버로 순간이동 (TeleportService)
--      - Studio 테스트 / UseTeleport = false: 이 서버의 숲으로 바로 출발
-- 방에서 나가면 빠지고, 방이 비면 카운트다운이 취소돼요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local lobbyNotify = Remotes.get("LobbyNotify")

local L = Config.Lobby

local Lobby = {}

type Room = {
	info: any, -- LobbyBuilder.RoomInfo
	members: { Player },
	status: string, -- "Empty" | "Counting" | "Waiting" | "Launching"
	deadline: number?,
}

type Options = {
	startLocal: ({ Player }) -> boolean, -- 이 서버의 숲에서 시작. 시작했으면 true
	canStartLocal: () -> boolean, -- 지금 이 서버의 숲이 비었는지
}

local rooms: { Room } = {}
local options: Options
local lobbySpawn: CFrame

-- Studio에서는 순간이동이 안 되므로 같은 서버에서 시작
local function useTeleport(): boolean
	return L.UseTeleport and not RunService:IsStudio() and game.PlaceId ~= 0
end

-- 이 서버가 "대기실에서 출발한 팀 전용 서버"인지
-- (ReserveServer로 만든 서버는 PrivateServerId가 있고 주인(OwnerId)이 0)
function Lobby.isMatchServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function say(player: Player, text: string)
	lobbyNotify:FireClient(player, text)
end

local function sayRoom(room: Room, text: string)
	for _, p in room.members do
		say(p, text)
	end
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function isInside(room: Room, player: Player): boolean
	local hrp = rootOf(player)
	if not hrp then
		return false
	end
	local rel = room.info.center:PointToObjectSpace(hrp.Position)
	local h = room.info.halfSize
	return math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z and rel.Y >= -2 and rel.Y <= h.Y
end

local function canJoinRooms(player: Player): boolean
	return player.Parent == Players and player:GetAttribute("InLobby") == true and player:GetAttribute("Teleporting") ~= true
end

local function roomOf(player: Player): Room?
	for _, room in rooms do
		if table.find(room.members, player) then
			return room
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- 화면/전광판 표시
---------------------------------------------------------------------------
local function statusText(room: Room): string
	local n = #room.members
	if room.status == "Counting" and room.deadline then
		return ("%d초 후 출발"):format(math.max(0, math.ceil(room.deadline - os.clock())))
	elseif room.status == "Waiting" then
		return "다른 팀이 숲에 있어요. 끝나면 출발"
	elseif room.status == "Launching" then
		return "출발!"
	elseif n >= L.MaxPlayers then
		return "꽉 참"
	end
	return "들어오면 출발 준비"
end

local function publish(room: Room)
	local i = room.info.index
	local n = #room.members
	local text = statusText(room)
	local full = n >= L.MaxPlayers
	local signText = ("방 %d   <font color=\"%s\">%d / %d명</font>\n%s"):format(
		i,
		if full then "#ff6060" else "#ffffff",
		n,
		L.MaxPlayers,
		text
	)
	if room.info.sign.Text ~= signText then
		room.info.sign.Text = signText
	end
	room.info.pad.Transparency = if n > 0 then 0.25 else 0.55
	-- 클라이언트 화면 위쪽 글씨용
	local line = ("%d/%d명 · %s"):format(n, L.MaxPlayers, text)
	if ReplicatedStorage:GetAttribute("LobbyRoom" .. i) ~= line then
		ReplicatedStorage:SetAttribute("LobbyRoom" .. i, line)
	end
end

---------------------------------------------------------------------------
-- 들어가기 / 나가기
---------------------------------------------------------------------------
local function removeMember(room: Room, player: Player, reason: string?)
	local idx = table.find(room.members, player)
	if not idx then
		return
	end
	table.remove(room.members, idx)
	if player.Parent == Players and player:GetAttribute("LobbyRoom") == room.info.index then
		player:SetAttribute("LobbyRoom", nil)
	end
	if reason and player.Parent == Players then
		say(player, reason)
	end
	if #room.members == 0 and (room.status == "Counting" or room.status == "Waiting") then
		room.status = "Empty"
		room.deadline = nil
	end
end

local function addMember(room: Room, player: Player)
	table.insert(room.members, player)
	player:SetAttribute("LobbyRoom", room.info.index)
	if room.status == "Empty" then
		room.status = "Counting"
		room.deadline = os.clock() + L.Countdown
	end
	sayRoom(room, ("%s 님이 방 %d에 들어왔어요 (%d/%d)"):format(player.DisplayName, room.info.index, #room.members, L.MaxPlayers))
end

local function bounce(room: Room, player: Player, text: string)
	local char = player.Character
	if char then
		char:PivotTo(room.info.outside)
	end
	say(player, text)
end

---------------------------------------------------------------------------
-- 출발
---------------------------------------------------------------------------
local function resetRoom(room: Room)
	for i = #room.members, 1, -1 do
		removeMember(room, room.members[i])
	end
	room.status = "Empty"
	room.deadline = nil
end

local function teleportGroup(room: Room, group: { Player }): boolean
	for _, p in group do
		p:SetAttribute("Teleporting", true)
	end
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(game.PlaceId)
		local teleportOptions = Instance.new("TeleportOptions")
		teleportOptions.ReservedServerAccessCode = code
		teleportOptions:SetTeleportData({ fromLobby = true, room = room.info.index, expected = #group })
		TeleportService:TeleportAsync(game.PlaceId, group, teleportOptions)
	end)
	if not ok then
		warn("[대기실] 순간이동 실패:", err)
		for _, p in group do
			p:SetAttribute("Teleporting", nil)
		end
		return false
	end
	-- 순간이동이 조용히 실패해서 아직 남아 있으면 다시 방에 들어갈 수 있게 풀어줌
	task.delay(25, function()
		for _, p in group do
			if p.Parent == Players then
				p:SetAttribute("Teleporting", nil)
			end
		end
	end)
	return true
end

local function launch(room: Room)
	local group = table.clone(room.members)
	if #group == 0 then
		resetRoom(room)
		return
	end

	if useTeleport() then
		room.status = "Launching"
		publish(room)
		sayRoom(room, "출발! 숲으로 이동합니다…")
		if teleportGroup(room, group) then
			resetRoom(room)
			return
		end
		sayRoom(room, "전용 서버로 이동하지 못했어요. 이 서버의 숲으로 출발합니다")
	end

	if not options.canStartLocal() then
		if room.status ~= "Waiting" then
			room.status = "Waiting"
			sayRoom(room, "다른 팀이 숲을 쓰고 있어요. 그 판이 끝나면 바로 출발해요")
		end
		return
	end

	room.status = "Launching"
	publish(room)
	resetRoom(room)
	for _, p in group do
		p:SetAttribute("InLobby", false)
	end
	if not options.startLocal(group) then
		-- 시작 못 했으면 대기실로 되돌림
		for _, p in group do
			if p.Parent == Players then
				p:SetAttribute("InLobby", true)
			end
		end
	end
end

local function step()
	-- 1) 방을 벗어났거나 나간 사람 빼기
	for _, room in rooms do
		if room.status ~= "Launching" then
			for i = #room.members, 1, -1 do
				local p = room.members[i]
				if p.Parent ~= Players then
					removeMember(room, p)
				elseif not canJoinRooms(p) or not isInside(room, p) then
					removeMember(room, p, ("방 %d에서 나왔어요"):format(room.info.index))
				end
			end
		end
	end

	-- 2) 새로 들어온 사람 넣기
	for _, player in Players:GetPlayers() do
		if canJoinRooms(player) and not roomOf(player) then
			for _, room in rooms do
				if isInside(room, player) then
					if room.status == "Launching" then
						bounce(room, player, "이 방은 지금 출발하는 중이에요")
					elseif #room.members >= L.MaxPlayers then
						bounce(room, player, ("방 %d은(는) 꽉 찼어요 (최대 %d명). 다른 방으로 가세요"):format(room.info.index, L.MaxPlayers))
					else
						addMember(room, player)
					end
					break
				end
			end
		end
	end

	-- 3) 카운트다운
	for _, room in rooms do
		if room.status == "Counting" and room.deadline and os.clock() >= room.deadline then
			launch(room)
		elseif room.status == "Waiting" and options.canStartLocal() then
			launch(room)
		end
		publish(room)
	end
end

function Lobby.getSpawn(): CFrame
	return lobbySpawn
end

function Lobby.init(info, opts: Options)
	options = opts
	lobbySpawn = info.spawn
	for _, roomInfo in info.rooms do
		local room: Room = { info = roomInfo, members = {}, status = "Empty", deadline = nil }
		table.insert(rooms, room)
		publish(room)
	end

	Players.PlayerRemoving:Connect(function(player)
		local room = roomOf(player)
		if room then
			removeMember(room, player)
			publish(room)
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn("[대기실] 순간이동 실패:", player.Name, result, message)
		player:SetAttribute("Teleporting", nil)
		say(player, "숲으로 이동하지 못했어요. 다시 방에 들어가 주세요")
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[대기실] 오류:", err)
			end
			task.wait(0.25)
		end
	end)
end

return Lobby
