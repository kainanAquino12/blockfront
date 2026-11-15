--[[
	AudioController (cliente) — áudio espacial do combate.

	- Sons 3D presos a um Attachment na posição do evento: o Roblox faz a
	  panorâmica e a atenuação, então dá para ouvir de onde vem o tiro.
	- Atenuação InverseTapered com distância mínima/máxima por categoria
	  (tiro, impacto, explosão, manuseio).
	- Tiros distantes vão para o SoundGroup "Distant" (equalizador cortando
	  agudos), soando abafados como tiros longe de verdade.
	- Reverberação ambiente de cidade (SoundService.AmbientReverb).
	- Limite de sons simultâneos por categoria: se estourar, o som novo é
	  descartado em vez de empilhar (evita "parede de ruído" e custo).
	- Sons do próprio jogador (arma na mão, interface) tocam em 2D.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local AudioController = {}

local active: { [string]: number } = {}
local groups: { [string]: SoundGroup } = {}
local rng = Random.new()

local function makeGroups()
	local near = Instance.new("SoundGroup")
	near.Name = "Near"
	near.Volume = 1
	near.Parent = SoundService
	local far = Instance.new("SoundGroup")
	far.Name = "Distant"
	far.Volume = 0.9
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -18
	eq.MidGain = -4
	eq.LowGain = 2
	eq.Parent = far
	far.Parent = SoundService
	local ui = Instance.new("SoundGroup")
	ui.Name = "Interface"
	ui.Volume = 0.8
	ui.Parent = SoundService
	groups.Near, groups.Distant, groups.Interface = near, far, ui
end

local function cameraPos(): Vector3
	return workspace.CurrentCamera.CFrame.Position
end

export type PlayOptions = {
	Volume: number?,
	Speed: number?, -- PlaybackSpeed
	Vary: number?, -- variação aleatória de pitch (± fração)
	Category: string?, -- Shot, Impact, Explosion, Foley
	Distant: boolean?, -- força o grupo abafado
}

-- Toca um som. position nil = 2D (para o próprio jogador). Retorna o Sound ou nil.
function AudioController.play(soundId: string?, position: Vector3?, opts: PlayOptions?): Sound?
	if not soundId or soundId == "" then
		return nil
	end
	local o = opts or {}
	local category = o.Category or "Foley"
	local cat = AudioConfig.Categories[category] or AudioConfig.Categories.Foley

	local dist = if position then (position - cameraPos()).Magnitude else 0
	if position and dist > cat.MaxDistance then
		return nil
	end
	if (active[category] or 0) >= cat.MaxActive then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = o.Volume or 0.8
	local speed = o.Speed or 1
	if o.Vary then
		speed *= 1 + rng:NextNumber(-o.Vary, o.Vary)
	end
	sound.PlaybackSpeed = speed

	local holder: Instance
	if position then
		local att = Instance.new("Attachment")
		att.WorldPosition = position
		att.Parent = workspace.Terrain
		holder = att
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = cat.RollOffMin
		sound.RollOffMaxDistance = cat.MaxDistance
		local distant = o.Distant or (category == "Shot" and dist > AudioConfig.DistantShotFrom)
		sound.SoundGroup = if distant then groups.Distant else groups.Near
	else
		holder = groups.Interface
		sound.SoundGroup = groups.Interface
	end
	sound.Parent = holder
	sound:Play()

	active[category] = (active[category] or 0) + 1
	local life = if category == "Explosion" then 8 else 4
	task.delay(life, function()
		active[category] = math.max(0, (active[category] or 1) - 1)
	end)
	Debris:AddItem(if position then holder else sound, life)
	return sound
end

-- Escolhe aleatoriamente um ID de uma lista.
function AudioController.pick(list: { string }?): string?
	if not list or #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

function AudioController.init()
	makeGroups()
	SoundService.AmbientReverb = Enum.ReverbType.City
	SoundService.RolloffScale = 1
end

return AudioController
