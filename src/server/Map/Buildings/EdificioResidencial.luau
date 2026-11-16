--[[
	Edifício Residencial — bloco de apartamentos (V6).

	Planta 34 x 34 (x 0..33, z 0..33), malha de pilares 11 x 11, piso a
	piso 9. Identidade:
	  - fachadas norte/sul de tijolo com SACADAS em balanço por vão e
	    porta-janela; leste/oeste com janelas recortadas em pares
	  - térreo com lojas (vitrines recuadas) e portaria com marquise
	  - núcleo de escada central (BuildingKit:stairCore) com casa de escada
	  - 4 apartamentos por andar (divisórias de gesso), móveis baixos
	  - cobertura com platibanda e caixa d'água
	Opções:
	  Floors   número de andares (padrão 8)
	  Wall     material da fachada (padrão "Brick")
	  Damaged  versão abandonada: a quina nordeste dos 3 últimos andares
	           já desabou (vãos inteiros removidos de forma estruturalmente
	           coerente) e as vitrines/janelas estão quebradas
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Res = {}

local S = 34
local FH = 9
local COLS = { 0, 11, 22, 32 }
local MARGIN = 3
local RC = "ReinforcedConcrete"

function Res.build(opts: { Floors: number?, Wall: string?, Damaged: boolean? }?)
	local FLOORS = (opts and opts.Floors) or 8
	local WALL = (opts and opts.Wall) or "Brick"
	local damaged = opts and opts.Damaged
	local function L(k: number): number
		return k * FH
	end
	local b = BuildingKit.new(S + MARGIN * 2, L(FLOORS) + 14, S + MARGIN * 2, Vector3.new(MARGIN, 0, MARGIN))
	if damaged then
		b.lightKind = "Emergency" -- prédio abandonado: só a luz de emergência ainda funciona
	end
	b:add("Foundation", RC, -1, 0, -1, S, 0, S, "Fundacao")

	for k = 1, FLOORS do
		local y = L(k)
		for i = 1, #COLS - 1 do
			for j = 1, #COLS - 1 do
				b:add("Slab", RC, COLS[i] + 2, y, COLS[j] + 2, COLS[i + 1] - 1, y, COLS[j + 1] - 1, ("Laje_N%d_%d%d"):format(k, i, j))
			end
		end
		for j, c in COLS do
			for i = 1, #COLS - 1 do
				b:add("Beam", RC, COLS[i] + 2, y - 1, c, COLS[i + 1] - 1, y, c + 1, ("VigaX_N%d_%d_%d"):format(k, j, i))
				b:add("Beam", RC, c, y - 1, COLS[i] + 2, c + 1, y, COLS[i + 1] - 1, ("VigaZ_N%d_%d_%d"):format(k, j, i))
			end
		end
	end
	for f = 0, FLOORS - 1 do
		for i, cx in COLS do
			for j, cz in COLS do
				b:add("Column", RC, cx, if f == 0 then 1 else L(f), cz, cx + 1, L(f + 1) - 1, cz + 1, ("Pilar_%d%d_A%d"):format(i, j, f))
			end
		end
	end
	for i, cx in COLS do
		for j, cz in COLS do
			b:add("Column", RC, cx, L(FLOORS), cz, cx + 1, L(FLOORS), cz + 1, ("Pilar_%d%d_Topo"):format(i, j))
		end
	end

	local levels = {}
	for k = 0, FLOORS do
		table.insert(levels, L(k))
	end
	-- núcleo em x 15..22: a porta (lado oeste, z 11..13) abre para um hall de 2 de largura
	-- entre o núcleo e a linha de pilares x 11..12 (em x 13 a porta ficava atrás de um pilar)
	b:stairCore(15, 10, levels, { Penthouse = 7, Name = "Nucleo" })

	-- fachadas
	local bays = { { 2, 10, 1 }, { 13, 21, 2 }, { 24, 31, 3 } }
	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f) + 1
		local yt = L(f + 1) - 2
		local tag = "A" .. f
		for _, side in { { z = 0, out = -2, n = "S" }, { z = S - 1, out = S + 1, n = "N" } } do
			for _, bay in bays do
				local a, c, i = bay[1], bay[2], bay[3]
				if f == 0 then
					-- térreo: vitrines recuadas (lojas) e portaria no vão do meio
					b:add("Wall", "Concrete", a, y0, side.z, c, y0, side.z, ("Base_%s_%d"):format(side.n, i))
					b:add("Glass", "TintedGlass", a, y0 + 1, side.z, c, yt - 1, side.z, ("Vitrine_%s_%d"):format(side.n, i))
					b:add("Wall", "Concrete", a, yt, side.z, c, yt, side.z, ("Bandeira_%s_%d"):format(side.n, i))
					if i == 2 then
						b:carve(15, y0, side.z, 19, y0 + 6, side.z)
					end
				else
					b:add("Wall", WALL, a, y0, side.z, c, yt, side.z, ("Fachada_%s_%s_%d"):format(side.n, tag, i))
					-- porta-janela da sacada
					local m = math.floor((a + c) / 2)
					b:carve(m - 1, y0, side.z, m + 1, y0 + 6, side.z)
					b:add("Glass", "TintedGlass", m - 1, y0 + 1, side.z, m + 1, y0 + 6, side.z, ("PortaJanela_%s_%s_%d"):format(side.n, tag, i))
					-- janelas laterais do vão
					for _, w in { a + 1, c - 2 } do
						b:carve(w, y0 + 2, side.z, w + 1, y0 + 5, side.z)
						b:add("Glass", "TintedGlass", w, y0 + 2, side.z, w + 1, y0 + 5, side.z, ("Janela_%s_%s_%d_%d"):format(side.n, tag, i, w))
					end
					-- sacada em balanço (2 de profundidade) presa na viga de borda
					local sy = L(f)
					local z0, z1 = -2, -1
					if side.n == "N" then
						z0, z1 = S, S + 1
					end
					b:add("Slab", RC, m - 3, sy, z0, m + 3, sy, z1, ("Sacada_%s_%s_%d"):format(side.n, tag, i))
					local rz = if side.n == "S" then -2 else S + 1
					b:add("Wall", "DarkMetal", m - 3, sy + 1, rz, m + 3, sy + 3, rz, ("GuardaCorpo_%s_%s_%d"):format(side.n, tag, i))
					b:carve(m - 2, sy + 2, rz, m + 2, sy + 2, rz) -- vazado
				end
			end
		end
		-- leste/oeste: tijolo com janelas em pares
		for _, side in { { x = 0, n = "O" }, { x = S - 1, n = "L" } } do
			for _, bay in bays do
				local a, c, i = bay[1], bay[2], bay[3]
				b:add("Wall", WALL, side.x, y0, a, side.x, yt, c, ("Fachada_%s_%s_%d"):format(side.n, tag, i))
				for _, w in { a + 1, c - 2 } do
					b:carve(side.x, y0 + 2, w, side.x, y0 + 5, w + 1)
					b:add("Glass", "TintedGlass", side.x, y0 + 2, w, side.x, y0 + 5, w + 1, ("Janela_%s_%s_%d_%d"):format(side.n, tag, i, w))
				end
			end
		end
		-- apartamentos: divisórias de gesso com portas para o hall do núcleo
		if f >= 1 then
			b:add("Partition", "Gypsum", 2, y0, 8, 12, L(f + 1) - 1, 8, ("Div_SO_%s"):format(tag))
			b:add("Partition", "Gypsum", 21, y0, 8, 31, L(f + 1) - 1, 8, ("Div_SL_%s"):format(tag))
			b:add("Partition", "Gypsum", 2, y0, 25, 12, L(f + 1) - 1, 25, ("Div_NO_%s"):format(tag))
			b:add("Partition", "Gypsum", 21, y0, 25, 31, L(f + 1) - 1, 25, ("Div_NL_%s"):format(tag))
			b:add("Partition", "Gypsum", 6, y0, 9, 6, L(f + 1) - 1, 24, ("Div_O_%s"):format(tag))
			b:add("Partition", "Gypsum", 27, y0, 9, 27, L(f + 1) - 1, 24, ("Div_L_%s"):format(tag))
			for _, d in { { 8, 8 }, { 24, 8 }, { 8, 25 }, { 24, 25 } } do
				b:carve(d[1], y0, d[2], d[1] + 2, y0 + 6, d[2])
			end
			b:carve(6, y0, 15, 6, y0 + 6, 17)
			b:carve(27, y0, 15, 27, y0 + 6, 17)
			-- móveis (cobertura baixa)
			b:add("Prop", "Wood", 3, y0, 3, 6, y0 + 1, 4, ("Sofa_%s"):format(tag))
			b:add("Prop", "Wood", 26, y0, 28, 29, y0 + 1, 30, ("Mesa_%s"):format(tag))
		end
	end

	-- portaria: marquise sobre a entrada sul
	b:add("Slab", RC, 13, L(1) - 1, -3, 21, L(1) - 1, -1, "Marquise")

	-- cobertura
	local yr = L(FLOORS) + 1
	b:add("Wall", "Concrete", 0, yr, 0, S - 1, yr + 1, 0, "Platibanda_S")
	b:add("Wall", "Concrete", 0, yr, S - 1, S - 1, yr + 1, S - 1, "Platibanda_N")
	b:add("Wall", "Concrete", 0, yr, 1, 0, yr + 1, S - 2, "Platibanda_O")
	b:add("Wall", "Concrete", S - 1, yr, 1, S - 1, yr + 1, S - 2, "Platibanda_L")
	b:add("Prop", "SheetMetal", 25, yr, 25, 29, yr + 4, 29, "CaixaDagua")
	-- telhado como posição de combate: ar-condicionado, exaustores, muretas de cobertura
	b:add("Prop", "DarkMetal", 3, yr, 3, 7, yr + 2, 6, "ArCondicionado_1")
	b:add("Prop", "DarkMetal", 3, yr, 26, 6, yr + 2, 30, "ArCondicionado_2")
	b:add("Prop", "SheetMetal", 26, yr, 4, 27, yr + 1, 5, "Exaustor_1")
	b:add("Prop", "SheetMetal", 10, yr, 28, 11, yr + 1, 29, "Exaustor_2")
	b:add("Wall", "Concrete", 9, yr, 4, 13, yr + 1, 4, "Mureta_1")

	-- versão abandonada: quina nordeste desabada nos 3 últimos andares
	if damaged then
		local fy = L(FLOORS - 3) + 1
		b:carve(24, fy, 24, S + 2, L(FLOORS) + 6, S + 2)
		-- janelas e vitrines quebradas (vãos abertos) em vários pontos
		for f = 0, FLOORS - 1, 2 do
			b:carve(2, L(f) + 2, -1, 9, L(f) + 6, 0)
			b:carve(S - 1, L(f) + 2, 2, S - 1, L(f) + 6, 9)
		end
	end

	return b:finish()
end

Res.Margin = MARGIN
Res.Size = S

return Res
