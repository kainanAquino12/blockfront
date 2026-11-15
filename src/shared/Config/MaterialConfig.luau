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
	Transparency: number?, -- vidro
}

local MaterialConfig = {}

local list: { MaterialDef } = {
	{
		Id = 1,
		Name = "Wood",
		MaxHealth = 30,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(148, 112, 78),
	},
	{
		Id = 2,
		Name = "Brick",
		MaxHealth = 60,
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(156, 84, 66),
	},
	{
		Id = 3,
		Name = "Concrete",
		MaxHealth = 120,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(150, 150, 146),
	},
	{
		Id = 4,
		Name = "Metal",
		MaxHealth = 300,
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(98, 102, 108),
	},
	{
		Id = 5,
		Name = "Sandbag",
		MaxHealth = 45,
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(160, 146, 112),
	},
	{
		Id = 6,
		Name = "Plaster",
		MaxHealth = 45,
		Material = Enum.Material.Plaster,
		Color = Color3.fromRGB(196, 188, 170),
	},
	{
		Id = 7,
		Name = "RoofTile",
		MaxHealth = 60,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(122, 70, 58),
	},
	{
		Id = 8,
		Name = "Planks",
		MaxHealth = 25,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(118, 88, 62),
	},
	{
		Id = 9,
		Name = "PaintedConcrete",
		MaxHealth = 120,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(150, 156, 150),
	},
	{
		Id = 10,
		Name = "Glass",
		MaxHealth = 5, -- qualquer tiro quebra
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(120, 150, 166),
		Transparency = 0.45,
	},
	{
		Id = 11,
		Name = "SheetMetal",
		MaxHealth = 150,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(110, 118, 124),
	},
	{
		Id = 12,
		Name = "PlasterYellow",
		MaxHealth = 45,
		Material = Enum.Material.Plaster,
		Color = Color3.fromRGB(184, 164, 120),
	},
	{
		Id = 13,
		Name = "PlasterGreen",
		MaxHealth = 45,
		Material = Enum.Material.Plaster,
		Color = Color3.fromRGB(132, 142, 118),
	},
	{
		Id = 14,
		Name = "BarnWood",
		MaxHealth = 30,
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(126, 62, 50),
	},
	{
		Id = 15,
		Name = "Military",
		MaxHealth = 140,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(104, 110, 88),
	},
	{
		Id = 16,
		Name = "DarkBrick",
		MaxHealth = 60,
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(110, 62, 54),
	},
	{
		Id = 17,
		Name = "Hay",
		MaxHealth = 20,
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(176, 154, 96),
	},
	{
		Id = 18,
		Name = "RoofGreen",
		MaxHealth = 60,
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(84, 108, 66),
	},
	{
		Id = 19,
		Name = "Stone", -- cornijas, peitoris, pilastras claras
		MaxHealth = 120,
		Material = Enum.Material.Limestone,
		Color = Color3.fromRGB(132, 128, 120),
	},
	{
		Id = 20,
		Name = "Awning", -- marquises e toldos de lona
		MaxHealth = 20,
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(78, 92, 84),
	},
	{
		Id = 21,
		Name = "DarkMetal", -- guarda-corpos, ar-condicionado, antenas
		MaxHealth = 200,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(62, 66, 72),
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
