--[[
	StructureKit (servidor)
	Construções destrutíveis descritas em células voxel. Cada função
	devolve { Size = Vector3 (células), Fill = (x,y,z) -> materialId },
	pronto para DestructionManager.createStructure.

	Convenções (espaço local, 1 célula = 1 stud):
	  y = 0 é o chão; a camada y = 0 das paredes é a fundação, âncora do
	  apoio estrutural (o que perde ligação com ela desmorona).
	  Faces: S (z = 0), N (z = máx), W (x = 0), E (x = máx).

	Tudo é destrutível, inclusive vidro (vida 5), portas de madeira,
	escadas, lajes e telhados.
]]

local MaterialConfig = require(game:GetService("ReplicatedStorage").Shared.Config.MaterialConfig)

local M = {}
for name, def in MaterialConfig.ByName do
	M[name] = def.Id
end

local StructureKit = {}
StructureKit.Materials = M

local DEFAULT_FLOOR_HEIGHT = 7 -- laje 1 + pé-direito 6 (porta de 6 de altura)

local function setOf(list: { string }?): { [string]: boolean }
	local t = {}
	for _, v in list or {} do
		t[v] = true
	end
	return t
end

-- Face e coordenada ao longo dela para uma célula do perímetro.
local function faceInfo(x: number, z: number, sx: number, sz: number): (string?, number, number)
	if z == 0 then
		return "S", x, sx
	elseif z == sz - 1 then
		return "N", sx - 1 - x, sx
	elseif x == 0 then
		return "W", sz - 1 - z, sz
	elseif x == sx - 1 then
		return "E", z, sz
	end
	return nil, 0, 0
end

export type BuildingOptions = {
	SizeX: number,
	SizeZ: number,
	Floors: number,
	FloorHeight: number?,
	Wall: number,
	Trim: number, -- pilares, fundação, cintas entre andares, mureta
	Slab: number?,
	Roof: number,
	Doors: { string }?, -- faces com porta aberta (térreo)
	WoodDoors: { string }?, -- faces com porta de madeira (destrutível, bloqueia passagem)
	ShopFront: string?, -- face com vitrine de vidro no térreo
	Glass: boolean?, -- janelas com vidro (padrão: true)
	WindowSpacing: number?, -- período das janelas (padrão 4)
	RoofAccess: boolean?, -- escada até o telhado
	Gable: boolean?, -- telhado de duas águas (casas)
	RoofProps: boolean?, -- ar-condicionado e caixa d'água no telhado plano
	Partition: boolean?, -- parede interna no térreo com vão
}

