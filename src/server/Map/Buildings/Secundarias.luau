--[[
	Construções secundárias (V7) — todas por BuildingKit (destrutíveis, com
	grafo estrutural). Cada uma tem desenho próprio; nenhuma é caixa repetida.

	  CentroComercial  2 andares, vitrines, lojas, escada, letreiro (44 x 32)
	  Posto            cobertura sobre 4 pilares + loja de conveniência + bombas
	  Oficina          oficina mecânica com 3 portões, escritório e fosso
	  Deposito         depósito de tijolo com telhado em dente de serra
	  ParqueTanques    3 tanques de armazenamento com dique de contenção
	  Celeiro          celeiro de madeira abandonado, parcialmente destruído

	Todas devolvem o def do BuildingKit; a frente (entrada) fica em z = 0.
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Sec = {}
local RC = "ReinforcedConcrete"

-- Grade de pilares/vigas/lajes (helper comum).
local function frame(b, cxs, czs, levels, colMat)
	for k = 2, #levels do
		local y = levels[k]
		for i = 1, #cxs - 1 do
			for j = 1, #czs - 1 do
				b:add("Slab", RC, cxs[i] + 2, y, czs[j] + 2, cxs[i + 1] - 1, y, czs[j + 1] - 1, ("Laje_N%d_%d%d"):format(k - 1, i, j))
			end
		end
		for j, c in czs do
			for i = 1, #cxs - 1 do
				b:add("Beam", RC, cxs[i] + 2, y - 1, c, cxs[i + 1] - 1, y, c + 1, ("VigaX_N%d_%d_%d"):format(k - 1, j, i))
			end
		end
		for i, c in cxs do
			for j = 1, #czs - 1 do
				b:add("Beam", RC, c, y - 1, czs[j] + 2, c + 1, y, czs[j + 1] - 1, ("VigaZ_N%d_%d_%d"):format(k - 1, i, j))
			end
		end
	end
	for f = 1, #levels - 1 do
		for i, cx in cxs do
			for j, cz in czs do
				local y0 = if f == 1 then levels[1] + 1 else levels[f]
				b:add("Column", colMat or RC, cx, y0, cz, cx + 1, levels[f + 1] - 1, cz + 1, ("Pilar_%d%d_A%d"):format(i, j, f - 1))
			end
		end
	end
	for i, cx in cxs do
		for j, cz in czs do
			local top = levels[#levels]
			b:add("Column", colMat or RC, cx, top, cz, cx + 1, top, cz + 1, ("Pilar_%d%d_Topo"):format(i, j))
		end
	end
end

---------------------------------------------------------------------------
function Sec.centroComercial()
	local W, D = 44, 32
	local b = BuildingKit.new(W + 6, 32, D + 8, Vector3.new(3, 0, 5))
	b:add("Foundation", RC, -1, 0, -4, W, 0, D, "Fundacao")
	local cxs, czs, levels = { 0, 14, 28, 42 }, { 0, 15, 30 }, { 0, 10, 20 }
	frame(b, cxs, czs, levels)
	b:stairCore(30, 8, levels, { Name = "Nucleo" })
	for f = 0, 1 do
		local y0, yt = levels[f + 1] + 1, levels[f + 2] - 2
		for i = 1, 3 do
			local a, c = cxs[i] + 2, cxs[i + 1] - 1
			-- frente: vitrines recuadas 2 no térreo, fita de vidro em cima
			if f == 0 then
				b:add("Glass", "TintedGlass", a, y0, 2, c, yt, 2, ("Vitrine_%d"):format(i))
				b:add("Wall", "DarkMetal", a, yt, 2, c, yt, 2, ("VitrineQuadro_%d"):format(i))
				b:carve(a + 4, y0, 2, a + 6, y0 + 5, 2) -- porta de cada loja
			else
				b:add("Wall", "FacadePanel", a, y0, 0, c, y0 + 1, 0, ("Peitoril_%d"):format(i))
				b:add("Glass", "TintedGlass", a, y0 + 2, 0, c, yt, 0, ("Fita_%d"):format(i))
			end
			-- fundos: bloco cego com porta de serviço
			b:add("Wall", "Brick", a, y0, D - 1, c, yt, D - 1, ("Fundos_%s_%d"):format(f, i))
		end
		for _, x in { 0, W - 1 } do
			for j = 1, 2 do
				local a, c = czs[j] + 2, czs[j + 1] - 1
				b:add("Wall", "Brick", x, y0, a, x, yt, c, ("Lateral_%d_%d_%d"):format(x, f, j))
			end
		end
		if f == 0 then
			b:carve(6, y0, D - 1, 8, y0 + 5, D - 1)
			-- lojas: divisórias e balcões
			for _, x in { 14, 28 } do
				b:add("Partition", "Gypsum", x + 2, y0, 3, x + 2, yt, 14, ("DivLoja_%d"):format(x))
			end
			b:add("Prop", "Wood", 4, y0, 9, 10, y0 + 1, 10, "Balcao_1")
			b:add("Prop", "Wood", 18, y0, 9, 24, y0 + 1, 10, "Balcao_2")
		end
	end
	-- marquise contínua sobre as vitrines e letreiro na platibanda
	b:add("Slab", RC, 0, levels[2] - 1, -3, W - 1, levels[2] - 1, -1, "Marquise")
	b:add("Wall", "Concrete", 0, 21, 0, W - 1, 22, 0, "Platibanda_F")
	b:add("Wall", "Concrete", 0, 21, D - 1, W - 1, 22, D - 1, "Platibanda_T")
	b:add("Prop", "DarkMetal", 12, 23, 0, 31, 25, 0, "Letreiro")
	return b:finish()
end

---------------------------------------------------------------------------
function Sec.posto()
	local b = BuildingKit.new(34, 14, 30, Vector3.new(1, 0, 1))
	b:add("Foundation", RC, -1, 0, -1, 32, 0, 28, "Piso")
	-- cobertura das bombas: 4 pilares, vigas e laje
	for _, x in { 2, 18 } do
		for _, z in { 2, 12 } do
			b:add("Column", "Metal", x, 1, z, x + 1, 8, z + 1, ("PilarCobertura_%d_%d"):format(x, z))
		end
		b:add("Beam", "Metal", x, 9, 0, x + 1, 9, 15, ("VigaCobertura_%d"):format(x))
	end
	b:add("Roof", "SheetMetal", 0, 10, 0, 21, 10, 15, "Cobertura")
	b:add("Wall", "DarkMetal", 0, 11, 0, 21, 11, 0, "Faixa_F")
	for _, x in { 6, 13 } do
		b:add("Prop", "Concrete", x, 1, 4, x + 2, 1, 11, ("Ilha_%d"):format(x))
		for _, z in { 5, 9 } do
			b:add("Prop", "DarkMetal", x + 1, 2, z, x + 1, 4, z, ("Bomba_%d_%d"):format(x, z))
		end
	end
	-- loja de conveniência (paredes portantes de tijolo)
	local x0, x1, z0, z1 = 22, 31, 14, 27
	b:add("BearingWall", "Brick", x0, 1, z0, x1, 7, z0, "Loja_F")
	b:add("BearingWall", "Brick", x0, 1, z1, x1, 7, z1, "Loja_T")
	b:add("BearingWall", "Brick", x0, 1, z0, x0, 7, z1, "Loja_O")
	b:add("BearingWall", "Brick", x1, 1, z0, x1, 7, z1, "Loja_L")
	b:carve(24, 1, z0, 29, 6, z0)
	b:add("Glass", "TintedGlass", 24, 3, z0, 29, 6, z0, "Loja_Vitrine")
	b:carve(26, 1, z0, 27, 2, z0) -- porta (vidro só em cima)
	b:carve(x0, 1, 18, x0, 6, 20)
	b:add("Slab", RC, x0, 8, z0, x1, 8, z1, "Loja_Teto")
	b:add("Prop", "Wood", 24, 1, 22, 29, 2, 23, "Loja_Balcao")
	-- totem de preços
	b:add("Prop", "DarkMetal", 1, 1, 24, 1, 9, 24, "Totem_Haste")
	b:add("Prop", "FacadePanel", 0, 10, 23, 2, 13, 25, "Totem_Placa")
	return b:finish()
end

---------------------------------------------------------------------------
function Sec.oficina()
	local W, D, H = 26, 18, 8
	local b = BuildingKit.new(W + 2, H + 6, D + 6, Vector3.new(1, 0, 3))
	b:add("Foundation", RC, -1, 0, -3, W, 0, D, "Piso")
	-- paredes portantes
	b:add("BearingWall", "Brick", 0, 1, 0, W - 1, H, 0, "Frente")
	b:add("BearingWall", "Brick", 0, 1, D - 1, W - 1, H, D - 1, "Fundos")
	b:add("BearingWall", "Brick", 0, 1, 0, 0, H, D - 1, "Lado_O")
	b:add("BearingWall", "Brick", W - 1, 1, 0, W - 1, H, D - 1, "Lado_L")
	b:add("BearingWall", "Concrete", 18, 1, 1, 18, H, D - 2, "Parede_Escritorio")
	-- 3 portões (portas de enrolar abertas)
	for _, x in { 2, 7, 12 } do
		b:carve(x, 1, 0, x + 3, 6, 0)
		b:add("Wall", "SheetMetal", x, 6, 0, x + 3, 6, 0, ("Enrolada_%d"):format(x))
	end
	b:carve(18, 1, 8, 18, 6, 10) -- porta do escritório
	b:carve(21, 3, 0, 23, 5, 0)
	b:add("Glass", "TintedGlass", 21, 3, 0, 23, 5, 0, "Janela_Escritorio")
	-- telhado: vigas metálicas + chapa
	for z = 2, D - 3, 4 do
		b:add("Beam", "Metal", 1, H, z, W - 2, H, z, ("Terca_%d"):format(z))
	end
	b:add("Roof", "SheetMetal", 0, H + 1, 0, W - 1, H + 1, D - 1, "Telhado")
	for _, lz in { 6, 10 } do
		for _, lx in { 6, 13 } do
			b:light(lx, H - 1, lz, "Industrial")
		end
	end
	-- fosso, elevador e bancadas
	b:carve(4, 0, 6, 6, 0, 12)
	b:add("Prop", "DarkMetal", 9, 1, 6, 9, 5, 7, "Elevador_Coluna")
	b:add("Prop", "DarkMetal", 2, 1, 15, 12, 2, 16, "Bancada")
	b:add("Prop", "Wood", 20, 1, 12, 23, 2, 13, "Mesa")
	-- placa
	b:add("Prop", "FacadePanel", 5, H + 2, 0, 16, H + 3, 0, "Placa")
	return b:finish()
end

---------------------------------------------------------------------------
function Sec.deposito()
	local W, D = 30, 22
	local b = BuildingKit.new(W + 2, 18, D + 2, Vector3.new(1, 0, 1))
	b:add("Foundation", RC, -1, 0, -1, W, 0, D, "Piso")
	local H = 9
	b:add("BearingWall", "DarkBrick", 0, 1, 0, W - 1, H, 0, "Frente")
	b:add("BearingWall", "DarkBrick", 0, 1, D - 1, W - 1, H, D - 1, "Fundos")
	b:add("BearingWall", "DarkBrick", 0, 1, 0, 0, H, D - 1, "Lado_O")
	b:add("BearingWall", "DarkBrick", W - 1, 1, 0, W - 1, H, D - 1, "Lado_L")
	b:carve(11, 1, 0, 18, 7, 0) -- portão
	for x = 3, W - 4, 6 do
		b:carve(x, 5, D - 1, x + 2, 7, D - 1)
		b:add("Glass", "Glass", x, 5, D - 1, x + 2, 7, D - 1, ("Janela_%d"):format(x))
	end
	-- telhado em dente de serra (3 sheds): viga + água inclinada em degraus + vidro vertical
	for s = 0, 2 do
		local z0 = 1 + s * 7
		-- viga apoiada nas paredes laterais
		b:add("Beam", RC, 0, H + 1, z0, W - 1, H + 1, z0, ("Shed_Viga_%d"):format(s))
		-- água inclinada em degraus (um elemento só, preso na viga)
		local shed = b:add("Roof", "SheetMetal", 0, H + 2, z0, W - 1, H + 2, z0, ("Shed_%d"):format(s))
		for step = 1, 5 do
			local y = H + 2 + math.floor(step / 2)
			b:extend(shed, 0, y, z0 + step, W - 1, y, z0 + step)
		end
		-- vidro vertical do shed: as pontas apoiam no topo das paredes laterais
		b:add("Glass", "Glass", 0, H + 1, z0 + 6, W - 1, H + 4, z0 + 6, ("Shed_Vidro_%d"):format(s))
		for _, lx in { 8, 15, 22 } do
			b:light(lx, H, z0, "Industrial")
		end
	end
	for _, c in { { 3, 3 }, { 3, 10 }, { 22, 4 }, { 22, 12 } } do
		b:add("Prop", "Wood", c[1], 1, c[2], c[1] + 4, 4, c[2] + 4, ("Caixas_%d_%d"):format(c[1], c[2]))
	end
	return b:finish()
end

---------------------------------------------------------------------------
function Sec.parqueTanques()
	local b = BuildingKit.new(62, 20, 30, Vector3.new(1, 0, 1))
	b:add("Foundation", RC, -1, 0, -1, 60, 0, 28, "Base")
	-- dique de contenção (mureta)
	b:add("Wall", "Concrete", 0, 1, 0, 59, 2, 0, "Dique_F")
	b:add("Wall", "Concrete", 0, 1, 27, 59, 2, 27, "Dique_T")
	b:add("Wall", "Concrete", 0, 1, 1, 0, 2, 26, "Dique_O")
	b:add("Wall", "Concrete", 59, 1, 1, 59, 2, 26, "Dique_L")
	b:carve(28, 1, 0, 31, 2, 0)
	for k, xc in { 10, 30, 50 } do
		local zc, r, h = 14, 7, 14
		local id = b:add("BearingWall", "SheetMetal", xc - r, 1, zc - 2, xc - r, h, zc + 2, ("Tanque_%d"):format(k))
		for _, seg in {
			{ xc + r, zc - 2, xc + r, zc + 2 }, { xc - 2, zc - r, xc + 2, zc - r }, { xc - 2, zc + r, xc + 2, zc + r },
			{ xc - 6, zc - 4, xc - 5, zc - 3 }, { xc + 5, zc - 4, xc + 6, zc - 3 }, { xc - 6, zc + 3, xc - 5, zc + 4 }, { xc + 5, zc + 3, xc + 6, zc + 4 },
			{ xc - 4, zc - 6, xc - 3, zc - 5 }, { xc + 3, zc - 6, xc + 4, zc - 5 }, { xc - 4, zc + 5, xc - 3, zc + 6 }, { xc + 3, zc + 5, xc + 4, zc + 6 },
		} do
			b:extend(id, seg[1], 1, seg[2], seg[3], h, seg[4])
		end
		b:add("Roof", "SheetMetal", xc - 6, h + 1, zc - 6, xc + 6, h + 1, zc + 6, ("Tampa_%d"):format(k))
		-- escada de marinheiro externa
		b:add("Prop", "DarkMetal", xc, 1, zc - r - 1, xc, h + 1, zc - r - 1, ("Escadinha_%d"):format(k))
	end
	-- tubulação ligando os tanques (apoiada nos tanques e em suportes)
	b:add("Wall", "DarkMetal", 4, 16, 14, 56, 16, 14, "Tubo_Topo")
	for _, x in { 20, 40 } do
		b:add("Prop", "Metal", x, 1, 13, x, 15, 13, ("Suporte_%d"):format(x))
	end
	return b:finish()
end

---------------------------------------------------------------------------
function Sec.celeiro()
	local W, D = 20, 14
	local b = BuildingKit.new(W + 2, 21, D + 2, Vector3.new(1, 3, 1))
	-- fundação funda (o terreno do campo é irregular)
	b:add("Foundation", RC, -1, -3, -1, W, 0, D, "Base")
	for _, x in { 0, W - 1 } do
		b:add("BearingWall", "BarnWood", x, 1, 0, x, 8, D - 1, ("Lado_%d"):format(x))
	end
	b:add("BearingWall", "BarnWood", 1, 1, 0, W - 2, 8, 0, "Frente")
	b:add("BearingWall", "BarnWood", 1, 1, D - 1, W - 2, 8, D - 1, "Fundos")
	b:carve(7, 1, 0, 12, 7, 0)
	-- empena e telhado em duas águas (degraus)
	-- cada água do telhado é um elemento só (apoiado na parede lateral)
	local aguaO = b:add("Roof", "RoofTile", 0, 9, -1, 0, 9, D, "Telhado_O")
	local aguaL = b:add("Roof", "RoofTile", W - 1, 9, -1, W - 1, 9, D, "Telhado_L")
	for s = 1, 5 do
		b:extend(aguaO, s, 9 + s, -1, s, 9 + s, D)
		b:extend(aguaL, W - 1 - s, 9 + s, -1, W - 1 - s, 9 + s, D)
	end
	b:extend(aguaO, 6, 15, -1, W - 7, 15, D) -- cumeeira
	for s = 0, 5 do
		b:add("Wall", "BarnWood", s + 1, 9, 0, W - 2 - s, 9 + s - 1, 0, ("EmpenaF_%d"):format(s))
	end
	-- abandonado: buraco no telhado e parede lateral desabada
	b:carve(11, 9, 3, W, 16, 9)
	b:carve(W - 1, 1, 8, W - 1, 8, D - 1)
	b:add("Prop", "Hay", 2, 1, 2, 5, 3, 5, "Feno")
	return b:finish()
end

return Sec
