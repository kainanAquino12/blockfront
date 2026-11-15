--[[
	UIController (cliente) — HUD do BLOCKFRONT, montado em código.
	Lê o estado da partida dos atributos de ReplicatedStorage.Match, a vida
	do Humanoid e a munição do WeaponController. Eventos de abate e acerto
	chegam pelo CombatEvent.

	Elementos:
	  topo        placar Azul x Vermelho + tempo + objetivo (área Centro)
	  faixa       aviso de fase (aguardando, início, vitória)
	  esquerda    time do jogador + vida
	  direita     arma + munição + recarga
	  canto       feed de eliminações
	  centro      retículo dinâmico (abre com a dispersão, vira ponto ao mirar),
	              marcador de acerto, barra de recarga, luneta da sniper,
	              setas de dano recebido, vinheta de vida baixa
	              (ScreenGui "CombatOverlay", DisplayOrder 50: sempre por cima)
	  direita     lista de armas (1-5) + munição
	  placar      segurar Tab (e automático no fim da partida)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local WeaponController = require(script.Parent.WeaponController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local player = Players.LocalPlayer

local UIController = {}

local THEME = {
	Panel = Color3.fromRGB(20, 23, 31),
	PanelLight = Color3.fromRGB(36, 41, 54),
	Text = Color3.fromRGB(240, 242, 248),
	Muted = Color3.fromRGB(150, 158, 176),
	Blue = GameConfig.Teams.Blue.Color,
	Red = GameConfig.Teams.Red.Color,
	Neutral = Color3.fromRGB(220, 220, 220),
	Danger = Color3.fromRGB(255, 92, 72),
	Font = Enum.Font.GothamBlack,
	FontBody = Enum.Font.GothamBold,
}

local gui: ScreenGui
local refs: { [string]: any } = {}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, r or 4) })
end

local function panel(props): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.15
	props.BorderSizePixel = 0
	return make("Frame", props, { corner() })
end

local function label(props): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or THEME.Font
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.TextScaled = props.TextScaled ~= false
	return make("TextLabel", props)
end

-- string.upper não converte letras acentuadas (UTF-8); trata as do português.
local ACCENTS = {
	["ç"] = "Ç", ["ã"] = "Ã", ["õ"] = "Õ", ["á"] = "Á", ["é"] = "É", ["í"] = "Í",
	["ó"] = "Ó", ["ú"] = "Ú", ["â"] = "Â", ["ê"] = "Ê", ["ô"] = "Ô", ["à"] = "À",
}
local function upper(s: string): string
	s = string.upper(s)
	for lower, up in ACCENTS do
		s = string.gsub(s, lower, up)
	end
	return s
end

local function teamColor(name: string?): Color3
	if name == "Blue" then
		return THEME.Blue
	elseif name == "Red" then
		return THEME.Red
	end
	return THEME.Neutral
end

local function teamLabel(name: string?): string
	if name == "Blue" then
		return "AZUL"
	elseif name == "Red" then
		return "VERMELHO"
	end
	return "NEUTRO"
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------

local function buildTop()
	local top = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 92),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local function scoreBox(name: string, color: Color3, x: number, anchor: number)
		local box = panel({
			Name = name,
			AnchorPoint = Vector2.new(anchor, 0),
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.fromOffset(120, 52),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.05,
			Parent = top,
		})
		refs[name] = label({ Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5), Text = "0", Parent = box })
	end
	scoreBox("ScoreBlue", THEME.Blue, 0, 0)
	scoreBox("ScoreRed", THEME.Red, 1, 1)

	local timer = panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(124, 52),
		Parent = top,
	})
	refs.Timer = label({ Size = UDim2.new(1, -16, 0.62, 0), Position = UDim2.fromOffset(8, 4), Text = "0:00", Parent = timer })
	refs.ToWin = label({
		Size = UDim2.new(1, -16, 0.28, 0),
		Position = UDim2.new(0, 8, 0.66, 0),
		Font = THEME.FontBody,
		TextColor3 = THEME.Muted,
		Text = "META " .. MatchConfig.ScoreToWin,
		Parent = timer,
	})

	-- Objetivos: um selo por ponto de captura (A, B, C)
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(#MatchConfig.CapturePoints * 64, 34),
		BackgroundTransparency = 1,
		Parent = top,
	}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	refs.Points = {}
	for i, def in MatchConfig.CapturePoints do
		local pill = panel({ Size = UDim2.fromOffset(56, 34), LayoutOrder = i, Parent = row })
		local bg = make("Frame", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundColor3 = THEME.PanelLight,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = pill,
		}, { corner(3) })
		local fill = make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = THEME.Neutral,
			BorderSizePixel = 0,
			Parent = bg,
		})
		local text = label({ Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Text = def.Id, ZIndex = 2, Parent = bg })
		make("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = text })
		local stroke = make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1, Parent = pill })
		refs.Points[def.Id] = { fill = fill, stroke = stroke }
	end

	-- Faixa de fase
	refs.Banner = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(520, 34),
		Text = "",
		Parent = gui,
	})
	make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = refs.Banner })
