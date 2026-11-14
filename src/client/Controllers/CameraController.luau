--[[
	CameraController (cliente)
	BLOCKFRONT é jogado em primeira pessoa: a câmera fica travada na
	cabeça, o mouse preso no centro e a mira é sempre o centro da tela.
	O campo de visão e os efeitos de mira/recuo ficam no ViewmodelController.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

-- Raio que sai do centro da tela (onde fica a mira).
function CameraController.getAimRay(): Ray
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

function CameraController.init()
	local player = Players.LocalPlayer
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	UserInputService.MouseIconEnabled = false
end

return CameraController
