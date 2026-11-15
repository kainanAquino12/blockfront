--[[
	MovementController (cliente)
	Velocidade do personagem conforme o estado:
	  andando   16 x multiplicador da arma (metralhadora mais lenta, pistola mais rápida)
	  correndo  x1.5 segurando Shift, só para frente, sem mirar e sem recarregar
	  mirando   x0.6
	Atirar interrompe a corrida (o WeaponController bloqueia o disparo
	enquanto corre e pede pausa na corrida). Pulo e queda usam o Humanoid
	padrão; a aterrissagem é tratada pela câmera.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

local MovementController = {}

local BASE_SPEED = 16
local SPRINT_MULT = 1.5
local AIM_MULT = 0.6

local weaponMult = 1
local aiming = false
local reloading = false
local sprinting = false
local sprintAlpha = 0
local sprintBlockedUntil = 0

function MovementController.setWeaponMultiplier(m: number)
	weaponMult = m
end

function MovementController.setAiming(v: boolean)
	aiming = v
end

function MovementController.setReloading(v: boolean)
	reloading = v
end

function MovementController.isSprinting(): boolean
	return sprinting
end

function MovementController.getSprintAlpha(): number
	return sprintAlpha
end

-- Interrompe a corrida por alguns instantes (ex.: ao atirar).
function MovementController.blockSprint(seconds: number)
	sprintBlockedUntil = os.clock() + seconds
	sprinting = false
end

-- 0..1: quanto o jogador está se movendo (para a dispersão das armas).
function MovementController.getMoveFactor(): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return 0
	end
	local v = root.AssemblyLinearVelocity
	local f = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / BASE_SPEED, 0, 1.5)
	if humanoid.FloorMaterial == Enum.Material.Air then
		f += 1 -- no ar: bem menos preciso
	end
	return f
end

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		sprinting = false
		return
	end
	local move = humanoid.MoveDirection
	local look = workspace.CurrentCamera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local forwardness = if forward.Magnitude > 0 and move.Magnitude > 0.1 then move.Unit:Dot(forward.Unit) else 0
	local wantSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		and forwardness > 0.5
		and not aiming
		and not reloading
		and os.clock() >= sprintBlockedUntil
		and humanoid.FloorMaterial ~= Enum.Material.Air
	if humanoid.FloorMaterial ~= Enum.Material.Air or not wantSprint then
		sprinting = wantSprint
	end

	local speed = BASE_SPEED * weaponMult
	if sprinting then
		speed *= SPRINT_MULT
	elseif aiming then
		speed *= AIM_MULT
	end
	humanoid.WalkSpeed = speed

	sprintAlpha += ((if sprinting then 1 else 0) - sprintAlpha) * math.min(dt * 10, 1)
	CameraController.setSprint(sprintAlpha)
end

function MovementController.init()
	RunService.RenderStepped:Connect(update)
end

return MovementController