end

local function buildPlayerPanel()
	local p = panel({
		Name = "Player",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(270, 70),
		Parent = gui,
	})
	refs.TeamTag = panel({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(120, 22),
		BackgroundColor3 = THEME.Neutral,
		BackgroundTransparency = 0,
		Parent = p,
	})
	refs.TeamText = label({ Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "—", Parent = refs.TeamTag })
	local bg = make("Frame", {
		Position = UDim2.fromOffset(8, 38),
		Size = UDim2.new(1, -70, 0, 22),
		BackgroundColor3 = THEME.PanelLight,
		BorderSizePixel = 0,
		Parent = p,
	}, { corner(3) })
	refs.HealthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(110, 220, 120),
		BorderSizePixel = 0,
		Parent = bg,
	}, { corner(3) })
	refs.HealthText = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 36),
		Size = UDim2.fromOffset(54, 26),
		Text = "100",
		Parent = p,
	})
end

local function buildWeaponPanel()
	local p = panel({
		Name = "Weapon",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(250, 76),
		Parent = gui,
	})
	refs.WeaponPanel = p
	refs.WeaponName = label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Muted,
		Text = "",
		Parent = p,
	})
	refs.Ammo = label({
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.fromOffset(110, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = p,
	})
	refs.Reserve = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 38),
		Size = UDim2.fromOffset(110, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = THEME.Muted,
		Text = "",
		Parent = p,
	})

	-- Lista de armas (teclas 1-5)
	local list = make("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -100),
		Size = UDim2.fromOffset(200, 5 * 24),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { make("UIListLayout", { Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })
	refs.Slots = {}
	for i = 1, 5 do
		local row = panel({ Size = UDim2.fromOffset(180, 21), LayoutOrder = i, BackgroundTransparency = 0.45, Parent = list })
		local text = label({
			Position = UDim2.fromOffset(8, 3),
			Size = UDim2.new(1, -16, 1, -6),
			Font = THEME.FontBody,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = THEME.Muted,
			Text = "",
			Parent = row,
		})
		refs.Slots[i] = { row = row, text = text }
	end
end

-- Retículo, marcador de acerto, barra de recarga, luneta, indicadores de dano
-- e vinheta. Ficam num ScreenGui próprio com DisplayOrder alto para nunca
-- ficarem atrás de outros elementos.
local function buildCrosshair()
	local cgui = make("ScreenGui", {
		Name = "CombatOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	refs.CombatGui = cgui

	-- Vinheta de vida baixa / dano (4 bordas com gradiente)
	refs.Vignette = {}
	for _, def in {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90 },
		{ UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
	} do
		local f = make("Frame", {
			Position = def[1],
			Size = def[2],
			BackgroundColor3 = Color3.fromRGB(200, 20, 20),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Parent = cgui,
		})
		local g = make("UIGradient", {
			Rotation = def[3],
			Transparency = NumberSequence.new(0, 1),
			Parent = f,
		})
		table.insert(refs.Vignette, f)
		local _ = g
	end

	-- Luneta: círculo transparente com contorno preto enorme (cobre o resto da tela)
	local scope = make("Frame", {
		Name = "Scope",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = cgui,
	})
	local lens = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		Parent = scope,
	}, {
		make("UIAspectRatioConstraint", { AspectRatio = 1 }),
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = 3000, Color = Color3.new(0, 0, 0) }),
	})
	for _, def in {
		{ UDim2.new(0.5, -1, 0, 0), UDim2.new(0, 2, 0.46, 0) },
		{ UDim2.new(0.5, -1, 0.54, 0), UDim2.new(0, 2, 0.46, 0) },
		{ UDim2.new(0, 0, 0.5, -1), UDim2.new(0.46, 0, 0, 2) },
		{ UDim2.new(0.54, 0, 0.5, -1), UDim2.new(0.46, 0, 0, 2) },
	} do
		make("Frame", { Position = def[1], Size = def[2], BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = lens })
	end
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60),
		BorderSizePixel = 0,
		Parent = lens,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.Scope = scope

	-- Retículo dinâmico: 4 barras afastadas pela dispersão atual + ponto central
	local holder = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = cgui,
	})
	refs.Bars = {}
	for i = 1, 4 do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = holder,
		}, { make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }) })
		refs.Bars[i] = bar
	end
	refs.Dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = holder,
	}, { make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }) })
	refs.Crosshair = holder

	-- Barra de recarga sob o retículo
	local rbg = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 34),
		Size = UDim2.fromOffset(70, 4),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = false,
		Parent = cgui,
	})
	refs.ReloadFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = rbg })
	refs.ReloadBar = rbg

	refs.HitMarker = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		Text = "×",
		TextTransparency = 1,
		Parent = cgui,
	})

	-- Indicadores de dano (pool de 6 setas em volta do centro)
	refs.DamageMarks = {}
	for i = 1, 6 do
		local m = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(70, 12),
			BackgroundColor3 = Color3.fromRGB(230, 40, 40),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Parent = cgui,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		refs.DamageMarks[i] = { frame = m, from = Vector3.zero, t = -1 }
	end
