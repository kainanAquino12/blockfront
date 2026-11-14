--[[
	DevToolsManager (servidor)
	Recebe pedidos de explosão de teste do cliente (teclas G e H) para
	exercitar a destruição antes das armas da Fase 3.

	Segurança: só aceita dentro do Roblox Studio, valida tipos, valores
	finitos, distância do personagem e cadência por jogador. É o mesmo
	padrão de validação que o CombatManager vai usar.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DestructionConfig = require(ReplicatedStorage.Shared.Config.DestructionConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local DestructionManager = require(script.Parent.DestructionManager)

local DevToolsManager = {}

local lastRequest: { [Player]: number } = {}

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

local function onRequest(player: Player, position: unknown, presetName: unknown)
	if typeof(position) ~= "Vector3" or typeof(presetName) ~= "string" then
		return
	end
	local preset = DestructionConfig.Presets[presetName :: string]
	if not preset or not isFiniteVector(position :: Vector3) then
		return
	end

	local now = os.clock()
	if now - (lastRequest[player] or 0) < GameConfig.DevTools.Cooldown then
		return
	end
	lastRequest[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - (position :: Vector3)).Magnitude > GameConfig.DevTools.MaxRange then
		return
	end

	DestructionManager.explode(position :: Vector3, preset.Radius, preset.Damage)
end

function DevToolsManager.isEnabled(): boolean
	return GameConfig.DevTools.Enabled and RunService:IsStudio()
end

function DevToolsManager.init()
	if not DevToolsManager.isEnabled() then
		return
	end
	Remotes.get("DevExplosionRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		lastRequest[p] = nil
	end)
end

return DevToolsManager
