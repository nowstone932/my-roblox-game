-- 게임의 모든 소리와 배경음악(BGM)을 여기서 관리합니다.
--
-- ▶ 소리를 넣는 방법 (자세한 건 docs/소리_넣기.md)
--   1. Roblox Studio → 보기(View) → 도구 상자(Toolbox) → "오디오(Audio)" 탭
--      (또는 웹의 Creator Hub → Creator Store → Audio)
--   2. 원하는 소리를 찾아서 재생해보고, 마음에 들면 우클릭 → "에셋 ID 복사(Copy Asset ID)"
--   3. 아래 표에서 알맞은 줄을 찾아 id = 0 의 0 자리에 그 숫자를 붙여넣고 저장
--
-- ▶ 칸 설명
--   id      : 소리 번호. 0이면 그 소리는 그냥 안 남 (에러 없음)
--             "rbxasset://..." 로 시작하는 건 로블록스에 기본으로 들어있는 임시 소리예요.
--   volume  : 크기 (0 ~ 2 정도. 1이 보통)
--   pitch   : 높낮이/빠르기 (1이 원래 소리, 0.5면 낮고 느리게, 1.5면 높고 빠르게)
--   looped  : true면 계속 반복 (배경음, BGM)
--   range   : 3D 소리일 때 들리는 최대 거리(스터드). 이 값이 있으면 "그 위치에서" 소리가 남
--   music   : true면 "음악" 그룹 (설정에서 음악 볼륨만 따로 줄일 수 있게)
--
-- 소리를 못 불러오면 게임은 멈추지 않고 그 소리만 조용히 빠집니다.
-- 대신 플레이 시작할 때 출력(Output) 창에 "불러오지 못한 소리" 목록이 한 번 나와요.

export type SoundDef = {
	id: number | string,
	volume: number?,
	pitch: number?,
	looped: boolean?,
	range: number?,
	music: boolean?,
}

local SoundList = {}

-- 전체 볼륨 (0 ~ 1)
SoundList.MasterVolume = {
	Music = 0.8, -- 배경음악/배경음
	Effects = 1, -- 효과음
}

