--[[
	GreedyMesher
	Converte uma região de um VoxelGrid em poucas caixas (boxes): células
	vizinhas do mesmo material são fundidas em um único paralelepípedo.
	Uma parede inteira intacta de 24x14x2 vira 1 caixa em vez de 672 Parts.

	Algoritmo (3D guloso): para cada célula ainda não usada, estende em X,
	depois a linha inteira em Y, depois o retângulo inteiro em Z.
	Não é o mínimo absoluto de caixas, mas é O(n) na prática e rápido.
]]

local VoxelGrid = require(script.Parent.VoxelGrid)

export type Box = {
	x: number,
	y: number,
	z: number,
	w: number,
	h: number,
	d: number,
	mat: number,
}

local GreedyMesher = {}

-- Região [x0, x0+rx) x [y0, y0+ry) x [z0, z0+rz), já recortada aos limites da grade.
function GreedyMesher.meshRegion(
	grid: VoxelGrid.VoxelGrid,
	x0: number,
	y0: number,
	z0: number,
	rx: number,
	ry: number,
	rz: number
): { Box }
	local boxes: { Box } = {}
	local visited = buffer.create(rx * ry * rz)
	local materials = grid.materials
	local sx, sxy = grid.sizeX, grid.sizeX * grid.sizeY
	local x1, y1, z1 = x0 + rx, y0 + ry, z0 + rz

	local function free(x: number, y: number, z: number, mat: number): boolean
		local li = (x - x0) + rx * ((y - y0) + ry * (z - z0))
		return buffer.readu8(visited, li) == 0 and buffer.readu8(materials, x + sx * y + sxy * z) == mat
	end

	for z = z0, z1 - 1 do
		for y = y0, y1 - 1 do
			for x = x0, x1 - 1 do
				local mat = buffer.readu8(materials, x + sx * y + sxy * z)
				if mat ~= 0 and free(x, y, z, mat) then
					local w = 1
					while x + w < x1 and free(x + w, y, z, mat) do
						w += 1
					end

					local h = 1
					while y + h < y1 do
						local ok = true
						for dx = 0, w - 1 do
							if not free(x + dx, y + h, z, mat) then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
						h += 1
					end

					local d = 1
					while z + d < z1 do
						local ok = true
						for dy = 0, h - 1 do
							for dx = 0, w - 1 do
								if not free(x + dx, y + dy, z + d, mat) then
									ok = false
									break
								end
							end
							if not ok then
								break
							end
						end
						if not ok then
							break
						end
						d += 1
					end

					for dz = 0, d - 1 do
						for dy = 0, h - 1 do
							for dx = 0, w - 1 do
								local li = (x + dx - x0) + rx * ((y + dy - y0) + ry * (z + dz - z0))
								buffer.writeu8(visited, li, 1)
							end
						end
					end

					table.insert(boxes, { x = x, y = y, z = z, w = w, h = h, d = d, mat = mat })
				end
			end
		end
	end

	return boxes
end

return GreedyMesher
