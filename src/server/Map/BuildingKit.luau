--[[
	BuildingKit (servidor) — construções por ELEMENTOS, não por caixas.

	Uma construção é descrita como elementos com papel estrutural (pilar,
	viga, laje, parede portante, vedação, vidro, divisória, escada, móvel).
	Cada elemento escreve suas células na grade e registra a quem pertence
	cada célula. O resultado alimenta o VoxelStructure (visual + dano) e o
	StructuralGraph (integridade e colapso).

	Uso:
	  local b = BuildingKit.new(sizeX, sizeY, sizeZ, offset)
	  b:add("Column", "ReinforcedConcrete", x0, y0, z0, x1, y1, z1, "Pilar_A1_T")
	  b:carve(x0, y0, z0, x1, y1, z1)    -- abre vãos (portas, poço de escada)
	  local def = b:finish()              -- { Size, Fill, Elements, ElementOf }

	Coordenadas: caixas INCLUSIVAS, em células, relativas a `offset`
	(permite margem em volta do prédio para marquises e sacadas).
	A última escrita vence: o elemento adicionado depois fica com a célula.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialConfig = require(ReplicatedStorage.Shared.Config.MaterialConfig)

local BuildingKit = {}
BuildingKit.__index = BuildingKit

function BuildingKit.new(sx: number, sy: number, sz: number, offset: Vector3?)
	local self = setmetatable({}, BuildingKit)
	self.sx, self.sy, self.sz = sx, sy, sz
	self.off = offset or Vector3.zero
	self.count = sx * sy * sz
	self.mats = buffer.create(self.count)
	self.elem = buffer.create(self.count * 2)
	self.elements = {}
	return self
end

local function matId(name: string): number
	local def = MaterialConfig.ByName[name]
	assert(def, "BuildingKit: material desconhecido " .. name)
	return def.Id
end

function BuildingKit:_box(x0, y0, z0, x1, y1, z1, fn)
	local o = self.off
	x0, x1 = math.min(x0, x1) + o.X, math.max(x0, x1) + o.X
	y0, y1 = math.min(y0, y1) + o.Y, math.max(y0, y1) + o.Y
	z0, z1 = math.min(z0, z1) + o.Z, math.max(z0, z1) + o.Z
	x0, y0, z0 = math.max(x0, 0), math.max(y0, 0), math.max(z0, 0)
	x1, y1, z1 = math.min(x1, self.sx - 1), math.min(y1, self.sy - 1), math.min(z1, self.sz - 1)
	local sx, sxy = self.sx, self.sx * self.sy
	for z = z0, z1 do
		for y = y0, y1 do
			for x = x0, x1 do
				fn(x + sx * y + sxy * z)
			end
		end
	end
end

-- Adiciona um elemento (caixa). Retorna o id.
function BuildingKit:add(kind: string, material: string, x0, y0, z0, x1, y1, z1, name: string?): number
	local id = #self.elements + 1
	assert(id < 65535, "BuildingKit: elementos demais")
	local m = matId(material)
	self.elements[id] = { Type = kind, Name = name or (kind .. "_" .. id), Material = m }
	local mats, elem = self.mats, self.elem
	self:_box(x0, y0, z0, x1, y1, z1, function(i)
		buffer.writeu8(mats, i, m)
		buffer.writeu16(elem, i * 2, id)
	end)
	return id
end

-- Acrescenta mais uma caixa a um elemento já existente (ex.: escada em degraus).
function BuildingKit:extend(id: number, x0, y0, z0, x1, y1, z1)
	local m = self.elements[id].Material
	local mats, elem = self.mats, self.elem
	self:_box(x0, y0, z0, x1, y1, z1, function(i)
		buffer.writeu8(mats, i, m)
		buffer.writeu16(elem, i * 2, id)
	end)
end

-- Remove células (vãos).
function BuildingKit:carve(x0, y0, z0, x1, y1, z1)
	local mats, elem = self.mats, self.elem
	self:_box(x0, y0, z0, x1, y1, z1, function(i)
		buffer.writeu8(mats, i, 0)
		buffer.writeu16(elem, i * 2, 0)
	end)
end

function BuildingKit:finish()
	local mats = self.mats
	local sx, sxy = self.sx, self.sx * self.sy
	return {
		Size = Vector3.new(self.sx, self.sy, self.sz),
		Fill = function(x: number, y: number, z: number): number
			return buffer.readu8(mats, x + sx * y + sxy * z)
		end,
		Elements = self.elements,
		ElementOf = self.elem,
	}
end

return BuildingKit
