--[[
	MapManager (servidor)
	Monta o mapa "Front Bloco" (MapLayout) e o ambiente.

	buildStatic()        terreno, rio, ruas, cenário, limites, spawns e
	                     iluminação. Criado uma vez.
	buildDestructibles() construções voxel. Recriado a cada partida pelo
	                     RoundManager (o mapa volta inteiro).

	Espelhamento: o MapLayout descreve o lado azul; o vermelho é o mesmo
	layout refletido no plano z = 0.
	  - estruturas: o canto mínimo é refletido e o preenchimento é
	    invertido no eixo z (portas na face S viram face N, etc.)
	  - cenário: posição refletida; a "frente" (-Z local) também é
	    refletida, então postes e semáforos continuam virados para a rua

	Hierarquia no Workspace:
	  Map                 cenário estático
	  SpawnPoints         SpawnLocations por equipe
	  DestructibleObjects estruturas voxel (DestructionManager)
	  CapturePoints       áreas de captura (CaptureManager)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DestructionManager = require(script.Parent.DestructionManager)
local MapFolder = script.Parent.Parent.Map
local MapLayout = require(MapFolder.MapLayout)
local PropKit = require(MapFolder.PropKit)

local MapManager = {}

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

-- Reflexão de um CFrame de cenário no plano z = 0 (mantém a "frente").
local function mirrorPropCF(cf: CFrame): CFrame
	local p = cf.Position
	local y = cf.YVector
	local z = cf.ZVector
	local y2 = Vector3.new(y.X, y.Y, -y.Z)
	local z2 = Vector3.new(z.X, z.Y, -z.Z)
	return CFrame.fromMatrix(Vector3.new(p.X, p.Y, -p.Z), y2:Cross(z2), y2, z2)
end

--[[
	Cria o contexto de construção de um lado.
	mode: "Blue" (como descrito), "Red" (espelhado) ou "Center" (como descrito,
	estruturas com prefixo "Center").
]]
local function makeContext(mode: string, static: Instance, destructibles: Instance)
	local mirrored = mode == "Red"
	local teamDef = GameConfig.Teams[mode]
	local ctx = {
		static = static,
		team = mode,
		color = if teamDef then teamDef.Color else Color3.new(1, 1, 1),
		displayName = if teamDef then teamDef.DisplayName else "",
	}

	function ctx.cf(x: number, y: number, z: number, yawDeg: number?): CFrame
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
		return if mirrored then mirrorPropCF(cf) else cf
	end

	function ctx.pos(x: number, y: number, z: number): Vector3
		return if mirrored then Vector3.new(x, y, -z) else Vector3.new(x, y, z)
	end

	function ctx.struct(name: string, x: number, z: number, def, y: number?)
		-- Estruturas com fachada externa (StructureKit.withFacade) crescem 1 célula
		-- para fora em X e Z; Offset devolve o canto ao mesmo lugar do miolo.
		if def.Offset then
			x += def.Offset.X
			z += def.Offset.Z
		end
		local origin, fill
		if mirrored then
			local sz = def.Size.Z
			origin = CFrame.new(x, y or 0, -(z + sz))
			local f = def.Fill
			fill = function(a: number, b: number, c: number): number
				return f(a, b, sz - 1 - c)
			end
		else
			origin = CFrame.new(x, y or 0, z)
			fill = def.Fill
		end
		DestructionManager.createStructure({
			Name = mode .. "_" .. name,
			Origin = origin,
			Size = def.Size,
			Fill = fill,
			Parent = destructibles,
		})
	end

	function ctx.yield()
		task.wait()
	end

	return ctx
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

local function applyEnvironment()
	-- Direção V3 "stylized military voxel": tarde clara, sol baixo lateral para
	-- marcar os volumes das fachadas, cores pouco saturadas e neblina leve que
	-- encurta as linhas de visão muito longas sem escurecer o combate.
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 1.9
	Lighting.Ambient = Color3.fromRGB(70, 72, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 120, 126)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.ExposureCompensation = 0
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(196, 196, 192)
	atmosphere.Decay = Color3.fromRGB(128, 122, 116)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.12
	cc.Contrast = 0.12
	cc.Brightness = 0
	cc.TintColor = Color3.fromRGB(255, 250, 242)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.03
	rays.Spread = 0.5
	rays.Parent = Lighting

	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.62
	clouds.Density = 0.45
	clouds.Color = Color3.fromRGB(226, 224, 220)
	clouds.Parent = terrain
	terrain.WaterColor = Color3.fromRGB(58, 74, 70)
	terrain.WaterTransparency = 0.75
	terrain.WaterReflectance = 0.3
	terrain.WaterWaveSize = 0.08
end

local function buildGround(map: Instance)
	local hx, hz = MapLayout.HalfX, MapLayout.HalfZ
	local river = MapLayout.River
	local C = PropKit.Colors
	local depth = 10
	local w0, w1 = -(hx + 40), river.X0
	local e0, e1 = river.X1, hx + 40
	PropKit.block(map, CFrame.new((w0 + w1) / 2, -depth / 2, 0), Vector3.new(w1 - w0, depth, (hz + 40) * 2), C.Grass, Enum.Material.Grass).Name = "Ground"
	PropKit.block(map, CFrame.new((e0 + e1) / 2, -depth / 2, 0), Vector3.new(e1 - e0, depth, (hz + 40) * 2), C.Grass, Enum.Material.Grass).Name = "Ground"
	PropKit.block(map, CFrame.new((river.X0 + river.X1) / 2, -river.Depth - 1, 0), Vector3.new(river.X1 - river.X0, 2, (hz + 40) * 2), C.Dirt, Enum.Material.Mud).Name = "Riverbed"
	workspace.Terrain:FillBlock(
		CFrame.new((river.X0 + river.X1) / 2, -river.Depth / 2 - 0.5, 0),
		Vector3.new(river.X1 - river.X0, river.Depth - 1, (hz + 40) * 2),
		Enum.Material.Water
	)

	-- Manchas de grama e terra para quebrar a uniformidade
	local rng = Random.new(42)
	for _ = 1, 70 do
		local x = rng:NextNumber(-hx, hx)
		if x < river.X0 - 12 or x > river.X1 + 12 then
			local w, d = rng:NextNumber(16, 50), rng:NextNumber(16, 50)
			PropKit.block(map, CFrame.new(x, 0.02, rng:NextNumber(-hz, hz)), Vector3.new(w, 0.05, d), if rng:NextNumber() < 0.75 then C.GrassDark else C.Dirt, Enum.Material.Grass, true)
		end
	end

	-- Piso urbano (calçamento cinza) na cidade e no pátio militar de cada base:
	-- tira o "gramado infinito" e deixa a grama só nos parques e no campo.
	PropKit.block(map, CFrame.new(0, 0.03, 0), Vector3.new(232, 0.06, 600), C.Pavement, Enum.Material.Pavement, true).Name = "UrbanGround"

	-- Ruas
	PropKit.road(map, Vector3.new(0, 0, 0), 600, 18, true) -- avenida central N-S
	PropKit.road(map, Vector3.new(-82, 0, 0), 436, 14, false) -- boulevard até a ponte central
	for _, z in { -160, -80, 80, 160 } do
		PropKit.road(map, Vector3.new(0, 0, z), 224, 12, false)
	end
	for _, z in { -80, 80 } do
		PropKit.road(map, Vector3.new(-205, 0, z), 190, 12, false) -- acesso industrial
	end
	for _, x in { -60, 60 } do
		PropKit.road(map, Vector3.new(x, 0, 0), 400, 10, true)
	end
	-- estradas de terra no campo
	PropKit.block(map, CFrame.new(232, 0.05, 0), Vector3.new(136, 0.1, 10), C.Dirt, Enum.Material.Ground, true)
	for _, z in { -151, 151 } do
		PropKit.block(map, CFrame.new(123, 0.05, z), Vector3.new(30, 0.1, 10), C.Dirt, Enum.Material.Ground, true)
		PropKit.block(map, CFrame.new(220, 0.05, z), Vector3.new(120, 0.1, 10), C.Dirt, Enum.Material.Ground, true)
	end
	-- pátio industrial de concreto
	PropKit.block(map, CFrame.new(-205, 0.06, 0), Vector3.new(150, 0.12, 60), Color3.fromRGB(150, 150, 156), Enum.Material.Concrete, true)

	PropKit.boundary(map, hx, hz)
end

function MapManager.buildStatic()
	local map = folder("Map")
	local spawns = folder("SpawnPoints")
	local scratch = Instance.new("Folder") -- estruturas não são criadas aqui

	buildGround(map)

	for _, mode in { "Blue", "Red" } do
		local ctx = makeContext(mode, map, scratch)
		ctx.struct = function() end -- estático apenas
		for _, pos in MapLayout.Spawns do
			makeSpawn(mode, ctx.cf(pos.X, pos.Y, pos.Z, 180), spawns)
		end
	end
	scratch:Destroy()
	applyEnvironment()
end

local propsBuilt = false

--[[
	Estruturas destrutíveis. Chamado a cada partida (o mapa volta inteiro).
	O MapLayout descreve estruturas e cenário juntos; o cenário vai para
	Workspace.MapProps só na primeira vez (nas seguintes vai para uma pasta
	temporária fora do Workspace e é descartado).
]]
function MapManager.buildDestructibles()
	DestructionManager.reset()
	local destructibles = folder("DestructibleObjects")
	local props: Instance
	if propsBuilt then
		props = Instance.new("Folder")
	else
		props = folder("MapProps")
	end
	for _, mode in { "Blue", "Red" } do
		MapLayout.buildSide(makeContext(mode, props, destructibles))
		task.wait()
	end
	MapLayout.buildCenter(makeContext("Center", props, destructibles))
	if propsBuilt then
		props:Destroy()
	end
	propsBuilt = true
end

function MapManager.init()
	MapManager.buildStatic()
	MapManager.buildDestructibles()
end

return MapManager
