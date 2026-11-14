--[[
	MapManager (servidor)
	Monta o mapa "Vila Bloco" (MapLayout) e o ambiente.

	buildStatic()        piso, ruas, praça, bases, enfeites, limites, spawns,
	                     iluminação. Criado uma vez.
	buildDestructibles() construções voxel. Recriado a cada partida pelo
	                     RoundManager (o mapa volta inteiro).

	O layout descreve o lado azul; o lado vermelho é o mesmo layout girado
	180° em torno do centro (MIRROR).

	Hierarquia no Workspace:
	  Map                 cenário estático
	  SpawnPoints         SpawnLocations por equipe
	  DestructibleObjects estruturas voxel (DestructionManager)
	  CapturePoints       área de captura (CaptureManager)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DestructionManager = require(script.Parent.DestructionManager)
local MapFolder = script.Parent.Parent.Map
local MapLayout = require(MapFolder.MapLayout)
local PropKit = require(MapFolder.PropKit)

local MapManager = {}

local MIRROR = CFrame.Angles(0, math.pi, 0)
local SIDES = {
	{ Team = "Blue", Transform = CFrame.identity },
	{ Team = "Red", Transform = MIRROR },
}

local function folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = workspace
	return nf
end

local function makeSpawn(teamName: string, cf: CFrame, parent: Instance)
	local def = GameConfig.Teams[teamName]
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = teamName .. "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Anchored = true
	spawn.Neutral = false
	spawn.TeamColor = def.TeamColor
	spawn.Color = def.Color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 3
	spawn.CFrame = cf
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = parent
end

-- Base de uma equipe (no referencial do lado azul; T espelha para o vermelho).
local function buildBase(parent: Instance, T: CFrame, teamName: string)
	local team = GameConfig.Teams[teamName]
	local color = team.Color
	local base = Instance.new("Model")
	base.Name = teamName .. "Base"
	local function at(x: number, y: number, z: number): CFrame
		return T * CFrame.new(x, y, z)
	end
	-- piso
	PropKit.block(base, at(0, 0.15, -140), Vector3.new(80, 0.3, 36), PropKit.Colors.BaseFloor, Enum.Material.Concrete)
	-- faixas na cor do time
	PropKit.block(base, at(0, 0.32, -122.5), Vector3.new(80, 0.05, 1), color, nil, true)
	PropKit.block(base, at(0, 0.32, -134), Vector3.new(30, 0.05, 1), color, nil, true)
	-- muros estáticos (fundo e laterais), com faixa do time
	local wallColor = Color3.fromRGB(86, 92, 104)
	PropKit.block(base, at(0, 4, -158.5), Vector3.new(82, 8, 2), wallColor, Enum.Material.Concrete)
	PropKit.block(base, at(-40.5, 4, -146), Vector3.new(2, 8, 25), wallColor, Enum.Material.Concrete)
	PropKit.block(base, at(40.5, 4, -146), Vector3.new(2, 8, 25), wallColor, Enum.Material.Concrete)
	PropKit.block(base, at(0, 6.5, -157.4), Vector3.new(82, 1.2, 0.2), color, nil, true)
	PropKit.block(base, at(-39.4, 6.5, -146), Vector3.new(0.2, 1.2, 25), color, nil, true)
	PropKit.block(base, at(39.4, 6.5, -146), Vector3.new(0.2, 1.2, 25), color, nil, true)
	-- letreiro do time
	local sign = PropKit.block(base, at(0, 11, -158.5), Vector3.new(26, 5, 1), Color3.fromRGB(26, 30, 40))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = team.DisplayName
	text.Parent = gui
	PropKit.block(base, at(-12, 4.5, -158.5), Vector3.new(1, 9, 1), wallColor)
	PropKit.block(base, at(12, 4.5, -158.5), Vector3.new(1, 9, 1), wallColor)
	PropKit.flag(base, at(-34, 0, -152), color)
	PropKit.flag(base, at(34, 0, -152), color)
	base.Parent = parent
end

local function applyEnvironment()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(96, 100, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 146, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function MapManager.buildStatic()
	local map = folder("Map")
	local spawns = folder("SpawnPoints")
	local hx, hz = MapLayout.HalfX, MapLayout.HalfZ
	local C = PropKit.Colors

	-- Chão: grama com manchas de tonalidade
	PropKit.block(map, CFrame.new(0, -1, 0), Vector3.new(hx * 2 + 60, 2, hz * 2 + 60), C.Grass, Enum.Material.Grass).Name = "Ground"
	local rng = Random.new(42)
	for _ = 1, 26 do
		local w, d = rng:NextNumber(14, 40), rng:NextNumber(14, 40)
		PropKit.block(map, CFrame.new(rng:NextNumber(-hx, hx), 0.02, rng:NextNumber(-hz, hz)), Vector3.new(w, 0.05, d), C.GrassDark, Enum.Material.Grass, true)
	end

	-- Avenidas e caminhos
	PropKit.road(map, Vector3.new(0, 0, 0), 236, 14, true)
	PropKit.road(map, Vector3.new(0, 0, 0), 280, 12, false)
	PropKit.block(map, CFrame.new(0, 0.12, 0), Vector3.new(44, 0.25, 44), C.Sidewalk, Enum.Material.Concrete).Name = "Plaza"
	for _, x in { -70, 70 } do
		PropKit.block(map, CFrame.new(x, 0.05, 0), Vector3.new(10, 0.1, 236), C.Dirt, Enum.Material.Ground, true)
	end

	for _, side in SIDES do
		local T = side.Transform
		buildBase(map, T, side.Team)
		for _, pos in MapLayout.Spawns do
			makeSpawn(side.Team, T * CFrame.new(pos), spawns)
		end
		for _, t in MapLayout.Trees do
			PropKit.tree(map, T * CFrame.new(t[1], 0, t[2]) * CFrame.Angles(0, t[1] % 3, 0), t[3])
		end
		for _, r in MapLayout.Rocks do
			PropKit.rock(map, T * CFrame.new(r[1], 0, r[2]) * CFrame.Angles(0, r[2] % 4, 0), r[3])
		end
		for _, l in MapLayout.Lamps do
			PropKit.lamp(map, T * CFrame.new(l[1], 0, l[2]) * CFrame.Angles(0, if l[1] > 0 then math.pi / 2 else -math.pi / 2, 0))
		end
		local containerColors = { Color3.fromRGB(196, 92, 52), Color3.fromRGB(64, 120, 168), Color3.fromRGB(96, 140, 84), Color3.fromRGB(210, 170, 60) }
		for i, c in MapLayout.Containers do
			PropKit.container(map, T * CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), containerColors[(i - 1) % #containerColors + 1])
		end
		for _, f in MapLayout.Fences do
			PropKit.fence(map, (T * CFrame.new(f[1])).Position, (T * CFrame.new(f[2])).Position)
		end
	end

	PropKit.boundary(map, hx, hz)
	applyEnvironment()
end

-- Estruturas destrutíveis. Chamado de novo a cada partida (mapa volta inteiro).
function MapManager.buildDestructibles()
	DestructionManager.reset()
	local destructibles = folder("DestructibleObjects")
	for _, side in SIDES do
		for _, s in MapLayout.Structures do
			DestructionManager.createStructure({
				Name = side.Team .. "_" .. s.Name,
				Origin = side.Transform * CFrame.new(s.At.X, 0, s.At.Y),
				Size = s.Def.Size,
				Fill = s.Def.Fill,
				Parent = destructibles,
			})
		end
		task.wait() -- reparte a montagem entre frames
	end
end

function MapManager.init()
	MapManager.buildStatic()
	MapManager.buildDestructibles()
end

return MapManager
