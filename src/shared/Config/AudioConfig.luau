--[[
	AudioConfig
	Sons de impacto, explosão e interface, e limites do áudio espacial.
	IDs verificados no Studio (ContentProvider:PreloadAsync, duração > 0).
	Sons de armas ficam em WeaponConfig.
]]

local AudioConfig = {}

-- Impacto de tiro por classe de material (vários IDs = variação aleatória).
AudioConfig.Impacts = {
	Concrete = { "rbxassetid://85805517776968", "rbxassetid://91269662967532" },
	Wood = { "rbxassetid://79898560742269", "rbxassetid://85069950880846" },
	Metal = { "rbxassetid://91399888182379" },
	Glass = { "rbxassetid://9114592102" },
	Dirt = { "rbxassetid://85805517776968" }, -- concreto mais grave (PlaybackSpeed menor)
	Body = { "rbxassetid://126486484494024" },
}

-- Golpe da marreta conforme o material atingido.
AudioConfig.MeleeImpacts = {
	Wood = "rbxassetid://9120801590",
	Metal = "rbxassetid://9120270688",
	Concrete = "rbxassetid://85805517776968",
	Glass = "rbxassetid://9114592102",
	Dirt = "rbxassetid://85805517776968",
	Body = "rbxassetid://126486484494024",
}

AudioConfig.Explosion = {
	Near = "rbxasset://sounds/impact_explosion_03.mp3", -- som embutido do Roblox
	Debris = "rbxassetid://132447255186419", -- detritos caindo logo depois
	Distant = "rbxassetid://117080687873544", -- versão abafada para longe
	DistantFrom = 180, -- studs: acima disso usa a versão distante
}

AudioConfig.UI = {
	Hitmarker = "rbxassetid://138148057831879",
}

-- Limites para não empilhar sons (por categoria).
AudioConfig.Categories = {
	Shot = { MaxActive = 24, MaxDistance = 600, RollOffMin = 12 },
	Impact = { MaxActive = 14, MaxDistance = 140, RollOffMin = 6 },
	Explosion = { MaxActive = 8, MaxDistance = 1400, RollOffMin = 30 },
	Foley = { MaxActive = 10, MaxDistance = 80, RollOffMin = 6 },
}

-- Acima desta distância, tiros vão para o grupo "Distant" (agudos cortados).
AudioConfig.DistantShotFrom = 140

return AudioConfig
