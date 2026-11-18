-- 영어 번역 사전: ["한국어 원문"] = "English"
--
-- 설정 창에서 언어를 English 로 바꾸면 shared/Lang.luau 가 이 사전으로 글을 바꿔 보여줍니다.
-- 한국어 원문은 코드에 쓰인 글자와 "완전히 똑같아야" 해요 (띄어쓰기, 문장부호까지).
-- %d(숫자), %s(이름) 자리는 영어 쪽에도 같은 순서로 넣어 주세요.
-- 여기 없는 글은 영어 설정에서도 한국어로 보입니다.
-- 숲 속 표지판 글씨도 여기서 번역합니다 (client/WorldText.luau). 장승의 한자(天下大將軍 등)는 장식이라 그대로 둡니다.

local Items = require(script.Parent.Items)
local Recipes = require(script.Parent.Recipes)
local Story = require(script.Parent.Story)

local En: { [string]: string } = {
	-----------------------------------------------------------------------
	-- 화면(HUD)
	-----------------------------------------------------------------------
	["[E] 줍기/사용   [C] 제작   [1~9] 도구 들기   [클릭] 도구 사용   [M] 지도\n[F] 손전등   [R] 건전지 교체   [Shift] 달리기   [Ctrl] 웅크리기   [Q] 목표   [P] 설정   [B] 상점(대기실)"] = "[E] Pick up / Use   [C] Craft   [1-9] Equip tool   [Click] Use tool   [M] Map\n[F] Flashlight   [R] Swap battery   [Shift] Sprint   [Ctrl] Crouch   [Q] Objectives   [P] Settings   [B] Shop (lobby)",
	["제작대  (C로 닫기)"] = "Workbench  (C to close)",
	["섬광탄 3개 구매 (로벅스)"] = "Buy 3 flashbangs (Robux)",
	["닫기"] = "Close",
	["[E] 닫기"] = "[E] Close",
	["숲지기에게 당했다…"] = "The Warden got you…",
	["살아있는 동료를 관전합니다 — 모두 끝나면 라운드 종료"] = "Spectating your teammates — the round ends when everyone is done",
	["지금 부활하기 (로벅스)"] = "Revive now (Robux)",
	["쓰러졌다!"] = "You are down!",
	["스스로 일어나기 (로벅스)"] = "Get back up (Robux)",
	["동료가 와서 살려줘야 한다… %d초"] = "A teammate must revive you… %ds",
	["차 밑에 숨어 있다… 숨 참기 %d초  (E로 나오기)"] = "Hiding under the car… holding breath %ds  (E to get out)",
	["옷장에 숨어 있다… 숨 참기 %d초  (E로 나오기)"] = "Hiding in the closet… holding breath %ds  (E to get out)",
	["가방이 비었다"] = "Your bag is empty",
	["새벽까지 %s"] = "%s until dawn",
	["탈출 성공! 다른 사람을 기다리는 중"] = "You escaped! Waiting for the others",
	["같이 출발한 수색대원을 기다리는 중… %s"] = "Waiting for the rest of your search party… %s",
	["라운드 종료"] = "Round over",
	["손전등 %s · 건전지 x%d"] = "Flashlight %s · Batteries x%d",
	["방전"] = "dead",
	["켜짐"] = "on",
	["꺼짐"] = "off",
	["인식표 — %s"] = "Dog tag — %s",
	['인식표 뒷면에 칼로 긁어 쓴 글씨:\n\n"%s"'] = 'Scratched into the back of the tag with a knife:\n\n"%s"',
	["관전 중: %s   [Q] / [E] 바꾸기"] = "Spectating: %s   [Q] / [E] to switch",

	-- 목표 패널
	["탈출 방법"] = "Ways out",
	["정문: 열림! 북쪽 출구로"] = "Gate: OPEN! Head for the north exit",
	["정문: 올라가는 중… %d초 버텨라"] = "Gate: rising… hold out %ds",
	["정문: 발전기 퓨즈 %d/%d"] = "Gate: generator fuses %d/%d",
	["트럭: 출발까지 %d초! 근처에 있어라"] = "Truck: leaving in %ds! Stay close",
	["트럭: 수리 완료 — 시동 가능"] = "Truck: repaired — ready to start",
	["트럭: 떠났다"] = "Truck: gone",
	["트럭: %s배터리 %s연료 %s열쇠"] = "Truck: %sbattery %sfuel %skey",
	["무전: 헬기 도착까지 %d초"] = "Radio: helicopter arrives in %ds",
	["무전: 헬기 도착! 헬기장으로 (%d초)"] = "Radio: helicopter is here! Get to the helipad (%ds)",
	["무전: 수리 완료 — 구조 요청 가능"] = "Radio: repaired — ready to call for rescue",
	["무전: 헬기가 떠났다"] = "Radio: the helicopter left",
	["무전: 안테나 %d/%d"] = "Radio: antenna parts %d/%d",
	["봉인: 말뚝 준비됨 — 괴물을 쓰러뜨려라"] = "Seal: stake ready — bring the monster down",
	["봉인: 룬 조각 %d/%d → 봉인 말뚝 제작"] = "Seal: rune shards %d/%d → craft the Sealing Stake",
	["실종자 인식표 모두 거둠 — 이제 봉인하면…"] = "All dog tags recovered — seal it now and…",
	["실종자 인식표 %d/%d"] = "Missing loggers' dog tags %d/%d",

	-----------------------------------------------------------------------
	-- 대기실 (수색대 야영지)
	-----------------------------------------------------------------------
	["[Enter] 지금 출발"] = "[Enter] Set out now",
	["지금 출발"] = "Set out now",
	["%d번 천막"] = "Tent %d",
	["%d번 천막 · %d/%d명 · %s"] = "Tent %d · %d/%d · %s",
	["%d초 후 출발"] = "Leaving in %ds",
	["%d초 후 출발 · 출발 버튼까지 %d초"] = "Leaving in %ds · start button in %ds",
	["다른 팀이 숲에 있어요. 끝나면 출발"] = "Another team is in the forest. You leave when they finish",
	["출발!"] = "Setting out!",
	["꽉 참"] = "Full",
	["들어오면 출발 준비"] = "Step inside to get ready",
	["숲으로 이동하는 중…"] = "Heading into the forest…",
	["수색대 야영지 — 천막 안에 들어가면 출발 준비 (천막 하나 최대 %d명)"] = "Search party camp — step into a tent to get ready (up to %d per tent)",
	["<b>수색대 수칙</b>\n1. 천막에 들어가면 같은 조가 된다 (최대 %d명)\n2. 불빛은 아껴 써라. 그것은 빛을 본다\n3. 뛰지 마라. 그것은 소리를 듣는다\n4. 숲에서 누가 불러도 대답하지 마라"] = "<b>SEARCH PARTY RULES</b>\n1. Everyone in a tent leaves as one team (up to %d)\n2. Save your light. It sees light\n3. Do not run. It hears you\n4. If a voice calls from the woods, do not answer",
	["%s 님이 %d번 천막에 들어왔어요 (%d/%d)"] = "%s joined tent %s (%s/%s)",
	["%d번 천막에서 나왔어요"] = "You left tent %s",
	["%s 님이 출발 버튼을 눌렀어요"] = "%s pressed the start button",
	["이 천막은 지금 출발하는 중이에요"] = "This tent is setting out right now",
	["%d번 천막은 꽉 찼어요 (최대 %d명). 다른 천막으로 가세요"] = "Tent %s is full (max %s). Try another tent",
	["출발! 숲으로 이동합니다…"] = "Setting out! Heading into the forest…",
	["전용 서버로 이동하지 못했어요. 이 서버의 숲으로 출발합니다"] = "Could not reach a private server. Starting in this server's forest",
	["다른 팀이 숲을 쓰고 있어요. 그 판이 끝나면 바로 출발해요"] = "Another team is using the forest. You will leave as soon as their round ends",
	["숲으로 이동하지 못했어요. 다시 천막에 들어가 주세요"] = "Could not travel to the forest. Please step into a tent again",
	["대기실로 돌아갑니다…"] = "Returning to camp…",

	-----------------------------------------------------------------------
	-- 설정 / 지도
	-----------------------------------------------------------------------
	["설정"] = "Settings",
	["[P] 닫기"] = "[P] Close",
	["[P] 마우스로 조작"] = "[P] Use mouse",
	["언어"] = "Language",
	["효과음"] = "Sound effects",
	["배경음"] = "Music",
	["흑송 벌목장 지도"] = "Blackpine Logging Camp",
	["▲ 나   ● 동료   초록 = 탈출 장소   [M] 닫기"] = "▲ You   ● Teammates   Green = escape route   [M] Close",
	["시작 (고장난 차)"] = "Start (broken car)",
	["벌목 캠프"] = "Logging camp",
	["제재소"] = "Sawmill",
	["벌목 트럭"] = "Logging truck",
	["전기 정문"] = "Electric gate",
	["발전기"] = "Generator",
	["감시탑 (무전기)"] = "Ranger tower (radio)",
	["헬기장"] = "Helipad",
	["벌목지"] = "Clear-cut",
	["폐주유소"] = "Old gas station",
	["고물 집하장"] = "Junkyard",
	["서낭당"] = "Shrine",
	["옛 제단 (출입 금지)"] = "Old altar (KEEP OUT)",
	-- 캠프 게시판의 안내도
	["흑송 벌목장\n안내도"] = "Blackpine Camp\nArea Map",
	["지금 여기"] = "You are here",
	["● 지금 여기"] = "● You are here",
	["■ 탈출 장소"] = "■ Escape route",
	["● 시작한 곳"] = "● Starting point",
	["● 출입 금지"] = "● Keep out",
	["지도를 챙기면 어디서든 다시 펼쳐 볼 수 있다"] = "Take the map and you can open it again anywhere",
	["지도 보기"] = "Look at map",
	["벌목장 지도"] = "Camp map",
	["벌목장 지도를 챙겼다 — [M]으로 언제든 펼쳐 볼 수 있다"] = "You took the camp map — press [M] to open it any time",
	["지도가 없다 — 벌목 캠프 한가운데 게시판에서 챙길 수 있다"] = "No map — grab one from the notice board in the middle of the logging camp",

	-----------------------------------------------------------------------
	-- 숲에서 뜨는 안내 글 (서버가 보냄)
	-----------------------------------------------------------------------
	["흑송 벌목장"] = "Blackpine Logging Camp",
	["손전등 건전지가 다 닳았다 — [R] 건전지 교체"] = "Flashlight battery is dead — [R] to swap",
	["손전등 건전지가 다 닳았다… 건전지를 찾아야 한다"] = "Flashlight battery is dead… you need to find one",
	["건전지가 없다"] = "No batteries",
	["숲이 술렁인다… 숲지기가 더 빨라졌다"] = "The forest stirs… the Warden is faster now",
	["발전기 가동! 정문이 천천히 올라간다… %d초만 버텨라"] = "Generator running! The gate is slowly rising… hold out %s seconds",
	["정문이 열렸다! 북쪽 출구로!"] = "The gate is open! Run for the north exit!",
	["퓨즈가 필요하다 (%d/%d)"] = "You need fuses (%s/%s)",
	["퓨즈 %d/%d"] = "Fuses %s/%s",
	["트럭이 출발했다!"] = "The truck has left!",
	["트럭에 필요한 것: 배터리, 연료통, 열쇠"] = "The truck needs: battery, fuel can, key",
	["트럭 부품 설치!"] = "Truck part installed!",
	["트럭 수리 완료! 시동을 걸 수 있다 (소리가 크다)"] = "Truck repaired! You can start it (it is loud)",
	["엔진이 굉음을 낸다! %d초 뒤 출발 — 트럭 근처를 지켜라!"] = "The engine roars! Leaving in %s seconds — stay near the truck!",
	["구조 헬기 도착! 서쪽 헬기장으로! (%d초 대기)"] = "Rescue helicopter is here! Get to the west helipad! (waits %s seconds)",
	["헬기가 떠났다…"] = "The helicopter left…",
	["안테나 부품이 필요하다 (%d/%d)"] = "You need antenna parts (%s/%s)",
	["안테나 %d/%d"] = "Antenna %s/%s",
	["무전기 수리 완료! 구조를 요청할 수 있다"] = "Radio repaired! You can call for rescue",
	['"여기는 수색대! 흑송 벌목장 헬기장으로 구조 바람!" — %d초 뒤 헬기 도착'] = '"Search party here! Requesting rescue at the Blackpine helipad!" — helicopter in %s seconds',
	["스타터 키트: 조명탄 총 + 손도끼 + 조명탄 %d발"] = "Starter kit: flare gun + hatchet + %s flares",
	["괴물이 너무 가까워서 숨을 수 없다!"] = "The monster is too close to hide!",
	["누군가 이미 숨어 있다"] = "Someone is already hiding here",
	["숨이 차서 뛰쳐나왔다!"] = "Out of breath — you burst out!",
	["숲지기가 차 밑에서 끌어냈다!"] = "The Warden dragged you out from under the car!",
	["숲지기가 옷장 문을 뜯어냈다!"] = "The Warden tore the closet door off!",
	["조명탄이 없어요! (제작: 고철 1 + 화약 1)"] = "No flares! (Craft: 1 scrap + 1 gunpowder)",
	["괴물이 빛에 눈이 멀었다! (%d초)"] = "The monster is blinded! (%s seconds)",
	["여기엔 설치할 수 없어요"] = "You cannot place it here",
	["곰덫 설치!"] = "Bear trap set!",
	["체력이 이미 가득해요"] = "You are already at full health",
	["괴물이 쓰러져 있을 때만 박을 수 있다"] = "You can only drive it in while the monster is down",
	["더 가까이 가야 한다"] = "Get closer",
	["이미 %s을(를) 가지고 있어요"] = "You already have: %s",
	["재료가 부족해요"] = "Not enough materials",
	["제작 완료: %s (핫바에 들어갔어요)"] = "Crafted: %s (added to your hotbar)",
	["제작 완료: %s"] = "Crafted: %s",
	["%s이(가) %s을(를) 일으켜 세웠다!"] = "%s revived %s!",
	["%s이(가) 쓰러졌다! %d초 안에 가서 살려라"] = "%s is down! Revive them within %s seconds",
	["%s 탈출 성공! (%s)"] = "%s escaped! (%s)",
	["라운드 종료 — %d명 탈출"] = "Round over — %s escaped",
	["%s이(가) 숲지기에게 당했다…"] = "%s was taken by the Warden…",
	["%s이(가) 스스로 일어났다!"] = "%s got back up!",
	["%s이(가) 되살아났다!"] = "%s came back to life!",
	["%s 획득! — %s"] = "Got %s! — %s",
	["%s +1"] = "%s +1",
	["인식표 발견: %s (%d/%d)"] = "Dog tag found: %s (%s/%s)",
	["%s이(가) %s을(를) 떨어뜨렸다"] = "%s dropped %s",
	["괴물이 곰덫에 걸렸다!"] = "The monster is caught in a bear trap!",
	["숲지기가 다시 일어났다…!"] = "The Warden is back on its feet…!",
	["숲지기가 쓰러졌다! %d초 안에 봉인 말뚝을 박아라!"] = "The Warden is down! Drive in the Sealing Stake within %s seconds!",

	-- [E] 표시
	["줍기"] = "Pick up",
	["읽기"] = "Read",
	["숨기"] = "Hide",
	["나오기"] = "Get out",
	["차 밑"] = "Under the car",
	["옷장"] = "Closet",
	["살리기"] = "Revive",
	["퓨즈 넣기"] = "Insert fuse",
	["부품 설치"] = "Install part",
	["시동 걸기"] = "Start engine",
	["안테나 설치"] = "Install antenna",
	["구조 요청"] = "Call for rescue",
	["무전기"] = "Radio",
	-----------------------------------------------------------------------
	-- 상점 / 게임패스 능력
	-----------------------------------------------------------------------
	["상점"] = "Shop",
	["수색대 보급소"] = "Search party supply post",
	["[B] 닫기   ·   소모품은 다음 판을 시작할 때 받아요"] = "[B] Close   ·   Consumables are handed out when your next round starts",
	["소모품은 다음 판을 시작할 때 받아요"] = "Consumables are handed out when your next round starts",
	["전체"] = "All",
	["게임패스"] = "Passes",
	["소모품"] = "Items",
	["게임패스 · 한 번 사면 계속"] = "Game pass · yours forever",
	["소모품 · 살 때마다 1개"] = "Consumable · one per purchase",
	["쓰러졌을 때 구매"] = "Buy when down",
	["추천"] = "Pick",
	["인기"] = "Hot",
	["팀"] = "Team",
	["[B] 마우스로 구매"] = "[B] Use mouse to buy",
	["[B] 닫기"] = "[B] Close",
	["구매"] = "Buy",
	["보유 중"] = "Owned",
	["준비 중"] = "Coming soon",
	["죽었을 때"] = "When down",
	["색: %s"] = "Color: %s",
	["보관 %d개"] = "%d stored",
	["기본"] = "Default",
	["파랑"] = "Blue",
	["초록"] = "Green",
	["보라"] = "Purple",
	["빨강"] = "Red",
	["스타터 키트"] = "Starter Kit",
	["매 판 조명탄 총 + 조명탄 6발 + 손도끼를 들고 시작"] = "Start every round with a flare gun, 6 flares and a hatchet",
	["숲지기 추적기"] = "Warden Tracker",
	["[T] 10초 동안 괴물 위치가 보인다. 삑삑 소리는 괴물도 듣는다"] = "[T] Shows the monster for 10 seconds. It can hear the beeping too",
	["숲지기 변신"] = "Warden Disguise",
	["[G] 한 판에 한 번, 20초 동안 숲지기로 변해 괴물이 공격하지 않는다"] = "[G] Once per round, become a Warden for 20 seconds. The monster will not attack you",
	["손전등 불빛 색"] = "Flashlight Color",
	["손전등 불빛 색을 바꾼다"] = "Change the color of your flashlight beam",
	["부활"] = "Revive",
	["죽거나 쓰러졌을 때 그 자리에서 일어난다 (한 판에 한 번)"] = "Get back up where you fell or died (once per round)",
	["섬광탄 3개"] = "3 Flashbangs",
	["다음 판에 섬광탄 3개를 들고 시작 (한 판에 한 묶음)"] = "Start your next round with 3 flashbangs (one pack per round)",
	["건전지 3개"] = "3 Batteries",
	["다음 판에 건전지 3개를 들고 시작 (한 판에 한 묶음)"] = "Start your next round with 3 batteries (one pack per round)",
	["팀 보급 상자"] = "Team Supply Crate",
	["다음 판에 같이 간 팀원 모두가 붕대와 건전지를 받는다"] = "Next round, everyone on your team gets a bandage and batteries",
	["섬광탄 묶음"] = "flashbang pack",
	["건전지 묶음"] = "battery pack",
	["상점: 섬광탄 %d개를 받았다"] = "Shop: you received %d flashbangs",
	["상점: 건전지 %d개를 받았다"] = "Shop: you received %d batteries",
	["%s의 보급 상자: 붕대 %d개 + 건전지 %d개"] = "%s's supply crate: %d bandage + %d batteries",
	["상점: %s을(를) 보관함에 넣었다. 다음 판을 시작할 때 받는다"] = "Shop: %s stored. You will get it when your next round starts",
	["부활할 수 없는 상황이라 섬광탄 묶음으로 바꿔 드렸어요"] = "You could not be revived right now, so you got a flashbang pack instead",
	["%s 구매 완료!"] = "%s purchased!",
	["추적기 준비됨"] = "Tracker ready",
	["추적기 작동 중 %d초"] = "Tracker active %ds",
	["추적기 충전 중… %d초"] = "Tracker recharging… %ds",
	["숲지기 변신 준비됨"] = "Warden disguise ready",
	["변신: 이번 판에 사용함"] = "Disguise: used this round",
	["숲지기로 변신 중 %d초 — 괴물이 공격하지 않는다"] = "Disguised as a Warden %ds — the monster will not attack",
	["이번 판에는 이미 변신했다"] = "You already used your disguise this round",
	["변신이 풀렸다 — 이제 괴물이 다시 알아본다"] = "The disguise wore off — the monster can recognise you again",
	["숲지기의 가죽을 뒤집어썼다… 괴물이 나를 동족으로 본다"] = "You pull on the Warden's hide… the monster takes you for one of its own",
	["추적"] = "Track",
	["변신"] = "Disguise",

	-----------------------------------------------------------------------
	-- 핸드폰 화면 버튼 (TouchControls)
	-----------------------------------------------------------------------
	["달리기"] = "Sprint",
	["손전등"] = "Light",
	["웅크리기"] = "Crouch",
	["건전지"] = "Battery",
	["목표"] = "Goals",
	["제작"] = "Craft",
	["지도"] = "Map",
	["제작대"] = "Workbench",
	["관전 중: %s"] = "Spectating: %s",
	["▲ 나   ● 동료   초록 = 탈출 장소"] = "▲ You   ● Teammates   Green = escape route",

	-----------------------------------------------------------------------
	-- 숲 속 표지판 / 물건에 적힌 글씨 (Build.text, ItemModels, LobbyBuilder)
	-----------------------------------------------------------------------
	["← 감시탑   주유소 →"] = "← Ranger tower   Gas station →",
	["↑ 정문"] = "↑ Main gate",
	["흑송 벌목장  ↑"] = "Blackpine Logging Camp  ↑",
	["← 벌목지"] = "← Clear-cut",
	["출입 금지"] = "NO ENTRY",
	["흑송 벌목장\n안내도"] = "Blackpine Logging Camp\nMap",
	["흑송 주유소"] = "Blackpine Gas",
	["출 구"] = "EXIT",
	["1998\n10월"] = "1998\nOCT",
	["열쇠"] = "KEYS",
	["⚡ 위험"] = "⚡ DANGER",
	["화약 위험"] = "EXPLOSIVES",
	["연료"] = "FUEL",
	["트럭"] = "TRUCK",
	["흑송"] = "BLACKPINE",

	-- 순위표 칸 이름 (Config.StatLabels)
	["탈출"] = "Escapes",
	["모은 인식표"] = "Dog tags",
}

