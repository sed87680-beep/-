-- 라스트 러스트 전투/이동 설정
-- 게임 안의 실제 이름과 다르면 여기 값만 바꾸면 됩니다.

local CombatConfig = {}

----------------------------------------------------------------------
-- 아이템 판별
----------------------------------------------------------------------
-- 방패: 속성(Attribute) IsShield = true 이거나 이름에 아래 단어가 들어가면 방패로 봄
CombatConfig.ShieldAttribute = "IsShield"
CombatConfig.ShieldNamePatterns = { "shield", "방패" }

-- 총: 속성 IsGun = true 이거나 이름에 아래 단어가 들어가면 총으로 봄
CombatConfig.GunAttribute = "IsGun"
CombatConfig.GunNamePatterns = { "gun", "rifle", "pistol", "smg", "shotgun", "총" }

----------------------------------------------------------------------
-- 이동속도
----------------------------------------------------------------------
CombatConfig.Speed = {
	AimMultiplier = 0.5, -- 총 조준 중: 50% 감소
	ShieldMultiplier = 0.6, -- 방패 들고 있을 때: 40% 감소

	-- 조준 + 방패 동시: "min" = 더 많이 줄어드는 쪽(50%)만 적용, "multiply" = 곱함(0.5 x 0.6 = 70% 감소)
	StackMode = "min",

	-- 조준 입력 (총을 든 상태에서 누르고 있는 동안 조준)
	AimInputs = { Enum.UserInputType.MouseButton2 },
	-- 다른 스크립트가 캐릭터에 Aiming 속성을 true로 넣어도 조준으로 처리
	AimAttribute = "Aiming",

	-- 게임에 달리기 기능이 없을 때만 true로 켜세요 (Shift 누르면 달리기)
	EnableSprint = false,
	SprintKey = Enum.KeyCode.LeftShift,
	SprintMultiplier = 1.6,
}

----------------------------------------------------------------------
-- 방패 자세 / 걷기·뛰기 팔 움직임
----------------------------------------------------------------------
CombatConfig.Pose = {
	-- 자세 기준 모델이 들어있는 폴더 (ReplicatedStorage 또는 Workspace 안)
	FolderName = "PoseModels",

	-- 상태별 기준 모델 이름. Run 모델이 없으면 Idle 자세를 조금 숙인 자세로 뜁니다.
	Stances = {
		ShieldOnly = { Idle = "ShieldOnly", Run = "ShieldOnly_Run" },
		ShieldAndWeapon = { Idle = "ShieldAndWeapon", Run = "ShieldAndWeapon_Run" },
	},

	-- 자세를 덮어쓸 관절 (다리는 그대로 걷기 애니메이션 사용)
	Joints = {
		-- R15
		"RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist",
		-- R6
		"Right Shoulder", "Left Shoulder",
	},

	-- 수평 속도(studs/s) 기준
	MoveThreshold = 0.5, -- 이보다 빠르면 걷는 중
	-- 이보다 빠르면 뛰는 중. 기본 걷기 16 x 방패 0.6 = 9.6 이라서 그보다 조금 높게 잡음
	RunThreshold = 11.5,

	-- 걸을 때: 손이 조금씩 흔들림
	WalkSwayDegrees = 4,
	WalkSwayHz = 1.6,
	-- 뛸 때: 더 크고 빠르게 + 뛰기 자세로 바뀜
	RunSwayDegrees = 10,
	RunSwayHz = 2.8,
	-- Run 모델이 없을 때 뛰기 자세 = Idle 자세에서 팔을 이만큼 앞으로 숙임
	RunFallbackPitchDegrees = -15,

	BlendSpeed = 10, -- 자세 전환 부드러움 (클수록 빠름)
}

----------------------------------------------------------------------
-- 사격 더미
----------------------------------------------------------------------
CombatConfig.Dummy = {
	-- 더미 찾기: 이 태그가 붙은 모델 또는 Workspace.ShootingDummies 폴더 안 모델
	Tag = "ShootingDummy",
	FolderName = "ShootingDummies",

	-- 전용공간: 이 태그가 붙은 Part 또는 Workspace 안 이 이름의 Part (여러 개 가능)
	ZoneTag = "ShootingRange",
	ZoneName = "ShootingRange",

	-- 더미 안에 이 이름의 Part/Attachment가 있으면 거기서 그 앞방향으로 발사, 없으면 모델 정면
	MuzzleName = "Muzzle",

	FireInterval = 1.5, -- 초
	BulletSpeed = 80, -- studs/s
	BulletDamage = 10,
	BulletMaxLifetime = 5, -- 초
	BulletSize = Vector3.new(0.3, 0.3, 1.2),
	BulletColor = Color3.fromRGB(255, 200, 60),

	ShieldBlocks = true, -- 방패에 맞으면 데미지 없이 막힘
}

return CombatConfig
