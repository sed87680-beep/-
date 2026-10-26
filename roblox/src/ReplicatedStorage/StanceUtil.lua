-- 캐릭터가 방패/무기/총을 들고 있는지 판별

local Config = require(script.Parent:WaitForChild("CombatConfig"))

local StanceUtil = {}

local function matchesName(inst, patterns)
	local name = string.lower(inst.Name)
	for _, pattern in ipairs(patterns) do
		if string.find(name, string.lower(pattern), 1, true) then
			return true
		end
	end
	return false
end

function StanceUtil.isShield(inst)
	return inst:GetAttribute(Config.ShieldAttribute) == true or matchesName(inst, Config.ShieldNamePatterns)
end

function StanceUtil.isGun(inst)
	return inst:GetAttribute(Config.GunAttribute) == true or matchesName(inst, Config.GunNamePatterns)
end

-- 방패가 Tool 이든 Accessory/Model 이든 캐릭터에 붙어 있으면 true
function StanceUtil.hasShield(character)
	for _, child in ipairs(character:GetChildren()) do
		if (child:IsA("Tool") or child:IsA("Accessory") or child:IsA("Model")) and StanceUtil.isShield(child) then
			return true
		end
	end
	return false
end

-- 방패가 아닌, 손에 든 Tool
function StanceUtil.getWeapon(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and not StanceUtil.isShield(child) then
			return child
		end
	end
	return nil
end

function StanceUtil.isHoldingGun(character)
	local weapon = StanceUtil.getWeapon(character)
	return weapon ~= nil and StanceUtil.isGun(weapon)
end

-- "ShieldAndWeapon" / "ShieldOnly" / nil
function StanceUtil.getStance(character)
	if not StanceUtil.hasShield(character) then
		return nil
	end
	if StanceUtil.getWeapon(character) then
		return "ShieldAndWeapon"
	end
	return "ShieldOnly"
end

-- 부품이 방패의 일부인지 (총알 막기용)
function StanceUtil.isShieldPart(part)
	local node = part
	while node and not node:IsA("Workspace") do
		if (node:IsA("Tool") or node:IsA("Accessory") or node:IsA("Model") or node:IsA("BasePart"))
			and not node:FindFirstChildOfClass("Humanoid")
			and StanceUtil.isShield(node)
		then
			return true
		end
		node = node.Parent
	end
	return false
end

return StanceUtil
