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
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer

local ViewmodelController = {}

local GLOVE = Color3.fromRGB(62, 64, 58) -- cinza-oliva: contrasta com a arma escura
local GLOVE_PAD = Color3.fromRGB(88, 90, 82)
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
	-- empunhadura do rifle no modelo: centro (0, -0.05, 0.05), inclinada -18° em X
	GripOffset = Vector3.new(0, -0.05, 0.05),
	GripTilt = math.rad(-18),
	HandguardHalf = 0.19, -- meia altura do guarda-mão (unidades do modelo)
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
-- Peças da mão em studs FINAIS (sem escala), ajustadas às medidas reais do
-- rifle no viewmodel (escala 0.36): empunhadura ~0.094 x 0.26 x 0.13 e
-- guarda-mão ~0.13 x 0.137. O referencial da mão direita é o CENTRO DA
-- EMPUNHADURA (já inclinado como ela); o da esquerda é o CENTRO DO GUARDA-MÃO.
local WATCH = Color3.fromRGB(70, 74, 78)
local HAND_R = {
	{ "Dorso", Vector3.new(0.034, 0.13, 0.15), CFrame.new(0.066, 0.0, 0.012), GLOVE },
	{ "Protecao", Vector3.new(0.012, 0.085, 0.09), CFrame.new(0.088, 0.01, 0.0), GLOVE_PAD },
	{ "Palma", Vector3.new(0.03, 0.12, 0.13), CFrame.new(-0.062, 0.0, 0.018), GLOVE },
	{ "Junta", Vector3.new(0.13, 0.035, 0.05), CFrame.new(0.0, 0.072, 0.06), GLOVE },
	{ "Punho", Vector3.new(0.12, 0.12, 0.05), CFrame.new(0.005, 0.035, 0.1), GLOVE_PAD },
	{ "Relogio", Vector3.new(0.03, 0.06, 0.04), CFrame.new(0.072, 0.035, 0.1), WATCH },
	-- polegar por cima, no lado esquerdo da arma
	{ "Polegar", Vector3.new(0.03, 0.03, 0.1), CFrame.new(-0.062, 0.078, -0.02), GLOVE },
	{ "PolegarPonta", Vector3.new(0.028, 0.028, 0.03), CFrame.new(-0.062, 0.078, -0.085), SKIN },
	-- indicador ao longo do guarda-mato, ponta dobrada no gatilho
	{ "Indicador", Vector3.new(0.028, 0.028, 0.075), CFrame.new(-0.036, 0.088, -0.075), GLOVE },
	{ "IndicadorPonta", Vector3.new(0.034, 0.026, 0.026), CFrame.new(-0.018, 0.086, -0.118), SKIN },
}
for _, y in { 0.035, 0.0, -0.035 } do
	-- médio, anelar e mínimo: dão a volta pela frente da empunhadura
	table.insert(HAND_R, { "Dedo", Vector3.new(0.12, 0.03, 0.032), CFrame.new(0.0, y, -0.082), GLOVE })
	table.insert(HAND_R, { "Ponta", Vector3.new(0.03, 0.028, 0.03), CFrame.new(-0.068, y, -0.07), SKIN })
end

local HAND_L = {
	-- dorso da luva virado para a câmera (lado esquerdo do guarda-mão)
	{ "Dorso", Vector3.new(0.035, 0.12, 0.16), CFrame.new(-0.085, -0.01, 0.0), GLOVE },
	{ "Protecao", Vector3.new(0.012, 0.08, 0.1), CFrame.new(-0.107, 0.0, 0.0), GLOVE_PAD },
	{ "Palma", Vector3.new(0.1, 0.03, 0.15), CFrame.new(-0.03, -0.084, 0.0), GLOVE },
	{ "Polegar", Vector3.new(0.03, 0.03, 0.1), CFrame.new(0.04, -0.084, -0.06), GLOVE },
	{ "PolegarPonta", Vector3.new(0.028, 0.028, 0.03), CFrame.new(0.04, -0.084, -0.12), SKIN },
	{ "Punho", Vector3.new(0.115, 0.115, 0.05), CFrame.new(-0.06, -0.04, 0.1), GLOVE_PAD },
}
for _, z in { -0.057, -0.019, 0.019, 0.057 } do
	-- dedos passam por cima do guarda-mão; pontas (pele) do outro lado
	table.insert(HAND_L, { "Dedo", Vector3.new(0.1, 0.03, 0.032), CFrame.new(-0.03, 0.084, z), GLOVE })
	table.insert(HAND_L, { "Ponta", Vector3.new(0.03, 0.04, 0.03), CFrame.new(0.055, 0.07, z), SKIN })
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

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

