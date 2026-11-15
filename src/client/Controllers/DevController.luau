--[[
	DevController (cliente)
	Atalhos de teste da destruição (somente no Roblox Studio):
	  G = explosão grande no ponto do mouse (prévia do lança-foguetes)
	  H = impacto pequeno no ponto do mouse (prévia de projétil / perfuração)
	O cliente só PEDE; quem decide e destrói é o servidor (DevToolsManager).

	Gancho de teste automatizado (também só no Studio): definir o atributo
	"DevLookAt" (Vector3) no jogador local aponta a câmera para esse ponto.
	Usado para testar o alinhamento mira/tiro com cliques reais do mouse.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local CameraController = require(script.Parent.CameraController)

local DevController = {}

local KEYS = {
	[Enum.KeyCode.G] = "DevBig",
	[Enum.KeyCode.H] = "DevSmall",
}

local function mouseHit(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local m = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(m.X, m.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	local cache = workspace:FindFirstChild("DebrisCache")
	if cache then
		table.insert(exclude, cache)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and result.Position
end

function DevController.init()
	if not (GameConfig.DevTools.Enabled and RunService:IsStudio()) then
		return
	end
	local request = Remotes.get("DevExplosionRequest")
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local preset = KEYS[input.KeyCode]
		if preset then
			local pos = mouseHit()
			if pos then
				request:FireServer(pos, preset)
			end
		end
	end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("DevLookAt"):Connect(function()
		local target = player:GetAttribute("DevLookAt")
		if typeof(target) == "Vector3" then
			CameraController.lookAt(target)
		end
	end)
	print("[BLOCKFRONT] DevTools: G = explosão grande, H = impacto pequeno")
end

return DevController