end

local damageFlash = 0
local nextMark = 1

function UIController.showDamage(from: Vector3?, amount: number)
	damageFlash = math.min(1, damageFlash + amount / 60)
	if not from then
		return
	end
	local m = refs.DamageMarks[nextMark]
	nextMark = nextMark % #refs.DamageMarks + 1
	m.from = from
	m.t = 0
end

local function updateCombatUI(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hp = humanoid and humanoid.Health or 0
	local alive = hp > 0
	local state = WeaponController.getState()
	local scoped = ViewmodelController.isScoped()
	local aimA = ViewmodelController.getAimAlpha()
	local menuOpen = refs.MenuOpen == true

	refs.Scope.Visible = alive and scoped and not menuOpen

	-- Retículo
	local showCross = alive and state ~= nil and not scoped and not menuOpen
	refs.Crosshair.Visible = showCross
	if showCross then
		local spread = WeaponController.getSpread()
		local half = math.tan(math.rad(camera.FieldOfView / 2))
		local gap = math.tan(math.rad(spread)) / half * (camera.ViewportSize.Y / 2)
		gap = math.clamp(gap + 4, 4, 120)
		local barsAlpha = math.clamp(aimA * 1.4, 0, 1) -- some ao mirar (fica o ponto)
		local isMelee = state.Weapon.Kind == "Melee" or state.Weapon.Kind == "Throwable"
		local len, thick = 9, 2
		local defs = {
			{ UDim2.fromOffset(0, -gap - len / 2), UDim2.fromOffset(thick, len) },
			{ UDim2.fromOffset(0, gap + len / 2), UDim2.fromOffset(thick, len) },
			{ UDim2.fromOffset(-gap - len / 2, 0), UDim2.fromOffset(len, thick) },
			{ UDim2.fromOffset(gap + len / 2, 0), UDim2.fromOffset(len, thick) },
		}
		for i, bar in refs.Bars do
			bar.Position = defs[i][1]
			bar.Size = defs[i][2]
			bar.BackgroundTransparency = if isMelee then 1 else barsAlpha
			bar.UIStroke.Transparency = if isMelee then 1 else 0.4 + barsAlpha * 0.6
		end
		refs.Dot.Size = if aimA > 0.5 then UDim2.fromOffset(4, 4) else UDim2.fromOffset(3, 3)
		refs.Dot.BackgroundColor3 = if aimA > 0.5 then Color3.fromRGB(255, 90, 90) else Color3.new(1, 1, 1)
	end

	-- Recarga
	refs.ReloadBar.Visible = alive and state ~= nil and state.Reloading
	if refs.ReloadBar.Visible then
		refs.ReloadFill.Size = UDim2.fromScale(WeaponController.getReloadProgress(), 1)
	end

	-- Indicadores de dano: apontam para a origem conforme a câmera gira
	local center = camera.ViewportSize / 2
	for _, m in refs.DamageMarks do
		if m.t >= 0 then
			m.t += dt
			if m.t > 1.4 then
				m.t = -1
				m.frame.BackgroundTransparency = 1
			else
				local rel = camera.CFrame:PointToObjectSpace(m.from)
				local ang = math.atan2(rel.X, -rel.Z)
				local r = 130
				m.frame.Position = UDim2.fromOffset(center.X + math.sin(ang) * r, center.Y - math.cos(ang) * r)
				m.frame.Rotation = math.deg(ang) + 90
				m.frame.BackgroundTransparency = 0.1 + 0.9 * (m.t / 1.4)
			end
		end
	end

	-- Vinheta: flash ao levar dano + persistente com pouca vida
	damageFlash = math.max(0, damageFlash - dt * 1.5)
	local low = if alive and hp < 35 then (1 - hp / 35) * 0.6 else 0
	local v = math.clamp(math.max(damageFlash, low), 0, 0.85)
	for _, f in refs.Vignette do
		f.BackgroundTransparency = 1 - v
	end
end

-- Menu aberto: esconde retículo e luneta.
function UIController.setMenuOpen(value: boolean)
	refs.MenuOpen = value
end

local function buildFeedAndToasts()
	refs.Feed = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(300, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	refs.Toast = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(560, 40),
		Text = "",
		TextTransparency = 1,
		Parent = gui,
	})
	refs.ToastStroke = make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 1, Parent = refs.Toast })
