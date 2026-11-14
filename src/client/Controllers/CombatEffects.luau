--[[
	CombatEffects (cliente) — somente visual e som.
	  - traçantes do rifle (pool de Parts) e clarão no cano
	  - foguetes desenhados localmente a partir do CombatEvent "Rocket"
	  - sons de disparo, arremesso e golpe dos outros jogadores
	O próprio tiro é desenhado na hora pelo WeaponController; os eventos do
	servidor sobre o jogador local são ignorados para não duplicar.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local player = Players.LocalPlayer
local Weapons = WeaponConfig.Weapons

local CombatEffects = {}

local effectsFolder: Folder
local tracerPool: { Part } = {}
local TRACER_POOL_SIZE = 48
local TRACER_TIME = 0.06
local rockets: { [number]: { model: Model, origin: Vector3, dir: Vector3, speed: number, t0: number, life: number } } = {}

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

-- Toca um som. position nil = som 2D (para o jogador local).
function CombatEffects.playSoundAt(soundId: string?, position: Vector3?, volume: number?)
	if not soundId then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.8
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 300
		sound.Parent = holder
		sound:Play()
		Debris:AddItem(holder, 4)
	else
		SoundService:PlayLocalSound(sound)
		sound:Destroy()
	end
end

local function muzzleFlash(position: Vector3)
	local p = newEffectPart()
	p.Size = Vector3.new(0.45, 0.45, 0.45)
	p.Color = Color3.fromRGB(255, 210, 90)
	p.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 8
	light.Brightness = 3
	light.Parent = p
	p.Parent = effectsFolder
	Debris:AddItem(p, 0.05)
end

-- isLocal: tiro do próprio jogador (som 2D, sem atenuação por distância).
function CombatEffects.playShot(weapon, from: Vector3, to: Vector3, isLocal: boolean?)
	local p = table.remove(tracerPool) or newEffectPart()
	local len = (to - from).Magnitude
	p.Size = Vector3.new(0.08, 0.08, len)
	p.Color = Color3.fromRGB(255, 226, 120)
	p.Transparency = 0.2
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	p.Parent = effectsFolder
	task.delay(TRACER_TIME, function()
		p.Parent = nil
		if #tracerPool < TRACER_POOL_SIZE then
			table.insert(tracerPool, p)
		else
			p:Destroy()
		end
	end)
	muzzleFlash(from)
	CombatEffects.playSoundAt(weapon.Sounds.Fire, if isLocal then nil else from, 0.7)
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
	-- Rastro de fumaça
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.15, 0.6)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.15, 0.6)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
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

local function spawnRocket(id: number, origin: Vector3, dir: Vector3, speed: number, range: number)
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
		if not isLocal and w then
			local shooterChar = e.Shooter and e.Shooter.Character
			local tool = shooterChar and shooterChar:FindFirstChildOfClass("Tool")
			local muzzle = tool and tool:FindFirstChild("Muzzle", true) :: Attachment?
			CombatEffects.playShot(w, if muzzle then muzzle.WorldPosition else e.Origin, e.Hit)
		end
	elseif e.Type == "Rocket" then
		spawnRocket(e.Id, e.Origin, e.Direction, e.Speed, w and w.Range or 600)
		if not isLocal and w then
			CombatEffects.playSoundAt(w.Sounds.Fire, e.Origin, 0.9)
		end
	elseif e.Type == "ProjectileEnd" then
		removeRocket(e.Id)
	elseif (e.Type == "Throw" or e.Type == "Swing") and not isLocal and w then
		CombatEffects.playSoundAt(w.Sounds.Fire, e.Origin, 0.8)
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
	for _ = 1, 16 do
		table.insert(tracerPool, newEffectPart())
	end
	Remotes.get("CombatEvent").OnClientEvent:Connect(onCombatEvent)
	RunService.RenderStepped:Connect(update)
end

return CombatEffects
