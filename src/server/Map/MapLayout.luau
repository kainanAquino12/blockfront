--[[
	MapLayout (servidor) — mapa "Vila Bloco", primeira arena do modo CONQUISTA.

	O layout é descrito UMA vez, do ponto de vista da equipe azul (sul,
	z negativo). O lado vermelho é o mesmo layout girado 180° em torno do
	centro, então o mapa é simétrico e justo para as duas equipes.

	Rotas do sul para o centro:
	  esquerda  (x ≈ -90) galpão de 2 andares e caixotes, rota coberta
	  centro    (x ≈ 0)   avenida aberta com barreiras e sacos de areia
	  direita   (x ≈ +80) casas, rota de flanco curta
	Centro: praça com a área de captura (raio 14), cercada por quatro
	prédios de esquina e coberturas baixas destrutíveis.

	Coordenadas de estruturas = canto mínimo (x, z) no chão.
]]

local StructureKit = require(script.Parent.StructureKit)
local M = StructureKit.Materials

local MapLayout = {}

MapLayout.HalfX = 150
MapLayout.HalfZ = 170

-- Pontos de nascimento da equipe azul (o vermelho é espelhado).
MapLayout.Spawns = {
	Vector3.new(-14, 0.5, -144),
	Vector3.new(0, 0.5, -148),
	Vector3.new(14, 0.5, -144),
}

-- Construções destrutíveis de um lado (espelhadas para o outro).
MapLayout.Structures = {
	-- Base: sacos de areia na saída
	{ Name = "BaseSandbagsL", At = Vector2.new(-34, -119), Def = StructureKit.sandbags(12, 3) },
	{ Name = "BaseSandbagsR", At = Vector2.new(22, -119), Def = StructureKit.sandbags(12, 3) },

	-- Rota esquerda
	{
		Name = "Warehouse",
		At = Vector2.new(-102, -88),
		Def = StructureKit.building({ SizeX = 22, SizeZ = 16, Floors = 2, Wall = M.Brick, Trim = M.Concrete, Slab = M.Planks, Roof = M.Concrete, Doors = { "N", "S", "E" } }),
	},
	{ Name = "LeftCrates", At = Vector2.new(-72, -62), Def = StructureKit.crates(6, 6) },
	{ Name = "LeftSandbags", At = Vector2.new(-92, -50), Def = StructureKit.sandbags(10, 3) },

	-- Rota central
	{ Name = "MidSandbags", At = Vector2.new(-6, -98), Def = StructureKit.sandbags(12, 3) },
	{ Name = "MidBarrierL", At = Vector2.new(-22, -80), Def = StructureKit.barrier(10) },
	{ Name = "MidBarrierR", At = Vector2.new(12, -78), Def = StructureKit.barrier(10) },
	{ Name = "MidCrates", At = Vector2.new(-3, -68), Def = StructureKit.crates(6, 6) },
	{ Name = "MidRuin", At = Vector2.new(-24, -56), Def = StructureKit.wall(14, 6, 2, M.Brick, M.Concrete, true) },

	-- Rota direita
	{
		Name = "HouseA",
		At = Vector2.new(62, -94),
		Def = StructureKit.building({ SizeX = 14, SizeZ = 12, Floors = 1, Wall = M.Plaster, Trim = M.Concrete, Roof = M.RoofTile, Doors = { "N", "W" } }),
	},
	{
		Name = "HouseB",
		At = Vector2.new(88, -64),
		Def = StructureKit.building({ SizeX = 12, SizeZ = 14, Floors = 2, Wall = M.PaintedConcrete, Trim = M.Concrete, Slab = M.Wood, Roof = M.RoofTile, Doors = { "N", "S", "W" } }),
	},
	{ Name = "RightBarrier", At = Vector2.new(60, -48), Def = StructureKit.barrier(8) },

	-- Praça central
	{
		Name = "CornerTower",
		At = Vector2.new(-46, -40),
		Def = StructureKit.building({ SizeX = 16, SizeZ = 14, Floors = 2, Wall = M.Brick, Trim = M.Concrete, Slab = M.Wood, Roof = M.Concrete, Doors = { "N", "E", "S" } }),
	},
	{
		Name = "CornerShop",
		At = Vector2.new(24, -38),
		Def = StructureKit.building({ SizeX = 14, SizeZ = 12, Floors = 1, Wall = M.Plaster, Trim = M.Concrete, Roof = M.RoofTile, Doors = { "N", "W" } }),
	},
	{ Name = "PlazaWallL", At = Vector2.new(-22, -20), Def = StructureKit.wall(8, 4, 1, M.Brick, M.Concrete, false) },
	{ Name = "PlazaWallR", At = Vector2.new(14, -20), Def = StructureKit.wall(8, 4, 1, M.Brick, M.Concrete, false) },
	{ Name = "ZoneBarrier", At = Vector2.new(-10, -9), Def = StructureKit.barrier(8) },
	{ Name = "ZoneSandbags", At = Vector2.new(3, -13), Def = StructureKit.sandbags(6, 3) },
}

-- Enfeites estáticos de um lado (espelhados).
MapLayout.Trees = {
	{ -126, -128, 1.2 }, { -122, -64, 1.0 }, { -132, -20, 1.3 }, { -62, -112, 1.1 }, { -58, -70, 0.9 },
	{ 124, -112, 1.2 }, { 128, -36, 1.0 }, { 54, -112, 1.0 }, { 118, -78, 0.9 }, { -128, -98, 0.8 },
	{ -70, -20, 1.0 }, { 66, -18, 0.9 },
}
MapLayout.Rocks = {
	{ -112, -32, 1.4 }, { 116, -98, 1.2 }, { -46, -104, 1.0 }, { 46, -62, 1.1 }, { 136, -140, 1.6 }, { -138, -150, 1.5 },
}
MapLayout.Lamps = {
	{ 9, -30 }, { -9, -60 }, { 9, -90 },
}
MapLayout.Containers = {
	{ -30, -132, 90 }, { 32, -128, 90 }, { -112, -118, 0 }, { 104, -126, 20 },
}
MapLayout.Fences = {
	{ Vector3.new(-80, 0, -110), Vector3.new(-80, 0, -94) },
	{ Vector3.new(-80, 0, -66), Vector3.new(-80, 0, -30) },
	{ Vector3.new(76, 0, -110), Vector3.new(76, 0, -100) },
}

return MapLayout
