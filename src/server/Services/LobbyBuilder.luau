-- 대기실(로비) 건물을 파트로 만듭니다.
-- 숲과 멀리 떨어진 하늘 위(ORIGIN)에 지어서 괴물/숲과 섞이지 않아요.
--
--   [방1] [방2] [방3] [방4]     <- 각 방 바닥(색깔 판)에 올라서면 그 방에 들어간 것
--
--            (시작 지점)

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Build = require(script.Parent.Build)

local LobbyBuilder = {}

export type RoomInfo = {
	index: number,
	center: CFrame, -- 방 바닥 한가운데 (바닥 높이)
	halfSize: Vector3, -- 이 상자 안에 있으면 방 안에 있는 것
	outside: CFrame, -- 방이 꽉 찼을 때 밀어낼 위치 (방 앞)
	sign: TextLabel, -- 방 입구 위 전광판 글씨
	pad: BasePart,
}

export type LobbyInfo = {
	spawn: CFrame,
	rooms: { RoomInfo },
}

local ORIGIN = CFrame.new(0, 300, 1600) -- 숲(가운데 0,0 / 한 변 640)과 멀리 떨어진 곳
local ROOM_SIZE = 24
local ROOM_HEIGHT = 12
local ROOM_GAP = 8

local ROOM_COLORS = {
	Color3.fromRGB(220, 70, 60), -- 빨강
	Color3.fromRGB(60, 140, 230), -- 파랑
	Color3.fromRGB(70, 190, 90), -- 초록
	Color3.fromRGB(235, 190, 60), -- 노랑
	Color3.fromRGB(170, 90, 220),
	Color3.fromRGB(240, 130, 50),
}

local WALL = Color3.fromRGB(58, 46, 36)
local FLOOR = Color3.fromRGB(70, 56, 42)

