--[[
	InteriorLightController (cliente) — desempenho das luzes internas (V8).

	As luminárias dos prédios (tag "BFInteriorLight", criadas pelo servidor)
	só ficam ligadas perto da câmera. Com centenas de PointLights no mapa,
	isso evita que o motor processe luzes de prédios distantes ou que o
	jogador nem está vendo. Atualiza em lotes a cada 0,35 s.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local InteriorLightController = {}

local RANGE = 150
local INTERVAL = 0.35

local lights: { PointLight } = {}
local index: { [PointLight]: number } = {}

local function add(l: Instance)
	if l:IsA("PointLight") and not index[l] then
		table.insert(lights, l)
		index[l] = #lights
		l.Enabled = false
	end
end

local function remove(l: Instance)
	local i = index[l :: any]
	if i then
		local last = lights[#lights]
		lights[i] = last
		index[last] = i
		lights[#lights] = nil
		index[l :: any] = nil
	end
end

function InteriorLightController.getEnabledCount(): number
	local n = 0
	for _, l in lights do
		if l.Enabled then
			n += 1
		end
	end
	return n
end

function InteriorLightController.init()
	for _, l in CollectionService:GetTagged("BFInteriorLight") do
		add(l)
	end
	CollectionService:GetInstanceAddedSignal("BFInteriorLight"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("BFInteriorLight"):Connect(remove)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < INTERVAL then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local pos = cam.CFrame.Position
		for _, l in lights do
			local p = l.Parent
			if p and p:IsA("BasePart") then
				local near = (p.Position - pos).Magnitude < RANGE
				if l.Enabled ~= near then
					l.Enabled = near
				end
			end
		end
	end)
end

return InteriorLightController
