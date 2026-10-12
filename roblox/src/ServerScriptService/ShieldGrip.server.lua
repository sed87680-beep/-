-- 방패 위치 맞추기
-- Roblox는 Tool을 무조건 오른손(RightGrip)에 붙이기 때문에, 방패 Tool을 들면
-- 기준 모델(PoseModels.ShieldOnly)에서 방패가 붙어 있는 몸 부위·위치로 옮겨 붙입니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local StanceUtil = require(ReplicatedStorage:WaitForChild("StanceUtil"))
local PoseConfig = Config.Pose

local GRIP_WAIT_TIMEOUT = 2

local function findReferenceModel()
	local folder = ReplicatedStorage:FindFirstChild(PoseConfig.FolderName)
		or workspace:FindFirstChild(PoseConfig.FolderName)
	local stance = PoseConfig.Stances.ShieldOnly
	return folder and stance and folder:FindFirstChild(stance.Idle)
end

local function getHandle(shield)
	if shield:IsA("BasePart") then
		return shield
	end
	return shield:FindFirstChild("Handle") or shield:FindFirstChildWhichIsA("BasePart", true)
end

-- 기준 모델에서 방패가 붙은 몸 부위 이름과, 그 부위 기준 방패 손잡이 위치
local function getReferenceOffset()
	local model = findReferenceModel()
	if not model then
		return nil
	end

	local refHandle
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("Tool") or d:IsA("Accessory") or d:IsA("Model") or d:IsA("BasePart")) and StanceUtil.isShield(d) then
			refHandle = getHandle(d)
			if refHandle then
				break
			end
		end
	end
	if not refHandle then
		warn("[ShieldGrip] 기준 모델 " .. model.Name .. " 안에서 방패를 못 찾았어요")
		return nil
	end

	local bestPart, bestDistance
	for _, name in ipairs(PoseConfig.ShieldBodyParts) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local distance = (part.Position - refHandle.Position).Magnitude
			if not bestDistance or distance < bestDistance then
				bestPart, bestDistance = part, distance
			end
		end
	end
	if not bestPart then
		return nil
	end
	return bestPart.Name, bestPart.CFrame:ToObjectSpace(refHandle.CFrame)
end

local function findGrip(character, handle)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Weld") and d.Name == "RightGrip" and d.Part1 == handle then
			return d
		end
	end
	return nil
end

local function onToolEquipped(character, tool)
	if not (PoseConfig.AttachShieldLikeReference and StanceUtil.isShield(tool)) then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		return
	end

	local bodyPartName, offset = getReferenceOffset()
	if not bodyPartName then
		return
	end
	local bodyPart = character:FindFirstChild(bodyPartName)
	if not bodyPart then
		return
	end

	-- RightGrip은 장착 직후에 생기므로 잠깐 기다림
	local grip
	local deadline = os.clock() + GRIP_WAIT_TIMEOUT
	repeat
		grip = findGrip(character, handle)
		if not grip then
			task.wait()
		end
	until grip or os.clock() > deadline or tool.Parent ~= character
	if not grip then
		return
	end

	grip.Part0 = bodyPart
	grip.C0 = offset
	grip.C1 = CFrame.identity
end

local function onCharacter(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(character, child)
		end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
