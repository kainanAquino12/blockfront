--[[
	WeaponConfig
	Fonte única das armas: estatísticas (o servidor valida e aplica dano com
	elas), comportamento (dispersão, recuo), apresentação em primeira pessoa
	e sons. Para trocar um som, troque só o ID aqui.

	Kind
	  Hitscan    raycast instantâneo (Pellets > 1 = escopeta)
	  Projectile foguete simulado no servidor
	  Throwable  granada física com pavio
	  Melee      golpe de curto alcance

	Dano
	  PlayerDamage       dano em jogadores (por chumbo na escopeta; no centro em explosões)
	  HeadshotMultiplier multiplicador na cabeça
	  StructureDamage    dano em células voxel (vida: vidro 5, madeira 30, tijolo 60, concreto 120, metal 300)
	  StructureRadius    raio do dano em estruturas no ponto de impacto

	Spread (graus): Hip sem mirar, Aim mirando, Move extra em movimento,
	  Bloom por disparo, BloomMax teto, BloomRecovery graus/s de volta.
	Recoil: Pitch (graus que a câmera sobe por tiro), Yaw (±graus aleatórios),
	  Kick (recuo visual da arma), Recovery (graus/s que a câmera volta sozinha).
	Viewmodel: Scale, Hip (pose sem mirar, espaço da câmera), AimDistance
	  (distância do olho até a alça de mira no ADS), AimFov, AimSensitivity,
	  EquipTime, Scope (luneta: tela preta com retículo no ADS).
	WalkMultiplier: velocidade de caminhada com a arma na mão.

	Sons: IDs públicos da Creator Store, todos verificados com
	ContentProvider:PreloadAsync no Studio (carregam e têm duração > 0).
	Fire, Reload, Equip, Cycle (bombeada/ferrolho após o tiro), Dry (sem munição).
]]

local rad = math.rad

local SND = {
	RifleFire = "rbxassetid://76727380063178",
	SmgFire = "rbxassetid://77130830495173",
	LmgFire = "rbxassetid://5246245227",
	SniperFire = "rbxassetid://98063753863205",
	ShotgunFire = "rbxassetid://132255180302885",
	PistolFire = "rbxassetid://90432171903658",
	RocketFire = "rbxassetid://87972247594387",
	RocketLoop = "rbxassetid://76270470644551",
	MagReload = "rbxassetid://117963160131194",
	MagIn = "rbxassetid://117994408780527",
	PistolReload = "rbxassetid://106978376532259",
	Bolt = "rbxassetid://131265718595511",
	Pump = "rbxassetid://113837896417526",
	ShotgunEquip = "rbxassetid://111520248018511",
	Dry = "rbxassetid://136577938825060",
	GrenadePin = "rbxassetid://9114659833",
	Swing = "rbxassetid://76909623649227",
}

local WeaponConfig = {}
WeaponConfig.Sounds = SND

