--[[
	QG Militar — ponto C, no topo do cume leste. Fica sobre o eixo z = 0.

	Fortaleza de concreto em "9 quadras" (56 x 56 studs, 2 níveis + terraço):
	  - paredes externas portantes grossas (2) com seteiras em cada nível
	  - paredes internas portantes formam 8 salas em volta de um PÁTIO
	    central aberto (20 x 20) — o ponto C fica no pátio
	  - portões a oeste (estrada que sobe o cume) e a leste
	  - dois núcleos de escada (salas sul e norte) que sobem até o terraço,
	    com casas de escada que servem de torres de observação
	  - terraço com parapeito ameado e posições de sacos de areia

	Estrutura (StructuralGraph): fundação, paredes portantes por nível,
	lajes por sala (apoiadas nas 4 paredes). Explosões abrem rombos nas
	paredes; derrubar uma parede portante faz as lajes vizinhas cederem.
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local QG = {}

local S = 56 -- planta quadrada: 0..55
local FH = 8
local LEVELS = { 0, 8, 16 }
local MARGIN = 2
local WALLS = { 0, 16, 38, 54 } -- linhas de parede (2 de espessura) em x e em z
local RC = "ReinforcedConcrete"
local MIL = "Military"

function QG.build()
	local b = BuildingKit.new(S + MARGIN * 2, 40, S + MARGIN * 2, Vector3.new(MARGIN, 0, MARGIN))
	b:add("Foundation", RC, -1, 0, -1, S, 0, S, "Fundacao")

	-- paredes portantes por nível (a célula da laje pertence à parede de cima)
	for f = 0, #LEVELS - 2 do
		local y0 = if f == 0 then 1 else LEVELS[f + 1]
		-- o último nível inclui a célula do terraço (o parapeito apoia nela)
		local y1 = if f == #LEVELS - 2 then LEVELS[f + 2] else LEVELS[f + 2] - 1
		local tag = "N" .. f
		for _, w in WALLS do
			local outer = w == 0 or w == S - 2
			local mat = if outer then MIL else RC
			b:add("BearingWall", mat, w, y0, 0, w + 1, y1, S - 1, ("ParedeX_%d_%s"):format(w, tag))
			b:add("BearingWall", mat, 0, y0, w, S - 1, y1, w + 1, ("ParedeZ_%d_%s"):format(w, tag))
		end
		-- seteiras nas paredes externas (1 de altura, 4 de largura)
		local sy = y0 + 3
		for a = 4, S - 8, 7 do
			b:carve(0, sy, a, 1, sy, a + 3)
			b:carve(S - 2, sy, a, S - 1, sy, a + 3)
			b:carve(a, sy, 0, a + 3, sy, 1)
			b:carve(a, sy, S - 2, a + 3, sy, S - 1)
		end
	end

	-- lajes por sala (nível 1 e terraço), o pátio central fica aberto
	for k = 2, #LEVELS do
		local y = LEVELS[k]
		for i = 1, #WALLS - 1 do
			for j = 1, #WALLS - 1 do
				if not (i == 2 and j == 2) then
					b:add("Slab", RC, WALLS[i] + 2, y, WALLS[j] + 2, WALLS[i + 1] - 1, y, WALLS[j + 1] - 1, ("Laje_N%d_%d%d"):format(k - 1, i, j))
				end
			end
		end
	end

	-- portões oeste e leste (atravessam a parede externa e a interna)
	for _, x in { 0, 16, 38, 54 } do
		b:carve(x, 1, 24, x + 1, 7, 31)
	end
	-- portas entre salas (térreo e 1º nível)
	for f = 0, 1 do
		local y0 = LEVELS[f + 1] + 1
		for _, d in {
			{ 16, 8 }, { 38, 8 }, { 16, 46 }, { 38, 46 }, -- paredes em x
		} do
			b:carve(d[1], y0, d[2], d[1] + 1, y0 + 6, d[2] + 2)
		end
		for _, d in { { 8, 16 }, { 8, 38 }, { 46, 16 }, { 46, 38 }, { 20, 16 }, { 20, 38 } } do
			b:carve(d[1], y0, d[2], d[1] + 2, y0 + 6, d[2] + 1)
		end
	end

	-- núcleos de escada nas salas sul e norte -> terraço (casas de escada = torres)
	b:stairCore(26, 2, LEVELS, { Penthouse = 9, Name = "NucleoSul" })
	b:stairCore(26, 40, LEVELS, { Penthouse = 9, Name = "NucleoNorte" })

	-- terraço: parapeito ameado + sacos de areia
	local yr = LEVELS[#LEVELS] + 1
	for _, e in { { 0, 0, S - 1, 0 }, { 0, S - 1, S - 1, S - 1 }, { 0, 1, 0, S - 2 }, { S - 1, 1, S - 1, S - 2 } } do
		b:add("Wall", MIL, e[1], yr, e[2], e[3], yr + 2, e[4], ("Parapeito_%d_%d"):format(e[1], e[2]))
	end
	for a = 3, S - 4, 5 do
		b:carve(a, yr + 2, 0, a + 1, yr + 2, 0)
		b:carve(a, yr + 2, S - 1, a + 1, yr + 2, S - 1)
		b:carve(0, yr + 2, a, 0, yr + 2, a + 1)
		b:carve(S - 1, yr + 2, a, S - 1, yr + 2, a + 1)
	end
	-- parapeito interno em volta do pátio
	b:add("Wall", MIL, 16, yr, 16, 39, yr, 16, "ParapeitoPatio_S")
	b:add("Wall", MIL, 16, yr, 39, 39, yr, 39, "ParapeitoPatio_N")
	b:add("Wall", MIL, 16, yr, 17, 16, yr, 38, "ParapeitoPatio_O")
	b:add("Wall", MIL, 39, yr, 17, 39, yr, 38, "ParapeitoPatio_L")
	for _, p in { { 6, 6 }, { 46, 6 }, { 6, 46 }, { 46, 46 } } do
		b:add("Prop", "Sandbag", p[1], yr, p[2], p[1] + 4, yr + 1, p[2] + 1, ("Sacos_%d_%d"):format(p[1], p[2]))
	end
	-- antena de rádio na casa de escada norte
	b:add("Prop", "DarkMetal", 33, yr + 10, 52, 33, yr + 20, 52, "Antena")

	-- pátio: barreiras de concreto e caixotes como cobertura no ponto C
	for _, c in { { 21, 22, 25, 23 }, { 30, 32, 34, 33 }, { 22, 30, 23, 33 }, { 32, 21, 33, 24 } } do
		b:add("Prop", MIL, c[1], 1, c[2], c[3], 3, c[4], ("BarreiraPatio_%d_%d"):format(c[1], c[2]))
	end
	-- salas: mesas de comando e armários
	for _, m in { { 4, 20, 9, 22 }, { 44, 20, 49, 22 }, { 4, 44, 9, 46 }, { 44, 6, 49, 8 } } do
		b:add("Prop", "DarkMetal", m[1], 1, m[2], m[3], 2, m[4], ("Mesa_%d_%d"):format(m[1], m[2]))
	end

	return b:finish()
end

QG.Margin = MARGIN
QG.Size = S

return QG
