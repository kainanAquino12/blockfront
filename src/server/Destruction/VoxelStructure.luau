--[[
	VoxelStructure (servidor)
	Uma construção destrutível: VoxelGrid (dados) + representação visual
	por chunks com greedy meshing.

	Representação:
	  Model (estrutura)
	    Chunk_<i> (Model)  -> poucas Parts ancoradas, uma por caixa do mesher

	As Parts vivem no servidor e são replicadas pelo próprio Roblox. Isso
	dá colisão e raycast corretos no servidor (validação de tiros) e faz
	jogadores que entram no meio da partida receberem o estado atual da
	destruição sem nenhum código extra. Só os chunks alterados são
	remontados, e as Parts são reaproveitadas (pool) em vez de recriadas.

	origin: CFrame do canto mínimo da célula (0,0,0). Os eixos locais da
	estrutura seguem o CFrame, então paredes podem ser giradas.
]]

local MaterialConfig = require(game:GetService("ReplicatedStorage").Shared.Config.MaterialConfig)
local DestructionConfig = require(game:GetService("ReplicatedStorage").Shared.Config.DestructionConfig)
local VoxelGrid = require(game:GetService("ReplicatedStorage").Shared.Modules.VoxelGrid)
local GreedyMesher = require(game:GetService("ReplicatedStorage").Shared.Modules.GreedyMesher)
local PartPool = require(script.Parent.PartPool)
local CollectionService = game:GetService("CollectionService")

-- Luminárias internas (V8). Ficam fora dos chunks (não são remontadas) e
-- presas a uma célula do teto: se ela for destruída, a luminária some.
local FIXTURES = {
	Fluorescent = { Size = Vector3.new(3.2, 0.25, 0.8), Color = Color3.fromRGB(206, 208, 200), Light = Color3.fromRGB(255, 240, 220), Range = 18, Brightness = 0.85 },
	Stair = { Size = Vector3.new(1.6, 0.25, 0.8), Color = Color3.fromRGB(206, 208, 200), Light = Color3.fromRGB(255, 240, 220), Range = 16, Brightness = 0.9 },
	Industrial = { Size = Vector3.new(1.6, 0.6, 1.6), Color = Color3.fromRGB(255, 226, 170), Light = Color3.fromRGB(255, 220, 170), Range = 32, Brightness = 1.4 },
	Emergency = { Size = Vector3.new(0.7, 0.4, 0.7), Color = Color3.fromRGB(255, 70, 50), Light = Color3.fromRGB(255, 80, 60), Range = 15, Brightness = 1.3 },
}

export type FillFunction = (x: number, y: number, z: number) -> number

export type StructureParams = {
	Name: string,
	Origin: CFrame,
	Size: Vector3, -- em células
	VoxelSize: number?,
	Fill: FillFunction,
	Parent: Instance,
}

local VoxelStructure = {}
VoxelStructure.__index = VoxelStructure

local nextId = 0

function VoxelStructure.new(params: StructureParams)
	local vs = params.VoxelSize or DestructionConfig.VoxelSize
	local cs = DestructionConfig.ChunkSize
	local sx, sy, sz = math.floor(params.Size.X), math.floor(params.Size.Y), math.floor(params.Size.Z)

	nextId += 1
	local self = setmetatable({}, VoxelStructure)
	self.Id = nextId
	self.Name = params.Name
	self.Origin = params.Origin
	self.VoxelSize = vs
	self.Grid = VoxelGrid.new(sx, sy, sz)
	self.ChunksX = math.ceil(sx / cs)
	self.ChunksY = math.ceil(sy / cs)
	self.ChunksZ = math.ceil(sz / cs)
	self.ChunkParts = {} :: { [number]: { BasePart } }
	self.ChunkModels = {} :: { [number]: Model }

	-- Esfera envolvente em world space (teste rápido de alcance de explosões).
	local half = Vector3.new(sx, sy, sz) * vs * 0.5
	self.BoundsCenter = params.Origin:PointToWorldSpace(half)
	self.BoundsRadius = half.Magnitude

	-- Preenche a grade.
	local grid = self.Grid
	for z = 0, sz - 1 do
		for y = 0, sy - 1 do
			for x = 0, sx - 1 do
				local mat = params.Fill(x, y, z)
				if mat ~= 0 then
					local def = MaterialConfig.ById[mat]
					assert(def, "Material inválido no Fill: " .. tostring(mat))
					grid:setCell(grid:index(x, y, z), mat, def.MaxHealth)
				end
			end
		end
	end

	local model = Instance.new("Model")
	model.Name = params.Name
	model:SetAttribute("StructureId", self.Id)
	model:SetAttribute("VoxelSize", vs)
	model:SetAttribute("GridSize", Vector3.new(sx, sy, sz))
	model.WorldPivot = params.Origin
	self.Model = model

	-- Monta todos os chunks fora do DataModel e parenteia uma vez no final.
	local total = self.ChunksX * self.ChunksY * self.ChunksZ
	for ci = 0, total - 1 do
		self:RebuildChunk(ci)
	end
	-- luminárias
	self.FixtureByCell = {} :: { [number]: BasePart }
	if params.Fixtures and #params.Fixtures > 0 then
		local lights = Instance.new("Folder")
		lights.Name = "Luzes"
		lights.Parent = model
		for _, f in params.Fixtures do
			local def = FIXTURES[f.kind] or FIXTURES.Fluorescent
			local p = Instance.new("Part")
			p.Name = "Luminaria_" .. f.kind
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = def.Color
			p.Size = def.Size
			p.CFrame = params.Origin * CFrame.new((f.x + 0.5) * vs, (f.y + 1) * vs - def.Size.Y / 2 - 0.02, (f.z + 0.5) * vs)
			local l = Instance.new("PointLight")
			l.Color = def.Light
			l.Range = def.Range
			l.Brightness = def.Brightness
			l.Shadows = false
			l.Parent = p
			CollectionService:AddTag(l, "BFInteriorLight")
			p.Parent = lights
			self.FixtureByCell[grid:index(f.x, f.y + 1, f.z)] = p
		end
	end

	model.Parent = params.Parent

	return self