---------------------------------------------------------------------------
-- 아이템 / 제작법 (ID 로 짝지음)
---------------------------------------------------------------------------
local ITEMS = {
	Scrap = { "Scrap", "Rusty scrap metal" },
	Wood = { "Wood", "Solid firewood" },
	Herb = { "Herb", "A plant for dressing wounds" },
	Gunpowder = { "Gunpowder", "Blasting powder from the camp store" },
	Cloth = { "Cloth", "Can be used as a bandage" },
	Ammo = { "Flare", "Ammo for the flare gun" },
	Cell = { "Battery", "Flashlight battery. Swapped automatically when empty (R: swap early)" },
	Fuse = { "Fuse", "Put it in the generator to open the gate" },
	Battery = { "Car battery", "For the logging truck" },
	FuelCan = { "Fuel can", "For the logging truck" },
	CarKey = { "Truck key", "For the logging truck" },
	Antenna = { "Antenna part", "For repairing the tower radio" },
	Rune = { "Rune shard", "Material for the stake that seals the monster" },
	DogTag = { "Dog tag", "A missing logger's dog tag" },
	FlareGun = { "Flare gun", "Ranged attack. The shot draws the monster" },
	Axe = { "Hatchet", "Melee attack. Needs no ammo" },
	Flashbang = { "Flashbang", "Throw it to stun the monster" },
	Trap = { "Bear trap", "Place on the ground. Holds the monster when it steps in" },
	Medkit = { "Bandage", "Restores health" },
	SealStake = { "Sealing Stake", "Drive it into the downed monster to seal it forever" },
}
for id, pair in ITEMS do
	local def = Items.defs[id]
	if def then
		En[def.name] = pair[1]
		En[def.desc] = pair[2]
	end
