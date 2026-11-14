--[[
	ClientMain (cliente) — ponto de entrada único do cliente.
	Inicializa os controllers. Nenhum outro LocalScript deve existir.
]]

local Controllers = script.Parent.Controllers

require(Controllers.DestructionEffects).init()
require(Controllers.CameraController).init()
require(Controllers.CombatEffects).init()
require(Controllers.WeaponController).init()
require(Controllers.UIController).init()
require(Controllers.DevController).init()

print("[BLOCKFRONT] Cliente iniciado")
