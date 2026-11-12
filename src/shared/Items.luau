-- 게임에 나오는 모든 아이템 정의
--   kind = "Material" : 제작 재료 (가방에 개수로 쌓임)
--   kind = "Quest"    : 탈출에 필요한 핵심 부품 (가방에 표시, 장소에 설치)
--   kind = "Tool"     : 손에 드는 도구. 화면 아래 핫바(1~9번)에 실제 아이템으로 들어옵니다.

export type ItemDef = {
	name: string,
	kind: string,
	color: Color3,
	desc: string,
	stack: boolean?, -- Tool 중 여러 개 쌓이는 소모품 (섬광탄 등)
}

local Items: { [string]: ItemDef } = {
	-- 재료
	Scrap = { name = "고철", kind = "Material", color = Color3.fromRGB(150, 150, 160), desc = "녹슨 쇳조각" },
	Wood = { name = "나무", kind = "Material", color = Color3.fromRGB(120, 80, 45), desc = "단단한 장작" },
	Herb = { name = "약초", kind = "Material", color = Color3.fromRGB(60, 200, 90), desc = "상처에 바르는 풀" },
	Gunpowder = { name = "화약", kind = "Material", color = Color3.fromRGB(70, 70, 70), desc = "캠프 창고의 화약" },
	Cloth = { name = "천", kind = "Material", color = Color3.fromRGB(200, 190, 160), desc = "붕대로 쓸 수 있는 천" },
	Ammo = { name = "조명탄", kind = "Material", color = Color3.fromRGB(255, 120, 40), desc = "조명탄 총 탄약" },

	-- 탈출 부품
	Fuse = { name = "퓨즈", kind = "Quest", color = Color3.fromRGB(255, 200, 40), desc = "발전기에 넣으면 정문이 열린다" },
	Battery = { name = "자동차 배터리", kind = "Quest", color = Color3.fromRGB(60, 120, 255), desc = "벌목 트럭용" },
	FuelCan = { name = "연료통", kind = "Quest", color = Color3.fromRGB(220, 40, 40), desc = "벌목 트럭용" },
	CarKey = { name = "트럭 열쇠", kind = "Quest", color = Color3.fromRGB(230, 230, 120), desc = "벌목 트럭용" },
	Antenna = { name = "안테나 부품", kind = "Quest", color = Color3.fromRGB(170, 220, 255), desc = "감시탑 무전기 수리용" },
	Rune = { name = "룬 조각", kind = "Quest", color = Color3.fromRGB(150, 60, 255), desc = "괴물을 봉인하는 말뚝의 재료" },

	-- 도구 (핫바)
	FlareGun = { name = "조명탄 총", kind = "Tool", color = Color3.fromRGB(255, 120, 40), desc = "원거리 공격. 총소리는 괴물을 부른다" },
	Axe = { name = "손도끼", kind = "Tool", color = Color3.fromRGB(180, 180, 190), desc = "근접 공격. 탄약이 필요 없다" },
	Flashbang = { name = "섬광탄", kind = "Tool", color = Color3.fromRGB(230, 230, 230), desc = "던지면 터져서 괴물을 기절시킨다", stack = true },
	Trap = { name = "곰덫", kind = "Tool", color = Color3.fromRGB(120, 120, 120), desc = "바닥에 설치. 괴물이 밟으면 묶인다", stack = true },
	Medkit = { name = "붕대", kind = "Tool", color = Color3.fromRGB(240, 240, 240), desc = "체력 회복", stack = true },
	SealStake = { name = "봉인 말뚝", kind = "Tool", color = Color3.fromRGB(150, 60, 255), desc = "쓰러진 괴물에게 박으면 영원히 봉인된다" },
}

-- 가방에 보여줄 순서
local order = {
	"Fuse", "Battery", "FuelCan", "CarKey", "Antenna", "Rune",
	"Scrap", "Wood", "Herb", "Gunpowder", "Cloth", "Ammo",
	"FlareGun", "Axe", "Flashbang", "Trap", "Medkit", "SealStake",
}

return {
	defs = Items,
	order = order,
}
