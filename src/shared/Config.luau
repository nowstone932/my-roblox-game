-- 게임 밸런스 숫자는 전부 여기서 바꿉니다.
-- 코드를 몰라도 이 파일만 고치면 괴물 속도, 재료 개수 같은 걸 조절할 수 있어요.

local Config = {}

Config.Round = {
	IntermissionTime = 15, -- 라운드 시작 전 대기 시간(초)
	RoundTime = 600, -- 한 라운드 제한 시간(초)
	MinPlayers = 1, -- 이 인원 이상이면 라운드 시작
}

Config.Map = {
	Size = 600, -- 숲 한 변의 길이(스터드)
	TreeCount = 220, -- 나무 개수
}

Config.Monster = {
	MaxHealth = 300,
	WanderSpeed = 10, -- 배회할 때 속도
	ChaseSpeed = 20, -- 쫓아올 때 속도 (기본 플레이어 속도는 16)
	SightRange = 90, -- 이 거리 안에서 눈에 보이면 쫓아옴
	HearRange = 18, -- 이 거리 안이면 나무 뒤에 숨어도 들킴
	LoseSightTime = 6, -- 놓친 뒤 이 시간이 지나면 포기
	AttackRange = 5,
	AttackDamage = 35,
	AttackCooldown = 1.5,
	RespawnTime = 45, -- 쓰러진 뒤 다시 깨어나는 시간
}

-- 숲에 떨어져 있는 재료들
Config.Materials = {
	Scrap = { Count = 30, Color = Color3.fromRGB(150, 150, 160), RespawnTime = 40 },
	Wood = { Count = 30, Color = Color3.fromRGB(110, 75, 40), RespawnTime = 40 },
	Herb = { Count = 20, Color = Color3.fromRGB(60, 200, 90), RespawnTime = 50 },
	Gunpowder = { Count = 15, Color = Color3.fromRGB(60, 60, 60), RespawnTime = 60 },
	Fuse = { Count = 5, Color = Color3.fromRGB(255, 200, 40), RespawnTime = 90 },
}

Config.Weapon = {
	Damage = 25,
	FireCooldown = 0.6,
	Range = 250,
}

Config.Flashbang = {
	Radius = 35,
	StunTime = 5,
}

Config.Medkit = {
	Heal = 50,
}

Config.Escape = {
	FusesRequired = 3, -- 탈출문을 열려면 퓨즈 박스에 넣어야 하는 퓨즈 수
}

-- 수익화: Creator Hub에서 게임패스/개발자 상품을 만든 뒤 숫자 ID를 넣으세요.
-- 0이면 해당 기능은 꺼진 상태입니다.
Config.Monetization = {
	StarterKitPassId = 0, -- 게임패스: 라운드 시작 시 조명탄 총 + 탄약 6발
	ReviveProductId = 0, -- 개발자 상품: 죽었을 때 그 자리에서 부활
	FlashbangPackProductId = 0, -- 개발자 상품: 섬광탄 3개
	StarterKitAmmo = 6,
}

-- 화면에 보이는 한국어 이름
Config.ItemNames = {
	Scrap = "고철",
	Wood = "나무",
	Herb = "약초",
	Gunpowder = "화약",
	Fuse = "퓨즈",
	Ammo = "탄약",
	Flashbang = "섬광탄",
	Medkit = "붕대",
	FlareGun = "조명탄 총",
}

-- 인벤토리에 저장되는 모든 아이템 (플레이어 Attribute 이름으로 쓰임)
Config.InventoryKeys = {
	"Scrap",
	"Wood",
	"Herb",
	"Gunpowder",
	"Fuse",
	"FlareGun",
	"Ammo",
	"Flashbang",
	"Medkit",
}

return Config
