--[[
	VoxelGrid
	Estrutura de dados pura (sem Instances) que guarda as células de uma
	construção destrutível. Usada pelo servidor como fonte da verdade.

	Armazenamento compacto em buffers:
	  materials: 1 byte por célula (Id do material, 0 = vazio)
	  health:    2 bytes por célula (vida atual, u16)

	Coordenadas de célula são 0-based: x em [0, sizeX-1], etc.
	Índice linear: x + sizeX * (y + sizeY * z)

	"Espaço de grade": 1 unidade = 1 célula, origem no canto mínimo da
	célula (0,0,0). O centro da célula (x,y,z) fica em (x+0.5, y+0.5, z+0.5).
]]

local VoxelGrid = {}
VoxelGrid.__index = VoxelGrid

export type VoxelGrid = typeof(setmetatable(
	{} :: {
		sizeX: number,
		sizeY: number,
		sizeZ: number,
		count: number,
		alive: number,
		materials: buffer,
		health: buffer,
	},
	VoxelGrid
))

function VoxelGrid.new(sizeX: number, sizeY: number, sizeZ: number): VoxelGrid
	assert(sizeX > 0 and sizeY > 0 and sizeZ > 0, "VoxelGrid: dimensões inválidas")
	local count = sizeX * sizeY * sizeZ
	local self = setmetatable({
		sizeX = sizeX,
		sizeY = sizeY,
		sizeZ = sizeZ,
		count = count,
		alive = 0,
		materials = buffer.create(count),
		health = buffer.create(count * 2),
	}, VoxelGrid)
	return self
end

function VoxelGrid.index(self: VoxelGrid, x: number, y: number, z: number): number
	return x + self.sizeX * (y + self.sizeY * z)
end

function VoxelGrid.coords(self: VoxelGrid, i: number): (number, number, number)
	local sx, sy = self.sizeX, self.sizeY
	local x = i % sx
	local rest = (i - x) // sx
	local y = rest % sy
	local z = (rest - y) // sy
	return x, y, z
end

function VoxelGrid.inBounds(self: VoxelGrid, x: number, y: number, z: number): boolean
	return x >= 0 and y >= 0 and z >= 0 and x < self.sizeX and y < self.sizeY and z < self.sizeZ
end

function VoxelGrid.getMaterial(self: VoxelGrid, i: number): number
	return buffer.readu8(self.materials, i)
end

function VoxelGrid.getHealth(self: VoxelGrid, i: number): number
	return buffer.readu16(self.health, i * 2)
end

-- Define uma célula. materialId 0 limpa a célula.
function VoxelGrid.setCell(self: VoxelGrid, i: number, materialId: number, hp: number)
	local was = buffer.readu8(self.materials, i)
	if was == 0 and materialId ~= 0 then
		self.alive += 1
	elseif was ~= 0 and materialId == 0 then
		self.alive -= 1
	end
	buffer.writeu8(self.materials, i, materialId)
	buffer.writeu16(self.health, i * 2, if materialId == 0 then 0 else math.clamp(math.floor(hp), 1, 65535))
end

function VoxelGrid.clearCell(self: VoxelGrid, i: number)
	self:setCell(i, 0, 0)
end

