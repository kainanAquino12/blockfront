--[[
	MapLayout (servidor) — mapa V5/V6 "Front Bloco: Campo Aberto" (V6: porto, canal, subúrbio,
	residenciais e prédio abandonado; 960 x 880 studs).
	Plano completo em docs/MAPA_V5.md (imagem: docs/mapa_v5_plano.png).

	640 x 880 studs. Azul ao sul (z < 0), vermelho ao norte. O relevo vem do
	TerrainGen (simétrico em z). O lado azul é descrito uma vez e espelhado
	em z = 0 pelo MapManager; buildCenter descreve o que fica sobre z = 0.

	Regiões:
	  bases         platô +12 nas pontas (z = ±360)
	  campos        colinas suaves entre as bases e o centro
	  vala          riacho seco em z = ±185 com pontes destrutíveis
	  centro (B)    praça, Torres Comerciais N/S, Edifício Administrativo
	  indústria (A) complexo industrial a oeste
	  cume (C)      QG militar no topo do cume leste (+26)

	API do contexto (ctx), fornecido pelo MapManager:
	  ctx.struct(name, x, z, def, y?) estrutura destrutível, canto mínimo (x, y, z)
	  ctx.cf(x, y, z, yawDeg?)      CFrame no referencial deste lado
	  ctx.pos(x, y, z)              Vector3 no referencial deste lado
	  ctx.static                    pasta do cenário estático
	  ctx.team / ctx.color          time deste lado
]]

local StructureKit = require(script.Parent.StructureKit)
local TerrainGen = require(script.Parent.TerrainGen)
local Ponte = require(script.Parent.Buildings.Ponte)
local EdificioCentral = require(script.Parent.Buildings.EdificioCentral)
local BuildingKit = require(script.Parent.BuildingKit)
local Admin = require(script.Parent.Buildings.EdificioAdministrativo)
local Industrial = require(script.Parent.Buildings.ComplexoIndustrial)
local QGMilitar = require(script.Parent.Buildings.QGMilitar)
local Residencial = require(script.Parent.Buildings.EdificioResidencial)
local Porto = require(script.Parent.Buildings.Porto)

---------------------------------------------------------------------------
-- Entulho estático (clima de combate): blocos de concreto e tijolo caídos.
-- Ancorados, sem física; poucos por pilha para não pesar.
---------------------------------------------------------------------------
local RUBBLE_COLORS = {
	{ Color3.fromRGB(122, 122, 118), Enum.Material.Concrete },
	{ Color3.fromRGB(110, 108, 102), Enum.Material.Concrete },
	{ Color3.fromRGB(138, 76, 60), Enum.Material.Brick },
	{ Color3.fromRGB(62, 66, 72), Enum.Material.Metal },
}
local function rubblePile(ctx, x: number, z: number, radius: number, count: number, seed: number)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Entulho"
	local y0 = TerrainGen.height(x, z)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = radius * math.sqrt(rng:NextNumber())
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		local s = rng:NextNumber(0.8, 2.6) * (1 - d / radius * 0.5)
		local size = Vector3.new(s * rng:NextNumber(0.8, 1.6), s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.8, 1.6))
		local look = RUBBLE_COLORS[rng:NextInteger(1, #RUBBLE_COLORS)]
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.Color = look[1]
		p.Material = look[2]
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local cf = CFrame.new(px, y0 + size.Y * 0.35 + (1 - d / radius) * radius * 0.25, pz)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5))
		p.CFrame = ctx.cf(0, 0, 0) * cf -- ctx.cf espelha no lado vermelho
		p.Parent = model
	end
	model.Parent = ctx.static
	return model
end

-- Fumaça de prédio em chamas (efeito simples do Roblox, sem assets).
local function smoke(ctx, x: number, y: number, z: number)
	local p = Instance.new("Part")
	p.Name = "Fumaca"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 1, 4)
	p.CFrame = ctx.cf(x, y, z)
	local s = Instance.new("Smoke")
	s.Color = Color3.fromRGB(58, 56, 54)
	s.Opacity = 0.35
	s.RiseVelocity = 9
	s.Size = 14
	s.TimeScale = 0.6
	s.Parent = p
	p.Parent = ctx.static