end

local RECIPES = {
	Axe = { "Hatchet", "Melee weapon. Quiet" },
	FlareGun = { "Flare gun", "Ranged weapon. The shot draws the monster" },
	Ammo = { "Flares x3", "Ammo for the flare gun" },
	Flashbang = { "Flashbang", "Throw to stun the monster for 5 seconds" },
	Trap = { "Bear trap", "Holds the monster for 6 seconds" },
	Medkit = { "Bandage", "Restores 50 health" },
	SealStake = { "Sealing Stake", "Drive it into the downed monster to seal it forever" },
}
for _, recipe in Recipes.list do
	local pair = RECIPES[recipe.id]
	if pair then
		En[recipe.name] = pair[1]
		En[recipe.desc] = pair[2]
	end
end

---------------------------------------------------------------------------
-- 이야기 (Story.luau 와 같은 순서 / 같은 ID)
---------------------------------------------------------------------------
local INTRO = {
	"Autumn 1998. Blackpine Logging Camp, Gangwon Province.",
	"A week ago, seven loggers vanished. We are the search party sent to find them.",
	"It is raining. A landslide has blocked the road behind us, and the radio is nothing but static.",
	"…The forest is too quiet. Not a single insect.",
	"Find the notes and get out of this valley. Save your light.",
}
for i, line in Story.Intro do
	En[line] = INTRO[i]
