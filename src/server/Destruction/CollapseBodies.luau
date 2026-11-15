--[[
	CollapseBodies (servidor) — PHYSICS COLLAPSE.

	Transforma células que perderam sustentação em corpos rígidos que caem
	de verdade, em vez de apagá-las.

	  pedido  -> lista de células de uma estrutura (um ou mais elementos)
	  blocos  -> as células são agrupadas em blocos de até BlockSize³ células
	             (nunca um corpo por voxel); cada bloco vira UM corpo:
	             poucas Parts (greedy mesh) soldadas, sem âncora, dono de
	             rede = servidor (todos os jogadores veem a mesma coisa)
	  queda   -> gravidade, colisão com o mapa e entre destroços; impulso
	             inicial a partir da explosão mais próxima
	  impacto -> corpo rápido que bate numa estrutura causa dano no ponto de
	             contato (DestructionManager.explode tipo "Impact"); isso pode
	             quebrar a laje de baixo ou o prédio vizinho (cascata limitada)
	  entulho -> corpo parado por SettleTime é ancorado e fica no mapa
	             (cobertura, persistente). Acima de MaxRubbleParts, o entulho
	             mais antigo é removido aos poucos.

	Limites: MaxActive corpos simulando ao mesmo tempo; os pedidos esperam
	na fila (as células continuam no lugar até o corpo nascer, então nada
	some de repente). Parts de corpos removidos voltam para um pool.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructuralConfig = require(ReplicatedStorage.Shared.Config.StructuralConfig)
local MaterialConfig = require(ReplicatedStorage.Shared.Config.MaterialConfig)
local VoxelGrid = require(ReplicatedStorage.Shared.Modules.VoxelGrid)
local GreedyMesher = require(ReplicatedStorage.Shared.Modules.GreedyMesher)

local cfg = StructuralConfig.Bodies

local CollapseBodies = {}

type Body = {
	Root: BasePart,
	Parts: { BasePart },
	Mass: number, -- em células
	Born: number,
	StillSince: number?,
	Settled: boolean,
	SettledAt: number?,
}

type Block = { s: any, cells: { number }, minY: number, impulse: Vector3? }

local queue: { Block } = {}
local active: { Body } = {}
local rubble: { Body } = {}
local rubbleParts = 0
local pool: { BasePart } = {}
local folder: Folder? = nil
local impactTimes: { number } = {}
local removeCells: (s: any, cells: { number }) -> () = function() end
local explode: (pos: Vector3, radius: number, damage: number, kind: string?) -> number = function()
	return 0
end
local stats = { Spawned = 0, Settled = 0, Impacts = 0, Cleaned = 0, Dusted = 0 }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function getFolder(): Folder
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "Rubble"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function acquirePart(): BasePart
	local p = table.remove(pool)
	if p then
		return p
	end
	p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	return p
end

local function releaseBody(b: Body)
	for _, p in b.Parts do
		for _, c in p:GetChildren() do
			c:Destroy()
		end
		p.Anchored = true
		p.Parent = nil
		table.insert(pool, p)
	end
	table.clear(b.Parts)
end

-- Configuração das funções do DestructionManager (evita dependência circular).
function CollapseBodies.bind(removeFn, explodeFn)
	removeCells = removeFn
	explode = explodeFn
end

local rayFolder: Instance? = nil
local function refreshRayFilter()
	local df = workspace:FindFirstChild("DestructibleObjects")
	if df and df ~= rayFolder then
		rayFolder = df
		rayParams.FilterDescendantsInstances = { df }
	end
end

--[[
	Enfileira células soltas de uma estrutura. Agrupa em blocos.
	impulseFrom: centro da explosão que causou (opcional).
]]
function CollapseBodies.enqueue(s, cells: { number }, impulseFrom: Vector3?)
	if #cells == 0 then
		return
	end
	s.QueuedCells = s.QueuedCells or {}
	local grid = s.Grid
	-- desabamentos grandes (pedido grande ou fila longa) usam blocos maiores:
	-- menos corpos, a fila anda rápido e nada fica muito tempo parado no ar
	local B = cfg.BlockSize
	if #cells > 1500 or #queue > 120 then
		B = cfg.BlockSizeLarge
	elseif #cells > 400 or #queue > 40 then
		B = cfg.BlockSizeMedium
	end
	local buckets: { [number]: Block } = {}
	for _, i in cells do
		if not s.QueuedCells[i] and grid:getMaterial(i) ~= 0 then
			s.QueuedCells[i] = true
			local x, y, z = grid:coords(i)
			local key = (x // B) + 1024 * ((y // B) + 1024 * (z // B))
			local b = buckets[key]
			if not b then
				b = { s = s, cells = {}, minY = y, impulse = impulseFrom }
				buckets[key] = b
			end
			table.insert(b.cells, i)
			b.minY = math.min(b.minY, y)
		end
	end
	for _, b in buckets do
		table.insert(queue, b)
	end
	-- de baixo para cima: a base cede primeiro
	table.sort(queue, function(a, b)
		return a.minY < b.minY
	end)
end

local function spawnBlock(blk: Block, now: number)
	local s = blk.s
	local grid = s.Grid
	local alive = {}
	for _, i in blk.cells do
		s.QueuedCells[i] = nil
		if grid:getMaterial(i) ~= 0 then
			table.insert(alive, i)
		end
	end
	if #alive == 0 then
		return
	end

	-- poucos voxels soltos: vira só poeira (fragmentos visuais do cliente)
	if #alive < 3 then
		stats.Dusted += #alive
		removeCells(s, alive)
		return
	end

	-- grade local do bloco -> greedy mesh
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, i in alive do
		local x, y, z = grid:coords(i)
		minX, minY, minZ = math.min(minX, x), math.min(minY, y), math.min(minZ, z)
		maxX, maxY, maxZ = math.max(maxX, x), math.max(maxY, y), math.max(maxZ, z)
	end
	local lx, ly, lz = maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1
	local tmp = VoxelGrid.new(lx, ly, lz)
	for _, i in alive do
		local x, y, z = grid:coords(i)
		local mat = grid:getMaterial(i)
		tmp:setCell(tmp:index(x - minX, y - minY, z - minZ), mat, 1)
	end
	local boxes = GreedyMesher.meshRegion(tmp, 0, 0, 0, lx, ly, lz)

	-- muitas caixas (bloco muito recortado): as menores viram poeira
	if #boxes > cfg.MaxPartsPerBody then
		table.sort(boxes, function(a, b)
			return a.w * a.h * a.d > b.w * b.h * b.d
		end)
		for k = #boxes, cfg.MaxPartsPerBody + 1, -1 do
			boxes[k] = nil
		end
	end

	-- remove do grid primeiro (a parte ancorada some no mesmo passo em que o corpo nasce)
	removeCells(s, alive)

	local vs = s.VoxelSize
	local model = Instance.new("Model")
	model.Name = "Body"
	local parts = {}
	local root: BasePart? = nil
	for _, box in boxes do
		local def = MaterialConfig.ById[box.mat]
		local p = acquirePart()
		p.Anchored = true
		p.Size = Vector3.new(box.w, box.h, box.d) * vs
		p.CFrame = s.Origin
			* CFrame.new(
				(minX + box.x + box.w * 0.5) * vs,
				(minY + box.y + box.h * 0.5) * vs,
				(minZ + box.z + box.d * 0.5) * vs
			)
		p.Material = def.Material
		p.Color = def.Color
		p.Transparency = def.Transparency or 0
		p.CastShadow = def.Transparency == nil
		p.CanCollide = true
		p.CanQuery = true
		p.Parent = model
		if root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		else
			root = p
		end
		table.insert(parts, p)
	end
	if not root then
		return
	end
	model.PrimaryPart = root
	model.Parent = getFolder()
	for _, p in parts do
		p.Anchored = false
	end
	root:SetNetworkOwner(nil)

	-- impulso: para longe da explosão + um pouco para cima; senão, quase nada
	local center = root.Position
	local vel = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
	if blk.impulse then
		local d = center - blk.impulse
		local dist = d.Magnitude
		if dist < 30 and dist > 1e-3 then
			local k = cfg.ExplosionImpulse * (1 - dist / 30)
			vel += (d.Unit + Vector3.new(0, 0.35, 0)) * k
		end
	end
	root.AssemblyLinearVelocity = vel
	root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.5

	table.insert(active, {
		Root = root,
		Parts = parts,
		Mass = #alive,
		Born = now,
		StillSince = nil,
		Settled = false,
	})
	stats.Spawned += 1
end

local function canImpact(now: number): boolean
	while impactTimes[1] and now - impactTimes[1] > 1 do
		table.remove(impactTimes, 1)
	end
	return #impactTimes < cfg.MaxImpactsPerSecond
end

local function settle(b: Body, now: number)
	for _, p in b.Parts do
		p.Anchored = true
	end
	b.Settled = true
	b.SettledAt = now
	table.insert(rubble, b)
	rubbleParts += #b.Parts
	stats.Settled += 1
end

-- Um passo (chamado pelo DestructionManager a cada BatchInterval).
function CollapseBodies.step(now: number, dt: number)
	refreshRayFilter()

	-- 1. nascer corpos da fila
	local spawned = 0
	-- sem vaga: os blocos esperam na fila, ainda no lugar (nada some)
	while #queue > 0 and spawned < 12 and #active < cfg.MaxActive do
		spawnBlock(table.remove(queue, 1), now)
		spawned += 1
	end

	-- 2. simulação: impacto, assentamento
	local i = 1
	while i <= #active do
		local b = active[i]
		local root = b.Root
		local remove = false
		if not root.Parent or root.Position.Y < cfg.KillY then
			releaseBody(b)
			remove = true
		else
			local v = root.AssemblyLinearVelocity
			local speed = v.Magnitude
			-- impacto em estrutura (cascata)
			if speed > cfg.ImpactSpeed and v.Y < -cfg.ImpactSpeed * 0.5 and canImpact(now) then
				local reach = speed * dt * 1.6 + root.Size.Y * 0.5 + 0.5
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams)
				if hit then
					local radius = math.clamp(math.sqrt(b.Mass) * 0.35, cfg.ImpactRadiusMin, cfg.ImpactRadiusMax)
					local damage = b.Mass * cfg.ImpactDamagePerMass * (speed / cfg.ImpactSpeed)
					table.insert(impactTimes, now)
					stats.Impacts += 1
					explode(hit.Position, radius, damage, "Impact")
				end
			end
			-- assentou?
			if speed < cfg.SettleSpeed then
				b.StillSince = b.StillSince or now
				if now - (b.StillSince :: number) >= cfg.SettleTime then
					settle(b, now)
					remove = true
				end
			else
				b.StillSince = nil
			end
			if not remove and now - b.Born > cfg.MaxSimTime then
				settle(b, now)
				remove = true
			end
		end
		if remove then
			active[i] = active[#active]
			active[#active] = nil
		else
			i += 1
		end
	end

	-- 3. limpeza controlada do entulho mais antigo
	local cleaned = 0
	while rubbleParts > cfg.MaxRubbleParts and cleaned < cfg.RubbleCleanupPerStep and #rubble > 0 do
		local b = table.remove(rubble, 1)
		rubbleParts -= #b.Parts
		local model = b.Root.Parent
		releaseBody(b)
		if model and model:IsA("Model") then
			model:Destroy()
		end
		cleaned += 1
		stats.Cleaned += 1
	end
end

function CollapseBodies.reset()
	table.clear(queue)
	table.clear(active)
	table.clear(rubble)
	rubbleParts = 0
	if folder then
		folder:Destroy()
		folder = nil
	end
end

function CollapseBodies.isBusy(): boolean
	return #queue > 0 or #active > 0
end

function CollapseBodies.getStats()
	local s = table.clone(stats)
	s.Queued = #queue
	s.Active = #active
	s.RubbleBodies = #rubble
	s.RubbleParts = rubbleParts
	return s
end

return CollapseBodies
