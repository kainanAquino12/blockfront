--[[
	WeaponModels
	Modelos das armas em blocos, fiéis à arte de referência do BLOCKFRONT
	(peças retas, cores sólidas: cinza-grafite com detalhes em bege, oliva,
	amarelo e laranja). Não depende de assets externos.

	O mesmo modelo é usado em dois lugares:
	  - Tool na mão do personagem (o que os outros jogadores veem)
	  - viewmodel em primeira pessoa (ViewmodelController), em escala menor

	Convenção: o Handle (invisível) fica na empunhadura, na origem.
	O cano aponta para -Z e o "para cima" da arma é +Y.
	Attachments criados no Handle:
	  Muzzle    ponta do cano (traçantes, clarão)
	  LeftHand  onde a mão esquerda segura (braços do viewmodel)
]]

local WeaponModels = {}

local C = {
	Black = Color3.fromRGB(22, 23, 27),
	Dark = Color3.fromRGB(40, 42, 48),
	Gray = Color3.fromRGB(70, 74, 84),
	Light = Color3.fromRGB(104, 110, 122),
	Tan = Color3.fromRGB(198, 172, 124),
	TanDark = Color3.fromRGB(160, 136, 94),
	Olive = Color3.fromRGB(98, 118, 62),
	OliveDark = Color3.fromRGB(78, 96, 48),
	Yellow = Color3.fromRGB(242, 192, 40),
	Orange = Color3.fromRGB(232, 92, 40),
	Brown = Color3.fromRGB(146, 86, 48),
	BrownDark = Color3.fromRGB(112, 64, 36),
	Green = Color3.fromRGB(112, 142, 72),
	GreenDark = Color3.fromRGB(84, 110, 52),
	Metal = Color3.fromRGB(128, 132, 140),
}

-- Peça: { tamanho, posição, cor, rotação em graus (opcional), material (opcional) }
type Piece = { any }

local function rail(pieces: { Piece }, y: number, z0: number, z1: number, step: number, width: number)
	local z = z0
	while z <= z1 + 1e-3 do
		table.insert(pieces, { Vector3.new(width, 0.06, 0.08), Vector3.new(0, y, z), C.Black })
		z += step
	end
end

local SPECS: { [string]: { pieces: { Piece }, muzzle: Vector3, leftHand: Vector3? } } = {}

