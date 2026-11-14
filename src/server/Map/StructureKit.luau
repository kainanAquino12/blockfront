--[[
	StructureKit (servidor)
	Funções que descrevem construções destrutíveis em células voxel.
	Cada função devolve { Size = Vector3 (células), Fill = (x,y,z) -> materialId }
	pronto para DestructionManager.createStructure.

	Convenções (espaço local da estrutura, 1 célula = 1 stud):
	  y = 0 é o chão; a camada y = 0 das paredes é a fundação (âncora do
	  apoio estrutural). Faces: S (z = 0), N (z = máx), W (x = 0), E (x = máx).
]]

local MaterialConfig = require(game:GetService("ReplicatedStorage").Shared.Config.MaterialConfig)

local M = {}
for name, def in MaterialConfig.ByName do
	M[name] = def.Id
end

local StructureKit = {}
StructureKit.Materials = M

local FLOOR_HEIGHT = 7 -- altura de um andar (pé-direito 6 + laje 1)

export type BuildingOptions = {
	SizeX: number,
	SizeZ: number,
	Floors: number, -- 1 ou 2
	Wall: number,
	Trim: number, -- pilares, fundação e cinta entre andares
	Slab: number?, -- laje do 2º andar
	Roof: number,
	Doors: { string }, -- faces com porta: "S", "N", "W", "E"
}

--[[
	Prédio oco com portas, janelas, escada interna (se tiver 2 andares),
	laje e telhado com mureta. Tudo destrutível; o 2º andar e o telhado
	só ficam de pé enquanto houver paredes ligando-os ao chão.
]]
function StructureKit.building(o: BuildingOptions)
	local sx, sz = o.SizeX, o.SizeZ
	local H = FLOOR_HEIGHT
	local roofY = o.Floors * H
	local sy = roofY + 2 -- telhado + mureta
	local doors = {}
	for _, f in o.Doors do
		doors[f] = true
	end
	local slab = o.Slab or o.Trim
	local cx, cz = sx // 2, sz // 2
	local stairZ0, stairZ1 = sz - 3, sz - 2

	local function faceInfo(x: number, z: number): (string?, number, number)
		-- face e coordenada ao longo dela (a) e comprimento (len)
		if z == 0 then
			return "S", x, sx
		elseif z == sz - 1 then
			return "N", x, sx
		elseif x == 0 then
			return "W", z, sz
		elseif x == sx - 1 then
			return "E", z, sz
		end
		return nil, 0, 0
	end

	local function fill(x: number, y: number, z: number): number
		local perimeter = x == 0 or z == 0 or x == sx - 1 or z == sz - 1
		local corner = (x == 0 or x == sx - 1) and (z == 0 or z == sz - 1)

		-- mureta do telhado
		if y == sy - 1 then
			return if perimeter then o.Trim else 0
		end
		-- telhado
		if y == roofY then
			return o.Roof
		end
		-- laje entre andares (com vão da escada)
		if o.Floors >= 2 and y == H then
			if perimeter then
				return o.Trim
			end
			if x >= 1 and x <= H and z >= stairZ0 and z <= stairZ1 then
				return 0
			end
			return slab
		end
		-- escada interna (degraus de 1 célula, encostada na face N)
		if o.Floors >= 2 and not perimeter and z >= stairZ0 and z <= stairZ1 then
			local step = x -- degrau x tem topo na altura x
			if x >= 1 and x <= H + 1 and y < step then
				return if y == step - 1 then o.Trim else slab
			end
		end
		if not perimeter then
			return 0
		end

		if corner then
			return o.Trim
		end

		local face, a, len = faceInfo(x, z)
		local level = y // H
		local ly = y - level * H -- altura dentro do andar (0..H-1)
		local mid = if face == "S" or face == "N" then cx else cz

		-- porta só no térreo, 3 de largura e 6 de altura (sem degrau)
		if face and doors[face] and level == 0 and a >= mid - 1 and a <= mid + 1 and ly <= 5 then
			return 0
		end
		if y == 0 then
			return o.Trim -- fundação
		end
		-- janelas: 2x2 a cada 5 células, longe dos cantos e da porta
		if face and ly >= 3 and ly <= 4 and a >= 2 and a <= len - 3 then
			local nearDoor = doors[face] and level == 0 and math.abs(a - mid) <= 2
			if not nearDoor and (a % 5 == 2 or a % 5 == 3) then
				return 0
			end
		end
		return o.Wall
	end

	return { Size = Vector3.new(sx, sy, sz), Fill = fill }
end

-- Muro reto. Ameias opcionais no topo (crenel = true).
function StructureKit.wall(length: number, height: number, thickness: number, material: number, trim: number?, crenel: boolean?)
	return {
		Size = Vector3.new(length, height, thickness),
		Fill = function(x: number, y: number, _z: number): number
			if crenel and y == height - 1 and x % 3 == 2 then
				return 0
			end
			if trim and (y == 0 or x == 0 or x == length - 1) then
				return trim
			end
			return material
		end,
	}
end

-- Barreira de concreto baixa (perfil trapezoidal), boa cobertura agachada.
function StructureKit.barrier(length: number)
	return {
		Size = Vector3.new(length, 3, 3),
		Fill = function(_x: number, y: number, z: number): number
			if y == 2 and z ~= 1 then
				return 0
			end
			return M.Concrete
		end,
	}
end

-- Muro de sacos de areia em fileiras desencontradas.
function StructureKit.sandbags(length: number, height: number)
	return {
		Size = Vector3.new(length, height, 2),
		Fill = function(x: number, y: number, _z: number): number
			if y == height - 1 and (x == 0 or x == length - 1) then
				return 0
			end
			return M.Sandbag
		end,
	}
end

-- Pilha de caixotes de madeira (degraus).
function StructureKit.crates(width: number, depth: number)
	return {
		Size = Vector3.new(width, 6, depth),
		Fill = function(x: number, y: number, z: number): number
			if y >= 3 and (x >= width - 3 or z >= depth - 3) then
				return 0
			end
			local edge = (x % 3 == 0 or x % 3 == 2) and (z % 3 == 0 or z % 3 == 2) and (y % 3 == 0 or y % 3 == 2)
			return if edge then M.Planks else M.Wood
		end,
	}
end

return StructureKit
