-- 대기실(수색대 야영지) 천막 관리. 코드에서는 천막 하나를 "방(room)"이라고 불러요.
--
-- 1. 천막 안(바닥 깔개 위)에 들어서면 그 천막에 들어감 (꽉 찼으면 천막 앞으로 밀려남)
-- 2. 첫 사람이 들어오면 카운트다운 시작 (Config.Lobby.Countdown 초까지 기다림)
-- 3. Config.Lobby.StartAfter 초가 지나면 "지금 출발" 버튼이 생김. 누르면 바로 출발
-- 4. 0초가 되거나 버튼을 누르면 그 천막에 있는 사람들만 함께 출발
--      - 게시된 게임: 그 천막 사람들만 새 전용 서버로 순간이동 (TeleportService)
--      - Studio 테스트 / UseTeleport = false: 이 서버의 숲으로 바로 출발
-- 천막에서 걸어 나가면 빠지고, 천막이 비면 카운트다운이 취소돼요.
-- (천막 안에서 점프하는 건 괜찮아요. 걸어서 밖으로 나가야 빠집니다)
--
-- 천막 앞 안내판과 화면 위 글씨는 클라이언트(client/Hud.luau)가 아래 속성을 보고 그립니다.
--   ReplicatedStorage: LobbyRoom1Count, LobbyRoom1Status, LobbyRoom1Left, LobbyRoom1Start

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local lobbyNotify = Remotes.get("LobbyNotify")
local lobbyStart = Remotes.get("LobbyStart")

local L = Config.Lobby

local Lobby = {}

type Room = {
	info: any, -- LobbyBuilder.RoomInfo
	members: { Player },
	status: string, -- "Empty" | "Counting" | "Waiting" | "Launching"
	deadline: number?,
	startedAt: number?, -- 카운트다운이 시작된 때
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

-- margin: 이미 들어와 있는 사람은 이만큼 더 벗어나야 나간 것으로 침 (경계에서 들락날락하지 않게)
-- 높이는 넉넉하게 봐서 점프해도 나간 것으로 치지 않아요.
local function isInside(room: Room, player: Player, margin: number?): boolean
	local hrp = rootOf(player)
	if not hrp then
		return false
	end
	local rel = room.info.center:PointToObjectSpace(hrp.Position)
	local h = room.info.halfSize
	local m = margin or 0
	return math.abs(rel.X) <= h.X + m and math.abs(rel.Z) <= h.Z + m and rel.Y >= -4 and rel.Y <= h.Y
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
local function canStartNow(room: Room): boolean
	return room.status == "Counting" and room.startedAt ~= nil and os.clock() - room.startedAt >= L.StartAfter
end

local function setAttr(name: string, value: any)
	if ReplicatedStorage:GetAttribute(name) ~= value then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local function publish(room: Room)
	local key = "LobbyRoom" .. room.info.index
	local n = #room.members
	local left = 0
	if room.status == "Counting" and room.deadline then
		left = math.max(0, math.ceil(room.deadline - os.clock()))
	end
	setAttr(key .. "Count", n)
	setAttr(key .. "Status", room.status)
	setAttr(key .. "Left", left)
	setAttr(key .. "Start", canStartNow(room))
	-- 사람이 있는 천막은 등불이 밝아짐
	room.info.lamp.Brightness = if n > 0 then 2.4 else 0.9
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
		room.startedAt = nil
	end
end

local function addMember(room: Room, player: Player)
	table.insert(room.members, player)
	player:SetAttribute("LobbyRoom", room.info.index)
	if room.status == "Empty" then
		room.status = "Counting"
		room.startedAt = os.clock()
		room.deadline = room.startedAt + L.Countdown
	end
	sayRoom(room, ("%s 님이 %d번 천막에 들어왔어요 (%d/%d)"):format(player.DisplayName, room.info.index, #room.members, L.MaxPlayers))
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
	room.startedAt = nil
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
				elseif not canJoinRooms(p) or not isInside(room, p, 2.5) then
					removeMember(room, p, ("%d번 천막에서 나왔어요"):format(room.info.index))
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
						bounce(room, player, "이 천막은 지금 출발하는 중이에요")
					elseif #room.members >= L.MaxPlayers then
						bounce(room, player, ("%d번 천막은 꽉 찼어요 (최대 %d명). 다른 천막으로 가세요"):format(room.info.index, L.MaxPlayers))
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
		local room: Room = { info = roomInfo, members = {}, status = "Empty", deadline = nil, startedAt = nil }
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

	-- "지금 출발" 버튼: 카운트다운이 StartAfter 초 넘게 흐른 천막에 있는 사람만 누를 수 있음
	lobbyStart.OnServerEvent:Connect(function(player: Player)
		local room = roomOf(player)
		if room and canStartNow(room) then
			sayRoom(room, ("%s 님이 출발 버튼을 눌렀어요"):format(player.DisplayName))
			room.deadline = os.clock() -- 다음 확인 때 바로 출발
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn("[대기실] 순간이동 실패:", player.Name, result, message)
		player:SetAttribute("Teleporting", nil)
		say(player, "숲으로 이동하지 못했어요. 다시 천막에 들어가 주세요")
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
