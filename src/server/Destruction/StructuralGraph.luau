--[[
	StructuralGraph (servidor) — STRUCTURAL INTEGRITY.

	Grafo de elementos estruturais sobre a grade voxel de uma construção.
	Cada célula pertence a um elemento (buffer ElementOf, u16). Os tipos e
	parâmetros ficam em StructuralConfig.Types.

	Construção do grafo (uma vez):
	  1. conta células, massa (células x densidade) e caixa de cada elemento;
	  2. varre as faces entre células de elementos diferentes e classifica o
	     contato: "apoiado em" (célula de B logo abaixo de A), lateral ou acima;
	  3. aplica as regras de apoio (quem sustenta quem e com que peso):
	       - qualquer elemento apoiado EM CIMA de um estrutural   peso 1
	       - viga/laje presa NA LATERAL de pilar/parede portante/viga  peso 1
	       - pilar pendurado na lateral de uma viga (transferência)  peso 0.05
	       - não estrutural (vidro, vedação, divisória, móvel) preso
	         em qualquer face de um estrutural, ou apoiado em outro   peso 1
	       - fundação: apoiada no chão
	  4. calcula a carga de projeto e define a capacidade de cada elemento
	     estrutural = max(carga, massa própria) x Safety do tipo.

	Avaliação (a cada mudança):
	  a. elemento estrutural com integridade < FailBelow rompe na hora;
	  b. BFS a partir das fundações define o "nível" de apoio de cada
	     elemento; quem não é alcançado está solto e cai;
	  c. carga de cima para baixo (nível decrescente): cada elemento soma a
	     massa viva + o que recebeu e reparte entre os apoios de nível menor,
	     pelo peso do apoio (isso mantém o grafo acíclico);
	  d. carga > capacidade x integridade, ou viga/laje sem apoios mínimos e
	     com vão maior que o balanço permitido => INSTÁVEL. O elemento range
	     por UnstableDelay segundos e então rompe, se continuar instável.
	     Isso gera o colapso progressivo em etapas.

	Divisórias e vidro não sustentam nada: removê-los não derruba nada.
	Tiros pequenos só removem células; o grafo só reage quando a
	integridade de um elemento estrutural cai de verdade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StructuralConfig = require(ReplicatedStorage.Shared.Config.StructuralConfig)
local MaterialConfig = require(ReplicatedStorage.Shared.Config.MaterialConfig)

export type ElementDef = { Type: string, Name: string, Material: number }

local Types = StructuralConfig.Types

local StructuralGraph = {}
StructuralGraph.__index = StructuralGraph

local function density(materialId: number): number
	local def = MaterialConfig.ById[materialId]
	return def and StructuralConfig.Density[def.Name] or 1
end

--[[
	defs: lista de ElementDef (índice = id do elemento, 1..n)
	elementOf: buffer u16 com o id do elemento de cada célula (0 = nenhum)
]]
function StructuralGraph.new(grid, defs: { ElementDef }, elementOf: buffer)
	local self = setmetatable({}, StructuralGraph)
	self.Grid = grid
	self.ElementOf = elementOf
	local n = #defs
	self.Count = n

	local E = {}
	for id = 1, n do
		local d = defs[id]
		local t = Types[d.Type]
		assert(t, "StructuralGraph: tipo desconhecido " .. tostring(d.Type))
		E[id] = {
			Id = id,
			Type = d.Type,
			Name = d.Name,
			T = t,
			Structural = t.Structural == true,
			Cells = {},
			Total = 0,
			Alive = 0,
			MassPerCell = density(d.Material),
			Min = Vector3.new(math.huge, math.huge, math.huge),
			Max = Vector3.new(-math.huge, -math.huge, -math.huge),
			Supporters = {} :: { [number]: number }, -- id -> peso
			Dependents = {} :: { [number]: true },
			Capacity = math.huge,
			Broken = false,
			UnstableAt = nil :: number?,
			Level = nil :: number?,
			Load = 0,
		}
	end
	self.Elements = E

	-- 1. células e caixas
	local sx, sy, sz = grid.sizeX, grid.sizeY, grid.sizeZ
	local sxy = sx * sy
	local mats = grid.materials
	for i = 0, grid.count - 1 do
		local id = buffer.readu16(elementOf, i * 2)
		if id ~= 0 and buffer.readu8(mats, i) ~= 0 then
			local e = E[id]
			table.insert(e.Cells, i)
			e.Total += 1
			local x = i % sx
			local y = (i // sx) % sy
			local z = i // sxy
			local p = Vector3.new(x, y, z)
			e.Min = e.Min:Min(p)
			e.Max = e.Max:Max(p)
		end
	end
	for _, e in E do
		e.Alive = e.Total
		if e.Total == 0 then
			e.Broken = true
		end
	end

	-- 2. contatos entre elementos
	local contacts: { [number]: { [number]: { below: boolean?, side: boolean?, above: boolean? } } } = {}
	local function contact(a: number, b: number, kind: string)
		local ca = contacts[a]
		if not ca then
			ca = {}
			contacts[a] = ca
		end
		local k = ca[b]
		if not k then
			k = {}
			ca[b] = k
		end
		k[kind] = true
	end
	for i = 0, grid.count - 1 do
		local a = buffer.readu16(elementOf, i * 2)
		if a ~= 0 and buffer.readu8(mats, i) ~= 0 then
			local x = i % sx
			local y = (i // sx) % sy
			-- só direções positivas (cada face uma vez)
			if x < sx - 1 then
				local j = i + 1
				local b = buffer.readu16(elementOf, j * 2)
				if b ~= 0 and b ~= a and buffer.readu8(mats, j) ~= 0 then
					contact(a, b, "side")
					contact(b, a, "side")
				end
			end
			if i // sxy < sz - 1 then
				local j = i + sxy
				local b = buffer.readu16(elementOf, j * 2)
				if b ~= 0 and b ~= a and buffer.readu8(mats, j) ~= 0 then
					contact(a, b, "side")
					contact(b, a, "side")
				end
			end
			if y < sy - 1 then
				local j = i + sx
				local b = buffer.readu16(elementOf, j * 2)
				if b ~= 0 and b ~= a and buffer.readu8(mats, j) ~= 0 then
					contact(b, a, "below") -- b está em cima de a
					contact(a, b, "above")
				end
			end
		end
	end

	-- 3. regras de apoio
	for a, list in contacts do
		local A = E[a]
		if A.Type ~= "Foundation" then
			for b, k in list do
				local B = E[b]
				local w = 0
				if k.below and (B.Structural or not A.Structural) then
					w = 1
				elseif not A.Structural and B.Structural then
					w = 1 -- vedação/acabamento presa na lateral de um estrutural
				elseif k.side and (A.Type == "Beam" or A.Type == "Slab")
					and (B.Type == "Column" or B.Type == "BearingWall" or B.Type == "Beam" or B.Type == "Foundation") then
					w = 1
				elseif k.side and (A.Type == "Column" or A.Type == "BearingWall") and B.Type == "Beam" then
					w = 0.05
				end
				if w > 0 then
					A.Supporters[b] = w
					B.Dependents[a] = true
				end
			end
		end
	end

	-- 4. carga de projeto -> capacidade
	local loose = self:_solve(true)
	self.DesignWarnings = {}
	for _, id in loose do
		table.insert(self.DesignWarnings, E[id].Name)
	end
	for _, e in E do
		if e.Hanging then
			table.insert(self.DesignWarnings, e.Name .. " (pendurado)")
		end
	end
	for _, e in E do
		if e.Structural and e.T.Safety then
			local base = math.max(e.Load, e.Total * e.MassPerCell)
			e.Capacity = base * e.T.Safety
		end
	end
	return self
end

function StructuralGraph:integrity(e): number
	return if e.Total > 0 then e.Alive / e.Total else 0
end

-- Maior ou menor dimensão horizontal (para o teste de balanço).
local function spanOf(e): number
	local size = e.Max - e.Min + Vector3.one
	if e.Type == "Slab" then
		return math.min(size.X, size.Z) -- laje: profundidade do balanço
	end
	return math.max(size.X, size.Z) -- viga: comprimento
end

--[[
	Calcula níveis e cargas. Retorna a lista de ids não alcançados (soltos).
	design = true: só calcula (sem instabilidade).
]]
function StructuralGraph:_solve(design: boolean): { number }
	local E = self.Elements
	local queue = {}
	for _, e in E do
		e.Level = nil
		e.Load = 0
		if not e.Broken and e.Alive > 0 and e.T.Grounded then
			e.Level = 0
			table.insert(queue, e.Id)
		end
	end
	local head = 1
	while head <= #queue do
		local cur = E[queue[head]]
		head += 1
		for d in cur.Dependents do
			local D = E[d]
			if D.Level == nil and not D.Broken and D.Alive > 0 then
				D.Level = cur.Level + 1
				table.insert(queue, d)
			end
		end
	end

	local loose = {}
	for _, e in E do
		if not e.Broken and e.Alive > 0 and e.Level == nil then
			table.insert(loose, e.Id)
		end
	end

	--[[
		Carga, de cima para baixo. A ordem é (altura da base, nível de apoio):
		um elemento só passa carga para apoios ESTRITAMENTE abaixo nessa ordem.
		Isso faz o peso descer pelos pilares (pilar de cima -> pilar de baixo)
		e não "vazar" de lado. Um elemento estrutural que só está preso a
		coisas na mesma altura ou acima (ex.: pilar cujo apoio de baixo sumiu
		e que ficou pendurado na viga de cima) fica marcado como Hanging:
		instável, rompe depois do tempo de aviso.
	]]
	local function below(S, e): boolean
		if S.Min.Y ~= e.Min.Y then
			return S.Min.Y < e.Min.Y
		end
		return S.Level < e.Level
	end
	table.sort(queue, function(a, b)
		local A, B = E[a], E[b]
		if A.Min.Y ~= B.Min.Y then
			return A.Min.Y > B.Min.Y
		end
		return A.Level > B.Level
	end)
	for _, id in queue do
		local e = E[id]
		local total = e.Alive * e.MassPerCell + e.Load
		e.Load = total
		e.Hanging = false
		if not e.T.Grounded then
			local sumW = 0
			for s, w in e.Supporters do
				local S = E[s]
				if not S.Broken and S.Level ~= nil and below(S, e) then
					sumW += w
				end
			end
			if sumW > 0 then
				for s, w in e.Supporters do
					local S = E[s]
					if not S.Broken and S.Level ~= nil and below(S, e) then
						S.Load += total * w / sumW
					end
				end
			elseif e.Structural then
				e.Hanging = true
			end
		end
	end
	return loose
end

-- Uma célula foi removida (explosão, tiro ou colapso).
function StructuralGraph:cellRemoved(i: number)
	local id = buffer.readu16(self.ElementOf, i * 2)
	if id ~= 0 then
		local e = self.Elements[id]
		e.Alive = math.max(e.Alive - 1, 0)
	end
end

--[[
	Avalia a estrutura. Retorna:
	  breaks: ids de elementos que rompem AGORA (soltos, rompidos ou
	          instáveis com o tempo esgotado);
	  pending: true se há elementos rangendo (avaliar de novo no próximo passo).
]]
function StructuralGraph:evaluate(now: number): ({ number }, boolean)
	local E = self.Elements
	local breaks = {}

	-- a. integridade
	for _, e in E do
		if not e.Broken and e.Structural and e.T.FailBelow and e.Alive > 0 then
			if self:integrity(e) < e.T.FailBelow then
				e.Broken = true
				table.insert(breaks, e.Id)
			end
		end
	end

	-- b + c. apoio e carga
	local loose = self:_solve(false)
	for _, id in loose do
		E[id].Broken = true
		table.insert(breaks, id)
	end

	-- d. instabilidade
	local pending = false
	local brokeByTimer = 0
	for _, e in E do
		if not e.Broken and e.Structural and e.Level ~= nil and not e.T.Grounded then
			local unstable = false
			if e.T.Safety and e.Load > e.Capacity * self:integrity(e) then
				unstable = true
			end
			if e.Hanging then
				unstable = true -- preso só por cima/de lado: não há caminho de carga até o chão
			end
			if e.T.MinSupports then
				local primary = 0
				for s, w in e.Supporters do
					local S = E[s]
					if w >= 1 and not S.Broken and S.Level ~= nil and S.Level < e.Level then
						primary += 1
					end
				end
				if primary < e.T.MinSupports and spanOf(e) > (e.T.MaxCantilever or 0) then
					unstable = true
				end
			end
			if unstable then
				if e.UnstableAt == nil then
					local span = StructuralConfig.UnstableDelayMax - StructuralConfig.UnstableDelayMin
					e.UnstableAt = now + StructuralConfig.UnstableDelayMin + math.random() * span
					pending = true
				elseif now >= e.UnstableAt and brokeByTimer < StructuralConfig.MaxBreaksPerStep then
					e.Broken = true
					brokeByTimer += 1
					table.insert(breaks, e.Id)
					pending = true -- a ruptura muda as cargas: reavaliar
				else
					pending = true
				end
			else
				e.UnstableAt = nil
			end
		end
	end
	return breaks, pending
end

-- Células ainda vivas de um elemento (para virar corpos físicos).
function StructuralGraph:aliveCells(id: number): { number }
	local e = self.Elements[id]
	local out = {}
	local mats = self.Grid.materials
	for _, i in e.Cells do
		if buffer.readu8(mats, i) ~= 0 then
			table.insert(out, i)
		end
	end
	return out
end

function StructuralGraph:findByName(name: string)
	for _, e in self.Elements do
		if e.Name == name then
			return e
		end
	end
	return nil
end

-- Resumo para depuração e testes.
function StructuralGraph:summary(): { [string]: number }
	local s = { Elements = 0, Broken = 0, Unstable = 0 }
	for _, e in self.Elements do
		if e.Total > 0 then
			s.Elements += 1
			if e.Broken then
				s.Broken += 1
			elseif e.UnstableAt then
				s.Unstable += 1
			end
		end
	end
	return s
end

return StructuralGraph
