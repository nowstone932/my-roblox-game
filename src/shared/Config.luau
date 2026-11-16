-- 게임 밸런스 숫자는 전부 여기서 바꿉니다.
-- 코드를 몰라도 이 파일만 고치면 괴물 속도, 재료 개수 같은 걸 조절할 수 있어요.

local Config = {}

Config.Round = {
	IntermissionTime = 20, -- (게임 서버) 대기실에서 넘어온 사람들을 기다리는 최대 시간(초)
	RoundTime = 1080, -- 한 라운드 제한 시간(초) = 18분
	FinaleTime = 240, -- 남은 시간이 이만큼이 되면 3막(폭풍)이 시작됨. 탈출 장치를 켜도 바로 시작됨
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
	TreeCount = 330, -- 소나무 (많을수록 무겁지만 숲이 빽빽해짐)
	DeadTreeCount = 70,
	RockCount = 45, -- 바위 (진짜 지형으로 만들어짐)
	BushCount = 100,
	StumpCount = 60, -- 숲 여기저기의 그루터기 (벌목지에는 따로 더 있음)
	FallenLogCount = 24, -- 쓰러진 통나무
	FogBankCount = 10, -- 바닥에 깔리는 안개 (손전등에 비침)
}

Config.Monster = {
	MaxHealth = 300,
	WanderSpeed = 11,
	ChaseSpeed = 19, -- 플레이어 걷기 15, 달리기 23 (Config.Player)
	RagePerStage = 1.5, -- 탈출 진행도가 오를 때마다 추격 속도 증가량
	FinaleSpeedBonus = 2, -- 3막(폭풍)에서 추가로 빨라지는 속도
	LoseSightTime = 6,
	AttackRange = 6,
	AttackDamage = 35,
	AttackCooldown = 1.4,
	DownedTime = 40, -- 쓰러져 있는 시간. 이 안에 봉인 말뚝을 박아야 함
	NearPlayerWanderChance = 0.45, -- 배회할 때 플레이어 근처로 갈 확률 (높을수록 자주 마주침)

	-- 눈: 손전등을 켜고 있으면 멀리서도 들키고, 끄면 가까이 와야 들킴
	SightRange = 90, -- 손전등을 켠 플레이어를 알아보는 거리
	DarkSightRange = 46, -- 손전등을 끈 플레이어를 알아보는 거리
	SightAngle = 110, -- 정면에서 좌우로 이 각도(도)까지만 봄. 등 뒤는 못 봄
	CloseSenseRange = 16, -- 이 거리 안이면 등 뒤에 있어도 기척으로 알아챔
	LightOnBackRange = 55, -- 이 거리 안에서 손전등으로 괴물을 비추면 등 뒤에서도 들킴

	-- 귀: 달리기 > 걷기 > 웅크리기 순으로 멀리 들림
	SprintHearRange = 48, -- 달리는 발소리가 들리는 거리
	WalkHearRange = 22, -- 걷는 발소리가 들리는 거리
	StillHearRange = 8, -- 웅크려 걷거나 가만히 있어도 이 거리 안이면 숨소리를 들음

	-- 지켜보기(Stalk): 멀리서 발견하면 바로 달려오지 않음.
	-- 플레이어가 "보고 있는 동안"은 꼼짝 않고 서 있다가, 눈을 떼면 소리 없이 다가옴.
	StalkChance = 0.6, -- 멀리서 발견했을 때 지켜보기를 시작할 확률
	StalkMinDistance = 30, -- 이 거리보다 멀 때만 지켜보기
	StalkTime = { 16, 26 }, -- 지켜보기가 이어지는 최대 시간(초) 범위
	StalkCooldown = 35,
	CreepSpeed = 9, -- 안 볼 때 다가오는 속도
	CreepStrikeRange = 15, -- 이 거리까지 다가오면 덮침
	StareBreakTime = 2.8, -- 이만큼(초) 계속 쳐다보면 반응함 (덮치거나, 어둠 속으로 물러남)
	StareChargeRange = 34, -- 쳐다볼 때 이 거리 안이면 물러나지 않고 덮침
	FleeTriggerRange = 60, -- 지켜보는 중에 이 거리 안에서 등을 보이고 달리면 바로 쫓아옴

	LungeSpeedMultiplier = 1.7, -- 돌진할 때 속도 배수
	LungeTime = 1.2,
	LungeCooldown = 8,
	AmbushAfter = 60, -- 이 시간 동안 아무도 못 찾으면 플레이어 등 뒤 어딘가에서 다시 나타남 (아무도 안 볼 때만)
	AmbushDistance = { 45, 65 },
	ClosetSearchChance = 0.35, -- 숨는 걸 들켰을 때 옷장을 열어젖힐 확률
	ClosetSearchDamage = 40,

	-- 시작 유예(1막): 라운드가 시작되고 이 시간(초) 동안은 괴물이 자기 둥지(제단) 근처만 돌아다니고,
	-- 아무도 쫓지 않아요. (둥지 근처를 어슬렁거리다 GraceChaseRange 안으로 들어온 사람만 알아챔)
	StartGrace = 150,
	GraceChaseRange = 35,

	HuntTime = 18, -- 놓친 뒤 마지막으로 본 곳 주변을 뒤지는 시간(초)
	HuntRadius = 28, -- 뒤지는 범위(스터드). 근처 건물 안도 들어가서 확인함
}