--[[
	Prédio genérico: casas, lojas, apartamentos e o QG militar.
	Escadas internas em zigue-zague (duas faixas junto à face N, alternando
	por andar) ligam todos os pisos; lajes com vão sobre cada lance.
]]
function StructureKit.building(o: BuildingOptions)
	local sx, sz, F = o.SizeX, o.SizeZ, o.Floors
	local H = o.FloorHeight or DEFAULT_FLOOR_HEIGHT
	local roofY = F * H
	local gable = o.Gable == true
	local gableH = if gable then math.ceil(sz / 2) else 0
	local sy = if gable then roofY + gableH + 1 else roofY + (if o.RoofProps then 4 else 2)
	local doors = setOf(o.Doors)
	local woodDoors = setOf(o.WoodDoors)
	local glass = o.Glass ~= false
	local spacing = o.WindowSpacing or 4
	local slab = o.Slab or o.Trim
	local stairLevels = if o.RoofAccess and not gable then F else F - 1

	local function surface(L: number): number
		return if L == 0 then 0 else L * H + 1
	end
	local function laneOf(L: number): (number, number)
		if L % 2 == 0 then
			return sz - 3, sz - 2
		end
		return sz - 5, sz - 4
	end
	local function stepIndex(L: number, x: number): number?
		local rise = surface(L + 1) - surface(L)
		local k = if L % 2 == 0 then x else rise + 1 - x
		if x >= 1 and x <= rise and k >= 1 and k <= rise then
			return k
		end
		return nil
	end

	-- Escada: a célula (x,y,z) é degrau?
	local function stairCell(x: number, y: number, z: number): number?
		for L = 0, stairLevels - 1 do
			local z0, z1 = laneOf(L)
			if z >= z0 and z <= z1 then
				local k = stepIndex(L, x)
				local base = surface(L)
				if k and y >= base and y < base + k then
					return if y == base + k - 1 then o.Trim else slab
				end
			end
		end
		return nil
	end

	-- Vão na laje acima de um lance (tudo menos o último degrau).
	local function slabHole(x: number, slabY: number, z: number): boolean
		local L = slabY // H - 1
		if L < 0 or L >= stairLevels then
			return false
		end
		local z0, z1 = laneOf(L)
		if z < z0 or z > z1 then
			return false
		end
		local k = stepIndex(L, x)
		local rise = surface(L + 1) - surface(L)
		return k ~= nil and k < rise
	end

	local function fill(x: number, y: number, z: number): number
		local perimeter = x == 0 or z == 0 or x == sx - 1 or z == sz - 1
		local corner = (x == 0 or x == sx - 1) and (z == 0 or z == sz - 1)

		-- Telhado de duas águas
		if gable and y > roofY then
			local j = y - roofY -- 1..
			local zLow, zHigh = j - 1, sz - j
			if zLow > zHigh then
				return 0
			end
			if z == zLow or z == zHigh or (zHigh - zLow <= 1 and z >= zLow and z <= zHigh) then
				return o.Roof
			end
			if (x == 0 or x == sx - 1) and z > zLow and z < zHigh then
				return o.Wall -- empena
			end
			return 0
		end

		-- Telhado plano, mureta e objetos de telhado
		if y == roofY then
			if slabHole(x, y, z) then
				return 0
			end
			return if perimeter then o.Trim else o.Roof
		end
		if y > roofY then
			if y == roofY + 1 and perimeter then
				return o.Trim
			end
			if o.RoofProps then
				-- ar-condicionado 2x2x1
				if y == roofY + 1 and x >= 3 and x <= 4 and z >= 2 and z <= 3 then
					return M.SheetMetal
				end
				-- caixa d'água 3x3x3 de madeira
				if y <= roofY + 3 and x >= sx - 5 and x <= sx - 3 and z >= 2 and z <= 4 then
					return M.Wood
				end
			end
			return 0
		end

		-- Lajes entre andares
		if y > 0 and y % H == 0 then
			if perimeter then
				return o.Trim
			end
			if slabHole(x, y, z) then
				return 0
			end
			return slab
		end

		-- Interior
		if not perimeter then
			local step = stairCell(x, y, z)
			if step then
				return step
			end
			if o.Partition and y < H and x == sx // 2 and z >= 1 and z < sz - 6 then
				if z >= 2 and z <= 4 and y <= 5 then
					return 0 -- vão de passagem
				end
				return o.Wall
			end
			return 0
		end

		if corner then
			return o.Trim
		end

		local face, a, len = faceInfo(x, z, sx, sz)
		local level = y // H
		local ly = y - level * H
		local mid = len // 2

		-- Portas no térreo (3 de largura, 6 de altura, sem degrau)
		if face and level == 0 and a >= mid - 1 and a <= mid + 1 and ly <= 5 then
			if doors[face] then
				return 0
			elseif woodDoors[face] then
				return M.Planks
			end
		end
		if y == 0 then
			return o.Trim -- fundação
		end

		-- Vitrine de loja
		if face and face == o.ShopFront and level == 0 and a >= 2 and a <= len - 3 and ly >= 1 and ly <= 4 then
			return M.Glass
		end

		-- Janelas 2x2
		if face and ly >= 2 and ly <= 3 and a >= 2 and a <= len - 3 then
			local nearDoor = level == 0 and (doors[face] or woodDoors[face]) and math.abs(a - mid) <= 2
			local phase = a % spacing
			if not nearDoor and (phase == 1 or phase == 2) then
				return if glass then M.Glass else 0
			end
		end
		-- Peitoril
		if face and ly == 1 and a >= 2 and a <= len - 3 and (a % spacing == 1 or a % spacing == 2) then
			return o.Trim
		end
		return o.Wall
	end

	return { Size = Vector3.new(sx, sy, sz), Fill = fill }
