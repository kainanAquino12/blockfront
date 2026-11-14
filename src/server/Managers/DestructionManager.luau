--[[
	DestructionManager (servidor)
	Autoridade única sobre a destruição. Nenhum cliente altera células:
	armas (Fase 3) e DevTools chamam DestructionManager.explode no servidor
	depois de validar o pedido.

	Fluxo de uma explosão:
	  1. explode(): aplica dano esférico em cada estrutura ao alcance
	     (VoxelGrid.damageSphere), marca chunks sujos e enfileira as células
	     destruídas para os clientes. Marca a estrutura para checar apoio.
	  2. Passo agrupado (a cada BatchInterval, no Heartbeat):
	     a. checa apoio estrutural das estruturas atingidas e enfileira as
	        células soltas para o desmoronamento progressivo;
	     b. remove um lote de células soltas (de baixo para cima);
	     c. remonta os chunks sujos (com limite por passo);
	     d. envia UMA mensagem DestructionBatch para todos os clientes com
	        as explosões e as células removidas (buffers compactos).

	A destruição é persistente: nada é restaurado durante a partida.
	reset() existe para o RoundManager reconstruir o mapa entre partidas.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DestructionConfig = require(ReplicatedStorage.Shared.Config.DestructionConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local VoxelStructure = require(script.Parent.Parent.Destruction.VoxelStructure)

local DestructionManager = {}

local structures: { [number]: any } = {}

-- Estado por estrutura entre passos.
local dirtyChunks: { [any]: { [number]: true } } = {}
local pendingCells: { [any]: { idx: { number }, mats: { number }, collapse: { number }, collapseMats: { number } } } = {}
local needsSupportCheck: { [any]: true } = {}
local collapseQueue: { [any]: { number } } = {}
local pendingExplosions: { { Position: Vector3, Radius: number } } = {}

local stats = {
	Explosions = 0,
	CellsDestroyed = 0,
	CellsCollapsed = 0,
	BatchesSent = 0,
	ChunksRebuilt = 0,
}

local batchEvent: RemoteEvent

local function getPending(s)
	local p = pendingCells[s]
	if not p then
		p = { idx = {}, mats = {}, collapse = {}, collapseMats = {} }
		pendingCells[s] = p
	end
	return p
end

local function markDirty(s, cellIndex: number)
	local set = dirtyChunks[s]
	if not set then
		set = {}
		dirtyChunks[s] = set
	end
	set[s:ChunkIndexOfCell(cellIndex)] = true
end

-- Cria e registra uma estrutura destrutível.
function DestructionManager.createStructure(params: VoxelStructure.StructureParams)
	local s = VoxelStructure.new(params)
	structures[s.Id] = s
	return s
end

function DestructionManager.getStructures()
	return structures
end

function DestructionManager.getStats()
	return table.clone(stats)
end

--[[
	Explosão autoritativa.
	position: world space. radius: studs. damage: dano no centro (vida de célula).
	Retorna o número de células destruídas imediatamente (sem contar desmoronamento).
]]
function DestructionManager.explode(position: Vector3, radius: number, damage: number): number
	assert(typeof(position) == "Vector3", "explode: position inválida")
	if radius <= 0 or damage <= 0 or radius ~= radius or damage ~= damage then
		return 0
	end
	stats.Explosions += 1
	table.insert(pendingExplosions, { Position = position, Radius = radius })

	local total = 0
	for _, s in structures do
		if (s.BoundsCenter - position).Magnitude <= s.BoundsRadius + radius then
			local g = s:WorldToGrid(position)
			local rCells = radius / s.VoxelSize
			local destroyed, mats = s.Grid:damageSphere(
				g.X,
				g.Y,
				g.Z,
				rCells,
				damage,
				DestructionConfig.FalloffMin,
				DestructionConfig.MaxCellsScannedPerExplosion
			)
			if #destroyed > 0 then
				local p = getPending(s)
				for n, i in destroyed do
					markDirty(s, i)
					table.insert(p.idx, i)
					table.insert(p.mats, mats[n])
				end
				needsSupportCheck[s] = true
				total += #destroyed
			end
		end
	end
	stats.CellsDestroyed += total
	return total
end

-- Amostra até `max` pares (índice, material) e serializa em buffers.
local function packCells(idx: { number }, mats: { number }, max: number): (buffer, buffer, number)
	local n = #idx
	local count = math.min(n, max)
	local bIdx = buffer.create(count * 4)
	local bMat = buffer.create(count)
	local step = n / math.max(count, 1)
	for k = 0, count - 1 do
		local src = math.floor(k * step) + 1
		buffer.writeu32(bIdx, k * 4, idx[src])
		buffer.writeu8(bMat, k, mats[src])
	end
	return bIdx, bMat, n
end

local function step()
	-- a. Apoio estrutural
	for s in needsSupportCheck do
		local loose = s.Grid:findUnsupported()
		if #loose > 0 then
			local q = collapseQueue[s] or {}
			-- Evita duplicar células que já estão na fila.
			local seen = {}
			for _, i in q do
				seen[i] = true
			end
			for _, i in loose do
				if not seen[i] then
					table.insert(q, i)
				end
			end
			collapseQueue[s] = q
		end
	end
	table.clear(needsSupportCheck)

	-- b. Desmoronamento progressivo
	for s, q in collapseQueue do
		local p = getPending(s)
		local limit = math.min(#q, DestructionConfig.CollapseCellsPerStep)
		local grid = s.Grid
		for k = 1, limit do
			local i = q[k]
			local mat = grid:getMaterial(i)
			if mat ~= 0 then
				grid:clearCell(i)
				markDirty(s, i)
				table.insert(p.collapse, i)
				table.insert(p.collapseMats, mat)
				stats.CellsCollapsed += 1
			end
		end
		if limit >= #q then
			collapseQueue[s] = nil
		else
			table.move(q, limit + 1, #q, 1)
			for k = #q - limit + 1, #q do
				q[k] = nil
			end
		end
	end

	-- c. Remontagem dos chunks sujos
	local budget = DestructionConfig.MaxChunkRebuildsPerStep
	for s, set in dirtyChunks do
		for ci in set do
			if budget <= 0 then
				break
			end
			s:RebuildChunk(ci)
			set[ci] = nil
			budget -= 1
			stats.ChunksRebuilt += 1
		end
		if next(set) == nil then
			dirtyChunks[s] = nil
		end
		if budget <= 0 then
			break
		end
	end

	-- d. Envio agrupado
	if #pendingExplosions == 0 and next(pendingCells) == nil then
		return
	end

	local message = {
		Explosions = pendingExplosions,
		Structures = {},
	}
	for s, p in pendingCells do
		local entry = {
			Id = s.Id,
			Origin = s.Origin,
			VoxelSize = s.VoxelSize,
			SizeX = s.Grid.sizeX,
			SizeY = s.Grid.sizeY,
		}
		if #p.idx > 0 then
			entry.Cells, entry.Mats, entry.CellsTotal = packCells(p.idx, p.mats, DestructionConfig.MaxCellsPerMessage)
		end
		if #p.collapse > 0 then
			entry.Collapse, entry.CollapseMats, entry.CollapseTotal =
				packCells(p.collapse, p.collapseMats, DestructionConfig.MaxCellsPerMessage)
		end
		table.insert(message.Structures, entry)
	end
	pendingExplosions = {}
	table.clear(pendingCells)

	if #Players:GetPlayers() > 0 then
		batchEvent:FireAllClients(message)
		stats.BatchesSent += 1
	end
end

-- Remove todas as estruturas (usado entre partidas para reconstruir o mapa).
function DestructionManager.reset()
	for _, s in structures do
		s.Model:Destroy()
	end
	table.clear(structures)
	table.clear(dirtyChunks)
	table.clear(pendingCells)
	table.clear(needsSupportCheck)
	table.clear(collapseQueue)
	pendingExplosions = {}
end

-- Executa um passo imediatamente (útil para testes automatizados).
function DestructionManager.flush()
	step()
end

function DestructionManager.init()
	batchEvent = Remotes.get("DestructionBatch")
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= DestructionConfig.BatchInterval then
			acc = 0
			step()
		end
	end)
end

return DestructionManager
