--[[
	TeamManager (servidor)
	Cria as equipes Blue e Red, distribui jogadores de forma equilibrada
	(sempre para a equipe com menos jogadores) e coloca os personagens no
	grupo de colisão "Characters" (fragmentos não colidem com jogadores).

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

local function onPlayerAdded(player: Player)
	TeamManager.assign(player)
	player.CharacterAdded:Connect(setCharacterGroup)
	if player.Character then
		setCharacterGroup(player.Character)
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
