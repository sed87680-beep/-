-- 방패 자세 + 걷기/뛰기 팔 움직임
--  - 방패만 들면: PoseModels.ShieldOnly 모델과 같은 팔 자세
--  - 방패 + 무기: PoseModels.ShieldAndWeapon 모델과 같은 팔 자세
--  - 걸을 때는 손이 조금씩 흔들리고, 뛸 때는 뛰기 자세(_Run 모델)로 바뀌며 크게 흔들림
-- 모든 플레이어 캐릭터에 적용하므로 다른 사람 자세도 똑같이 보입니다.
-- 공격(몽둥이 휘두르기 등) 애니메이션이 재생되는 동안은 잠깐 꺼져서 원래 모션이 보입니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local StanceUtil = require(ReplicatedStorage:WaitForChild("StanceUtil"))
local PoseConfig = Config.Pose

local RESCAN_INTERVAL = 1

local jointNames = {}
for _, name in ipairs(PoseConfig.Joints) do
	jointNames[name] = true
end

local runFallback = CFrame.Angles(math.rad(PoseConfig.RunFallbackPitchDegrees), 0, 0)

-- 기준 모델의 몸 부위 (이름 → Part)
local poseParts = {}

local function getPoseParts(modelName)
	if not modelName then
		return nil
	end
	local cached = poseParts[modelName]
	if cached and cached.model.Parent then
		return cached.parts
	end

	local folder = ReplicatedStorage:FindFirstChild(PoseConfig.FolderName)
		or workspace:FindFirstChild(PoseConfig.FolderName)
	local model = folder and folder:FindFirstChild(modelName)
	if not model then
		return nil
	end

	local parts = {}
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	poseParts[modelName] = { model = model, parts = parts }
	return parts
end

-- 기준 모델에서 Part0 → Part1 상대 위치를 그대로 재현하는 Motor6D.Transform (회전만)
local function poseTransform(motor, parts)
	if not parts then
		return nil
	end
	local p0, p1 = motor.Part0, motor.Part1
	if not (p0 and p1) then
		return nil
	end
	local ref0, ref1 = parts[p0.Name], parts[p1.Name]
	if not (ref0 and ref1) then
		return nil
	end
	local rel = ref0.CFrame:ToObjectSpace(ref1.CFrame)
	return (motor.C0:Inverse() * rel * motor.C1).Rotation
end

local actionPriorities = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}

-- 게임 자체 공격/막기 애니메이션이 재생 중인지
local function isPlayingActionAnimation(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if actionPriorities[track.Priority] and track.WeightCurrent > 0.05 then
			return true
		end
	end
	return false
end

local states = setmetatable({}, { __mode = "k" })

local function getState(character)
	local state = states[character]
	if not state then
		state = {
			motors = {},
			nextScan = 0,
			stance = nil,
			weight = 0,
			moveWeight = 0,
			runWeight = 0,
			phase = 0,
			smoothed = {},
		}
		states[character] = state
	end
	local now = os.clock()
	if now >= state.nextScan then
		state.nextScan = now + RESCAN_INTERVAL
		table.clear(state.motors)
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Motor6D") and jointNames[d.Name] then
				table.insert(state.motors, d)
			end
		end
	end
	return state
end

local function approach(current, target, alpha)
	return current + (target - current) * alpha
end

local function updateCharacter(character, dt, alpha)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 then
		return
	end

	local state = getState(character)
	local stance = StanceUtil.getStance(character)
	if stance then
		state.stance = stance
	end
	local yielding = PoseConfig.YieldToActionAnimations and isPlayingActionAnimation(humanoid)
	-- 공격 모션은 바로 보여야 하므로 꺼질 때는 더 빠르게
	state.weight = approach(state.weight, (stance and not yielding) and 1 or 0, yielding and math.min(1, alpha * 3) or alpha)
	if state.weight < 0.01 then
		state.weight = 0
		table.clear(state.smoothed)
		return
	end

	local stanceModels = PoseConfig.Stances[state.stance]
	if not stanceModels then
		return
	end
	local idleParts = getPoseParts(stanceModels.Idle)
	local runParts = getPoseParts(stanceModels.Run)

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = speed > PoseConfig.MoveThreshold
	local running = speed > PoseConfig.RunThreshold
	state.moveWeight = approach(state.moveWeight, moving and 1 or 0, alpha)
	state.runWeight = approach(state.runWeight, running and 1 or 0, alpha)

	local hz = approach(PoseConfig.WalkSwayHz, PoseConfig.RunSwayHz, state.runWeight)
	state.phase = (state.phase + dt * hz * 2 * math.pi) % (2 * math.pi)
	local swayDegrees = approach(PoseConfig.WalkSwayDegrees, PoseConfig.RunSwayDegrees, state.runWeight)
		* state.moveWeight
	local swayWave = math.sin(state.phase) * swayDegrees

	for _, motor in ipairs(state.motors) do
		local idle = poseTransform(motor, idleParts)
		if idle then
			local run = poseTransform(motor, runParts) or idle * runFallback
			local target = idle:Lerp(run, state.runWeight)

			-- 자세 바뀔 때 툭 끊기지 않도록 부드럽게
			local previous = state.smoothed[motor]
			local smoothed = previous and previous:Lerp(target, alpha) or target
			state.smoothed[motor] = smoothed

			-- 왼팔/오른팔 반대로, 팔꿈치·손목은 절반만 흔들림
			local side = string.find(motor.Name, "Left") and -1 or 1
			local scale = string.find(motor.Name, "Shoulder") and 1 or 0.5
			local sway = CFrame.Angles(math.rad(swayWave * side * scale), 0, 0)

			-- 애니메이션이 넣은 값 위에 덮어쓰기 (weight로 자연스럽게 섞음)
			motor.Transform = motor.Transform:Lerp(smoothed * sway, state.weight)
		end
	end
end

-- Stepped는 애니메이션이 Transform을 갱신한 뒤에 실행되므로 여기서 덮어씀
RunService.Stepped:Connect(function(_, dt)
	local alpha = 1 - math.exp(-dt * PoseConfig.BlendSpeed)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			updateCharacter(character, dt, alpha)
		end
	end
end)
