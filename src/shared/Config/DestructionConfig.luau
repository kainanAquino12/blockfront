--[[
	DestructionConfig
	Parâmetros do sistema de destruição voxel. Todos os limites de
	performance ficam aqui para serem ajustados em um só lugar.
]]

local DestructionConfig = {}

-- Tamanho padrão (studs) de uma célula voxel.
DestructionConfig.VoxelSize = 1

-- Lado de um chunk, em células. Um chunk é a unidade de reconstrução visual:
-- quando uma célula muda, só o chunk dela é remontado.
DestructionConfig.ChunkSize = 8

-- Servidor: intervalo (s) entre envios agrupados para os clientes.
DestructionConfig.BatchInterval = 0.05

-- Servidor: limite de chunks remontados por passo (o resto fica para o próximo).
DestructionConfig.MaxChunkRebuildsPerStep = 32

-- Servidor: limite de células examinadas por explosão (proteção contra raios absurdos).
DestructionConfig.MaxCellsScannedPerExplosion = 20000

-- Servidor: máximo de células enviadas por estrutura em cada mensagem.
-- Acima disso é feita amostragem (o cliente só precisa delas para os fragmentos).
DestructionConfig.MaxCellsPerMessage = 300

-- Dano mínimo na borda da explosão, como fração do dano central.
DestructionConfig.FalloffMin = 0.35

-- Desmoronamento: células sem apoio caem aos poucos (de baixo para cima),
-- no máximo esta quantidade por passo, criando o efeito progressivo.
DestructionConfig.CollapseCellsPerStep = 60

-- Cliente: fragmentos visuais (nunca existem no servidor).
DestructionConfig.Debris = {
	PoolSize = 260, -- partes pré-criadas
	MaxActive = 220, -- fragmentos simultâneos no máximo
	MaxPerBatch = 90, -- fragmentos por estrutura em uma mensagem
	LifetimeMin = 2.0,
	LifetimeMax = 3.5,
	FadeTime = 0.5,
	MaxDistance = 350, -- não cria fragmentos longe da câmera
	SizeMin = 0.45, -- fração do VoxelSize
	SizeMax = 0.9,
	Speed = 38, -- velocidade de ejeção a partir do centro da explosão
}

-- Explosões de teste (DevTools) e base para as armas da Fase 3.
DestructionConfig.Presets = {
	DevBig = { Radius = 6, Damage = 260 },
	DevSmall = { Radius = 1.6, Damage = 140 },
}

return DestructionConfig