end

local ACT_LINES = {
	[2] = "…Bones clatter somewhere far off. It has left its nest.",
	[3] = "The storm is coming. It no longer hides.",
}
for i, line in Story.ActLines do
	En[line] = ACT_LINES[i]
end

local NOTES = {
	Briefing = {
		"Search Party Briefing",
		'Missing: 7 workers of Blackpine Logging Camp.\nLast transmission: "Something came out by the altar."\n\nCamp layout\n- North: electric gate (powered by the generator)\n- Center: logging camp, sawmill, truck\n- Southwest: clear-cut (field of stumps)\n- West: ranger tower, helipad\n- East: old gas station, junkyard\n- Northeast: shrine, old altar (KEEP OUT)\n\n* No spare flashlight batteries. Find them on site.',
	},
	Foreman = {
		"Foreman's Log",
		"Oct 3 - The company told us to cut everything, even the sacred tree by the altar. The elders begged us not to. We had no choice.\n\nOct 5 - Every night, the sound of bones clattering in the woods.\n\nOct 7 - Tried to run in the truck, but someone pulled the battery and the fuel can. I hid the key somewhere in the cabins.\nBattery and fuel should be around the gas station, the sawmill or the junkyard.",
	},
	Mechanic = {
		"Mechanic's Memo",
		"The gate has an electric lock. It needs 3 fuses in the generator to open.\nSpare fuses are scattered around the cabins, the sawmill, the gas station shed and under the tower.\n\n* The gate is old and takes a long time to open.\nThe whole valley will hear the generator the entire time. Be ready.",
	},
	Ranger = {
		"Ranger Radio Log",
		"[Oct 6 23:40] Storm tore the antenna off. Two parts and I can fix it.\n[Oct 7 02:15] No answer from HQ.\n[Oct 7 03:02] Someone is calling my name from under the tower. It is Foreman Park's voice. Foreman Park died yesterday.\n\nThe rescue helicopter can only land on the helipad in the west clearing.\nIt takes a long time to arrive. You have to hold out until then.",
	},
	Sawmill = {
		"Bloodstained Note",
		"Do not shoot. It comes to the sound.\nThe moment Kim fired his shotgun, it came running through the trees.\n\nIt sees light, too. With a flashlight on, it notices you from far away.\nI turned mine off and crouched, and it walked right past me.\n\nI hid in a closet and it just went by. You run out of breath if you stay too long, though.",
	},
	Child = {
		"Crayon Drawing",
		'(A drawing of a tall person with antlers. In front of it, a child with wide-open eyes)\n\n"Mister Warden doesn\'t move when I am looking.\nWhen I close my eyes, he is closer.\n\nHe hates flashes of light. He covers his eyes and stays still."',
	},
	Mimic = {
		"Soaked Notebook",
		'I heard Yeong-sik\'s voice in the clear-cut. "Over here, I hurt my leg."\nI went. Nobody was there. He died three days ago.\n\nIt steals the voices of the dead.\nIf someone calls you in the forest, do not answer. Do not go.\n\nIf you see it standing far away, do not turn your back and run. If you run, it chases.\nKeep your eyes on it, back away slowly, and get behind a tree or a building.',
	},
	Shaman = {
		"Talisman of the Shrine",
		"Beyond this rope lies the Warden's land.\n\nWhile the sacred tree stands, it sleeps.\nWhen the tree is cut, it comes to collect the names of those who cut it, one by one.\n\nTo put it back to sleep, drive a stake carved with three runes into its chest.\nFind the seven names it has taken and return them, and the forest will never wake again.",
	},
	Altar = {
		"Mossy Gravestone",
		"The Warden does not die.\nKnock it down and it rises again.\n\nWhile it is down, drive a stake carved with three runes into its chest.\nThen the forest will sleep once more.\n\nThe runes are scattered near the altar, the shrine and the cairns.",
	},
}
for _, note in Story.Notes do
	local pair = NOTES[note.id]
	if pair then
		En[note.title] = pair[1]
		En[note.body] = pair[2]
	end