-- 플레이어 움직임
Config.Player = {
	WalkSpeed = 15,
	SprintSpeed = 23,
	CrouchSpeed = 7, -- 웅크려 걷기 (발소리가 거의 안 남)
	SprintTime = 5, -- 기력이 가득일 때 달릴 수 있는 시간(초)
	SprintRecover = 8, -- 기력이 다 차는 데 걸리는 시간(초)
}

-- 플레이어가 괴물에게 치명상을 입으면 바로 죽지 않고 쓰러짐 → 동료가 살려줄 수 있음
Config.Downed = {
	BleedOutTime = 35, -- 이 시간 안에 못 살리면 사망
	ReviveHoldTime = 4, -- 동료가 E를 누르고 있어야 하는 시간
	ReviveHealth = 40,
}

-- 공포 연출 감독(Director): 플레이어마다 상황(집 안/숲/혼자/숨는 중)에 맞는 일을 골라서 일으킴
-- 괴물이 실제로 가까이 있을 때는 가짜 연출을 하지 않음 (진짜가 충분히 무서우니까)
Config.Director = {
	FirstDelay = { 25, 45 }, -- 라운드 시작 후 첫 연출까지(초)
	Interval = { 30, 65 }, -- 한 사람에게 연출이 일어나는 간격(초)
	FinaleFactor = 0.7, -- 3막에서는 간격이 이 배수로 짧아짐
	MonsterNearRange = 70, -- 괴물이 이 거리 안이면 가짜 연출을 미룸
	CalmAfterChase = 25, -- 쫓기고 난 뒤 이 시간(초) 동안은 연출을 쉼 (숨 돌릴 틈)
	BlackoutInterval = { 170, 260 }, -- 숲 전체 정전 간격(초)
	LightningRevealInterval = { 70, 130 }, -- 번개가 칠 때 멀리 무언가가 서 있는 연출 간격(초)
}

-- 안개. 숫자 3개는 순서대로 1막(정적) / 2막(사냥) / 3막(폭풍)
-- Density 가 클수록 안개가 짙어져서 멀리 안 보임 (0.3 옅음 ~ 0.6 아주 짙음)
Config.Atmosphere = {
	Density = { 0.36, 0.42, 0.5 },
	Haze = { 1.8, 2.4, 3 },
	LobbyDensity = 0.12, -- 대기실에 있을 때
	MoonBrightness = 0.5, -- 달빛 세기 (나무 그림자가 생김). 0이면 달빛 없음
}

