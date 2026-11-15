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

function CombatEffects.muzzleFlash(position: Vector3, scale: number?)
	local s = scale or 1
	local p = newEffectPart()
	p.Size = Vector3.new(0.35, 0.35, 0.35) * s
	p.Color = Color3.fromRGB(255, 214, 110)
	p.CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0)
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 9 * s
	light.Brightness = 3
	light.Parent = p
	p.Parent = effectsFolder
	Debris:AddItem(p, 0.045)
end

local function tracer(from: Vector3, to: Vector3)
	local p = table.remove(tracerPool) or newEffectPart()
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	p.Size = Vector3.new(0.07, 0.07, math.min(len, 60))
	p.Color = Color3.fromRGB(255, 226, 120)
	p.Transparency = 0.15
	-- traçante curto saindo do cano em direção ao alvo
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -math.min(len, 60) / 2)
	p.Parent = effectsFolder
	task.delay(TRACER_TIME, function()
		p.Parent = nil
		if #tracerPool < TRACER_POOL_SIZE then
			table.insert(tracerPool, p)
		else
			p:Destroy()
		end
	end)
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
	CombatEffects.muzzleFlash(from, if weapon.Pellets then 1.5 else 1)
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
end

return CombatEffects