end

---------------------------------------------------------------------------
-- Atualização
---------------------------------------------------------------------------

local feedOrder = 0

local function pushFeed(e)
	feedOrder += 1
	local row = panel({ Size = UDim2.fromOffset(300, 26), LayoutOrder = -feedOrder, Parent = refs.Feed })
	local weapon = WeaponConfig.Weapons[e.Weapon]
	local killer = if e.Killer ~= "" then e.Killer else "—"
	local text = string.format(
		'<font color="#%s">%s</font>  [%s%s]  <font color="#%s">%s</font>',
		teamColor(e.KillerTeam):ToHex(),
		killer,
		weapon and upper(weapon.DisplayName) or "?",
		if e.Headshot then " · CABEÇA" else "",
		teamColor(e.VictimTeam):ToHex(),
		e.Victim
	)
	label({
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		RichText = true,
		Font = THEME.FontBody,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = text,
		Parent = row,
	})
	local rows = {}
	for _, c in refs.Feed:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 6, #rows do
		rows[i]:Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			row:Destroy()
		end
	end)
end

local toastToken = 0
function UIController.toast(text: string, color: Color3?)
	toastToken += 1
	local my = toastToken
	refs.Toast.Text = text
	refs.Toast.TextColor3 = color or THEME.Text
	refs.Toast.TextTransparency = 0
	refs.ToastStroke.Transparency = 0.3
	task.delay(2.5, function()
		if my == toastToken then
			TweenService:Create(refs.Toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(refs.ToastStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

local function flashHitMarker(lethal: boolean, headshot: boolean)
	local m = refs.HitMarker
	m.TextColor3 = if lethal then THEME.Danger elseif headshot then Color3.fromRGB(255, 220, 80) else Color3.new(1, 1, 1)
	m.TextTransparency = 0
	m.Size = UDim2.fromOffset(40, 40)
	TweenService:Create(m, TweenInfo.new(0.25), { TextTransparency = 1, Size = UDim2.fromOffset(30, 30) }):Play()
end

local function updateMatch(match: Configuration)
	refs.ScoreBlue.Text = tostring(match:GetAttribute("ScoreBlue") or 0)
	refs.ScoreRed.Text = tostring(match:GetAttribute("ScoreRed") or 0)
	refs.Timer.Text = formatTime(match:GetAttribute("TimeLeft") or 0)

	local state = match:GetAttribute("State")
	if state == "Waiting" then
		refs.Banner.Text = "AGUARDANDO JOGADORES"
		refs.Banner.TextColor3 = THEME.Text
	elseif state == "Starting" then
		refs.Banner.Text = "A PARTIDA COMEÇA EM " .. tostring(match:GetAttribute("TimeLeft") or 0)
		refs.Banner.TextColor3 = THEME.Text
	elseif state == "Ended" then
		local winner = match:GetAttribute("Winner")
		refs.Banner.Text = if winner == "Draw" then "EMPATE" else "VITÓRIA " .. teamLabel(winner)
		refs.Banner.TextColor3 = teamColor(winner)
	else
		refs.Banner.Text = ""
	end

	for _, def in MatchConfig.CapturePoints do
		local r = refs.Points[def.Id]
		local value = match:GetAttribute("Cap_" .. def.Id .. "_Value") or 0
		local owner = match:GetAttribute("Cap_" .. def.Id .. "_Owner") or ""
		local cstate = match:GetAttribute("Cap_" .. def.Id .. "_State") or "Idle"
		r.fill.Size = UDim2.fromScale(1, math.abs(value))
		r.fill.BackgroundColor3 = if value < 0 then THEME.Blue elseif value > 0 then THEME.Red else THEME.Neutral
		r.stroke.Transparency = if cstate == "Contested" then 0 elseif cstate == "Capturing" then 0.5 else 1
		r.stroke.Color = if cstate == "Contested" then THEME.Danger else Color3.new(1, 1, 1)
		if owner ~= "" then
			r.fill.Size = UDim2.fromScale(1, 1)
		end
	end
end

local function updatePlayer()
	local team = player.Team and player.Team.Name
	refs.TeamTag.BackgroundColor3 = teamColor(team)
	refs.TeamText.Text = if team then GameConfig.Teams[team].DisplayName else "SEM TIME"

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hp = humanoid and humanoid.Health or 0
	local max = humanoid and humanoid.MaxHealth or 100
	local ratio = math.clamp(hp / math.max(max, 1), 0, 1)
	refs.HealthFill.Size = UDim2.fromScale(ratio, 1)
	refs.HealthFill.BackgroundColor3 = if ratio > 0.5
		then Color3.fromRGB(110, 220, 120)
		elseif ratio > 0.25 then Color3.fromRGB(250, 200, 70)
		else THEME.Danger
	refs.HealthText.Text = tostring(math.ceil(hp))
end

local function updateWeapon()
	local s = WeaponController.getState()
	refs.WeaponPanel.Visible = s ~= nil
	if not s then
		return
	end
	refs.WeaponName.Text = upper(s.Weapon.DisplayName)
	if s.Weapon.Kind == "Melee" then
		refs.Ammo.Text = "∞"
		refs.Reserve.Text = ""
	elseif s.Reloading then
		refs.Ammo.Text = "..."
		refs.Reserve.Text = "RECARREGANDO"
	else
		refs.Ammo.Text = tostring(s.Ammo)
		refs.Ammo.TextColor3 = if s.Ammo == 0 then THEME.Danger else THEME.Text
		refs.Reserve.Text = if s.Weapon.Kind == "Throwable" then "RESTANTES" else "/ " .. tostring(s.Reserve)
	end
end

local function updateSlots()
	local slots = WeaponController.getSlots()
	local current = WeaponController.getState()
	for i, r in refs.Slots do
		local t = slots[i]
		r.row.Visible = t ~= nil
		if t then
			local id = t:GetAttribute("WeaponId")
			local w = id and WeaponConfig.Weapons[id]
			local active = current ~= nil and w ~= nil and current.Weapon == w
			r.text.Text = upper(w and w.DisplayName or t.Name) .. "   " .. i
			r.text.TextColor3 = if active then THEME.Text else THEME.Muted
			r.row.BackgroundTransparency = if active then 0.1 else 0.55
		end
	end
end

---------------------------------------------------------------------------
-- Placar (segurar Tab)
---------------------------------------------------------------------------

local function buildScoreboard()
	local board = panel({
		Name = "Scoreboard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 440),
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	})
	refs.Scoreboard = board
	label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 28),
		Text = "PLACAR",
		Parent = board,
	})
	refs.BoardColumns = {}
	for i, name in { "Blue", "Red" } do
		local col = make("Frame", {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 16 else 8, 0, 52),
			Size = UDim2.new(0.5, -24, 1, -68),
			BackgroundTransparency = 1,
			Parent = board,
		})
		local header = panel({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = teamColor(name),
			BackgroundTransparency = 0,
			Parent = col,
		})
		local title = label({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(0.6, -10, 1, -12),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = GameConfig.Teams[name].DisplayName,
			Parent = header,
		})
		local score = label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.new(0.4, -10, 1, -12),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "0",
			Parent = header,
		})
		label({
			Position = UDim2.fromOffset(10, 46),
			Size = UDim2.new(1, -20, 0, 16),
			Font = THEME.FontBody,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "ABATES   MORTES",
			Parent = col,
		})
		local rows = make("Frame", {
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 1, -66),
			BackgroundTransparency = 1,
			Parent = col,
		}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		refs.BoardColumns[name] = { title = title, score = score, rows = rows }
	end
