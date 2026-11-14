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

return PropKit
