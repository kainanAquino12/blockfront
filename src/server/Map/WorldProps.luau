--[[
	WorldProps (servidor) — objetos estáticos do mundo (V7).

	Tudo ancorado, sem física, poucas Parts por objeto, cores sóbrias.
	Destrutíveis (muros, barreiras, portões, cercas de concreto) NÃO ficam
	aqui: usam StructureKit/BuildingKit via ctx.struct.

	  Urbanos     streetLamp, trafficLight, roadSign, powerPole + wire, manhole
	  Industriais generator, pipeRack, containerStack
	  Militares   wreckTank, wreckTruck
	  Ambiente    tree, bush, rock
	Cada função recebe a pasta de destino e um CFrame (já no referencial do
	lado: use ctx.cf para espelhar no lado vermelho).
]]

local WorldProps = {}

local C = {
	Steel = Color3.fromRGB(70, 74, 78),
	SteelLight = Color3.fromRGB(104, 108, 110),
	Concrete = Color3.fromRGB(118, 118, 114),
	Wood = Color3.fromRGB(92, 72, 54),
	Trunk = Color3.fromRGB(78, 64, 50),
	Leaf1 = Color3.fromRGB(70, 84, 56),
	Leaf2 = Color3.fromRGB(82, 92, 62),
	Leaf3 = Color3.fromRGB(62, 74, 50),
	Rock = Color3.fromRGB(104, 102, 98),
	Olive = Color3.fromRGB(70, 74, 56),
	Burnt = Color3.fromRGB(44, 42, 40),
	Rust = Color3.fromRGB(96, 70, 54),
	Sign = Color3.fromRGB(138, 136, 128),
	Signal = Color3.fromRGB(150, 120, 60),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Cilindro vertical (o eixo do Cylinder é X; gira para ficar em pé).
local function vcyl(parent, name, height, diameter, cf, color, material)
	return part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

---------------------------------------------------------------------------
-- Urbanos
---------------------------------------------------------------------------

function WorldProps.streetLamp(parent: Instance, cf: CFrame)
	local m = model(parent, "PosteIluminacao")
	vcyl(m, "Haste", 12, 0.5, cf, C.Steel, Enum.Material.Metal)
	part(m, "Braco", Vector3.new(0.35, 0.35, 3.2), cf * CFrame.new(0, 11.8, -1.5), C.Steel, Enum.Material.Metal)
	part(m, "Luminaria", Vector3.new(0.9, 0.35, 1.6), cf * CFrame.new(0, 11.6, -3), C.SteelLight, Enum.Material.Metal)
	return m
end

function WorldProps.trafficLight(parent: Instance, cf: CFrame)
	local m = model(parent, "Semaforo")
	vcyl(m, "Haste", 9, 0.45, cf, C.Steel, Enum.Material.Metal)
	part(m, "Braco", Vector3.new(0.3, 0.3, 5), cf * CFrame.new(0, 8.8, -2.5), C.Steel, Enum.Material.Metal)
	local box = part(m, "Caixa", Vector3.new(0.9, 2.6, 0.8), cf * CFrame.new(0, 7.8, -4.6), Color3.fromRGB(34, 36, 38), Enum.Material.Metal)
	for k, col in { Color3.fromRGB(110, 40, 36), Color3.fromRGB(120, 96, 40), Color3.fromRGB(46, 90, 60) } do
		part(m, "Luz" .. k, Vector3.new(0.5, 0.5, 0.1), box.CFrame * CFrame.new(0, 0.85 - (k - 1) * 0.85, -0.42), col, Enum.Material.SmoothPlastic)
	end
	return m
end

function WorldProps.roadSign(parent: Instance, cf: CFrame, wide: boolean?)
	local m = model(parent, "Placa")
	vcyl(m, "Haste", 6, 0.25, cf, C.SteelLight, Enum.Material.Metal)
	local size = if wide then Vector3.new(3.2, 1.6, 0.12) else Vector3.new(1.6, 1.6, 0.12)
	part(m, "Chapa", size, cf * CFrame.new(0, 5.4, -0.15), C.Sign, Enum.Material.Metal)
	part(m, "Faixa", Vector3.new(size.X * 0.8, 0.25, 0.14), cf * CFrame.new(0, 5.4, -0.16), C.Signal, Enum.Material.SmoothPlastic)
	return m
end

function WorldProps.powerPole(parent: Instance, cf: CFrame): Vector3
	local m = model(parent, "PosteEletrico")
	vcyl(m, "Poste", 14, 0.7, cf, C.Wood, Enum.Material.Wood)
	part(m, "Cruzeta", Vector3.new(4, 0.3, 0.3), cf * CFrame.new(0, 13, 0), C.Wood, Enum.Material.Wood)
	part(m, "Transformador", Vector3.new(0.9, 1.4, 0.9), cf * CFrame.new(0, 10.5, 0.6), C.Steel, Enum.Material.Metal)
	return (cf * CFrame.new(0, 13.1, 0)).Position
end

-- Fio entre dois pontos (com leve barriga).
function WorldProps.wire(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2 - Vector3.new(0, 0.8, 0)
	for _, seg in { { a, mid }, { mid, b } } do
		local len = (seg[2] - seg[1]).Magnitude
		local p = part(parent, "Fio", Vector3.new(0.08, 0.08, len), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), Color3.fromRGB(28, 28, 28), Enum.Material.SmoothPlastic)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
end

function WorldProps.manhole(parent: Instance, cf: CFrame)
	local p = part(parent, "Bueiro", Vector3.new(0.12, 2.4, 2.4), cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 42), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	p.CanCollide = false
	return p
end

---------------------------------------------------------------------------
-- Industriais
---------------------------------------------------------------------------

function WorldProps.generator(parent: Instance, cf: CFrame)
	local m = model(parent, "Gerador")
	part(m, "Base", Vector3.new(4, 0.5, 7), cf * CFrame.new(0, 0.25, 0), C.Steel, Enum.Material.Metal)
	part(m, "Corpo", Vector3.new(3.4, 3, 6), cf * CFrame.new(0, 2, 0), Color3.fromRGB(84, 92, 74), Enum.Material.Metal)
	part(m, "Radiador", Vector3.new(3.2, 2.6, 0.4), cf * CFrame.new(0, 1.9, -3.1), C.Steel, Enum.Material.DiamondPlate)
	vcyl(m, "Escape", 2, 0.4, cf * CFrame.new(1, 3.5, 2), C.Burnt, Enum.Material.Metal)
	return m
end

-- Pórtico de tubulação entre dois pontos no chão (altura h).
function WorldProps.pipeRack(parent: Instance, a: Vector3, b: Vector3, h: number)
	local m = model(parent, "PorticoTubulacao")
	local dir = (b - a)
	local len = dir.Magnitude
	local cf = CFrame.lookAt(a, b)
	local n = math.max(2, math.floor(len / 10) + 1)
	for i = 0, n - 1 do
		local p = cf * CFrame.new(0, 0, -len * i / (n - 1))
		for _, s in { -1.5, 1.5 } do
			part(m, "Coluna", Vector3.new(0.5, h, 0.5), p * CFrame.new(s, h / 2, 0), C.Steel, Enum.Material.Metal)
		end
		part(m, "Travessa", Vector3.new(3.6, 0.4, 0.5), p * CFrame.new(0, h, 0), C.Steel, Enum.Material.Metal)
	end
	for k, s in { -0.8, 0.8 } do
		part(m, "Tubo" .. k, Vector3.new(len, 0.9, 0.9), cf * CFrame.new(s, h + 0.65, -len / 2) * CFrame.Angles(0, math.rad(90), 0), if k == 1 then C.Rust else C.SteelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	return m
end

local CONTAINER_COLORS = {
	Color3.fromRGB(96, 70, 54),
	Color3.fromRGB(70, 82, 70),
	Color3.fromRGB(84, 88, 96),
	Color3.fromRGB(112, 96, 70),
}
function WorldProps.containerStack(parent: Instance, cf: CFrame, layers: number, seed: number)
	local m = model(parent, "PilhaConteineres")
	local rng = Random.new(seed)
	for i = 0, layers - 1 do
		local c = CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)]
		local off = CFrame.new(rng:NextNumber(-0.4, 0.4), 4.1 * i + 2.05, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0)
		local body = part(m, "Conteiner", Vector3.new(8, 4, 20), cf * off, c, Enum.Material.CorrodedMetal)
		part(m, "Porta", Vector3.new(7.6, 3.6, 0.2), body.CFrame * CFrame.new(0, 0, 10), c:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.DiamondPlate)
	end
	return m
