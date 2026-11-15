--[[
	AimController (cliente) — ÚNICA fonte de verdade do estado de mira (ADS).

	Quem escreve:
	  WeaponController.setHeld(true/false)  botão direito pressionado/solto
	  ViewmodelController.setWeapon(...)    a arma equipada pode mirar? FOV? luneta?
	  WeaponController.setBlocked(...)      menu aberto
	Quem lê (só leitura):
	  ViewmodelController (pose), CameraController (FOV e sensibilidade, recebidos
	  daqui), MovementController (velocidade), UIController (retículo/luneta),
	  WeaponController (dispersão).

	Regra: mira = botão segurado E arma com mira E não está correndo, recarregando
	nem com menu aberto. Ao sair da condição que bloqueou (ex.: fim da recarga),
	a mira volta sozinha se o botão continuar segurado.
	Roda no RenderStep logo antes da câmera, para câmera e viewmodel usarem o
	mesmo valor no mesmo quadro.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer

local AimController = {}

local held = false
local blocked = false
local canAim = false
local scope = false
local aimFov = 80
local aimSens = 1
local aiming = false
local alpha = 0

function AimController.setHeld(value: boolean)
	held = value
end

function AimController.setBlocked(value: boolean)
	blocked = value
end

-- Chamado pelo viewmodel ao equipar/desequipar.
function AimController.setWeapon(weaponCanAim: boolean, fov: number?, sensitivity: number?, isScope: boolean?)
	canAim = weaponCanAim
	aimFov = fov or 80
	aimSens = sensitivity or 1
	scope = isScope == true
	alpha = 0
end

function AimController.isAiming(): boolean
	return aiming
end

function AimController.getAlpha(): number
	return alpha
end

function AimController.isScoped(): boolean
	return scope and alpha > 0.9
end

local function reloading(): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("Reloading") == true
end

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	aiming = held and canAim and alive and not blocked and not reloading() and not MovementController.isSprinting()
	local target = if aiming then 1 else 0
	alpha += (target - alpha) * math.min(dt * 13, 1)
	if math.abs(alpha - target) < 0.001 then
		alpha = target
	end
	MovementController.setAiming(aiming)
	CameraController.setAim(alpha, aimFov, aimSens)
end

function AimController.init()
	RunService:BindToRenderStep("BlockfrontAim", Enum.RenderPriority.Camera.Value - 1, update)
end

return AimController