SoundList.Sounds = {
	-------------------------------------------------------------------------
	-- 배경음악 / 배경음 (반복)
	-------------------------------------------------------------------------
	LobbyMusic = { id = 0, volume = 0.35, looped = true, music = true }, -- 대기 시간 음악 (잔잔하고 불길한 피아노 등)
	ForestAmbience = { id = 0, volume = 0.5, looped = true, music = true }, -- 숲 배경음: 바람, 귀뚜라미, 부엉이
	TensionMusic = { id = 0, volume = 0.6, looped = true, music = true }, -- 긴장 음악: 괴물이 가까울수록 커짐 (낮은 드론음)
	ChaseMusic = { id = 0, volume = 0.7, looped = true, music = true }, -- 추격 음악: 괴물이 쫓아올 때 (빠른 북소리/현악)
	Heartbeat = { id = 0, volume = 1, looped = true }, -- 심장 소리: 괴물이 가깝거나 체력이 낮을 때

	-------------------------------------------------------------------------
	-- 괴물 (3D: 괴물 위치에서 들림 → 소리로 방향을 알 수 있음)
	-------------------------------------------------------------------------
	MonsterBreath = { id = 0, volume = 0.8, looped = true, range = 60 }, -- 괴물 숨소리 (반복, 몸에 붙어서 따라다님)
	MonsterGrowl = { id = 0, volume = 1, range = 90 }, -- 가끔 내는 낮은 으르렁 소리
	MonsterScream = { id = 0, volume = 1.2, range = 300 }, -- 플레이어 발견 시 비명/포효
	MonsterFootstep = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 1.5, pitch = 0.45, range = 70 }, -- 무거운 발소리 (임시: 기본 발소리를 낮게)
	MonsterHurt = { id = 0, volume = 1, range = 120 }, -- 괴물이 맞았을 때
	MonsterVanish = { id = 0, volume = 0.9, range = 80 }, -- 연기 속으로 사라질 때 (휙~ 바람 소리)
	MonsterSealed = { id = 0, volume = 1.2, range = 300 }, -- 봉인 성공 (마법/폭발음)

	-------------------------------------------------------------------------
	-- 플레이어 행동
	-------------------------------------------------------------------------
	Pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.3 }, -- 재료 줍기 (임시: 기본 딩 소리)
	QuestPickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.8 }, -- 탈출 부품 줍기 (임시)
	NoteOpen = { id = 0, volume = 0.6 }, -- 쪽지 읽기 (종이 바스락)
	Craft = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6 }, -- 제작 완료 (임시: 칼 뽑는 소리)
	FlareGun = { id = 0, volume = 1, range = 250 }, -- 조명탄 총 발사
	AxeSwing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.8, pitch = 0.8, range = 60 }, -- 도끼 휘두르기 (임시: 칼 휘두르는 소리)
	Flashbang = { id = 0, volume = 1.2, range = 200 }, -- 섬광탄 폭발
	TrapSet = { id = 0, volume = 0.8, range = 40 }, -- 곰덫 설치 (철컥)
	TrapSnap = { id = 0, volume = 1.2, range = 150 }, -- 곰덫이 괴물을 물었을 때 (쾅!)
	Heal = { id = 0, volume = 0.7 }, -- 구급상자/부활
	PlayerHurt = { id = 0, volume = 1 }, -- 괴물에게 맞음
	Downed = { id = 0, volume = 0.9 }, -- 쓰러짐
	ClosetDoor = { id = 0, volume = 0.9, range = 50 }, -- 옷장 문 여닫기 (끼익)

	-------------------------------------------------------------------------
	-- 탈출 장치
	-------------------------------------------------------------------------
	Install = { id = 0, volume = 0.9, range = 60 }, -- 퓨즈/부품/안테나 끼우기 (철컥)
	Generator = { id = 0, volume = 1, range = 200 }, -- 발전기 가동 (부르릉)
	GateOpen = { id = 0, volume = 1, range = 200 }, -- 철문 올라가는 소리
	TruckEngine = { id = 0, volume = 1, looped = true, range = 250 }, -- 트럭 엔진 (시동 후 반복)
	RadioCall = { id = 0, volume = 0.9, range = 80 }, -- 무전기 지직거림
	Helicopter = { id = 0, volume = 1, looped = true, range = 400 }, -- 헬기 프로펠러 (반복)

	-------------------------------------------------------------------------
	-- 공포 이벤트
	-------------------------------------------------------------------------
	Whisper = { id = 0, volume = 0.8 }, -- 환청 속삭임
	TwigSnap = { id = 0, volume = 1, range = 40 }, -- 등 뒤에서 나뭇가지 부러짐
	Blackout = { id = 0, volume = 0.8 }, -- 정전 (전기 꺼지는 소리)
	Stinger = { id = 0, volume = 0.9 }, -- 깜짝 효과음 (유령이 보일 때)

	-------------------------------------------------------------------------
	-- 라운드 / 엔딩
	-------------------------------------------------------------------------
	RoundStart = { id = 0, volume = 0.8, music = true }, -- 라운드 시작 (낮은 종소리 등)
	Victory = { id = 0, volume = 0.9, music = true }, -- 탈출 성공 짧은 음악
	Defeat = { id = 0, volume = 0.9, music = true }, -- 사망/시간 초과 짧은 음악
}

-- id 칸 값을 실제 SoundId 문자열로 바꿔줌. 비어 있으면 nil
function SoundList.toSoundId(id: any): string?
	if typeof(id) == "number" and id > 0 then
		return "rbxassetid://" .. math.floor(id)
	elseif typeof(id) == "string" and id ~= "" then
		if id:match("^%d+$") then
			return "rbxassetid://" .. id
		end
		return id
	end
	return nil
end

return SoundList
