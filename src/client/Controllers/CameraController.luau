--[[
	CameraController (cliente) — câmera de primeira pessoa própria.

	Por que não a câmera padrão do Roblox: ela usa o botão direito do mouse
	para girar, o que conflitava com a mira (ADS), e reescreve o CFrame a
	cada frame, então recuo e balanço "brigavam" com ela.

	Funcionamento (RenderStep, prioridade Camera):
	  - yaw/pitch vêm do delta do mouse (mouse travado no centro), com a
	    sensibilidade do jogador e o multiplicador de mira da arma
	  - a posição é a cabeça do personagem, com suavização vertical curta
	    (degraus e escadas não dão solavanco)
	  - balanço ao andar/correr, mergulho ao aterrissar e inclinação lateral
	    leve; tudo reduzido ao mirar
	  - recuo: cada tiro sobe a mira (pitch real, o jogador compensa) e ela
	    volta sozinha a uma taxa por arma depois que o tiro para
	  - FOV: base 80, +6 correndo, campo de mira da arma no ADS
	  - o personagem gira junto com a câmera e fica invisível localmente

	A mira (raio do centro da tela) é sempre camera.CFrame.LookVector: o que
	o jogador vê no centro é exatamente para onde o tiro vai.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SettingsController = require(script.Parent.SettingsController)

local player = Players.LocalPlayer

local CameraController = {}

local BASE_FOV = 80
local SPRINT_FOV = 6
local RAD_PER_PIXEL = 0.0032 -- com sensibilidade 1.0
local PITCH_LIMIT = math.rad(85)
local EYE_OFFSET = Vector3.new(0, 1.55, 0) -- olho em relação ao HumanoidRootPart

local yaw, pitch = 0, 0
local recoilAccum = 0 -- radianos de recuo ainda não recuperados
local recoveryRate = math.rad(7)
local lastShot = 0
local smoothEyeY: number? = nil
local bobT = 0
local landDip, landVel = 0, 0
local tilt = 0
local enabled = false
local lastFallSpeed = 0 -- maior velocidade de queda desde que saiu do chão

-- Estado vindo de outros controllers
local aimAlpha = 0
local aimFov = BASE_FOV
local aimSensitivity = 1
local sprintAlpha = 0

local hiddenParts: { BasePart } = {}

function CameraController.setAim(alpha: number, fov: number, sensitivity: number)
	aimAlpha = alpha
	aimFov = fov
	aimSensitivity = sensitivity
end

function CameraController.setSprint(alpha: number)
	sprintAlpha = alpha
end

-- Recuo de um disparo (graus). yawDeg é aleatório em ±yawDeg.
function CameraController.addRecoil(pitchDeg: number, yawDeg: number, recoveryDegPerSec: number)
	local p = math.rad(pitchDeg) * (1 - aimAlpha * 0.25)
	pitch = math.clamp(pitch + p, -PITCH_LIMIT, PITCH_LIMIT)
	yaw += math.rad((math.random() * 2 - 1) * yawDeg)
	recoilAccum += p
	recoveryRate = math.rad(recoveryDegPerSec)
	lastShot = os.clock()
end

-- Aterrissagem: intensidade pela velocidade de queda.
function CameraController.land(fallSpeed: number)
	local strength = math.clamp((fallSpeed - 20) / 60, 0, 1)
	landVel -= strength * 6
end

-- Aponta a câmera para um ponto (início de vida, testes).
function CameraController.lookAt(target: Vector3)
	local cam = workspace.CurrentCamera
	local dir = (target - cam.CFrame.Position).Unit
	yaw = math.atan2(-dir.X, -dir.Z)
	pitch = math.clamp(math.asin(dir.Y), -PITCH_LIMIT, PITCH_LIMIT)
	recoilAccum = 0
end

function CameraController.getAimRay(): Ray
	local cf = workspace.CurrentCamera.CFrame
	return Ray.new(cf.Position, cf.LookVector)
end

function CameraController.isEnabled(): boolean
	return enabled
end

function CameraController.getYaw(): number
	return yaw
end

-- Liga/desliga o controle (menu aberto, sem personagem).
function CameraController.setEnabled(value: boolean)
	enabled = value
	if not value then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function collectHidden(character: Model)
	table.clear(hiddenParts)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(hiddenParts, d)
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			table.insert(hiddenParts, d)
		end
	end)
end

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid then
		return
	end
	humanoid.AutoRotate = false
	local _, y = root.CFrame:ToOrientation()
	yaw, pitch = y, 0
	recoilAccum = 0
	smoothEyeY = nil
	collectHidden(character)
	humanoid.FreeFalling:Connect(function(active)
		if not active then
			CameraController.land(lastFallSpeed)
			lastFallSpeed = 0
		end
	end)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not enabled or not root or not humanoid then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Mouse
	local delta = UserInputService:GetMouseDelta()
	local sens = SettingsController.getSensitivity() * RAD_PER_PIXEL * (1 + (aimSensitivity - 1) * aimAlpha)
	yaw -= delta.X * sens
	pitch = math.clamp(pitch - delta.Y * sens, -PITCH_LIMIT, PITCH_LIMIT)

	-- Recuperação do recuo depois que o tiro para
	if recoilAccum > 0 and os.clock() - lastShot > 0.08 then
		local r = math.min(recoilAccum, recoveryRate * dt)
		recoilAccum -= r
		pitch = math.clamp(pitch - r, -PITCH_LIMIT, PITCH_LIMIT)
	end

	-- Posição do olho, com suavização vertical curta
	local eye = root.Position + EYE_OFFSET
	if humanoid.Health <= 0 then
		eye = root.Position + Vector3.new(0, 0.5, 0)
	end
	if smoothEyeY == nil or math.abs(eye.Y - smoothEyeY) > 3 then
		smoothEyeY = eye.Y
	else
		smoothEyeY += (eye.Y - smoothEyeY) * math.min(dt * 18, 1)
	end
	eye = Vector3.new(eye.X, smoothEyeY :: number, eye.Z)

	-- Balanço ao andar (mais forte correndo, quase nada mirando)
	local vel = root.AssemblyLinearVelocity
	if vel.Y < 0 then
		lastFallSpeed = math.max(lastFallSpeed, -vel.Y)
	end
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local moveFactor = if grounded then math.clamp(speed / 16, 0, 1.6) else 0
	bobT += dt * (6 + speed * 0.45) * (if moveFactor > 0.05 then 1 else 0)
	local bobAmp = moveFactor * (1 - aimAlpha * 0.85) * (1 + sprintAlpha * 0.6)
	local bobX = math.sin(bobT) * 0.045 * bobAmp
	local bobY = math.abs(math.cos(bobT)) * 0.06 * bobAmp

	-- Mergulho ao aterrissar (mola amortecida)
	landVel += (-landDip * 120 - landVel * 16) * dt
	landDip += landVel * dt

	-- Inclinação lateral leve ao andar de lado
	local right = CFrame.Angles(0, yaw, 0).RightVector
	local strafe = if grounded then vel:Dot(right) / 16 else 0
	tilt += (math.clamp(-strafe, -1, 1) * math.rad(1.2) * (1 - aimAlpha) - tilt) * math.min(dt * 8, 1)

	local cf = CFrame.new(eye)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)
		* CFrame.new(bobX, bobY + landDip * 0.35, 0)
		* CFrame.Angles(0, 0, tilt + bobX * 0.15)
	camera.CFrame = cf
	camera.Focus = cf * CFrame.new(0, 0, -4)

	local targetFov = BASE_FOV + SPRINT_FOV * sprintAlpha
	targetFov += (aimFov - targetFov) * aimAlpha
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 14, 1)

	-- Personagem gira com a câmera; corpo invisível para o próprio jogador
	if humanoid.Health > 0 then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
	for _, p in hiddenParts do
		p.LocalTransparencyModifier = 1
	end
end

function CameraController.init()
	player.CameraMode = Enum.CameraMode.Classic
	UserInputService.MouseIconEnabled = false
	workspace.CurrentCamera.FieldOfView = BASE_FOV
	player.CharacterAdded:Connect(function(c)
		task.spawn(onCharacter, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("BlockfrontCamera", Enum.RenderPriority.Camera.Value, update)
end

return CameraController
