this.curvy_maiden_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.curvy_maiden";
		this.m.Name = "丰满少女像";
		this.m.Description = "一尊身材夸张得离谱的木制女人像。%name%管她叫“唯一的真爱”——不要克朗，也不会跟贵族骑士私奔的那种。";
		this.m.Icon = "misc/inventory_the_curvy_maiden.png";
	}
});
