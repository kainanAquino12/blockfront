--[[
	DevToolsManager (servidor)
	Ferramentas de teste, ativas só dentro do Roblox Studio:
	  - pedidos de explosão do cliente (teclas G e H)
	  - bonecos de treino perto de cada base (alvos para mira e dano)

	Segurança: só aceita dentro do Roblox Studio, valida tipos, valores
	finitos, distância do personagem e cadência por jogador. É o mesmo
	padrão de validação que o CombatManager vai usar.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DestructionConfig = require(ReplicatedStorage.Shared.Config.DestructionConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local DestructionManager = require(script.Parent.DestructionManager)

local DevToolsManager = {}

local lastRequest: { [Player]: number } = {}

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

local function onRequest(player: Player, position: unknown, presetName: unknown)
	if typeof(position) ~= "Vector3" or typeof(presetName) ~= "string" then
		return
	end
	local preset = DestructionConfig.Presets[presetName :: string]
	if not preset or not isFiniteVector(position :: Vector3) then
		return
	end

	local now = os.clock()
	if now - (lastRequest[player] or 0) < GameConfig.DevTools.Cooldown then
		return
	end
	lastRequest[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - (position :: Vector3)).Magnitude > GameConfig.DevTools.MaxRange then
		return
	end

	DestructionManager.explode(position :: Vector3, preset.Radius, preset.Damage)
end

-- Boneco de treino (alvo estático com Humanoid) para testar mira, dano e
-- tiro na cabeça sem um segundo jogador. Renasce 3 s depois de "morrer".
local DUMMY_SPOTS = {
	Vector3.new(-20, 0, -286),
	Vector3.new(20, 0, -286),
	Vector3.new(0, 0, -215),
	Vector3.new(-20, 0, 286),
	Vector3.new(20, 0, 286),
	Vector3.new(0, 0, 215),
}

local function buildDummy(folder: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Boneco"
	model:SetAttribute("TrainingDummy", true)
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide = true
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = CFrame.new(position + offset)
		p.Parent = model
		return p
	end
	local orange = Color3.fromRGB(240, 140, 50)
	local gray = Color3.fromRGB(120, 124, 132)
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), gray)
	root.Transparency = 1
	root.CanCollide = false
	part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), orange)
	part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), gray)
	part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), gray)
	part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), gray)
	part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), gray)
	part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), gray)
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayName = "Boneco de treino"
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = folder
	humanoid.Died:Connect(function()
		task.delay(3, function()
			model:Destroy()
			buildDummy(folder, position)
		end)
	end)
end

local function spawnDummies()
	local folder = Instance.new("Folder")
	folder.Name = "TrainingDummies"
	folder.Parent = workspace
	for _, pos in DUMMY_SPOTS do
		buildDummy(folder, pos)
	end
end

function DevToolsManager.isEnabled(): boolean
	return GameConfig.DevTools.Enabled and RunService:IsStudio()
end

function DevToolsManager.init()
	if not DevToolsManager.isEnabled() then
		return
	end
	Remotes.get("DevExplosionRequest").OnServerEvent:Connect(onRequest)
	spawnDummies()
	Players.PlayerRemoving:Connect(function(p)
		lastRequest[p] = nil
	end)
end

return DevToolsManager
