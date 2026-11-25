this.wolfs_fang_whistle_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.wolfs_fang_whistle";
		this.m.Name = "狼牙哨";
		this.m.Description = "吹出来的声音尖利又走调。%name%发誓它能驱邪，但实际上它只会惹军士心烦。";
		this.m.Icon = "misc/inventory_wolfs_fang_whistle.png";
	}
});
