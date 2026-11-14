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
	  centro      mira + marcador de acerto + notificações de conquista
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
end

local function buildCrosshair()
	local holder = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for _, def in {
		{ UDim2.new(0.5, -1, 0, 0), UDim2.fromOffset(2, 8) },
		{ UDim2.new(0.5, -1, 1, -8), UDim2.fromOffset(2, 8) },
		{ UDim2.new(0, 0, 0.5, -1), UDim2.fromOffset(8, 2) },
		{ UDim2.new(1, -8, 0.5, -1), UDim2.fromOffset(8, 2) },
	} do
		make("Frame", {
			Position = def[1],
			Size = def[2],
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = holder,
		}, { make("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5 }) })
	end
	refs.Crosshair = holder

	refs.HitMarker = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		Text = "×",
		TextTransparency = 1,
		Parent = gui,
	})
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
	refs.Crosshair.Visible = hp > 0 and WeaponController.getState() ~= nil and not ViewmodelController.isAiming()
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
		end
	end)

	WeaponController.Changed:Connect(updateWeapon)
	RunService.Heartbeat:Connect(updatePlayer)
	updateWeapon()
end

return UIController
