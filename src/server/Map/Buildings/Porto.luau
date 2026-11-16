--[[
	Porto (V6) — armazém portuário, pórtico de carga e silos, a oeste do canal.
	Fica sobre o eixo z = 0 (simétrico em z na volumetria).

	Armazém de CONCRETO (diferente da nave de aço da indústria):
	  - 34 x 96 studs, pórticos de concreto a cada 12, vigas transversais
	    e vigas de borda, cobertura em lajes por vão com lanternim de vidro
	  - doca de carga elevada no lado leste (voltada ao canal) com portões
	  - escritório de 2 andares dentro da ponta sul (núcleo de escada)
	Pórtico de carga (guindaste) de aço entre o armazém e o canal:
	  4 pernas de 30 studs, vigas mestras, carro e cabine.
	Bateria de silos de concreto ao norte e ao sul, com passarela no topo.

	Coordenadas locais: x 0..95 (oeste->leste), z 0..159 (sul->norte).
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Porto = {}

local MARGIN = 2
local RC = "ReinforcedConcrete"
local W = { x0 = 4, x1 = 37, z0 = 32, z1 = 127 } -- armazém
local H = 14

function Porto.build()
	local b = BuildingKit.new(96 + MARGIN * 2, 46, 160 + MARGIN * 2, Vector3.new(MARGIN, 0, MARGIN))
	b:add("Foundation", RC, 0, 0, 0, 95, 0, 159, "Fundacao")
	b.lightKind = "Industrial" -- refletores no armazém (luz automática das lajes)

	---------------------------------------------------------------------
	-- Armazém
	---------------------------------------------------------------------
	local frames = {}
	for z = W.z0, W.z1 - 1, 12 do
		table.insert(frames, z)
	end
	table.insert(frames, W.z1 - 1)
	for n, z in frames do
		for _, x in { W.x0, W.x1 - 1 } do
			b:add("Column", RC, x, 1, z, x + 1, H - 1, z + 1, ("Pilar_%d_%d"):format(x, n))
		end
		b:add("Beam", RC, W.x0 + 2, H - 1, z, W.x1 - 2, H, z + 1, ("VigaT_%d"):format(n))
	end
	for n = 1, #frames - 1 do
		local z0, z1 = frames[n] + 2, frames[n + 1] - 1
		if z1 >= z0 then
			for _, x in { W.x0, W.x1 - 1 } do
				b:add("Beam", RC, x, H - 1, z0, x + 1, H, z1, ("VigaBorda_%d_%d"):format(x, n))
			end
			b:add("Slab", RC, W.x0 + 2, H, z0, 14, H, z1, ("Cobertura_O_%d"):format(n))
			b:add("Slab", RC, 27, H, z0, W.x1 - 2, H, z1, ("Cobertura_L_%d"):format(n))
			-- lanternim: faixa central elevada com vidro nas laterais
			b:add("Glass", "Glass", 15, H, z0, 26, H, z1, ("Claraboia_%d"):format(n))
			-- paredes: base de concreto + painéis de concreto pré-moldado
			b:add("Wall", "Concrete", W.x0, 1, z0, W.x0, H - 2, z1, ("Parede_O_%d"):format(n))
			b:carve(W.x0, 8, z0 + 2, W.x0, 10, z1 - 2)
			b:add("Glass", "Glass", W.x0, 8, z0 + 2, W.x0, 10, z1 - 2, ("JanelaAlta_O_%d"):format(n))
			b:add("Wall", "FacadePanel", W.x1 - 1, 1, z0, W.x1 - 1, H - 2, z1, ("Parede_L_%d"):format(n))
			-- portão de carga em cada vão do lado leste (doca)
			b:carve(W.x1 - 1, 2, z0 + 2, W.x1 - 1, 9, z1 - 2)
		end
	end
	-- empenas sul e norte com portão central
	for _, z in { W.z0, W.z1 } do
		b:add("Wall", "FacadePanel", W.x0 + 2, 1, z, W.x1 - 2, H - 2, z, "Empena_" .. z)
		b:carve(15, 1, z, 26, 10, z)
	end
	-- doca de carga elevada (concreto) com para-choques
	b:add("Foundation", RC, W.x1 + 1, 1, W.z0, W.x1 + 6, 2, W.z1, "Doca")
	for z = W.z0 + 4, W.z1 - 4, 12 do
		b:add("Prop", "DarkMetal", W.x1 + 7, 1, z, W.x1 + 7, 2, z + 1, ("ParaChoque_%d"):format(z))
	end
	-- escritório de 2 andares na ponta sul (dentro do armazém)
	b:add("Slab", RC, W.x0 + 2, 7, W.z0 + 2, W.x1 - 2, 7, W.z0 + 21, "Escritorio_Laje")
	b:add("Beam", RC, W.x0 + 2, 6, W.z0 + 22, W.x1 - 2, 7, W.z0 + 23, "Escritorio_Viga")
	for _, x in { W.x0 + 10, W.x0 + 22 } do
		b:add("Column", RC, x, 1, W.z0 + 22, x + 1, 5, W.z0 + 23, ("Escritorio_Pilar_%d"):format(x))
	end
	b:add("Wall", "Gypsum", W.x0 + 2, 8, W.z0 + 22, W.x1 - 2, 10, W.z0 + 22, "Escritorio_Visor_Base")
	b:stairCore(W.x0 + 24, W.z0 + 4, { 0, 7 }, { Name = "EscritorioNucleo" })
	-- pallets e máquinas (cobertura)
	for _, p in { { 10, 50 }, { 24, 62 }, { 10, 78 }, { 24, 94 }, { 14, 110 } } do
		b:add("Prop", "Wood", p[1], 1, p[2], p[1] + 4, 3, p[2] + 3, ("Pallets_%d"):format(p[2]))
	end

	---------------------------------------------------------------------
	-- Pórtico de carga (aço) entre o armazém e o canal
	---------------------------------------------------------------------
	local G = { x0 = 52, x1 = 88, z0 = 60, z1 = 99, h = 30 }
	for _, x in { G.x0, G.x1 - 2 } do
		for _, z in { G.z0, G.z1 - 2 } do
			b:add("Column", "Metal", x, 1, z, x + 2, G.h, z + 2, ("Perna_%d_%d"):format(x, z))
		end
		b:add("Beam", "Metal", x, G.h + 1, G.z0, x + 2, G.h + 2, G.z1, ("VigaMestra_%d"):format(x))
		-- travessas baixas (contraventamento)
		b:add("Beam", "DarkMetal", x + 1, 12, G.z0 + 3, x + 1, 12, G.z1 - 3, ("Contraventamento_%d"):format(x))
	end
	for _, z in { G.z0, G.z1 - 2 } do
		b:add("Beam", "Metal", G.x0 + 3, G.h + 1, z, G.x1 - 3, G.h + 2, z + 2, ("VigaTesta_%d"):format(z))
	end
	-- carro (viga de rolamento entre as testas) com cabine e cabo pendurados: um elemento só
	local carro = b:add("Prop", "DarkMetal", 66, G.h + 3, G.z0, 74, G.h + 5, G.z1 - 1, "Carro")
	b:extend(carro, 70, 14, 79, 70, G.h + 2, 80)
	b:extend(carro, 71, G.h - 2, 76, 75, G.h + 2, 79)
	-- contêineres sob o pórtico
	for _, c in { { 58, 66 }, { 58, 82 }, { 72, 66 }, { 72, 88 } } do
		b:add("Prop", "SheetMetal", c[1], 1, c[2], c[1] + 5, 6, c[2] + 11, ("Conteiner_%d_%d"):format(c[1], c[2]))
	end
	b:add("Prop", "SheetMetal", 58, 7, 66, 63, 12, 77, "Conteiner_Pilha")

	---------------------------------------------------------------------
	-- Silos (concreto) ao sul e ao norte, com passarela no topo
	---------------------------------------------------------------------
	for _, zc in { 12, 147 } do
		local ids = {}
		for k, xc in { 50, 62, 74 } do
			local id = b:add("BearingWall", RC, xc - 4, 1, zc - 2, xc - 4, 32, zc + 2, ("Silo_%d_%d"):format(zc, k))
			for _, r in { { xc + 4, zc - 2, xc + 4, zc + 2 }, { xc - 2, zc - 4, xc + 2, zc - 4 }, { xc - 2, zc + 4, xc + 2, zc + 4 },
				{ xc - 3, zc - 3, xc - 3, zc - 3 }, { xc + 3, zc - 3, xc + 3, zc - 3 }, { xc - 3, zc + 3, xc - 3, zc + 3 }, { xc + 3, zc + 3, xc + 3, zc + 3 } } do
				b:extend(id, r[1], 1, r[2], r[3], 32, r[4])
			end
			table.insert(ids, id)
			b:add("Roof", RC, xc - 3, 33, zc - 3, xc + 3, 33, zc + 3, ("SiloTampa_%d_%d"):format(zc, k))
		end
		b:add("Wall", "DarkMetal", 46, 34, zc - 1, 78, 34, zc + 1, ("Passarela_%d"):format(zc))
		b:add("Wall", "DarkMetal", 46, 35, zc - 1, 78, 35, zc - 1, ("PassarelaGC_%d"):format(zc))
	end

	return b:finish()
end

Porto.Margin = MARGIN

return Porto
