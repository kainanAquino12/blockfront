--[[
	TerrainGen (servidor) — relevo do mapa V5 com o Terrain do Roblox.

	O relevo é uma função de altura h(x, z) em studs, SIMÉTRICA em z
	(h(x, z) = h(x, -z)), então os dois times têm o mesmo terreno.

	Camadas (de baixo para cima na composição da altura):
	  colinas    ruído suave nos campos entre bases e centro (+1 a +9)
	  vala       riacho seco que corta o mapa em z = ±185 (até -6)
	  cume leste sobe até +20 a leste, com platô no topo (QG militar)
	  platôs     áreas planas para fundações: centro (+2), indústria (0),
	             bases (+10), topo do cume (+20). Transição suave nas bordas.
	  estradas   cada estrada tem largura e perfil próprio: segue o terreno
	             suavizado e aplaina a seção transversal (estradas inclinadas)

	Materiais: asfalto nas estradas, calçamento nos platôs urbanos, lama no
	fundo da vala, rocha nas encostas íngremes, terra e grama no resto.
	Cores do Terrain ajustadas para a paleta sóbria (nada de verde-limão).

	TerrainGen.height(x, z) é usado também para posicionar estruturas,
	pontos de captura e spawns em cima do chão.
]]

local TerrainGen = {}

TerrainGen.HalfX = 480 -- V6: expandido para oeste (porto) e leste (subúrbio)
TerrainGen.HalfZ = 440
TerrainGen.Floor = -16 -- fundo do terreno

local RES = 4

---------------------------------------------------------------------------
-- Formas
---------------------------------------------------------------------------

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Distância de um ponto até um retângulo (0 dentro).
local function rectDist(x: number, z: number, x0: number, z0: number, x1: number, z1: number): number
	local dx = math.max(x0 - x, 0, x - x1)
	local dz = math.max(z0 - z, 0, z - z1)
	return math.sqrt(dx * dx + dz * dz)
end

-- Platôs: { x0, z0, x1, z1, altura, borda }. z em valor absoluto (simétrico).
TerrainGen.Pads = {
	Center = { -150, 0, 78, 132, 2, 26 },
	Industry = { -320, 0, -150, 142, 0, 24 },
	Base = { -90, 330, 90, 440, 12, 40 },
	Military = { 196, 0, 272, 44, 26, 26 },
	Port = { -480, 0, -386, 172, 1, 16 }, -- V6: pátio do porto, além do canal
	Suburb = { 352, 0, 470, 262, 5, 30 }, -- V6: planície do subúrbio a leste
}

-- Estradas: polilinhas { {x, |z|}, ... } (meio mapa; a outra metade é espelhada).
TerrainGen.Roads = {
	{ Name = "Avenida", Width = 18, Points = { { 0, 0 }, { 0, 440 } } },
	{ Name = "Industrial", Width = 12, Points = { { -170, 60 }, { -170, 400 } } },
	{ Name = "Morro", Width = 12, Points = { { 196, 0 }, { 186, 40 }, { 150, 120 }, { 112, 200 }, { 70, 300 } } },
	{ Name = "LigacaoOeste", Width = 14, Points = { { -176, 0 }, { -150, 0 } } },
	{ Name = "LigacaoLeste", Width = 12, Points = { { 78, 0 }, { 196, 0 } } },
	{ Name = "AnelSul", Width = 12, Points = { { -150, 126 }, { 78, 126 } } },
	{ Name = "AcessoBase", Width = 14, Points = { { -60, 330 }, { 60, 330 } } },
	-- V6
	{ Name = "Porto", Width = 14, Points = { { -170, 150 }, { -480, 150 } } },
	{ Name = "PortoSul", Width = 12, Points = { { -170, 300 }, { -480, 300 } } },
	{ Name = "LesteSuburbio", Width = 12, Points = { { 272, 0 }, { 330, 24 }, { 474, 24 } } },
	{ Name = "RuaSuburbio", Width = 12, Points = { { 404, 24 }, { 404, 330 } } },
	{ Name = "MorroSuburbio", Width = 10, Points = { { 70, 300 }, { 250, 330 }, { 404, 330 } } },
}

-- V6: canal com água de norte a sul a oeste da indústria (pontes nas estradas do porto)
TerrainGen.Canal = { X = -365, HalfWidth = 16, Bottom = -8, Water = -2 }

