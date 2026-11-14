--[[
	PartPool (servidor)
	Reaproveita as Parts usadas pelos chunks das estruturas. Remontar um
	chunk devolve as Parts que sobraram e pega novas do pool, evitando
	Instance.new/Destroy a cada explosão.
]]

local PartPool = {}

local free: { BasePart } = {}
local MAX_FREE = 2000

local function create(): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = "Voxels"
	return p
end

function PartPool.acquire(): BasePart
	local n = #free
	if n > 0 then
		local p = free[n]
		free[n] = nil
		return p
	end
	return create()
end

function PartPool.release(part: BasePart)
	part.Parent = nil
	if #free < MAX_FREE then
		table.insert(free, part)
	else
		part:Destroy()
	end
end

function PartPool.freeCount(): number
	return #free
end

return PartPool
