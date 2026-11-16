--[[
	Complexo Industrial — ponto A (oeste). Fica sobre o eixo z = 0.

	Nave de fábrica de 76 x 84 studs com estrutura de AÇO:
	  - pórticos: pilares metálicos a cada 12 studs nas laterais + tesouras
	    (treliças) metálicas vencendo o vão inteiro em x
	  - viga de rolamento da ponte rolante apoiada em consoles dos pilares
	  - fechamento em chapa sobre embasamento de concreto, faixa de
	    janelas altas, portões grandes nas faces sul/norte e leste
	  - telhado de chapa apoiado nas tesouras, com claraboias de vidro
	  - mezanino de concreto (sala de controle) com escada metálica
	  - máquinas e contêineres como cobertura no piso
	Anexo de escritórios de 4 andares (concreto) colado à face leste, com
	núcleo de escada. Dois silos de chapa ao sul e ao norte.

	A destruição respeita o aço: sem os pilares de um pórtico, a tesoura
	daquele pórtico fica com 1 apoio e cai, levando o telhado do vão.
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Ind = {}

local HX, HZ = 76, 84 -- nave: x 0..75, z 0..83
local H = 20 -- altura até a corda inferior da tesoura
local BAY = 12
local MARGIN = 3
local ANNEX = { x0 = 76, x1 = 105, z0 = 28, z1 = 55, floors = 4 } -- anexo de escritórios
local RC = "ReinforcedConcrete"

function Ind.build()
	local b = BuildingKit.new(ANNEX.x1 + 2 + MARGIN * 2, 52, HZ + MARGIN * 2, Vector3.new(MARGIN, 0, MARGIN))

	b:add("Foundation", RC, -1, 0, -1, ANNEX.x1 + 1, 0, HZ, "Fundacao")

	-- pórticos: pilares metálicos (2x2) nas laterais oeste e leste da nave
	local frames = {}
	for z = 0, HZ - 2, BAY do
		table.insert(frames, z)
	end
	table.insert(frames, HZ - 2)
	for n, z in frames do
		for _, x in { 0, HX - 2 } do
			b:add("Column", "Metal", x, 1, z, x + 1, H + 1, z + 1, ("PilarAco_%d_%d"):format(x, n))
			-- console da viga de rolamento
			local cx = if x == 0 then 2 else HX - 3
			b:add("Beam", "Metal", cx, 13, z, cx, 13, z + 1, ("Console_%d_%d"):format(x, n))
		end
		-- tesoura: corda inferior, corda superior e montantes (um elemento só)
		local t = b:add("Beam", "Metal", 2, H, z, HX - 3, H, z, ("Tesoura_%d"):format(n))
		b:extend(t, 0, H + 3, z, HX - 1, H + 3, z)
		for x = 2, HX - 3, 6 do
			b:extend(t, x, H + 1, z, x, H + 2, z)
		end
		-- refletores industriais pendurados na corda inferior da tesoura
		for _, lx in { 16, 37, 58 } do
			b:light(lx, H - 1, z, "Industrial")
		end
		-- faixa do telhado sobre a tesoura (as chapas e claraboias se prendem nela)
		b:extend(t, 0, H + 4, z, HX - 1, H + 4, z)
	end
	-- vigas de rolamento (ao longo de z, sobre os consoles)
	for _, cx in { 2, HX - 3 } do
		for n = 1, #frames - 1 do
			b:add("Beam", "DarkMetal", cx, 14, frames[n], cx, 14, frames[n + 1] + 1, ("ViaRolamento_%d_%d"):format(cx, n))
		end
	end
	-- terças e telhado de chapa (apoiado nas tesouras), claraboias de vidro
	for n = 1, #frames - 1 do
		local z0, z1 = frames[n] + 1, frames[n + 1] - 1
		if z1 >= z0 then
			b:add("Roof", "SheetMetal", 0, H + 4, z0, 25, H + 4, z1, ("Telhado_O_%d"):format(n))
			b:add("Glass", "Glass", 26, H + 4, z0, 49, H + 4, z1, ("Claraboia_%d"):format(n))
			b:add("Roof", "SheetMetal", 50, H + 4, z0, HX - 1, H + 4, z1, ("Telhado_L_%d"):format(n))
		end
	end

	-- fechamento: embasamento de concreto + chapa + faixa de janelas altas
	for n = 1, #frames - 1 do
		local z0, z1 = frames[n] + 2, frames[n + 1] - 1
		for _, x in { 0, HX - 1 } do
			b:add("Wall", "Concrete", x, 1, z0, x, 3, z1, ("Embasamento_%d_%d"):format(x, n))
			b:add("Wall", "SheetMetal", x, 4, z0, x, H - 5, z1, ("Chapa_%d_%d"):format(x, n))
			b:add("Glass", "Glass", x, H - 4, z0, x, H - 2, z1, ("JanelaAlta_%d_%d"):format(x, n))
			b:add("Wall", "SheetMetal", x, H - 1, z0, x, H + 3, z1, ("Oitao_%d_%d"):format(x, n))
		end
	end
	-- faces sul e norte (empenas) com portão grande no meio
	for _, z in { 0, HZ - 1 } do
		local tag = if z == 0 then "S" else "N"
		b:add("Wall", "Concrete", 2, 1, z, HX - 3, 3, z, "EmpenaBase_" .. tag)
		-- a empena vai até logo abaixo da tesoura do pórtico da ponta
		b:add("Wall", "SheetMetal", 2, 4, z, HX - 3, H - 1, z, "Empena_" .. tag)
		b:carve(28, 1, z, 47, 14, z) -- portão (20 x 14)
		b:carve(8, 1, z, 11, 7, z) -- porta de pedestres
		b:carve(64, 1, z, 67, 7, z)
	end
	-- portão leste para o pátio (ao lado do anexo)
	b:carve(HX - 1, 1, 6, HX - 1, 12, 21)

	-- mezanino (sala de controle) no canto noroeste, sobre pilares de concreto
	b:add("Column", RC, 2, 1, 60, 3, 8, 61, "MezaninoPilar_1")
	b:add("Column", RC, 20, 1, 60, 21, 8, 61, "MezaninoPilar_2")
	b:add("Column", RC, 20, 1, 78, 21, 8, 79, "MezaninoPilar_3")
	b:add("Beam", RC, 2, 9, 60, 21, 9, 61, "MezaninoViga_S")
	b:add("Beam", RC, 20, 9, 62, 21, 9, 79, "MezaninoViga_L")
	b:add("Slab", RC, 2, 9, 62, 19, 9, 81, "MezaninoLaje")
	b:add("Wall", "Concrete", 2, 10, 62, 19, 12, 62, "MezaninoParapeito")
	b:carve(6, 10, 62, 9, 12, 62)
	b:add("Glass", "Glass", 6, 10, 62, 9, 12, 62, "MezaninoVisor")
	-- escada metálica do mezanino (degraus de 1 em 1)
	local st = b:add("Stair", "DarkMetal", 22, 1, 66, 24, 1, 66, "EscadaMetalica")
	for i = 0, 8 do
		b:extend(st, 22, 1 + i, 66 + i, 24, 1 + i, 66 + i)
	end
	-- o último degrau fica rente ao topo da viga: atravessa-se a viga a pé

	-- máquinas, prensas e contêineres (cobertura no piso)
	for _, m in {
		{ 10, 14, 17, 21, 5 }, { 30, 26, 39, 31, 4 }, { 50, 14, 57, 21, 6 },
		{ 30, 52, 39, 57, 4 }, { 52, 62, 59, 69, 5 }, { 10, 36, 13, 47, 3 },
	} do
		b:add("Prop", "DarkMetal", m[1], 1, m[2], m[3], m[5], m[4], ("Maquina_%d_%d"):format(m[1], m[2]))
	end
	for _, c in { { 62, 30 }, { 62, 46 }, { 22, 40 } } do
		b:add("Prop", "SheetMetal", c[1], 1, c[2], c[1] + 4, 5, c[2] + 11, ("Conteiner_%d_%d"):format(c[1], c[2]))
	end

	---------------------------------------------------------------------
	-- Anexo de escritórios (4 andares, concreto, colado à face leste)
	---------------------------------------------------------------------
	local a = ANNEX
	local AH = 10
	local levels = {}
	for k = 0, a.floors do
		table.insert(levels, k * AH)
	end
	local cxs = { a.x0, a.x0 + 13, a.x1 - 1 }
	local czs = { a.z0, a.z0 + 13, a.z1 - 1 }
	for k = 1, a.floors do
		local y = k * AH
		for i = 1, #cxs - 1 do
			for j = 1, #czs - 1 do
				b:add("Slab", RC, cxs[i] + 2, y, czs[j] + 2, cxs[i + 1] - 1, y, czs[j + 1] - 1, ("Anexo_Laje_N%d_%d%d"):format(k, i, j))
			end
		end
		for _, cz in czs do
			for i = 1, #cxs - 1 do
				b:add("Beam", RC, cxs[i] + 2, y - 1, cz, cxs[i + 1] - 1, y, cz + 1, ("Anexo_VigaX_N%d_%d_%d"):format(k, cz, i))
			end
		end
		for _, cx in cxs do
			for j = 1, #czs - 1 do
				b:add("Beam", RC, cx, y - 1, czs[j] + 2, cx + 1, y, czs[j + 1] - 1, ("Anexo_VigaZ_N%d_%d_%d"):format(k, cx, j))
			end
		end
	end
	for f = 0, a.floors - 1 do
		for _, cx in cxs do
			for _, cz in czs do
				local y0 = if f == 0 then 1 else (f * AH)
				b:add("Column", RC, cx, y0, cz, cx + 1, (f + 1) * AH - 1, cz + 1, ("Anexo_Pilar_%d_%d_A%d"):format(cx, cz, f))
			end
		end
		-- fachada: concreto com janelas em fita
		local y0 = f * AH + 1
		local yt = (f + 1) * AH - 2
		local tag = "A" .. f
		-- fachadas por fora da linha dos pilares (não comem células dos pilares)
		local xe = a.x1 + 1
		b:add("Wall", "Concrete", xe, y0, a.z0, xe, yt, a.z1, "Anexo_Fachada_L_" .. tag)
		b:carve(xe, y0 + 2, a.z0 + 3, xe, yt - 1, a.z1 - 3)
		b:add("Glass", "TintedGlass", xe, y0 + 2, a.z0 + 3, xe, yt - 1, a.z1 - 3, "Anexo_Fita_L_" .. tag)
		for _, z in { a.z0 - 1, a.z1 + 1 } do
			b:add("Wall", "Concrete", a.x0 + 2, y0, z, xe, yt, z, ("Anexo_Fachada_%d_%s"):format(z, tag))
			b:carve(a.x0 + 4, y0 + 2, z, a.x1 - 3, yt - 1, z)
			b:add("Glass", "TintedGlass", a.x0 + 4, y0 + 2, z, a.x1 - 3, yt - 1, z, ("Anexo_Fita_%d_%s"):format(z, tag))
		end
		-- ligação com a nave (porta no térreo)
		if f == 0 then
			b:carve(a.x0 - 1, 1, 38, a.x0 + 1, 7, 41)
		end
	end
	b:stairCore(a.x0 + 17, a.z0 + 2, levels, { Penthouse = 7, Name = "Anexo_Nucleo" })
	b:add("Wall", "Concrete", a.x0, a.floors * AH + 1, a.z0, a.x1 + 1, a.floors * AH + 2, a.z0, "Anexo_Platibanda_S")
	b:add("Wall", "Concrete", a.x0, a.floors * AH + 1, a.z1, a.x1 + 1, a.floors * AH + 2, a.z1, "Anexo_Platibanda_N")

	---------------------------------------------------------------------
	-- Silos (chapa) sobre bases de concreto
	---------------------------------------------------------------------
	for _, sz in { 6, HZ - 13 } do
		local cx, cz = 88, sz + 3
		b:add("Foundation", RC, cx - 4, 1, cz - 4, cx + 4, 1, cz + 4, ("SiloBase_%d"):format(sz))
		local id = b:add("Wall", "SheetMetal", cx - 3, 2, cz - 1, cx - 3, 22, cz + 1, ("Silo_%d"):format(sz))
		for _, r in { { cx + 3, cz - 1, cx + 3, cz + 1 }, { cx - 1, cz - 3, cx + 1, cz - 3 }, { cx - 1, cz + 3, cx + 1, cz + 3 },
			{ cx - 2, cz - 2, cx - 2, cz - 2 }, { cx + 2, cz - 2, cx + 2, cz - 2 }, { cx - 2, cz + 2, cx - 2, cz + 2 }, { cx + 2, cz + 2, cx + 2, cz + 2 } } do
			b:extend(id, r[1], 2, r[2], r[3], 22, r[4])
		end
		b:add("Roof", "SheetMetal", cx - 3, 23, cz - 3, cx + 3, 23, cz + 3, ("SiloTampa_%d"):format(sz))
	end

	return b:finish()
end

Ind.Margin = MARGIN
Ind.Footprint = Vector2.new(ANNEX.x1 + 2, HZ)

return Ind
