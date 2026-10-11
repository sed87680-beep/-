# 라스트 러스트: 사격 더미, 방패 자세, 이동속도

## 기능
- **사격 더미**: 전용공간 안에 있는 더미만 쏘고, 그 공간에 플레이어가 있을 때만 쏴요. 플레이어를 따라 조준하지 않고 더미 정면으로 일직선으로만 쏘고, 총알은 공간 밖으로 나가면 사라져요. 방패에 맞으면 막혀요.
- **방패 자세**: 방패만 들면 `ShieldOnly` 모델과 같은 팔 자세가 되고, 방패와 무기를 같이 들면 `ShieldAndWeapon` 모델과 같은 자세가 돼요.
- **걷기/뛰기**: 걸을 때는 손이 조금씩 흔들리고, 뛸 때는 뛰기 자세로 바뀌면서 더 크게 흔들려요.
- **이동속도**: 총을 조준하는 동안(우클릭) 50% 느려지고, 방패를 들고 있으면 40% 느려져요.

## Roblox Studio에 넣는 위치

| 파일 | 넣을 곳 | 종류 |
|---|---|---|
| `src/ReplicatedStorage/CombatConfig.lua` | ReplicatedStorage | ModuleScript (이름: `CombatConfig`) |
| `src/ReplicatedStorage/StanceUtil.lua` | ReplicatedStorage | ModuleScript (이름: `StanceUtil`) |
| `src/ServerScriptService/ShootingDummy.server.lua` | ServerScriptService | Script |
| `src/StarterPlayer/StarterPlayerScripts/StancePoseController.client.lua` | StarterPlayer > StarterPlayerScripts | LocalScript |
| `src/StarterPlayer/StarterCharacterScripts/MoveSpeedController.client.lua` | StarterPlayer > StarterCharacterScripts | LocalScript |

Rojo를 쓰면 이 폴더에서 `rojo serve`를 실행하면 돼요.

## Studio에서 맞춰야 할 것
1. **전용공간**: 사격장 영역을 덮는 Part를 하나 만들고 이름을 `ShootingRange`로 지어요. Anchored, CanCollide 끄기, Transparency 1로 두면 돼요.
2. **사격 더미**: 더미 모델을 Workspace 안 `ShootingDummies` 폴더에 넣거나, `ShootingDummy` 태그를 붙여요. 총구 위치를 정하려면 더미 안에 `Muzzle`이라는 Part나 Attachment를 넣어요. 그 앞방향으로 쏴요. 더미에 원래 있던 사격 스크립트는 꺼야 해요.
3. **자세 기준 모델**: ReplicatedStorage에 `PoseModels` 폴더를 만들고, 원래 있던 모델 이름을 바꿔서 넣어요.
   - 방패 든 모습 모델 → `ShieldOnly`
   - 방패랑 무기 든 모습 모델 → `ShieldAndWeapon`
   - (선택) 뛸 때 자세 모델 → `ShieldOnly_Run`, `ShieldAndWeapon_Run`. 없으면 기본 자세에서 팔을 조금 숙여서 뛰어요.
   - 기준 모델은 플레이어와 같은 리그(R15 또는 R6)여야 해요.
4. **방패/총 이름**: 이름에 `Shield`나 `방패`가 들어가면 방패, `Gun`/`Rifle`/`Pistol`/`총`이 들어가면 총으로 인식해요. 이름이 다르면 Tool에 속성 `IsShield` 또는 `IsGun`을 `true`로 추가하거나 `CombatConfig`의 이름 목록을 고치면 돼요.
5. **달리기**: 게임에 달리기 기능이 없으면 `CombatConfig.Speed.EnableSprint = true`로 켜세요(Shift).

숫자(속도 배율, 흔들림 크기, 연사 속도, 데미지 등)는 전부 `CombatConfig`에서 바꿀 수 있어요.