end

---------------------------------------------------------------------------
-- Militares (destroços)
---------------------------------------------------------------------------

function WorldProps.wreckTank(parent: Instance, cf: CFrame)
	local m = model(parent, "TanqueDestruido")
	local tilt = cf * CFrame.Angles(math.rad(3), 0, math.rad(-4))
	part(m, "Casco", Vector3.new(7, 2.4, 12), tilt * CFrame.new(0, 2, 0), C.Olive:Lerp(C.Burnt, 0.45), Enum.Material.CorrodedMetal)
	part(m, "Glacis", Vector3.new(7, 1.2, 2.5), tilt * CFrame.new(0, 2.6, -6.3) * CFrame.Angles(math.rad(-25), 0, 0), C.Olive:Lerp(C.Burnt, 0.5), Enum.Material.CorrodedMetal)
	for _, s in { -3.9, 3.9 } do
		part(m, "Esteira", Vector3.new(1.4, 2, 12.6), tilt * CFrame.new(s, 1.1, 0), C.Burnt, Enum.Material.DiamondPlate)
	end
	-- torre deslocada pela explosão e cano caído
	local tur = tilt * CFrame.new(0.8, 4.1, 1) * CFrame.Angles(math.rad(-6), math.rad(28), math.rad(5))
	part(m, "Torre", Vector3.new(4.6, 1.8, 5), tur, C.Olive:Lerp(C.Burnt, 0.55), Enum.Material.CorrodedMetal)
	part(m, "Cano", Vector3.new(0.55, 0.55, 7), tur * CFrame.new(0, -0.3, -5.4) * CFrame.Angles(math.rad(-9), 0, 0), C.Burnt, Enum.Material.Metal)
	return m