--[[
	Aplica dano esférico.
	cx, cy, cz, radius: em espaço de grade.
	damage: dano no centro; cai linearmente até damage * falloffMin na borda.
	maxScan: limite de células examinadas.
	getMaxHealth(materialId) não é necessário: a vida atual já está na célula.

	Retorna dois arrays paralelos: índices destruídos e seus materiais
	(o material é lido antes de limpar, para os fragmentos terem a cor certa).
]]
function VoxelGrid.damageSphere(
	self: VoxelGrid,
	cx: number,
	cy: number,
	cz: number,
	radius: number,
	damage: number,
	falloffMin: number,
	maxScan: number
): ({ number }, { number })
	local destroyed: { number } = {}
	local destroyedMats: { number } = {}
	if radius <= 0 or damage <= 0 then
		return destroyed, destroyedMats
	end

	local x0 = math.max(0, math.floor(cx - radius))
	local y0 = math.max(0, math.floor(cy - radius))
	local z0 = math.max(0, math.floor(cz - radius))
	local x1 = math.min(self.sizeX - 1, math.floor(cx + radius))
	local y1 = math.min(self.sizeY - 1, math.floor(cy + radius))
	local z1 = math.min(self.sizeZ - 1, math.floor(cz + radius))
	if x0 > x1 or y0 > y1 or z0 > z1 then
		return destroyed, destroyedMats
	end

	local scan = (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1)
	if scan > maxScan then
		-- Reduz o raio proporcionalmente em vez de travar o servidor.
		local factor = (maxScan / scan) ^ (1 / 3)
		return self:damageSphere(cx, cy, cz, radius * factor, damage, falloffMin, maxScan)
	end

	local r2 = radius * radius
	local materials, health = self.materials, self.health
	local sx, sxy = self.sizeX, self.sizeX * self.sizeY

	for z = z0, z1 do
		local dz = z + 0.5 - cz
		for y = y0, y1 do
			local dy = y + 0.5 - cy
			local dyz2 = dy * dy + dz * dz
			if dyz2 <= r2 then
				for x = x0, x1 do
					local dx = x + 0.5 - cx
					local d2 = dx * dx + dyz2
					if d2 <= r2 then
						local i = x + sx * y + sxy * z
						local mat = buffer.readu8(materials, i)
						if mat ~= 0 then
							local t = math.sqrt(d2) / radius
							local dmg = damage * (1 - t * (1 - falloffMin))
							local hp = buffer.readu16(health, i * 2) - dmg
							if hp <= 0 then
								table.insert(destroyed, i)
								table.insert(destroyedMats, mat)
								buffer.writeu8(materials, i, 0)
								buffer.writeu16(health, i * 2, 0)
								self.alive -= 1
							else
								buffer.writeu16(health, i * 2, math.floor(hp))
							end
						end
					end
				end
			end
		end
	end

	return destroyed, destroyedMats
end

--[[
	Encontra células vivas que NÃO estão conectadas (6-vizinhança) a uma
	célula âncora. Âncoras = camada y == 0 (apoiada no chão).
	Retorna os índices ordenados de baixo para cima (y crescente), que é a
	ordem usada no desmoronamento progressivo.
	Custo: O(células) usando buffers; feito no máximo uma vez por passo
	de servidor para cada estrutura que sofreu dano.
]]
function VoxelGrid.findUnsupported(self: VoxelGrid): { number }
	local sx, sy, sz = self.sizeX, self.sizeY, self.sizeZ
	local sxy = sx * sy
	local count = self.count
	local materials = self.materials
	local visited = buffer.create(count)
	local queue = buffer.create(count * 4)
	local head, tail = 0, 0

	-- Semeia com a camada de base.
	for z = 0, sz - 1 do
		for x = 0, sx - 1 do
			local i = x + sxy * z
			if buffer.readu8(materials, i) ~= 0 then
				buffer.writeu8(visited, i, 1)
				buffer.writeu32(queue, tail * 4, i)
				tail += 1
			end
		end
	end

	while head < tail do
		local i = buffer.readu32(queue, head * 4)
		head += 1
		local x = i % sx
		local y = (i // sx) % sy
		local z = i // sxy

		-- 6 vizinhos
		if x > 0 then
			local n = i - 1
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
		if x < sx - 1 then
			local n = i + 1
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
		if y > 0 then
			local n = i - sx
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
		if y < sy - 1 then
			local n = i + sx
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
		if z > 0 then
			local n = i - sxy
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
		if z < sz - 1 then
			local n = i + sxy
			if buffer.readu8(visited, n) == 0 and buffer.readu8(materials, n) ~= 0 then
				buffer.writeu8(visited, n, 1)
				buffer.writeu32(queue, tail * 4, n)
				tail += 1
			end
		end
	end

	-- Coleta em ordem de y crescente (camada por camada).
	local result: { number } = {}
	if tail == self.alive then
		return result
	end
	for y = 0, sy - 1 do
		for z = 0, sz - 1 do
			for x = 0, sx - 1 do
				local i = x + sx * y + sxy * z
				if buffer.readu8(materials, i) ~= 0 and buffer.readu8(visited, i) == 0 then
					table.insert(result, i)
				end
			end
		end
	end
	return result
end

return VoxelGrid
