--[[
	CombatManager (servidor)
	Toda decisão de combate acontece aqui. O cliente só envia a intenção
	(WeaponFire: arma, origem, direção, alvo sugerido, semente dos chumbos)
	e o servidor valida:
	  - partida permite combate, jogador vivo, arma realmente equipada
	  - cadência (FireInterval com tolerância de latência)
	  - munição (contada no servidor, publicada nos atributos da Tool)
	  - origem perto da cabeça, direção unitária e finita
	Depois o próprio servidor faz o raycast/simulação e aplica o dano.

	Fluxo da mira (sem divergência entre mira e impacto):
	  1. o cliente usa o centro da câmera como origem e direção
	  2. aplica a dispersão da arma e envia a direção final
	  3. o servidor repete o raycast com essa direção e decide o acerto
	  4. os efeitos de todos usam o ponto de impacto calculado pelo servidor
	     (o atirador desenha o próprio tiro na hora com o mesmo raycast)

	Alvos: jogadores (sem fogo amigo; dano próprio reduzido em explosões)
	e bonecos de treino (Humanoid com atributo TrainingDummy, só no Studio).

	Eventos CombatEvent enviados:
	  Shot { Shooter, Weapon, Origin, Hits = { {Position, Material} } }
	  Rocket / ProjectileEnd / Throw / Swing
	  Hit { Headshot, Lethal }            só para o atirador
	  Damaged { From, Amount }            só para a vítima (indicador de dano)
	  Kill { Killer, KillerTeam, Victim, VictimTeam, Weapon, Headshot }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local WeaponMath = require(ReplicatedStorage.Shared.Modules.WeaponMath)
local DestructionManager = require(script.Parent.DestructionManager)
local TeamManager = require(script.Parent.TeamManager)
local RoundManager = require(script.Parent.RoundManager)
local Projectiles = require(script.Parent.Parent.Combat.Projectiles)

local Weapons = WeaponConfig.Weapons
local V = WeaponConfig.Validation

local CombatManager = {}

local combatEvent: RemoteEvent
local lastFire: { [Player]: { [string]: number } } = {}
local killedHumanoids: { [Humanoid]: true } = setmetatable({}, { __mode = "k" }) :: any

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

local function getEquippedTool(player: Player, weaponId: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("WeaponId") == weaponId then
		return tool
	end
	return nil
end

local function aliveHumanoid(model: Model?): Humanoid?
	local h = model and model:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

-- Modelo com Humanoid que contém a peça (personagem ou boneco de treino) e o jogador, se houver.
local function targetFromPart(part: Instance?): (Model?, Player?)
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model, Players:GetPlayerFromCharacter(model)
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local function isStructurePart(part: Instance): boolean
	local folder = workspace:FindFirstChild("DestructibleObjects")
	return folder ~= nil and part:IsDescendantOf(folder)
end

local function rayParamsExcluding(player: Player): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local grenades = workspace:FindFirstChild("Grenades")
	if grenades then
		table.insert(exclude, grenades)
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function rootPosition(player: Player?): Vector3?
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

---------------------------------------------------------------------------
-- Dano e abates
---------------------------------------------------------------------------

--[[
	Aplica dano a um alvo (personagem de jogador ou boneco de treino).
	from: posição de onde veio o dano (para o indicador de direção da vítima).
	Retorna true se causou dano.
]]
function CombatManager.damageTarget(attacker: Player?, model: Model, amount: number, weaponId: string, headshot: boolean?, from: Vector3?): boolean
	local humanoid = aliveHumanoid(model)
	if not humanoid or amount <= 0 then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		if attacker and attacker ~= victim and attacker.Team ~= nil and attacker.Team == victim.Team then
			return false -- sem fogo amigo
		end
		if model:FindFirstChildOfClass("ForceField") then
			return false -- proteção de nascimento
		end
	elseif not model:GetAttribute("TrainingDummy") then
		return false
	end

	humanoid:TakeDamage(amount)
	local lethal = humanoid.Health <= 0

	if attacker and attacker ~= victim then
		combatEvent:FireClient(attacker, { Type = "Hit", Headshot = headshot == true, Lethal = lethal })
	end
	if victim then
		combatEvent:FireClient(victim, { Type = "Damaged", From = from or rootPosition(attacker), Amount = amount })
	end

	if lethal and victim and not killedHumanoids[humanoid] then
		killedHumanoids[humanoid] = true
		TeamManager.addStat(victim, "Mortes", 1)
		local killerName = ""
		if attacker and attacker ~= victim then
			TeamManager.addStat(attacker, "Abates", 1)
			local team = TeamManager.getTeamOf(attacker)
			if team then
				RoundManager.addScore(team, MatchConfig.ScorePerKill)
			end
			killerName = attacker.Name
		end
		combatEvent:FireAllClients({
			Type = "Kill",
			Killer = killerName,
			KillerTeam = attacker and TeamManager.getTeamOf(attacker) or "",
			Victim = victim.Name,
			VictimTeam = TeamManager.getTeamOf(victim) or "",
			Weapon = weaponId,
			Headshot = headshot == true,
		})
	end
	return true
end

-- Explosão completa: destrói estrutura e fere alvos (queda linear até a borda;
-- 35% do dano atrás de estruturas).
function CombatManager.explodeAt(owner: Player?, weaponId: string, position: Vector3)
	local w = Weapons[weaponId]
	local radius = w.ExplosionRadius
	DestructionManager.explode(position, radius, w.StructureDamage, "Explosion")

	local blockParams = RaycastParams.new()
	blockParams.FilterType = Enum.RaycastFilterType.Include
	blockParams.FilterDescendantsInstances = { workspace:FindFirstChild("DestructibleObjects") }

	local targets = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(targets, p.Character)
		end
	end
	local dummies = workspace:FindFirstChild("TrainingDummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			table.insert(targets, d)
		end
	end

	for _, model in targets do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = (root.Position - position).Magnitude
			if d <= radius then
				local t = d / radius
				local dmg = w.PlayerDamage * (1 - t * (1 - WeaponConfig.ExplosionFalloffMin))
				if owner and model == owner.Character then
					dmg *= w.SelfDamageMultiplier or 1
				end
				if workspace:Raycast(position, root.Position - position, blockParams) then
					dmg *= 0.35
				end
				CombatManager.damageTarget(owner, model, dmg, weaponId, false, position)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Munição
---------------------------------------------------------------------------

function CombatManager.setupTool(tool: Tool, weaponId: string)
	local w = Weapons[weaponId]
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Ammo", w.MagSize or 0)
	tool:SetAttribute("Reserve", w.ReserveAmmo or 0)
	tool:SetAttribute("Reloading", false)
end

local function consumeAmmo(tool: Tool, w): boolean
	if w.Kind == "Melee" then
		return true
	end
	if tool:GetAttribute("Reloading") then
		return false
	end
	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo <= 0 then
		return false
	end
	tool:SetAttribute("Ammo", ammo - 1)
	return true
end

local function onReload(player: Player, weaponId: unknown)
	if typeof(weaponId) ~= "string" then
		return
	end
	local w = Weapons[weaponId :: string]
	if not w or not w.ReloadTime then
		return
	end
	local tool = getEquippedTool(player, weaponId :: string)
	if not tool or tool:GetAttribute("Reloading") then
		return
	end
	local ammo = tool:GetAttribute("Ammo") or 0
	local reserve = tool:GetAttribute("Reserve") or 0
	if ammo >= w.MagSize or reserve <= 0 then
		return
	end
	tool:SetAttribute("Reloading", true)
	task.delay(w.ReloadTime, function()
		if not tool.Parent then
			return
		end
		local a = tool:GetAttribute("Ammo") or 0
		local r = tool:GetAttribute("Reserve") or 0
		local take = math.min(w.MagSize - a, r)
		tool:SetAttribute("Ammo", a + take)
		tool:SetAttribute("Reserve", r - take)
		tool:SetAttribute("Reloading", false)
	end)
end

---------------------------------------------------------------------------
-- Tipos de arma
---------------------------------------------------------------------------

-- Um raio de projétil: devolve alvo atingido, peça, posição e material.
local function traceBullet(player: Player, w, origin: Vector3, direction: Vector3, claimed: Instance?)
	local params = rayParamsExcluding(player)
	local result = workspace:Raycast(origin, direction * w.Range, params)
	local hitPos = if result then result.Position else origin + direction * w.Range
	local model, hitPart = nil, nil
	if result then
		model = targetFromPart(result.Instance)
		hitPart = result.Instance
	end

	-- "Favor do atirador": o servidor não viu o alvo por latência, mas o cliente
	-- afirma ter acertado. Aceita se o alvo está perto da linha do tiro e nada
	-- sólido bloqueia o caminho até ele.
	if not model and typeof(claimed) == "Instance" and (claimed :: Instance):IsA("BasePart") then
		local cModel = targetFromPart(claimed :: Instance)
		if cModel and cModel ~= player.Character then
			local p = (claimed :: BasePart).Position
			local along = (p - origin):Dot(direction)
			local closest = origin + direction * along
			if along > 0 and along <= w.Range and (p - closest).Magnitude <= V.ClaimMaxRayDistance then
				local blockParams = rayParamsExcluding(player)
				blockParams:AddToFilter(cModel)
				if not workspace:Raycast(origin, p - origin, blockParams) then
					model, hitPart, hitPos = cModel, claimed :: BasePart, p
					result = nil
				end
			end
		end
	end
	return model, hitPart, hitPos, result
end

local function fireHitscan(player: Player, w, origin: Vector3, direction: Vector3, claimed: Instance?, seed: number?)
	local dirs: { Vector3 }
	if w.Pellets and w.Pellets > 1 then
		dirs = WeaponMath.pelletDirections(direction, seed or 0, w.Pellets, w.PelletSpread)
	else
		dirs = { direction }
	end

	local damageByTarget: { [Model]: { amount: number, headshot: boolean } } = {}
	local hits = {}
	local structureHits = 0
	for i, dir in dirs do
		local model, hitPart, hitPos, result = traceBullet(player, w, origin, dir, if i == 1 then claimed else nil)
		local material = if result then result.Material.Name elseif model then "Body" else ""
		if model then
			local headshot = hitPart ~= nil and hitPart.Name == "Head"
			local entry = damageByTarget[model] or { amount = 0, headshot = false }
			entry.amount += w.PlayerDamage * (if headshot then w.HeadshotMultiplier else 1)
			entry.headshot = entry.headshot or headshot
			damageByTarget[model] = entry
			material = "Body"
		elseif result and isStructurePart(result.Instance) and structureHits < 8 then
			structureHits += 1
			DestructionManager.explode(result.Position + dir * 0.4, w.StructureRadius, w.StructureDamage, "Impact")
		end
		table.insert(hits, { Position = hitPos, Material = material, Normal = result and result.Normal or nil })
	end

	for model, entry in damageByTarget do
		CombatManager.damageTarget(player, model, entry.amount, w.Id, entry.headshot, origin)
	end

	combatEvent:FireAllClients({ Type = "Shot", Shooter = player, Weapon = w.Id, Origin = origin, Hits = hits })
end

local function fireRocket(player: Player, w, origin: Vector3, direction: Vector3)
	local id = Projectiles.fireRocket(player, w.Id, origin, direction, w.ProjectileSpeed, w.Range)
	combatEvent:FireAllClients({
		Type = "Rocket",
		Id = id,
		Shooter = player,
		Weapon = w.Id,
		Origin = origin,
		Direction = direction,
		Speed = w.ProjectileSpeed,
	})
end

local function throwGrenade(player: Player, w, origin: Vector3, direction: Vector3)
	local velocity = (direction + Vector3.new(0, w.ThrowLift, 0)).Unit * w.ThrowSpeed
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		velocity += root.AssemblyLinearVelocity * 0.5
	end
	Projectiles.throwGrenade(player, w.Id, origin + direction * 1.5, velocity, w.Fuse)
	combatEvent:FireAllClients({ Type = "Throw", Shooter = player, Weapon = w.Id, Origin = origin })
end

local function swingMelee(player: Player, w, origin: Vector3, direction: Vector3)
	local params = rayParamsExcluding(player)
	local result = workspace:Spherecast(origin, 1.2, direction * w.Range, params)
	local material = ""
	if result then
		local model = targetFromPart(result.Instance)
		if model then
			CombatManager.damageTarget(player, model, w.PlayerDamage, w.Id, false, origin)
			material = "Body"
		else
			material = result.Material.Name
			if isStructurePart(result.Instance) then
				DestructionManager.explode(result.Position + direction * 0.6, w.StructureRadius, w.StructureDamage, "Impact")
			end
		end
	end
	combatEvent:FireAllClients({ Type = "Swing", Shooter = player, Weapon = w.Id, Origin = origin, Hit = result and result.Position, Material = material })
end

local HANDLERS = {
	Hitscan = fireHitscan,
	Projectile = fireRocket,
	Throwable = throwGrenade,
	Melee = swingMelee,
}

---------------------------------------------------------------------------
-- Entrada do cliente
---------------------------------------------------------------------------

local function onFire(player: Player, weaponId: unknown, origin: unknown, direction: unknown, claimed: unknown, seed: unknown)
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if seed ~= nil and (typeof(seed) ~= "number" or seed ~= seed or math.abs(seed :: number) > 2 ^ 31) then
		return
	end
	local w = Weapons[weaponId :: string]
	if not w or not RoundManager.isCombatAllowed() then
		return
	end
	local o, d = origin :: Vector3, direction :: Vector3
	if not isFiniteVector(o) or not isFiniteVector(d) or d.Magnitude < 0.5 or d.Magnitude > 1.5 then
		return
	end
	d = d.Unit

	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not aliveHumanoid(character) or not head then
		return
	end
	if (o - head.Position).Magnitude > V.MaxOriginOffset then
		return
	end

	local tool = getEquippedTool(player, w.Id)
	if not tool then
		return
	end

	local now = os.clock()
	local times = lastFire[player]
	if not times then
		times = {}
		lastFire[player] = times
	end
	if now - (times[w.Id] or 0) < w.FireInterval * V.FireIntervalTolerance then
		return
	end
	if not consumeAmmo(tool, w) then
		return
	end
	times[w.Id] = now

	HANDLERS[w.Kind](player, w, o, d, claimed :: Instance?, seed :: number?)
end

function CombatManager.init()
	combatEvent = Remotes.get("CombatEvent")
	Remotes.get("WeaponFire").OnServerEvent:Connect(onFire)
	Remotes.get("WeaponReload").OnServerEvent:Connect(onReload)
	Players.PlayerRemoving:Connect(function(p)
		lastFire[p] = nil
	end)
	Projectiles.init(function(owner, weaponId, position, projectileId)
		if projectileId then
			combatEvent:FireAllClients({ Type = "ProjectileEnd", Id = projectileId })
		end
		CombatManager.explodeAt(owner, weaponId, position)
	end)
	RoundManager.StateChanged:Connect(function(state)
		if state == "Ended" then
			Projectiles.clearAll()
		end
	end)
end

return CombatManager
