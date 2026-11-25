this.brass_knuckles_fork_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.brass_knuckles_fork";
		this.m.Name = "指虎餐叉";
		this.m.Description = "一把沉重的双齿木叉，叉柄格外粗壮。%name%用它叉肉，顺手还能往烦人的新兵脑袋上敲几下。";
		this.m.Icon = "misc/inventory_brass_knuckles_fork.png";
	}
});
