--[[
	DestructionManager (servidor)
	Autoridade única sobre a destruição. Nenhum cliente altera células:
	armas (Fase 3) e DevTools chamam DestructionManager.explode no servidor
	depois de validar o pedido.

	V4: STRUCTURAL INTEGRITY & PHYSICS COLLAPSE
	  - estruturas criadas com Elements (BuildingKit) ganham um
	    StructuralGraph: pilares, vigas, lajes, paredes portantes, vedações...
	    com massa, carga e capacidade (ver StructuralGraph.luau);
	  - tudo o que perde sustentação (elemento rompido, solto pelo grafo ou
	    célula sem caminho até o chão) vira corpo físico em CollapseBodies,
	    cai, colide, pode quebrar o que estiver embaixo e vira entulho
	    persistente. Nada mais é simplesmente apagado.

	Fluxo de uma explosão:
	  1. explode(): aplica dano esférico em cada estrutura ao alcance
	     (VoxelGrid.damageSphere), marca chunks sujos e enfileira as células
	     destruídas para os clientes. Marca a estrutura para checar apoio.
	  2. Passo agrupado (a cada BatchInterval, no Heartbeat):
	     a. avalia o grafo estrutural (se houver) e o apoio por conectividade;
	        o que caiu vai para CollapseBodies;
	     b. CollapseBodies cria os corpos da fila, simula impacto/assentamento;
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
local StructuralConfig = require(ReplicatedStorage.Shared.Config.StructuralConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local VoxelStructure = require(script.Parent.Parent.Destruction.VoxelStructure)
local StructuralGraph = require(script.Parent.Parent.Destruction.StructuralGraph)
local CollapseBodies = require(script.Parent.Parent.Destruction.CollapseBodies)

local DestructionManager = {}

local structures: { [number]: any } = {}

-- Estado por estrutura entre passos.
local dirtyChunks: { [any]: { [number]: true } } = {}
local pendingCells: { [any]: { idx: { number }, mats: { number }, collapse: { number }, collapseMats: { number } } } = {}
local needsSupportCheck: { [any]: true } = {}
local cellsChanged: { [any]: true } = {} -- precisa refazer o flood de conectividade
local pendingExplosions: { { Position: Vector3, Radius: number } } = {}
local recentExplosions: { { Position: Vector3, Time: number } } = {}

local stats = {
	Explosions = 0,
	CellsDestroyed = 0,
	CellsCollapsed = 0,
	BatchesSent = 0,
	ChunksRebuilt = 0,
	StepMsMax = 0, -- maior tempo de um passo (ms), para medir o custo do colapso
	StepMsLast = 0,
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
-- params.Elements + params.ElementOf (BuildingKit) ativam o grafo estrutural.
function DestructionManager.createStructure(params)
	local s = VoxelStructure.new(params)
	structures[s.Id] = s
	if params.Elements and params.ElementOf then
		s.Graph = StructuralGraph.new(s.Grid, params.Elements, params.ElementOf)
		if #s.Graph.DesignWarnings > 0 then
			warn(
				("[BLOCKFRONT] %s: %d elementos sem apoio no projeto: %s"):format(
					s.Name,
					#s.Graph.DesignWarnings,
					table.concat(s.Graph.DesignWarnings, ", ", 1, math.min(#s.Graph.DesignWarnings, 8))
				)
			)
		end
	end
	return s
end

-- Remove células do grid (usado pelo CollapseBodies quando um corpo nasce).
local function removeCells(s, cells: { number })
	local p = getPending(s)
	local grid = s.Grid
	for _, i in cells do
		local mat = grid:getMaterial(i)
		if mat ~= 0 then
			grid:clearCell(i)
			markDirty(s, i)
			s:RemoveFixtureAt(i)
			table.insert(p.collapse, i)
			table.insert(p.collapseMats, mat)
			stats.CellsCollapsed += 1
			if s.Graph then
				s.Graph:cellRemoved(i)
			end
		end
	end
	needsSupportCheck[s] = true
	cellsChanged[s] = true
end

local function nearestRecentExplosion(pos: Vector3, now: number): Vector3?
	local best, bestD = nil, 40
	for _, e in recentExplosions do
		if now - e.Time < 1.5 then
			local d = (e.Position - pos).Magnitude
			if d < bestD then
				best, bestD = e.Position, d
			end
		end
	end
	return best
end

function DestructionManager.getStructures()
	return structures
end

function DestructionManager.getStats()
	return table.clone(stats)
end

function DestructionManager.resetStepTiming()
	stats.StepMsMax = 0
end

--[[
	Explosão autoritativa.
	position: world space. radius: studs. damage: dano no centro (vida de célula).
	kind: efeito visual nos clientes. "Explosion" (padrão) = explosão completa,
	"Impact" = só fragmentos (tiros e golpes de marreta).
	Retorna o número de células destruídas imediatamente (sem contar desmoronamento).
]]
function DestructionManager.explode(position: Vector3, radius: number, damage: number, kind: string?): number
	assert(typeof(position) == "Vector3", "explode: position inválida")
	if radius <= 0 or damage <= 0 or radius ~= radius or damage ~= damage then
		return 0
	end
	stats.Explosions += 1
	table.insert(pendingExplosions, { Position = position, Radius = radius, Kind = kind or "Explosion" })

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
					s:RemoveFixtureAt(i)
					table.insert(p.idx, i)
					table.insert(p.mats, mats[n])
					if s.Graph then
						s.Graph:cellRemoved(i)
					end
				end
				needsSupportCheck[s] = true
				cellsChanged[s] = true
				total += #destroyed
			end
		end
	end
	stats.CellsDestroyed += total
	if (kind or "Explosion") == "Explosion" then
		table.insert(recentExplosions, { Position = position, Time = os.clock() })
		if #recentExplosions > 16 then
			table.remove(recentExplosions, 1)
		end
	end
	return total
end

function DestructionManager.findStructure(name: string)
	for _, s in structures do
		if s.Name == name then
			return s
		end
	end
	return nil
end

--[[
	Destrói uma fração das células de um elemento estrutural (testes e
	DevTools). Segue o mesmo caminho de uma explosão: as células saem do
	grid, os clientes recebem os fragmentos e o grafo reavalia o apoio.
	Retorna o número de células destruídas, ou nil se não achou.
]]
function DestructionManager.destroyElement(structureName: string, elementName: string, fraction: number?): number?
	local s = DestructionManager.findStructure(structureName)
	if not s or not s.Graph then
		return nil
	end
	local e = s.Graph:findByName(elementName)
	if not e then
		return nil
	end
	local cells = s.Graph:aliveCells(e.Id)
	local n = math.ceil(#cells * math.clamp(fraction or 1, 0, 1))
	local p = getPending(s)
	local grid = s.Grid
	for k = 1, n do
		local i = cells[k]
		local mat = grid:getMaterial(i)
		grid:clearCell(i)
		markDirty(s, i)
		s:RemoveFixtureAt(i)
		table.insert(p.idx, i)
		table.insert(p.mats, mat)
		s.Graph:cellRemoved(i)
	end
	table.insert(pendingExplosions, { Position = s:CellWorldPosition(cells[1] or 0), Radius = 2, Kind = "Impact" })
	needsSupportCheck[s] = true
	cellsChanged[s] = true
	stats.CellsDestroyed += n
	return n
end

function DestructionManager.getCollapseStats()
	return CollapseBodies.getStats()
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
	local now = os.clock()

	-- a. Integridade estrutural + conectividade
	local checks = needsSupportCheck
	needsSupportCheck = {}
	for s in checks do
		if s.Graph then
			local breaks, pending = s.Graph:evaluate(now)
			if #breaks > 0 then
				local cells = {}
				local center: Vector3? = nil
				for _, id in breaks do
					for _, i in s.Graph:aliveCells(id) do
						table.insert(cells, i)
					end
				end
				if #cells > 0 then
					center = nearestRecentExplosion(s:CellWorldPosition(cells[1]), now)
					CollapseBodies.enqueue(s, cells, center)
				end
			end
			if pending then
				needsSupportCheck[s] = true
			end
		end
		-- células sem caminho até o chão (pedaços pendurados por nada)
		if cellsChanged[s] and now < (s.NextFloodAt or 0) then
			needsSupportCheck[s] = true -- espera o intervalo do flood
		elseif cellsChanged[s] then
			cellsChanged[s] = nil
			s.NextFloodAt = now + StructuralConfig.FloodInterval
			local loose = s.Grid:findUnsupported()
			if #loose > 0 then
				local center = nearestRecentExplosion(s:CellWorldPosition(loose[1]), now)
				CollapseBodies.enqueue(s, loose, center)
			end
		end
	end

	-- b. Corpos físicos do colapso
	CollapseBodies.step(now, DestructionConfig.BatchInterval)

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
	table.clear(cellsChanged)
	table.clear(recentExplosions)
	CollapseBodies.reset()
	pendingExplosions = {}
end

-- Executa um passo imediatamente (útil para testes automatizados).
function DestructionManager.flush()
	step()
end

function DestructionManager.init()
	batchEvent = Remotes.get("DestructionBatch")
	CollapseBodies.bind(removeCells, DestructionManager.explode)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= DestructionConfig.BatchInterval then
			acc = 0
			local t0 = os.clock()
			step()
			local ms = (os.clock() - t0) * 1000
			stats.StepMsLast = ms
			stats.StepMsMax = math.max(stats.StepMsMax, ms)
		end
	end)
end

return DestructionManager