-- RIFLE DE ASSALTO -----------------------------------------------------------
do
	local p: { Piece } = {
		{ Vector3.new(0.26, 0.72, 0.36), Vector3.new(0, -0.05, 0.05), C.Dark, Vector3.new(-18, 0, 0) }, -- empunhadura
		{ Vector3.new(0.34, 0.36, 1.3), Vector3.new(0, 0.42, -0.25), C.Gray }, -- receptor inferior
		{ Vector3.new(0.32, 0.3, 1.5), Vector3.new(0, 0.74, -0.2), C.Dark }, -- receptor superior
		{ Vector3.new(0.03, 0.12, 0.36), Vector3.new(0.17, 0.74, -0.1), C.Light }, -- janela de ejeção
		{ Vector3.new(0.14, 0.08, 0.2), Vector3.new(0, 0.86, 0.48), C.Black }, -- alavanca de manejo
		{ Vector3.new(0.18, 0.26, 0.2), Vector3.new(0, 1.02, 0.36), C.Black }, -- alça de mira
		{ Vector3.new(0.06, 0.08, 0.06), Vector3.new(0, 1.18, 0.36), C.Black }, -- entalhe
		{ Vector3.new(0.36, 0.38, 0.95), Vector3.new(0, 0.66, -1.4), C.Tan }, -- guarda-mão
		{ Vector3.new(0.38, 0.06, 0.16), Vector3.new(0, 0.66, -1.15), C.TanDark }, -- ventilação
		{ Vector3.new(0.38, 0.06, 0.16), Vector3.new(0, 0.66, -1.4), C.TanDark },
		{ Vector3.new(0.38, 0.06, 0.16), Vector3.new(0, 0.66, -1.65), C.TanDark },
		{ Vector3.new(0.12, 0.14, 0.14), Vector3.new(0, 0.9, -1.95), C.Black }, -- base da massa
		{ Vector3.new(0.06, 0.24, 0.06), Vector3.new(0, 1.05, -1.95), C.Black }, -- massa de mira
		{ Vector3.new(0.13, 0.13, 0.9), Vector3.new(0, 0.68, -2.3), C.Black }, -- cano
		{ Vector3.new(0.19, 0.19, 0.3), Vector3.new(0, 0.68, -2.85), C.Dark }, -- quebra-chamas
		{ Vector3.new(0.2, 0.04, 0.2), Vector3.new(0, 0.68, -2.85), C.Black }, -- fenda
		{ Vector3.new(0.3, 0.2, 0.46), Vector3.new(0, 0.24, -0.58), C.Gray }, -- poço do carregador
		{ Vector3.new(0.24, 0.45, 0.4), Vector3.new(0, 0.04, -0.6), C.Dark, Vector3.new(8, 0, 0) }, -- carregador
		{ Vector3.new(0.24, 0.4, 0.38), Vector3.new(0, -0.32, -0.68), C.Dark, Vector3.new(18, 0, 0) },
		{ Vector3.new(0.06, 0.06, 0.42), Vector3.new(0, 0.16, -0.18), C.Black }, -- guarda-mato
		{ Vector3.new(0.05, 0.16, 0.05), Vector3.new(0, 0.26, -0.12), C.Black }, -- gatilho
		{ Vector3.new(0.04, 0.08, 0.1), Vector3.new(0.18, 0.5, -0.02), C.Light }, -- seletor
		{ Vector3.new(0.18, 0.18, 0.6), Vector3.new(0, 0.66, 0.75), C.Black }, -- tubo da coronha
		{ Vector3.new(0.3, 0.42, 0.75), Vector3.new(0, 0.56, 1.15), C.Gray }, -- coronha
		{ Vector3.new(0.28, 0.1, 0.62), Vector3.new(0, 0.81, 1.15), C.Dark }, -- apoio de rosto
		{ Vector3.new(0.32, 0.62, 0.12), Vector3.new(0, 0.5, 1.56), C.Black }, -- soleira
	}
	rail(p, 0.92, -0.85, 0.2, 0.17, 0.24)
	SPECS.Rifle = { pieces = p, muzzle = Vector3.new(0, 0.68, -3.02), leftHand = Vector3.new(0, 0.48, -1.45) }
end

