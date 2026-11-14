--[[
	PropKit (servidor)
	Cenário estático (não destrutível) em blocos: piso, ruas, bases,
	árvores, pedras, postes, cercas, bandeiras e limites do mapa.
	Tudo ancorado e com poucas peças; detalhes pequenos sem colisão nem
	sombra para economizar física e renderização.
]]

local PropKit = {}

local COLORS = {
	Grass = Color3.fromRGB(104, 176, 92),
	GrassDark = Color3.fromRGB(86, 152, 78),
	Dirt = Color3.fromRGB(176, 140, 96),
	Asphalt = Color3.fromRGB(64, 68, 78),
	Line = Color3.fromRGB(246, 214, 80),
	Sidewalk = Color3.fromRGB(196, 196, 204),
	Trunk = Color3.fromRGB(120, 78, 48),
	Leaves = Color3.fromRGB(76, 156, 72),
	LeavesLight = Color3.fromRGB(110, 186, 84),
	Rock = Color3.fromRGB(130, 134, 142),
	RockDark = Color3.fromRGB(104, 108, 118),
	Metal = Color3.fromRGB(70, 74, 84),
	Lamp = Color3.fromRGB(255, 236, 170),
	BaseFloor = Color3.fromRGB(150, 156, 168),
}
PropKit.Colors = COLORS

