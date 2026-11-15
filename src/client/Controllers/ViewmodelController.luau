--[[
	ViewmodelController (cliente) — arma e braços em primeira pessoa.
	Só o jogador local vê. Usa o mesmo modelo em blocos da Tool
	(WeaponModels), em escala menor, preso à câmera, com antebraços na cor
	do time segurando a arma.

	Poses (todas misturadas suavemente):
	  Hip     WeaponConfig.Viewmodel.Hip
	  ADS     calculada pelo Attachment "Sight" do modelo: a linha de visada
	          fica exatamente no centro da tela, a AimDistance do olho.
	          Por isso a mira fica sempre alinhada, para qualquer arma.
	  Sprint  arma baixa e inclinada
	  Parede  arma recua quando o cano encostaria numa parede (não atravessa)

	Animações procedurais (sem assets):
	  equipar (sobe de baixo), balanço ao andar, inércia ao girar, recuo por
	  arma, recarga (carregador sai e volta), bombeada/ferrolho depois do
	  tiro, ferrolho da pistola, golpe da marreta, arremesso da granada.

	Luneta: com a sniper mirada, o modelo some e o UIController desenha a
	tela da luneta.

	A Tool real continua na mão do personagem para os outros jogadores.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponModels = require(ReplicatedStorage.Shared.Modules.WeaponModels)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer

local ViewmodelController = {}

local GLOVE = Color3.fromRGB(46, 48, 56)
local ELBOW_R = Vector3.new(0.5, -1.05, -0.35)
local ELBOW_L = Vector3.new(-0.32, -1.1, -0.55)
local ARM_WIDTH = 0.2
local SPRINT_POSE = CFrame.new(0.06, -0.14, 0.05) * CFrame.Angles(math.rad(-18), math.rad(38), math.rad(16))

local folder: Model
local model: Model? = nil
local handle: BasePart? = nil
local weapon = nil
local vm = nil
local aimPose: CFrame? = nil
local parts: { BasePart } = {}
local animated: { [string]: { { part: BasePart, rel: CFrame } } } = {}
local arms: { [string]: BasePart } = {}

-- Estado das animações
local equipAlpha = 0
local aimAlpha = 0
local aiming = false
local reloadAlpha = 0
local reloadStart = 0
local wasReloading = false
local recoil = 0
local recoilRot = 0
local cycleT = -1
local slideT = -1
local swingT = -1
local throwT = -1
local bobT = 0
local swayX, swayY = 0, 0
local wallPush = 0
local lastCamCF: CFrame? = nil
local hidden = false

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
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function teamColor(): Color3
	local team = player.Team and player.Team.Name
	local def = team and GameConfig.Teams[team]
	return if def then def.Color else Color3.fromRGB(90, 90, 90)
end

local function setArmsVisible(right: boolean, left: boolean)
	arms.SleeveR.Transparency = if right then 0 else 1
	arms.HandR.Transparency = if right then 0 else 1
	arms.SleeveL.Transparency = if left then 0 else 1
	arms.HandL.Transparency = if left then 0 else 1
end

local function setHidden(value: boolean)
	if hidden == value then
		return
	end
	hidden = value
	for _, p in parts do
		p.LocalTransparencyModifier = if value then 1 else 0
	end
	for _, a in arms do
		a.LocalTransparencyModifier = if value then 1 else 0
	end
end

local function clearModel()
	if model then
		model:Destroy()
	end
	model, handle, weapon, vm, aimPose = nil, nil, nil, nil, nil
	table.clear(parts)
	table.clear(animated)
	setArmsVisible(false, false)
	hidden = false
end

function ViewmodelController.setWeapon(id: string?)
	clearModel()
	aiming = false
	if not id then
		return
	end
	local w = WeaponConfig.Weapons[id]
	if not w or not w.Viewmodel then
		return
	end
	local h = WeaponModels.build(id, false)
	local m = Instance.new("Model")
	m.Name = "Viewmodel_" .. id
	h.Parent = m
	m.PrimaryPart = h
	m:ScaleTo(w.Viewmodel.Scale)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = false
			table.insert(parts, d)
			local tag = d.Name
			if tag == "Mag" or tag == "Pump" or tag == "Slide" then
				animated[tag] = animated[tag] or {}
				table.insert(animated[tag], { part = d, rel = h.CFrame:ToObjectSpace(d.CFrame) })
			end
		end
	end
	m.Parent = folder
	model, handle, weapon, vm = m, h, w, w.Viewmodel

	-- Pose de mira a partir da linha de visada (já escalada).
	local sight = h:FindFirstChild("Sight") :: Attachment?
	if sight and vm.AimDistance then
		local s = h.CFrame:PointToObjectSpace(sight.WorldPosition)
		aimPose = CFrame.new(-s.X, -s.Y, -vm.AimDistance - s.Z)
	end

	local color = teamColor()
	arms.SleeveR.Color = color
	arms.SleeveL.Color = color
	setArmsVisible(true, h:FindFirstChild("LeftHand") ~= nil)

	equipAlpha = 0
	recoil, recoilRot, cycleT, slideT, swingT, throwT = 0, 0, -1, -1, -1, -1
	wasReloading = false
	reloadAlpha = 0
end

function ViewmodelController.canAim(): boolean
	return aimPose ~= nil
end

function ViewmodelController.setAiming(on: boolean)
	aiming = on and aimPose ~= nil
end

function ViewmodelController.isAiming(): boolean
	return aiming
end

function ViewmodelController.getAimAlpha(): number
	return aimAlpha
end

function ViewmodelController.isScoped(): boolean
	return weapon ~= nil and vm ~= nil and vm.Scope == true and aimAlpha > 0.9
end

-- Recuo visual do disparo (o recuo da câmera é do CameraController).
function ViewmodelController.kick()
	if not weapon then
		return
	end
	local k = weapon.Recoil.Kick * (1 - aimAlpha * 0.5)
	recoil = math.min(recoil + k, 2.2)
	recoilRot = math.min(recoilRot + k * 0.6, 1.6)
	if animated.Slide then
		slideT = 0
	end
end

-- Bombeada da escopeta / ferrolho da sniper.
function ViewmodelController.cycle()
	cycleT = 0
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

local function placeArm(sleeve: BasePart, hand: BasePart, elbow: Vector3, handCF: CFrame)
	local handPos = handCF.Position
	local len = (handPos - elbow).Magnitude
	sleeve.Size = Vector3.new(ARM_WIDTH, ARM_WIDTH, math.max(len - 0.05, 0.05))
	sleeve.CFrame = CFrame.lookAt((elbow + handPos) / 2, handPos)
	hand.CFrame = handCF
end

-- Desloca peças marcadas (carregador, telha, ferrolho) em relação ao Handle.
local function offsetTagged(tag: string, offset: CFrame)
	local list = animated[tag]
	if not list or not handle then
		return
	end
	for _, e in list do
		e.part.CFrame = handle.CFrame * offset * e.rel
	end
end

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

local function render(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	aimAlpha = lerp(aimAlpha, if aiming then 1 else 0, math.min(dt * 13, 1))
	CameraController.setAim(aimAlpha, vm and vm.AimFov or 80, vm and vm.AimSensitivity or 1)

	if not model or not handle or not vm or not humanoid or humanoid.Health <= 0 then
		if model and humanoid and humanoid.Health <= 0 then
			clearModel()
		end
		return
	end

	local camCF = camera.CFrame
	equipAlpha = math.min(equipAlpha + dt / (vm.EquipTime or 0.35), 1)
	local e = 1 - (1 - equipAlpha) ^ 3 -- desaceleração

	-- Recarga: acompanha o atributo oficial da Tool
	local tool = character:FindFirstChildOfClass("Tool")
	local reloading = tool ~= nil and tool:GetAttribute("Reloading") == true
	if reloading and not wasReloading then
		reloadStart = os.clock()
	end
	wasReloading = reloading
	reloadAlpha = lerp(reloadAlpha, if reloading then 1 else 0, math.min(dt * 9, 1))

	-- Balanço ao andar (menor mirando)
	local moveF = math.clamp(MovementController.getMoveFactor(), 0, 1.5)
	local sprintA = MovementController.getSprintAlpha()
	bobT += dt * (7 + moveF * 5)
	local amp = moveF * (1 - aimAlpha * 0.9) * (1 + sprintA * 0.8)
	local bob = CFrame.new(math.sin(bobT) * 0.025 * amp, -math.abs(math.cos(bobT)) * 0.03 * amp, 0)
		* CFrame.Angles(0, 0, math.sin(bobT) * 0.02 * amp)
	-- respiração parada
	local breath = CFrame.new(0, math.sin(os.clock() * 1.6) * 0.006 * (1 - aimAlpha), 0)

	-- Inércia ao girar a câmera
	if lastCamCF then
		local delta = lastCamCF:ToObjectSpace(camCF)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local sway = 1 - aimAlpha * 0.7
		swayX = lerp(swayX, math.clamp(-ry * 1.6, -0.1, 0.1) * sway, math.min(dt * 12, 1))
		swayY = lerp(swayY, math.clamp(-rx * 1.6, -0.1, 0.1) * sway, math.min(dt * 12, 1))
	end
	lastCamCF = camCF
	local swayCF = CFrame.Angles(swayY, swayX, 0) * CFrame.new(swayX * 0.3, swayY * 0.3, 0)

	-- Recuo visual
	recoil = lerp(recoil, 0, math.min(dt * 14, 1))
	recoilRot = lerp(recoilRot, 0, math.min(dt * 10, 1))
	local recoilCF = CFrame.new(0, recoil * 0.015, recoil * 0.09) * CFrame.Angles(recoilRot * 0.06, 0, 0)

	-- Pose base: hip <-> ADS, depois corrida
	local base = if aimPose then vm.Hip:Lerp(aimPose, aimAlpha) else vm.Hip
	base = base:Lerp(base * SPRINT_POSE, sprintA * (1 - aimAlpha))

	-- Não atravessar paredes: recua e baixa a arma se o cano encostaria
	wallParams.FilterDescendantsInstances = { character, folder }
	local hit = workspace:Raycast(camCF.Position, camCF.LookVector * 2.4, wallParams)
	local targetPush = if hit then math.clamp((2.4 - hit.Distance) / 2.0, 0, 1) else 0
	wallPush = lerp(wallPush, targetPush, math.min(dt * 12, 1))
	local wallCF = CFrame.new(0, -0.12 * wallPush, 0.55 * wallPush) * CFrame.Angles(math.rad(25) * wallPush, math.rad(20) * wallPush, 0)

	local equipCF = CFrame.new(0, -(1 - e) * 0.7, 0.1 * (1 - e)) * CFrame.Angles(-(1 - e) * 0.9, 0, (1 - e) * 0.3)
	local reloadCF = CFrame.new(0, -reloadAlpha * 0.12, 0) * CFrame.Angles(-reloadAlpha * 0.25, reloadAlpha * 0.15, reloadAlpha * 0.5)

	-- Bombeada / ferrolho: inclina a arma
	local cycleCF = CFrame.identity
	local pumpOffset = 0
	if cycleT >= 0 then
		cycleT += dt
		local c = cycleT / 0.45
		if c >= 1 then
			cycleT = -1
		else
			local s = math.sin(c * math.pi)
			cycleCF = CFrame.new(0, -0.03 * s, 0.04 * s) * CFrame.Angles(0.1 * s, 0, -0.25 * s)
			pumpOffset = s * 0.35
		end
	end

	-- Golpe (marreta) e arremesso (granada)
	local actionCF = CFrame.identity
	if swingT >= 0 then
		swingT += dt
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
		if throwT < 0.12 then
			local a = throwT / 0.12
			actionCF = CFrame.new(0, a * 0.15, a * 0.25) * CFrame.Angles(a * 0.6, 0, 0)
		elseif throwT < 0.3 then
			local a = (throwT - 0.12) / 0.18
			actionCF = CFrame.new(-a * 0.2, 0.15 - a * 0.8, 0.25 - a * 1.0) * CFrame.Angles(0.6 - a * 1.4, 0, 0)
		elseif throwT < 0.6 then
			actionCF = CFrame.new(0, -2, 0) -- fora da tela
		else
			throwT = -1
			equipAlpha = 0
		end
	end

	local final = camCF * swayCF * bob * breath * base * wallCF * equipCF * reloadCF * recoilCF * cycleCF * actionCF
	model:PivotTo(final)

	-- Peças animadas
	if animated.Mag and reloading then
		local p = math.clamp((os.clock() - reloadStart) / (weapon.ReloadTime or 1), 0, 1)
		local drop: number
		if p < 0.3 then
			drop = (p / 0.3) * 1.6
		elseif p < 0.6 then
			drop = 3
		elseif p < 0.85 then
			drop = 1.6 * (1 - (p - 0.6) / 0.25)
		else
			drop = 0
		end
		offsetTagged("Mag", CFrame.new(0, -drop, drop * 0.2))
	end
	if animated.Pump and pumpOffset > 0 then
		offsetTagged("Pump", CFrame.new(0, 0, pumpOffset))
	end
	if animated.Slide and slideT >= 0 then
		slideT += dt
		local s = 1 - math.clamp(slideT / 0.09, 0, 1)
		offsetTagged("Slide", CFrame.new(0, 0, 0.3 * s))
		if slideT > 0.09 then
			slideT = -1
		end
	end

	-- Braços: antebraços do cotovelo (fora da tela) até as mãos
	local sScale = vm.Scale
	local handRCF = final * CFrame.new(0, -0.08 * sScale, 0.05 * sScale)
	placeArm(arms.SleeveR, arms.HandR, camCF:PointToWorldSpace(ELBOW_R), handRCF)
	local lh = handle:FindFirstChild("LeftHand") :: Attachment?
	if lh then
		local handLCF = CFrame.new(lh.WorldPosition) * final.Rotation
		if reloading then
			-- mão esquerda vai buscar o carregador
			local p = math.clamp((os.clock() - reloadStart) / (weapon.ReloadTime or 1), 0, 1)
			local away = math.sin(math.clamp((p - 0.15) / 0.7, 0, 1) * math.pi)
			handLCF = handLCF * CFrame.new(0, -0.35 * away, 0.25 * away)
		end
		placeArm(arms.SleeveL, arms.HandL, camCF:PointToWorldSpace(ELBOW_L), handLCF)
	end

	setHidden(ViewmodelController.isScoped())
end

function ViewmodelController.init()
	local camera = workspace.CurrentCamera
	folder = Instance.new("Model")
	folder.Name = "Viewmodel"
	folder.Parent = camera
	arms.SleeveR = makeArmPart("SleeveR", teamColor(), Vector3.new(ARM_WIDTH, ARM_WIDTH, 1))
	arms.SleeveL = makeArmPart("SleeveL", teamColor(), Vector3.new(ARM_WIDTH, ARM_WIDTH, 1))
	arms.HandR = makeArmPart("HandR", GLOVE, Vector3.new(0.13, 0.15, 0.16))
	arms.HandL = makeArmPart("HandL", GLOVE, Vector3.new(0.13, 0.15, 0.16))
	RunService:BindToRenderStep("BlockfrontViewmodel", Enum.RenderPriority.Camera.Value + 1, render)
end

return ViewmodelController
