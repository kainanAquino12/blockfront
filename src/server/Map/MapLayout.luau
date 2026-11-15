--[[
	MapLayout (servidor) — mapa V5 "Front Bloco: Campo Aberto".
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

function MapLayout.buildSide(ctx)
	buildTower(ctx)
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
	-- C: QG Militar no topo do cume (pátio centrado em x ~234, z ~0)
	ctx.struct("QGMilitar", 206 - QGMilitar.Margin, -28 - QGMilitar.Margin, QGMilitar.build(), TerrainGen.RidgeHeight)
end

return MapLayout
