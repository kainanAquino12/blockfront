--[[
	WeaponConfig
	Estatísticas das armas. O servidor usa estes valores para validar e
	aplicar dano; o cliente usa para cadência, munição prevista e efeitos.

	Kind:
	  Hitscan    disparo instantâneo por raycast (rifle)
	  Projectile projétil simulado no servidor (lança-foguetes)
	  Throwable  objeto físico com pavio (granada)
	  Melee      golpe de curto alcance (marreta)

	PlayerDamage      dano em jogadores (no centro, para explosões)
	StructureDamage   dano em células voxel (vida: madeira 30, tijolo 60, concreto 120, metal 300)
	StructureRadius   raio (studs) do dano em estruturas no ponto de impacto
	ExplosionRadius   raio (studs) de explosões (jogadores e estruturas)
	FireInterval      segundos entre disparos/golpes
	MagSize / ReserveAmmo / ReloadTime  munição (Throwable: MagSize = quantidade carregada)

	Sons: assets públicos e gratuitos da Creator Store (IDs verificados no Studio)
	ou sons embutidos do Roblox (rbxasset://).
]]

local WeaponConfig = {}

WeaponConfig.Weapons = {
	Rifle = {
		Id = "Rifle",
		DisplayName = "Rifle",
		Kind = "Hitscan",
		PlayerDamage = 20,
		HeadshotMultiplier = 1.6,
		Range = 400,
		FireInterval = 0.1,
		Automatic = true,
		SpreadDegrees = 1.2,
		MagSize = 30,
		ReserveAmmo = 150,
		ReloadTime = 2.0,
		StructureRadius = 0.9,
		StructureDamage = 40,
		Sounds = {
			Fire = "rbxassetid://76727380063178",
			Reload = "rbxassetid://117963160131194",
		},
	},
	RocketLauncher = {
		Id = "RocketLauncher",
		DisplayName = "Lança-foguetes",
		Kind = "Projectile",
		PlayerDamage = 110,
		Range = 600,
		ProjectileSpeed = 140,
		FireInterval = 1.0,
		Automatic = false,
		MagSize = 1,
		ReserveAmmo = 5,
		ReloadTime = 2.5,
		ExplosionRadius = 8,
		StructureDamage = 320,
		SelfDamageMultiplier = 0.5,
		Sounds = {
			Fire = "rbxassetid://87972247594387",
			Reload = "rbxassetid://117963160131194",
		},
	},
	Grenade = {
		Id = "Grenade",
		DisplayName = "Granada",
		Kind = "Throwable",
		PlayerDamage = 95,
		Range = 0,
		ThrowSpeed = 70,
		ThrowLift = 0.35, -- componente vertical extra (arco)
		Fuse = 2.5,
		FireInterval = 1.0,
		Automatic = false,
		MagSize = 3,
		ReserveAmmo = 0,
		ExplosionRadius = 7,
		StructureDamage = 240,
		SelfDamageMultiplier = 0.5,
		Sounds = {
			Fire = "rbxassetid://76909623649227",
		},
	},
	Sledgehammer = {
		Id = "Sledgehammer",
		DisplayName = "Marreta",
		Kind = "Melee",
		PlayerDamage = 55,
		Range = 8,
		FireInterval = 0.75,
		Automatic = false,
		StructureRadius = 2.4,
		StructureDamage = 220,
		Sounds = {
			Fire = "rbxassetid://76909623649227",
		},
	},
}

--[[
	Viewmodel em primeira pessoa (espaço da câmera: X direita, Y cima, -Z frente).
	Scale  escala do modelo na tela
	Hip    posição da empunhadura sem mirar
	Aim    posição mirando (botão direito); nil = arma sem mira
	AimFov campo de visão ao mirar
]]
local rad = math.rad
WeaponConfig.Viewmodel = {
	Rifle = {
		Scale = 0.4,
		Hip = CFrame.new(0.44, -0.5, -1.6) * CFrame.Angles(0, rad(14), rad(-4)),
		Aim = CFrame.new(0, -0.49, -1.3),
		AimFov = 55,
	},
	RocketLauncher = {
		Scale = 0.42,
		Hip = CFrame.new(0.5, -0.55, -1.35) * CFrame.Angles(0, rad(12), rad(-3)),
		Aim = CFrame.new(0, -0.68, -0.8),
		AimFov = 55,
	},
	Grenade = {
		Scale = 0.38,
		Hip = CFrame.new(0.5, -0.5, -1.3) * CFrame.Angles(rad(10), rad(-15), 0),
	},
	Sledgehammer = {
		Scale = 0.4,
		Hip = CFrame.new(0.75, -0.95, -1.1) * CFrame.Angles(rad(-50), rad(-10), rad(25)),
	},
}

-- Ordem no inventário (teclas 1-4).
WeaponConfig.Loadout = { "Rifle", "RocketLauncher", "Grenade", "Sledgehammer" }

WeaponConfig.ExplosionSound = "rbxasset://sounds/impact_explosion_03.mp3"

-- Dano de explosão na borda, como fração do dano central.
WeaponConfig.ExplosionFalloffMin = 0.2

-- Validação no servidor.
WeaponConfig.Validation = {
	MaxOriginOffset = 10, -- distância máxima entre a origem do disparo e a cabeça
	FireIntervalTolerance = 0.8, -- aceita disparos até 20% mais rápidos (latência)
	ClaimMaxRayDistance = 4, -- "favor do atirador": distância máx. do alvo à linha do tiro
}

return WeaponConfig