end

local function statOf(p: Player, name: string): number
	local ls = p:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return if v and v:IsA("IntValue") then v.Value else 0
end

local function refreshScoreboard()
	local match = ReplicatedStorage:FindFirstChild("Match")
	for name, col in refs.BoardColumns do
		col.score.Text = tostring(match and match:GetAttribute("Score" .. name) or 0)
		for _, c in col.rows:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local list = {}
		for _, p in Players:GetPlayers() do
			if p.Team and p.Team.Name == name then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return statOf(a, "Abates") > statOf(b, "Abates")
		end)
		for i, p in list do
			local row = panel({
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = i,
				BackgroundColor3 = if p == player then THEME.PanelLight else THEME.Panel,
				BackgroundTransparency = if p == player then 0 else 0.3,
				Parent = col.rows,
			})
			label({
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(0.55, -10, 1, -12),
				Font = THEME.FontBody,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = p.DisplayName,
				Parent = row,
			})
			label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 6),
				Size = UDim2.new(0.45, -10, 1, -12),
				Font = THEME.Font,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = string.format("%d        %d", statOf(p, "Abates"), statOf(p, "Mortes")),
				Parent = row,
			})
		end
	end
end

function UIController.init()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	gui = make("ScreenGui", {
		Name = "MainHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTop()
	buildPlayerPanel()
	buildWeaponPanel()
	buildCrosshair()
	buildFeedAndToasts()
	buildScoreboard()

	local boardAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		local matchCfg = ReplicatedStorage:FindFirstChild("Match")
		local show = UserInputService:IsKeyDown(Enum.KeyCode.Tab) or (matchCfg ~= nil and matchCfg:GetAttribute("State") == "Ended")
		refs.Scoreboard.Visible = show
		if show then
			boardAcc += dt
			if boardAcc >= 0.5 then
				boardAcc = 0
				refreshScoreboard()
			end
		else
			boardAcc = 1 -- atualiza na hora quando abrir de novo
		end
	end)

	local match = ReplicatedStorage:WaitForChild("Match") :: Configuration
	local lastOwners = {}
	local lastState = match:GetAttribute("State")
	match.AttributeChanged:Connect(function(name)
		updateMatch(match)
		local pointId = string.match(name, "^Cap_(%w+)_Owner$")
		if pointId then
			local def
			for _, d in MatchConfig.CapturePoints do
				if d.Id == pointId then
					def = d
				end
			end
			local owner = match:GetAttribute(name) or ""
			local label = pointId .. " · " .. upper(def and def.Name or "")
			if owner ~= "" then
				UIController.toast(teamLabel(owner) .. " CONQUISTOU " .. label, teamColor(owner))
			elseif lastOwners[pointId] and lastOwners[pointId] ~= "" then
				UIController.toast(label .. " NEUTRALIZADO", THEME.Neutral)
			end
			lastOwners[pointId] = owner
		elseif name == "State" then
			local state = match:GetAttribute("State")
			if state == "InProgress" and lastState ~= "InProgress" then
				UIController.toast("CONQUISTE OS PONTOS A, B E C!")
			end
			lastState = state
		end
	end)
	updateMatch(match)

	Remotes.get("CombatEvent").OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.Type == "Kill" then
			pushFeed(e)
		elseif e.Type == "Hit" then
			flashHitMarker(e.Lethal, e.Headshot)
		elseif e.Type == "Damaged" then
			UIController.showDamage(e.From, e.Amount or 10)
		end
	end)

	WeaponController.Changed:Connect(function()
		updateWeapon()
		updateSlots()
	end)
	RunService.Heartbeat:Connect(updatePlayer)
	RunService.RenderStepped:Connect(updateCombatUI)
	task.spawn(function()
		while true do
			updateSlots()
			task.wait(1)
		end
	end)
	updateWeapon()
end

return UIController
