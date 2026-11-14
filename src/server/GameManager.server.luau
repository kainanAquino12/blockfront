--[[
	GameManager (servidor) — ponto de entrada único do servidor.
	Inicializa os managers em ordem de dependência. Nenhum outro Script de
	servidor deve existir; todo o resto são ModuleScripts.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local Managers = script.Parent.Managers
local TeamManager = require(Managers.TeamManager)
local DestructionManager = require(Managers.DestructionManager)
local MapManager = require(Managers.MapManager)
local DevToolsManager = require(Managers.DevToolsManager)

local function setupCollisionGroups()
	local groups = GameConfig.CollisionGroups
	for _, name in { groups.Characters, groups.Debris } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.Debris, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.Characters, false)
end

setupCollisionGroups()
Remotes.init()
TeamManager.init()
DestructionManager.init()
MapManager.init()
DevToolsManager.init()

print("[BLOCKFRONT] Servidor iniciado")
