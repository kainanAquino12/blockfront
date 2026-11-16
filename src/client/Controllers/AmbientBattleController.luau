--[[
	AmbientBattleController (cliente) — clima sonoro de guerra (V10).

	Toca, de tempos em tempos, combate DISTANTE fora do campo de visão:
	rajadas curtas de fuzil/metralhadora e explosões abafadas, sempre longe
	(300 a 650 studs) e no grupo "Distant" (agudos cortados). Não tem nenhum
	efeito no jogo: só som, gerado localmente em cada cliente.

	Volume baixo de propósito para não confundir com tiros de verdade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local AudioController = require(script.Parent.AudioController)

local AmbientBattleController = {}

local rng = Random.new()

local function farPoint(): Vector3
	local cam = workspace.CurrentCamera
	local pos = cam and cam.CFrame.Position or Vector3.zero
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(300, 650)
	return pos + Vector3.new(math.cos(a) * d, rng:NextNumber(5, 40), math.sin(a) * d)
end

local function burst()
	local ids = { WeaponConfig.Sounds.RifleFire, WeaponConfig.Sounds.LmgFire, WeaponConfig.Sounds.SmgFire }
	local id = ids[rng:NextInteger(1, #ids)]
	local at = farPoint()
	local shots = rng:NextInteger(3, 8)
	local gap = rng:NextNumber(0.08, 0.16)
	for i = 1, shots do
		task.delay((i - 1) * gap, function()
			AudioController.play(id, at, { Category = "Shot", Volume = 0.35, Vary = 0.08, Distant = true })
		end)
	end
end

local function boom()
	AudioController.play(AudioConfig.Explosion.Distant, farPoint(), { Category = "Explosion", Volume = 0.45, Vary = 0.12, Distant = true })
end

function AmbientBattleController.init()
	task.spawn(function()
		task.wait(8)
		while true do
			task.wait(rng:NextNumber(5, 12))
			burst()
			if rng:NextNumber() < 0.35 then
				task.wait(rng:NextNumber(1, 4))
				boom()
			end
		end
	end)
end

return AmbientBattleController
