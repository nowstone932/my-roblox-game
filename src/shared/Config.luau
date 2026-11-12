-- 게임 밸런스 숫자는 전부 여기서 바꿉니다.
-- 코드를 몰라도 이 파일만 고치면 괴물 속도, 재료 개수 같은 걸 조절할 수 있어요.

local Config = {}

Config.Round = {
	IntermissionTime = 20, -- 라운드 시작 전 대기 시간(초)
	RoundTime = 900, -- 한 라운드 제한 시간(초) = 15분
	MinPlayers = 1,
}

Config.Map = {
	Size = 640, -- 숲 한 변의 길이(스터드)
	TreeCount = 320,
	DeadTreeCount = 60,
	RockCount = 50,
	BushCount = 90,
}

Config.Monster = {
	MaxHealth = 300,
	WanderSpeed = 11,
	ChaseSpeed = 19, -- 기본 플레이어 걷기 속도는 16 (달리기 22)
	RagePerStage = 1.5, -- 탈출 진행도가 오를 때마다 추격 속도 증가량
	SightRange = 90,
	HearRange = 16, -- 이 거리 안이면 숨어도(옷장 제외) 들킴
	LoseSightTime = 6,
	AttackRange = 6,
	AttackDamage = 35,
	AttackCooldown = 1.4,
	DownedTime = 40, -- 쓰러져 있는 시간. 이 안에 봉인 말뚝을 박아야 함
	NearPlayerWanderChance = 0.55, -- 배회할 때 플레이어 근처로 갈 확률 (높을수록 무서움)
}

-- 소리 범위: 이 거리 안의 괴물이 소리 난 곳으로 조사하러 옴
Config.Noise = {
	Gunshot = 160,
	TruckStart = 400,
	RadioCall = 400,
	Generator = 120,
	Axe = 40,
}

-- 숲에 무작위로 떨어져 있는 재료 (탈출 부품은 Story.luau 의 QuestItems)
Config.Materials = {
	Scrap = { Count = 30, RespawnTime = 45 },
	Wood = { Count = 30, RespawnTime = 45 },
	Herb = { Count = 18, RespawnTime = 60 },
	Gunpowder = { Count = 14, RespawnTime = 60 },
	Cloth = { Count = 14, RespawnTime = 60 },
}

Config.Tools = {
	FlareGun = { Damage = 30, Cooldown = 0.7, Range = 250 },
	Axe = { Damage = 18, Cooldown = 0.8, Range = 9 },
	Flashbang = { Radius = 30, StunTime = 5, FuseTime = 1.2, ThrowSpeed = 70 },
	Trap = { HoldTime = 6 },
	Medkit = { Heal = 50 },
	SealStake = { Range = 14 },
}

Config.Escape = {
	FusesRequired = 3,
	AntennaRequired = 2,
	RunesRequired = 3,
	TruckWarmup = 20, -- 시동 걸고 출발까지 버텨야 하는 시간
	TruckBoardRadius = 18, -- 출발 순간 트럭 근처에 있어야 탈출
	RescueWait = 90, -- 무전 후 헬기 도착까지
	RescueWindow = 40, -- 헬기가 기다려주는 시간
}

Config.Hiding = {
	MaxTime = 25, -- 옷장에 숨어 있을 수 있는 최대 시간
	BlockedRange = 12, -- 괴물이 이 거리 안에 있으면 숨을 수 없음
}

-- 소리 ID (Creator Store에서 무료 사운드를 찾아 rbxassetid 숫자를 넣으세요. 0이면 소리 없음)
Config.Sounds = {
	Ambience = 0, -- 숲 배경음 (반복)
	MonsterScream = 0, -- 괴물이 플레이어를 발견했을 때
	Heartbeat = 0, -- 괴물이 가까울 때 (반복)
	Gunshot = 0,
	Flashbang = 0,
}

-- 수익화: Creator Hub에서 게임패스/개발자 상품을 만든 뒤 숫자 ID를 넣으세요. 0이면 꺼짐.
Config.Monetization = {
	StarterKitPassId = 0, -- 게임패스: 라운드 시작 시 조명탄 총 + 조명탄 6발 + 손도끼
	ReviveProductId = 0, -- 개발자 상품: 죽었을 때 그 자리에서 부활
	FlashbangPackProductId = 0, -- 개발자 상품: 섬광탄 3개
	StarterKitAmmo = 6,
}

return Config
