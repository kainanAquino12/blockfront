--[[
	MatchConfig
	Regras da partida no modo CONQUISTA.

	O estado da partida é publicado como atributos em
	ReplicatedStorage.Match (Configuration), lidos pelo HUD:
	  State          "Waiting" | "Starting" | "InProgress" | "Ended"
	  TimeLeft       segundos restantes da fase atual
	  ScoreBlue      pontuação coletiva azul
	  ScoreRed       pontuação coletiva vermelha
	  Winner         "Blue" | "Red" | "Draw" | ""
	  Cap_<Id>_Owner "Blue" | "Red" | ""   (Id = A, B, C)
	  Cap_<Id>_Value -1 (azul domina) .. 0 (neutro) .. 1 (vermelho domina)
	  Cap_<Id>_State "Idle" | "Capturing" | "Contested"
]]

local RunService = game:GetService("RunService")

local MatchConfig = {}

-- No Studio basta 1 jogador para testar; em servidor real, 2.
MatchConfig.MinPlayers = if RunService:IsStudio() then 1 else 2
MatchConfig.StartingTime = 5
MatchConfig.MatchDuration = 600
MatchConfig.EndedTime = 10
MatchConfig.ScoreToWin = 600

MatchConfig.ScorePerKill = 3
MatchConfig.ScorePerSecondHeld = 1

-- Pontos de captura (mapa "Front Bloco"). FlagOffset: posição do mastro em relação ao centro.
MatchConfig.CapturePoints = {
	{ Id = "A", Name = "Indústria", Position = Vector3.new(-240, 0, 0), Radius = 18, FlagOffset = Vector3.new(8, 0, 8) },
	{ Id = "B", Name = "Praça", Position = Vector3.new(-20, 2, 0), Radius = 20, FlagOffset = Vector3.new(0, 0, 0) },
	{ Id = "C", Name = "QG do Cume", Position = Vector3.new(234, 26, 0), Radius = 18, FlagOffset = Vector3.new(-8, 0, 8) },
}

MatchConfig.CaptureRules = {
	Height = 14, -- altura do cilindro de captura acima do chão
	CaptureTime = 10, -- segundos para 1 jogador ir de neutro a dominado
	ExtraPlayerBonus = 0.5, -- +50% de velocidade por jogador extra
	MaxRateMultiplier = 2.5,
	TickInterval = 0.2,
}

return MatchConfig
