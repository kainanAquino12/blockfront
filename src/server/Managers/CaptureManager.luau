--[[
	CaptureManager (servidor) — objetivos do modo CONQUISTA.
	Vários pontos de captura (MatchConfig.CapturePoints: A, B, C). Para cada
	ponto, a cada passo conta os jogadores vivos de cada equipe dentro do
	cilindro e move o valor de controle:
	  -1 = azul domina   0 = neutro   +1 = vermelho domina
	Só uma equipe presente: o valor anda na direção dela (mais rápido com
	mais jogadores). As duas presentes: disputado, nada muda.
	O dono perde o ponto quando o valor cruza o zero (neutraliza) e a outra
	equipe só domina ao chegar no extremo dela.
	Cada ponto dominado rende ScorePerSecondHeld por segundo à equipe.

	Estado publicado em atributos de ReplicatedStorage.Match, por ponto:
	  Cap_<Id>_Value, Cap_<Id>_Owner ("Blue"/"Red"/""), Cap_<Id>_State
	  ("Idle"/"Capturing"/"Contested")

	Visual: disco, anel e mastro com a letra do ponto, coloridos pelo dono.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local TeamManager = require(script.Parent.TeamManager)

local rules = MatchConfig.CaptureRules
local NEUTRAL_COLOR = Color3.fromRGB(235, 235, 235)

local CaptureManager = {}

type PointState = {
	Def: any,
	Value: number,
	Owner: string,
	ScoreAcc: number,
	Visual: { BasePart },
	Label: TextLabel?,
}

local points: { PointState } = {}
local matchFolder: Configuration
local onScore: ((teamName: string, points: number) -> ())? = nil
local onOwnerChanged: ((pointName: string, newOwner: string, previous: string) -> ())? = nil

local function colorOf(owner: string): Color3
	return if owner ~= "" then GameConfig.Teams[owner].Color else NEUTRAL_COLOR
end

local function refreshVisual(p: PointState)
	local color = colorOf(p.Owner)
	for _, part in p.Visual do
		part.Color = color
	end
	if p.Label then
		p.Label.TextColor3 = color
	end
end

local function publish(p: PointState, state: string)
	local id = p.Def.Id
	matchFolder:SetAttribute("Cap_" .. id .. "_Value", p.Value)
	matchFolder:SetAttribute("Cap_" .. id .. "_Owner", p.Owner)
	matchFolder:SetAttribute("Cap_" .. id .. "_State", state)
end

local function setOwner(p: PointState, newOwner: string)
	if newOwner == p.Owner then
		return
	end
	local previous = p.Owner
	p.Owner = newOwner
	refreshVisual(p)
	if onOwnerChanged then
		onOwnerChanged(p.Def.Id, newOwner, previous)
	end
end

-- Jogadores vivos de cada equipe dentro do cilindro de um ponto.
function CaptureManager.countInside(def): (number, number)
	local blue, red = 0, 0
	for _, pl in Players:GetPlayers() do
		local character = pl.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local offset = root.Position - def.Position
			local flat = Vector2.new(offset.X, offset.Z).Magnitude
			if flat <= def.Radius and offset.Y >= -4 and offset.Y <= rules.Height then
				local team = TeamManager.getTeamOf(pl)
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

local function stepPoint(p: PointState, dt: number)
	local blue, red = CaptureManager.countInside(p.Def)
	local state = "Idle"
	if blue > 0 and red > 0 then
		state = "Contested"
	elseif blue > 0 or red > 0 then
		local n = math.max(blue, red)
		local mult = math.min(1 + (n - 1) * rules.ExtraPlayerBonus, rules.MaxRateMultiplier)
		local dir = if blue > 0 then -1 else 1
		if p.Value ~= dir then
			state = "Capturing"
			p.Value = math.clamp(p.Value + (dt / rules.CaptureTime) * mult * dir, -1, 1)
		end
	end

	if p.Value <= -1 then
		setOwner(p, "Blue")
	elseif p.Value >= 1 then
		setOwner(p, "Red")
	elseif p.Owner == "Blue" and p.Value >= 0 then
		setOwner(p, "")
	elseif p.Owner == "Red" and p.Value <= 0 then
		setOwner(p, "")
	end

	if p.Owner ~= "" and onScore then
		p.ScoreAcc += dt
		while p.ScoreAcc >= 1 do
			p.ScoreAcc -= 1
			onScore(p.Owner, MatchConfig.ScorePerSecondHeld)
		end
	else
		p.ScoreAcc = 0
	end
	publish(p, state)
end

-- Avança todos os pontos em dt segundos (só com a partida em andamento).
function CaptureManager.step(dt: number)
	for _, p in points do
		stepPoint(p, dt)
	end
end

function CaptureManager.reset()
	for _, p in points do
		p.Value = 0
		p.ScoreAcc = 0
		p.Owner = ""
		refreshVisual(p)
		publish(p, "Idle")
	end
end

function CaptureManager.setCallbacks(scoreFn, ownerFn)
	onScore = scoreFn
	onOwnerChanged = ownerFn
end

local function newPart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(part :: any)[k] = v
	end
	return part
end

local function buildPoint(def, parent: Instance): PointState
	local model = Instance.new("Model")
	model.Name = "Point_" .. def.Id
	local base = CFrame.new(def.Position)
	local disc = newPart({
		Name = "Zone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, def.Radius * 2, def.Radius * 2),
		CFrame = base * CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.6,
		Parent = model,
	})
	local ring = newPart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, def.Radius * 2 + 1.2, def.Radius * 2 + 1.2),
		CFrame = disc.CFrame * CFrame.new(-0.02, 0, 0),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Parent = model,
	})
	-- Mastro com bandeira e a letra do ponto (visível de longe).
	newPart({
		Name = "Pole",
		Size = Vector3.new(0.6, 22, 0.6),
		CFrame = base * CFrame.new(def.FlagOffset.X, 11, def.FlagOffset.Z),
		Color = Color3.fromRGB(220, 220, 228),
		CanCollide = true,
		Parent = model,
	})
	local flag = newPart({
		Name = "Flag",
		Size = Vector3.new(6, 3.6, 0.2),
		CFrame = base * CFrame.new(def.FlagOffset.X + 3.3, 19.8, def.FlagOffset.Z),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(60, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
	billboard.MaxDistance = 1200
	billboard.LightInfluence = 0
	billboard.Adornee = disc
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = def.Id
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	model.Parent = parent
	return { Def = def, Value = 0, Owner = "", ScoreAcc = 0, Visual = { disc, ring, flag }, Label = label }
end

function CaptureManager.getPoints()
	return points
end

function CaptureManager.init(match: Configuration)
	matchFolder = match
	local folder = workspace:FindFirstChild("CapturePoints")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "CapturePoints"
	folder.Parent = workspace
	for _, def in MatchConfig.CapturePoints do
		table.insert(points, buildPoint(def, folder))
	end
	CaptureManager.reset()
end

return CaptureManager
