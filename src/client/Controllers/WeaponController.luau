--[[
	WeaponController (cliente)
	Entrada das armas:
	  botão esquerdo  atira (segurar = automático)
	  botão direito   mira (ADS)
	  R               recarrega
	  1-5 / roda      troca de arma (o hotbar padrão do Roblox fica desligado)

	Arquitetura do disparo (mira e tiro sempre alinhados):
	  1. origem = posição da câmera; direção = centro da tela (LookVector)
	  2. dispersão atual aplicada no cliente (escopeta: semente dos chumbos)
	  3. o cliente desenha o próprio tiro na hora com o mesmo raycast
	  4. envia WeaponFire; o servidor valida, refaz o raycast e aplica o dano

	Dispersão atual = Hip..Aim (pela mira) + Move (movimento/pulo) + Bloom
	(acumula por tiro e se recupera). O HUD desenha o retículo com ela.
	O cliente prevê munição e cadência; a munição oficial vem dos
	atributos da Tool (servidor).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local WeaponMath = require(ReplicatedStorage.Shared.Modules.WeaponMath)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local AimController = require(script.Parent.AimController)
local AudioController = require(script.Parent.AudioController)
local CombatEffects = require(script.Parent.CombatEffects)

local player = Players.LocalPlayer
local rng = Random.new()

local WeaponController = {}

local fireRemote: RemoteEvent
local reloadRemote: RemoteEvent

local tool: Tool? = nil
local weapon = nil
local localAmmo = 0
local lastFire = 0
local readyAt = 0 -- fim da animação de equipar
local triggerDown = false
local aimHeld = false
local bloom = 0
local toolConns: { RBXScriptConnection } = {}
local menuBlocked = false

local changed = Instance.new("BindableEvent")
WeaponController.Changed = changed.Event -- HUD escuta munição/arma

function WeaponController.getState()
	if not tool or not weapon then
		return nil
	end
	return {
		Weapon = weapon,
		Ammo = localAmmo,
		Reserve = tool:GetAttribute("Reserve") or 0,
		Reloading = tool:GetAttribute("Reloading") == true,
		ReloadProgress = WeaponController.getReloadProgress(),
	}
end

local reloadStart = 0
function WeaponController.getReloadProgress(): number
	if not tool or not weapon or not weapon.ReloadTime or not tool:GetAttribute("Reloading") then
		return 0
	end
	return math.clamp((os.clock() - reloadStart) / weapon.ReloadTime, 0, 1)
end

-- Dispersão atual (graus) — usada no tiro e no retículo.
function WeaponController.getSpread(): number
	if not weapon then
		return 0
	end
	local sp = weapon.Spread
	local aim = AimController.getAlpha()
	local base = sp.Hip + (sp.Aim - sp.Hip) * aim
	return base + sp.Move * MovementController.getMoveFactor() * (1 - aim * 0.6) + bloom
end

-- Bloqueia a entrada das armas (menu aberto).
function WeaponController.setBlocked(value: boolean)
	menuBlocked = value
	AimController.setBlocked(value)
	if value then
		triggerDown = false
		aimHeld = false
		AimController.setHeld(false)
	end
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

local function aimParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { workspace.CurrentCamera }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	for _, name in { "DebrisCache", "Grenades", "LocalEffects" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function claimedTarget(result: RaycastResult?): Instance?
	if not result then
		return nil
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return result.Instance
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function toolsBySlot(): { [number]: Tool }
	local out = {}
	local function scan(container: Instance?)
		if not container then
			return
		end
		for _, t in container:GetChildren() do
			if t:IsA("Tool") then
				local slot = t:GetAttribute("Slot")
				if typeof(slot) == "number" then
					out[slot] = t
				end
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)
	return out
end

function WeaponController.getSlots(): { [number]: Tool }
	return toolsBySlot()
end

local function equipSlot(slot: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local t = toolsBySlot()[slot]
	if t and t ~= tool then
		humanoid:EquipTool(t)
	end
end

---------------------------------------------------------------------------
-- Recarga e disparo
---------------------------------------------------------------------------

local function requestReload()
	if not tool or not weapon or not weapon.ReloadTime then
		return
	end
	if tool:GetAttribute("Reloading") or (tool:GetAttribute("Reserve") or 0) <= 0 then
		return
	end
	if localAmmo >= weapon.MagSize then
		return
	end
	reloadRemote:FireServer(weapon.Id)
	-- armas com carregador animado tocam MagOut/MagIn/Charge no ritmo da animação
	-- (ViewmodelController); as outras tocam o som único de recarga
	if not weapon.Sounds.MagOut then
		AudioController.play(weapon.Sounds.Reload, nil, { Volume = 0.7 })
	end
end

local function fire()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not weapon or not humanoid or humanoid.Health <= 0 or menuBlocked then
		return
	end
	local now = os.clock()
	if now < readyAt or now - lastFire < weapon.FireInterval then
		return
	end
	if MovementController.isSprinting() then
		MovementController.blockSprint(0.35)
		return
	end
	if weapon.Kind ~= "Melee" then
		if tool:GetAttribute("Reloading") then
			return
		end
		if localAmmo <= 0 then
			lastFire = now
			if (tool:GetAttribute("Reserve") or 0) > 0 then
				requestReload()
			else
				AudioController.play(weapon.Sounds.Dry, nil, { Volume = 0.6 })
			end
			return
		end
		localAmmo -= 1
	end
	lastFire = now
	MovementController.blockSprint(0.3)

	local camCF = workspace.CurrentCamera.CFrame
	local origin = camCF.Position
	local spreadDeg = WeaponController.getSpread()
	local direction = WeaponMath.spread(camCF.LookVector, spreadDeg, rng)
	local muzzlePos = ViewmodelController.getMuzzlePosition() or origin
	local recoil = weapon.Recoil

	if weapon.Kind == "Hitscan" then
		local params = aimParams()
		local seed = nil
		local dirs = { direction }
		if weapon.Pellets and weapon.Pellets > 1 then
			seed = rng:NextInteger(1, 2 ^ 30)
			dirs = WeaponMath.pelletDirections(direction, seed, weapon.Pellets, weapon.PelletSpread)
		end
		local claimed = nil
		local hits = {}
		for i, d in dirs do
			local result = workspace:Raycast(origin, d * weapon.Range, params)
			if i == 1 then
				claimed = claimedTarget(result)
			end
			table.insert(hits, {
				Position = if result then result.Position else origin + d * weapon.Range,
				Material = if result then (if claimedTarget(result) then "Body" else result.Material.Name) else "",
				Normal = result and result.Normal,
			})
		end
		CombatEffects.playShot(weapon, muzzlePos, hits, true)
		if weapon.Sounds.Layer then
			AudioController.play(weapon.Sounds.Layer, nil, { Volume = 0.35, Vary = 0.06 })
		end
		if weapon.Sounds.Shell and rng:NextNumber() < 0.6 then
			local shell = weapon.Sounds.Shell
			task.delay(0.28 + rng:NextNumber() * 0.15, function()
				AudioController.play(shell, nil, { Volume = 0.22, Vary = 0.15 })
			end)
		end
		fireRemote:FireServer(weapon.Id, origin, direction, claimed, seed)
		bloom = math.min(bloom + weapon.Spread.Bloom, weapon.Spread.BloomMax)
		CameraController.addRecoil(recoil.Pitch, recoil.Yaw, recoil.Recovery)
		ViewmodelController.kick()
		if weapon.Sounds.Cycle then
			task.delay(0.32, function()
				if tool and weapon and weapon.Sounds.Cycle then
					ViewmodelController.cycle()
					AudioController.play(weapon.Sounds.Cycle, nil, { Volume = 0.6 })
				end
			end)
		end
	elseif weapon.Kind == "Melee" then
		ViewmodelController.swing()
		AudioController.play(weapon.Sounds.Fire, nil, { Volume = 0.8, Vary = 0.08 })
		-- impacto local imediato (o servidor decide o dano)
		local params = aimParams()
		local result = workspace:Spherecast(origin, 1.2, direction * weapon.Range, params)
		if result then
			task.delay(0.12, function()
				CombatEffects.meleeImpact(result.Position, if claimedTarget(result) then "Body" else result.Material.Name)
			end)
		end
		fireRemote:FireServer(weapon.Id, origin, direction)
	elseif weapon.Kind == "Throwable" then
		ViewmodelController.throw()
		AudioController.play(weapon.Sounds.Fire, nil, { Volume = 0.8 })
		fireRemote:FireServer(weapon.Id, origin, direction)
	else -- Projectile
		AudioController.play(weapon.Sounds.Fire, nil, { Volume = 0.9 })
		CameraController.addRecoil(recoil.Pitch, recoil.Yaw, recoil.Recovery)
		ViewmodelController.kick()
		CombatEffects.muzzleFlash(muzzlePos, 1.6)
		fireRemote:FireServer(weapon.Id, origin, direction)
	end

	changed:Fire()
	if weapon.Kind ~= "Melee" and weapon.Kind ~= "Throwable" and localAmmo <= 0 then
		task.delay(0.25, requestReload)
	end
end

---------------------------------------------------------------------------
-- Equipar
---------------------------------------------------------------------------

local function unequip()
	for _, c in toolConns do
		c:Disconnect()
	end
	table.clear(toolConns)
	tool, weapon = nil, nil
	triggerDown = false
	bloom = 0
	ViewmodelController.setWeapon(nil)
	MovementController.setWeaponMultiplier(1)
	MovementController.setReloading(false)
	changed:Fire()
end

local function equip(t: Tool)
	unequip()
	local id = t:GetAttribute("WeaponId")
	local w = id and WeaponConfig.Weapons[id]
	if not w then
		return
	end
	tool, weapon = t, w
	localAmmo = t:GetAttribute("Ammo") or 0
	readyAt = os.clock() + (w.Viewmodel and w.Viewmodel.EquipTime or 0.3)
	ViewmodelController.setWeapon(w.Id)
	MovementController.setWeaponMultiplier(w.WalkMultiplier or 1)
	AudioController.play(w.Sounds.Equip, nil, { Volume = 0.5 })

	-- Munição oficial: só pode diminuir a prevista, exceto após recarga.
	table.insert(toolConns, t:GetAttributeChangedSignal("Ammo"):Connect(function()
		local official = t:GetAttribute("Ammo") or 0
		if official < localAmmo or (official > localAmmo and not t:GetAttribute("Reloading")) then
			localAmmo = official
		end
		changed:Fire()
	end))
	table.insert(toolConns, t:GetAttributeChangedSignal("Reloading"):Connect(function()
		local r = t:GetAttribute("Reloading") == true
		if r then
			reloadStart = os.clock()
		else
			localAmmo = t:GetAttribute("Ammo") or 0
		end
		MovementController.setReloading(r)
		changed:Fire()
	end))
	table.insert(toolConns, t:GetAttributeChangedSignal("Reserve"):Connect(function()
		changed:Fire()
	end))
	changed:Fire()
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			equip(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child == tool then
			unequip()
		end
	end)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(unequip)
	-- Começa com a arma principal na mão.
	task.delay(0.6, function()
		if player.Character == character and not tool then
			equipSlot(1)
		end
	end)
end

function WeaponController.init()
	fireRemote = Remotes.get("WeaponFire")
	reloadRemote = Remotes.get("WeaponReload")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	local keySlots = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
	}

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or menuBlocked then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerDown = true
			fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimHeld = true
			AimController.setHeld(true)
		elseif input.KeyCode == Enum.KeyCode.R then
			requestReload()
		elseif keySlots[input.KeyCode] then
			equipSlot(keySlots[input.KeyCode])
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimHeld = false
			AimController.setHeld(false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or menuBlocked or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		local current = tool and tool:GetAttribute("Slot") or 1
		local slots = toolsBySlot()
		local dir = if input.Position.Z > 0 then -1 else 1
		for i = 1, 5 do
			local s = ((current - 1 + dir * i) % 5) + 1
			if slots[s] then
				equipSlot(s)
				break
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if weapon then
			bloom = math.max(0, bloom - weapon.Spread.BloomRecovery * dt)
		end
		if triggerDown and weapon and weapon.Automatic then
			fire()
		end
	end)
end

return WeaponController
