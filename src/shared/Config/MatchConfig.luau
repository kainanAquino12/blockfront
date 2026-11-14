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
	  CaptureOwner   "Blue" | "Red" | ""
	  CaptureValue   -1 (azul domina) .. 0 (neutro) .. 1 (vermelho domina)
	  CaptureState   "Idle" | "Capturing" | "Contested"
]]

local RunService = game:GetService("RunService")

local MatchConfig = {}

-- No Studio basta 1 jogador para testar; em servidor real, 2.
MatchConfig.MinPlayers = if RunService:IsStudio() then 1 else 2
MatchConfig.StartingTime = 5
MatchConfig.MatchDuration = 300
MatchConfig.EndedTime = 10
MatchConfig.ScoreToWin = 250

MatchConfig.ScorePerKill = 3
MatchConfig.ScorePerSecondHeld = 1

MatchConfig.Capture = {
	Name = "Centro",
	Position = Vector3.new(0, 0, 0), -- a parede de tijolos corta a zona ao meio

	Radius = 14,
	Height = 12, -- altura do cilindro de captura acima do piso
	CaptureTime = 8, -- segundos para 1 jogador ir de neutro a dominado
	ExtraPlayerBonus = 0.5, -- +50% de velocidade por jogador extra
	MaxRateMultiplier = 2.5,
	TickInterval = 0.2,
}

return MatchConfig