end

local LOGGERS = {
	{ "Foreman Park Man-su", "I never should have listened to the company. That tree was not ours to cut." },
	{ "Kim Cheol-ho", "Two shotgun blasts and it did not go down. It got up and came again." },
	{ "Lee Yeong-sik", "I held my breath in the closet. It sniffed at the door, then just left." },
	{ "Choi Dong-gyu", "If a lantern goes out on its own, it is close. My flashlight flickered too. When that happens, look behind you." },
	{ "Jeong Sun-gil", "I hung the truck key on the key hook in the cabin. Somebody, anybody, get away." },
	{ "Han Gi-su", "It just stood far off, watching us. Every time I looked away, it was a little closer." },
	{ "Yun Jae-seok", "Three runes. That is what grandmother said. Drive it in after it falls. She said to gather all our name tags, too." },
}
for i, logger in Story.Loggers do
	local pair = LOGGERS[i]
	if pair then
		En[logger.name] = pair[1]
		En[logger.words] = pair[2]
	end
end

local WHISPERS = {
	"…go back…",
	"…you will stay here too…",
	"…seven… eight…",
	"…watching you…",
	"…turn off the light…",
}
for i, line in Story.Whispers do
	En[line] = WHISPERS[i]
end

local MIMIC = {
	'"…Is someone there? Please, help me…"',
	'"…Are you the search party? Over here, over here…"',
	'"…I hurt my leg… come this way…"',
	'"…So cold… shine your light over here…"',
	'"…Take me with you… don\'t leave me…"',
}
for i, line in Story.Mimic do
	En[line] = MIMIC[i]
end

local ENDINGS = {
	Gate = { "Out Through the Gate", "The electric gate closed behind us. The forest fell silent again… for now." },
	Truck = { "Escape by Truck", "The logging truck tears down the muddy road. In the mirror, an antlered shadow grows smaller and smaller." },
	Radio = { "Rescued", "The helicopter lifts off. In the middle of the forest below, something looks up at us. Two eyes gleam in the rain." },
	Seal = { "The Forest Sealed", "As the stake went in, the Warden sank into the earth like a root. But the names it took still linger in the forest." },
	TrueSeal = { "End of the Long Night", "We laid seven name tags on the altar and drove in the stake. The rain stopped. Birds sing in the forest again. This time, forever." },
	Dead = { "Missing", "The search party never came back either. A few days later, someone reported hearing their voices in the forest." },
	Timeout = { "Dawn", "Morning came, but the forest was not finished. No one knows what became of those who remained." },
}
for id, ending in Story.Endings do
	local pair = ENDINGS[id]
	if pair then
		En[ending.title] = pair[1]
		En[ending.text] = pair[2]
	end
end

return En
