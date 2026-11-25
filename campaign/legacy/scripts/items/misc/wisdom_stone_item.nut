this.wisdom_stone_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.wisdom_stone";
		this.m.Name = "智慧之石";
		this.m.Description = "一块画了张脸的普通鹅卵石。%name%战前会跟它商量好几个钟头。最怪的是——这块石头偶尔还真能给出靠谱的建议（至少%name%这么认为）。";
		this.m.Icon = "misc/inventory_wisdom_stone.png";
	}
});
