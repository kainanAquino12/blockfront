--[[
	LoadoutManager (servidor)
	Entrega as armas a cada renascimento (o Backpack é recriado a cada
	spawn, então munição e granadas voltam cheias).
	Cada arma é uma Tool montada pelo WeaponModels, com atributos de
	munição definidos pelo CombatManager.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)
local CombatManager = require(script.Parent.CombatManager)

local LoadoutManager = {}

function LoadoutManager.createTool(weaponId: string): Tool
	local w = WeaponConfig.Weapons[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = w.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true -- disparo controlado pelo WeaponController
	local handle = WeaponModels.build(weaponId)
	handle.Parent = tool
	CombatManager.setupTool(tool, weaponId)
	return tool
end

local function giveLoadout(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	for _, weaponId in WeaponConfig.Loadout do
		LoadoutManager.createTool(weaponId).Parent = backpack
	end
end

function LoadoutManager.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			giveLoadout(player)
		end)
		if player.Character then
			task.spawn(giveLoadout, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return LoadoutManager
