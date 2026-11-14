--[[
	WeaponModels
	Monta os modelos das armas em blocos, no estilo da arte de referência
	(peças retas, cores sólidas, cinza escuro + detalhes em bege, oliva,
	amarelo e laranja). Não depende de assets externos.

	Convenção: o Handle é a empunhadura, na origem. O cano aponta para -Z
	e o "para cima" da arma é +Y (orientação padrão de Tool do Roblox).
	Cada arma tem um Attachment "Muzzle" na ponta do cano.
]]

local WeaponModels = {}

local C = {
	Dark = Color3.fromRGB(38, 40, 46),
	Gray = Color3.fromRGB(72, 76, 86),
	Tan = Color3.fromRGB(198, 172, 124),
	Olive = Color3.fromRGB(98, 118, 62),
	Yellow = Color3.fromRGB(242, 192, 40),
	Orange = Color3.fromRGB(232, 92, 40),
	Brown = Color3.fromRGB(146, 86, 48),
	Green = Color3.fromRGB(112, 142, 72),
	Metal = Color3.fromRGB(118, 122, 130),
}

-- Peças de cada arma: { tamanho, posição relativa ao Handle, cor }
local SPECS: { [string]: { handle: { any }, parts: { { any } }, muzzle: Vector3 } } = {
	Rifle = {
		handle = { Vector3.new(0.28, 0.75, 0.4), C.Dark },
		parts = {
			{ Vector3.new(0.36, 0.42, 1.5), Vector3.new(0, 0.5, -0.15), C.Gray }, -- corpo
			{ Vector3.new(0.3, 0.12, 1.5), Vector3.new(0, 0.77, -0.15), C.Dark }, -- trilho
			{ Vector3.new(0.34, 0.34, 0.7), Vector3.new(0, 0.5, -1.25), C.Tan }, -- guarda-mão
			{ Vector3.new(0.14, 0.14, 1.0), Vector3.new(0, 0.55, -2.1), C.Dark }, -- cano
			{ Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 0.55, -2.65), C.Dark }, -- quebra-chamas
			{ Vector3.new(0.08, 0.3, 0.1), Vector3.new(0, 0.8, -1.45), C.Dark }, -- massa de mira
			{ Vector3.new(0.16, 0.22, 0.22), Vector3.new(0, 0.92, 0.35), C.Dark }, -- alça de mira
			{ Vector3.new(0.24, 0.7, 0.36), Vector3.new(0, -0.05, -0.55), C.Dark }, -- carregador
			{ Vector3.new(0.3, 0.5, 0.9), Vector3.new(0, 0.4, 1.05), C.Gray }, -- coronha
			{ Vector3.new(0.32, 0.7, 0.14), Vector3.new(0, 0.33, 1.52), C.Dark }, -- soleira
		},
		muzzle = Vector3.new(0, 0.55, -2.8),
	},
	RocketLauncher = {
		handle = { Vector3.new(0.26, 0.7, 0.36), C.Dark },
		parts = {
			{ Vector3.new(0.55, 0.55, 3.4), Vector3.new(0, 0.65, -0.4), C.Olive }, -- tubo
			{ Vector3.new(0.85, 0.85, 0.5), Vector3.new(0, 0.65, -2.3), C.Dark }, -- boca
			{ Vector3.new(0.6, 0.6, 0.18), Vector3.new(0, 0.65, -1.75), C.Yellow }, -- faixa amarela
			{ Vector3.new(0.75, 0.75, 0.45), Vector3.new(0, 0.65, 1.45), C.Dark }, -- traseira
			{ Vector3.new(0.6, 0.6, 0.18), Vector3.new(0, 0.65, 1.1), C.Orange }, -- faixa laranja
			{ Vector3.new(0.16, 0.32, 0.3), Vector3.new(0, 1.05, -0.6), C.Dark }, -- mira
			{ Vector3.new(0.22, 0.5, 0.3), Vector3.new(0, 0.2, -0.9), C.Dark }, -- empunhadura frontal
		},
		muzzle = Vector3.new(0, 0.65, -2.6),
	},
	Grenade = {
		handle = { Vector3.new(0.55, 0.7, 0.55), C.Green },
		parts = {
			{ Vector3.new(0.6, 0.4, 0.6), Vector3.new(0, 0, 0), C.Green }, -- gomos
			{ Vector3.new(0.3, 0.22, 0.3), Vector3.new(0, 0.46, 0), C.Metal }, -- espoleta
			{ Vector3.new(0.1, 0.55, 0.14), Vector3.new(0.3, 0.25, 0), C.Metal }, -- alavanca
			{ Vector3.new(0.06, 0.22, 0.22), Vector3.new(-0.2, 0.55, 0), C.Metal }, -- argola
		},
		muzzle = Vector3.new(0, 0.6, 0),
	},
	Sledgehammer = {
		handle = { Vector3.new(0.26, 0.6, 0.26), C.Brown },
		parts = {
			{ Vector3.new(0.22, 3.0, 0.22), Vector3.new(0, 1.8, 0), C.Brown }, -- cabo
			{ Vector3.new(0.3, 0.2, 0.3), Vector3.new(0, -0.38, 0), C.Brown }, -- ponta do cabo
			{ Vector3.new(0.75, 0.75, 1.5), Vector3.new(0, 3.4, 0), C.Dark }, -- cabeça
			{ Vector3.new(0.8, 0.5, 0.2), Vector3.new(0, 3.4, -0.72), C.Gray }, -- face de impacto
			{ Vector3.new(0.12, 0.3, 0.3), Vector3.new(0.42, 3.4, 0.3), C.Brown }, -- cunha
		},
		muzzle = Vector3.new(0, 3.4, -0.85),
	},
}

local function newPart(size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
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
	Constrói as peças de uma arma.
	Retorna o Handle (com as outras peças soldadas como filhas) e o Attachment Muzzle.
	O Handle fica na origem do mundo; quem chama posiciona/parenteia.
]]
function WeaponModels.build(weaponId: string): (Part, Attachment)
	local spec = SPECS[weaponId]
	assert(spec, "WeaponModels: arma sem modelo: " .. weaponId)

	local handle = newPart(spec.handle[1], spec.handle[2])
	handle.Name = "Handle"
	handle.CFrame = CFrame.new()

	for n, ps in spec.parts do
		local p = newPart(ps[1], ps[3])
		p.Name = "Piece" .. n
		p.CFrame = CFrame.new(ps[2])
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = handle
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.muzzle
	muzzle.Parent = handle

	return handle, muzzle
end

WeaponModels.Colors = C

return WeaponModels