-- LANÇA-FOGUETES -------------------------------------------------------------
do
	local p: { Piece } = {
		{ Vector3.new(0.26, 0.65, 0.36), Vector3.new(0, -0.05, 0), C.Dark, Vector3.new(-12, 0, 0) }, -- empunhadura
		{ Vector3.new(0.3, 0.3, 0.62), Vector3.new(0, 0.38, -0.1), C.Dark }, -- caixa do gatilho
		{ Vector3.new(0.06, 0.06, 0.4), Vector3.new(0, 0.18, -0.2), C.Black }, -- guarda-mato
		{ Vector3.new(0.62, 0.62, 3.2), Vector3.new(0, 0.82, -0.3), C.Olive }, -- tubo
		{ Vector3.new(0.64, 0.1, 3.0), Vector3.new(0, 1.0, -0.3), C.OliveDark }, -- faixa superior
		{ Vector3.new(0.7, 0.7, 0.2), Vector3.new(0, 0.82, -1.8), C.Dark }, -- colar frontal
		{ Vector3.new(0.66, 0.66, 0.22), Vector3.new(0, 0.82, -1.45), C.Yellow }, -- faixa amarela
		{ Vector3.new(0.95, 0.95, 0.55), Vector3.new(0, 0.82, -2.15), C.Dark }, -- boca
		{ Vector3.new(0.72, 0.72, 0.06), Vector3.new(0, 0.82, -2.43), C.Black }, -- interior da boca
		{ Vector3.new(0.66, 0.66, 0.22), Vector3.new(0, 0.82, 1.0), C.Orange }, -- faixa laranja
		{ Vector3.new(0.7, 0.7, 0.15), Vector3.new(0, 0.82, 1.2), C.Dark },
		{ Vector3.new(0.88, 0.88, 0.42), Vector3.new(0, 0.82, 1.46), C.Dark }, -- saída traseira
		{ Vector3.new(0.62, 0.62, 0.06), Vector3.new(0, 0.82, 1.68), C.Black },
		{ Vector3.new(0.22, 0.14, 0.5), Vector3.new(0, 1.2, -0.55), C.Dark }, -- base da mira
		{ Vector3.new(0.2, 0.32, 0.36), Vector3.new(0, 1.42, -0.55), C.Black }, -- mira
		{ Vector3.new(0.14, 0.14, 0.04), Vector3.new(0, 1.45, -0.74), C.Light }, -- lente
		{ Vector3.new(0.06, 0.2, 0.06), Vector3.new(0, 1.66, -0.55), C.Black }, -- alça da mira
		{ Vector3.new(0.22, 0.55, 0.3), Vector3.new(0, 0.3, -1.0), C.Dark, Vector3.new(-8, 0, 0) }, -- empunhadura frontal
		{ Vector3.new(0.3, 0.16, 0.36), Vector3.new(0, 0.55, -1.0), C.Dark },
		{ Vector3.new(0.08, 0.12, 0.12), Vector3.new(0.34, 0.82, 0.55), C.Light }, -- presilha
		{ Vector3.new(0.08, 0.12, 0.12), Vector3.new(0.34, 0.82, -1.15), C.Light },
	}
	SPECS.RocketLauncher = { pieces = p, muzzle = Vector3.new(0, 0.82, -2.5), leftHand = Vector3.new(0, 0.25, -1.0) }
end

-- GRANADA --------------------------------------------------------------------
do
	local p: { Piece } = {
		{ Vector3.new(0.5, 0.62, 0.5), Vector3.new(0, 0, 0), C.Green }, -- corpo
		{ Vector3.new(0.58, 0.18, 0.42), Vector3.new(0, 0.12, 0), C.Green }, -- gomos
		{ Vector3.new(0.42, 0.18, 0.58), Vector3.new(0, 0.12, 0), C.Green },
		{ Vector3.new(0.58, 0.18, 0.42), Vector3.new(0, -0.14, 0), C.Green },
		{ Vector3.new(0.42, 0.18, 0.58), Vector3.new(0, -0.14, 0), C.Green },
		{ Vector3.new(0.6, 0.05, 0.6), Vector3.new(0, -0.01, 0), C.GreenDark }, -- sulco
		{ Vector3.new(0.6, 0.05, 0.6), Vector3.new(0, 0.24, 0), C.GreenDark },
		{ Vector3.new(0.6, 0.05, 0.6), Vector3.new(0, -0.26, 0), C.GreenDark },
		{ Vector3.new(0.34, 0.08, 0.34), Vector3.new(0, -0.34, 0), C.GreenDark }, -- base
		{ Vector3.new(0.28, 0.12, 0.28), Vector3.new(0, 0.37, 0), C.Metal }, -- pescoço
		{ Vector3.new(0.22, 0.16, 0.22), Vector3.new(0, 0.5, 0), C.Metal }, -- espoleta
		{ Vector3.new(0.08, 0.52, 0.14), Vector3.new(0.31, 0.26, 0), C.Metal, Vector3.new(0, 0, -10) }, -- alavanca
		{ Vector3.new(0.26, 0.06, 0.14), Vector3.new(0.18, 0.56, 0), C.Metal },
		{ Vector3.new(0.04, 0.22, 0.04), Vector3.new(-0.22, 0.6, 0.09), C.Light }, -- argola
		{ Vector3.new(0.04, 0.22, 0.04), Vector3.new(-0.22, 0.6, -0.09), C.Light },
		{ Vector3.new(0.04, 0.04, 0.22), Vector3.new(-0.22, 0.69, 0), C.Light },
		{ Vector3.new(0.04, 0.04, 0.22), Vector3.new(-0.22, 0.51, 0), C.Light },
	}
	SPECS.Grenade = { pieces = p, muzzle = Vector3.new(0, 0.6, 0), leftHand = nil }