local function signLabel(part: BasePart, text: string, textColor: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0 -- 어두워도 잘 보이게
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.RichText = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = textColor
	label.Parent = gui
	return label
end

function LobbyBuilder.build(): LobbyInfo
	local old = Workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	local count = Config.Lobby.RoomCount
	local width = math.max(140, count * (ROOM_SIZE + ROOM_GAP) + 30)
	local depth = 100
	local height = 26

	-- 바닥, 천장, 벽 (밖으로 못 나가게 막힘)
	Build.part(folder, Vector3.new(width, 2, depth), ORIGIN * CFrame.new(0, -1, 0), FLOOR, Enum.Material.WoodPlanks)
	Build.part(folder, Vector3.new(width, 2, depth), ORIGIN * CFrame.new(0, height + 1, 0), WALL, Enum.Material.Wood)
	Build.part(folder, Vector3.new(width, height, 2), ORIGIN * CFrame.new(0, height / 2, -depth / 2 - 1), WALL, Enum.Material.Wood)
	Build.part(folder, Vector3.new(width, height, 2), ORIGIN * CFrame.new(0, height / 2, depth / 2 + 1), WALL, Enum.Material.Wood)
	Build.part(folder, Vector3.new(2, height, depth), ORIGIN * CFrame.new(-width / 2 - 1, height / 2, 0), WALL, Enum.Material.Wood)
	Build.part(folder, Vector3.new(2, height, depth), ORIGIN * CFrame.new(width / 2 + 1, height / 2, 0), WALL, Enum.Material.Wood)

	-- 천장 조명
	for x = -width / 2 + 20, width / 2 - 20, 30 do
		for _, z in { -25, 20 } do
			local lamp = Build.part(folder, Vector3.new(2, 0.6, 2), ORIGIN * CFrame.new(x, height - 0.3, z), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
			local light = Build.light(lamp, Color3.fromRGB(255, 210, 160), 40, 1.6)
			light.Shadows = false
		end
	end

	-- 큰 안내판 (방 위쪽 벽)
	local title = Build.part(
		folder,
		Vector3.new(70, 7, 0.4),
		ORIGIN * CFrame.new(0, height - 4.5, -depth / 2 + 0.3) * CFrame.Angles(0, math.pi, 0), -- 글씨 면이 대기실 쪽을 보게
		Color3.fromRGB(25, 20, 16),
		Enum.Material.SmoothPlastic
	)
	signLabel(
		title,
		("흑송 벌목장 수색대 대기실\n방 바닥에 올라서면 %d초 뒤 출발 · 한 방 최대 %d명"):format(
			Config.Lobby.Countdown,
			Config.Lobby.MaxPlayers
		),
		Color3.fromRGB(240, 225, 200)
	)

	-- 방
	local rooms: { RoomInfo } = {}
	local roomZ = -depth / 2 + ROOM_SIZE / 2 + 6
	local totalWidth = count * ROOM_SIZE + (count - 1) * ROOM_GAP
	for i = 1, count do
		local x = -totalWidth / 2 + ROOM_SIZE / 2 + (i - 1) * (ROOM_SIZE + ROOM_GAP)
		local center = ORIGIN * CFrame.new(x, 0, roomZ)
		local color = ROOM_COLORS[(i - 1) % #ROOM_COLORS + 1]
		local room = Instance.new("Model")
		room.Name = "Room" .. i
		room.Parent = folder

		local pad = Build.part(room, Vector3.new(ROOM_SIZE - 2, 0.3, ROOM_SIZE - 2), center * CFrame.new(0, 0.15, 0), color, Enum.Material.Neon, {
			Transparency = 0.55,
			CanCollide = false,
		})
		pad.Name = "Pad"
		-- 뒤 벽, 옆 벽 (앞은 열려 있음)
		Build.part(room, Vector3.new(ROOM_SIZE, ROOM_HEIGHT, 1), center * CFrame.new(0, ROOM_HEIGHT / 2, -ROOM_SIZE / 2), WALL, Enum.Material.Wood)
		Build.part(room, Vector3.new(1, ROOM_HEIGHT, ROOM_SIZE), center * CFrame.new(-ROOM_SIZE / 2, ROOM_HEIGHT / 2, 0), WALL, Enum.Material.Wood)
		Build.part(room, Vector3.new(1, ROOM_HEIGHT, ROOM_SIZE), center * CFrame.new(ROOM_SIZE / 2, ROOM_HEIGHT / 2, 0), WALL, Enum.Material.Wood)
		-- 입구 위 들보 + 색 띠
		Build.part(room, Vector3.new(ROOM_SIZE, 1.2, 1), center * CFrame.new(0, ROOM_HEIGHT - 0.6, ROOM_SIZE / 2), WALL, Enum.Material.Wood)
		Build.part(room, Vector3.new(ROOM_SIZE, 0.4, 0.2), center * CFrame.new(0, ROOM_HEIGHT - 1.4, ROOM_SIZE / 2 + 0.5), color, Enum.Material.Neon)
		local roomLamp = Build.part(room, Vector3.new(1.5, 0.4, 1.5), center * CFrame.new(0, ROOM_HEIGHT - 0.2, 0), color, Enum.Material.Neon)
		Build.light(roomLamp, color, 22, 1.2).Shadows = false

		-- 입구 위 전광판 (방 앞쪽을 바라봄)
		local signPos = (center * CFrame.new(0, ROOM_HEIGHT + 3, ROOM_SIZE / 2)).Position
		local board = Build.part(room, Vector3.new(ROOM_SIZE - 2, 5.5, 0.4), CFrame.lookAt(signPos, signPos - center.LookVector), Color3.fromRGB(15, 15, 18))
		board.Name = "Sign"
		local sign = signLabel(board, "방 " .. i, Color3.new(1, 1, 1))

		table.insert(rooms, {
			index = i,
			center = center,
			halfSize = Vector3.new(ROOM_SIZE / 2 - 1, 8, ROOM_SIZE / 2 - 1),
			outside = center * CFrame.new(0, 3, ROOM_SIZE / 2 + 8),
			sign = sign,
			pad = pad,
		})
	end

	-- 시작 지점 (방들을 바라봄)
	local spawnPos = (ORIGIN * CFrame.new(0, 3, depth / 2 - 15)).Position
	local spawn = CFrame.lookAt(spawnPos, spawnPos + ORIGIN.LookVector)
	local spawnMark = Build.part(folder, Vector3.new(12, 0.2, 12), CFrame.new(spawnPos - Vector3.new(0, 2.9, 0)), Color3.fromRGB(90, 75, 60), Enum.Material.Slate, {
		CanCollide = false,
	})
	spawnMark.Name = "LobbySpawn"

	folder.Parent = Workspace
	return {
		spawn = spawn,
		rooms = rooms,
	}
end

return LobbyBuilder
