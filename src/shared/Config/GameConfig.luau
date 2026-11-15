--[[
	GameConfig
	Configuração geral da partida e das equipes do BLOCKFRONT.
	Valores puros (sem lógica). Lido por servidor e cliente.
]]

local GameConfig = {}

GameConfig.Teams = {
	Blue = {
		Name = "Blue",
		DisplayName = "BLUE TEAM",
		TeamColor = BrickColor.new("Bright blue"),
		Color = Color3.fromRGB(64, 118, 214),
	},
	Red = {
		Name = "Red",
		DisplayName = "RED TEAM",
		TeamColor = BrickColor.new("Bright red"),
		Color = Color3.fromRGB(206, 72, 60),
	},
}

-- Ordem fixa usada no balanceamento (desempate determinístico).
GameConfig.TeamOrder = { "Blue", "Red" }

GameConfig.RespawnTime = 4

-- Ferramentas de desenvolvimento (explosões de teste por tecla).
-- Só funcionam dentro do Roblox Studio, mesmo que Enabled = true.
GameConfig.DevTools = {
	Enabled = true,
	MaxRange = 250, -- distância máxima entre o personagem e o ponto pedido
	Cooldown = 0.2, -- segundos entre pedidos por jogador
}

-- Grupos de colisão usados pelo jogo.
GameConfig.CollisionGroups = {
	Characters = "Characters",
	Debris = "Debris",
}

-- Área de demonstração do padrão V4 (prédio Edifício Central), fora do
-- mapa de combate. Só para avaliar arquitetura e colapso estrutural.
GameConfig.DemoArea = {
	Enabled = true,
	Origin = Vector3.new(420, 0, -60), -- canto sudoeste do prédio
	SpawnOffset = Vector3.new(21, 3, -40), -- onde o jogador aparece (de frente para a fachada sul)
}

return GameConfig
