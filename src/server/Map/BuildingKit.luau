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
	self.fixtures = {} -- luminárias { x, y, z, kind } (coordenadas da grade)
	self.lightKind = "Fluorescent"
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

--[[
	Luminária pendurada no teto. (x, y, z) em coordenadas locais (com offset):
	a luminária fica no topo da célula (x, y, z) e se prende na célula de
	cima (o teto). Se o teto for destruído, a luminária some junto.
	kind: "Fluorescent" | "Industrial" | "Emergency" | "Stair"
]]
function BuildingKit:light(x: number, y: number, z: number, kind: string?)
	local o = self.off
	table.insert(self.fixtures, { x = x + o.X, y = y + o.Y, z = z + o.Z, kind = kind or self.lightKind })
end

function BuildingKit:_solid(x: number, y: number, z: number): boolean
	if x < 0 or y < 0 or z < 0 or x >= self.sx or y >= self.sy or z >= self.sz then
		return false
	end
	return buffer.readu8(self.mats, x + self.sx * y + self.sx * self.sy * z) ~= 0
end

--[[
	Luz automática: uma luminária no centro de cada painel de laje com
	espaço vazio embaixo (salas, corredores, galpões). Painéis grandes ganham
	duas. Ignora sacadas, marquises e tabuleiros de ponte.
]]
function BuildingKit:_autoLights()
	local sx, sy, sz = self.sx, self.sy, self.sz
	local sxy = sx * sy
	local mins, maxs = {}, {}
	for i = 0, self.count - 1 do
		local id = buffer.readu16(self.elem, i * 2)
		if id ~= 0 and buffer.readu8(self.mats, i) ~= 0 and self.elements[id].Type == "Slab" then
			local x, y, z = i % sx, (i // sx) % sy, i // sxy
			local a, b = mins[id], maxs[id]
			if not a then
				mins[id] = Vector3.new(x, y, z)
				maxs[id] = Vector3.new(x, y, z)
			else
				mins[id] = a:Min(Vector3.new(x, y, z))
				maxs[id] = b:Max(Vector3.new(x, y, z))
			end
		end
	end
	for id, a in mins do
		local name = self.elements[id].Name
		local b = maxs[id]
		local w, d = b.X - a.X + 1, b.Z - a.Z + 1
		if w * d >= 30 and math.min(w, d) >= 4 and not (string.find(name, "Sacada") or string.find(name, "Marquise") or string.find(name, "Tabuleiro")) then
			local spots
			if w * d > 150 then
				if w >= d then
					spots = { { a.X + w * 0.3, (a.Z + b.Z) / 2 }, { a.X + w * 0.7, (a.Z + b.Z) / 2 } }
				else
					spots = { { (a.X + b.X) / 2, a.Z + d * 0.3 }, { (a.X + b.X) / 2, a.Z + d * 0.7 } }
				end
			else
				spots = { { (a.X + b.X) / 2, (a.Z + b.Z) / 2 } }
			end
			for _, sp in spots do
				local x, z, y = math.floor(sp[1]), math.floor(sp[2]), a.Y
				-- teto sólido e pelo menos 3 células livres embaixo (é um ambiente)
				if self:_solid(x, y, z) and not self:_solid(x, y - 1, z) and not self:_solid(x, y - 2, z) and not self:_solid(x, y - 3, z) then
					table.insert(self.fixtures, { x = x, y = y - 1, z = z, kind = self.lightKind })
				end
			end
		end
	end
end

function BuildingKit:finish(opts: { NoAutoLights: boolean? }?)
	local mats = self.mats
	local sx, sxy = self.sx, self.sx * self.sy
	if not (opts and opts.NoAutoLights) then
		self:_autoLights()
	end
	-- descarta luminárias cujo teto não existe (vãos, poços)
	local fixtures = {}
	for _, f in self.fixtures do
		if self:_solid(f.x, f.y + 1, f.z) and not self:_solid(f.x, f.y, f.z) then
			table.insert(fixtures, f)
		end
	end
	return {
		Size = Vector3.new(self.sx, self.sy, self.sz),
		Fill = function(x: number, y: number, z: number): number
			return buffer.readu8(mats, x + sx * y + sxy * z)
		end,
		Elements = self.elements,
		ElementOf = self.elem,
		Fixtures = fixtures,
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
		Fixtures = nil,
	}
	if def.Fixtures then
		out.Fixtures = {}
		for _, f in def.Fixtures do
			table.insert(out.Fixtures, { x = f.x, y = f.y, z = sz - 1 - f.z, kind = f.kind })
		end
	end
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
function BuildingKit:stairCore(x0: number, z0: number, levels: { number }, opts: { Penthouse: number?, Name: string?, Material: string? }?)
	local RC = (opts and opts.Material) or "ReinforcedConcrete" -- material das paredes (torres de pedra/tijolo)
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
		self:carve(x0, fy, z0 + 1, x0, fy + 6, z0 + 4) -- porta de 4 de largura
	end
	if ph then
		local yt = levels[n + 1] + ph + 1
		self:add("Roof", RC, x0, yt, z0, x1, yt, z1, name .. "_Teto")
	end
	-- luz em cada patamar (sob a faixa de laje) e na casa de escada
	for k = 2, n + 1 do
		self:light(x0 + 2, levels[k] - 1, z0 + 2, "Stair")
	end
	if ph then
		self:light(x0 + 2, levels[n + 1] + ph, z0 + 2, "Stair")
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
		Fixtures = nil,
	}
	if def.Fixtures then
		out.Fixtures = {}
		for _, fx in def.Fixtures do
			table.insert(out.Fixtures, { x = fx.z, y = fx.y, z = fx.x, kind = fx.kind })
		end
	end
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

