--[[
	CameraController (cliente)
	Câmera de tiro em terceira pessoa: com uma arma na mão, o mouse fica
	preso no centro da tela, a câmera vai para trás do ombro direito e o
	personagem gira junto com a câmera. A mira é sempre o centro da tela.
	Sem arma, volta ao comportamento padrão do Roblox.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

local SHOULDER_OFFSET = Vector3.new(1.8, 0.6, 0)
local COMBAT_MIN_ZOOM = 7
local DEFAULT_MIN_ZOOM = 0.5
local active = false

function CameraController.setCombatMode(enabled: boolean)
	active = enabled
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = not enabled
		humanoid.CameraOffset = if enabled then SHOULDER_OFFSET else Vector3.zero
	end
	-- Mantém a câmera em terceira pessoa com arma (primeira pessoa esconderia
	-- o personagem e desalinharia a mira com o deslocamento de ombro).
	local p = Players.LocalPlayer
	p.CameraMinZoomDistance = if enabled then COMBAT_MIN_ZOOM else DEFAULT_MIN_ZOOM
	if not enabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	UserInputService.MouseIconEnabled = not enabled
end

function CameraController.isCombatMode(): boolean
	return active
end

-- Raio que sai do centro da tela (onde fica a mira).
function CameraController.getAimRay(): Ray
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

function CameraController.init()
	RunService:BindToRenderStep("BlockfrontCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not active then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local look = workspace.CurrentCamera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		CameraController.setCombatMode(false)
	end)
end

return CameraController
