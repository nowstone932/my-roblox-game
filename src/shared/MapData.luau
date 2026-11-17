-- 지도 화면(client/MapUi.luau)에 그릴 장소와 길.
-- 좌표는 server/Services/MapBuilder.luau 가 짓는 위치와 같아요. (x, z) / 북쪽 = -Z
-- 맵을 옮겼으면 여기 숫자도 같이 바꿔 주세요. 제단은 일부러 "출입 금지"로만 표시합니다.

local MapData = {}

MapData.Size = 640 -- 숲 한 변의 길이 (Config.Map.Size 와 같게)

-- kind: "Start" 시작 / "Camp" 중앙 캠프 / "Exit" 탈출 장소 / "Place" 그 밖의 장소 / "Danger" 위험
-- side = "right": 이름을 점 오른쪽에 씀 (가까운 장소끼리 글씨가 겹치지 않게)
MapData.Places = {
	{ name = "시작 (고장난 차)", x = 10, z = 272, kind = "Start" },
	{ name = "벌목 캠프", x = 0, z = 104, kind = "Camp" },
	{ name = "제재소", x = 50, z = 76, kind = "Place", side = "right" },
	{ name = "벌목 트럭", x = 18, z = 46, kind = "Exit", side = "right" },
	{ name = "전기 정문", x = 0, z = -292, kind = "Exit" },
	{ name = "발전기", x = 44, z = -262, kind = "Place", side = "right" },
	{ name = "감시탑 (무전기)", x = -210, z = -40, kind = "Place" },
	{ name = "헬기장", x = -205, z = -155, kind = "Exit" },
	{ name = "벌목지", x = -150, z = 185, kind = "Place" },
	{ name = "폐주유소", x = 210, z = 60, kind = "Place" },
	{ name = "고물 집하장", x = 232, z = 140, kind = "Place" },
	{ name = "서낭당", x = 108, z = -62, kind = "Place" },
	{ name = "옛 제단 (출입 금지)", x = 185, z = -175, kind = "Danger" },
}

-- 길: 점을 차례로 이은 선
MapData.Roads = {
	{ width = 5, points = { { 0, 320 }, { 0, 220 }, { -12, 160 }, { 0, 110 }, { 6, 20 }, { -6, -120 }, { 0, -260 }, { 0, -320 } } },
	{ width = 4, points = { { 0, 100 }, { -120, 40 }, { -205, -30 }, { -205, -140 } } },
	{ width = 4, points = { { 0, 100 }, { 120, 70 }, { 210, 60 }, { 230, 140 } } },
	{ width = 3, points = { { -12, 160 }, { -100, 182 } } },
	{ width = 2, points = { { 6, 20 }, { 62, -22 }, { 100, -54 } } },
}

return MapData
