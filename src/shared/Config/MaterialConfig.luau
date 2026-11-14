--[[
	MaterialConfig
	Materiais destrutíveis. Cada célula voxel guarda apenas o Id (u8) do
	material; todas as outras propriedades vêm desta tabela.

	MaxHealth: vida de uma célula. O dano de uma explosão é comparado com ela,
	então materiais com mais vida resistem mais (precisam de explosões maiores
	ou de vários impactos).
	Id 0 é reservado para "vazio".
]]

export type MaterialDef = {
	Id: number,
	Name: string,
	MaxHealth: number,
	Material: Enum.Material,
	Color: Color3,
}

local MaterialConfig = {}

local list: { MaterialDef } = {
	{
		Id = 1,
		Name = "Wood",
		MaxHealth = 30,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(196, 140, 84),
	},
	{
		Id = 2,
		Name = "Brick",
		MaxHealth = 60,
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(214, 98, 72),
	},
	{
		Id = 3,
		Name = "Concrete",
		MaxHealth = 120,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(176, 180, 188),
	},
	{
		Id = 4,
		Name = "Metal",
		MaxHealth = 300,
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(120, 128, 140),
	},
	{
		Id = 5,
		Name = "Sandbag",
		MaxHealth = 45,
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(196, 176, 128),
	},
	{
		Id = 6,
		Name = "Plaster",
		MaxHealth = 45,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(238, 226, 198),
	},
	{
		Id = 7,
		Name = "RoofTile",
		MaxHealth = 60,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(196, 86, 62),
	},
	{
		Id = 8,
		Name = "Planks",
		MaxHealth = 25,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(150, 104, 64),
	},
	{
		Id = 9,
		Name = "PaintedConcrete",
		MaxHealth = 120,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(112, 150, 170),
	},
}

MaterialConfig.ById = {} :: { [number]: MaterialDef }
MaterialConfig.ByName = {} :: { [string]: MaterialDef }

for _, def in list do
	MaterialConfig.ById[def.Id] = def
	MaterialConfig.ByName[def.Name] = def
end

MaterialConfig.EMPTY = 0

return MaterialConfig
