this.snake_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.snake_figurine";
		this.m.Name = "柳条蛇";
		this.m.Description = "用几根柳条和碎绳编成的蛇。%name%最爱把它塞进新兵的铺盖里，考验他们的反应和骂人的功夫。";
		this.m.Icon = "misc/inventory_snake_figurine.png";
	}
});
