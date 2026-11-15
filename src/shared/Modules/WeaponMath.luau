--[[
	WeaponMath
	Matemática compartilhada entre cliente e servidor para que os dois
	calculem exatamente as mesmas direções (dispersão e chumbos da escopeta).
]]

local WeaponMath = {}

-- Desvia uma direção dentro de um cone de `degrees` graus.
function WeaponMath.spread(direction: Vector3, degrees: number, rng: Random): Vector3
	if degrees <= 0 then
		return direction
	end
	local cf = CFrame.lookAt(Vector3.zero, direction)
	-- raiz quadrada: distribuição uniforme na área do cone
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber(0, math.pi * 2)
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Direções dos chumbos a partir de uma semente (mesma semente = mesmas direções).
function WeaponMath.pelletDirections(direction: Vector3, seed: number, count: number, degrees: number): { Vector3 }
	local rng = Random.new(seed)
	local dirs = {}
	for i = 1, count do
		dirs[i] = WeaponMath.spread(direction, degrees, rng)
	end
	return dirs
end

-- Classe sonora/visual de um material de superfície.
local CLASS = {
	[Enum.Material.Brick] = "Concrete",
	[Enum.Material.Concrete] = "Concrete",
	[Enum.Material.Slate] = "Concrete",
	[Enum.Material.Asphalt] = "Concrete",
	[Enum.Material.Rock] = "Concrete",
	[Enum.Material.Cobblestone] = "Concrete",
	[Enum.Material.SmoothPlastic] = "Concrete",
	[Enum.Material.Plastic] = "Concrete",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
	[Enum.Material.Glass] = "Glass",
	[Enum.Material.Grass] = "Dirt",
	[Enum.Material.Ground] = "Dirt",
	[Enum.Material.Mud] = "Dirt",
	[Enum.Material.Sand] = "Dirt",
	[Enum.Material.Fabric] = "Dirt",
	[Enum.Material.Water] = "Dirt",
}

function WeaponMath.materialClass(material: Enum.Material?): string
	return (material and CLASS[material]) or "Concrete"
end

-- Mesmo que materialClass, a partir do nome do material ("Body" = personagem).
local BY_NAME: { [string]: Enum.Material } = {}
for _, item in Enum.Material:GetEnumItems() do
	BY_NAME[item.Name] = item :: any
end
function WeaponMath.classFromName(name: string): string
	if name == "Body" then
		return "Body"
	end
	return WeaponMath.materialClass(BY_NAME[name])
end

return WeaponMath
