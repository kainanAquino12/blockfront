--[[
	DestructionEffects (cliente)
	Somente visual. Recebe DestructionBatch do servidor e cria:
	  - efeito de explosão (Explosion sem força + clarão)
	  - fragmentos cúbicos físicos, locais a este cliente

	Os fragmentos nunca existem no servidor e não afetam a jogabilidade.
	Limites (DestructionConfig.Debris):
	  - pool fixo de Parts criado uma vez (sem Instance.new por explosão)
	  - teto de fragmentos ativos e por mensagem (amostragem)
	  - não cria fragmentos longe da câmera
	  - cada fragmento vive alguns segundos, desaparece e volta ao pool
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DestructionConfig = require(ReplicatedStorage.Shared.Config.DestructionConfig)
local MaterialConfig = require(ReplicatedStorage.Shared.Config.MaterialConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local Debris = game:GetService("Debris")

local cfg = DestructionConfig.Debris

local DestructionEffects = {}

type Active = { part: BasePart, born: number, life: number }

local PARK = CFrame.new(0, -400, 0) -- acima de FallenPartsDestroyHeight; partes estacionadas ficam ancoradas
local free: { BasePart } = {}
local active: { Active } = {}
local cacheFolder: Folder
local rng = Random.new()

local function newDebrisPart(): BasePart
	local p = Instance.new("Part")
	p.Name = "Debris"
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CollisionGroup = GameConfig.CollisionGroups.Debris
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = PARK
	p.Parent = cacheFolder
	return p
end

local function park(p: BasePart)
	if p.Parent ~= cacheFolder then
		-- Caiu abaixo de FallenPartsDestroyHeight e foi destruída: repõe no pool.
		p = newDebrisPart()
	end
	p.Anchored = true
	p.CFrame = PARK
	p.Transparency = 0
	table.insert(free, p)
end

local function spawnDebris(position: Vector3, materialId: number, voxelSize: number, velocity: Vector3)
	if #active >= cfg.MaxActive then
		return
	end
	local p = table.remove(free)
	if not p then
		return
	end
	local def = MaterialConfig.ById[materialId]
	local s = voxelSize * rng:NextNumber(cfg.SizeMin, cfg.SizeMax)
	p.Size = Vector3.new(s, s, s)
	p.Material = def and def.Material or Enum.Material.SmoothPlastic
	local base = def and def.Color or Color3.new(0.6, 0.6, 0.6)
	local shade = rng:NextNumber(0.8, 1.1)
	p.Color = Color3.new(math.min(base.R * shade, 1), math.min(base.G * shade, 1), math.min(base.B * shade, 1))
	p.Transparency = 0
	p.CFrame = CFrame.new(position)
		* CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
	p.Anchored = false
	p.AssemblyLinearVelocity = velocity
	p.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(4, 14)
	table.insert(active, {
		part = p,
		born = os.clock(),
		life = rng:NextNumber(cfg.LifetimeMin, cfg.LifetimeMax),
	})
end

local function cellPosition(origin: CFrame, vs: number, sx: number, sy: number, i: number): Vector3
	local x = i % sx
	local rest = (i - x) // sx
	local y = rest % sy
	local z = (rest - y) // sy
	return origin:PointToWorldSpace(Vector3.new((x + 0.5) * vs, (y + 0.5) * vs, (z + 0.5) * vs))
end

-- Centro da explosão mais próxima (para dar direção aos fragmentos).
local function nearestExplosion(explosions, pos: Vector3): Vector3?
	local best, bestD = nil, math.huge
	for _, e in explosions do
		local d = (e.Position - pos).Magnitude
		if d < bestD then
			best, bestD = e.Position, d
		end
	end
	return best
end

local function emitCells(entry, cells: buffer, mats: buffer, explosions, collapse: boolean)
	local count = buffer.len(mats)
	if count == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local budget = math.min(cfg.MaxPerBatch, cfg.MaxActive - #active)
	if budget <= 0 then
		return
	end
	local step = math.max(1, count / budget)
	local k = 0
	while k < count do
		local idx = math.floor(k)
		local i = buffer.readu32(cells, idx * 4)
		local mat = buffer.readu8(mats, idx)
		local pos = cellPosition(entry.Origin, entry.VoxelSize, entry.SizeX, entry.SizeY, i)
		if (pos - camPos).Magnitude <= cfg.MaxDistance then
			local vel: Vector3
			if collapse then
				vel = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-4, 0), rng:NextNumber(-2, 2))
			else
				local center = nearestExplosion(explosions, pos) or pos
				local dir = pos - center
				dir = if dir.Magnitude > 1e-3 then dir.Unit else rng:NextUnitVector()
				vel = (dir + Vector3.new(0, 0.6, 0)).Unit * cfg.Speed * rng:NextNumber(0.4, 1)
			end
			spawnDebris(pos, mat, entry.VoxelSize, vel)
		end
		k += step
	end
end

local function playExplosion(position: Vector3, radius: number)
	local e = Instance.new("Explosion")
	e.BlastPressure = 0
	e.BlastRadius = radius
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Position = position
	e.Parent = workspace

	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = WeaponConfig.ExplosionSound
	sound.Volume = 1
	sound.RollOffMaxDistance = 600
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 4)

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 200, 90)
	flash.Size = Vector3.one * radius
	flash.Position = position
	flash.Parent = workspace
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) / 0.25
		if a >= 1 then
			conn:Disconnect()
			flash:Destroy()
			return
		end
		flash.Size = Vector3.one * radius * (1 + a * 1.2)
		flash.Transparency = a
	end)
end

local function onBatch(message)
	if type(message) ~= "table" then
		return
	end
	local explosions = message.Explosions or {}
	for _, e in explosions do
		if e.Kind == "Explosion" then
			playExplosion(e.Position, e.Radius)
		end
	end
	for _, entry in message.Structures or {} do
		if entry.Cells then
			emitCells(entry, entry.Cells, entry.Mats, explosions, false)
		end
		if entry.Collapse then
			emitCells(entry, entry.Collapse, entry.CollapseMats, explosions, true)
		end
	end
end

local function update()
	local now = os.clock()
	local n = #active
	local i = 1
	while i <= n do
		local a = active[i]
		local age = now - a.born
		if age >= a.life then
			park(a.part)
			active[i] = active[n]
			active[n] = nil
			n -= 1
		else
			local fadeStart = a.life - cfg.FadeTime
			if age > fadeStart then
				a.part.Transparency = (age - fadeStart) / cfg.FadeTime
			end
			i += 1
		end
	end
end

function DestructionEffects.getActiveCount(): number
	return #active
end

function DestructionEffects.init()
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "DebrisCache"
	cacheFolder.Parent = workspace
	for _ = 1, cfg.PoolSize do
		table.insert(free, newDebrisPart())
	end
	Remotes.get("DestructionBatch").OnClientEvent:Connect(onBatch)
	RunService.Heartbeat:Connect(update)
end

return DestructionEffects
