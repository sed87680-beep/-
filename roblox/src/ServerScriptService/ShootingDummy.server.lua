-- 사격 더미
--  - 전용공간(ShootingRange Part) 안에 있는 더미만 쏨
--  - 같은 전용공간 안에 플레이어가 있을 때만 쏨
--  - 플레이어를 따라 조준하지 않고, 더미 정면으로 일직선(수평)으로만 쏨
--  - 총알이 전용공간 밖으로 나가면 사라짐

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local StanceUtil = require(ReplicatedStorage:WaitForChild("StanceUtil"))
local DummyConfig = Config.Dummy

local bulletFolder = Instance.new("Folder")
bulletFolder.Name = "DummyBullets"
bulletFolder.Parent = workspace

local function getZones()
	local zones = {}
	for _, zone in ipairs(CollectionService:GetTagged(DummyConfig.ZoneTag)) do
		if zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == DummyConfig.ZoneName and d:IsA("BasePart") and not table.find(zones, d) then
			table.insert(zones, d)
		end
	end
	return zones
end

local function getDummies()
	local dummies = {}
	for _, dummy in ipairs(CollectionService:GetTagged(DummyConfig.Tag)) do
		if dummy:IsA("Model") then
			table.insert(dummies, dummy)
		end
	end
	local folder = workspace:FindFirstChild(DummyConfig.FolderName)
	if folder then
		for _, dummy in ipairs(folder:GetChildren()) do
			if dummy:IsA("Model") and not table.find(dummies, dummy) then
				table.insert(dummies, dummy)
			end
		end
	end
	return dummies
end

local function isInZone(zone, position)
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function findZone(zones, position)
	for _, zone in ipairs(zones) do
		if isInZone(zone, position) then
			return zone
		end
	end
	return nil
end

local function playerInZone(zone)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and isInZone(zone, root.Position) then
			return true
		end
	end
	return false
end

-- 발사 위치와 수평 정면 방향
local function getMuzzle(dummy)
	local muzzle = dummy:FindFirstChild(DummyConfig.MuzzleName, true)
	local cf
	if muzzle and muzzle:IsA("Attachment") then
		cf = muzzle.WorldCFrame
	elseif muzzle and muzzle:IsA("BasePart") then
		cf = muzzle.CFrame
	else
		cf = dummy:GetPivot()
	end
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return cf.Position, look.Unit
end

local bullets = {}

local function fire(dummy, zone)
	local origin, direction = getMuzzle(dummy)

	local part = Instance.new("Part")
	part.Name = "DummyBullet"
	part.Size = DummyConfig.BulletSize
	part.Color = DummyConfig.BulletColor
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(origin, origin + direction)
	part.Parent = bulletFolder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { dummy, bulletFolder, zone }

	table.insert(bullets, {
		part = part,
		position = origin,
		direction = direction,
		zone = zone,
		params = params,
		age = 0,
	})
end

local function onHit(result)
	local hitPart = result.Instance
	if DummyConfig.ShieldBlocks and StanceUtil.isShieldPart(hitPart) then
		return
	end
	local model = hitPart:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(DummyConfig.BulletDamage)
	end
end

RunService.Heartbeat:Connect(function(dt)
	for i = #bullets, 1, -1 do
		local bullet = bullets[i]
		bullet.age += dt
		local step = bullet.direction * DummyConfig.BulletSpeed * dt
		local result = workspace:Raycast(bullet.position, step, bullet.params)

		local done = false
		if result then
			onHit(result)
			done = true
		else
			bullet.position += step
			bullet.part.CFrame = CFrame.lookAt(bullet.position, bullet.position + bullet.direction)
			done = bullet.age >= DummyConfig.BulletMaxLifetime
				or not bullet.zone.Parent
				or not isInZone(bullet.zone, bullet.position)
		end

		if done then
			bullet.part:Destroy()
			table.remove(bullets, i)
		end
	end
end)

local ZONE_REFRESH_INTERVAL = 5

local lastFired = setmetatable({}, { __mode = "k" })
local zones = getZones()
local nextZoneRefresh = os.clock() + ZONE_REFRESH_INTERVAL

while true do
	task.wait(0.1)
	local now = os.clock()
	if now >= nextZoneRefresh then
		zones = getZones()
		nextZoneRefresh = now + ZONE_REFRESH_INTERVAL
	end
	for _, dummy in ipairs(getDummies()) do
		if dummy.Parent and now - (lastFired[dummy] or 0) >= DummyConfig.FireInterval then
			local zone = findZone(zones, dummy:GetPivot().Position)
			if zone and playerInZone(zone) then
				lastFired[dummy] = now
				fire(dummy, zone)
			end
		end
	end
end
