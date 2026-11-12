# 어두운 숲 탈출 (Dark Forest Escape)

어두운 숲에서 괴물을 피해 탈출하는 로블록스 1인칭 공포 게임입니다.
재료를 모아 무기와 아이템을 만들고, 괴물을 기절시키거나 쓰러뜨리며 탈출하세요.

👉 **처음이라면 [docs/시작하기.md](docs/시작하기.md) 부터 보세요.** (Rojo 설치 → Studio 연결 → 플레이)

## 게임 흐름

1. 대기 시간 후 라운드 시작, 모두 숲 남쪽에서 출발
2. 숲에 흩어진 재료(고철, 나무, 약초, 화약, 퓨즈)를 줍기
3. 재료로 **조명탄 총 / 탄약 / 섬광탄 / 붕대** 제작
4. 괴물은 보이거나 가까우면 추격 → 섬광탄으로 기절, 총으로 쓰러뜨리기 (잠시 후 부활)
5. 퓨즈 3개를 퓨즈 박스에 넣으면 북쪽 탈출문이 열림 → 통과하면 탈출 성공

## 폴더 구조

```
default.project.json        Rojo 설정 (어떤 폴더가 Studio 어디로 가는지)
src/
  shared/                   → ReplicatedStorage.Shared (서버/클라 공용)
    Config.luau             밸런스 숫자, 수익화 ID ← 가장 자주 고칠 파일
    Recipes.luau            제작법
    Remotes.luau            서버 ↔ 클라 통신
  server/                   → ServerScriptService.Server
    Main.server.luau        서버 시작점
    Services/
      MapBuilder.luau       어두운 숲 맵 자동 생성 + 조명
      MaterialSpawner.luau  재료 뿌리기 / 줍기
      MonsterAI.luau        괴물 AI (배회, 추격, 기절, 부활)
      Combat.luau           제작, 총 발사, 아이템 사용 (서버 판정)
      GameLoop.luau         라운드 진행, 퓨즈/탈출문, 탈출 판정
      Monetization.luau     게임패스 / 개발자 상품
      Inventory.luau        인벤토리 (플레이어 Attribute)
  client/                   → StarterPlayerScripts.Client
    Main.client.luau        입력, 손전등, 효과
    Hud.luau                화면 UI
```

## 다음에 해볼 만한 것

- 괴물 소리, 발소리, 배경음 (Creator Store에서 사운드 ID 가져오기)
- 실제 괴물 모델/애니메이션으로 교체
- DataStore로 탈출 기록·구매 기록 저장
- Studio에서 맵 직접 꾸미기 (오두막, 길, 안개 낀 호수 등)
