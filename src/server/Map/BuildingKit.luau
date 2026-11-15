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

--[[
	Espelha uma definição de estrutura em z (o que era a face sul vira a
	face norte). Funciona com qualquer def { Size, Fill, Elements?, ElementOf? }:
	usado pelo MapManager no lado vermelho e para virar prédios de frente.
]]
function BuildingKit.flipZ(def)
	local size = def.Size
	local sx, sy, sz = size.X, size.Y, size.Z
	local f = def.Fill
	local out = {
		Size = size,
		Fill = function(x: number, y: number, z: number): number
			return f(x, y, sz - 1 - z)
		end,
		Elements = def.Elements,
		ElementOf = nil,
		Offset = def.Offset,
	}
	if def.ElementOf then
		local sxy = sx * sy
		local src = def.ElementOf
		local dst = buffer.create(buffer.len(src))
		for c = 0, sz - 1 do
			buffer.copy(dst, (sz - 1 - c) * sxy * 2, src, c * sxy * 2, sxy * 2)
		end
		out.ElementOf = dst
	end
	return out
end

--[[
	Núcleo de escada (paredes portantes + escada em U por andar), 8 x 14 em
	planta, canto em (x0, z0). Mesmo desenho usado no Edifício Central:
	  porta na parede oeste (x0), z0+1..z0+3, abrindo no patamar
	  lance A sobe para o norte (x0+1..x0+3), patamar ao fundo,
	  lance B volta para o sul (x0+4..x0+6) até a laje de cima
	  poço aberto nas lajes em z0+5..z0+12
	levels: alturas das lajes { y0 (fundação), y1, ..., yN }
	opts.Penthouse: altura da casa de escada acima da última laje
	opts.Name: prefixo dos nomes dos elementos
]]
function BuildingKit:stairCore(x0: number, z0: number, levels: { number }, opts: { Penthouse: number?, Name: string? }?)
	local RC = "ReinforcedConcrete"
	local name = (opts and opts.Name) or "Nucleo"
	local ph = opts and opts.Penthouse
	local x1, z1 = x0 + 7, z0 + 13
	local n = #levels - 1 -- andares
	for f = 0, n do
		local y0 = if f == 0 then levels[1] + 1 else levels[f + 1]
		local y1
		if f == n then
			if not ph then
				break
			end
			y1 = levels[f + 1] + ph
		else
			y1 = levels[f + 2] - 1
		end
		local tag = ("%s_A%d"):format(name, f)
		self:add("BearingWall", RC, x0, y0, z0, x0, y1, z1, tag .. "_O")
		self:add("BearingWall", RC, x1, y0, z0, x1, y1, z1, tag .. "_L")
		self:add("BearingWall", RC, x0, y0, z0, x1, y1, z0, tag .. "_S")
		self:add("BearingWall", RC, x0, y0, z1, x1, y1, z1, tag .. "_N")
		local fy = levels[f + 1] + 1
		self:carve(x0, fy, z0 + 1, x0, fy + 6, z0 + 3)
	end
	if ph then
		local yt = levels[n + 1] + ph + 1
		self:add("Roof", RC, x0, yt, z0, x1, yt, z1, name .. "_Teto")
	end
	-- poço nas lajes (mantém a faixa de patamar z0+1..z0+4)
	for k = 2, n + 1 do
		self:carve(x0 + 1, levels[k] - 1, z0 + 5, x1 - 1, levels[k], z1 - 1)
	end
	-- escadas
	for f = 0, n - 1 do
		local y0 = levels[f + 1] + 1
		local rise = levels[f + 2] - levels[f + 1]
		local half = math.floor(rise / 2)
		local sid = self:add("Stair", RC, x0 + 1, y0, z0 + 4, x0 + 3, y0, z0 + 4, ("%s_Escada_A%d"):format(name, f))
		for i = 0, half do
			self:extend(sid, x0 + 1, math.max(y0 + i - 1, y0), z0 + 4 + i, x0 + 3, y0 + i, z0 + 4 + i)
		end
		self:extend(sid, x0 + 1, y0 + half - 1, z0 + 5 + half, x1 - 1, y0 + half, z1 - 1)
		for i = 0, rise - half - 2 do
			local z = z0 + 4 + half - i
			self:extend(sid, x0 + 4, y0 + half + i, z, x0 + 6, y0 + half + 1 + i, z)
		end
	end
end

--[[
	Troca os eixos x e z de uma definição (gira o desenho em planta):
	usado para pontes que atravessam o canal no eixo x.
]]
function BuildingKit.swapXZ(def)
	local sx, sy, sz = def.Size.X, def.Size.Y, def.Size.Z
	local f = def.Fill
	local out = {
		Size = Vector3.new(sz, sy, sx),
		Fill = function(x: number, y: number, z: number): number
			return f(z, y, x)
		end,
		Elements = def.Elements,
	}
	if def.ElementOf then
		local src = def.ElementOf
		local dst = buffer.create(buffer.len(src))
		-- origem: i = x + sx*y + sx*sy*z ; destino (x'=z, z'=x): j = z + sz*y + sz*sy*x
		for z = 0, sz - 1 do
			for y = 0, sy - 1 do
				for x = 0, sx - 1 do
					local i = x + sx * y + sx * sy * z
					local j = z + sz * y + sz * sy * x
					buffer.writeu16(dst, j * 2, buffer.readu16(src, i * 2))
				end
			end
		end
		out.ElementOf = dst
	end
	return out
end

return BuildingKit
