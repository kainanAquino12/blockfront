--[[
	TeamSelectController (cliente) — menu de escolha de time.
	Abre sozinho ao entrar (o jogador só nasce depois de escolher) e com a
	tecla M para trocar de time, escolher a arma principal e ajustar a
	sensibilidade do mouse. Enquanto aberto, câmera e armas ficam pausadas. Mostra quantos jogadores há em cada lado
	e desabilita o time que ficaria desequilibrado (a regra oficial é do
	servidor, em TeamManager.canJoin).

	Enquanto o menu está aberto, um botão Modal solta o mouse da primeira
	pessoa e a câmera mostra uma vista aérea do mapa (se ainda não nasceu).
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)
local SettingsController = require(script.Parent.SettingsController)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local TeamSelectController = {}

local MAX_IMBALANCE = 1
local OVERVIEW = CFrame.lookAt(Vector3.new(-230, 170, -330), Vector3.new(0, 0, -40))

local gui: ScreenGui
local cards: { [string]: { button: TextButton, count: TextLabel, list: TextLabel, status: TextLabel } } = {}
local open = false
local selectRemote: RemoteEvent

local function teamCount(name: string): number
	local team = Teams:FindFirstChild(name) :: Team?
	return if team then #team:GetPlayers() else 0
end

-- Espelho da regra do servidor, só para mostrar o botão desabilitado.
local function canJoin(name: string): boolean
	local mine = player.Team and player.Team.Name
	if mine == name then
		return false
	end
	local counts = {}
	for _, n in GameConfig.TeamOrder do
		counts[n] = teamCount(n) - (if mine == n then 1 else 0)
	end
	for _, n in GameConfig.TeamOrder do
		if n ~= name and counts[name] + 1 > counts[n] + MAX_IMBALANCE then
			return false
		end
	end
	return true
end

local function refresh()
	for name, c in cards do
		local team = Teams:FindFirstChild(name) :: Team?
		local names = {}
		if team then
			for _, p in team:GetPlayers() do
				table.insert(names, p.DisplayName)
			end
		end
		c.count.Text = tostring(#names) .. (if #names == 1 then " JOGADOR" else " JOGADORES")
		c.list.Text = if #names > 0 then table.concat(names, "\n") else "—"
		local mine = player.Team and player.Team.Name == name
		local ok = canJoin(name)
		c.status.Text = if mine then "SEU TIME" elseif ok then "ENTRAR" else "TIME CHEIO"
		c.button.AutoButtonColor = ok
		c.button.BackgroundTransparency = if ok or mine then 0 else 0.55
	end
end

function TeamSelectController.setOpen(value: boolean)
	open = value
	gui.Enabled = value
	UserInputService.MouseIconEnabled = value
	local hud = player.PlayerGui:FindFirstChild("MainHUD")
	if hud then
		hud.Enabled = not value
	end
	CameraController.setEnabled(not value)
	WeaponController.setBlocked(value)
	UIController.setMenuOpen(value)
	if value then
		refresh()
		if TeamSelectController.RefreshLoadout then
			TeamSelectController.RefreshLoadout()
		end
	end
end

function TeamSelectController.isOpen(): boolean
	return open
end

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function buildCard(name: string, xScale: number)
	local def = GameConfig.Teams[name]
	local button = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(xScale, 0.55),
		Size = UDim2.fromOffset(300, 340),
		BackgroundColor3 = def.Color,
		Text = "",
		AutoButtonColor = true,
		Parent = gui,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
	make("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 0.6, Parent = button })
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = def.DisplayName,
		Parent = button,
	})
	local count = make("TextLabel", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.15,
		Text = "",
		Parent = button,
	})
	local list = make("TextLabel", {
		Position = UDim2.fromOffset(16, 100),
		Size = UDim2.new(1, -32, 1, -170),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = button,
	})
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), Parent = list })
	local status = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundColor3 = Color3.fromRGB(20, 23, 31),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "ENTRAR",
		Parent = button,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = status })
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = status })

	button.Activated:Connect(function()
		if canJoin(name) then
			selectRemote:FireServer(name)
		end
	end)
	cards[name] = { button = button, count = count, list = list, status = status }
end

