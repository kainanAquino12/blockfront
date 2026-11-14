--[[
	WeaponController (cliente)
	Entrada das armas: botão esquerdo dispara (segurar = automático no
	rifle), botão direito mira, R recarrega, 1-4 trocam de arma (hotbar
	padrão do Roblox). A arma visível em primeira pessoa é o viewmodel.

	O cliente prevê munição e cadência para responder na hora, desenha o
	próprio tiro imediatamente e envia WeaponFire ao servidor. O servidor
	tem a palavra final (munição oficial vem dos atributos da Tool).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local CameraController = require(script.Parent.CameraController)
local CombatEffects = require(script.Parent.CombatEffects)
local ViewmodelController = require(script.Parent.ViewmodelController)

local player = Players.LocalPlayer
local rng = Random.new()

local WeaponController = {}

local fireRemote: RemoteEvent
local reloadRemote: RemoteEvent

local tool: Tool? = nil
local weapon = nil
local localAmmo = 0
local lastFire = 0
local triggerDown = false
local toolConns: { RBXScriptConnection } = {}

local changed = Instance.new("BindableEvent")
WeaponController.Changed = changed.Event -- HUD escuta para atualizar munição

function WeaponController.getState()
	if not tool or not weapon then
		return nil
	end
	return {
		Weapon = weapon,
		Ammo = localAmmo,
		Reserve = tool:GetAttribute("Reserve") or 0,
		Reloading = tool:GetAttribute("Reloading") == true,
	}
end

local function aimParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
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

-- Ponto do mundo sob a mira (centro da tela).
local function aimPoint(): Vector3
	local ray = CameraController.getAimRay()
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, aimParams())
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

local function spread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local angle = math.rad(rng:NextNumber(0, degrees))
	local roll = rng:NextNumber(0, math.pi * 2)
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

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
	CombatEffects.playSoundAt(weapon.Sounds.Reload, nil, 0.6)
end

local function fire()
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not weapon or not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastFire < weapon.FireInterval then
		return
	end
	if weapon.Kind ~= "Melee" then
		if tool:GetAttribute("Reloading") then
			return
		end
		if localAmmo <= 0 then
			requestReload()
			return
		end
		localAmmo -= 1
	end
	lastFire = now

	local origin = head.Position
	local direction = (aimPoint() - origin).Unit
	local muzzlePos = ViewmodelController.getMuzzlePosition() or origin

	if weapon.Kind == "Hitscan" then
		local spreadDeg = weapon.SpreadDegrees * (if ViewmodelController.isAiming() then 0.25 else 1)
		direction = spread(direction, spreadDeg)
		local result = workspace:Raycast(origin, direction * weapon.Range, aimParams())
		local hitPos = if result then result.Position else origin + direction * weapon.Range
		local claimed = nil
		if result and result.Instance:FindFirstAncestorOfClass("Model") then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and Players:GetPlayerFromCharacter(model) then
				claimed = result.Instance
			end
		end
		CombatEffects.playShot(weapon, muzzlePos, hitPos, true)
		ViewmodelController.kick(weapon.Kind)
		fireRemote:FireServer(weapon.Id, origin, direction, claimed)
	elseif weapon.Kind == "Melee" then
		ViewmodelController.swing()
		CombatEffects.playSoundAt(weapon.Sounds.Fire, nil, 0.8)
		fireRemote:FireServer(weapon.Id, origin, direction)
	elseif weapon.Kind == "Throwable" then
		ViewmodelController.throw()
		CombatEffects.playSoundAt(weapon.Sounds.Fire, nil, 0.8)
		fireRemote:FireServer(weapon.Id, origin, direction)
	else
		ViewmodelController.kick(weapon.Kind)
		CombatEffects.playSoundAt(weapon.Sounds.Fire, nil, 0.9)
		fireRemote:FireServer(weapon.Id, origin, direction)
	end

	changed:Fire()
	if weapon.Kind ~= "Melee" and localAmmo <= 0 then
		task.delay(0.15, requestReload)
	end
end

local function unequip()
	for _, c in toolConns do
		c:Disconnect()
	end
	table.clear(toolConns)
	tool, weapon = nil, nil
	triggerDown = false
	ViewmodelController.setWeapon(nil)
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
	-- Munição oficial do servidor: só pode diminuir a prevista, exceto
	-- depois de uma recarga (quando aumenta).
	table.insert(toolConns, t:GetAttributeChangedSignal("Ammo"):Connect(function()
		local official = t:GetAttribute("Ammo") or 0
		if official > localAmmo and not t:GetAttribute("Reloading") then
			localAmmo = official
		elseif official < localAmmo then
			localAmmo = official
		end
		changed:Fire()
	end))
	table.insert(toolConns, t:GetAttributeChangedSignal("Reloading"):Connect(function()
		if not t:GetAttribute("Reloading") then
			localAmmo = t:GetAttribute("Ammo") or 0
		end
		changed:Fire()
	end))
	table.insert(toolConns, t:GetAttributeChangedSignal("Reserve"):Connect(function()
		changed:Fire()
	end))
	ViewmodelController.setWeapon(w.Id)
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
end

function WeaponController.init()
	fireRemote = Remotes.get("WeaponFire")
	reloadRemote = Remotes.get("WeaponReload")

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerDown = true
			fire()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			ViewmodelController.setAiming(true)
		elseif input.KeyCode == Enum.KeyCode.R then
			requestReload()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			triggerDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			ViewmodelController.setAiming(false)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if triggerDown and weapon and weapon.Automatic then
			fire()
		end
	end)
end

return WeaponController
