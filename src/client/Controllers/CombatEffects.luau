--[[
	CombatEffects (cliente) — efeitos visuais e sonoros do combate.
	  - traçantes (pool de Parts) e clarão no cano com luz
	  - impactos por material: som (concreto, madeira, metal, vidro, terra,
	    corpo) e fragmentos cúbicos na cor da superfície
	  - foguetes desenhados localmente, com rastro e som de propulsão 3D
	  - sons 3D dos tiros, arremessos e golpes dos outros jogadores
	  - marcador de acerto (som) para o atirador
	O próprio tiro é desenhado na hora pelo WeaponController; os eventos do
	servidor sobre o jogador local são ignorados para não duplicar sons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)
local WeaponMath = require(ReplicatedStorage.Shared.Modules.WeaponMath)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local AudioController = require(script.Parent.AudioController)
local DestructionEffects = require(script.Parent.DestructionEffects)

local player = Players.LocalPlayer
local Weapons = WeaponConfig.Weapons
local rng = Random.new()

local CombatEffects = {}

local effectsFolder: Folder
local tracerPool: { Part } = {}
local TRACER_POOL_SIZE = 64
local TRACER_TIME = 0.05
local rockets: { [number]: { model: Model, origin: Vector3, dir: Vector3, speed: number, t0: number, life: number } } = {}

-- Cores de fragmento por classe de material (superfícies não voxel)
local FRAG = {
	Concrete = { Color3.fromRGB(170, 170, 176), Enum.Material.Concrete },
	Wood = { Color3.fromRGB(160, 112, 70), Enum.Material.WoodPlanks },
	Metal = { Color3.fromRGB(150, 156, 166), Enum.Material.Metal },
	Glass = { Color3.fromRGB(180, 220, 240), Enum.Material.Glass },
	Dirt = { Color3.fromRGB(110, 150, 80), Enum.Material.Grass },
	Body = { Color3.fromRGB(190, 40, 40), Enum.Material.SmoothPlastic },
}

local function newEffectPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	return p
end

--[[
	V11: tiros com cara de tiro.
	  - Clarão do cano: núcleo + "pétalas" alinhadas ao disparo + fumaça
	    que sobe e some (antes era um cubinho amarelo por 1 quadro).
	  - Traçante VIAJANDO: uma risca curta e brilhante que sai do cano e
	    voa até o ponto de impacto a ~900 studs/s (antes era uma linha
	    parada de 60 studs que piscava).
	  - Impacto: poeira na cor do material + faísca rápida.
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TRACER_SPEED = 900
local TRACER_LEN = 7
local flying: { { part: Part, from: Vector3, dir: Vector3, dist: number, t: number } } = {}

local function fade(p: BasePart, time: number, goal: { [string]: any })
	local tw = TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	Debris:AddItem(p, time + 0.05)
end

function CombatEffects.muzzleFlash(position: Vector3, scale: number?, direction: Vector3?)
	local s = scale or 1
	local dir = if direction and direction.Magnitude > 1e-3 then direction.Unit else workspace.CurrentCamera.CFrame.LookVector
	local base = CFrame.lookAt(position, position + dir) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
	local core = newEffectPart()
	core.Size = Vector3.new(0.22, 0.22, 0.22) * s
	core.Color = Color3.fromRGB(255, 236, 170)
	core.CFrame = base
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 12 * s
	light.Brightness = 4
	light.Shadows = false
	light.Parent = core
	core.Parent = effectsFolder
	Debris:AddItem(core, 0.05)
	-- chama para frente + duas pétalas cruzadas
	local flame = newEffectPart()
	flame.Size = Vector3.new(0.14, 0.14, rng:NextNumber(0.6, 0.95)) * s
	flame.Color = Color3.fromRGB(255, 196, 90)
	flame.CFrame = base * CFrame.new(0, 0, -flame.Size.Z / 2)
	flame.Parent = effectsFolder
	Debris:AddItem(flame, 0.04)
	for k = 0, 1 do
		local petal = newEffectPart()
		petal.Size = Vector3.new(0.32 * s, 0.035 * s, 0.035 * s)
		petal.Color = Color3.fromRGB(255, 170, 70)
		petal.CFrame = base * CFrame.new(0, 0, -0.15 * s) * CFrame.Angles(0, 0, k * math.pi / 2)
		petal.Parent = effectsFolder
		Debris:AddItem(petal, 0.035)
	end
	-- fumaça
	local smoke = newEffectPart()
	smoke.Material = Enum.Material.SmoothPlastic
	smoke.Color = Color3.fromRGB(170, 168, 160)
	smoke.Shape = Enum.PartType.Ball
	smoke.Transparency = 0.78
	smoke.Size = Vector3.one * 0.15 * s
	smoke.CFrame = base * CFrame.new(0, 0, -0.3 * s)
	smoke.Parent = effectsFolder
	fade(smoke, 0.35, { Size = Vector3.one * 0.45 * s, Transparency = 1, CFrame = smoke.CFrame + Vector3.new(0, 0.35, 0) + dir * 0.4 })
end

local function tracer(from: Vector3, to: Vector3)
	local d = to - from
	local dist = d.Magnitude
	if dist < 2 then
		return
	end
	local p = table.remove(tracerPool) or newEffectPart()
	p.Size = Vector3.new(0.05, 0.05, TRACER_LEN)
	p.Color = Color3.fromRGB(255, 214, 130)
	p.Transparency = 0.1
	p.Parent = effectsFolder
	table.insert(flying, { part = p, from = from, dir = d / dist, dist = dist, t = 0 })
end

local function updateTracers(dt: number)
	local i = 1
	while i <= #flying do
		local f = flying[i]
		f.t += dt
		local head = math.min(f.t * TRACER_SPEED, f.dist)
		local tail = math.max(head - TRACER_LEN, 0)
		if tail >= f.dist - 0.05 then
			f.part.Parent = nil
			if #tracerPool < TRACER_POOL_SIZE then
				table.insert(tracerPool, f.part)
			else
				f.part:Destroy()
			end
			flying[i] = flying[#flying]
			flying[#flying] = nil
		else
			local a = f.from + f.dir * tail
			local b = f.from + f.dir * head
			local len = math.max((b - a).Magnitude, 0.05)
			f.part.Size = Vector3.new(0.05, 0.05, len)
			f.part.CFrame = CFrame.lookAt((a + b) / 2, b)
			i += 1
		end
	end
end

-- Poeira e faísca no ponto de impacto.
local DUST = {
	Concrete = Color3.fromRGB(176, 172, 164),
	Wood = Color3.fromRGB(150, 116, 80),
	Metal = Color3.fromRGB(150, 150, 150),
	Glass = Color3.fromRGB(200, 220, 230),
	Dirt = Color3.fromRGB(120, 104, 80),
	Body = Color3.fromRGB(120, 20, 20),
}
local function impactPuff(position: Vector3, class: string, normal: Vector3)
	local dust = newEffectPart()
	dust.Material = Enum.Material.SmoothPlastic
	dust.Color = DUST[class] or DUST.Concrete
	dust.Shape = Enum.PartType.Ball
	dust.Transparency = 0.45
	dust.Size = Vector3.one * 0.3
	dust.CFrame = CFrame.new(position + normal * 0.15)
	dust.Parent = effectsFolder
	fade(dust, 0.4, { Size = Vector3.one * 1.4, Transparency = 1, CFrame = CFrame.new(position + normal * 0.7) })
	if class == "Metal" or class == "Concrete" then
		local spark = newEffectPart()
		spark.Color = Color3.fromRGB(255, 220, 140)
		spark.Size = Vector3.one * 0.14
		spark.CFrame = CFrame.new(position + normal * 0.05)
		spark.Parent = effectsFolder
		Debris:AddItem(spark, 0.04)
	end
end

-- Impacto num ponto: som pelo material + fragmentos.
function CombatEffects.impact(position: Vector3, materialName: string?, normal: Vector3?)
	if not materialName or materialName == "" then
		return
	end
	local class = WeaponMath.classFromName(materialName)
	AudioController.play(AudioController.pick(AudioConfig.Impacts[class]), position, {
		Category = "Impact",
		Volume = if class == "Glass" then 0.5 else 0.7,
		Speed = if class == "Dirt" then 0.7 else 1,
		Vary = 0.12,
	})
	local frag = FRAG[class]
	local n = normal or Vector3.yAxis
	impactPuff(position, class, n)
	for _ = 1, (if class == "Body" then 3 else 2) do
		local v = (n + rng:NextUnitVector() * 0.6).Unit * rng:NextNumber(8, 18) + Vector3.new(0, 6, 0)
		DestructionEffects.spawnFragment(position + n * 0.2, frag[1], frag[2], rng:NextNumber(0.12, 0.25), v)
	end
end

-- Golpe de marreta atingindo algo.
function CombatEffects.meleeImpact(position: Vector3, materialName: string?)
	if not materialName or materialName == "" then
		return
	end
	local class = WeaponMath.classFromName(materialName)
	AudioController.play(AudioConfig.MeleeImpacts[class], position, { Category = "Impact", Volume = 1, Vary = 0.1 })
end

--[[
	Tiro (todas as armas de projétil instantâneo).
	hits: { {Position, Material, Normal} } — 1 item, ou vários na escopeta.
	isLocal: tiro do próprio jogador (som 2D, sem atenuação).
]]
function CombatEffects.playShot(weapon, from: Vector3, hits, isLocal: boolean?)
	for _, h in hits do
		tracer(from, h.Position)
		CombatEffects.impact(h.Position, h.Material, h.Normal)
	end
	CombatEffects.muzzleFlash(from, if weapon.Pellets then 1.5 else 1, hits[1] and (hits[1].Position - from))
	AudioController.play(weapon.Sounds.Fire, if isLocal then nil else from, {
		Category = "Shot",
		Volume = if isLocal then 0.75 else 1,
		Vary = 0.05,
	})
end

local function buildRocketModel(): Model
	local model = Instance.new("Model")
	local body = newEffectPart()
	body.Material = Enum.Material.SmoothPlastic
	body.Color = WeaponModels.Colors.Olive
	body.Size = Vector3.new(0.4, 0.4, 1.2)
	body.Name = "Body"
	body.Parent = model
	local tip = newEffectPart()
	tip.Material = Enum.Material.SmoothPlastic
	tip.Color = WeaponModels.Colors.Dark
	tip.Size = Vector3.new(0.3, 0.3, 0.3)
	tip.Name = "Tip"
	tip.Parent = model
	local flame = newEffectPart()
	flame.Color = Color3.fromRGB(255, 140, 40)
	flame.Size = Vector3.new(0.3, 0.3, 0.4)
	flame.Name = "Flame"
	flame.Parent = model
	local light = Instance.new("PointLight")
	light.Color = flame.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = flame
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.15, 0.6)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.15, 0.6)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.Color = ColorSequence.new(Color3.fromRGB(210, 210, 210))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.WidthScale = NumberSequence.new(1, 3)
	trail.Parent = body
	model.PrimaryPart = body
	return model
end

local function placeRocket(r, position: Vector3)
	local cf = CFrame.lookAt(position, position + r.dir)
	local model = r.model
	model.Body.CFrame = cf
	model.Tip.CFrame = cf * CFrame.new(0, 0, -0.75)
	model.Flame.CFrame = cf * CFrame.new(0, 0, 0.8)
end

local function spawnRocket(id: number, origin: Vector3, dir: Vector3, speed: number, range: number, loopId: string?)
	local r = {
		model = buildRocketModel(),
		origin = origin,
		dir = dir,
		speed = speed,
		t0 = os.clock(),
		life = range / speed + 0.5,
	}
	placeRocket(r, origin)
	r.model.Parent = effectsFolder
	if loopId then
		local loop = Instance.new("Sound")
		loop.SoundId = loopId
		loop.Looped = true
		loop.Volume = 0.7
		loop.RollOffMode = Enum.RollOffMode.InverseTapered
		loop.RollOffMinDistance = 10
		loop.RollOffMaxDistance = 250
		loop.Parent = r.model.Body
		loop:Play()
	end
	rockets[id] = r
end

local function removeRocket(id: number)
	local r = rockets[id]
	if r then
		rockets[id] = nil
		r.model:Destroy()
	end
end

local function onCombatEvent(e)
	if type(e) ~= "table" then
		return
	end
	local isLocal = e.Shooter == player
	local w = e.Weapon and Weapons[e.Weapon]
	if e.Type == "Shot" then
		if not isLocal and w and type(e.Hits) == "table" then
			local shooterChar = e.Shooter and e.Shooter.Character
			local tool = shooterChar and shooterChar:FindFirstChildOfClass("Tool")
			local muzzle = tool and tool:FindFirstChild("Muzzle", true) :: Attachment?
			CombatEffects.playShot(w, if muzzle then muzzle.WorldPosition else e.Origin, e.Hits, false)
		end
	elseif e.Type == "Rocket" then
		spawnRocket(e.Id, e.Origin, e.Direction, e.Speed, w and w.Range or 600, w and w.Sounds.Loop)
		if not isLocal and w then
			AudioController.play(w.Sounds.Fire, e.Origin, { Category = "Shot", Volume = 1 })
		end
	elseif e.Type == "ProjectileEnd" then
		removeRocket(e.Id)
	elseif e.Type == "Throw" and not isLocal and w then
		AudioController.play(w.Sounds.Fire, e.Origin, { Category = "Foley", Volume = 0.8 })
	elseif e.Type == "Swing" and not isLocal and w then
		AudioController.play(w.Sounds.Fire, e.Origin, { Category = "Foley", Volume = 0.8 })
		if e.Hit then
			CombatEffects.meleeImpact(e.Hit, e.Material)
		end
	elseif e.Type == "Hit" then
		AudioController.play(AudioConfig.UI.Hitmarker, nil, { Volume = if e.Lethal then 1 else 0.7, Speed = if e.Lethal then 0.8 elseif e.Headshot then 1.25 else 1 })
	end
end

local function update()
	local now = os.clock()
	for id, r in rockets do
		local t = now - r.t0
		if t > r.life then
			removeRocket(id)
		else
			placeRocket(r, r.origin + r.dir * r.speed * t)
		end
	end
end

function CombatEffects.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "LocalEffects"
	effectsFolder.Parent = workspace
	for _ = 1, 24 do
		table.insert(tracerPool, newEffectPart())
	end
	Remotes.get("CombatEvent").OnClientEvent:Connect(onCombatEvent)
	RunService.RenderStepped:Connect(update)
	RunService.RenderStepped:Connect(updateTracers)
end

return CombatEffects