-- V6: crateras de impacto { x, |z|, raio, profundidade }
TerrainGen.Craters = {
	{ -60, 222, 7, 2.5 }, { 110, 160, 6, 2 }, { -212, 232, 8, 3 }, { 380, 120, 7, 2.5 },
	{ 430, 240, 6, 2 }, { -20, 292, 6, 2 }, { 262, 252, 7, 2.5 }, { 300, 90, 6, 2 },
}

TerrainGen.Valley = { Z = 185, HalfWidth = 16, Depth = 7 }
-- Trincheiras em zigue-zague na encosta oeste do QG militar ({x, |z|} ...)
TerrainGen.Trenches = {
	{ Width = 4, Depth = 3, Points = { { 188, 0 }, { 183, 12 }, { 189, 24 }, { 183, 36 }, { 188, 48 } } },
}
TerrainGen.RidgeHeight = 26
TerrainGen.BaseHeight = 12
-- { x, |z|, raio, altura }
TerrainGen.Hills = {
	{ -130, 255, 46, 11 },
	{ 70, 250, 38, 8 },
	{ -250, 270, 40, 9 },
}

local function baseHeight(x: number, az: number): number
	-- colinas suaves (ruído) nos campos
	local hills = 4
		+ 6.5 * math.noise(x / 80, az / 80, 0.37)
		+ 3 * math.noise(x / 34, az / 34, 4.1)
		+ 1.2 * math.noise(x / 13, az / 13, 9.3)
	-- colinas de observação nos campos (uma de cada lado do mapa, por time)
	for _, c in TerrainGen.Hills do
		local d = math.sqrt((x - c[1]) ^ 2 + (az - c[2]) ^ 2)
		if d < c[3] then
			local k = math.cos(d / c[3] * math.pi * 0.5)
			hills += c[4] * k * k
		end
	end
	hills = math.max(hills, 0.5)

	-- cume leste: sobe até +20 em x ~ 230, some perto dos limites
	local ridgeK = smoothstep(105, 200, x) * (1 - smoothstep(296, 362, x))
	local ridgeZ = 1 - smoothstep(120, 300, az)
	local ridge = TerrainGen.RidgeHeight * ridgeK * ridgeZ + 2.5 * math.noise(x / 25, az / 25, 2.2) * ridgeK
	local h = math.max(hills, ridge)

	-- vala (riacho seco)
	local v = TerrainGen.Valley
	local dv = math.abs(az - v.Z)
	if dv < v.HalfWidth then
		local k = math.cos(dv / v.HalfWidth * math.pi * 0.5)
		h -= v.Depth * k * k
	end

	-- plano de transição para as bases
	h = h + (TerrainGen.BaseHeight - h) * smoothstep(290, 340, az)
	return h
end

local function padBlend(x: number, az: number, h: number): (number, string?)
	local which = nil
	for name, p in TerrainGen.Pads do
		local d = rectDist(x, az, p[1], p[2], p[3], p[4])
		if d < p[6] then
			local k = 1 - smoothstep(0, p[6], d)
			h = h + (p[5] - h) * k
			if d == 0 then
				which = name
			end
		end
	end
	return h, which
end

-- Distância até uma estrada e posição ao longo dela (para o perfil).
local function roadInfo(x: number, az: number)
	local best, bestRoad, bestA = math.huge, nil, nil
	for _, r in TerrainGen.Roads do
		local pts = r.Points
		for i = 1, #pts - 1 do
			local ax, az0 = pts[i][1], pts[i][2]
			local bx, bz = pts[i + 1][1], pts[i + 1][2]
			local vx, vz = bx - ax, bz - az0
			local len2 = vx * vx + vz * vz
			local t = math.clamp(((x - ax) * vx + (az - az0) * vz) / len2, 0, 1)
			local px, pz = ax + vx * t, az0 + vz * t
			local d = math.sqrt((x - px) ^ 2 + (az - pz) ^ 2) - r.Width / 2
			if d < best then
				best, bestRoad, bestA = d, r, Vector2.new(px, pz)
			end
		end
	end
	return best, bestRoad, bestA
end

