--[[
	MapLayout (servidor) — mapa "Front Bloco", arena principal do modo CONQUISTA.

	Área jogável: 600 x 780 studs. Bases nas pontas (azul ao sul, z < 0;
	vermelho ao norte). Três pontos de captura em z = 0:
	  A  (-200, 0)  pátio de contêineres na zona INDUSTRIAL (oeste)
	  B  (   0, 0)  praça com chafariz no centro da CIDADE
	  C  ( 215, 0)  fazenda do outro lado do rio, no CAMPO (leste)

	Regiões (de oeste para leste):
	  indústria  galpões, silos, guindaste, tubulações, contêineres
	  cidade     quarteirões com prédios de 3 a 6 andares, lojas, casas,
	             avenida central, ruas transversais, calçadas, carros
	  rio        atravessa o mapa de norte a sul; 3 pontes destrutíveis
	  campo      celeiros, sede da fazenda, plantações, colinas em degraus
	  militar    bases com QG, garagens, torres, barracas; postos avançados
	             com bunker e barricadas na avenida

	O layout de um lado (azul) é descrito uma vez e espelhado no plano
	z = 0 para o lado vermelho (MapManager). buildCenter descreve o que
	fica sobre z = 0 e não é espelhado.

	API do contexto (ctx), fornecido pelo MapManager:
	  ctx.struct(name, x, z, def, y?) estrutura destrutível, canto mínimo (x, y, z)
	  ctx.cf(x, y, z, yawDeg?)      CFrame no referencial deste lado
	  ctx.pos(x, y, z)              Vector3 no referencial deste lado
	  ctx.static                    pasta do cenário estático
	  ctx.team / ctx.color          time deste lado
]]

local StructureKit = require(script.Parent.StructureKit)
local PropKit = require(script.Parent.PropKit)
local M = StructureKit.Materials
-- Prédios usam a fachada com profundidade (V3). Prédios de 3+ andares ganham
-- guarda-corpos na face da primeira porta; casas com telhado de duas águas
-- ganham embasamento e pilastras de tijolo escuro.
local function B(o)
	if o.Floors >= 3 and o.Balconies == nil then
		o.Balconies = o.Doors and o.Doors[1]
	end
	if o.Gable and o.Accent == nil then
		o.Accent = M.DarkBrick
	end
	return StructureKit.facadeBuilding(o)
end

local MapLayout = {}

MapLayout.HalfX = 300
MapLayout.HalfZ = 390
MapLayout.River = { X0 = 140, X1 = 160, Depth = 6 }

-- Pontos de nascimento da equipe azul (vermelho espelhado). Orientados para o norte.
MapLayout.Spawns = {
	Vector3.new(0, 0.5, -352),
	Vector3.new(-22, 0.5, -346),
	Vector3.new(22, 0.5, -346),
	Vector3.new(-40, 0.5, -326),
	Vector3.new(40, 0.5, -326),
}

local CAR_COLORS = {
	Color3.fromRGB(214, 62, 52),
	Color3.fromRGB(58, 112, 200),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(250, 196, 60),
	Color3.fromRGB(70, 160, 110),
	Color3.fromRGB(40, 42, 50),
}

---------------------------------------------------------------------------
-- Cidade
---------------------------------------------------------------------------

