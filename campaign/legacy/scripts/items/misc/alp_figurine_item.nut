this.alp_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.alp_figurine";
		this.m.Name = "梦魇雕像";
		this.m.Description = "一尊扭曲诡异的雕像，木纹苍白。%name%有时会把它放在熟睡战友的胸口上。打发时间的好法子。";
		this.m.Icon = "misc/inventory_alp_figurine.png";
	}
});
