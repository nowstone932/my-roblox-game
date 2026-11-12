-- 서버 시작점. 각 기능(Service)을 순서대로 켭니다.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
local Tools = require(Services.Tools)
local Pickups = require(Services.Pickups)
local MonsterAI = require(Services.MonsterAI)
local Hiding = require(Services.Hiding)
local Combat = require(Services.Combat)
local Monetization = require(Services.Monetization)
local GameLoop = require(Services.GameLoop)

local map = MapBuilder.build()

Tools.init()
Pickups.init(map)
MonsterAI.init(map)
Hiding.init(map)
Combat.init()
Monetization.init({
	onRevive = GameLoop.revive,
})
GameLoop.init(map)

GameLoop.run()