end

-- MARRETA --------------------------------------------------------------------
do
	local p: { Piece } = {
		{ Vector3.new(0.22, 3.6, 0.22), Vector3.new(0, 1.5, 0), C.Brown }, -- cabo
		{ Vector3.new(0.23, 3.4, 0.06), Vector3.new(0, 1.55, 0.09), C.BrownDark }, -- veio da madeira
		{ Vector3.new(0.28, 0.85, 0.28), Vector3.new(0, -0.05, 0), C.Black }, -- empunhadura emborrachada
		{ Vector3.new(0.3, 0.06, 0.3), Vector3.new(0, 0.2, 0), C.Dark },
		{ Vector3.new(0.3, 0.06, 0.3), Vector3.new(0, -0.15, 0), C.Dark },
		{ Vector3.new(0.32, 0.14, 0.32), Vector3.new(0, -0.52, 0), C.Dark }, -- ponta
		{ Vector3.new(0.78, 0.78, 1.25), Vector3.new(0, 3.3, 0), C.Dark }, -- cabeça
		{ Vector3.new(0.86, 0.86, 0.14), Vector3.new(0, 3.3, -0.66), C.Gray }, -- face de impacto
		{ Vector3.new(0.86, 0.86, 0.14), Vector3.new(0, 3.3, 0.66), C.Gray },
		{ Vector3.new(0.82, 0.14, 0.5), Vector3.new(0, 3.3, 0), C.Gray }, -- cinta
		{ Vector3.new(0.3, 0.2, 0.3), Vector3.new(0, 2.84, 0), C.Gray }, -- colar
		{ Vector3.new(0.12, 0.06, 0.3), Vector3.new(0, 3.72, 0), C.Brown }, -- cunha
	}
	SPECS.Sledgehammer = { pieces = p, muzzle = Vector3.new(0, 3.3, -0.75), leftHand = Vector3.new(0, 1.15, 0) }
end

local function newPart(size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	return p
end

--[[
	Constrói uma arma.
	weld = true (padrão): peças soldadas ao Handle, para Tool/objeto físico.
	weld = false: sem solda (viewmodel move tudo com PivotTo).
	Retorna o Handle (peças como filhas) e o Attachment Muzzle.
]]
function WeaponModels.build(weaponId: string, weld: boolean?): (Part, Attachment)
	local spec = SPECS[weaponId]
	assert(spec, "WeaponModels: arma sem modelo: " .. weaponId)

	local handle = newPart(Vector3.new(0.2, 0.2, 0.2), C.Dark)
	handle.Name = "Handle"
	handle.Transparency = 1
	handle.CFrame = CFrame.new()

	for n, ps in spec.pieces do
		local p = newPart(ps[1], ps[3], ps[5])
		p.Name = "Piece" .. n
		local rot = ps[4] :: Vector3?
		p.CFrame = CFrame.new(ps[2])
			* (if rot then CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) else CFrame.identity)
		if weld ~= false then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
		p.Parent = handle
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.muzzle
	muzzle.Parent = handle

	if spec.leftHand then
		local lh = Instance.new("Attachment")
		lh.Name = "LeftHand"
		lh.Position = spec.leftHand
		lh.Parent = handle
	end

	return handle, muzzle
end

WeaponModels.Colors = C

return WeaponModels