end
local M = StructureKit.Materials

local MapLayout = {}

MapLayout.HalfX = TerrainGen.HalfX
MapLayout.HalfZ = TerrainGen.HalfZ

local BASE_Y = TerrainGen.BaseHeight

-- Pontos de nascimento da equipe azul (vermelho espelhado). Orientados para o norte.
MapLayout.Spawns = {
	Vector3.new(0, BASE_Y + 0.5, -372),
	Vector3.new(-24, BASE_Y + 0.5, -366),
	Vector3.new(24, BASE_Y + 0.5, -366),
	Vector3.new(-44, BASE_Y + 0.5, -352),
	Vector3.new(44, BASE_Y + 0.5, -352),
}

-- Altura do chão (para posicionar estruturas em cima do terreno).
local function ground(x: number, z: number): number
	return math.floor(TerrainGen.height(x, z) + 0.5)
end

---------------------------------------------------------------------------
-- Pontes sobre a vala (avenida e estrada industrial)
---------------------------------------------------------------------------

local function buildBridges(ctx)
	local v = TerrainGen.Valley
	local length = v.HalfWidth * 2 + 12
	for _, r in { { x = 0, w = 18, name = "PonteAvenida" }, { x = -170, w = 12, name = "PonteIndustrial" } } do
		local floorY = math.floor(TerrainGen.height(r.x, -v.Z)) - 1
		local deckTop = TerrainGen.bridgeDeckHeight(r.x)
		local def = Ponte.build(r.w, length, deckTop - floorY)
		local x0 = r.x - math.floor((r.w + 2) / 2)
		local z0 = -v.Z - math.floor(length / 2)
		ctx.struct(r.name, x0, z0, def, floorY)
	end
end

---------------------------------------------------------------------------
-- Base (só o essencial: muros baixos de proteção do renascimento)
---------------------------------------------------------------------------

local function buildBase(ctx)
	local y = BASE_Y
	ctx.struct("BaseMuroO", -62, -344, StructureKit.wall(16, 3, 2, M.Concrete, M.Military, true), y)
	ctx.struct("BaseMuroL", 46, -344, StructureKit.wall(16, 3, 2, M.Concrete, M.Military, true), y)
	ctx.struct("BaseSacos1", -30, -330, StructureKit.sandbags(10, 3), y)
	ctx.struct("BaseSacos2", 20, -330, StructureKit.sandbags(10, 3), y)
end

---------------------------------------------------------------------------
-- Campos: poucas coberturas pesadas (nada de enfeite)
---------------------------------------------------------------------------

local function buildFields(ctx)
	for _, c in {
		{ "CampoBarreira1", -120, -250, 8 },
		{ "CampoBarreira2", 70, -240, 8 },
		{ "CampoBarreira3", -40, -150, 7 },
		{ "CampoBarreira4", 150, -290, 7 },
	} do
		ctx.struct(c[1], c[2], c[3], StructureKit.barrier(c[4]), ground(c[2], c[3]))
	end
end

---------------------------------------------------------------------------
-- Centro: Torre Comercial (10 andares). No lado azul fica ao sul da praça B,
-- virada de frente para o norte (entrada e marquise voltadas para a praça).
---------------------------------------------------------------------------

local CENTER_Y = 2

local function buildTower(ctx)
	local def = BuildingKit.flipZ(EdificioCentral.build({ Floors = 10 }))
	local m = EdificioCentral.Margin
	ctx.struct("TorreComercial", -48 - m, -112 - m, def, CENTER_Y)
end

---------------------------------------------------------------------------
-- V6: expansão (residencial, pontes do canal, subúrbio e linha de frente)
---------------------------------------------------------------------------

