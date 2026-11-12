-- 서버 시작점. 각 기능(Service)을 순서대로 켭니다.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
local MaterialSpawner = require(Services.MaterialSpawner)
local MonsterAI = require(Services.MonsterAI)
local Combat = require(Services.Combat)
local Monetization = require(Services.Monetization)
local GameLoop = require(Services.GameLoop)

local map = MapBuilder.build()

MaterialSpawner.init(map)
MonsterAI.init(map)
Combat.init()
Monetization.init({
	onRevive = GameLoop.revive,
})
GameLoop.init(map)

GameLoop.run()