--[[
	Recarga com carregador (V10), p = 0..1 do ReloadTime:
	  0.00-0.15  inclina a arma para a direita (mostra o poço do carregador)
	  0.10-0.30  mão esquerda pega o carregador e puxa para baixo  (som MagOut)
	  0.30-0.50  carregador e mão saem por baixo da tela
	  0.50-0.72  volta com o carregador novo
	  0.72-0.78  encaixa                                          (som MagIn)
	  0.80-0.90  tapa na arma / ferrolho                          (som Charge)
	  0.85-1.00  arma volta à posição
	Devolve: deslocamento da arma, queda do carregador (unidades do modelo) e
	quanto a mão esquerda está presa ao carregador (0..1).
]]
local function reloadPose(p: number): (CFrame, number, number)
	local tilt = smooth(0, 0.15, p) * (1 - smooth(0.85, 1, p))
	local slap = math.sin(smooth(0.8, 0.9, p) * math.pi) * (1 - smooth(0.9, 0.95, p))
	local weaponCF = CFrame.new(-0.06 * tilt, -0.03 * tilt, 0.02 * tilt)
		* CFrame.Angles(0.05 * tilt + 0.03 * slap, 0.05 * tilt, 0.22 * tilt)
	local drop
	if p < 0.12 then
		drop = 0
	elseif p < 0.3 then
		drop = smooth(0.12, 0.3, p) * 1.6
	elseif p < 0.5 then
		drop = 1.6 + smooth(0.3, 0.5, p) * 1.2
	elseif p < 0.72 then
		drop = 2.8 - smooth(0.5, 0.72, p) * 2.4
	elseif p < 0.78 then
		drop = 0.4 * (1 - smooth(0.72, 0.78, p))
	else
		drop = 0
	end
	local onMag = smooth(0.06, 0.13, p) * (1 - smooth(0.78, 0.86, p))
	return weaponCF, drop, onMag
end

local RELOAD_SOUNDS = { { 0.14, "MagOut" }, { 0.74, "MagIn" }, { 0.86, "Charge" } }
local reloadSoundsFired: { [string]: boolean } = {}

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
local WRIST = { R = Vector3.new(0.005, 0.04, 0.13), L = Vector3.new(-0.07, -0.05, 0.13) }

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
		table.clear(reloadSoundsFired)
	end
	local reloadP = if reloading then math.clamp((os.clock() - reloadStart) / (weapon.ReloadTime or 1), 0, 1) else 1
	local magReload = animated.Mag ~= nil and weapon.Sounds and weapon.Sounds.MagOut ~= nil
	if reloading and magReload then
		for _, ev in RELOAD_SOUNDS do
			if reloadP >= ev[1] and not reloadSoundsFired[ev[2]] then
				reloadSoundsFired[ev[2]] = true
				local id = weapon.Sounds[ev[2]]
				if id then
					AudioController.play(id, nil, { Volume = 0.75, Vary = 0.04 })
				end
			end
		end
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
	local hit = workspace:Raycast(camCF.Position, camCF.LookVector * 1.7, wallParams)
	local targetPush = if hit then math.clamp((1.7 - hit.Distance) / 1.4, 0, 1) else 0
	wallPush = lerp(wallPush, targetPush, math.min(dt * 12, 1))
	-- perto da parede: recua reto (sem girar a arma, que deixava a mira torta)
	local wallCF = CFrame.new(0, -0.06 * wallPush, 0.4 * wallPush) * CFrame.Angles(math.rad(8) * wallPush, 0, 0)

	local equipCF = CFrame.new(0, -(1 - e) * 0.7, 0.1 * (1 - e)) * CFrame.Angles(-(1 - e) * 0.9, 0, (1 - e) * 0.3)
	local reloadCF, magDrop, magHold = CFrame.identity, 0, 0
	if magReload and reloading then
		reloadCF, magDrop, magHold = reloadPose(reloadP)
	else
		reloadCF = CFrame.new(0, -reloadAlpha * 0.12, 0) * CFrame.Angles(-reloadAlpha * 0.25, reloadAlpha * 0.15, reloadAlpha * 0.5)
	end

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
		if magReload then
			offsetTagged("Mag", CFrame.new(0, -magDrop, magDrop * 0.12) * CFrame.Angles(magDrop * 0.12, 0, 0))
		else
			local p = reloadP
			local drop = if p < 0.3 then (p / 0.3) * 1.6 elseif p < 0.6 then 3 elseif p < 0.85 then 1.6 * (1 - (p - 0.6) / 0.25) else 0
			offsetTagged("Mag", CFrame.new(0, -drop, drop * 0.2))
		end
	elseif animated.Mag then
		offsetTagged("Mag", CFrame.identity)
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
	-- mão direita: centro da empunhadura, com a mesma inclinação dela
	local handRCF = final * CFrame.new(ARM.GripOffset * sScale) * CFrame.Angles(ARM.GripTilt, 0, 0)
	placeArm("R", camCF, handRCF)
	local lh = handle:FindFirstChild("LeftHand") :: Attachment?
	if lh then
		-- mão esquerda: centro do guarda-mão (o attachment fica na face de baixo)
		local handLCF = CFrame.new(lh.WorldPosition + final.UpVector * ARM.HandguardHalf * sScale) * final.Rotation
		if reloading and magReload and magHold > 0 then
			-- segura o carregador (limita a descida para o braço não esticar demais)
			local mag = animated.Mag[1].part
			local magCF = CFrame.new(mag.Position - final.UpVector * 0.02) * final.Rotation * CFrame.Angles(0, 0, -0.3)
			local d = (magCF.Position - handLCF.Position)
			if d.Magnitude > 0.5 then
				magCF = CFrame.new(handLCF.Position + d.Unit * 0.5) * magCF.Rotation
			end
			handLCF = handLCF:Lerp(magCF, magHold)
		elseif reloading then
			-- armas sem carregador: a mão sai e volta
			local away = math.sin(math.clamp((reloadP - 0.15) / 0.7, 0, 1) * math.pi)
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
			local p = makeArmPart(("Mao%s%d%s"):format(piece[1], n, side), piece[4], piece[2])
			p.Material = Enum.Material.SmoothPlastic
			arms[p.Name] = p
			table.insert(handPieces[side], { part = p, rel = piece[3] })
		end
	end
	RunService:BindToRenderStep("BlockfrontViewmodel", Enum.RenderPriority.Camera.Value + 1, render)
end

return ViewmodelController
