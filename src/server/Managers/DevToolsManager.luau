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
local TerrainGen = require(script.Parent.Parent.Map.TerrainGen)

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
		-- em cima do relevo
		buildDummy(folder, Vector3.new(pos.X, TerrainGen.height(pos.X, pos.Z), pos.Z))
	end
end

function DevToolsManager.isEnabled(): boolean
	return GameConfig.DevTools.Enabled and RunService:IsStudio()
end

--[[
	Comandos de teste do colapso estrutural, chamados pelo command bar do
	Studio (mesma instância dos módulos do jogo):
	  game.ServerStorage.DevStructure:Invoke("teleport")
	  game.ServerStorage.DevStructure:Invoke("break", "Pilar_22_A0", 1)
	  game.ServerStorage.DevStructure:Invoke("explode", Vector3, raio, dano)
	  game.ServerStorage.DevStructure:Invoke("stats")
]]
local DEMO = "Demo_EdificioCentral"
local function devStructure(cmd: string, a: any, b: any, c: any): any
	if cmd == "teleport" then
		local demo = GameConfig.DemoArea
		for _, p in Players:GetPlayers() do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = CFrame.lookAt(demo.Origin + demo.SpawnOffset, demo.Origin + Vector3.new(21, 12, 15))
			end
		end
		return true
	elseif cmd == "break" then
		return DestructionManager.destroyElement(a or DEMO, b, c)
	elseif cmd == "breakName" then
		return DestructionManager.destroyElement(DEMO, a, b)
	elseif cmd == "explode" then
		return DestructionManager.explode(a, b or 6, c or 260)
	elseif cmd == "elements" then
		-- elementos cujo nome contém o padrão : estado, nível, carga, capacidade
		local s = DestructionManager.findStructure(DEMO)
		local out = {}
		for _, e in s.Graph.Elements do
			if string.find(e.Name, a, 1, true) then
				table.insert(out, string.format("%s broken=%s lvl=%s load=%.0f cap=%.0f alive=%d/%d unst=%s",
					e.Name, tostring(e.Broken), tostring(e.Level), e.Load, e.Capacity, e.Alive, e.Total, tostring(e.UnstableAt ~= nil)))
			end
		end
		return table.concat(out, "\n")
	elseif cmd == "stats" then
		local s = DestructionManager.findStructure(if type(a) == "string" then a else DEMO)
		local out = {
			Destruction = DestructionManager.getStats(),
			Collapse = DestructionManager.getCollapseStats(),
		}
		if s and s.Graph then
			out.Graph = s.Graph:summary()
			out.Parts = s:CountParts()
			out.Cells = s.Grid.alive
			out.DesignWarnings = s.Graph.DesignWarnings
		end
		return out
	end
	return nil
end

function DevToolsManager.init()
	if not DevToolsManager.isEnabled() then
		return
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "DevStructure"
	bf.OnInvoke = devStructure
	bf.Parent = game:GetService("ServerStorage")
	Remotes.get("DevExplosionRequest").OnServerEvent:Connect(onRequest)
	spawnDummies()
	Players.PlayerRemoving:Connect(function(p)
		lastRequest[p] = nil
	end)
end

return DevToolsManager
