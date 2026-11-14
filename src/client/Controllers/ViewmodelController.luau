--[[
	ViewmodelController (cliente) — arma e braços em primeira pessoa.
	Só o jogador local vê. Usa o mesmo modelo em blocos da Tool
	(WeaponModels), em escala menor, preso à câmera, com braços em blocos
	na cor do time segurando a arma.

	Animações procedurais (sem assets):
	  troca de arma (sobe da parte de baixo da tela), balanço ao andar,
	  inércia ao girar a câmera, recuo com tranco da câmera, recarga
	  (abaixa e inclina), golpe da marreta, arremesso da granada e mira
	  (botão direito: arma vai ao centro e o campo de visão fecha).

	A Tool real continua na mão do personagem para os outros jogadores;
	localmente ela é escondida (LocalTransparencyModifier).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)

local player = Players.LocalPlayer

local ViewmodelController = {}

local BASE_FOV = 80
local SKIN = Color3.fromRGB(234, 190, 150)
local SHOULDER_R = Vector3.new(0.6, -1.25, -0.75)
local SHOULDER_L = Vector3.new(-0.2, -1.25, -0.95)
local ARM_WIDTH = 0.12

local model: Model? = nil
local handle: BasePart? = nil
local weaponId: string? = nil
local vmCfg = nil
local arms: { [string]: BasePart } = {}
local folder: Model

-- Estado das animações
local equipAlpha = 0
local aimAlpha = 0
local aiming = false
local reloadAlpha = 0
local recoil = 0 -- recuo da arma (0..1+)
local camKick = 0 -- tranco da câmera (radianos)
local swingT = -1
local throwT = -1
local bobT = 0
local swayX, swayY = 0, 0
local lastCamCF: CFrame? = nil

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function makeArmPart(name: string, color: Color3, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function teamColor(): Color3
	local team = player.Team and player.Team.Name
	local def = team and GameConfig.Teams[team]
	return if def then def.Color else Color3.fromRGB(90, 90, 90)
end

local function clearModel()
	if model then
		model:Destroy()
	end
	model, handle, weaponId, vmCfg = nil, nil, nil, nil
	for _, a in arms do
		a.Transparency = 1
	end
end

function ViewmodelController.setWeapon(id: string?)
	clearModel()
	aiming = false
	if not id then
		return
	end
	local cfg = WeaponConfig.Viewmodel[id]
	if not cfg then
		return
	end
	local h = WeaponModels.build(id, false)
	local m = Instance.new("Model")
	m.Name = "Viewmodel_" .. id
	h.Parent = m
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = false
		end
	end
	m.PrimaryPart = h
	m:ScaleTo(cfg.Scale)
	m.Parent = folder
	model, handle, weaponId, vmCfg = m, h, id, cfg

	local color = teamColor()
	arms.SleeveR.Color = color
	arms.SleeveL.Color = color
	arms.SleeveR.Transparency = 0
	arms.HandR.Transparency = 0
	local hasLeft = h:FindFirstChild("LeftHand") ~= nil
	arms.SleeveL.Transparency = if hasLeft then 0 else 1
	arms.HandL.Transparency = if hasLeft then 0 else 1

	equipAlpha = 0
	recoil, swingT, throwT = 0, -1, -1
end

function ViewmodelController.setAiming(on: boolean)
	aiming = on and vmCfg ~= nil and vmCfg.Aim ~= nil
end

function ViewmodelController.isAiming(): boolean
	return aiming
end

-- Recuo: kind define a força (rifle leve, foguete forte).
function ViewmodelController.kick(kind: string)
	if kind == "Hitscan" then
		recoil = math.min(recoil + 0.35, 1.2)
		camKick += math.rad(0.9)
	elseif kind == "Projectile" then
		recoil = 1.5
		camKick += math.rad(5)
	end
end

function ViewmodelController.swing()
	swingT = 0
end

function ViewmodelController.throw()
	throwT = 0
end

function ViewmodelController.getMuzzlePosition(): Vector3?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	return muzzle and muzzle.WorldPosition
end

local function placeArm(sleeve: BasePart, hand: BasePart, shoulder: Vector3, handCF: CFrame)
	local handPos = handCF.Position
	local len = (handPos - shoulder).Magnitude
	sleeve.Size = Vector3.new(ARM_WIDTH, ARM_WIDTH, math.max(len - 0.08, 0.05))
	sleeve.CFrame = CFrame.lookAt((shoulder + handPos) / 2, handPos)
	hand.CFrame = handCF
end

local function hideOwnTool(character: Model)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
	local vest = character:FindFirstChild("TeamVest")
	if vest then
		for _, d in vest:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end

local function render(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Tranco da câmera (o módulo de câmera reescreve o CFrame a cada frame,
	-- então isso é só visual e volta sozinho).
	camKick = lerp(camKick, 0, math.min(dt * 10, 1))
	if camKick > 1e-4 then
		camera.CFrame *= CFrame.Angles(camKick, 0, 0)
	end

	aimAlpha = lerp(aimAlpha, if aiming then 1 else 0, math.min(dt * 14, 1))
	local aimFov = vmCfg and vmCfg.AimFov or BASE_FOV
	camera.FieldOfView = lerp(BASE_FOV, aimFov, aimAlpha)

	if character then
		hideOwnTool(character)
	end
	if not model or not handle or not vmCfg or not humanoid or humanoid.Health <= 0 then
		if model and humanoid and humanoid.Health <= 0 then
			clearModel()
		end
		return
	end

	local camCF = camera.CFrame
	equipAlpha = math.min(equipAlpha + dt / 0.25, 1)

	-- Recarga: segue o atributo oficial da Tool.
	local tool = character:FindFirstChildOfClass("Tool")
	local reloading = tool ~= nil and tool:GetAttribute("Reloading") == true
	reloadAlpha = lerp(reloadAlpha, if reloading then 1 else 0, math.min(dt * 8, 1))

	-- Balanço ao andar
	local speed = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local moving = if grounded then speed else 0
	bobT += dt * 9 * moving
	local bobAmt = 1 - aimAlpha * 0.85
	local bob = CFrame.new(math.sin(bobT) * 0.03 * moving * bobAmt, -math.abs(math.cos(bobT)) * 0.035 * moving * bobAmt, 0)

	-- Inércia ao girar
	if lastCamCF then
		local delta = lastCamCF:ToObjectSpace(camCF)
		local rx, ry = delta:ToEulerAnglesYXZ()
		swayX = lerp(swayX, math.clamp(-ry * 2, -0.12, 0.12), math.min(dt * 10, 1))
		swayY = lerp(swayY, math.clamp(-rx * 2, -0.12, 0.12), math.min(dt * 10, 1))
	end
	lastCamCF = camCF
	local sway = CFrame.Angles(swayY, swayX, 0) * CFrame.new(swayX * 0.4, swayY * 0.4, 0)

	recoil = lerp(recoil, 0, math.min(dt * 12, 1))
	local recoilCF = CFrame.new(0, recoil * 0.03, recoil * 0.14) * CFrame.Angles(recoil * 0.12, 0, 0)

	local hip: CFrame = vmCfg.Hip
	local base = if vmCfg.Aim then hip:Lerp(vmCfg.Aim, aimAlpha) else hip

	local equipCF = CFrame.new(0, -(1 - equipAlpha) * 0.8, 0) * CFrame.Angles(-(1 - equipAlpha) * 0.8, 0, 0)
	local reloadCF = CFrame.new(0, -reloadAlpha * 0.18, 0) * CFrame.Angles(-reloadAlpha * 0.35, 0, reloadAlpha * 0.45)

	local actionCF = CFrame.identity
	if swingT >= 0 then
		swingT += dt
		-- levanta (0-0.1s), desce com força (0.1-0.25s), volta (0.25-0.55s)
		local a: number
		if swingT < 0.1 then
			a = -(swingT / 0.1) * 0.4
		elseif swingT < 0.25 then
			a = -0.4 + ((swingT - 0.1) / 0.15) * 1.6
		elseif swingT < 0.55 then
			a = 1.2 * (1 - (swingT - 0.25) / 0.3)
		else
			a = 0
			swingT = -1
		end
		actionCF = CFrame.new(-a * 0.2, -a * 0.15, -a * 0.25) * CFrame.Angles(-a, 0, a * 0.3)
	elseif throwT >= 0 then
		throwT += dt
		local a: number
		if throwT < 0.12 then
			a = throwT / 0.12
			actionCF = CFrame.new(0, a * 0.15, a * 0.25) * CFrame.Angles(a * 0.6, 0, 0)
		elseif throwT < 0.3 then
			a = (throwT - 0.12) / 0.18
			actionCF = CFrame.new(-a * 0.2, 0.15 - a * 0.8, 0.25 - a * 1.0) * CFrame.Angles(0.6 - a * 1.4, 0, 0)
		elseif throwT < 0.6 then
			actionCF = CFrame.new(0, -2, 0) -- fora da tela (a próxima granada sobe em seguida)
		else
			throwT = -1
			equipAlpha = 0
		end
	end

	local final = camCF * bob * sway * base * equipCF * reloadCF * recoilCF * actionCF
	model:PivotTo(final)

	-- Braços
	local s = vmCfg.Scale
	local shoulderR = camCF:PointToWorldSpace(SHOULDER_R)
	local handRCF = final * CFrame.new(0, -0.1 * s, 0.05 * s)
	placeArm(arms.SleeveR, arms.HandR, shoulderR, handRCF)
	local lh = handle:FindFirstChild("LeftHand") :: Attachment?
	if lh then
		local shoulderL = camCF:PointToWorldSpace(SHOULDER_L)
		local handLCF = CFrame.new(lh.WorldPosition) * final.Rotation -- ScaleTo já escala os Attachments
		placeArm(arms.SleeveL, arms.HandL, shoulderL, handLCF)
	end
end

function ViewmodelController.init()
	local camera = workspace.CurrentCamera
	folder = Instance.new("Model")
	folder.Name = "Viewmodel"
	folder.Parent = camera
	arms.SleeveR = makeArmPart("SleeveR", teamColor(), Vector3.new(ARM_WIDTH, ARM_WIDTH, 1))
	arms.SleeveL = makeArmPart("SleeveL", teamColor(), Vector3.new(ARM_WIDTH, ARM_WIDTH, 1))
	arms.HandR = makeArmPart("HandR", SKIN, Vector3.new(0.13, 0.15, 0.15))
	arms.HandL = makeArmPart("HandL", SKIN, Vector3.new(0.13, 0.15, 0.15))
	for _, a in arms do
		a.Transparency = 1
	end
	camera.FieldOfView = BASE_FOV
	RunService:BindToRenderStep("BlockfrontViewmodel", Enum.RenderPriority.Camera.Value + 2, render)
end

return ViewmodelController