local function buildExpansion(ctx)
	-- Edifício Residencial (8 andares) a oeste da praça, portaria voltada para o norte
	local m = Residencial.Margin
	ctx.struct("EdificioResidencial", -135 - m, -104 - m, BuildingKit.flipZ(Residencial.build({ Floors = 8 })), CENTER_Y)
	ctx.yield()

	-- pontes sobre o canal (atravessam no eixo x)
	local cn = TerrainGen.Canal
	local length = cn.HalfWidth * 2 + 12
	for _, r in { { z = -150, w = 14, name = "PonteCanalPorto" }, { z = -300, w = 12, name = "PonteCanalSul" } } do
		local floorY = cn.Bottom - 1
		local deckTop = TerrainGen.canalDeckHeight(r.z)
		local def = BuildingKit.swapXZ(Ponte.build(r.w, length, deckTop - floorY))
		ctx.struct(r.name, cn.X - math.floor(length / 2), r.z - math.floor((r.w + 2) / 2), def, floorY)
	end
	ctx.yield()

	-- subúrbio: prédio de apartamentos de 4 andares (concreto pintado)
	local sy = math.floor(TerrainGen.height(437, -123) + 0.5)
	ctx.struct("Suburbio_Apartamentos", 420 - m, -140 - m, Residencial.build({ Floors = 4, Wall = "PaintedConcrete" }), sy)
	-- linha de frente: muros baixos, sacos de areia e barreiras no subúrbio e nos campos
	for _, c in {
		{ "Suburbio_Muro1", 370, -60, StructureKit.wall(14, 3, 1, M.Brick, M.Concrete, false) },
		{ "Suburbio_Muro2", 440, -200, StructureKit.wall(12, 3, 1, M.Concrete, M.Concrete, false) },
		{ "Suburbio_Sacos1", 384, -100, StructureKit.sandbags(10, 3) },
		{ "Suburbio_Sacos2", 352, -170, StructureKit.sandbags(8, 3) },
		{ "Trincheira_Sacos1", 300, -96, StructureKit.sandbags(8, 3) },
		{ "Porto_Barreira", -420, -150 + 10, StructureKit.barrier(8) },
	} do
		ctx.struct(c[1], c[2], c[3], c[4], math.floor(TerrainGen.height(c[2], c[3]) + 0.5))
	end
	ctx.yield()

	-- entulho e fumaça (clima de combate desde o início)
	rubblePile(ctx, -60, -60, 9, 22, 11)
	rubblePile(ctx, -118, -128, 8, 18, 12)
	rubblePile(ctx, 20, -150, 7, 14, 13)
	rubblePile(ctx, 400, -90, 8, 16, 14)
	rubblePile(ctx, -300, -150, 7, 14, 15)
	smoke(ctx, -27, 92, -97)
end

function MapLayout.buildSide(ctx)
	buildTower(ctx)
	ctx.yield()
	buildExpansion(ctx)
	ctx.yield()
	buildBase(ctx)
	ctx.yield()
	buildBridges(ctx)
	ctx.yield()
	buildFields(ctx)
end

-- Sobre o eixo z = 0 (não espelhadas; a volumetria é simétrica em z).
function MapLayout.buildCenter(ctx)
	-- B: Edifício Administrativo a leste da praça (fachada com pórtico voltada para oeste)
	ctx.struct("EdificioAdministrativo", 40 - Admin.WestMargin, -40 - Admin.Margin, Admin.build(), CENTER_Y)
	ctx.yield()
	-- A: Complexo Industrial (nave x -290..-215, anexo a leste)
	ctx.struct("ComplexoIndustrial", -290 - Industrial.Margin, -42 - Industrial.Margin, Industrial.build(), 0)
	ctx.yield()
	-- V6: prédio residencial ABANDONADO (7 andares, quina desabada) entre a praça e a indústria
	local rm = Residencial.Margin
	ctx.struct("PredioAbandonado", -122 - rm, -17 - rm, Residencial.build({ Floors = 7, Damaged = true }), CENTER_Y)
	rubblePile(ctx, -92, 22, 10, 28, 21) -- escombros da quina que caiu
	smoke(ctx, -95, 50, 10)
	ctx.yield()
	-- V6: porto (armazém, pórtico de carga e silos) além do canal
	ctx.struct("Porto", -478 - Porto.Margin, -80 - Porto.Margin, Porto.build(), 1)
	ctx.yield()
	-- C: QG Militar no topo do cume (pátio centrado em x ~234, z ~0)
	ctx.struct("QGMilitar", 206 - QGMilitar.Margin, -28 - QGMilitar.Margin, QGMilitar.build(), TerrainGen.RidgeHeight)
end

return MapLayout
