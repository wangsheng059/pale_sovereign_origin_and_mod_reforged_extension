this.pipe_of_the_dead_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.pipe_of_the_dead";
		this.m.Name = "亡者烟斗";
		this.m.Description = "一支用骷髅战士的股骨做成的大烟斗，斗钵上精雕着一颗骷髅。每逢大战过后，%name%都会塞上廉价烟草独自抽上一斗，说烟雾会“把战死者的魂灵送去应得的安息之所”。";
		this.m.Icon = "misc/inventory_pipe_of_the_dead.png";
	}
});
