--[[
	ViewmodelController (cliente) — arma e braços em primeira pessoa.
	Só o jogador local vê. Usa o mesmo modelo em blocos da Tool
	(WeaponModels), em escala menor, preso à câmera.

	Braços (rig com IK de 2 ossos, V4):
	  ombro -> braço -> cotovelo -> antebraço -> mão
	  - os ombros ficam fixos no espaço da câmera, fora da tela (embaixo e
	    para os lados); as mãos vão para a empunhadura (Handle) e para o
	    Attachment "LeftHand" da arma; o cotovelo é calculado (IK analítico)
	    e aponta para baixo/para fora.
	  - todas as medidas do braço ficam em ARM (uma escala só, a do
	    viewmodel), não por arma.
	  - manga em cor de uniforme neutra; braçadeira fina na cor do time.

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
local AimController = require(script.Parent.AimController)

local player = Players.LocalPlayer

local ViewmodelController = {}

local GLOVE = Color3.fromRGB(34, 35, 37)
local GLOVE_PAD = Color3.fromRGB(52, 54, 57)
local SKIN = Color3.fromRGB(198, 142, 108)
local UNIFORM = Color3.fromRGB(112, 114, 92) -- manga camuflada (igual para os dois times)
local UNIFORM_DARK = Color3.fromRGB(92, 94, 76)
local CAMO = { Color3.fromRGB(64, 70, 50), Color3.fromRGB(150, 140, 110), Color3.fromRGB(46, 48, 38), Color3.fromRGB(96, 104, 76) }

-- Medidas do braço no espaço do viewmodel (studs, relativas à câmera).
-- Ombros fora do campo de visão; comprimentos chegam à empunhadura de todas
-- as armas com folga (se não chegar, o braço estica um pouco em vez de soltar
-- a mão da arma).
local ARM = {
	ShoulderR = Vector3.new(0.62, -0.95, -0.05),
	ShoulderL = Vector3.new(-0.62, -0.92, -0.1),
	PoleR = Vector3.new(0.6, -1, 0.2), -- direção para onde o cotovelo aponta
	PoleL = Vector3.new(-0.9, -1, 0.1),
	Upper = 0.68,
	Fore = 0.6,
	UpperWidth = 0.23,
	ForeWidth = 0.2, -- manga do antebraço (perto do cotovelo); afina até o punho
	CuffWidth = 0.185,
	BandWidth = 0.24,
	HandScale = 1.55, -- mãos proporcionais ao antebraço grosso
}

--[[
	Mãos (V9): luva tática sem dedos, 5 dedos reconhecíveis, pontas de pele.
	Cada peça é { nome, tamanho, CFrame local, cor } no referencial da mão,
	que usa os mesmos eixos da arma (-Z = cano, +Y = cima, +X = direita).

	Mão DIREITA (origem = empunhadura/pistol grip):
	  dorso da mão do lado de fora (+X), palma do lado de dentro (-X),
	  4 dedos dobrados em volta da frente da empunhadura (-Z), indicador
	  estendido no guarda-mato (gatilho), polegar por cima do lado esquerdo.
	Mão ESQUERDA (origem = Attachment "LeftHand" no guarda-mão):
	  palma por baixo do guarda-mão, polegar no lado esquerdo, 4 dedos
	  subindo pelo lado direito com as pontas por cima.
]]
local function fingerR(y: number, z: number, curl: number): { any }
	-- falange (luva) atravessando a frente da empunhadura + ponta de pele no lado de dentro
	return {
		{ "Dedo", Vector3.new(0.088, 0.021, 0.024), CFrame.new(0.002, y, z) * CFrame.Angles(0, 0, curl), GLOVE },
		{ "Ponta", Vector3.new(0.02, 0.019, 0.022), CFrame.new(-0.05, y - 0.004, z + 0.012), SKIN },
	}
end
local HAND_R = {
	{ "Dorso", Vector3.new(0.034, 0.1, 0.118), CFrame.new(0.046, 0.004, 0.006), GLOVE },
	{ "Protecao", Vector3.new(0.012, 0.072, 0.07), CFrame.new(0.066, 0.012, 0.0), GLOVE_PAD },
	{ "Palma", Vector3.new(0.03, 0.098, 0.1), CFrame.new(-0.036, 0.0, 0.012), GLOVE },
	{ "Punho", Vector3.new(0.1, 0.094, 0.034), CFrame.new(0.004, -0.004, 0.072), GLOVE_PAD },
	{ "Relogio", Vector3.new(0.024, 0.05, 0.03), CFrame.new(0.058, 0.0, 0.074), Color3.fromRGB(70, 74, 78) },
	-- polegar: por cima do lado esquerdo, apontando para o cano
	{ "Polegar", Vector3.new(0.024, 0.024, 0.06), CFrame.new(-0.05, 0.05, -0.03) * CFrame.Angles(0, math.rad(-8), 0), GLOVE },
	{ "PolegarPonta", Vector3.new(0.022, 0.022, 0.024), CFrame.new(-0.054, 0.05, -0.07), SKIN },
	-- indicador estendido no gatilho
	{ "Indicador", Vector3.new(0.022, 0.022, 0.062), CFrame.new(-0.028, 0.044, -0.052), GLOVE },
	{ "IndicadorPonta", Vector3.new(0.021, 0.021, 0.024), CFrame.new(-0.028, 0.044, -0.094), SKIN },
}
for i, y in { 0.018, -0.008, -0.034 } do
	for _, piece in fingerR(y, -0.058, math.rad(-4 + i * 3)) do
		table.insert(HAND_R, piece)
	end
end

local HAND_L = {
	{ "Palma", Vector3.new(0.104, 0.03, 0.118), CFrame.new(0.004, -0.06, 0.0), GLOVE },
	{ "Dorso", Vector3.new(0.03, 0.08, 0.11), CFrame.new(-0.058, -0.03, 0.004), GLOVE },
	{ "Protecao", Vector3.new(0.012, 0.06, 0.07), CFrame.new(-0.078, -0.028, 0.0), GLOVE_PAD },
	{ "Punho", Vector3.new(0.092, 0.088, 0.034), CFrame.new(-0.02, -0.07, 0.07), GLOVE_PAD },
	{ "Polegar", Vector3.new(0.024, 0.024, 0.07), CFrame.new(-0.06, 0.02, -0.03), GLOVE },
	{ "PolegarPonta", Vector3.new(0.022, 0.022, 0.024), CFrame.new(-0.06, 0.022, -0.075), SKIN },
}
for i, z in { -0.042, -0.014, 0.014, 0.04 } do
	table.insert(HAND_L, { "Dedo" .. i, Vector3.new(0.024, 0.074, 0.024), CFrame.new(0.06, -0.02, z), GLOVE })
	table.insert(HAND_L, { "Ponta" .. i, Vector3.new(0.022, 0.022, 0.022), CFrame.new(0.05, 0.03, z) * CFrame.Angles(0, 0, math.rad(-35)), SKIN })
end

-- Manchas da camuflagem (frações ao longo do segmento, lado e tamanho).
-- { t (0 = ombro/cotovelo, 1 = punho), lado Y (+1 cima / -1 baixo), lado X, comprimento relativo, cor }
local CAMO_PATCHES = {
	{ 0.12, 1, 0, 0.2, 1 }, { 0.32, -1, 1, 0.16, 2 }, { 0.5, 1, -1, 0.22, 3 },
	{ 0.66, -1, 0, 0.18, 4 }, { 0.82, 1, 1, 0.14, 2 }, { 0.42, 0, -1, 0.14, 1 },
	{ 0.2, 0, 1, 0.16, 3 }, { 0.58, 0, 1, 0.14, 2 }, { 0.75, 0, -1, 0.16, 4 }, { 0.9, -1, 0, 0.1, 1 },
}
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
local aimAlpha = 0 -- cópia local do AimController.getAlpha() a cada quadro
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
	for name, part in arms do
		local isLeft = string.sub(name, -1) == "L"
		part.Transparency = if (isLeft and left) or (not isLeft and right) then 0 else 1
	end
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
	AimController.setWeapon(false)
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
	AimController.setWeapon(aimPose ~= nil, vm.AimFov, vm.AimSensitivity, vm.Scope)

	-- braçadeira: única peça na cor do time (dessaturada)
	local band = teamColor():Lerp(UNIFORM, 0.35)
	arms.BandR.Color = band
	arms.BandL.Color = band
	setArmsVisible(true, h:FindFirstChild("LeftHand") ~= nil)

	equipAlpha = 0
	recoil, recoilRot, cycleT, slideT, swingT, throwT = 0, 0, -1, -1, -1, -1
	wasReloading = false
	reloadAlpha = 0
end

function ViewmodelController.canAim(): boolean
	return aimPose ~= nil
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

-- Segmento (Part) do ponto a ao ponto b, com a espessura dada.
local function segment(part: BasePart, a: Vector3, b: Vector3, width: number, up: Vector3)
	local len = (b - a).Magnitude
	part.Size = Vector3.new(width, width, math.max(len, 0.01))
	part.CFrame = CFrame.lookAt((a + b) / 2, b, up)
end

--[[
	IK analítico de 2 ossos. shoulder/hand/pole em coordenadas do mundo.
	Retorna o cotovelo. Se a mão estiver longe demais, os ossos esticam na
	mesma proporção (a mão nunca solta a arma).
]]
local function solveElbow(shoulder: Vector3, hand: Vector3, pole: Vector3, a: number, b: number): Vector3
	local toHand = hand - shoulder
	local d = toHand.Magnitude
	if d < 1e-4 then
		return shoulder + pole.Unit * a
	end
	local dir = toHand / d
	local reach = a + b
	if d >= reach * 0.999 then
		local k = d / reach
		return shoulder + dir * a * k
	end
	d = math.max(d, math.abs(a - b) + 1e-3)
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local perp = pole - dir * pole:Dot(dir)
	if perp.Magnitude < 1e-4 then
		perp = dir:Cross(Vector3.yAxis)
	end
	return shoulder + dir * (a * cosA) + perp.Unit * (a * sinA)
end

local handPieces: { [string]: { { part: BasePart, rel: CFrame } } } = { R = {}, L = {} }
local camoPieces: { [string]: { { part: BasePart, seg: string, t: number, oy: number, ox: number, len: number } } } = { R = {}, L = {} }

-- Manchas de camuflagem acompanham o segmento (Upper/Fore) a cada quadro.
local function placeCamo(side: string, seg: string, a: Vector3, b: Vector3, width: number, up: Vector3)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	for _, c in camoPieces[side] do
		if c.seg == seg then
			local plen = math.max(len * c.len * 1.5, 0.05)
			c.part.Size = Vector3.new(if c.ox ~= 0 then 0.006 else width * 0.8, if c.oy ~= 0 then 0.006 else width * 0.75, plen)
			c.part.CFrame = cf * CFrame.new(c.ox * (width / 2 + 0.002), c.oy * (width / 2 + 0.002), len * (0.5 - c.t))
		end
	end
end

-- Ponto do punho de cada mão (onde o antebraço termina), no referencial da mão.
local WRIST = { R = Vector3.new(0.006, -0.006, 0.1) * ARM.HandScale, L = Vector3.new(0.024, -0.072, 0.1) * ARM.HandScale }

local function placeArm(side: string, camCF: CFrame, handCF: CFrame)
	local shoulder = camCF:PointToWorldSpace(ARM["Shoulder" .. side])
	local pole = camCF:VectorToWorldSpace(ARM["Pole" .. side])
	local wrist = handCF:PointToWorldSpace(WRIST[side])
	local elbow = solveElbow(shoulder, wrist, pole, ARM.Upper, ARM.Fore)
	local up = camCF.UpVector
	segment(arms["Upper" .. side], shoulder, elbow, ARM.UpperWidth, up)
	-- antebraço: manga grossa perto do cotovelo, punho dobrado (cuff) perto da mão
	local cuffStart = elbow:Lerp(wrist, 0.78)
	segment(arms["Fore" .. side], elbow, cuffStart, ARM.ForeWidth, up)
	segment(arms["Cuff" .. side], cuffStart, wrist, ARM.CuffWidth, up)
	placeCamo(side, "Upper", shoulder, elbow, ARM.UpperWidth, up)
	placeCamo(side, "Fore", elbow, cuffStart, ARM.ForeWidth, up)
	-- braçadeira do time no braço
	segment(arms["Band" .. side], shoulder:Lerp(elbow, 0.55), shoulder:Lerp(elbow, 0.68), ARM.BandWidth, up)
	-- mão: peças rígidas no referencial da arma
	for _, h in handPieces[side] do
		h.part.CFrame = handCF * h.rel
	end
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

	aimAlpha = AimController.getAlpha()

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

	-- Braços: IK do ombro (fora da tela) até as mãos na arma
	local sScale = vm.Scale
	local handRCF = final * CFrame.new(0, -0.1 * sScale, 0.06 * sScale)
	placeArm("R", camCF, handRCF)
	local lh = handle:FindFirstChild("LeftHand") :: Attachment?
	if lh then
		local handLCF = CFrame.new(lh.WorldPosition) * final.Rotation
		if reloading then
			-- mão esquerda vai buscar o carregador
			local p = math.clamp((os.clock() - reloadStart) / (weapon.ReloadTime or 1), 0, 1)
			local away = math.sin(math.clamp((p - 0.15) / 0.7, 0, 1) * math.pi)
			handLCF = handLCF * CFrame.new(0, -0.35 * away, 0.25 * away)
		end
		placeArm("L", camCF, handLCF)
	end

	setHidden(AimController.isScoped())
end

function ViewmodelController.init()
	local camera = workspace.CurrentCamera
	folder = Instance.new("Model")
	folder.Name = "Viewmodel"
	folder.Parent = camera
	for _, side in { "R", "L" } do
		arms["Upper" .. side] = makeArmPart("Upper" .. side, UNIFORM, Vector3.one * 0.1)
		arms["Fore" .. side] = makeArmPart("Fore" .. side, UNIFORM, Vector3.one * 0.1)
		arms["Cuff" .. side] = makeArmPart("Cuff" .. side, UNIFORM_DARK, Vector3.one * 0.1)
		arms["Band" .. side] = makeArmPart("Band" .. side, teamColor(), Vector3.one * 0.1)
		arms["Cuff" .. side].Material = Enum.Material.SmoothPlastic
		arms["Fore" .. side].Material = Enum.Material.SmoothPlastic
		arms["Upper" .. side].Material = Enum.Material.SmoothPlastic
		for n, c in CAMO_PATCHES do
			for _, seg in { "Upper", "Fore" } do
				local p = makeArmPart(("Camo%s%d%s"):format(seg, n, side), CAMO[c[5]], Vector3.one * 0.05)
				p.Material = Enum.Material.SmoothPlastic
				arms[p.Name] = p
				table.insert(camoPieces[side], { part = p, seg = seg, t = c[1], oy = c[2], ox = c[3], len = c[4] })
			end
		end
		for n, piece in (if side == "R" then HAND_R else HAND_L) do
			local hs = ARM.HandScale
			local p = makeArmPart(("Mao%s%d%s"):format(piece[1], n, side), piece[4], piece[2] * hs)
			p.Material = Enum.Material.SmoothPlastic
			arms[p.Name] = p
			-- mão esquerda espelhada em X: dedos no lado visível (esquerdo) do guarda-mão
			local rel = piece[3]
			if side == "L" then
				local rx, ry, rz = rel:ToOrientation()
				rel = CFrame.new(-rel.X, rel.Y, rel.Z) * CFrame.fromOrientation(rx, -ry, -rz)
			end
			table.insert(handPieces[side], { part = p, rel = CFrame.new(rel.Position * hs) * rel.Rotation })
		end
	end
	RunService:BindToRenderStep("BlockfrontViewmodel", Enum.RenderPriority.Camera.Value + 1, render)
end

return ViewmodelController
