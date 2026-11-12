-- 제작법 목록. 순서대로 숫자키 1, 2, 3, 4 에 연결됩니다.

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
		id = "FlareGun",
		name = "조명탄 총",
		desc = "괴물에게 피해를 줍니다 (왼쪽 클릭)",
		cost = { Scrap = 3, Wood = 2 },
		item = "FlareGun",
		amount = 1,
		unique = true,
	},
	{
		id = "Ammo",
		name = "탄약 x3",
		desc = "조명탄 총 탄약",
		cost = { Scrap = 1, Gunpowder = 1 },
		item = "Ammo",
		amount = 3,
	},
	{
		id = "Flashbang",
		name = "섬광탄",
		desc = "가까운 괴물을 잠시 기절시킵니다 (G)",
		cost = { Scrap = 2, Gunpowder = 1 },
		item = "Flashbang",
		amount = 1,
	},
	{
		id = "Medkit",
		name = "붕대",
		desc = "체력을 회복합니다 (H)",
		cost = { Herb = 2, Wood = 1 },
		item = "Medkit",
		amount = 1,
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
