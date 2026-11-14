--[[
	CaptureManager (servidor) — objetivo do modo CONQUISTA.
	Uma área circular no centro do mapa. A cada TickInterval conta os
	jogadores vivos de cada equipe dentro dela e move CaptureValue:
	  -1 = azul domina   0 = neutro   +1 = vermelho domina
	Só uma equipe presente: o valor anda na direção dela (mais rápido com
	mais jogadores). As duas presentes: disputado, nada muda.
	A equipe dona perde o domínio quando o valor cruza o zero (neutraliza)
	e a outra só domina ao chegar no extremo dela.
	Enquanto uma equipe domina, ela ganha ScorePerSecondHeld por segundo
	(via callback onScore, ligado pelo RoundManager).

	Visual: disco e anel em Workspace.CapturePoints, coloridos pelo dono.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local TeamManager = require(script.Parent.TeamManager)

local cfg = MatchConfig.Capture
local NEUTRAL_COLOR = Color3.fromRGB(235, 235, 235)

local CaptureManager = {}

local value = 0
local owner = ""
local matchFolder: Configuration
local disc: Part
local ring: Part
local beacon: Part
local scoreAcc = 0
local onScore: ((teamName: string, points: number) -> ())? = nil
local onOwnerChanged: ((newOwner: string, previous: string) -> ())? = nil

local function ownerColor(): Color3
	if owner ~= "" then
		return GameConfig.Teams[owner].Color
	end
	return NEUTRAL_COLOR
end

local function refreshVisual()
	local color = ownerColor()
	disc.Color = color
	ring.Color = color
	beacon.Color = color
end

local function publish(state: string)
	matchFolder:SetAttribute("CaptureValue", value)
	matchFolder:SetAttribute("CaptureOwner", owner)
	matchFolder:SetAttribute("CaptureState", state)
end

local function setOwner(newOwner: string)
	if newOwner == owner then
		return
	end
	local previous = owner
	owner = newOwner
	refreshVisual()
	if onOwnerChanged then
		onOwnerChanged(newOwner, previous)
	end
end

-- Conta jogadores vivos dentro do cilindro de captura.
function CaptureManager.countInside(): (number, number)
	local blue, red = 0, 0
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local offset = root.Position - cfg.Position
			local flat = Vector2.new(offset.X, offset.Z).Magnitude
			if flat <= cfg.Radius and offset.Y >= -2 and offset.Y <= cfg.Height then
				local team = TeamManager.getTeamOf(p)
				if team == "Blue" then
					blue += 1
				elseif team == "Red" then
					red += 1
				end
			end
		end
	end
	return blue, red
end

-- Avança a captura em dt segundos. Só é chamado com a partida em andamento.
function CaptureManager.step(dt: number)
	local blue, red = CaptureManager.countInside()
	local state = "Idle"
	if blue > 0 and red > 0 then
		state = "Contested"
	elseif blue > 0 or red > 0 then
		local n = math.max(blue, red)
		local mult = math.min(1 + (n - 1) * cfg.ExtraPlayerBonus, cfg.MaxRateMultiplier)
		local delta = (dt / cfg.CaptureTime) * mult
		local dir = if blue > 0 then -1 else 1
		local target = dir -- extremo da equipe presente
		if value ~= target then
			state = "Capturing"
			value = math.clamp(value + delta * dir, -1, 1)
		end
	end

	-- Transições de dono.
	if value <= -1 then
		setOwner("Blue")
	elseif value >= 1 then
		setOwner("Red")
	elseif owner == "Blue" and value >= 0 then
		setOwner("")
	elseif owner == "Red" and value <= 0 then
		setOwner("")
	end

	-- Pontos por manter a área.
	if owner ~= "" and onScore then
		scoreAcc += dt
		while scoreAcc >= 1 do
			scoreAcc -= 1
			onScore(owner, MatchConfig.ScorePerSecondHeld)
		end
	else
		scoreAcc = 0
	end

	publish(state)
end

function CaptureManager.reset()
	value = 0
	scoreAcc = 0
	owner = ""
	refreshVisual()
	publish("Idle")
end

function CaptureManager.getOwner(): string
	return owner
end

function CaptureManager.setCallbacks(scoreFn, ownerFn)
	onScore = scoreFn
	onOwnerChanged = ownerFn
end

local function buildVisual()
	local folder = workspace:FindFirstChild("CapturePoints")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "CapturePoints"

	local point = Instance.new("Model")
	point.Name = cfg.Name

	disc = Instance.new("Part")
	disc.Name = "Zone"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, cfg.Radius * 2, cfg.Radius * 2)
	disc.CFrame = CFrame.new(cfg.Position + Vector3.new(0, 0.34, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Material = Enum.Material.SmoothPlastic
	disc.Transparency = 0.55
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Parent = point

	ring = disc:Clone()
	ring.Name = "Ring"
	ring.Size = Vector3.new(0.25, cfg.Radius * 2 + 1, cfg.Radius * 2 + 1)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.CFrame = disc.CFrame * CFrame.new(-0.02, 0, 0)
	ring.Parent = point

	-- Torre em blocos no centro da zona (marca visual do objetivo).
	beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(1, 1, 1)
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CFrame = CFrame.new(cfg.Position + Vector3.new(0, 18, 0))
	beacon.Parent = point

	point.Parent = folder
	folder.Parent = workspace
end

function CaptureManager.init(match: Configuration)
	matchFolder = match
	buildVisual()
	CaptureManager.reset()
end

return CaptureManager
