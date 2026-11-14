--[[
	Remotes
	Ponto único de criação e acesso aos RemoteEvents.
	O servidor cria todos em ReplicatedStorage.Remotes (Remotes.init);
	o cliente apenas obtém (Remotes.get), esperando se ainda não chegaram.

	Toda mensagem cliente -> servidor deve ser validada no handler do
	servidor (tipos, distância, cadência). Nunca confiar no cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- Lista oficial de eventos. Adicionar aqui antes de usar.
local EVENT_NAMES = {
	"DestructionBatch", -- servidor -> clientes: células destruídas + explosões (agrupado)
	"DevExplosionRequest", -- cliente -> servidor: explosão de teste (somente Studio)
}

local Remotes = {}

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init só pode rodar no servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	assert(table.find(EVENT_NAMES, name), "Remote desconhecido: " .. name)
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder, "Remotes.init ainda não foi chamado")
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
