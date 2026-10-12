-- 이동속도: 총 들고 우클릭(조준) 50% 감소, 방패 들고 우클릭 40% 감소
-- 다른 스크립트(달리기 등)가 WalkSpeed를 바꾸면 그 값을 기본 속도로 삼고 배율만 곱합니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local StanceUtil = require(ReplicatedStorage:WaitForChild("StanceUtil"))
local SpeedConfig = Config.Speed

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local baseSpeed = humanoid.WalkSpeed
local appliedSpeed = baseSpeed
local aimHeld = false
local sprintHeld = false

local aimInputs = {}
for _, inputType in ipairs(SpeedConfig.AimInputs) do
	aimInputs[inputType] = true
end

humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
	-- 우리가 넣은 값이 아니면 다른 스크립트가 바꾼 것 → 새 기본 속도
	if math.abs(humanoid.WalkSpeed - appliedSpeed) > 1e-3 then
		baseSpeed = humanoid.WalkSpeed
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if aimInputs[input.UserInputType] or aimInputs[input.KeyCode] then
		aimHeld = true
	elseif input.KeyCode == SpeedConfig.SprintKey and not gameProcessed then
		sprintHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if aimInputs[input.UserInputType] or aimInputs[input.KeyCode] then
		aimHeld = false
	elseif input.KeyCode == SpeedConfig.SprintKey then
		sprintHeld = false
	end
end)

local function isAiming()
	if character:GetAttribute(SpeedConfig.AimAttribute) == true then
		return true
	end
	return aimHeld and StanceUtil.isHoldingGun(character)
end

local function isRaisingShield()
	return aimHeld and StanceUtil.hasShield(character)
end

local function getMultiplier()
	local aimMult = isAiming() and SpeedConfig.AimMultiplier or 1
	local shieldMult = isRaisingShield() and SpeedConfig.ShieldMultiplier or 1
	if SpeedConfig.StackMode == "multiply" then
		return aimMult * shieldMult
	end
	return math.min(aimMult, shieldMult)
end

local connection
connection = RunService.Heartbeat:Connect(function()
	if not humanoid.Parent or humanoid.Health <= 0 then
		connection:Disconnect()
		return
	end

	local speed = baseSpeed * getMultiplier()
	if SpeedConfig.EnableSprint and sprintHeld then
		speed *= SpeedConfig.SprintMultiplier
	end

	if math.abs(humanoid.WalkSpeed - speed) > 1e-3 then
		appliedSpeed = speed
		humanoid.WalkSpeed = speed
	end
end)
