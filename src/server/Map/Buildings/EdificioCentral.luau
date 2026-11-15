--[[
	Edifício Central — prédio demonstrativo do padrão V4.

	Comercial de 6 andares em estrutura de concreto armado.
	Escala (personagem R15 ~5 studs):
	  planta 42 x 30 studs, malha de pilares 10 x 14 (pilares 2x2)
	  piso a piso 9 (laje 1 + pé-direito 8), portas 3 x 7, altura ~62
	Coordenadas locais: x 0..41 (oeste->leste), z 0..29 (sul->norte),
	y 0 = fundação. Margem de 3 células em volta para marquise e sacadas.

	Estrutura (StructuralGraph):
	  Foundation  laje de fundação (y 0)
	  Column      pilar por andar; a célula da laje pertence ao pilar de cima
	  Beam        vigas de borda e internas nas linhas dos pilares (2 de altura,
	              aparecem no teto), uma por vão
	  Slab        painéis de laje entre vigas (um por vão), sacadas, marquise
	  BearingWall núcleo de concreto da escada (por andar)
	Vedação/acabamento (não sustentam): peitoris, vidro, montantes, brises,
	divisórias de gesso, escadas, mesas/balcões, equipamentos da cobertura.

	Andares:
	  térreo  lobby com fachada de vidro, entrada com marquise, recepção
	  1 a 4   escritórios: salas fechadas a oeste, planta livre a leste
	  5       planta livre com muretas (cobertura para combate)
	  cobertura  platibanda, casa de escada, ar-condicionado, caixa d'água
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local EdificioCentral = {}

local W, D = 42, 30 -- planta (x, z)
local FLOORS = 6
local FH = 9 -- piso a piso
local COLS_X = { 0, 10, 20, 30, 40 }
local COLS_Z = { 0, 14, 28 }
local MARGIN = 3
local CORE = { x0 = 22, x1 = 29, z0 = 8, z1 = 21 } -- paredes do núcleo (escada)

local RC = "ReinforcedConcrete"

local function L(k: number): number
	return k * FH -- y da laje do nível k (0 = fundação, 6 = cobertura)
end

local function isColX(x: number): boolean
	for _, c in COLS_X do
		if x == c or x == c + 1 then
			return true
		end
	end
	return false
end

function EdificioCentral.build()
	local b = BuildingKit.new(W + MARGIN * 2, L(FLOORS) + 14, D + MARGIN * 2, Vector3.new(MARGIN, 0, MARGIN))

	-------------------------------------------------------------------------
	-- Fundação
	-------------------------------------------------------------------------
	b:add("Foundation", RC, -1, 0, -1, W, 0, D, "Fundacao")

	-------------------------------------------------------------------------
	-- Lajes e vigas (níveis 1..6)
	-------------------------------------------------------------------------
	for k = 1, FLOORS do
		local y = L(k)
		-- painéis de laje entre as vigas
		for i = 1, #COLS_X - 1 do
			for j = 1, #COLS_Z - 1 do
				b:add("Slab", RC, COLS_X[i] + 2, y, COLS_Z[j] + 2, COLS_X[i + 1] - 1, y, COLS_Z[j + 1] - 1,
					("Laje_N%d_V%d%d"):format(k, i, j))
			end
		end
		-- vigas em X (ao longo das linhas de pilares em z)
		for j, cz in COLS_Z do
			for i = 1, #COLS_X - 1 do
				b:add("Beam", RC, COLS_X[i] + 2, y - 1, cz, COLS_X[i + 1] - 1, y, cz + 1,
					("VigaX_N%d_L%d_V%d"):format(k, j, i))
			end
		end
		-- vigas em Z (ao longo das linhas de pilares em x)
		for i, cx in COLS_X do
			for j = 1, #COLS_Z - 1 do
				b:add("Beam", RC, cx, y - 1, COLS_Z[j] + 2, cx + 1, y, COLS_Z[j + 1] - 1,
					("VigaZ_N%d_L%d_V%d"):format(k, i, j))
			end
		end
		-- poço da escada (dentro do núcleo), mantém a faixa de patamar z 9..12
		b:carve(CORE.x0 + 1, y - 1, CORE.z0 + 5, CORE.x1 - 1, y, CORE.z1 - 1)
	end

	-------------------------------------------------------------------------
	-- Pilares (por andar). A célula da laje de cima pertence ao pilar de cima.
	-------------------------------------------------------------------------
	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f)
		local y1 = L(f + 1) - 1
		for i, cx in COLS_X do
			for j, cz in COLS_Z do
				b:add("Column", RC, cx, y0, cz, cx + 1, y1, cz + 1, ("Pilar_%d%d_A%d"):format(i, j, f))
			end
		end
	end
	-- topo dos pilares na laje de cobertura
	for i, cx in COLS_X do
		for j, cz in COLS_Z do
			local edge = i == 1 or i == #COLS_X or j == 1 or j == #COLS_Z
			local top = if edge then L(FLOORS) + 2 else L(FLOORS)
			b:add("Column", RC, cx, L(FLOORS), cz, cx + 1, top, cz + 1, ("Pilar_%d%d_Topo"):format(i, j))
		end
	end

	-------------------------------------------------------------------------
	-- Núcleo de concreto (parede portante) + casa de escada na cobertura
	-------------------------------------------------------------------------
	for f = 0, FLOORS do
		local y0 = if f == 0 then 1 else L(f)
		local y1 = if f == FLOORS then L(f) + 7 else L(f + 1) - 1
		local name = ("Nucleo_A%d"):format(f)
		local id = b:add("BearingWall", RC, CORE.x0, y0, CORE.z0, CORE.x0, y1, CORE.z1, name .. "_O")
		b:add("BearingWall", RC, CORE.x1, y0, CORE.z0, CORE.x1, y1, CORE.z1, name .. "_L")
		b:add("BearingWall", RC, CORE.x0, y0, CORE.z0, CORE.x1, y1, CORE.z0, name .. "_S")
		b:add("BearingWall", RC, CORE.x0, y0, CORE.z1, CORE.x1, y1, CORE.z1, name .. "_N")
		local _ = id
		-- porta do núcleo para o corredor oeste (abre no patamar z 9..11)
		local fy = if f == 0 then 1 else L(f) + 1
		b:carve(CORE.x0, fy, CORE.z0 + 1, CORE.x0, fy + 6, CORE.z0 + 3)
	end
	-- laje da casa de escada
	b:add("Roof", RC, CORE.x0, L(FLOORS) + 8, CORE.z0, CORE.x1, L(FLOORS) + 8, CORE.z1, "CasaEscada_Teto")

	-------------------------------------------------------------------------
	-- Escadas em U (dentro do núcleo), uma por andar
	-------------------------------------------------------------------------
	for f = 0, FLOORS - 1 do
		local y0 = L(f) + 1
		local sid = b:add("Stair", RC, 23, y0, 12, 25, y0, 12, ("Escada_A%d"):format(f))
		-- lance A: x 23..25, sobe indo para o norte (degraus de 2 de espessura)
		for i = 0, 4 do
			b:extend(sid, 23, math.max(y0 + i - 1, y0), 12 + i, 25, y0 + i, 12 + i)
		end
		-- patamar
		b:extend(sid, 23, y0 + 3, 17, 28, y0 + 4, 20)
		-- lance B: x 26..28, sobe voltando para o sul até a laje de cima
		for i = 0, 3 do
			b:extend(sid, 26, y0 + 4 + i, 16 - i, 28, y0 + 5 + i, 16 - i)
		end
	end

	-- cornijas de pedra (nível 1 e cobertura); antes das fachadas para que
	-- sacadas e marquise fiquem com as células onde se cruzam
	for _, k in { 1, FLOORS } do
		local y = L(k)
		b:add("Wall", "Stone", -1, y, -1, W, y, -1, ("Cornija_S_N%d"):format(k))
		b:add("Wall", "Stone", -1, y, D, W, y, D, ("Cornija_N_N%d"):format(k))
		b:add("Wall", "Stone", -1, y, 0, -1, y, D - 1, ("Cornija_O_N%d"):format(k))
		b:add("Wall", "Stone", W, y, 0, W, y, D - 1, ("Cornija_L_N%d"):format(k))
	end
	-------------------------------------------------------------------------
	-- Fachadas
	-------------------------------------------------------------------------
	-- vãos entre pilares ao longo de x (fachadas sul/norte) e de z (oeste/leste)
	local baysX = {}
	for i = 1, #COLS_X - 1 do
		table.insert(baysX, { COLS_X[i] + 2, COLS_X[i + 1] - 1, i })
	end
	local baysZ = {}
	for j = 1, #COLS_Z - 1 do
		table.insert(baysZ, { COLS_Z[j] + 2, COLS_Z[j + 1] - 1, j })
	end

	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f) + 1
		local yt = L(f + 1) - 2 -- última célula abaixo da viga
		local tag = "A" .. f

		if f == 0 then
			-- TÉRREO
			-- sul: vitrine recuada (z 2) com caixilhos; entrada aberta no vão central
			for _, bay in baysX do
				local a, c, i = bay[1], bay[2], bay[3]
				b:add("Glass", "TintedGlass", a, y0, 2, c, yt, 2, ("Vitrine_S_%d"):format(i))
				for x = a, c, 4 do
					if x >= 23 and x <= 28 then
						continue -- vão da entrada
					end
					b:add("Wall", "DarkMetal", x, y0, 2, x, yt, 2, ("Caixilho_S_%d_%d"):format(i, x))
				end
				b:add("Wall", "FacadePanel", a, yt + 1 - 1, 0, c, yt, 1, ("Bandeira_S_%d"):format(i))
			end
			b:carve(23, y0, 0, 28, yt - 1, 2) -- entrada principal (6 x 6)
			-- marquise da entrada (balanço de 3, presa na viga de borda)
			b:add("Slab", RC, 18, L(1) - 1, -3, 33, L(1) - 1, -1, "Marquise")
			b:add("Wall", "DarkMetal", 18, L(1) - 2, -3, 33, L(1) - 2, -3, "Marquise_Friso")

			-- norte: parede de serviço com janelas altas e porta
			for _, bay in baysX do
				local a, c, i = bay[1], bay[2], bay[3]
				b:add("Wall", "FacadePanel", a, y0, 28, c, yt, 29, ("Parede_N_T_%d"):format(i))
				b:carve(a + 2, y0 + 4, 28, c - 2, y0 + 6, 29)
				b:add("Glass", "TintedGlass", a + 2, y0 + 4, 28, c - 2, y0 + 6, 28, ("Janela_N_T_%d"):format(i))
			end
			b:carve(13, y0, 28, 15, y0 + 6, 29) -- porta de serviço
		else
			-- ANDARES: sul e norte com pano de vidro recuado + peitoril + brises
			for _, side in { { z0 = 0, z1 = 1, zg = 1, zf = 0, n = "S" }, { z0 = 28, z1 = 29, zg = 28, zf = 29, n = "N" } } do
				for _, bay in baysX do
					local a, c, i = bay[1], bay[2], bay[3]
					local balcony = side.n == "N" and f <= 4 and (i == 1 or i == 4)
					if not balcony then
						b:add("Wall", "FacadePanel", a, y0, side.z0, c, y0 + 2, side.z1, ("Peitoril_%s_%s_%d"):format(side.n, tag, i))
					end
					local gy0 = if balcony then y0 else y0 + 3
					b:add("Glass", "TintedGlass", a, gy0, side.zg, c, yt, side.zg, ("Vidro_%s_%s_%d"):format(side.n, tag, i))
					-- brises verticais (metal escuro) por fora do vidro
					for x = a + 1, c, 3 do
						b:add("Wall", "DarkMetal", x, gy0, side.zf, x, yt, side.zf, ("Brise_%s_%s_%d_%d"):format(side.n, tag, i, x))
					end
					if balcony then
						-- porta de vidro para a sacada
						b:carve(a + 3, y0, side.zg, a + 4, y0 + 6, side.zf)
						-- sacada em balanço (2 de profundidade) + guarda-corpo
						local sy = L(f)
						b:add("Slab", RC, a, sy, 30, c, sy, 31, ("Sacada_%s_%d"):format(tag, i))
						b:add("Wall", "DarkMetal", a, sy + 1, 31, c, sy + 1, 31, ("GuardaCorpoBase_%s_%d"):format(tag, i))
						for x = a, c, 2 do
							b:add("Wall", "DarkMetal", x, sy + 2, 31, x, sy + 2, 31, ("Montante_%s_%d_%d"):format(tag, i, x))
						end
						b:add("Wall", "DarkMetal", a, sy + 3, 31, c, sy + 3, 31, ("Corrimao_%s_%d"):format(tag, i))
					end
				end
			end
		end

		-- oeste e leste: parede de painéis com janelas recortadas (todas os andares)
		for _, side in { { x0 = 0, x1 = 1, xg = 1, n = "O" }, { x0 = 40, x1 = 41, xg = 40, n = "L" } } do
			for _, bay in baysZ do
				local a, c, j = bay[1], bay[2], bay[3]
				local wall = b:add("Wall", "FacadePanel", side.x0, y0, a, side.x1, yt, c, ("Parede_%s_%s_%d"):format(side.n, tag, j))
				for _, wz in { a + 1, a + 7 } do
					b:carve(side.x0, y0 + 2, wz, side.x1, y0 + 5, wz + 3)
					b:add("Glass", "TintedGlass", side.xg, y0 + 2, wz, side.xg, y0 + 5, wz + 3, ("Janela_%s_%s_%d_%d"):format(side.n, tag, j, wz))
					-- peitoril de pedra saliente: faz parte da parede (cai junto com ela)
					local xs = if side.n == "O" then -1 else 42
					b:extend(wall, xs, y0 + 1, wz - 1, xs, y0 + 1, wz + 4)
				end
			end
		end
	end

	-- a marquise fica por cima da cornija do nível 1 no trecho da entrada
	b:add("Slab", RC, 18, L(1), -3, 33, L(1), -1, "Marquise_Laje")

	-------------------------------------------------------------------------
	-- Interiores
	-------------------------------------------------------------------------
	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f) + 1
		local yc = L(f + 1) - 1 -- até o teto
		local tag = "A" .. f
		if f == 0 then
			-- lobby: balcão de recepção em pedra, bancos de espera
			b:add("Prop", "Stone", 10, y0, 9, 17, y0 + 2, 10, "Recepcao")
			b:add("Prop", "Stone", 10, y0, 11, 10, y0 + 2, 12, "Recepcao_Lado")
			b:add("Prop", "Wood", 33, y0, 6, 37, y0, 7, "Banco_1")
			b:add("Prop", "Wood", 33, y0, 22, 37, y0, 23, "Banco_2")
		elseif f <= 4 then
			-- metade oeste: salas fechadas (sul e norte) com corredor no meio
			for _, zw in { 7, 22 } do
				local id = b:add("Partition", "Gypsum", 2, y0, zw, 21, yc, zw, ("Divisoria_%s_%d"):format(tag, zw))
				local _ = id
				for _, dx in { 5, 15 } do
					b:carve(dx, y0, zw, dx + 2, y0 + 6, zw) -- portas
				end
			end
			for _, zr in { { 2, 6 }, { 23, 27 } } do
				b:add("Partition", "Gypsum", 11, y0, zr[1], 11, yc, zr[2], ("DivisoriaSala_%s_%d"):format(tag, zr[1]))
			end
			-- metade leste: planta livre com mesas (cobertura baixa)
			for _, dz in { 3, 24 } do
				for _, dx in { 32, 36 } do
					b:add("Prop", "Wood", dx, y0, dz, dx + 2, y0 + 1, dz + 1, ("Mesa_%s_%d_%d"):format(tag, dx, dz))
				end
			end
			b:add("Prop", "Wood", 32, y0, 12, 36, y0 + 1, 13, ("MesaReuniao_%s"):format(tag))
		else
			-- último andar: planta livre com muretas (cobertura para combate)
			for _, m in { { 4, 6, 12, 6 }, { 4, 22, 12, 22 }, { 33, 10, 33, 18 }, { 14, 14, 18, 14 } } do
				b:add("Partition", "Gypsum", m[1], y0, m[2], m[3], y0 + 2, m[4], ("Mureta_%s_%d_%d"):format(tag, m[1], m[2]))
			end
		end
	end

	-------------------------------------------------------------------------
	-- Cobertura
	-------------------------------------------------------------------------
	local yr = L(FLOORS) + 1
	b:add("Wall", "FacadePanel", 0, yr, 0, W - 1, yr + 1, 0, "Platibanda_S")
	b:add("Wall", "FacadePanel", 0, yr, D - 1, W - 1, yr + 1, D - 1, "Platibanda_N")
	b:add("Wall", "FacadePanel", 0, yr, 1, 0, yr + 1, D - 2, "Platibanda_O")
	b:add("Wall", "FacadePanel", W - 1, yr, 1, W - 1, yr + 1, D - 2, "Platibanda_L")
	b:add("Wall", "Stone", -1, yr + 2, -1, W, yr + 2, 0, "Rufo_S")
	b:add("Wall", "Stone", -1, yr + 2, D - 1, W, yr + 2, D, "Rufo_N")
	-- porta da casa de escada para a cobertura (lado sul do núcleo)
	b:carve(24, yr, CORE.z0, 27, yr + 6, CORE.z0)
	-- equipamentos
	b:add("Prop", "DarkMetal", 4, yr, 4, 9, yr + 2, 8, "ArCondicionado_1")
	b:add("Prop", "DarkMetal", 4, yr, 11, 9, yr + 2, 15, "ArCondicionado_2")
	b:add("Prop", "SheetMetal", 33, yr, 21, 37, yr + 4, 25, "CaixaDagua")
	b:add("Prop", "DarkMetal", 38, yr, 3, 38, yr + 9, 3, "Antena")
	-- dutos ligando o ar-condicionado ao núcleo
	b:add("Prop", "SheetMetal", 10, yr, 6, 21, yr, 6, "Duto")

	-- isColX fica disponível para variações futuras da fachada
	local _ = isColX

	return b:finish()
end

-- Medidas para quem posiciona o prédio (MapManager).
EdificioCentral.Margin = MARGIN
EdificioCentral.Footprint = Vector2.new(W, D)

return EdificioCentral