local function build()
	gui = make("ScreenGui", {
		Name = "TeamSelection",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 14, 20),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = gui,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromOffset(620, 70),
		BackgroundTransparency = 1,
		Font = Enum.Font.Arcade,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "BLOCKFRONT",
		Parent = gui,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromOffset(620, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(170, 178, 196),
		Text = "ESCOLHA SEU TIME",
		Parent = gui,
	}).Position = UDim2.new(0.5, 0, 0.07, 78)

	buildCard("Blue", 0.32)
	buildCard("Red", 0.68)
	for _, c in cards do
		c.button.Position = UDim2.fromScale(c.button.Position.X.Scale, 0.44)
	end

	-- Arma principal (vale no próximo nascimento)
	local loadoutLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 182),
		Size = UDim2.fromOffset(640, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(170, 178, 196),
		Text = "ARMA PRINCIPAL",
		Parent = gui,
	})
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 204),
		Size = UDim2.fromOffset(660, 38),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = row })
	local loadoutButtons = {}
	local function refreshLoadout()
		local current = player:GetAttribute("Primary") or WeaponConfig.DefaultPrimary
		for id, b in loadoutButtons do
			b.BackgroundColor3 = if id == current then Color3.fromRGB(240, 200, 70) else Color3.fromRGB(36, 41, 54)
			b.TextColor3 = if id == current then Color3.fromRGB(20, 22, 28) else Color3.new(1, 1, 1)
		end
		loadoutLabel.Text = if player.Character then "ARMA PRINCIPAL (VALE NO PRÓXIMO RENASCIMENTO)" else "ARMA PRINCIPAL"
	end
	for _, id in WeaponConfig.Primaries do
		local w = WeaponConfig.Weapons[id]
		local b = make("TextButton", {
			Size = UDim2.fromOffset(126, 38),
			BackgroundColor3 = Color3.fromRGB(36, 41, 54),
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = string.upper(w.DisplayName),
			Parent = row,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = b })
		make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = b })
		b.Activated:Connect(function()
			Remotes.get("LoadoutSelect"):FireServer(id)
		end)
		loadoutButtons[id] = b
	end
	player:GetAttributeChangedSignal("Primary"):Connect(refreshLoadout)
	TeamSelectController.RefreshLoadout = refreshLoadout
	refreshLoadout()

	-- Sensibilidade do mouse
	local sens = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 252),
		Size = UDim2.fromOffset(320, 34),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("TextLabel", {
		Size = UDim2.fromOffset(150, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(170, 178, 196),
		Text = "SENSIBILIDADE",
		Parent = sens,
	})
	local sensValue = make("TextLabel", {
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(70, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = sens,
	})
	local function sensButton(text: string, x: number, delta: number)
		local b = make("TextButton", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.fromRGB(36, 41, 54),
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = text,
			Parent = sens,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = b })
		b.Activated:Connect(function()
			SettingsController.setSensitivity(SettingsController.getSensitivity() + delta)
		end)
	end
	-- Campo de visão
	local fovRow = sens:Clone()
	fovRow.Position = UDim2.new(0.5, 0, 0.44, 290)
	fovRow.Parent = gui
	for _, c in fovRow:GetChildren() do
		c:Destroy()
	end
	make("TextLabel", {
		Size = UDim2.fromOffset(150, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(170, 178, 196),
		Text = "CAMPO DE VISÃO",
		Parent = fovRow,
	})
	local fovValue = make("TextLabel", {
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(70, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = fovRow,
	})
	for _, def in { { "-", 160, -SettingsController.FovStep }, { "+", 276, SettingsController.FovStep } } do
		local b = make("TextButton", {
			Position = UDim2.fromOffset(def[2], 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.fromRGB(36, 41, 54),
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = def[1],
			Parent = fovRow,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = b })
		b.Activated:Connect(function()
			SettingsController.setFov(SettingsController.getFov() + def[3])
		end)
	end
	local function refreshFov()
		fovValue.Text = tostring(SettingsController.getFov())
	end
	SettingsController.Changed:Connect(refreshFov)
	refreshFov()

	sensButton("-", 160, -SettingsController.SensitivityStep)
	sensButton("+", 276, SettingsController.SensitivityStep)
	local function refreshSens()
		sensValue.Text = string.format("%.1f", SettingsController.getSensitivity())
	end
	SettingsController.Changed:Connect(refreshSens)
	refreshSens()

	local auto = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 336),
		Size = UDim2.fromOffset(240, 44),
		BackgroundColor3 = Color3.fromRGB(36, 41, 54),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "AUTOMÁTICO",
		Modal = true, -- solta o mouse da primeira pessoa enquanto o menu está aberto
		Parent = gui,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = auto })
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = auto })
	auto.Activated:Connect(function()
		if player.Team then
			TeamSelectController.setOpen(false)
		else
			selectRemote:FireServer("Auto")
		end
	end)
	TeamSelectController.AutoButton = auto
end

function TeamSelectController.init()
	selectRemote = Remotes.get("TeamSelect")
	build()

	for _, name in GameConfig.TeamOrder do
		local team = Teams:WaitForChild(name) :: Team
		team.PlayerAdded:Connect(refresh)
		team.PlayerRemoved:Connect(refresh)
	end
	player:GetPropertyChangedSignal("Team"):Connect(function()
		TeamSelectController.AutoButton.Text = if player.Team then "VOLTAR" else "AUTOMÁTICO"
		if player.Team and open then
			TeamSelectController.setOpen(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M and player.Team then
			TeamSelectController.setOpen(not open)
		end
	end)

	-- Vista aérea enquanto não tem personagem.
	RunService:BindToRenderStep("BlockfrontMenuCamera", Enum.RenderPriority.Camera.Value + 3, function()
		local camera = workspace.CurrentCamera
		if not player.Character then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = OVERVIEW
		end
	end)

	-- Sem personagem, o StreamingEnabled não sabe o que carregar: pede o
	-- centro do mapa para a vista aérea do menu não ficar vazia.
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(Vector3.new(-60, 0, -120))
		end)
	end)

	TeamSelectController.setOpen(player.Team == nil)
end

return TeamSelectController
