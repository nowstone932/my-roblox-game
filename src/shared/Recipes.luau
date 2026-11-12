-- 제작법 목록 (제작 창에 이 순서대로 나옵니다)

export type Recipe = {
	id: string,
	name: string,
	desc: string,
	cost: { [string]: number },
	item: string,
	amount: number,
	unique: boolean?, -- true면 하나만 가질 수 있음
}

local list: { Recipe } = {
	{
		id = "Axe",
		name = "손도끼",
		desc = "근접 무기. 조용하다",
		cost = { Wood = 2, Scrap = 1 },
		item = "Axe",
		amount = 1,
		unique = true,
	},
	{
		id = "FlareGun",
		name = "조명탄 총",
		desc = "원거리 무기. 총소리가 괴물을 부른다",
		cost = { Scrap = 3, Wood = 1, Gunpowder = 1 },
		item = "FlareGun",
		amount = 1,
		unique = true,
	},
	{
		id = "Ammo",
		name = "조명탄 x3",
		desc = "조명탄 총 탄약",
		cost = { Scrap = 1, Gunpowder = 1 },
		item = "Ammo",
		amount = 3,
	},
	{
		id = "Flashbang",
		name = "섬광탄",
		desc = "던져서 괴물을 5초 기절",
		cost = { Scrap = 1, Gunpowder = 2 },
		item = "Flashbang",
		amount = 1,
	},
	{
		id = "Trap",
		name = "곰덫",
		desc = "밟은 괴물을 6초 묶어둔다",
		cost = { Scrap = 3 },
		item = "Trap",
		amount = 1,
	},
	{
		id = "Medkit",
		name = "붕대",
		desc = "체력 50 회복",
		cost = { Herb = 1, Cloth = 1 },
		item = "Medkit",
		amount = 1,
	},
	{
		id = "SealStake",
		name = "봉인 말뚝",
		desc = "쓰러진 괴물에게 박으면 영원히 봉인",
		cost = { Rune = 3, Wood = 2 },
		item = "SealStake",
		amount = 1,
		unique = true,
	},
}

local byId: { [string]: Recipe } = {}
for _, recipe in list do
	byId[recipe.id] = recipe
end

return {
	list = list,
	byId = byId,
}
