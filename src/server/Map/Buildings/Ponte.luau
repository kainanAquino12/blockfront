--[[
	Ponte de concreto sobre a vala (atravessa no eixo Z).

	Estrutura (StructuralGraph):
	  Foundation  cabeceiras nas duas margens e sapatas dos pilares no fundo
	  Column      dois pilares no meio do vão
	  Beam        travessa sobre os pilares
	  Beam        dois tabuleiros (cabeceira -> travessa), 2 de espessura
	  Wall        guarda-corpos (metal escuro) sobre o tabuleiro

	Destruir os pilares ou a travessa derruba os tabuleiros; destruir só o
	guarda-corpo não derruba nada.

	build(width, length, deckHeight): deckHeight = altura do topo da pista
	acima da origem (fundo da vala). Retorna o def do BuildingKit.
]]

local BuildingKit = require(script.Parent.Parent.BuildingKit)

local Ponte = {}

function Ponte.build(width: number, length: number, deckHeight: number)
	local W = width + 2
	local Lz = length
	local top = math.max(math.floor(deckHeight + 0.5), 4) -- topo da pista (em células)
	local b = BuildingKit.new(W, top + 3, Lz)
	local RC = "ReinforcedConcrete"
	local deck0 = top - 2 -- tabuleiro: células top-2 e top-1
	local mid = math.floor(Lz / 2)

	-- cabeceiras (apoiadas nas margens)
	b:add("Foundation", RC, 0, 0, 0, W - 1, top - 1, 3, "Cabeceira_1")
	b:add("Foundation", RC, 0, 0, Lz - 4, W - 1, top - 1, Lz - 1, "Cabeceira_2")
	-- sapatas e pilares no meio
	for _, x in { 2, W - 5 } do
		b:add("Foundation", RC, x - 1, 0, mid - 2, x + 3, 0, mid + 2, "Sapata_" .. x)
		b:add("Column", RC, x, 1, mid - 1, x + 2, deck0 - 2, mid + 1, "Pilar_" .. x)
	end
	-- travessa
	b:add("Beam", RC, 0, deck0 - 1, mid - 2, W - 1, deck0 - 1, mid + 2, "Travessa")
	-- tabuleiros
	-- tabuleiros: vigas-laje de cabeceira até o meio da travessa (2 apoios cada)
	b:add("Beam", RC, 0, deck0, 4, W - 1, top - 1, mid, "Tabuleiro_1")
	b:add("Beam", RC, 0, deck0, mid + 1, W - 1, top - 1, Lz - 5, "Tabuleiro_2")
	-- guarda-corpos
	for _, x in { 0, W - 1 } do
		b:add("Wall", "DarkMetal", x, top, 4, x, top, Lz - 5, "GuardaCorpo_" .. x)
		for z = 4, Lz - 5, 3 do
			b:add("Wall", "DarkMetal", x, top + 1, z, x, top + 1, z, ("Montante_%d_%d"):format(x, z))
		end
		b:add("Wall", "DarkMetal", x, top + 2, 4, x, top + 2, Lz - 5, "Corrimao_" .. x)
	end
	return b:finish()
end

return Ponte