local function trenchDepth(x: number, az: number): number
	local best = 0
	for _, t in TerrainGen.Trenches do
		local pts = t.Points
		for i = 1, #pts - 1 do
			local ax, az0 = pts[i][1], pts[i][2]
			local vx, vz = pts[i + 1][1] - ax, pts[i + 1][2] - az0
			local tt = math.clamp(((x - ax) * vx + (az - az0) * vz) / (vx * vx + vz * vz), 0, 1)
			local d = math.sqrt((x - ax - vx * tt) ^ 2 + (az - az0 - vz * tt) ^ 2)
			if d < t.Width / 2 + 1 then
				best = math.max(best, t.Depth * (1 - smoothstep(t.Width / 2 - 0.5, t.Width / 2 + 1, d)))
			end
		end
	end
	return best
end

local function rawHeight(x: number, az: number): (number, string?)
	local h = baseHeight(x, az)
	local hh, pad = padBlend(x, az, h)
	hh -= trenchDepth(x, az)
	-- crateras
	for _, c in TerrainGen.Craters do
		local d = math.sqrt((x - c[1]) ^ 2 + (az - c[2]) ^ 2)
		if d < c[3] * 1.3 then
			if d < c[3] then
				hh -= c[4] * (1 - (d / c[3]) ^ 2)
			else
				hh += 0.6 * math.sin((d - c[3]) / (c[3] * 0.3) * math.pi) -- borda levantada
			end
		end
	end
	-- canal (depois dos platôs: corta qualquer coisa)
	local cn = TerrainGen.Canal
	local dc = math.abs(x - cn.X)
	if dc < cn.HalfWidth then
		local k = math.cos(dc / cn.HalfWidth * math.pi * 0.5)
		k = math.min(1, k * 1.6)
		hh = hh + (cn.Bottom - hh) * k
	end
	return hh, pad
end

--[[
	Altura final do chão em (x, z) e o tipo de superfície.
	Estradas: a altura da seção é a do eixo da estrada (suavizada), então a
	pista fica plana de lado a lado e sobe/desce com o terreno.
]]
function TerrainGen.sample(x: number, z: number): (number, string)
	local az = math.abs(z)
	local h, pad = rawHeight(x, az)
	local d, road, axis = roadInfo(x, az)
	local kind = "Natural"
	if pad == "Center" or pad == "Base" then
		kind = "Urban"
	elseif pad == "Industry" or pad == "Military" or pad == "Port" then
		kind = "Yard"
	end
	if math.abs(x - TerrainGen.Canal.X) < TerrainGen.Canal.HalfWidth then
		kind = "Canal"
	end
	if road and d < 6 then
		-- altura do eixo, média de 3 amostras ao longo (suaviza)
		local ah = 0
		for _, o in { -6, 0, 6 } do
			local hh = rawHeight(axis.X + o, axis.Y + o)
			ah += hh
		end
		ah /= 3
		-- na vala, a estrada não desce: passa por cima (ponte)
		local v = TerrainGen.Valley
		local onBridge = math.abs(axis.Y - v.Z) < v.HalfWidth + 2
		if onBridge then
			-- o chão continua sendo a vala; a ponte é uma estrutura
			return h, "Valley"
		end
		local cn = TerrainGen.Canal
		if math.abs(axis.X - cn.X) < cn.HalfWidth + 2 then
			return h, "Canal"
		end
		local k = 1 - smoothstep(0, 6, d)
		h = h + (ah - h) * k
		if d <= 0 then
			kind = "Road"
		end
	end
	local v = TerrainGen.Valley
	if math.abs(az - v.Z) < v.HalfWidth * 0.55 and kind == "Natural" then
		kind = "Valley"
	end
	return h, kind
end

function TerrainGen.height(x: number, z: number): number
	local h = TerrainGen.sample(x, z)
	return h
end

-- Altura da pista sobre o canal (estrada em z = zRoad).
function TerrainGen.canalDeckHeight(zRoad: number): number
	local c = TerrainGen.Canal
	local a = TerrainGen.height(c.X - c.HalfWidth - 4, zRoad)
	local b = TerrainGen.height(c.X + c.HalfWidth + 4, zRoad)
	return math.max(a, b)
end

-- Altura da pista no eixo da ponte sobre a vala (para posicionar pontes).
function TerrainGen.bridgeDeckHeight(x: number): number
	local v = TerrainGen.Valley
	local a = TerrainGen.height(x, v.Z - v.HalfWidth - 4)
	local b = TerrainGen.height(x, v.Z + v.HalfWidth + 4)
	return math.max(a, b)
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------

local COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(86, 92, 62),
	[Enum.Material.Ground] = Color3.fromRGB(102, 90, 72),
	[Enum.Material.Mud] = Color3.fromRGB(76, 68, 56),
	[Enum.Material.Rock] = Color3.fromRGB(108, 106, 100),
	[Enum.Material.Asphalt] = Color3.fromRGB(52, 54, 58),
	[Enum.Material.Pavement] = Color3.fromRGB(108, 108, 104),
	[Enum.Material.Concrete] = Color3.fromRGB(96, 96, 93),
	[Enum.Material.Slate] = Color3.fromRGB(84, 84, 82),
}

local function materialFor(kind: string, slope: number, x: number, z: number): Enum.Material
	if kind == "Road" then
		return Enum.Material.Asphalt
	elseif kind == "Urban" then
		return Enum.Material.Pavement
	elseif kind == "Yard" then
		return Enum.Material.Concrete
	elseif kind == "Valley" or kind == "Canal" then
		return Enum.Material.Mud
	end
	if slope > 0.55 then
		return Enum.Material.Rock
	elseif slope > 0.32 then
		return Enum.Material.Ground
	end
	-- manchas de terra batida na grama (marcas de combate)
	if math.noise(x / 18, z / 18, 7.7) > 0.25 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

--[[
	Escreve o terreno inteiro (WriteVoxels por faixas para não travar o
	servidor). Retorna o tempo gasto em segundos.
]]
function TerrainGen.build(): number
	local t0 = os.clock()
	local terrain = workspace.Terrain
	terrain:Clear()
	for mat, color in COLORS do
		terrain:SetMaterialColor(mat, color)
	end

	local hx, hz = TerrainGen.HalfX + 16, TerrainGen.HalfZ + 16
	local nx = math.floor(hx * 2 / RES)
	local nz = math.floor(hz * 2 / RES)
	local y0 = TerrainGen.Floor
	local ny = math.floor((36 - y0) / RES)

	-- alturas e superfícies por coluna
	local H = table.create(nx * nz)
	local K = table.create(nx * nz)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local x = -hx + (i + 0.5) * RES
			local z = -hz + (j + 0.5) * RES
			local h, kind = TerrainGen.sample(x, z)
			H[i * nz + j + 1] = h
			K[i * nz + j + 1] = kind
		end
		if i % 20 == 0 then
			task.wait()
		end
	end

	local STRIP = 40 -- colunas em X por WriteVoxels
	for i0 = 0, nx - 1, STRIP do
		local w = math.min(STRIP, nx - i0)
		local mats = table.create(w)
		local occ = table.create(w)
		for a = 1, w do
			local i = i0 + a - 1
			local mcol, ocol = table.create(ny), table.create(ny)
			for b = 1, ny do
				mcol[b] = table.create(nz)
				ocol[b] = table.create(nz)
			end
			for j = 0, nz - 1 do
				local h = H[i * nz + j + 1]
				local kind = K[i * nz + j + 1]
				local hxn = H[math.min(i + 1, nx - 1) * nz + j + 1]
				local hzn = H[i * nz + math.min(j + 1, nz - 1) + 1]
				local slope = math.max(math.abs(hxn - h), math.abs(hzn - h)) / RES
				local x = -hx + (i + 0.5) * RES
				local z = -hz + (j + 0.5) * RES
				local surf = materialFor(kind, slope, x, z)
				local cn = TerrainGen.Canal
				local water = if math.abs(x - cn.X) < cn.HalfWidth + 2 then cn.Water else nil
				for b = 1, ny do
					local cellBottom = y0 + (b - 1) * RES
					local fill = math.clamp((h - cellBottom) / RES, 0, 1)
					if fill > 0 then
						local top = h - cellBottom < RES * 1.5
						mcol[b][j + 1] = if top then surf elseif cellBottom > h - 8 then Enum.Material.Ground else Enum.Material.Rock
						ocol[b][j + 1] = fill
					elseif water and cellBottom < water then
						mcol[b][j + 1] = Enum.Material.Water
						ocol[b][j + 1] = math.clamp((water - cellBottom) / RES, 0, 1)
					else
						mcol[b][j + 1] = Enum.Material.Air
						ocol[b][j + 1] = 0
					end
				end
			end
			mats[a] = mcol
			occ[a] = ocol
		end
		local min = Vector3.new(-hx + i0 * RES, y0, -hz)
		local region = Region3.new(min, min + Vector3.new(w * RES, ny * RES, nz * RES))
		terrain:WriteVoxels(region, RES, mats, occ)
		task.wait()
	end
	return os.clock() - t0
end

return TerrainGen
