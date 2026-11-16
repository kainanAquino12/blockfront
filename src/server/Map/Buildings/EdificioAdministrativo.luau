--[[
	Edifício Administrativo — sede do governo local, a leste da praça B.

	Bloco de 6 andares em torno de um ÁTRIO central aberto (pátio com
	galerias). Fica sobre o eixo z = 0 e é simétrico em z na volumetria.
	Planta 36 x 80 studs (x 0..35, z 0..79), piso a piso 9.

	Identidade (diferente das torres comerciais):
	  - pórtico monumental de pé-direito duplo na fachada oeste (voltada
	    para a praça), colunata de pedra e entablamento
	  - fachadas de tijolo com janelas verticais recuadas e pilastras (os
	    pilares da estrutura ficam 1 célula para fora da parede)
	  - átrio com galerias e guarda-corpos, vigas metálicas cruzando o
	    átrio na cobertura (claraboia)
	  - duas escadas (núcleos de concreto) nas alas norte e sul

	Estrutura (StructuralGraph): fundação, pilares por andar, vigas nas
	linhas da malha, painéis de laje por vão, núcleos portantes. Fachadas,
	vidro, divisórias e colunata de enfeite não sustentam nada (exceto as
	colunas do pórtico, que são pilares de verdade e seguram o entablamento).
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Admin = {}

local W, D = 36, 80
local FLOORS = 6
local FH = 11
local COLS_X = { 0, 12, 22, 34 }
local COLS_Z = { 0, 10, 20, 30, 40, 50, 60, 70, 78 }
local ATRIUM = { x0 = 14, x1 = 21, z0 = 22, z1 = 57 } -- vazio central (entre linhas 12 e 22 / 20 e 60)
local MARGIN = 3
local RC = "ReinforcedConcrete"

local function L(k: number): number
	return k * FH
end

local function inAtrium(x0: number, z0: number, x1: number, z1: number): boolean
	return x0 >= ATRIUM.x0 - 2 and x1 <= ATRIUM.x1 + 2 and z0 >= ATRIUM.z0 - 2 and z1 <= ATRIUM.z1 + 2
end

function Admin.build()
	local b = BuildingKit.new(W + MARGIN * 2 + 4, L(FLOORS) + 10, D + MARGIN * 2, Vector3.new(MARGIN + 4, 0, MARGIN))

	b:add("Foundation", RC, -5, 0, -1, W, 0, D, "Fundacao")

	-- lajes e vigas (o átrio fica sem laje do 1º andar para cima)
	for k = 1, FLOORS do
		local y = L(k)
		for i = 1, #COLS_X - 1 do
			for j = 1, #COLS_Z - 1 do
				local x0, x1 = COLS_X[i] + 2, COLS_X[i + 1] - 1
				local z0, z1 = COLS_Z[j] + 2, COLS_Z[j + 1] - 1
				if not inAtrium(x0, z0, x1, z1) then
					b:add("Slab", RC, x0, y, z0, x1, y, z1, ("Laje_N%d_V%d_%d"):format(k, i, j))
				end
			end
		end
		for j, cz in COLS_Z do
			for i = 1, #COLS_X - 1 do
				b:add("Beam", RC, COLS_X[i] + 2, y - 1, cz, COLS_X[i + 1] - 1, y, cz + 1, ("VigaX_N%d_L%d_V%d"):format(k, j, i))
			end
		end
		for i, cx in COLS_X do
			for j = 1, #COLS_Z - 1 do
				b:add("Beam", RC, cx, y - 1, COLS_Z[j] + 2, cx + 1, y, COLS_Z[j + 1] - 1, ("VigaZ_N%d_L%d_V%d"):format(k, i, j))
			end
		end
		-- vigas transversais que atravessariam o vazio do átrio saem (menos na cobertura)
		if k < FLOORS then
			b:carve(ATRIUM.x0, y - 1, ATRIUM.z0, ATRIUM.x1, y, ATRIUM.z1)
		end
	end

	-- pilares por andar (célula da laje pertence ao pilar de cima)
	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f)
		for i, cx in COLS_X do
			for j, cz in COLS_Z do
				b:add("Column", RC, cx, y0, cz, cx + 1, L(f + 1) - 1, cz + 1, ("Pilar_%d_%d_A%d"):format(i, j, f))
			end
		end
	end
	for i, cx in COLS_X do
		for j, cz in COLS_Z do
			b:add("Column", RC, cx, L(FLOORS), cz, cx + 1, L(FLOORS), cz + 1, ("Pilar_%d_%d_Topo"):format(i, j))
		end
	end

	-- núcleos de escada nas alas sul e norte (ala leste, entre as linhas 22 e 34)
	local levels = {}
	for k = 0, FLOORS do
		table.insert(levels, L(k))
	end
	b:stairCore(24, 3, levels, { Penthouse = 7, Name = "NucleoSul" })
	b:stairCore(24, 63, levels, { Penthouse = 7, Name = "NucleoNorte" })

	---------------------------------------------------------------------
	-- Fachadas: tijolo com janelas verticais recuadas; pilares viram pilastras
	---------------------------------------------------------------------
	local function bays(cols: { number })
		local out = {}
		for i = 1, #cols - 1 do
			table.insert(out, { cols[i] + 2, cols[i + 1] - 1, i })
		end
		return out
	end
	local baysX, baysZ = bays(COLS_X), bays(COLS_Z)

	for f = 0, FLOORS - 1 do
		local y0 = if f == 0 then 1 else L(f) + 1
		local yt = L(f + 1) - 2
		local tag = "A" .. f
		local portico = f <= 1

		-- oeste (praça): pórtico de pé-direito duplo nos 2 primeiros andares
		for _, bay in baysZ do
			local a, c, j = bay[1], bay[2], bay[3]
			if portico then
				-- pano de vidro recuado 5 células atrás da colunata
				b:add("Glass", "TintedGlass", 5, y0, a, 5, yt, c, ("PorticoVidro_%s_%d"):format(tag, j))
				for z = a, c, 3 do
					b:add("Wall", "DarkMetal", 5, y0, z, 5, yt, z, ("PorticoCaixilho_%s_%d"):format(tag, z))
				end
			else
				local wall = b:add("Wall", "Brick", 1, y0, a, 1, yt, c, ("Fachada_O_%s_%d"):format(tag, j))
				local _ = wall
				for z = a + 1, c - 1, 3 do
					b:carve(1, y0 + 1, z, 1, yt - 1, z + 1)
					b:add("Glass", "TintedGlass", 1, y0 + 1, z, 1, yt - 1, z + 1, ("Janela_O_%s_%d"):format(tag, z))
					b:add("Wall", "Stone", 0, y0, z, 0, y0, z + 1, ("Peitoril_O_%s_%d"):format(tag, z))
				end
			end
		end
		-- leste: tijolo com janelas
		for _, bay in baysZ do
			local a, c, j = bay[1], bay[2], bay[3]
			b:add("Wall", "Brick", W - 2, y0, a, W - 2, yt, c, ("Fachada_L_%s_%d"):format(tag, j))
			for z = a + 1, c - 1, 3 do
				b:carve(W - 2, y0 + 1, z, W - 2, yt - 1, z + 1)
				b:add("Glass", "TintedGlass", W - 2, y0 + 1, z, W - 2, yt - 1, z + 1, ("Janela_L_%s_%d"):format(tag, z))
			end
		end
		-- sul e norte: tijolo com janelas largas
		for _, side in { { z = 1, n = "S" }, { z = D - 2, n = "N" } } do
			for _, bay in baysX do
				local a, c, i = bay[1], bay[2], bay[3]
				b:add("Wall", "Brick", a, y0, side.z, c, yt, side.z, ("Fachada_%s_%s_%d"):format(side.n, tag, i))
				b:carve(a + 2, y0 + 2, side.z, c - 2, yt - 1, side.z)
				b:add("Glass", "TintedGlass", a + 2, y0 + 2, side.z, c - 2, yt - 1, side.z, ("Janela_%s_%s_%d"):format(side.n, tag, i))
			end
		end
		-- entradas: portas largas no pórtico e portas laterais no térreo
		if f == 0 then
			b:carve(5, y0, 36, 5, y0 + 6, 43) -- portal principal
			b:carve(16, y0, 1, 19, y0 + 6, 1) -- sul
			b:carve(16, y0, D - 2, 19, y0 + 6, D - 2) -- norte
		end

		-- átrio: guarda-corpo nas bordas das galerias (andares de cima)
		if f >= 1 then
			local gy = L(f) + 1
			b:add("Wall", "DarkMetal", ATRIUM.x0 - 1, gy, ATRIUM.z0 - 1, ATRIUM.x1 + 1, gy, ATRIUM.z0 - 1, ("Galeria_S_%s"):format(tag))
			b:add("Wall", "DarkMetal", ATRIUM.x0 - 1, gy, ATRIUM.z1 + 1, ATRIUM.x1 + 1, gy, ATRIUM.z1 + 1, ("Galeria_N_%s"):format(tag))
			b:add("Wall", "DarkMetal", ATRIUM.x0 - 1, gy, ATRIUM.z0, ATRIUM.x0 - 1, gy, ATRIUM.z1, ("Galeria_O_%s"):format(tag))
			b:add("Wall", "DarkMetal", ATRIUM.x1 + 1, gy, ATRIUM.z0, ATRIUM.x1 + 1, gy, ATRIUM.z1, ("Galeria_L_%s"):format(tag))
		end

		-- divisórias: salas nas alas leste (fora dos núcleos) e oeste (andares 2+)
		if f >= 1 then
			for _, zr in { { 20, 31 }, { 32, 47 }, { 48, 59 } } do
				b:add("Partition", "Gypsum", 26, y0, zr[1], 26, L(f + 1) - 1, zr[2], ("Divisoria_L_%s_%d"):format(tag, zr[1]))
				b:carve(26, y0, zr[1] + 3, 26, y0 + 6, zr[1] + 5)
				b:add("Partition", "Gypsum", 27, y0, zr[2], 32, L(f + 1) - 1, zr[2], ("DivisoriaT_L_%s_%d"):format(tag, zr[2]))
			end
		end
		if f >= 2 then
			for _, zr in { { 2, 19 }, { 60, 77 } } do
				b:add("Partition", "Gypsum", 9, y0, zr[1], 9, L(f + 1) - 1, zr[2], ("Divisoria_O_%s_%d"):format(tag, zr[1]))
				b:carve(9, y0, zr[1] + 7, 9, y0 + 6, zr[1] + 9)
			end
		end
		-- mesas e arquivos como cobertura baixa
		if f >= 1 then
			for _, p in { { 3, 25 }, { 3, 45 }, { 28, 26 }, { 28, 52 } } do
				b:add("Prop", "Wood", p[1], y0, p[2], p[1] + 3, y0 + 1, p[2] + 1, ("Mesa_%s_%d_%d"):format(tag, p[1], p[2]))
			end
		end
	end

	---------------------------------------------------------------------
	-- Pórtico: colunata de pedra (pilares reais) + entablamento
	---------------------------------------------------------------------
	-- colunas a cada 7 (vão livre de 5 entre elas: passa um jogador de qualquer tamanho)
	for z = 4, D - 6, 7 do
		local onGrid = false
		for _, cz in COLS_Z do
			if z == cz or z == cz + 1 then
				onGrid = true
			end
		end
		if not onGrid then
			b:add("Column", "Stone", -3, 1, z, -2, L(2) - 2, z + 1, ("Colunata_%d"):format(z))
		end
	end
	b:add("Beam", "Stone", -4, L(2) - 1, 2, 1, L(2), D - 3, "Entablamento")
	b:add("Wall", "Stone", -4, L(2) + 1, 2, -4, L(2) + 1, D - 3, "Entablamento_Friso")
	-- escadaria de entrada (degraus largos de pedra)
	for s = 0, 1 do
		b:add("Prop", "Stone", -5 + s, 1, 30 + s, -4 + s, 1 + s - s, 49 - s, ("Degrau_%d"):format(s))
	end

	---------------------------------------------------------------------
	-- Cobertura: platibanda, cornija, vigas metálicas sobre o átrio
	---------------------------------------------------------------------
	local yr = L(FLOORS) + 1
	b:add("Wall", "Stone", 0, yr, 0, W - 1, yr + 1, 0, "Platibanda_S")
	b:add("Wall", "Stone", 0, yr, D - 1, W - 1, yr + 1, D - 1, "Platibanda_N")
	b:add("Wall", "Stone", 0, yr, 1, 0, yr + 1, D - 2, "Platibanda_O")
	b:add("Wall", "Stone", W - 1, yr, 1, W - 1, yr + 1, D - 2, "Platibanda_L")
	for z = ATRIUM.z0, ATRIUM.z1, 6 do
		b:add("Beam", "DarkMetal", ATRIUM.x0 - 2, yr, z, ATRIUM.x1 + 2, yr, z, ("Claraboia_%d"):format(z))
	end
	b:add("Prop", "DarkMetal", 4, yr, 6, 9, yr + 2, 12, "ArCondicionado_1")
	b:add("Prop", "DarkMetal", 4, yr, 66, 9, yr + 2, 72, "ArCondicionado_2")
	b:add("Prop", "DarkMetal", 2, yr, 39, 2, yr + 10, 40, "Mastro")

	return b:finish()
end

Admin.Margin = MARGIN
Admin.WestMargin = MARGIN + 4
Admin.Footprint = Vector2.new(W, D)

return Admin
