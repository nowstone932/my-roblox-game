-- 게임 밸런스 숫자는 전부 여기서 바꿉니다.
-- 코드를 몰라도 이 파일만 고치면 괴물 속도, 재료 개수 같은 걸 조절할 수 있어요.

local Config = {}

Config.Round = {
	IntermissionTime = 20, -- (게임 서버) 대기실에서 넘어온 사람들을 기다리는 최대 시간(초)
	RoundTime = 900, -- 한 라운드 제한 시간(초) = 15분
}

-- 대기실(로비): 방 여러 개, 방에 들어가면 카운트다운 후 그 방 사람들끼리 출발
Config.Lobby = {
	RoomCount = 4, -- 방 개수
	MaxPlayers = 5, -- 방 하나에 들어갈 수 있는 최대 인원
	Countdown = 30, -- 첫 사람이 들어가면 출발까지 몇 초
	-- true: 출발하면 그 방 사람들만 "새 서버(전용 숲)"로 순간이동 (게임을 게시한 뒤에만 동작)
	-- false: 같은 서버 안의 숲으로 출발 (한 번에 한 방만 플레이, 나머지 방은 기다림)
	-- Studio 테스트에서는 순간이동이 안 되기 때문에 항상 false처럼 동작해요.
	UseTeleport = true,
	ReturnDelay = 10, -- 라운드가 끝나고 대기실로 돌아가기까지(초)
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

	-- 공포 연출 행동
	StalkChance = 0.5, -- 멀리서 발견했을 때 바로 달려오지 않고 가만히 지켜볼 확률
	StalkMinDistance = 35, -- 이 거리보다 멀 때만 지켜보기
	StalkTime = { 3, 6 }, -- 지켜보는 시간(초) 범위
	StalkCooldown = 40,
	LungeSpeedMultiplier = 1.7, -- 돌진할 때 속도 배수
	LungeTime = 1.2,
	LungeCooldown = 8,
	AmbushAfter = 45, -- 이 시간 동안 아무도 못 찾으면 플레이어 등 뒤 어딘가로 순간이동
	AmbushDistance = { 45, 65 },
	ClosetSearchChance = 0.35, -- 숨는 걸 들켰을 때 옷장을 열어젖힐 확률
	ClosetSearchDamage = 40,
}

-- 플레이어가 괴물에게 치명상을 입으면 바로 죽지 않고 쓰러짐 → 동료가 살려줄 수 있음
Config.Downed = {
	BleedOutTime = 35, -- 이 시간 안에 못 살리면 사망
	ReviveHoldTime = 4, -- 동료가 E를 누르고 있어야 하는 시간
	ReviveHealth = 40,
}

-- 랜덤 공포 이벤트 (환청, 유령, 정전 등)
Config.Events = {
	Interval = { 50, 110 }, -- 이벤트 사이 간격(초)
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
-- places: 그 재료가 놓일 수 있는 장소 (MapBuilder가 만든 자리 이름)
-- forest: 숲 바닥에 아무렇게나 떨어져 있을 비율 (0~1)
Config.Materials = {
	Scrap = { Count = 26, RespawnTime = 45, places = { "Junk", "Shelf", "SawmillFloor", "Workbench" }, forest = 0.15 },
	Wood = { Count = 26, RespawnTime = 45, places = { "LogPile", "SawmillFloor", "Campfire" }, forest = 0.5 },
	Herb = { Count = 18, RespawnTime = 60, places = { "HerbPatch" }, forest = 0.4 },
	Gunpowder = { Count = 8, RespawnTime = 60, places = { "ExplosiveCrate", "Shelf" }, forest = 0 },
	Cloth = { Count = 12, RespawnTime = 60, places = { "Clothesline", "Bed", "CabinFloor" }, forest = 0 },
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

-- 소리와 배경음악(BGM) ID는 src/shared/SoundList.luau 에서 바꿔요. (설명: docs/소리_넣기.md)

-- 수익화: Creator Hub에서 게임패스/개발자 상품을 만든 뒤 숫자 ID를 넣으세요. 0이면 꺼짐.
Config.Monetization = {
	StarterKitPassId = 0, -- 게임패스: 라운드 시작 시 조명탄 총 + 조명탄 6발 + 손도끼
	ReviveProductId = 0, -- 개발자 상품: 죽었을 때 그 자리에서 부활
	FlashbangPackProductId = 0, -- 개발자 상품: 섬광탄 3개
	StarterKitAmmo = 6,
}

return Config
