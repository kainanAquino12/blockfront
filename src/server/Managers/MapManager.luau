--[[
	MapManager (servidor)
	Monta o campo de testes da Fase 2: piso, spawn de cada equipe e as
	paredes voxel do protótipo de destruição. O mapa completo (Fase 4)
	vai substituir buildTestRange por um layout de verdade.

	Hierarquia criada no Workspace:
	  Map                 piso e cenário estático
	  SpawnPoints         SpawnLocations por equipe
	  DestructibleObjects estruturas voxel (DestructionManager)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MaterialConfig = require(ReplicatedStorage.Shared.Config.MaterialConfig)
local DestructionManager = require(script.Parent.DestructionManager)

local MapManager = {}

local folders: { [string]: Folder } = {}

local function folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = workspace
	folders[name] = nf
	return nf
end

local function makeSpawn(teamName: string, position: Vector3, parent: Instance)
	local def = GameConfig.Teams[teamName]
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = teamName .. "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Anchored = true
	spawn.Neutral = false
	spawn.TeamColor = def.TeamColor
	spawn.Color = def.Color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 2
	spawn.Position = position
	spawn.Parent = parent
end

local WOOD = MaterialConfig.ByName.Wood.Id
local BRICK = MaterialConfig.ByName.Brick.Id
local CONCRETE = MaterialConfig.ByName.Concrete.Id
local METAL = MaterialConfig.ByName.Metal.Id

-- Parede de tijolos com base de concreto e viga metálica no topo.
local function brickWallFill(sx: number, sy: number)
	return function(_x: number, y: number, _z: number): number
		if y <= 1 then
			return CONCRETE
		elseif y == sy - 1 then
			return METAL
		end
		return BRICK
	end
end

function MapManager.buildTestRange()
	local map = folder("Map")
	local spawns = folder("SpawnPoints")
	local destructibles = folder("DestructibleObjects")

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(320, 2, 320)
	floor.Position = Vector3.new(0, -1, 0)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(92, 168, 96)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = map

	makeSpawn("Blue", Vector3.new(0, 0.5, -70), spawns)
	makeSpawn("Red", Vector3.new(0, 0.5, 70), spawns)

	-- Três paredes de teste, uma por material, entre as bases.
	DestructionManager.createStructure({
		Name = "TestWall_Wood",
		Origin = CFrame.new(-46, 0, -1),
		Size = Vector3.new(20, 12, 2),
		Fill = function()
			return WOOD
		end,
		Parent = destructibles,
	})

	DestructionManager.createStructure({
		Name = "TestWall_Brick",
		Origin = CFrame.new(-12, 0, -1),
		Size = Vector3.new(24, 14, 2),
		Fill = brickWallFill(24, 14),
		Parent = destructibles,
	})

	DestructionManager.createStructure({
		Name = "TestWall_Concrete",
		Origin = CFrame.new(26, 0, -1.5),
		Size = Vector3.new(20, 12, 3),
		Fill = function()
			return CONCRETE
		end,
		Parent = destructibles,
	})
end

function MapManager.init()
	MapManager.buildTestRange()
end

return MapManager