local function buildCity(ctx)
	local s = ctx.static

	-- Quarteirão 1 (de frente para a praça)
	ctx.struct("TorrePraca", -50, -72, B({ SizeX = 20, SizeZ = 16, Floors = 5, Wall = M.Brick, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N", "S" }, RoofAccess = true, RoofProps = true, Partition = true }))
	ctx.struct("LojaPraca", -27, -50, B({ SizeX = 14, SizeZ = 10, Floors = 1, Wall = M.PlasterYellow, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N" }, ShopFront = "N", WoodDoors = { "S" } }))
	ctx.struct("EdificioAzul", 14, -70, B({ SizeX = 18, SizeZ = 14, Floors = 3, Wall = M.PaintedConcrete, Trim = M.Concrete, Roof = M.RoofGreen, Doors = { "N", "W" }, RoofAccess = true, Partition = true }))
	ctx.struct("Cafe", 36, -50, B({ SizeX = 14, SizeZ = 10, Floors = 1, Wall = M.PlasterGreen, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N" }, ShopFront = "N" }))
	ctx.struct("CasaOeste1", -106, -64, B({ SizeX = 12, SizeZ = 10, Floors = 2, Wall = M.Plaster, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "N" }, WoodDoors = { "S" }, Gable = true }))
	ctx.struct("CasaOeste2", -88, -62, B({ SizeX = 12, SizeZ = 10, Floors = 1, Wall = M.PlasterYellow, Trim = M.Concrete, Roof = M.RoofTile, Doors = { "N" }, Gable = true }))
	ctx.struct("GaragemLeste", 72, -60, StructureKit.garage(10, 9))
	ctx.struct("CasaLeste1", 90, -68, B({ SizeX = 14, SizeZ = 10, Floors = 2, Wall = M.DarkBrick, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "N", "W" }, Gable = true }))

	-- Quarteirão 2
	ctx.struct("TorreTijolo", -50, -124, B({ SizeX = 20, SizeZ = 18, Floors = 5, Wall = M.DarkBrick, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N", "E" }, RoofAccess = true, RoofProps = true, Partition = true }))
	ctx.struct("Predio3", -28, -148, B({ SizeX = 16, SizeZ = 14, Floors = 3, Wall = M.Plaster, Trim = M.Concrete, Roof = M.Concrete, Doors = { "E", "N" }, RoofAccess = true, RoofProps = true }))
	ctx.struct("Escritorios", 16, -134, B({ SizeX = 18, SizeZ = 18, Floors = 6, Wall = M.PaintedConcrete, Trim = M.Concrete, Roof = M.Concrete, Doors = { "W", "N" }, WindowSpacing = 3, RoofAccess = true, RoofProps = true }))
	ctx.struct("Mercado", 38, -102, B({ SizeX = 14, SizeZ = 11, Floors = 1, Wall = M.PlasterYellow, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N", "W" }, ShopFront = "N" }))
	ctx.struct("CasaOeste3", -106, -112, B({ SizeX = 12, SizeZ = 10, Floors = 2, Wall = M.PlasterGreen, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "E" }, Gable = true }))
	ctx.struct("CasaOeste4", -90, -140, B({ SizeX = 12, SizeZ = 10, Floors = 1, Wall = M.Brick, Trim = M.Concrete, Roof = M.RoofGreen, Doors = { "N", "E" } }))
	ctx.struct("CasaLeste2", 72, -112, B({ SizeX = 12, SizeZ = 10, Floors = 2, Wall = M.PlasterGreen, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "W" }, WoodDoors = { "N" }, Gable = true }))
	ctx.struct("PredioLeste", 88, -146, B({ SizeX = 16, SizeZ = 14, Floors = 3, Wall = M.Brick, Trim = M.Concrete, Roof = M.Concrete, Doors = { "W", "N" }, RoofAccess = true }))

	-- Quarteirão 3 (perto do posto avançado)
	ctx.struct("Oficina", -50, -198, StructureKit.garage(14, 10))
	ctx.struct("Loja3", -30, -198, B({ SizeX = 14, SizeZ = 10, Floors = 1, Wall = M.PlasterGreen, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N", "E" }, ShopFront = "N" }))
	ctx.struct("Predio4", 22, -202, B({ SizeX = 18, SizeZ = 14, Floors = 3, Wall = M.DarkBrick, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N", "W" }, RoofAccess = true, RoofProps = true }))
	ctx.struct("CasaLeste3", 74, -196, B({ SizeX = 12, SizeZ = 10, Floors = 2, Wall = M.Plaster, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "N" }, Gable = true }))

	-- Coberturas na rua
	ctx.struct("PracaMuroL", -24, -36, StructureKit.wall(10, 4, 1, M.Brick, M.Concrete, false))
	ctx.struct("PracaMuroR", 14, -36, StructureKit.wall(10, 4, 1, M.Brick, M.Concrete, false))
	ctx.struct("PracaBarreira", -4, -22, StructureKit.barrier(8))
	ctx.struct("RuaSacos", -7, -112, StructureKit.sandbags(10, 3))
	ctx.struct("RuaBarreira1", 2, -92, StructureKit.barrier(7))
	ctx.struct("RuaCaixotes", -60, -100, StructureKit.crates(6, 6))

	-- Calçadas, árvores, postes, semáforos, faixas, carros e mobiliário
	-- calçadas da avenida, interrompidas nos cruzamentos (z = -80 e -160)
	for _, seg in { { -33, -73 }, { -87, -153 }, { -167, -296 } } do
		local len = seg[1] - seg[2]
		local zc = (seg[1] + seg[2]) / 2
		PropKit.sidewalk(s, ctx.cf(-11, 0, zc), Vector2.new(4, len))
		PropKit.sidewalk(s, ctx.cf(11, 0, zc), Vector2.new(4, len))
	end
	for z = -44, -290, -22 do
		if math.abs(z + 80) > 10 and math.abs(z + 160) > 10 then
			PropKit.tree(s, ctx.cf(-11, 0.4, z, z % 90), 0.7)
			PropKit.tree(s, ctx.cf(11, 0.4, z - 11, z % 70), 0.7)
		end
	end
	for _, z in { -60, -120, -190, -250 } do
		PropKit.lamp(s, ctx.cf(11.5, 0.4, z, -90))
		PropKit.lamp(s, ctx.cf(-11.5, 0.4, z + 15, 90))
	end
	for _, z in { -80, -160 } do
		PropKit.trafficLight(s, ctx.cf(10.5, 0.4, z + 8, 90))
		PropKit.trafficLight(s, ctx.cf(-10.5, 0.4, z - 8, -90))
		PropKit.crosswalk(s, ctx.cf(0, 0, z + 9), 16)
		PropKit.crosswalk(s, ctx.cf(0, 0, z - 9), 16)
	end
	local carSpots = {
		{ 6, -60, 0 }, { -6, -138, 180 }, { 5, -205, 0 }, { -30, -77, 90 }, { 40, -84, 90 },
		{ -80, -155, 90 }, { 90, -163, 90 }, { 64, -130, 0 }, { -64, -60, 0 },
	}
	for i, c in carSpots do
		PropKit.car(s, ctx.cf(c[1], 0, c[2], c[3]), CAR_COLORS[(i - 1) % #CAR_COLORS + 1])
	end
	for _, b in { { -16, -46, 0 }, { 16, -46, 0 }, { -40, -88, 0 } } do
		PropKit.bench(s, ctx.cf(b[1], 0.4, b[2], b[3]))
	end
	PropKit.hydrant(s, ctx.cf(12.5, 0.4, -100))
	PropKit.hydrant(s, ctx.cf(-12.5, 0.4, -176))
	PropKit.trashBin(s, ctx.cf(12.5, 0.4, -70))
	PropKit.trashBin(s, ctx.cf(-12.5, 0.4, -128))
	PropKit.planter(s, ctx.cf(-32, 0, -36), 8)
	PropKit.planter(s, ctx.cf(32, 0, -36), 8)
	PropKit.billboard(s, ctx.cf(60, 0, -215, 0), "BLOCKFRONT", Color3.fromRGB(40, 44, 60))
end

---------------------------------------------------------------------------
-- Indústria (oeste)
---------------------------------------------------------------------------

local function buildIndustry(ctx)
	local s = ctx.static
	ctx.struct("GalpaoGrande", -262, -88, StructureKit.warehouse(36, 24, 14))
	ctx.struct("GalpaoMedio", -190, -136, StructureKit.warehouse(30, 20, 12))
	ctx.struct("Deposito", -282, -186, StructureKit.warehouse(24, 18, 10, M.Brick))
	ctx.struct("Escritorio", -150, -186, B({ SizeX = 16, SizeZ = 12, Floors = 2, Wall = M.Concrete, Trim = M.Military, Roof = M.Concrete, Doors = { "N", "W" }, RoofAccess = true, RoofProps = true }))
	ctx.struct("TorreInd", -128, -104, StructureKit.watchtower())
	ctx.struct("IndCaixotes1", -220, -52, StructureKit.crates(6, 6))
	ctx.struct("IndCaixotes2", -168, -84, StructureKit.crates(6, 9))
	ctx.struct("IndBarreira", -240, -126, StructureKit.barrier(10))
	ctx.struct("IndMuro", -300, -240, StructureKit.wall(40, 5, 1, M.Concrete, M.Military, true))

	PropKit.silo(s, ctx.cf(-140, 0, -60), 26)
	PropKit.silo(s, ctx.cf(-128, 0, -76), 22)
	PropKit.crane(s, ctx.cf(-250, 0, -30))
	PropKit.pipe(s, ctx.pos(-226, 0, -60), ctx.pos(-226, 0, -112), 10)
	PropKit.pipe(s, ctx.pos(-226, 0, -112), ctx.pos(-190, 0, -112), 10)
	local containerColors = { Color3.fromRGB(196, 92, 52), Color3.fromRGB(64, 120, 168), Color3.fromRGB(96, 140, 84), Color3.fromRGB(210, 170, 60) }
	local containers = {
		{ -214, -26, 0 }, { -184, -30, 90 }, { -246, -16, 90 }, { -200, -66, 0 }, { -278, -122, 0 },
		{ -278, -114, 0 }, { -160, -230, 90 }, { -250, -230, 0 }, { -134, -146, 90 },
	}
	for i, c in containers do
		PropKit.container(s, ctx.cf(c[1], 0, c[2], c[3]), containerColors[(i - 1) % #containerColors + 1])
	end
	-- pilha de dois contêineres
	PropKit.container(s, ctx.cf(-278, 8, -118, 0), containerColors[2])
	PropKit.truck(s, ctx.cf(-170, 0, -56, 90))
	PropKit.truck(s, ctx.cf(-292, 0, -150, 0))
	PropKit.billboard(s, ctx.cf(-120, 0, -250, 30), "FABRICA", Color3.fromRGB(150, 70, 50))
end

---------------------------------------------------------------------------
-- Campo (leste do rio)
---------------------------------------------------------------------------

local function buildCountryside(ctx)
	local s = ctx.static
	ctx.struct("Celeiro", 196, -50, StructureKit.warehouse(26, 16, 10, M.BarnWood))
	ctx.struct("SedeFazenda", 238, -34, B({ SizeX = 14, SizeZ = 12, Floors = 2, Wall = M.Plaster, Trim = M.Wood, Slab = M.Wood, Roof = M.RoofTile, Doors = { "N", "W" }, WoodDoors = { "S" }, Gable = true }))
	ctx.struct("Feno1", 206, -18, StructureKit.hay(6, 4))
	ctx.struct("Feno2", 228, -12, StructureKit.hay(4, 6))
	ctx.struct("MuroPedra", 180, -26, StructureKit.wall(12, 3, 1, M.Concrete, nil, true))
	ctx.struct("TorreCampo", 176, -118, StructureKit.watchtower())
	ctx.struct("Silo2", 262, -110, StructureKit.warehouse(18, 12, 8, M.Wood))
	ctx.struct("CampoSacos", 236, -80, StructureKit.sandbags(10, 3))
	ctx.struct("Ponte2", 136, -156, StructureKit.bridge(28, 10, 6), -6)

	PropKit.crops(s, ctx.cf(250, 0, -150), 50, 30)
	PropKit.crops(s, ctx.cf(205, 0, -210), 40, 40)
	PropKit.hill(s, ctx.cf(278, 0, -60), 40, 50, 4)
	PropKit.hill(s, ctx.cf(230, 0, -270), 60, 40, 5)
	PropKit.hill(s, ctx.cf(290, 0, -190), 30, 40, 3)
	PropKit.fence(s, ctx.pos(180, 0, -70), ctx.pos(260, 0, -70))
	PropKit.fence(s, ctx.pos(180, 0, -130), ctx.pos(180, 0, -190))
	for z = -20, -300, -40 do
		PropKit.powerPole(s, ctx.cf(168, 0, z))
	end
	for _, t in { { 290, -20, 1.2 }, { 170, -240, 1.1 }, { 290, -300, 1.3 }, { 220, -120, 1.0 }, { 260, -330, 1.1 }, { 185, -300, 0.9 } } do
		PropKit.tree(s, ctx.cf(t[1], 0, t[2], t[1] % 90), t[3])
	end
	for _, b in { { 200, -80 }, { 240, -95 }, { 275, -240 }, { 165, -60 } } do
		PropKit.bush(s, ctx.cf(b[1], 0, b[2]), 1.2)
	end
	PropKit.truck(s, ctx.cf(225, 0, -66, 90))
end

---------------------------------------------------------------------------
-- Área militar: base e posto avançado
---------------------------------------------------------------------------

local function buildMilitary(ctx)
	local s = ctx.static
	local wallColor = Color3.fromRGB(86, 92, 104)
	local color = ctx.color

	-- Piso e muros estáticos da base
	PropKit.block(s, ctx.cf(0, 0.15, -342), Vector3.new(160, 0.3, 84), PropKit.Colors.BaseFloor, Enum.Material.Concrete)
	PropKit.block(s, ctx.cf(0, 0.33, -302), Vector3.new(160, 0.05, 1.2), color, nil, true)
	PropKit.block(s, ctx.cf(0, 5, -385), Vector3.new(164, 10, 2), wallColor, Enum.Material.Concrete)
	PropKit.block(s, ctx.cf(-81, 5, -343), Vector3.new(2, 10, 84), wallColor, Enum.Material.Concrete)
	PropKit.block(s, ctx.cf(81, 5, -343), Vector3.new(2, 10, 84), wallColor, Enum.Material.Concrete)
	PropKit.block(s, ctx.cf(0, 8.5, -383.9), Vector3.new(164, 1.2, 0.2), color, nil, true)
	-- Letreiro do time
	local sign = PropKit.block(s, ctx.cf(0, 14, -384.5), Vector3.new(34, 6, 1), Color3.fromRGB(26, 30, 40))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = color
		text.Text = ctx.displayName
		text.Parent = gui
	end

	-- Muro frontal destrutível com três portões
	ctx.struct("BaseMuroL", -80, -301, StructureKit.gateWall(40, 5, M.Military, M.Concrete))
	ctx.struct("BaseMuroC", -40, -301, StructureKit.wall(28, 5, 1, M.Military, M.Concrete, true))
	ctx.struct("BaseMuroC2", 12, -301, StructureKit.wall(28, 5, 1, M.Military, M.Concrete, true))
	ctx.struct("BaseMuroR", 40, -301, StructureKit.gateWall(40, 5, M.Military, M.Concrete))

	-- QG, garagens, torres
	ctx.struct("QG", -14, -380, B({ SizeX = 28, SizeZ = 16, Floors = 2, Wall = M.Military, Trim = M.Concrete, Roof = M.Concrete, Doors = { "N" }, RoofAccess = true, RoofProps = true, Partition = true }))
	ctx.struct("GaragemBase1", -72, -350, StructureKit.garage(14, 12))
	ctx.struct("GaragemBase2", 58, -350, StructureKit.garage(14, 12))
	ctx.struct("TorreBaseL", -78, -312, StructureKit.watchtower())
	ctx.struct("TorreBaseR", 71, -312, StructureKit.watchtower())
	ctx.struct("BaseSacos1", -50, -318, StructureKit.sandbags(12, 3))
	ctx.struct("BaseSacos2", 38, -318, StructureKit.sandbags(12, 3))

	PropKit.tent(s, ctx.cf(-50, 0.3, -366, 90))
	PropKit.tent(s, ctx.cf(-34, 0.3, -366, 90))
	PropKit.tent(s, ctx.cf(40, 0.3, -368, 90))
	PropKit.truck(s, ctx.cf(-44, 0.3, -338, 0))
	PropKit.truck(s, ctx.cf(30, 0.3, -336, 0))
	PropKit.flag(s, ctx.cf(-70, 0.3, -380), color)
	PropKit.flag(s, ctx.cf(70, 0.3, -380), color)
	for _, x in { -60, 60 } do
		PropKit.hedgehog(s, ctx.cf(x, 0, -290))
		PropKit.hedgehog(s, ctx.cf(x + 6, 0, -294))
	end

	-- Posto avançado na avenida
	ctx.struct("PostoBunker", 14, -244, StructureKit.bunker(12, 8))
	ctx.struct("PostoTorre", -26, -246, StructureKit.watchtower())
	ctx.struct("PostoBarreira1", -8, -228, StructureKit.barrier(7))
	ctx.struct("PostoBarreira2", 2, -240, StructureKit.barrier(7))
	ctx.struct("PostoSacos", -40, -232, StructureKit.sandbags(10, 3))
	ctx.struct("PostoSacos2", 30, -226, StructureKit.sandbags(10, 3))
	PropKit.hedgehog(s, ctx.cf(-14, 0, -260))
	PropKit.hedgehog(s, ctx.cf(14, 0, -262))
	PropKit.truck(s, ctx.cf(-50, 0, -250, 90))
end

---------------------------------------------------------------------------
-- Vegetação e borda (lado)
---------------------------------------------------------------------------

local function buildNature(ctx)
	local s = ctx.static
	local trees = {
		{ -120, -40, 1.0 }, { -112, -200, 1.1 }, { -300, -60, 1.3 }, { -296, -300, 1.2 }, { -200, -300, 1.0 },
		{ -140, -280, 1.2 }, { 120, -40, 1.0 }, { 118, -120, 0.9 }, { 120, -230, 1.1 }, { -60, -280, 1.0 },
		{ 60, -280, 1.0 }, { 100, -290, 1.2 }, { -100, -290, 1.1 },
	}
	for _, t in trees do
		PropKit.tree(s, ctx.cf(t[1], 0, t[2], t[2] % 90), t[3])
	end
	for _, r in { { -300, -120, 1.5 }, { -230, -280, 1.2 }, { 120, -300, 1.4 }, { -70, -230, 1.0 } } do
		PropKit.rock(s, ctx.cf(r[1], 0, r[2], r[1] % 60), r[3])
	end
	for _, b in { { -116, -150, 1 }, { 116, -80, 1 }, { 116, -180, 1.1 }, { -60, -40, 0.8 }, { 60, -40, 0.8 } } do
		PropKit.bush(s, ctx.cf(b[1], 0, b[2]), b[3])
	end
end

-- Constrói tudo de um lado (chamado duas vezes: azul e vermelho espelhado).
function MapLayout.buildSide(ctx)
	buildCity(ctx)
	ctx.yield()
	buildIndustry(ctx)
	ctx.yield()
	buildCountryside(ctx)
	ctx.yield()
	buildMilitary(ctx)
	ctx.yield()
	buildNature(ctx)
end

---------------------------------------------------------------------------
-- Centro (sobre z = 0, não espelhado)
---------------------------------------------------------------------------

function MapLayout.buildCenter(ctx)
	local s = ctx.static
	-- Praça B
	PropKit.block(s, ctx.cf(0, 0.15, 0), Vector3.new(64, 0.3, 64), PropKit.Colors.Sidewalk, Enum.Material.Concrete)
	PropKit.fountain(s, ctx.cf(0, 0.3, 0))
	for _, p in { { -24, 0, 90 }, { 24, 0, -90 } } do
		PropKit.bench(s, ctx.cf(p[1], 0.3, p[2], p[3]))
	end
	-- Ponte central (sobre o rio, z = -5..5) e pátio A
	ctx.struct("PonteCentral", 136, -5, StructureKit.bridge(28, 10, 6), -6)
	ctx.struct("PatioCaixotes", -203, -3, StructureKit.crates(6, 6))
end

return MapLayout
