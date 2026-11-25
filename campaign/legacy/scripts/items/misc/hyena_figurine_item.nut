this.hyena_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.hyena_figurine";
		this.m.Name = "鬣狗雕像";
		this.m.Description = "看起来像被真鬣狗啃过，满是缺口和凿痕。%name%声称它夜里会笑。";
		this.m.Icon = "misc/inventory_hyena_figurine.png";
	}
});