end

function WorldProps.wreckTruck(parent: Instance, cf: CFrame)
	local m = model(parent, "CaminhaoDestruido")
	local tilt = cf * CFrame.Angles(0, 0, math.rad(6))
	part(m, "Chassi", Vector3.new(4.4, 0.8, 13), tilt * CFrame.new(0, 1.6, 0), C.Burnt, Enum.Material.Metal)
	part(m, "Cabine", Vector3.new(4.4, 3.4, 3.6), tilt * CFrame.new(0, 3.6, -4.6), C.Olive:Lerp(C.Burnt, 0.6), Enum.Material.CorrodedMetal)
	part(m, "Carroceria", Vector3.new(4.4, 2, 8), tilt * CFrame.new(0, 3, 2.2) * CFrame.Angles(math.rad(4), 0, 0), C.Olive:Lerp(C.Burnt, 0.4), Enum.Material.CorrodedMetal)
	for _, z in { -4.4, 1, 4.4 } do
		for _, s in { -2.4, 2.4 } do
			part(m, "Roda", Vector3.new(0.9, 2, 2), tilt * CFrame.new(s, 1.1, z), C.Burnt, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	return m
end

---------------------------------------------------------------------------
-- Ambiente
---------------------------------------------------------------------------

-- Árvore proporcional (~10 a 13 studs): tronco + copa irregular de 5 blocos.
function WorldProps.tree(parent: Instance, cf: CFrame, seed: number)
	local rng = Random.new(seed)
	local m = model(parent, "Arvore")
	local h = rng:NextNumber(5.5, 7.5)
	part(m, "Tronco", Vector3.new(1, h, 1), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.06, 0.06)), C.Trunk, Enum.Material.Wood)
	local leaves = { C.Leaf1, C.Leaf2, C.Leaf3 }
	for i = 1, 5 do
		local s = rng:NextNumber(2.4, 4.2)
		local off = CFrame.new(rng:NextNumber(-1.8, 1.8), h + rng:NextNumber(-0.5, 3), rng:NextNumber(-1.8, 1.8))
		part(m, "Copa" .. i, Vector3.new(s, s * rng:NextNumber(0.6, 0.9), s), cf * off * CFrame.Angles(0, rng:NextNumber(0, 6), 0), leaves[rng:NextInteger(1, 3)], Enum.Material.LeafyGrass)
	end
	return m
end

function WorldProps.bush(parent: Instance, cf: CFrame, seed: number)
	local rng = Random.new(seed)
	local m = model(parent, "Arbusto")
	for i = 1, 3 do
		local s = rng:NextNumber(1.2, 2.2)
		local p = part(m, "Folhas" .. i, Vector3.new(s, s * 0.7, s), cf * CFrame.new(rng:NextNumber(-1, 1), s * 0.3, rng:NextNumber(-1, 1)), if i == 2 then C.Leaf3 else C.Leaf2, Enum.Material.LeafyGrass)
		p.CanCollide = false
	end
	return m
end

