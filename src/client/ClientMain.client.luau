--[[
	ClientMain (cliente) — ponto de entrada único do cliente.
	Inicializa os controllers em ordem de dependência. Nenhum outro
	LocalScript deve existir.
]]

local Controllers = script.Parent.Controllers

require(Controllers.SettingsController).init()
require(Controllers.AudioController).init()
require(Controllers.DestructionEffects).init()
require(Controllers.CameraController).init()
require(Controllers.MovementController).init()
require(Controllers.ViewmodelController).init()
require(Controllers.CombatEffects).init()
require(Controllers.WeaponController).init()
require(Controllers.UIController).init()
require(Controllers.TeamSelectController).init()
require(Controllers.DevController).init()

print("[BLOCKFRONT] Cliente iniciado")
