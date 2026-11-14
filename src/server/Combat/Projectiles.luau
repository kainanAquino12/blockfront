--[[
	Projectiles (servidor)
	Simulação autoritativa dos projéteis.

	Foguete: simulado só com dados (posição + velocidade), um raycast por
	Heartbeat do ponto anterior ao novo. Nada físico é replicado: os
	clientes recebem CombatEvent "Rocket" (origem, direção, velocidade) e
	desenham o foguete localmente; ao explodir, recebem "ProjectileEnd".

	Granada: Part física de verdade, dona da rede = servidor (quique e rola
	igual para todos). Explode quando o pavio acaba.

	Quando um projétil detona, chama o callback onDetonate(owner, weaponId,
	position) fornecido pelo CombatManager, que aplica o dano.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)

local Projectiles = {}

type Rocket = {
	Id: number,
	Owner: Player,
	WeaponId: string,
	Position: Vector3,
	Velocity: Vector3,
	Traveled: number,
	MaxRange: number,
}

local rockets: { Rocket } = {}
local nextId = 0
local onDetonate: (owner: Player, weaponId: string, position: Vector3, projectileId: number?) -> ()

local function rayParams(owner: Player): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if owner.Character then
		table.insert(exclude, owner.Character)
	end
	local grenades = workspace:FindFirstChild("Grenades")
	if grenades then
		table.insert(exclude, grenades)
	end
	params.FilterDescendantsInstances = exclude
	return params
end

function Projectiles.fireRocket(owner: Player, weaponId: string, origin: Vector3, direction: Vector3, speed: number, range: number): number
	nextId += 1
	table.insert(rockets, {
		Id = nextId,
		Owner = owner,
		WeaponId = weaponId,
		Position = origin,
		Velocity = direction * speed,
		Traveled = 0,
		MaxRange = range,
	})
	return nextId
end

local function stepRockets(dt: number)
	local i = 1
	while i <= #rockets do
		local r = rockets[i]
		local move = r.Velocity * dt
		local result = workspace:Raycast(r.Position, move, rayParams(r.Owner))
		local detonateAt: Vector3? = nil
		if result then
			-- Recua um pouco para a explosão nascer fora da parede.
			detonateAt = result.Position - r.Velocity.Unit * 0.3
		else
			r.Position += move
			r.Traveled += move.Magnitude
			if r.Traveled >= r.MaxRange then
				detonateAt = r.Position
			end
		end
		if detonateAt then
			table.remove(rockets, i)
			onDetonate(r.Owner, r.WeaponId, detonateAt, r.Id)
		else
			i += 1
		end
	end
end

function Projectiles.throwGrenade(owner: Player, weaponId: string, origin: Vector3, velocity: Vector3, fuse: number)
	local folder = workspace:FindFirstChild("Grenades")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Grenades"
		folder.Parent = workspace
	end
	local handle = WeaponModels.build(weaponId)
	handle.Name = "ThrownGrenade"
	handle.CanCollide = true
	handle.Massless = false
	handle.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.3)
	handle.CFrame = CFrame.new(origin)
	handle.Parent = folder
	handle:SetNetworkOwner(nil)
	handle.AssemblyLinearVelocity = velocity
	handle.AssemblyAngularVelocity = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8)

	task.delay(fuse, function()
		if handle.Parent then
			local pos = handle.Position
			handle:Destroy()
			onDetonate(owner, weaponId, pos, nil)
		end
	end)
end

function Projectiles.clearAll()
	table.clear(rockets)
	local folder = workspace:FindFirstChild("Grenades")
	if folder then
		folder:ClearAllChildren()
	end
end

function Projectiles.init(detonateCallback)
	onDetonate = detonateCallback
	RunService.Heartbeat:Connect(stepRockets)
end

return Projectiles
