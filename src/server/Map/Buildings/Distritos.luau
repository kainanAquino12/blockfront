--[[
	Construções dos distritos novos (V10). Cada uma tem papel na guerra e
	desenho próprio; todas são BuildingKit (estrutura real, destrutível).

	  estacao()   Estação ferroviária: saguão de tijolo com pé-direito duplo,
	              torre do relógio (posto de tiro), plataforma com cobertura
	              metálica sobre pilares de aço, ala de bilheteria.
	  hospital()  Hospital de campanha em H: 2 alas de 4 andares ligadas por
	              um bloco central, heliponto na cobertura, marquise da
	              emergência, enfermarias com leitos. Uma ala já foi atingida
	              (último andar aberto pelo bombardeio).
	  igreja()    Igreja em ruínas: nave de pedra com contrafortes, metade do
	              telhado desabado, torre sineira escalável (escada até o
	              campanário = ponto de observação), bancos e entulho.
	  escola()    Escola transformada em posto de comando: 2 andares em L,
	              corredor e salas, janelas do térreo com sacos de areia,
	              muro com portão e pátio.

	Coordenadas locais: entrada principal voltada para z = 0 (sul), salvo
	quando indicado; quem posiciona usa BuildingKit.flipZ se precisar.
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local D = {}
local RC = "ReinforcedConcrete"

---------------------------------------------------------------------------
-- Estação ferroviária. Trilhos ao longo de z, do lado x = 0 (oeste).
-- Planta: plataforma x 2..17, prédio x 20..43, comprimento z 0..95.
---------------------------------------------------------------------------
function D.estacao()
	local b = BuildingKit.new(48, 54, 100, Vector3.new(2, 0, 2))
	b:add("Foundation", RC, -1, 0, -1, 45, 0, 96, "Fundacao")
	b:add("Foundation", RC, 19, 1, 0, 45, 2, 95, "Embasamento") -- prédio no nível da plataforma
	-- plataforma elevada (2) ao longo dos trilhos
	b:add("Foundation", "Concrete", 2, 1, 0, 17, 2, 95, "Plataforma")
	b:add("Wall", "Stone", 2, 3, 0, 2, 3, 95, "Plataforma_Borda") -- faixa de segurança
	-- cobertura da plataforma: pilares de aço, vigas e telhado de chapa
	for z = 4, 88, 12 do
		b:add("Column", "Metal", 9, 3, z, 10, 11, z + 1, ("Plataforma_Pilar_%d"):format(z))
		b:add("Beam", "Metal", 3, 12, z, 17, 12, z + 1, ("Plataforma_Viga_%d"):format(z))
	end
	local roof = b:add("Roof", "SheetMetal", 3, 13, 2, 17, 13, 93, "Plataforma_Telhado")
	local _ = roof
	for z = 10, 86, 24 do
		b:add("Prop", "DarkMetal", 7, 3, z, 12, 4, z + 1, ("Banco_%d"):format(z))
	end
	b:add("Prop", "DarkMetal", 11, 8, 40, 12, 10, 41, "Placa_Plataforma") -- presa no pilar

	-- prédio da estação: saguão de pé-direito duplo + alas de 2 andares
	b.lightKind = "Industrial"
	b:framedBlock({
		Name = "Saguao", X = { 20, 32, 42 }, Z = { 30, 44, 58 }, Levels = { 2, 24 },
		Wall = "DarkBrick", Win = "Tall", Roof = true, RoofMaterial = "Stone",
		Doors = { { face = "L", at = 40, w = 6 }, { face = "O", at = 40, w = 6 }, { face = "S", at = 23, w = 4 }, { face = "N", at = 23, w = 4 } },
	})
	b.lightKind = "Fluorescent"
	for _, ala in { { z0 = 4, z1 = 30, n = "AlaSul" }, { z0 = 58, z1 = 84, n = "AlaNorte" } } do
		b:framedBlock({
			Name = ala.n, X = { 20, 32, 42 }, Z = { ala.z0, ala.z0 + 13, ala.z1 }, Levels = { 2, 13, 24 },
			Wall = "Brick", Win = "Punched", Roof = true, RoofMaterial = "Stone",
			SkipFaces = if ala.n == "AlaSul" then { N = true } else { S = true },
			Doors = { { face = "O", at = ala.z0 + 6, w = 3 } },
		})
	end
	-- escada na ala sul (até a cobertura da ala)
	b:stairCore(33, 9, { 2, 13, 24 }, { Penthouse = 7, Name = "AlaSul_Nucleo" })
	-- torre do relógio sobre o saguão (núcleo de escada vira a torre)
	-- patamares dentro da torre (o saguão não tem laje nos níveis 11 e 29)
	for _, y in { 13, 24, 35 } do
		b:add("Slab", RC, 28, y, 38, 33, y, 41, ("Torre_Patamar_%d"):format(y))
	end
	b:stairCore(27, 37, { 2, 13, 24, 35 }, { Penthouse = 9, Name = "Torre", Material = "DarkBrick" })
	b:carve(27, 37, 40, 27, 40, 46) -- janelas do campanário/relógio (posto de tiro)
	b:carve(34, 37, 40, 34, 40, 46)
	b:add("Prop", "Stone", 26, 42, 40, 26, 45, 47, "Relogio_O")
	b:add("Prop", "Stone", 35, 42, 40, 35, 45, 47, "Relogio_L")
	-- bilheteria e bancos no saguão
	b:add("Prop", "Wood", 22, 3, 46, 23, 4, 54, "Bilheteria")
	b:add("Prop", "Wood", 30, 3, 34, 34, 3, 35, "Banco_Saguao_1")
	b:add("Prop", "Wood", 30, 3, 52, 34, 3, 53, "Banco_Saguao_2")
	-- marquise da entrada (lado da cidade)
	b:add("Slab", RC, 43, 12, 38, 45, 12, 50, "Marquise")
	return b:finish()
end

---------------------------------------------------------------------------
-- Hospital em H. Alas leste/oeste x 0..15 e 46..61, z 0..63; bloco central
-- x 16..45, z 22..41. 4 andares (piso a piso 8).
---------------------------------------------------------------------------
function D.hospital()
	local b = BuildingKit.new(66, 56, 70, Vector3.new(2, 0, 3))
	b:add("Foundation", RC, -1, 0, -3, 62, 0, 64, "Fundacao")
	local L = { 0, 10, 20, 30, 40 }
	b:framedBlock({
		Name = "AlaOeste", X = { 0, 14 }, Z = { 0, 11, 22, 33, 44, 55, 62 }, Levels = L,
		Wall = "PaintedConcrete", Win = "Ribbon", Roof = true,
		SkipFaces = {}, Doors = { { face = "S", at = 5, w = 4 } },
	})
	b:framedBlock({
		Name = "AlaLeste", X = { 46, 60 }, Z = { 0, 11, 22, 33, 44, 55, 62 }, Levels = L,
		Wall = "PaintedConcrete", Win = "Ribbon", Roof = true,
		Doors = { { face = "S", at = 51, w = 4 } },
	})
	b:framedBlock({
		Name = "Centro", X = { 16, 30, 44 }, Z = { 22, 40 }, Levels = L,
		Wall = "FacadePanel", Win = "Ribbon", Roof = true,
		Doors = { { face = "S", at = 27, w = 6 }, { face = "N", at = 27, w = 6 } },
	})
	-- passagens entre o bloco central e as alas (cada andar)
	for f = 0, 3 do
		local y = L[f + 1] + 1
		b:carve(14, y, 26, 18, y + 5, 30)
		b:carve(44, y, 26, 48, y + 5, 30)
		if f >= 1 then
			b:add("Slab", RC, 15, L[f + 1], 26, 17, L[f + 1], 30, ("Passagem_O_%d"):format(f))
			b:add("Slab", RC, 45, L[f + 1], 26, 46, L[f + 1], 30, ("Passagem_L_%d"):format(f))
		end
	end
	-- escadas: uma em cada ala, até a cobertura
	b:stairCore(4, 40, L, { Penthouse = 7, Name = "NucleoOeste" })
	b:stairCore(50, 40, L, { Penthouse = 7, Name = "NucleoLeste" })
	-- marquise da emergência
	for _, x in { 22, 38 } do
		b:add("Column", "Metal", x, 1, -3, x + 1, 6, -2, ("Marquise_Pilar_%d"):format(x))
	end
	b:add("Beam", "Metal", 20, 7, -3, 41, 7, -2, "Marquise_Viga")
	b:add("Slab", RC, 20, 7, -1, 41, 7, 21, "Marquise_Laje")
	-- cruz vermelha (desbotada) na fachada sul do bloco central
	b:add("Prop", "Brick", 29, 22, 22, 32, 27, 22, "Cruz_V")
	b:add("Prop", "Brick", 27, 24, 22, 34, 25, 22, "Cruz_H")
	-- heliponto na cobertura do centro: piso escuro com o "H"
	local yr = L[5] + 1
	b:add("Prop", "DarkMetal", 19, yr, 24, 41, yr, 38, "Heliponto")
	b:add("Prop", "Stone", 25, yr + 1, 27, 26, yr + 1, 35, "Heliponto_H1")
	b:add("Prop", "Stone", 34, yr + 1, 27, 35, yr + 1, 35, "Heliponto_H2")
	b:add("Prop", "Stone", 27, yr + 1, 30, 33, yr + 1, 32, "Heliponto_H3")
	-- enfermarias: leitos e divisórias nas alas
	for f = 0, 3 do
		local y = L[f + 1] + 1
		for _, ala in { { x0 = 2, x1 = 13 }, { x0 = 48, x1 = 59 } } do
			b:add("Partition", "Gypsum", ala.x0, y, 20, ala.x1, L[f + 2] - 1, 20, ("Div_%d_%d"):format(ala.x0, f))
			b:carve(ala.x0 + 4, y, 20, ala.x0 + 6, y + 5, 20)
			for z = 3, 15, 4 do
				b:add("Prop", "DarkMetal", ala.x0 + 1, y, z, ala.x0 + 3, y + 1, z + 1, ("Leito_%d_%d_%d"):format(ala.x0, f, z))
			end
		end
	end
	-- ala leste atingida: último andar aberto
	b:carve(46, L[4] + 1, 0, 61, L[5] + 3, 18)
	b:add("Prop", "Concrete", 48, L[4] + 1, 2, 53, L[4] + 2, 6, "Entulho_Ala")
	return b:finish()
end

---------------------------------------------------------------------------
-- Igreja em ruínas: nave x 0..23, z 0..47 (fachada/entrada em z = 0),
-- torre sineira x 24..31, z 0..13 (núcleo de escada até o campanário).
---------------------------------------------------------------------------
function D.igreja()
	local b = BuildingKit.new(36, 46, 52, Vector3.new(2, 0, 2))
	local ST = "Stone"
	b:add("Foundation", RC, -1, 0, -1, 33, 0, 48, "Fundacao")
	local H = 16
	-- paredes portantes grossas (2) da nave
	b:add("BearingWall", ST, 0, 1, 0, 1, H, 47, "Nave_O")
	b:add("BearingWall", ST, 22, 1, 0, 23, H, 47, "Nave_L")
	b:add("BearingWall", ST, 2, 1, 0, 21, H, 1, "Fachada")
	b:add("BearingWall", ST, 2, 1, 46, 21, H, 47, "Abside")
	-- contrafortes
	for z = 8, 40, 8 do
		b:add("BearingWall", ST, -2, 1, z, -1, 10, z + 1, ("Contraforte_O_%d"):format(z))
		if z >= 16 then
			b:add("BearingWall", ST, 24, 1, z, 25, 10, z + 1, ("Contraforte_L_%d"):format(z))
		end
	end
	-- portal e rosácea
	b:carve(9, 1, 0, 14, 9, 1)
	b:carve(10, 11, 0, 13, 14, 1)
	b:add("Glass", "TintedGlass", 10, 11, 1, 13, 14, 1, "Rosacea")
	-- janelas altas da nave
	for z = 4, 40, 8 do
		for _, x in { 0, 22 } do
			b:carve(x, 5, z, x + 1, 12, z + 1)
		end
	end
	-- telhado em duas águas: só a metade norte sobrou (sul desabado)
	local aguaO = b:add("Roof", "RoofTile", 0, H + 1, 24, 1, H + 1, 47, "Telhado_O")
	local aguaL = b:add("Roof", "RoofTile", 22, H + 1, 24, 23, H + 1, 47, "Telhado_L")
	for st = 1, 8 do
		b:extend(aguaO, 1 + st, H + 1 + st, 24, 1 + st, H + 1 + st, 47)
		b:extend(aguaL, 22 - st, H + 1 + st, 24, 22 - st, H + 1 + st, 47)
	end
	b:extend(aguaO, 10, H + 9, 24, 13, H + 9, 47)
	-- empena da abside
	for st = 0, 7 do
		b:add("Wall", ST, 2 + st, H + 1, 47, 21 - st, H + 1 + st, 47, ("Empena_%d"):format(st))
	end
	-- interior: bancos (cobertura baixa), altar, entulho do telhado
	for z = 8, 36, 4 do
		b:add("Prop", "Wood", 3, 1, z, 9, 2, z, ("Banco_O_%d"):format(z))
		if z > 14 then
			b:add("Prop", "Wood", 14, 1, z, 20, 2, z, ("Banco_L_%d"):format(z))
		end
	end
	b:add("Prop", ST, 8, 1, 41, 15, 3, 43, "Altar")
	b:add("Prop", "RoofTile", 14, 1, 6, 19, 2, 11, "Entulho_Telhado")
	-- torre sineira: núcleo de escada (paredes portantes) até o campanário
	for _, y in { 9, 18, 27 } do
		b:add("Slab", RC, 25, y, 1, 30, y, 4, ("Torre_Patamar_%d"):format(y))
	end
	b:stairCore(24, 0, { 0, 9, 18, 27 }, { Penthouse = 8, Name = "Torre", Material = "Stone" })
	b:carve(24, 29, 3, 24, 34, 10) -- arcos do campanário (vista para todos os lados)
	b:carve(31, 29, 3, 31, 34, 10)
	b:carve(26, 29, 0, 29, 34, 0)
	b:carve(26, 29, 13, 29, 34, 13)
	b:add("Prop", "DarkMetal", 27, 28, 2, 28, 31, 3, "Sino") -- apoiado no patamar do campanário
	b:add("Prop", ST, 27, 37, 6, 28, 41, 7, "Agulha")
	-- passagem da nave para a torre
	b:carve(22, 1, 1, 24, 7, 4)
	return b:finish()
end

---------------------------------------------------------------------------
-- Escola / posto de comando: bloco de salas x 0..47, z 0..13 e ala
-- x 0..13, z 14..39 (L). 2 andares. Pátio cercado por muro com portão.
---------------------------------------------------------------------------
function D.escola()
	local b = BuildingKit.new(60, 30, 58, Vector3.new(2, 0, 2))
	b:add("Foundation", RC, -1, 0, -1, 56, 0, 54, "Fundacao")
	local L = { 0, 10, 20 }
	b:framedBlock({
		Name = "Salas", X = { 0, 12, 24, 36, 46 }, Z = { 0, 12 }, Levels = L,
		Wall = "Brick", Win = "Ribbon", Roof = true,
		Doors = { { face = "N", at = 18, w = 4 }, { face = "S", at = 40, w = 4 } },
	})
	b:framedBlock({
		Name = "Ala", X = { 0, 12 }, Z = { 14, 26, 38 }, Levels = L,
		Wall = "PlasterYellow", Win = "Punched", Roof = true, SkipFaces = { S = true },
		Doors = { { face = "L", at = 30, w = 3 } },
	})
	b:carve(2, 1, 13, 11, 6, 15) -- liga as duas alas no térreo
	b:carve(2, L[2] + 1, 13, 11, L[2] + 6, 15)
	b:add("Slab", RC, 2, L[2], 13, 11, L[2], 13, "Ligacao_Laje")
	-- núcleo entre as linhas de pilares 24 e 36 (não colide com nenhum pilar)
	b:stairCore(26, 2, L, { Penthouse = 6, Name = "Nucleo" })
	-- salas: carteiras viradas como barricadas
	for _, x in { 3, 15, 38 } do
		for f = 0, 1 do
			local y = L[f + 1] + 1
			if x == 3 then
				b:add("Partition", "Gypsum", 12, y, 2, 12, L[f + 2] - 1, 11, ("Div_%d"):format(f))
				b:carve(12, y, 8, 12, y + 5, 10)
			end
			b:add("Prop", "Wood", x, y, 4, x + 5, y, 5, ("Carteiras_%d_%d"):format(x, f))
			b:add("Prop", "Wood", x + 1, y, 8, x + 4, y + 1, 8, ("Mesa_%d_%d"):format(x, f))
		end
	end
	-- posto de comando: mesa de mapas e rádios
	b:add("Prop", "Wood", 3, 1, 24, 9, 2, 28, "MesaDeMapas")
	b:add("Prop", "DarkMetal", 3, 1, 32, 4, 3, 35, "Radios")
	-- sacos de areia nas janelas do térreo (lado do pátio, norte)
	for x = 3, 30, 6 do
		b:add("Prop", "Sandbag", x, 1, 14, x + 3, 3, 14, ("Sacos_%d"):format(x))
	end
	-- muro do pátio com portão
	b:add("Wall", "Concrete", 14, 1, 52, 55, 4, 52, "Muro_N")
	b:add("Wall", "Concrete", 55, 1, 14, 55, 4, 51, "Muro_L")
	b:carve(55, 1, 28, 55, 4, 35) -- portão
	b:add("Prop", "DarkMetal", 30, 1, 30, 30, 14, 30, "Mastro")
	return b:finish()
end

return D
