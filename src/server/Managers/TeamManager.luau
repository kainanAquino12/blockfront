--[[
	TeamManager (servidor)
	Cria as equipes Blue e Red, distribui jogadores de forma equilibrada
	(sempre para a equipe com menos jogadores), cria o placar individual
	(leaderstats: Abates/Mortes), veste cada personagem com um colete em
	blocos na cor do time e coloca os personagens no grupo de colisão
	"Characters" (fragmentos não colidem com jogadores).

	O spawn por equipe é feito pelo próprio Roblox: cada SpawnLocation do
	mapa tem TeamColor da equipe e Neutral = false (ver MapManager).
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local TeamManager = {}

local teamsByName: { [string]: Team } = {}

local function ensureTeam(def): Team
	local team = Teams:FindFirstChild(def.Name) :: Team?
	if not team then
		team = Instance.new("Team")
		team.Name = def.Name
		team.Parent = Teams
	end
	assert(team)
	team.TeamColor = def.TeamColor
	team.AutoAssignable = false
	return team
end

function TeamManager.getTeam(name: string): Team
	return teamsByName[name]
end

function TeamManager.getTeamOf(player: Player): string?
	local team = player.Team
	if team and teamsByName[team.Name] == team then
		return team.Name
	end
	return nil
end

-- Equipe com menos jogadores (empate: ordem de GameConfig.TeamOrder).
function TeamManager.pickTeamForNewPlayer(): Team
	local best: Team? = nil
	local bestCount = math.huge
	for _, name in GameConfig.TeamOrder do
		local team = teamsByName[name]
		local count = #team:GetPlayers()
		if count < bestCount then
			best, bestCount = team, count
		end
	end
	assert(best)
	return best
end

function TeamManager.assign(player: Player)
	player.Team = TeamManager.pickTeamForNewPlayer()
end

local function setCharacterGroup(character: Model)
	local group = GameConfig.CollisionGroups.Characters
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

-- Colete em blocos (peito + costas + ombreiras) na cor do time.
local function addTeamVest(player: Player, character: Model)
	local torso = character:WaitForChild("UpperTorso", 5) or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local teamName = TeamManager.getTeamOf(player)
	local color = if teamName then GameConfig.Teams[teamName].Color else Color3.new(0.5, 0.5, 0.5)
	local s = torso.Size
	local vest = Instance.new("Model")
	vest.Name = "TeamVest"
	local pieces = {
		{ Vector3.new(s.X * 0.9, s.Y * 0.8, 0.2), Vector3.new(0, -s.Y * 0.05, -s.Z / 2 - 0.08) }, -- peito
		{ Vector3.new(s.X * 0.9, s.Y * 0.8, 0.2), Vector3.new(0, -s.Y * 0.05, s.Z / 2 + 0.08) }, -- costas
		{ Vector3.new(0.45, 0.25, s.Z + 0.3), Vector3.new(-s.X * 0.33, s.Y / 2 + 0.05, 0) }, -- ombro esq.
		{ Vector3.new(0.45, 0.25, s.Z + 0.3), Vector3.new(s.X * 0.33, s.Y / 2 + 0.05, 0) }, -- ombro dir.
	}
	for _, def in pieces do
		local p = Instance.new("Part")
		p.Size = def[1]
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = torso.CFrame * CFrame.new(def[2])
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = p
		weld.Parent = p
		p.Parent = vest
	end
	vest.Parent = character
end

local function createLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Abates"
	kills.Parent = stats
	local deaths = Instance.new("IntValue")
	deaths.Name = "Mortes"
	deaths.Parent = stats
	stats.Parent = player
end

function TeamManager.resetStats()
	for _, p in Players:GetPlayers() do
		local stats = p:FindFirstChild("leaderstats")
		if stats then
			for _, v in stats:GetChildren() do
				if v:IsA("IntValue") then
					v.Value = 0
				end
			end
		end
	end
end

function TeamManager.addStat(player: Player, statName: string, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(statName)
	if v and v:IsA("IntValue") then
		v.Value += amount
	end
end

local function onCharacterAdded(player: Player, character: Model)
	setCharacterGroup(character)
end

local function onPlayerAdded(player: Player)
	createLeaderstats(player)
	TeamManager.assign(player)
	player.CharacterAdded:Connect(function(c)
		onCharacterAdded(player, c)
	end)
	-- O colete só pode ser soldado depois que o visual do avatar é aplicado,
	-- porque aplicar a aparência troca as partes do corpo.
	player.CharacterAppearanceLoaded:Connect(function(c)
		addTeamVest(player, c)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function TeamManager.init()
	for _, name in GameConfig.TeamOrder do
		teamsByName[name] = ensureTeam(GameConfig.Teams[name])
	end
	Players.RespawnTime = GameConfig.RespawnTime
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
end

return TeamManager