-- 날씨. 숫자 3개는 순서대로 1막 / 2막 / 3막
Config.Weather = {
	RainRate = { 140, 420, 950 }, -- 빗방울 개수 (0이면 비 없음)
	LightningInterval = { { 80, 150 }, { 40, 85 }, { 9, 22 } }, -- 번개 간격(초) 범위
	Wind = { 4, 9, 18 }, -- 바람 세기 (풀이 흔들리는 정도)
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
	Cell = { Count = 9, RespawnTime = 100, places = { "CabinTable", "Bed", "TowerCrate", "Workbench", "Shelf", "Helipad" }, forest = 0 }, -- 손전등 건전지
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
	GateOpenTime = 22, -- 발전기를 켜고 정문이 다 열릴 때까지 버텨야 하는 시간 (그동안 발전기가 시끄럽게 돎)
	TruckWarmup = 20, -- 시동 걸고 출발까지 버텨야 하는 시간
	TruckBoardRadius = 18, -- 출발 순간 트럭 근처에 있어야 탈출
	RescueWait = 90, -- 무전 후 헬기 도착까지
	RescueWindow = 40, -- 헬기가 기다려주는 시간
}

Config.Hiding = {
	MaxTime = 25, -- 옷장/차 밑에 숨어 있을 수 있는 최대 시간
	BlockedRange = 12, -- 괴물이 이 거리 안에 있으면 숨을 수 없음
}

-- 직접 만든 3D 괴물 모델 (Studio의 ReplicatedStorage > Assets > Monster 에 넣었을 때만 쓰여요)
Config.MonsterModel = {
	Height = 16, -- 괴물 키(스터드). 플레이어 키는 약 5.5. 모델은 이 키에 맞게 자동으로 커지거나 작아져요
	HipHeight = 6.5, -- 판정 상자가 땅에서 떠 있는 높이 (기본 괴물과 같게)
	FaceYaw = 0, -- 괴물이 뒷걸음질로 다니면 180 으로 바꾸세요
	-- Animation Editor에서 "Roblox에 게시"하고 받은 애니메이션 번호 (0 = 없음)
	Animations = {
		Idle = 0, -- 가만히 서 있기 (supjigi-still)
		Walk = 0, -- 걷기 (supjigi-walking)
		Run = 0, -- 달리기 (supjigi-running)
		Charge = 0, -- 쫓아올 때 팔을 뻗고 달리기 (supjigi-charge-prototype). 없으면 Run 을 씀
		Attack = 0, -- 할퀴기 (없어도 됨)
		Stunned = 0, -- 눈이 부셔 움츠림 (없어도 됨)
		Scream = 0, -- 울부짖기 (없어도 됨)
	},
}

-- 화면 효과
Config.Screen = {
	DangerRed = 0, -- 괴물이 가까울 때 화면이 붉어지는 세기 (0~1). 0 = 끔 (대신 화면 가장자리가 어두워지고 심장 소리가 남)
	Vignette = 0.4, -- 평소 화면 가장자리 어둡기 (0~1)
	FearVignette = 0.25, -- 괴물이 가까울 때 더해지는 어둡기
	HeadBob = 1, -- 걸을 때 화면 흔들림 배수 (0 = 끔. 멀미가 나면 줄이세요)
	ObjectiveShowTime = 9, -- 목표 패널이 바뀐 뒤 화면에 떠 있는 시간(초). Q를 누르면 언제든 볼 수 있음
}

-- 손전등. 켜고 있으면 괴물이 멀리서도 알아보고, 건전지가 닳음
Config.Flashlight = {
	Brightness = 4.5, -- 빛의 세기
	Range = 75, -- 빛이 닿는 거리 (스터드)
	Angle = 50, -- 빛이 퍼지는 각도 (도). 너무 넓히면 공포감이 줄어요
	BatteryTime = 210, -- 건전지 하나로 켜둘 수 있는 시간(초)
	LowBattery = 0.22, -- 이 아래로 떨어지면 어두워지고 깜빡임 (0~1)
	TeamBrightness = 2.2, -- 다른 사람 눈에 보이는 내 손전등 밝기
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
