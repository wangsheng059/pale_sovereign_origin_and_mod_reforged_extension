this.strange_little_bag_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.strange_little_bag";
		this.m.Name = "奇怪的小布袋";
		this.m.Description = "%name%声称里面装着“祖先的泥土”。其实那只是你们第一次一起上路时的路边尘土，但%name%把它当作最神圣的遗物珍藏。";
		this.m.Icon = "misc/inventory_strange_little_bag.png";
	}
});
