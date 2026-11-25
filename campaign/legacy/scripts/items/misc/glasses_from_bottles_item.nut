this.glasses_from_bottles_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.glasses_from_bottles";
		this.m.Name = "瓶底眼镜";
		this.m.Description = "用瓶底和一条腰带做成的眼镜。%name%“清点战利品”时总要戴上，说能让他更专注。又或许他只是想显得有学问？";
		this.m.Icon = "misc/inventory_glasses_from_bottles.png";
	}
});