WeaponConfig.Weapons = {
	Rifle = {
		Id = "Rifle",
		DisplayName = "Rifle de Assalto",
		Kind = "Hitscan",
		PlayerDamage = 22,
		HeadshotMultiplier = 1.6,
		Range = 450,
		FireInterval = 0.095,
		Automatic = true,
		MagSize = 30,
		ReserveAmmo = 150,
		ReloadTime = 2.1,
		StructureRadius = 0.9,
		StructureDamage = 40,
		Spread = { Hip = 1.4, Aim = 0.2, Move = 1.2, Bloom = 0.22, BloomMax = 2.4, BloomRecovery = 7 },
		Recoil = { Pitch = 0.5, Yaw = 0.22, Kick = 0.35, Recovery = 7 },
		WalkMultiplier = 1,
		Viewmodel = { Scale = 0.36, Hip = CFrame.new(0.4232, -0.45, -1) * CFrame.Angles(0, rad(3), rad(-2)), AimDistance = 0.95, AimFov = 62, AimSensitivity = 0.75, EquipTime = 0.4 },
		Sounds = { Fire = SND.RifleFire, Reload = SND.MagReload, Equip = SND.MagIn, Dry = SND.Dry },
	},
	SMG = {
		Id = "SMG",
		DisplayName = "Submetralhadora",
		Kind = "Hitscan",
		PlayerDamage = 15,
		HeadshotMultiplier = 1.5,
		Range = 220,
		FireInterval = 0.065,
		Automatic = true,
		MagSize = 32,
		ReserveAmmo = 192,
		ReloadTime = 1.8,
		StructureRadius = 0.8,
		StructureDamage = 25,
		Spread = { Hip = 1.9, Aim = 0.55, Move = 0.9, Bloom = 0.18, BloomMax = 3, BloomRecovery = 9 },
		Recoil = { Pitch = 0.32, Yaw = 0.32, Kick = 0.25, Recovery = 8 },
		WalkMultiplier = 1.06,
		Viewmodel = { Scale = 0.38, Hip = CFrame.new(0.4048, -0.432, -0.88) * CFrame.Angles(0, rad(3), rad(-2)), AimDistance = 0.85, AimFov = 66, AimSensitivity = 0.8, EquipTime = 0.3 },
		Sounds = { Fire = SND.SmgFire, Reload = SND.MagReload, Equip = SND.MagIn, Dry = SND.Dry },
	},
	LMG = {
		Id = "LMG",
		DisplayName = "Metralhadora",
		Kind = "Hitscan",
		PlayerDamage = 20,
		HeadshotMultiplier = 1.4,
		Range = 420,
		FireInterval = 0.08,
		Automatic = true,
		MagSize = 100,
		ReserveAmmo = 200,
		ReloadTime = 4.6,
		StructureRadius = 1.1,
		StructureDamage = 45,
		Spread = { Hip = 2.6, Aim = 0.6, Move = 2.0, Bloom = 0.12, BloomMax = 3, BloomRecovery = 5 },
		Recoil = { Pitch = 0.42, Yaw = 0.42, Kick = 0.4, Recovery = 6 },
		WalkMultiplier = 0.85,
		Viewmodel = { Scale = 0.32, Hip = CFrame.new(0.4416, -0.486, -1.04) * CFrame.Angles(0, rad(3), rad(-2)), AimDistance = 1.0, AimFov = 62, AimSensitivity = 0.7, EquipTime = 0.6 },
		Sounds = { Fire = SND.LmgFire, Reload = SND.MagReload, Equip = SND.MagIn, Dry = SND.Dry },
	},
	Sniper = {
		Id = "Sniper",
		DisplayName = "Sniper",
		Kind = "Hitscan",
		PlayerDamage = 95,
		HeadshotMultiplier = 2.2,
		Range = 900,
		FireInterval = 1.35,
		Automatic = false,
		MagSize = 5,
		ReserveAmmo = 25,
		ReloadTime = 3.0,
		StructureRadius = 1.2,
		StructureDamage = 120,
		Spread = { Hip = 5, Aim = 0, Move = 3, Bloom = 0, BloomMax = 0, BloomRecovery = 10 },
		Recoil = { Pitch = 3.2, Yaw = 0.6, Kick = 1.2, Recovery = 5 },
		WalkMultiplier = 0.92,
		Viewmodel = { Scale = 0.32, Hip = CFrame.new(0.4232, -0.468, -1) * CFrame.Angles(0, rad(3), rad(-2)), AimDistance = 0.6, AimFov = 18, AimSensitivity = 0.3, EquipTime = 0.55, Scope = true },
		Sounds = { Fire = SND.SniperFire, Reload = SND.MagReload, Equip = SND.Bolt, Cycle = SND.Bolt, Dry = SND.Dry },
	},
	Shotgun = {
		Id = "Shotgun",
		DisplayName = "Escopeta",
		Kind = "Hitscan",
		Pellets = 8,
		PelletSpread = 4.5, -- abertura do cone de chumbos (graus)
		PlayerDamage = 13,
		HeadshotMultiplier = 1.3,
		Range = 70,
		FireInterval = 0.9,
		Automatic = false,
		MagSize = 6,
		ReserveAmmo = 30,
		ReloadTime = 3.2,
		StructureRadius = 0.7,
		StructureDamage = 30,
		Spread = { Hip = 0.8, Aim = 0.3, Move = 0.6, Bloom = 0, BloomMax = 0, BloomRecovery = 10 },
		Recoil = { Pitch = 2.6, Yaw = 0.7, Kick = 1.0, Recovery = 6 },
		WalkMultiplier = 1,
		Viewmodel = { Scale = 0.36, Hip = CFrame.new(0.4232, -0.468, -0.96) * CFrame.Angles(0, rad(3), rad(-2)), AimDistance = 0.9, AimFov = 70, AimSensitivity = 0.85, EquipTime = 0.45 },
		Sounds = { Fire = SND.ShotgunFire, Reload = SND.Pump, Equip = SND.ShotgunEquip, Cycle = SND.Pump, Dry = SND.Dry },
	},
	Pistol = {
		Id = "Pistol",
		DisplayName = "Pistola",
		Kind = "Hitscan",
		PlayerDamage = 26,
		HeadshotMultiplier = 1.6,
		Range = 200,
		FireInterval = 0.16,
		Automatic = false,
		MagSize = 12,
		ReserveAmmo = 72,
		ReloadTime = 1.5,
		StructureRadius = 0.8,
		StructureDamage = 30,
		Spread = { Hip = 1.2, Aim = 0.3, Move = 0.8, Bloom = 0.4, BloomMax = 2.4, BloomRecovery = 8 },
		Recoil = { Pitch = 1.0, Yaw = 0.3, Kick = 0.5, Recovery = 8 },
		WalkMultiplier = 1.06,
		Viewmodel = { Scale = 0.42, Hip = CFrame.new(0.3128, -0.378, -0.84) * CFrame.Angles(0, rad(3), 0), AimDistance = 1.0, AimFov = 70, AimSensitivity = 0.85, EquipTime = 0.25 },
		Sounds = { Fire = SND.PistolFire, Reload = SND.PistolReload, Equip = SND.MagIn, Dry = SND.Dry },
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
		ReserveAmmo = 4,
		ReloadTime = 2.6,
		ExplosionRadius = 8,
		StructureDamage = 320,
		SelfDamageMultiplier = 0.5,
		Spread = { Hip = 0.6, Aim = 0, Move = 0.5, Bloom = 0, BloomMax = 0, BloomRecovery = 10 },
		Recoil = { Pitch = 4, Yaw = 1, Kick = 1.6, Recovery = 4 },
		WalkMultiplier = 0.9,
		Viewmodel = { Scale = 0.36, Hip = CFrame.new(0.4048, -0.468, -1.08) * CFrame.Angles(0, rad(4), rad(-2)), AimDistance = 0.7, AimFov = 60, AimSensitivity = 0.75, EquipTime = 0.7 },
		Sounds = { Fire = SND.RocketFire, Reload = SND.MagIn, Equip = SND.MagIn, Loop = SND.RocketLoop, Dry = SND.Dry },
	},
	Grenade = {
		Id = "Grenade",
		DisplayName = "Granada",
		Kind = "Throwable",
		PlayerDamage = 95,
		Range = 0,
		ThrowSpeed = 70,
		ThrowLift = 0.35,
		Fuse = 2.5,
		FireInterval = 1.0,
		Automatic = false,
		MagSize = 3,
		ReserveAmmo = 0,
		ExplosionRadius = 7,
		StructureDamage = 240,
		SelfDamageMultiplier = 0.5,
		Spread = { Hip = 0, Aim = 0, Move = 0, Bloom = 0, BloomMax = 0, BloomRecovery = 10 },
		Recoil = { Pitch = 0, Yaw = 0, Kick = 0, Recovery = 10 },
		WalkMultiplier = 1.05,
		Viewmodel = { Scale = 0.34, Hip = CFrame.new(0.4048, -0.432, -0.88) * CFrame.Angles(rad(10), rad(-15), 0), EquipTime = 0.3 },
		Sounds = { Fire = SND.Swing, Equip = SND.GrenadePin },
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
		Spread = { Hip = 0, Aim = 0, Move = 0, Bloom = 0, BloomMax = 0, BloomRecovery = 10 },
		Recoil = { Pitch = 0, Yaw = 0, Kick = 0, Recovery = 10 },
		WalkMultiplier = 1.08,
		Viewmodel = { Scale = 0.34, Hip = CFrame.new(0.5704, -0.765, -0.88) * CFrame.Angles(rad(-50), rad(-10), rad(25)), EquipTime = 0.35 },
		Sounds = { Fire = SND.Swing, Equip = SND.Swing },
	},
}

-- Equipamento: escolha de arma principal + secundária, foguete, granada e marreta.
WeaponConfig.Primaries = { "Rifle", "SMG", "LMG", "Sniper", "Shotgun" }
WeaponConfig.DefaultPrimary = "Rifle"
WeaponConfig.FixedSlots = { "Pistol", "RocketLauncher", "Grenade", "Sledgehammer" } -- teclas 2 a 5

-- Dano de explosão na borda, como fração do dano central.
WeaponConfig.ExplosionFalloffMin = 0.2

-- Validação no servidor.
WeaponConfig.Validation = {
	MaxOriginOffset = 10, -- distância máxima entre a origem do disparo e a cabeça
	FireIntervalTolerance = 0.8, -- aceita disparos até 20% mais rápidos (latência)
	ClaimMaxRayDistance = 4, -- "favor do atirador": distância máx. do alvo à linha do tiro
}

return WeaponConfig
