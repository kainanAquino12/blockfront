--[[
	LoadoutManager (servidor)
	Entrega o equipamento a cada nascimento (o Backpack é recriado a cada
	spawn, então munição e granadas voltam cheias):
	  1 arma principal (escolhida no menu: rifle, SMG, metralhadora, sniper, escopeta)
	  2 pistola   3 lança-foguetes   4 granada   5 marreta
	A escolha chega por LoadoutSelect, é validada contra WeaponConfig.Primaries
	e guardada no atributo "Primary" do jogador; vale a partir do próximo
	nascimento (ou na hora, se o jogador ainda não nasceu).
	Cada Tool recebe o atributo "Slot" (tecla) usado pelo cliente.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local CombatManager = require(script.Parent.CombatManager)

local LoadoutManager = {}

function LoadoutManager.createTool(weaponId: string, slot: number): Tool
	local w = WeaponConfig.Weapons[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = w.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true -- disparo controlado pelo WeaponController
	local handle = WeaponModels.build(weaponId)
	handle.Parent = tool
	CombatManager.setupTool(tool, weaponId)
	tool:SetAttribute("Slot", slot)
	return tool
end

local function primaryOf(player: Player): string
	local p = player:GetAttribute("Primary")
	if typeof(p) == "string" and table.find(WeaponConfig.Primaries, p) then
		return p
	end
	return WeaponConfig.DefaultPrimary
end

local function giveLoadout(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	LoadoutManager.createTool(primaryOf(player), 1).Parent = backpack
	for i, weaponId in WeaponConfig.FixedSlots do
		LoadoutManager.createTool(weaponId, i + 1).Parent = backpack
	end
end

local function onSelect(player: Player, weaponId: unknown)
	if typeof(weaponId) ~= "string" or not table.find(WeaponConfig.Primaries, weaponId) then
		return
	end
	player:SetAttribute("Primary", weaponId)
end

function LoadoutManager.init()
	Remotes.get("LoadoutSelect").OnServerEvent:Connect(onSelect)
	local function onPlayer(player: Player)
		player:SetAttribute("Primary", WeaponConfig.DefaultPrimary)
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
