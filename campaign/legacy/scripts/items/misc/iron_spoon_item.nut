this.iron_spoon_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.iron_spoon";
		this.m.Name = "铁勺";
		this.m.Description = "一把弯得厉害的铁勺，勺柄上打着名字缩写。%name%相信战前用它吃饭能长力气。";
		this.m.Icon = "misc/inventory_iron_spoon.png";
	}
});
