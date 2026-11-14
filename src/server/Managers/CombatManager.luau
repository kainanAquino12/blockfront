--[[
	CombatManager (servidor)
	Toda decisão de combate acontece aqui. O cliente só envia a intenção
	(WeaponFire: arma, origem, direção, alvo sugerido) e o servidor valida:
	  - partida permite combate, jogador vivo, arma realmente equipada
	  - cadência (FireInterval com tolerância de latência)
	  - munição (contada no servidor, publicada como atributos da Tool)
	  - origem perto da cabeça, direção unitária e finita
	Depois o próprio servidor faz o raycast/simulação e aplica o dano.

	Dano em jogadores: sem fogo amigo; o próprio jogador recebe dano
	reduzido das suas explosões. Abate dá ponto à equipe (RoundManager)
	e soma Abates/Mortes (TeamManager).

	Atributos da Tool (lidos pelo cliente/HUD):
	  WeaponId, Ammo, Reserve, Reloading
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
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
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("WeaponId") == weaponId then
		return tool
	end
	return nil
end

local function aliveHumanoid(character: Model?): Humanoid?
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

local function characterFromPart(part: Instance?): (Model?, Player?)
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return model, player
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

---------------------------------------------------------------------------
-- Dano e abates
---------------------------------------------------------------------------

--[[
	Aplica dano respeitando times. Retorna true se causou dano.
	Registra o abate quando a vida chega a zero.
]]
function CombatManager.damagePlayer(attacker: Player?, victim: Player, amount: number, weaponId: string, headshot: boolean?): boolean
	local humanoid = aliveHumanoid(victim.Character)
	if not humanoid or amount <= 0 then
		return false
	end
	if attacker and attacker ~= victim and attacker.Team ~= nil and attacker.Team == victim.Team then
		return false -- sem fogo amigo
	end
	if victim.Character:FindFirstChildOfClass("ForceField") then
		return false -- proteção de spawn
	end

	humanoid:TakeDamage(amount)

	if attacker and attacker ~= victim then
		combatEvent:FireClient(attacker, { Type = "Hit", Headshot = headshot == true, Lethal = humanoid.Health <= 0 })
	end

	if humanoid.Health <= 0 and not killedHumanoids[humanoid] then
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

-- Explosão completa: destrói estrutura e fere jogadores (queda linear até a borda).
function CombatManager.explodeAt(owner: Player?, weaponId: string, position: Vector3)
	local w = Weapons[weaponId]
	local radius = w.ExplosionRadius
	DestructionManager.explode(position, radius, w.StructureDamage, "Explosion")

	for _, victim in Players:GetPlayers() do
		local root = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = (root.Position - position).Magnitude
			if d <= radius then
				local t = d / radius
				local dmg = w.PlayerDamage * (1 - t * (1 - WeaponConfig.ExplosionFalloffMin))
				if victim == owner then
					dmg *= w.SelfDamageMultiplier or 1
				end
				-- Atrás de uma parede, a explosão fere bem menos.
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { workspace:FindFirstChild("DestructibleObjects") }
				if workspace:Raycast(position, root.Position - position, params) then
					dmg *= 0.35
				end
				CombatManager.damagePlayer(owner, victim, dmg, weaponId)
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
		-- Recarga só conclui se a arma continua com o jogador.
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

local function fireHitscan(player: Player, w, origin: Vector3, direction: Vector3, claimed: Instance?)
	local params = rayParamsExcluding(player)
	local result = workspace:Raycast(origin, direction * w.Range, params)
	local hitPos = if result then result.Position else origin + direction * w.Range

	local victimChar, victim = nil, nil
	local hitPart: BasePart? = nil
	if result then
		victimChar, victim = characterFromPart(result.Instance)
		hitPart = result.Instance :: BasePart
	end

	-- "Favor do atirador": o servidor não viu o alvo (latência), mas o
	-- cliente afirma ter acertado. Aceita se o alvo está perto da linha
	-- do tiro e nada sólido bloqueia o caminho até ele.
	if not victim and typeof(claimed) == "Instance" and (claimed :: Instance):IsA("BasePart") then
		local cChar, cPlayer = characterFromPart(claimed :: Instance)
		if cPlayer and cPlayer ~= player then
			local p = (claimed :: BasePart).Position
			local along = (p - origin):Dot(direction)
			local closest = origin + direction * along
			if along > 0 and along <= w.Range and (p - closest).Magnitude <= V.ClaimMaxRayDistance then
				local blockParams = rayParamsExcluding(player)
				blockParams:AddToFilter(cChar)
				local blocked = workspace:Raycast(origin, p - origin, blockParams)
				if not blocked then
					victimChar, victim, hitPart = cChar, cPlayer, claimed :: BasePart
					hitPos = p
				end
			end
		end
	end

	if victim then
		local headshot = hitPart ~= nil and hitPart.Name == "Head"
		local dmg = w.PlayerDamage * (if headshot then w.HeadshotMultiplier else 1)
		CombatManager.damagePlayer(player, victim, dmg, w.Id, headshot)
	elseif result and isStructurePart(result.Instance) then
		DestructionManager.explode(result.Position + direction * 0.4, w.StructureRadius, w.StructureDamage, "Impact")
	end

	combatEvent:FireAllClients({ Type = "Shot", Shooter = player, Weapon = w.Id, Origin = origin, Hit = hitPos })
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
	if result then
		local _, victim = characterFromPart(result.Instance)
		if victim then
			CombatManager.damagePlayer(player, victim, w.PlayerDamage, w.Id, false)
		elseif isStructurePart(result.Instance) then
			DestructionManager.explode(result.Position + direction * 0.6, w.StructureRadius, w.StructureDamage, "Impact")
		end
	end
	combatEvent:FireAllClients({ Type = "Swing", Shooter = player, Weapon = w.Id, Origin = origin, Hit = result and result.Position })
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

local function onFire(player: Player, weaponId: unknown, origin: unknown, direction: unknown, claimed: unknown)
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
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

	HANDLERS[w.Kind](player, w, o, d, claimed :: Instance?)
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
