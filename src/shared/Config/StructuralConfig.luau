--[[
	StructuralConfig
	Parâmetros do sistema STRUCTURAL INTEGRITY & PHYSICS COLLAPSE.

	Conceitos (detalhes em server/Destruction/StructuralGraph.luau):
	  Elemento  conjunto de células voxel com um papel na construção
	            (pilar, viga, laje, parede...). Cada célula pertence a um só.
	  Massa     células vivas x densidade do material.
	  Carga     massa própria + carga recebida dos elementos que ele apoia,
	            distribuída de cima para baixo pelo caminho de apoio.
	  Capacidade  calculada na construção: carga de projeto x fator de
	            segurança do tipo. Multiplicada pela integridade atual.
	  Integridade  células vivas / células iniciais.
]]

local StructuralConfig = {}

--[[
	Tipos de elemento.
	  Structural  sustenta outros elementos (transmite carga para baixo).
	  FailBelow   integridade abaixo da qual o elemento rompe sozinho.
	  Safety      fator de segurança sobre a carga de projeto (capacidade).
	              Ex.: 2.2 = aguenta 2,2x a carga original antes de ceder.
	  MinSupports quantos apoios precisa (viga/laje com 1 apoio só = balanço).
	  MaxCantilever  com menos apoios que MinSupports, ainda fica de pé se o
	              maior lado do elemento for <= este valor (sacadas, marquises).
]]
StructuralConfig.Types = {
	Foundation = { Structural = true, Grounded = true },
	-- pilar e parede portante: sem MinSupports. Sem o apoio de baixo, ficam pendurados nas vigas
	-- (peso 0.05) e é a sobrecarga nas vigas que decide se o trecho de cima cai.
	Column = { Structural = true, FailBelow = 0.45, Safety = 2.4 },
	BearingWall = { Structural = true, FailBelow = 0.35, Safety = 2.4 },
	Beam = { Structural = true, FailBelow = 0.4, Safety = 1.9, MinSupports = 2, MaxCantilever = 4 },
	Slab = { Structural = true, FailBelow = 0.3, Safety = 1.9, MinSupports = 3, MaxCantilever = 3 }, -- painel com 2 bordas só cede
	Stair = { Structural = false, FailBelow = 0.3 },
	Wall = { Structural = false }, -- vedação / fachada: só pesa, não sustenta
	Partition = { Structural = false }, -- divisória de gesso
	Glass = { Structural = false },
	Roof = { Structural = false },
	Prop = { Structural = false }, -- mesas, balcões, equipamentos
}

-- Densidade por nome de material (padrão 1). Vidro e gesso pesam pouco.
StructuralConfig.Density = {
	Glass = 0.3,
	TintedGlass = 0.3,
	Gypsum = 0.35,
	Wood = 0.45,
	Planks = 0.45,
	DarkMetal = 0.8,
	Metal = 1.2,
	ReinforcedConcrete = 1.1,
}

-- Um elemento sobrecarregado "range" por um tempo antes de ceder (s).
-- É o que transforma uma falha em colapso progressivo, em etapas.
StructuralConfig.UnstableDelayMin = 0.35
StructuralConfig.UnstableDelayMax = 0.9

-- Flood de conectividade (custo O(células)) no máximo a cada X s por estrutura.
StructuralConfig.FloodInterval = 0.3

-- Rupturas por passo de servidor (o resto fica para os próximos passos).
StructuralConfig.MaxBreaksPerStep = 6

-- Corpos físicos do colapso (servidor).
StructuralConfig.Bodies = {
	BlockSize = 7, -- células: blocos de até 7x7x7 viram um corpo
	BlockSizeMedium = 9, -- pedido com mais de 400 células
	BlockSizeLarge = 12, -- pedido com mais de 1500 células (andar inteiro cedendo)
	MaxActive = 72, -- corpos simulando ao mesmo tempo; o resto espera na fila (no lugar)
	MaxPartsPerBody = 20,
	SettleSpeed = 1.2, -- studs/s: abaixo disso conta como parado
	SettleTime = 0.8, -- parado por este tempo -> ancora e vira entulho
	MaxSimTime = 8, -- força a ancoragem depois disso
	KillY = -60,
	-- Entulho persistente: acima do orçamento, os mais antigos somem aos poucos.
	MaxRubbleParts = 1800,
	RubbleCleanupPerStep = 6,
	-- Impacto de corpo em queda em outra estrutura (cascata).
	ImpactSpeed = 22, -- velocidade mínima para causar dano
	ImpactDamagePerMass = 1.4,
	ImpactRadiusMin = 1.3,
	ImpactRadiusMax = 3.2,
	MaxImpactsPerSecond = 10,
	ExplosionImpulse = 30, -- velocidade inicial a partir da explosão mais próxima
}

return StructuralConfig
