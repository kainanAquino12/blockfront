--[[
	SettingsController (cliente)
	Preferências do jogador nesta sessão. Hoje: sensibilidade do mouse.
	Ajustada no menu (tecla M). Fica num atributo do jogador local para
	sobreviver a renascimentos.
]]

local Players = game:GetService("Players")

local SettingsController = {}

local player = Players.LocalPlayer

SettingsController.SensitivityMin = 0.2
SettingsController.SensitivityMax = 3.0
SettingsController.SensitivityStep = 0.1

local changed = Instance.new("BindableEvent")
SettingsController.Changed = changed.Event

function SettingsController.getSensitivity(): number
	return player:GetAttribute("Sensitivity") or 1.0
end

function SettingsController.setSensitivity(value: number)
	local v = math.clamp(math.round(value * 10) / 10, SettingsController.SensitivityMin, SettingsController.SensitivityMax)
	player:SetAttribute("Sensitivity", v)
	changed:Fire()
end

function SettingsController.init()
	if player:GetAttribute("Sensitivity") == nil then
		player:SetAttribute("Sensitivity", 1.0)
	end
end

return SettingsController