end

--[[
	Galpão industrial: base de concreto, paredes de chapa, faixa de janelas
	altas, portões grandes nas faces S e N, claraboias no telhado e uma
	passarela interna com escada.
]]
function StructureKit.warehouse(sx: number, sz: number, h: number, wall: number?)
	wall = wall or M.SheetMetal
	local gateW = math.min(10, sx - 8)
	local function fill(x: number, y: number, z: number): number
		local perimeter = x == 0 or z == 0 or x == sx - 1 or z == sz - 1
		local corner = (x == 0 or x == sx - 1) and (z == 0 or z == sz - 1)
		if y == h - 1 then
			-- telhado com claraboias
			if not perimeter and x % 6 == 3 and z >= 3 and z <= sz - 4 then
				return M.Glass
			end
			return if perimeter then M.Concrete else wall
		end
		if not perimeter then
			-- passarela ao longo da face N, a 6 de altura, com escada na ponta W
			if z >= sz - 3 and z <= sz - 2 then
				if y == 6 and x >= 8 then
					return M.SheetMetal
				end
				if x >= 1 and x <= 7 and y < x then
					return if y == x - 1 then M.SheetMetal else 0
				end
			end
			return 0
		end
		if corner or y <= 1 then
			-- portões nas faces S e N (concreto na base, menos no vão)
			local gate = (z == 0 or z == sz - 1) and math.abs(x - sx // 2) <= gateW // 2 and y <= 8
			if gate and not corner then
				return 0
			end
			return M.Concrete
		end
		local gate = (z == 0 or z == sz - 1) and math.abs(x - sx // 2) <= gateW // 2 and y <= 8
		if gate then
			return 0
		end
		-- porta lateral (face W)
		if x == 0 and math.abs(z - sz // 2) <= 1 and y <= 5 then
			return 0
		end
		-- faixa de janelas altas
		if y >= h - 4 and y <= h - 3 then
			local a = if z == 0 or z == sz - 1 then x else z
			if a % 3 ~= 0 then
				return M.Glass
			end
		end
		-- pilares de concreto a cada 6
		local a = if z == 0 or z == sz - 1 then x else z
		if a % 6 == 0 then
			return M.Concrete
		end
		return wall
	end
	return { Size = Vector3.new(sx, h, sz), Fill = fill }
end

-- Garagem: caixa de concreto com portão largo na face S.
function StructureKit.garage(sx: number, sz: number)
	local h = 7
	return {
		Size = Vector3.new(sx, h, sz),
		Fill = function(x: number, y: number, z: number): number
			local perimeter = x == 0 or z == 0 or x == sx - 1 or z == sz - 1
			if y == h - 1 then
				return M.Concrete
			end
			if not perimeter then
				return 0
			end
			if z == 0 and x >= 2 and x <= sx - 3 and y <= 5 then
				return 0
			end
			if y == 0 or y == h - 2 or x == 0 or x == sx - 1 and z == 0 then
				return M.Concrete
			end
			return M.Military
		end,
	}
end

--[[
	Torre de observação de madeira: quatro pernas, escada de degraus
	espaçados (escalável) por dentro, plataforma com parapeito e cobertura.
]]
function StructureKit.watchtower()
	local s, top = 7, 12
	local h = top + 5
	return {
		Size = Vector3.new(s, h, s),
		Fill = function(x: number, y: number, z: number): number
			local leg = (x == 0 or x == s - 1) and (z == 0 or z == s - 1)
			local edge = x == 0 or z == 0 or x == s - 1 or z == s - 1
			if y == h - 1 then
				return M.RoofTile
			end
			if y > top then
				if leg then
					return M.Wood
				end
				if y == top + 1 and edge then
					return M.Planks -- parapeito
				end
				return 0
			end
			if y == top then
				if x >= 2 and x <= 4 and z == 1 then
					return 0 -- alçapão da escada
				end
				return M.Planks
			end
			if leg then
				return M.Wood
			end
			-- travessas diagonais nas faces E e W
			if (x == 0 or x == s - 1) and (z == y % (s - 1) or z == (s - 1) - y % (s - 1)) and y >= 1 then
				return M.Wood
			end
			-- escada interna: degraus a cada 2 de altura sob o alçapão (escalável)
			if z == 1 and x >= 2 and x <= 4 and y % 2 == 1 then
				return M.Planks
			end
			return 0
		end,
	}
end

-- Bunker de concreto com seteira na face S e entrada na face N.
function StructureKit.bunker(sx: number, sz: number)
	local h = 5
	return {
		Size = Vector3.new(sx, h, sz),
		Fill = function(x: number, y: number, z: number): number
			local perimeter = x == 0 or z == 0 or x == sx - 1 or z == sz - 1
			if y == h - 1 then
				return M.Military
			end
			if not perimeter then
				return 0
			end
			if z == 0 and y == 2 and x >= 2 and x <= sx - 3 then
				return 0 -- seteira
			end
			if z == sz - 1 and math.abs(x - sx // 2) <= 1 and y <= 3 then
				return 0
			end
			return M.Military
		end,
	}
end

--[[
	Ponte de concreto sobre o rio (atravessa no eixo X).
	A origem fica no leito do rio; o tabuleiro fica em deckY (= profundidade
	do rio, então fica rente à rua). Pilares no leito e cabeceiras nas
	margens sustentam o tabuleiro: destruí-los derruba a ponte.
]]
function StructureKit.bridge(length: number, width: number, deckY: number)
	local h = deckY + 3
	return {
		Size = Vector3.new(length, h, width),
		Fill = function(x: number, y: number, z: number): number
			local abutment = x < 4 or x > length - 5
			if y < deckY then
				if abutment then
					return M.Concrete
				end
				local pillar = (x % 8 == 3 or x % 8 == 4) and (z <= 1 or z >= width - 2)
				return if pillar then M.Concrete else 0
			end
			if y == deckY then
				return M.Concrete
			end
			-- guarda-corpo
			if z == 0 or z == width - 1 then
				if y == deckY + 2 then
					return M.SheetMetal
				end
				if y == deckY + 1 and x % 2 == 0 then
					return M.SheetMetal
				end
			end
			return 0
		end,
	}
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

-- Muro de terreno com portão central (vão de 4).
function StructureKit.gateWall(length: number, height: number, material: number, trim: number)
	return {
		Size = Vector3.new(length, height, 1),
		Fill = function(x: number, y: number, _z: number): number
			if math.abs(x - length // 2) <= 2 and y < height then
				return 0
			end
			if y == height - 1 or x % 5 == 0 then
				return trim
			end
			return material
		end,
	}
end

-- Barreira de concreto baixa (perfil trapezoidal).
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

-- Pilha de caixotes de madeira (em degraus).
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

-- Fardos de feno empilhados.
function StructureKit.hay(width: number, depth: number)
	return {
		Size = Vector3.new(width, 4, depth),
		Fill = function(x: number, y: number, z: number): number
			if y >= 2 and (x < 2 or z >= depth - 2) then
				return 0
			end
			return M.Hay
		end,
	}
end

return StructureKit