--[[
	Bloco estrutural com fachada (V10). Monta, numa chamada, um volume de
	vários andares com estrutura real e fachada:
	  o.X, o.Z      linhas de pilares (2x2) em x e em z (a primeira e a última
	                são o perímetro)
	  o.Levels      alturas das lajes { y0, y1, ..., yN } (y0 = base, sem laje)
	  o.Name        prefixo dos nomes dos elementos
	  o.Wall        material da fachada (padrão "Brick")
	  o.Win         "Ribbon" (fita), "Punched" (janelas recortadas em pares),
	                "Tall" (janelas altas e estreitas) ou "None"
	  o.Doors       { { face = "S"|"N"|"O"|"L", at = coordenada, w = largura } }
	                portas no térreo (face S = z mínimo)
	  o.Holes       { {x0, z0, x1, z1} } vãos sem laje (átrios, poços)
	  o.Roof        true: platibanda na cobertura
	  o.SkipFaces   { S = true, ... } faces sem fachada (coladas em outro volume)
	Lajes, vigas e pilares entram no grafo estrutural como no Edifício Central.
]]
function BuildingKit:framedBlock(o)
	local RC = "ReinforcedConcrete"
	local X, Z, Lv = o.X, o.Z, o.Levels
	local name = o.Name or "Bloco"
	local wall = o.Wall or "Brick"
	local win = o.Win or "Punched"
	local skip = o.SkipFaces or {}
	local function inHole(x0, z0, x1, z1)
		for _, h in o.Holes or {} do
			if x0 >= h[1] and x1 <= h[3] and z0 >= h[2] and z1 <= h[4] then
				return true
			end
		end
		return false
	end
	local n = #Lv - 1
	for k = 2, #Lv do
		local y = Lv[k]
		for i = 1, #X - 1 do
			for j = 1, #Z - 1 do
				local x0, x1, z0, z1 = X[i] + 2, X[i + 1] - 1, Z[j] + 2, Z[j + 1] - 1
				if not inHole(x0, z0, x1, z1) then
					self:add("Slab", RC, x0, y, z0, x1, y, z1, ("%s_Laje_N%d_%d%d"):format(name, k - 1, i, j))
				end
			end
		end
		for j, c in Z do
			for i = 1, #X - 1 do
				self:add("Beam", RC, X[i] + 2, y - 1, c, X[i + 1] - 1, y, c + 1, ("%s_VigaX_N%d_%d_%d"):format(name, k - 1, j, i))
			end
		end
		for i, c in X do
			for j = 1, #Z - 1 do
				self:add("Beam", RC, c, y - 1, Z[j] + 2, c + 1, y, Z[j + 1] - 1, ("%s_VigaZ_N%d_%d_%d"):format(name, k - 1, i, j))
			end
		end
		for _, h in o.Holes or {} do
			if k < #Lv then
				self:carve(h[1], y - 1, h[2], h[3], y, h[4])
			end
		end
	end
	for f = 0, n - 1 do
		for i, cx in X do
			for j, cz in Z do
				local y0 = if f == 0 then Lv[1] + 1 else Lv[f + 1]
				self:add("Column", RC, cx, y0, cz, cx + 1, Lv[f + 2] - 1, cz + 1, ("%s_Pilar_%d%d_A%d"):format(name, i, j, f))
			end
		end
	end
	for i, cx in X do
		for j, cz in Z do
			self:add("Column", RC, cx, Lv[#Lv], cz, cx + 1, Lv[#Lv], cz + 1, ("%s_Pilar_%d%d_Topo"):format(name, i, j))
		end
	end
	-- fachada por vão (entre pilares), em cada andar
	local xs, xe, zs, ze = X[1], X[#X] + 1, Z[1], Z[#Z] + 1
	local function facade(face: string, f: number, a: number, c: number)
		local y0 = if f == 0 then Lv[1] + 1 else Lv[f + 1] + 1
		local yt = Lv[f + 2] - 2
		local tag = ("%s_Fachada_%s_A%d_%d"):format(name, face, f, a)
		local alongX = face == "S" or face == "N"
		local fixed = if face == "S" then zs elseif face == "N" then ze elseif face == "O" then xs else xe
		local function box(kind, mat, u0, v0, u1, v1, nm)
			if alongX then
				return self:add(kind, mat, u0, v0, fixed, u1, v1, fixed, nm)
			else
				return self:add(kind, mat, fixed, v0, u0, fixed, v1, u1, nm)
			end
		end
		local function cut(u0, v0, u1, v1)
			if alongX then
				self:carve(u0, v0, fixed, u1, v1, fixed)
			else
				self:carve(fixed, v0, u0, fixed, v1, u1)
			end
		end
		box("Wall", wall, a, y0, c, yt, tag)
		local function glass(u0, v0, u1, v1)
			cut(u0, v0, u1, v1)
			box("Glass", "TintedGlass", u0, v0, u1, v1, tag .. "_Vidro" .. u0)
		end
		if win == "Ribbon" then
			if c - a >= 3 then
				glass(a + 1, y0 + 2, c - 1, yt - 1)
			end
		elseif win == "Punched" then
			for u = a + 1, c - 2, 4 do
				glass(u, y0 + 2, math.min(u + 1, c - 1), y0 + 5)
			end
		elseif win == "Tall" then
			for u = a + 1, c - 1, 3 do
				glass(u, y0 + 1, u, yt - 1)
			end
		end
		if f == 0 then
			for _, d in o.Doors or {} do
				if d.face == face and d.at >= a and d.at + (d.w or 3) - 1 <= c then
					cut(d.at, y0, d.at + (d.w or 3) - 1, y0 + 6)
				end
			end
		end
	end
	for f = 0, n - 1 do
		for i = 1, #X - 1 do
			if not skip.S then
				facade("S", f, X[i] + 2, X[i + 1] - 1)
			end
			if not skip.N then
				facade("N", f, X[i] + 2, X[i + 1] - 1)
			end
		end
		for j = 1, #Z - 1 do
			if not skip.O then
				facade("O", f, Z[j] + 2, Z[j + 1] - 1)
			end
			if not skip.L then
				facade("L", f, Z[j] + 2, Z[j + 1] - 1)
			end
		end
	end
	if o.Roof then
		local yr = Lv[#Lv] + 1
		local pm = o.RoofMaterial or "Concrete"
		if not skip.S then
			self:add("Wall", pm, xs, yr, zs, xe, yr + 1, zs, name .. "_Platibanda_S")
		end
		if not skip.N then
			self:add("Wall", pm, xs, yr, ze, xe, yr + 1, ze, name .. "_Platibanda_N")
		end
		if not skip.O then
			self:add("Wall", pm, xs, yr, zs + 1, xs, yr + 1, ze - 1, name .. "_Platibanda_O")
		end
		if not skip.L then
			self:add("Wall", pm, xe, yr, zs + 1, xe, yr + 1, ze - 1, name .. "_Platibanda_L")
		end
	end
end

return BuildingKit
