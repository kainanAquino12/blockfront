--[[
	RoundManager (servidor) — ciclo da partida no modo CONQUISTA.

	Waiting    -> espera MinPlayers
	Starting   -> contagem curta; mapa já está pronto
	InProgress -> tempo correndo; captura ativa; abates e área dão pontos
	Ended      -> vencedor anunciado; combate desligado
	(volta para Waiting: mapa destrutível reconstruído, placares zerados,
	 todos renascem)

	A partida termina quando o tempo acaba ou uma equipe atinge ScoreToWin.
	Estado publicado em atributos de ReplicatedStorage.Match (ver MatchConfig).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local TeamManager = require(script.Parent.TeamManager)
local CaptureManager = require(script.Parent.CaptureManager)
local MapManager = require(script.Parent.MapManager)

local RoundManager = {}

local match: Configuration
local scores = { Blue = 0, Red = 0 }
local state = "Waiting"
local stateChanged = Instance.new("BindableEvent")

local function setState(newState: string)
	state = newState
	match:SetAttribute("State", newState)
	stateChanged:Fire(newState)
end

local function publishScores()
	match:SetAttribute("ScoreBlue", scores.Blue)
	match:SetAttribute("ScoreRed", scores.Red)
end

function RoundManager.getState(): string
	return state
end

-- Combate permitido em todas as fases, menos no fim da partida.
function RoundManager.isCombatAllowed(): boolean
	return state ~= "Ended"
end

-- Pontos só contam com a partida em andamento.
function RoundManager.addScore(teamName: string, points: number)
	if state ~= "InProgress" or scores[teamName] == nil then
		return
	end
	scores[teamName] += points
	publishScores()
end

function RoundManager.getMatchFolder(): Configuration
	return match
end

local function countdown(seconds: number, stopWhen: (() -> boolean)?)
	local t = seconds
	match:SetAttribute("TimeLeft", math.ceil(t))
	while t > 0 do
		local dt = task.wait(0.2)
		t -= dt
		match:SetAttribute("TimeLeft", math.max(0, math.ceil(t)))
		if stopWhen and stopWhen() then
			return
		end
	end
end

local function decideWinner(): string
	if scores.Blue > scores.Red then
		return "Blue"
	elseif scores.Red > scores.Blue then
		return "Red"
	end
	return "Draw"
end

local function resetForNewMatch()
	scores.Blue, scores.Red = 0, 0
	publishScores()
	match:SetAttribute("Winner", "")
	TeamManager.resetStats()
	CaptureManager.reset()
	MapManager.buildDestructibles()
	for _, p in Players:GetPlayers() do
		task.spawn(function()
			p:LoadCharacter()
		end)
	end
end

local function runMatch()
	setState("InProgress")
	local t = MatchConfig.MatchDuration
	match:SetAttribute("TimeLeft", t)
	local acc = 0
	while t > 0 do
		local dt = RunService.Heartbeat:Wait()
		t -= dt
		acc += dt
		if acc >= MatchConfig.Capture.TickInterval then
			CaptureManager.step(acc)
			acc = 0
			match:SetAttribute("TimeLeft", math.max(0, math.ceil(t)))
		end
		if scores.Blue >= MatchConfig.ScoreToWin or scores.Red >= MatchConfig.ScoreToWin then
			break
		end
		if #Players:GetPlayers() == 0 then
			break
		end
	end
	match:SetAttribute("Winner", decideWinner())
	setState("Ended")
	print(("[BLOCKFRONT] Fim da partida: Azul %d x %d Vermelho"):format(scores.Blue, scores.Red))
end

local function loop()
	while true do
		setState("Waiting")
		match:SetAttribute("TimeLeft", 0)
		while #Players:GetPlayers() < MatchConfig.MinPlayers do
			task.wait(1)
		end
		setState("Starting")
		countdown(MatchConfig.StartingTime)
		runMatch()
		countdown(MatchConfig.EndedTime)
		resetForNewMatch()
	end
end

RoundManager.StateChanged = stateChanged.Event

function RoundManager.init()
	match = ReplicatedStorage:FindFirstChild("Match") :: Configuration
	if not match then
		match = Instance.new("Configuration")
		match.Name = "Match"
		match.Parent = ReplicatedStorage
	end
	match:SetAttribute("ScoreToWin", MatchConfig.ScoreToWin)
	publishScores()
	match:SetAttribute("Winner", "")

	CaptureManager.init(match)
	CaptureManager.setCallbacks(function(teamName, points)
		RoundManager.addScore(teamName, points)
	end, function(newOwner, previous)
		print(("[BLOCKFRONT] Área de captura: %s -> %s"):format(previous == "" and "neutra" or previous, newOwner == "" and "neutra" or newOwner))
	end)

	task.spawn(loop)
end

return RoundManager
