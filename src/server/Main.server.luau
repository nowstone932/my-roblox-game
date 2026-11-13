-- 서버 시작점. 각 기능(Service)을 순서대로 켭니다.
--
-- 이 게임은 장소(Place) 하나로 두 가지 서버 역할을 해요.
--   대기실 서버: 보통 서버. 대기실 + 방 4개. (Studio 테스트도 여기)
--   게임 서버  : 방 카운트다운이 끝나면 그 방 사람들만 순간이동해 오는 전용 서버. 숲에서 한 판.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
local LobbyBuilder = require(Services.LobbyBuilder)
local Tools = require(Services.Tools)
local Pickups = require(Services.Pickups)
local MonsterAI = require(Services.MonsterAI)
local Hiding = require(Services.Hiding)
local Combat = require(Services.Combat)
local Monetization = require(Services.Monetization)
local GameLoop = require(Services.GameLoop)
local Lobby = require(Services.Lobby)

local isMatchServer = Lobby.isMatchServer()
print(if isMatchServer then "[서버] 게임 서버로 시작 (대기실에서 온 팀 전용)" else "[서버] 대기실 서버로 시작")

local map = MapBuilder.build()
local lobbyInfo = if isMatchServer then nil else LobbyBuilder.build()

Tools.init()
Pickups.init(map)
MonsterAI.init(map)
Hiding.init(map)
Combat.init()
Monetization.init({
	onRevive = GameLoop.revive,
})
GameLoop.init(map, {
	matchServer = isMatchServer,
	lobbySpawn = if lobbyInfo then lobbyInfo.spawn else nil,
})

if isMatchServer then
	GameLoop.runMatchServer()
else
	Lobby.init(lobbyInfo, {
		startLocal = GameLoop.startMatch,
		canStartLocal = GameLoop.canStartMatch,
	})
end