-- Cria uma peça ancorada. detail = true: sem colisão/sombra (enfeites).
function PropKit.block(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, detail: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if detail then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local block = PropKit.block

function PropKit.tree(parent: Instance, cf: CFrame, scale: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local s = scale
	block(m, cf * CFrame.new(0, 3 * s, 0), Vector3.new(1.4, 6, 1.4) * s, COLORS.Trunk)
	block(m, cf * CFrame.new(0, 7 * s, 0), Vector3.new(6, 4, 6) * s, COLORS.Leaves)
	block(m, cf * CFrame.new(0.4 * s, 10 * s, -0.3 * s), Vector3.new(4.4, 3, 4.4) * s, COLORS.LeavesLight)
	block(m, cf * CFrame.new(-0.2 * s, 12.2 * s, 0.2 * s), Vector3.new(2.4, 1.6, 2.4) * s, COLORS.Leaves)
	m.Parent = parent
end

function PropKit.rock(parent: Instance, cf: CFrame, scale: number)
	local m = Instance.new("Model")
	m.Name = "Rock"
	local s = scale
	block(m, cf * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, 0.3, 0), Vector3.new(5, 2.6, 4) * s, COLORS.Rock, Enum.Material.Slate)
	block(m, cf * CFrame.new(1 * s, 2.6 * s, 0.4 * s) * CFrame.Angles(0, -0.4, 0), Vector3.new(3, 1.8, 2.6) * s, COLORS.RockDark, Enum.Material.Slate)
	m.Parent = parent
end

function PropKit.lamp(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	block(m, cf * CFrame.new(0, 0.25, 0), Vector3.new(1.2, 0.5, 1.2), COLORS.Metal)
	block(m, cf * CFrame.new(0, 5, 0), Vector3.new(0.5, 10, 0.5), COLORS.Metal)
	block(m, cf * CFrame.new(0, 10, -1), Vector3.new(0.5, 0.5, 2.5), COLORS.Metal, nil, true)
	local bulb = block(m, cf * CFrame.new(0, 9.6, -2), Vector3.new(1, 0.5, 1), COLORS.Lamp, Enum.Material.Neon, true)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.8
	light.Color = COLORS.Lamp
	light.Parent = bulb
	m.Parent = parent
end

function PropKit.fence(parent: Instance, from: Vector3, to: Vector3)
	local m = Instance.new("Model")
	m.Name = "Fence"
	local dir = to - from
	local len = dir.Magnitude
	local cf = CFrame.lookAt(from, to)
	local posts = math.max(1, math.floor(len / 4))
	for i = 0, posts do
		block(m, cf * CFrame.new(0, 1.5, -len * i / posts), Vector3.new(0.5, 3, 0.5), COLORS.Trunk)
	end
	block(m, cf * CFrame.new(0, 2.4, -len / 2), Vector3.new(0.2, 0.4, len), COLORS.Trunk, nil, true)
	block(m, cf * CFrame.new(0, 1.2, -len / 2), Vector3.new(0.2, 0.4, len), COLORS.Trunk, nil, true)
	m.Parent = parent
end

function PropKit.flag(parent: Instance, cf: CFrame, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Flag"
	block(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(2, 1, 2), COLORS.Metal)
	block(m, cf * CFrame.new(0, 9, 0), Vector3.new(0.5, 17, 0.5), Color3.fromRGB(220, 220, 228))
	block(m, cf * CFrame.new(2.6, 15.5, 0), Vector3.new(4.8, 3, 0.2), color, nil, true)
	block(m, cf * CFrame.new(2.6, 15.5, 0), Vector3.new(1.4, 3.02, 0.22), Color3.fromRGB(245, 245, 245), nil, true)
	m.Parent = parent
end

-- Contêiner de carga (cobertura estática grande).
function PropKit.container(parent: Instance, cf: CFrame, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Container"
	block(m, cf * CFrame.new(0, 4, 0), Vector3.new(16, 8, 6.5), color, Enum.Material.SmoothPlastic)
	for i = -3, 3 do
		block(m, cf * CFrame.new(i * 2.2, 4, -3.3), Vector3.new(0.5, 7.4, 0.2), color:Lerp(Color3.new(0, 0, 0), 0.25), nil, true)
		block(m, cf * CFrame.new(i * 2.2, 4, 3.3), Vector3.new(0.5, 7.4, 0.2), color:Lerp(Color3.new(0, 0, 0), 0.25), nil, true)
	end
	m.Parent = parent
end

-- Estrada reta com faixa central tracejada.
function PropKit.road(parent: Instance, center: Vector3, length: number, width: number, alongZ: boolean)
	local size = if alongZ then Vector3.new(width, 0.2, length) else Vector3.new(length, 0.2, width)
	block(parent, CFrame.new(center + Vector3.new(0, 0.1, 0)), size, COLORS.Asphalt, Enum.Material.Asphalt)
	local dashes = math.floor(length / 8)
	for i = 0, dashes - 1 do
		local t = -length / 2 + 4 + i * 8
		local off = if alongZ then Vector3.new(0, 0.22, t) else Vector3.new(t, 0.22, 0)
		local dsize = if alongZ then Vector3.new(0.6, 0.05, 4) else Vector3.new(4, 0.05, 0.6)
		block(parent, CFrame.new(center + off), dsize, COLORS.Line, nil, true)
	end
end

-- Muro estático alto nos limites do mapa (pedra em blocos) + barreira invisível.
function PropKit.boundary(parent: Instance, halfX: number, halfZ: number)
	local h = 40
	local rng = Random.new(7)
	local function side(cf: CFrame, len: number)
		local barrier = block(parent, cf * CFrame.new(0, h / 2, 0), Vector3.new(len, h, 2), Color3.new(), nil, false)
		barrier.Transparency = 1
		barrier.CastShadow = false
		barrier.Name = "Boundary"
		local x = -len / 2
		while x < len / 2 do
			local w = rng:NextNumber(8, 16)
			local hh = rng:NextNumber(6, 16)
			block(parent, cf * CFrame.new(x + w / 2, hh / 2, -4), Vector3.new(w, hh, rng:NextNumber(6, 10)), if rng:NextNumber() < 0.5 then COLORS.Rock else COLORS.RockDark, Enum.Material.Slate)
			x += w - 1
		end
	end
	side(CFrame.new(0, 0, -halfZ), halfX * 2)
	side(CFrame.new(0, 0, halfZ) * CFrame.Angles(0, math.pi, 0), halfX * 2)
	side(CFrame.new(-halfX, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), halfZ * 2)
	side(CFrame.new(halfX, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), halfZ * 2)
end

---------------------------------------------------------------------------
-- Cidade
---------------------------------------------------------------------------

-- Calçada elevada (retângulo centrado em cf).
function PropKit.sidewalk(parent: Instance, cf: CFrame, size: Vector2)
	block(parent, cf * CFrame.new(0, 0.2, 0), Vector3.new(size.X, 0.4, size.Y), COLORS.Sidewalk, Enum.Material.Concrete)
end

-- Faixa de pedestres (listras paralelas ao eixo local Z, distribuídas em X).
function PropKit.crosswalk(parent: Instance, cf: CFrame, width: number)
	local n = math.floor(width / 2)
	for i = 0, n - 1 do
		block(parent, cf * CFrame.new(-width / 2 + 1 + i * 2, 0.23, 0), Vector3.new(1, 0.05, 5), Color3.fromRGB(240, 240, 240), nil, true)
	end
end

-- Carro estacionado em blocos (cobertura estática).
function PropKit.car(parent: Instance, cf: CFrame, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Car"
	local dark = Color3.fromRGB(30, 32, 38)
	local glass = Color3.fromRGB(150, 196, 220)
	block(m, cf * CFrame.new(0, 1.4, 0), Vector3.new(4.6, 1.6, 9), color)
	block(m, cf * CFrame.new(0, 2.8, 0.6), Vector3.new(4.2, 1.4, 4.6), color)
	block(m, cf * CFrame.new(0, 2.8, -1.7), Vector3.new(4.0, 1.2, 0.2), glass, Enum.Material.Glass, true)
	block(m, cf * CFrame.new(0, 2.8, 2.9), Vector3.new(4.0, 1.2, 0.2), glass, Enum.Material.Glass, true)
	block(m, cf * CFrame.new(2.12, 2.8, 0.6), Vector3.new(0.2, 1.1, 4.2), glass, Enum.Material.Glass, true)
	block(m, cf * CFrame.new(-2.12, 2.8, 0.6), Vector3.new(0.2, 1.1, 4.2), glass, Enum.Material.Glass, true)
	for _, w in { { 2.1, 3 }, { -2.1, 3 }, { 2.1, -3 }, { -2.1, -3 } } do
		block(m, cf * CFrame.new(w[1], 0.8, w[2]), Vector3.new(0.8, 1.6, 1.6), dark, nil, true)
	end
	block(m, cf * CFrame.new(1.4, 1.5, -4.55), Vector3.new(1, 0.5, 0.1), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, true)
	block(m, cf * CFrame.new(-1.4, 1.5, -4.55), Vector3.new(1, 0.5, 0.1), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, true)
	block(m, cf * CFrame.new(1.4, 1.5, 4.55), Vector3.new(1, 0.5, 0.1), Color3.fromRGB(220, 40, 40), Enum.Material.Neon, true)
	block(m, cf * CFrame.new(-1.4, 1.5, 4.55), Vector3.new(1, 0.5, 0.1), Color3.fromRGB(220, 40, 40), Enum.Material.Neon, true)
	m.Parent = parent
end

-- Caminhão militar em blocos.
function PropKit.truck(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Truck"
	local olive = Color3.fromRGB(98, 112, 70)
	local dark = Color3.fromRGB(30, 32, 38)
	block(m, cf * CFrame.new(0, 2.2, -4), Vector3.new(5, 3.4, 4), olive)
	block(m, cf * CFrame.new(0, 2.9, -6.05), Vector3.new(4.4, 1.2, 0.1), Color3.fromRGB(150, 196, 220), Enum.Material.Glass, true)
	block(m, cf * CFrame.new(0, 1.6, 2.5), Vector3.new(5.4, 1.2, 9), dark)
	block(m, cf * CFrame.new(0, 3.6, 2.5), Vector3.new(5.6, 3.4, 9), Color3.fromRGB(122, 132, 88), Enum.Material.Fabric)
	for _, z in { -4, 1, 5 } do
		block(m, cf * CFrame.new(2.6, 1, z), Vector3.new(0.9, 2, 2), dark, nil, true)
		block(m, cf * CFrame.new(-2.6, 1, z), Vector3.new(0.9, 2, 2), dark, nil, true)
	end
	m.Parent = parent
end

function PropKit.bench(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Bench"
	block(m, cf * CFrame.new(0, 1, 0), Vector3.new(4, 0.3, 1.2), COLORS.Trunk)
	block(m, cf * CFrame.new(0, 1.7, 0.5), Vector3.new(4, 1, 0.2), COLORS.Trunk, nil, true)
	block(m, cf * CFrame.new(-1.7, 0.5, 0), Vector3.new(0.3, 1, 1), COLORS.Metal, nil, true)
	block(m, cf * CFrame.new(1.7, 0.5, 0), Vector3.new(0.3, 1, 1), COLORS.Metal, nil, true)
	m.Parent = parent
end

function PropKit.hydrant(parent: Instance, cf: CFrame)
	block(parent, cf * CFrame.new(0, 0.9, 0), Vector3.new(0.8, 1.8, 0.8), Color3.fromRGB(214, 52, 44))
	block(parent, cf * CFrame.new(0, 1.2, 0), Vector3.new(1.3, 0.3, 0.3), Color3.fromRGB(214, 52, 44), nil, true)
end

function PropKit.trashBin(parent: Instance, cf: CFrame)
	block(parent, cf * CFrame.new(0, 1, 0), Vector3.new(1.4, 2, 1.4), Color3.fromRGB(60, 110, 70))
	block(parent, cf * CFrame.new(0, 2.05, 0), Vector3.new(1.6, 0.15, 1.6), Color3.fromRGB(40, 70, 48), nil, true)
end

function PropKit.trafficLight(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "TrafficLight"
	block(m, cf * CFrame.new(0, 4.5, 0), Vector3.new(0.5, 9, 0.5), COLORS.Metal)
	block(m, cf * CFrame.new(0, 8.8, -2.5), Vector3.new(0.4, 0.4, 5), COLORS.Metal, nil, true)
	block(m, cf * CFrame.new(0, 7.8, -4.6), Vector3.new(1, 2.6, 0.8), Color3.fromRGB(30, 32, 38), nil, true)
	block(m, cf * CFrame.new(0, 8.6, -5.02), Vector3.new(0.5, 0.5, 0.05), Color3.fromRGB(255, 60, 50), Enum.Material.Neon, true)
	block(m, cf * CFrame.new(0, 7.8, -5.02), Vector3.new(0.5, 0.5, 0.05), Color3.fromRGB(80, 60, 30), nil, true)
	block(m, cf * CFrame.new(0, 7.0, -5.02), Vector3.new(0.5, 0.5, 0.05), Color3.fromRGB(30, 70, 40), nil, true)
	m.Parent = parent
end

function PropKit.bush(parent: Instance, cf: CFrame, scale: number)
	block(parent, cf * CFrame.new(0, 1 * scale, 0), Vector3.new(3, 2, 3) * scale, COLORS.Leaves)
	block(parent, cf * CFrame.new(0.4 * scale, 2.2 * scale, 0.2 * scale), Vector3.new(2, 1, 2) * scale, COLORS.LeavesLight, nil, true)
end

-- Canteiro com flores.
function PropKit.planter(parent: Instance, cf: CFrame, length: number)
	block(parent, cf * CFrame.new(0, 0.6, 0), Vector3.new(length, 1.2, 2), Color3.fromRGB(150, 150, 158), Enum.Material.Concrete)
	block(parent, cf * CFrame.new(0, 1.25, 0), Vector3.new(length - 0.4, 0.3, 1.6), Color3.fromRGB(86, 150, 70), Enum.Material.Grass, true)
	local colors = { Color3.fromRGB(240, 90, 110), Color3.fromRGB(250, 210, 80), Color3.fromRGB(250, 250, 250) }
	for i = 0, math.floor(length / 1.5) - 1 do
		block(parent, cf * CFrame.new(-length / 2 + 1 + i * 1.5, 1.55, (i % 2) * 0.5 - 0.25), Vector3.new(0.5, 0.4, 0.5), colors[i % 3 + 1], nil, true)
	end
end

function PropKit.fountain(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Fountain"
	local stone = Color3.fromRGB(176, 178, 186)
	block(m, cf * CFrame.new(0, 0.8, 0), Vector3.new(14, 1.6, 14), stone, Enum.Material.Concrete)
	local water = block(m, cf * CFrame.new(0, 1.65, 0), Vector3.new(12, 0.2, 12), Color3.fromRGB(80, 160, 220), Enum.Material.Glass, true)
	water.Transparency = 0.3
	block(m, cf * CFrame.new(0, 3, 0), Vector3.new(3, 3, 3), stone, Enum.Material.Concrete)
	block(m, cf * CFrame.new(0, 5, 0), Vector3.new(1.4, 1.4, 1.4), stone, Enum.Material.Concrete)
	block(m, cf * CFrame.new(0, 6, 0), Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(130, 200, 240), Enum.Material.Neon, true)
	m.Parent = parent
end

function PropKit.billboard(parent: Instance, cf: CFrame, text: string, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Billboard"
	block(m, cf * CFrame.new(-4, 5, 0), Vector3.new(0.6, 10, 0.6), COLORS.Metal)
	block(m, cf * CFrame.new(4, 5, 0), Vector3.new(0.6, 10, 0.6), COLORS.Metal)
	local board = block(m, cf * CFrame.new(0, 11, 0), Vector3.new(14, 5, 0.5), color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.PixelsPerStud = 30
		gui.Face = face
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = text
		t.Parent = gui
	end
	m.Parent = parent
end

---------------------------------------------------------------------------
-- Indústria
---------------------------------------------------------------------------

function PropKit.silo(parent: Instance, cf: CFrame, height: number)
	local m = Instance.new("Model")
	m.Name = "Silo"
	local c = Color3.fromRGB(196, 202, 212)
	local band = Color3.fromRGB(150, 156, 168)
	local body = block(m, cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, 10, 10), c, Enum.Material.Metal)
	body.Shape = Enum.PartType.Cylinder
	local cap = block(m, cf * CFrame.new(0, height + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1, 8, 8), band, Enum.Material.Metal)
	cap.Shape = Enum.PartType.Cylinder
	for i = 1, math.floor(height / 4) do
		local ring = block(m, cf * CFrame.new(0, i * 4, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 10.3, 10.3), band, Enum.Material.Metal, true)
		ring.Shape = Enum.PartType.Cylinder
	end
	m.Parent = parent
end

-- Guindaste de pórtico (estático).
function PropKit.crane(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Crane"
	local y = Color3.fromRGB(236, 180, 40)
	for _, x in { -12, 12 } do
		for _, z in { -3, 3 } do
			block(m, cf * CFrame.new(x, 11, z), Vector3.new(1.4, 22, 1.4), y, Enum.Material.Metal)
		end
		block(m, cf * CFrame.new(x, 1, 0), Vector3.new(2, 2, 8), COLORS.Metal)
	end
	block(m, cf * CFrame.new(0, 22.5, 3), Vector3.new(27, 1.6, 1.4), y, Enum.Material.Metal)
	block(m, cf * CFrame.new(0, 22.5, -3), Vector3.new(27, 1.6, 1.4), y, Enum.Material.Metal)
	block(m, cf * CFrame.new(3, 21, 0), Vector3.new(4, 2.4, 7), Color3.fromRGB(60, 64, 72))
	block(m, cf * CFrame.new(3, 14, 0), Vector3.new(0.2, 12, 0.2), Color3.fromRGB(30, 30, 30), nil, true)
	m.Parent = parent
end

-- Tubulação aérea entre dois pontos.
function PropKit.pipe(parent: Instance, from: Vector3, to: Vector3, height: number)
	local a, b = from + Vector3.new(0, height, 0), to + Vector3.new(0, height, 0)
	local len = (b - a).Magnitude
	block(parent, CFrame.lookAt((a + b) / 2, b), Vector3.new(1.4, 1.4, len), Color3.fromRGB(196, 110, 60), Enum.Material.Metal)
	for _, p in { from, to } do
		block(parent, CFrame.new(p + Vector3.new(0, height / 2, 0)), Vector3.new(0.8, height, 0.8), COLORS.Metal)
	end
end

---------------------------------------------------------------------------
-- Campo e área militar
---------------------------------------------------------------------------

-- Colina em degraus (estilo voxel), boa para combate de longa distância.
function PropKit.hill(parent: Instance, cf: CFrame, width: number, depth: number, steps: number)
	for i = 0, steps - 1 do
		local w, d = width - i * width / (steps + 1), depth - i * depth / (steps + 1)
		local color = if i % 2 == 0 then COLORS.Grass else COLORS.GrassDark
		block(parent, cf * CFrame.new(0, i * 2 + 1, 0), Vector3.new(w, 2, d), color, Enum.Material.Grass)
	end
end

function PropKit.crops(parent: Instance, cf: CFrame, width: number, depth: number)
	block(parent, cf * CFrame.new(0, 0.1, 0), Vector3.new(width, 0.2, depth), Color3.fromRGB(120, 90, 60), Enum.Material.Ground, true)
	for x = -width / 2 + 1.5, width / 2 - 1.5, 3 do
		block(parent, cf * CFrame.new(x, 0.9, 0), Vector3.new(1.2, 1.4, depth - 2), Color3.fromRGB(150, 190, 70), Enum.Material.Grass, true)
	end
end

function PropKit.powerPole(parent: Instance, cf: CFrame)
	block(parent, cf * CFrame.new(0, 8, 0), Vector3.new(0.8, 16, 0.8), COLORS.Trunk)
	block(parent, cf * CFrame.new(0, 15, 0), Vector3.new(6, 0.5, 0.5), COLORS.Trunk, nil, true)
end

function PropKit.tent(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Tent"
	local c = Color3.fromRGB(118, 128, 86)
	block(m, cf * CFrame.new(0, 2.6, 0), Vector3.new(8, 0.4, 10), c, Enum.Material.Fabric)
	block(m, cf * CFrame.new(-3.2, 1.3, 0) * CFrame.Angles(0, 0, math.rad(20)), Vector3.new(0.3, 3, 10), c, Enum.Material.Fabric)
	block(m, cf * CFrame.new(3.2, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-20)), Vector3.new(0.3, 3, 10), c, Enum.Material.Fabric)
	m.Parent = parent
end

-- Ouriço tcheco (barreira antitanque estática).
function PropKit.hedgehog(parent: Instance, cf: CFrame)
	local c = Color3.fromRGB(60, 62, 70)
	block(parent, cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Vector3.new(0.5, 4.5, 0.5), c, Enum.Material.Metal)
	block(parent, cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(-45), 0, math.rad(45)), Vector3.new(0.5, 4.5, 0.5), c, Enum.Material.Metal)
	block(parent, cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(-45)), Vector3.new(0.5, 4.5, 0.5), c, Enum.Material.Metal)
end

return PropKit