function WorldProps.rock(parent: Instance, cf: CFrame, scale: number, seed: number)
	local rng = Random.new(seed)
	local m = model(parent, "Rocha")
	for i = 1, 3 do
		local s = scale * rng:NextNumber(0.6, 1.2)
		part(m, "Pedra" .. i, Vector3.new(s * 1.3, s * 0.8, s), cf * CFrame.new(rng:NextNumber(-1, 1) * scale * 0.6, s * 0.25, rng:NextNumber(-1, 1) * scale * 0.6)
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), C.Rock:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)), Enum.Material.Slate)
	end
	return m
end

---------------------------------------------------------------------------
-- Ferrovia (V10)
---------------------------------------------------------------------------

-- Trilho ao longo de z (lastro de brita + 2 trilhos + dormentes a cada 6).
function WorldProps.railTrack(parent: Instance, x: number, y: number, z0: number, z1: number)
	local m = model(parent, "Trilho")
	local len = z1 - z0
	local cz = (z0 + z1) / 2
	part(m, "Lastro", Vector3.new(6, 0.5, len), CFrame.new(x, y + 0.25, cz), Color3.fromRGB(92, 88, 82), Enum.Material.Slate)
	for z = z0 + 2, z1 - 2, 6 do
		part(m, "Dormente", Vector3.new(5, 0.3, 0.8), CFrame.new(x, y + 0.6, z), Color3.fromRGB(78, 62, 48), Enum.Material.Wood)
	end
	for _, s in { -1.45, 1.45 } do
		part(m, "Trilho", Vector3.new(0.3, 0.35, len), CFrame.new(x + s, y + 0.92, cz), Color3.fromRGB(96, 92, 88), Enum.Material.Metal)
	end
	return m
end

-- Vagão de carga (fechado ou plataforma com carga), cor desbotada.
function WorldProps.wagon(parent: Instance, cf: CFrame, kind: string, seed: number)
	local rng = Random.new(seed)
	local m = model(parent, "Vagao")
	local colors = { Color3.fromRGB(104, 62, 48), Color3.fromRGB(76, 84, 70), Color3.fromRGB(90, 92, 96) }
	local c = colors[rng:NextInteger(1, #colors)]
	part(m, "Chassi", Vector3.new(3.6, 0.6, 22), cf * CFrame.new(0, 1.9, 0), C.Burnt, Enum.Material.Metal)
	for _, z in { -7.5, 7.5 } do
		part(m, "Truque", Vector3.new(3, 1.1, 3.6), cf * CFrame.new(0, 1.1, z), C.Burnt, Enum.Material.DiamondPlate)
	end
	if kind == "Box" then
		part(m, "Caixa", Vector3.new(4.2, 4.6, 21), cf * CFrame.new(0, 4.5, 0), c, Enum.Material.CorrodedMetal)
		part(m, "Teto", Vector3.new(4.4, 0.3, 21.4), cf * CFrame.new(0, 6.9, 0), c:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal)
		part(m, "Porta", Vector3.new(0.15, 3.8, 5), cf * CFrame.new(2.15, 4.3, 0), c:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.DiamondPlate)
	else
		part(m, "Prancha", Vector3.new(4.2, 0.4, 21), cf * CFrame.new(0, 2.4, 0), C.Wood, Enum.Material.WoodPlanks)
		-- carga: caixas militares amarradas
		for _, z in { -6, 0, 6 } do
			part(m, "Carga", Vector3.new(3.6, 2.2, 4.4), cf * CFrame.new(0, 3.7, z), C.Olive, Enum.Material.Fabric)
		end
	end
	return m
end

-- Fogo + fumaça (prédios atingidos). Sem luz forte, só o efeito.
function WorldProps.fire(parent: Instance, pos: Vector3, size: number)
	local p = part(parent, "Incendio", Vector3.new(2, 0.2, 2), CFrame.new(pos), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = 9
	f.Color = Color3.fromRGB(236, 120, 50)
	f.SecondaryColor = Color3.fromRGB(150, 40, 20)
	f.Parent = p
	local s = Instance.new("Smoke")
	s.Color = Color3.fromRGB(46, 44, 42)
	s.Opacity = 0.35
	s.RiseVelocity = 10
	s.Size = 14
	s.Parent = p
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 140, 60)
	l.Range = 18
	l.Brightness = 1.2
	l.Parent = p
	return p
end

-- Pasta de categoria dentro do cenário estático (UrbanInfrastructure, ...).
function WorldProps.folder(static: Instance, name: string): Instance
	local f = static:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = static
	end
	return f
end

return WorldProps