end

function VoxelStructure:ChunkIndexOfCell(i: number): number
	local x, y, z = self.Grid:coords(i)
	local cs = DestructionConfig.ChunkSize
	return (x // cs) + self.ChunksX * ((y // cs) + self.ChunksY * (z // cs))
end

-- Converte posição world -> espaço de grade (unidade = célula).
function VoxelStructure:WorldToGrid(position: Vector3): Vector3
	return self.Origin:PointToObjectSpace(position) / self.VoxelSize
end

-- Centro da célula em world space.
function VoxelStructure:CellWorldPosition(i: number): Vector3
	local x, y, z = self.Grid:coords(i)
	local vs = self.VoxelSize
	return self.Origin:PointToWorldSpace(Vector3.new((x + 0.5) * vs, (y + 0.5) * vs, (z + 0.5) * vs))
end

function VoxelStructure:RebuildChunk(ci: number)
	local cs = DestructionConfig.ChunkSize
	local cx = ci % self.ChunksX
	local cy = (ci // self.ChunksX) % self.ChunksY
	local cz = ci // (self.ChunksX * self.ChunksY)
	local grid = self.Grid

	local x0, y0, z0 = cx * cs, cy * cs, cz * cs
	local rx = math.min(cs, grid.sizeX - x0)
	local ry = math.min(cs, grid.sizeY - y0)
	local rz = math.min(cs, grid.sizeZ - z0)

	local boxes = GreedyMesher.meshRegion(grid, x0, y0, z0, rx, ry, rz)
	local parts = self.ChunkParts[ci]
	if not parts then
		parts = {}
		self.ChunkParts[ci] = parts
	end

	local chunkModel = self.ChunkModels[ci]
	if not chunkModel and #boxes > 0 then
		chunkModel = Instance.new("Model")
		chunkModel.Name = "Chunk_" .. ci
		chunkModel.Parent = self.Model
		self.ChunkModels[ci] = chunkModel
	end

	local vs = self.VoxelSize
	for n, box in boxes do
		local part = parts[n]
		if not part then
			part = PartPool.acquire()
			parts[n] = part
		end
		local def = MaterialConfig.ById[box.mat]
		part.Size = Vector3.new(box.w, box.h, box.d) * vs
		part.CFrame = self.Origin
			* CFrame.new((box.x + box.w * 0.5) * vs, (box.y + box.h * 0.5) * vs, (box.z + box.d * 0.5) * vs)
		part.Material = def.Material
		part.Color = def.Color
		part.Transparency = def.Transparency or 0
		part.CastShadow = def.Transparency == nil
		part.Parent = chunkModel
	end

	for n = #parts, #boxes + 1, -1 do
		PartPool.release(parts[n])
		parts[n] = nil
	end
end

-- Uma célula do teto foi removida: a luminária presa nela some.
function VoxelStructure:RemoveFixtureAt(i: number)
	local p = self.FixtureByCell[i]
	if p then
		self.FixtureByCell[i] = nil
		p:Destroy()
	end
end

function VoxelStructure:CountParts(): number
	local n = 0
	for _, parts in self.ChunkParts do
		n += #parts
	end
	return n
end

return VoxelStructure
