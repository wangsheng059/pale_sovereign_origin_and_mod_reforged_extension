this.goblin_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.goblin_figurine";
		this.m.Name = "地精雕像";
		this.m.Description = "个头小、鼻子尖，丑得出奇。%name%把它刻出来当针插用，往这个“绿皮”背上扎针时格外开心。";
		this.m.Icon = "misc/inventory_goblin_figurine.png";
	}
});
