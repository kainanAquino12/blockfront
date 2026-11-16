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
local EdificioCentral = require(script.Parent.Parent.Map.Buildings.EdificioCentral)
local TerrainGen = require(script.Parent.Parent.Map.TerrainGen)
local BuildingKit = require(script.Parent.Parent.Map.BuildingKit)
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
		local origin
		if mirrored then
			origin = CFrame.new(x, y or 0, -(z + def.Size.Z))
			def = BuildingKit.flipZ(def) -- Fill e ElementOf espelhados em z
		else
			origin = CFrame.new(x, y or 0, z)
		end
		local fill, elementOf = def.Fill, def.ElementOf
		DestructionManager.createStructure({
			Name = mode .. "_" .. name,
			Origin = origin,
			Size = def.Size,
			Fill = fill,
			Elements = def.Elements,
			ElementOf = elementOf,
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
	-- V6: céu fechado de zona de guerra (sem assets externos)
	Lighting.ClockTime = 16.3
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(70, 72, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(108, 108, 112)
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
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(178, 176, 170)
	atmosphere.Decay = Color3.fromRGB(112, 102, 94)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 2.3
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.18
	cc.Contrast = 0.15
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
	clouds.Cover = 0.84
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(176, 174, 170)
	clouds.Parent = terrain
	terrain.WaterColor = Color3.fromRGB(58, 74, 70)
	terrain.WaterTransparency = 0.75
	terrain.WaterReflectance = 0.3
	terrain.WaterWaveSize = 0.08
end

local function buildGround(map: Instance)
	-- Relevo V5 (Terrain do Roblox): colinas, vala, cume leste, platôs e estradas.
	local seconds = TerrainGen.build()
	print(("[BLOCKFRONT] Terreno gerado em %.2f s"):format(seconds))
	PropKit.boundary(map, MapLayout.HalfX, MapLayout.HalfZ)
end

-- Chão da área de demonstração (estático).
local function buildDemoGround(map: Instance)
	local demo = GameConfig.DemoArea
	if not demo or not demo.Enabled then
		return
	end
	local o = demo.Origin
	local fp = EdificioCentral.Footprint
	local center = o + Vector3.new(fp.X / 2, 0, fp.Y / 2)
	local ground = PropKit.block(map, CFrame.new(center.X, -0.5, center.Z - 20), Vector3.new(160, 1, 160), Color3.fromRGB(96, 98, 98), Enum.Material.Concrete, false)
	ground.Name = "DemoGround"
	local road = PropKit.block(map, CFrame.new(center.X, 0.03, o.Z - 18), Vector3.new(160, 0.06, 20), Color3.fromRGB(52, 54, 58), Enum.Material.Asphalt, true)
	road.Name = "DemoRoad"
end

-- Prédio de demonstração (estrutura com grafo estrutural).
local function buildDemoBuilding(destructibles: Instance)
	local demo = GameConfig.DemoArea
	if not demo or not demo.Enabled then
		return
	end
	local def = EdificioCentral.build()
	local m = EdificioCentral.Margin
	local s = DestructionManager.createStructure({
		Name = "Demo_EdificioCentral",
		Origin = CFrame.new(demo.Origin - Vector3.new(m, 0, m)),
		Size = def.Size,
		Fill = def.Fill,
		Elements = def.Elements,
		ElementOf = def.ElementOf,
		Parent = destructibles,
	})
	return s
end
MapManager.buildDemoBuilding = buildDemoBuilding

function MapManager.buildStatic()
	local map = folder("Map")
	local spawns = folder("SpawnPoints")
	local scratch = Instance.new("Folder") -- estruturas não são criadas aqui

	buildGround(map)
	buildDemoGround(map)

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
--[[
	Organização no Explorer: as estruturas vão para subpastas por distrito
	dentro de DestructibleObjects (o nome da pasta-mãe é usado por scripts
	e não muda).
]]
local DISTRICTS = {
	{ "Map_Bridges", { "Ponte" } },
	{ "Map_CentralDistrict", { "Torre", "Edificio", "PredioAbandonado", "CentroComercial", "Posto", "Praca" } },
	{ "Map_IndustrialZone", { "Industria", "Porto", "Deposito", "ParqueTanques" } },
	{ "Map_SuburbsAndTrenches", { "Suburbio", "Trincheira", "QG", "Campo" } },
	{ "Map_SpawnAndObjectives", { "Base" } },
}
local function organizeDistricts(destructibles: Instance)
	local folders = {}
	for _, d in DISTRICTS do
		local f = destructibles:FindFirstChild(d[1]) or Instance.new("Folder")
		f.Name = d[1]
		f.Parent = destructibles
		folders[d[1]] = f
	end
	for _, m in destructibles:GetChildren() do
		if m:IsA("Model") then
			for _, d in DISTRICTS do
				local hit = false
				for _, key in d[2] do
					if string.find(m.Name, key, 1, true) then
						hit = true
						break
					end
				end
				if hit then
					m.Parent = folders[d[1]]
					break
				end
			end
		end
	end
end

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
	organizeDistricts(destructibles)
	task.wait()
	buildDemoBuilding(destructibles)
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
