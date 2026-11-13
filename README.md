# 어두운 숲 탈출 (Dark Forest Escape)

어두운 숲에서 괴물을 피해 탈출하는 로블록스 1인칭 공포 게임입니다.
재료를 모아 무기와 아이템을 만들고, 괴물을 기절시키거나 쓰러뜨리며 탈출하세요.

👉 **처음이라면 [docs/시작하기.md](docs/시작하기.md) 부터 보세요.** (Rojo 설치 → Studio 연결 → 플레이)

## 게임 흐름

1998년, 사라진 벌목꾼들을 찾으러 흑송 벌목장에 온 수색대. 숲에는 사슴 두개골 얼굴의 "숲지기"가 있다.

0. **대기실**에서 방(4개, 방마다 최대 5명)에 들어가면 30초 카운트다운 → 그 방 사람들끼리 숲으로 출발
1. 숲에서 재료와 탈출 부품을 모으고, 쪽지로 단서를 얻는다
2. 제작대(C)에서 손도끼, 조명탄 총, 섬광탄, 곰덫, 붕대, 봉인 말뚝을 만든다 → 핫바에 실제 도구로 들어옴
3. 숲지기를 피하거나(나무 뒤, 옷장), 기절시키거나(섬광탄, 덫), 싸운다(도끼, 총)
4. 4가지 방법 중 하나로 탈출: **정문**(퓨즈) / **트럭**(배터리+연료+열쇠) / **무전 구조**(안테나) / **봉인**(룬 3개로 말뚝 → 쓰러진 괴물에게)

## 폴더 구조

```
default.project.json        Rojo 설정 (어떤 폴더가 Studio 어디로 가는지)
src/
  shared/                   → ReplicatedStorage.Shared (서버/클라 공용)
    Config.luau             밸런스 숫자, 수익화 ID ← 가장 자주 고칠 파일
    SoundList.luau          소리 · 배경음악 ID 목록 (docs/소리_넣기.md)
    Story.luau              스토리, 쪽지 내용, 엔딩, 탈출 부품 위치 후보
    Items.luau              아이템 이름/색/설명
    Recipes.luau            제작법
    Remotes.luau            서버 ↔ 클라 통신
  server/                   → ServerScriptService.Server
    Main.server.luau        서버 시작점
    Services/
      Build.luau            소품 만들기 (나무, 오두막, 트럭, 옷장 …)
      MapBuilder.luau       흑송 벌목장 맵 배치 + 조명
      LobbyBuilder.luau     대기실 건물 + 방 4개 + 전광판
      Lobby.luau            대기실 방 입장/퇴장, 카운트다운, 출발 (순간이동)
      Pickups.luau          재료 / 탈출 부품 / 쪽지
      Tools.luau            제작한 도구를 핫바에 실제 Tool로 넣기
      Combat.luau           제작, 도구 사용 (서버 판정)
      MonsterAI.luau        숲지기 모델 + AI (배회, 소리 조사, 추격, 기절, 쓰러짐, 봉인)
      Hiding.luau           옷장 숨기
      Objectives.luau       정문 / 트럭 / 무전 / 봉인 탈출 장치
      GameLoop.luau         라운드 진행, 탈출 처리, 엔딩
      Monetization.luau     게임패스 / 개발자 상품
      Inventory.luau        인벤토리 (플레이어 Attribute)
      Sfx.luau              서버에서 효과음 요청
  client/                   → StarterPlayerScripts.Client
    Main.client.luau        입력, 손전등, 달리기, 효과
    Hud.luau                목표 패널, 가방, 제작대, 쪽지, 인트로/엔딩
    MonsterAnimator.luau    괴물 걷기/팔 뻗기/고개 꺾기 연출
    Audio.luau              소리 재생, 긴장/추격 BGM 연출, 괴물 3D 소리
```

## 다음에 해볼 만한 것

- `src/shared/SoundList.luau` 에 소리 ID 채우기 (docs/소리_넣기.md)
- Blender 등으로 만든 괴물 메시로 교체
- DataStore로 탈출 기록·구매 기록 저장
- Studio에서 맵 직접 꾸미기 (오두막, 길, 안개 낀 호수 등)
