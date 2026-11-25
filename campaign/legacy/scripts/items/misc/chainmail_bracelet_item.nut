this.chainmail_bracelet_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.chainmail_bracelet";
		this.m.Name = "锁甲手环";
		this.m.Description = "用%name%缝补过上百次的那件盔甲的碎片编成的手环。象征着无尽的耐心，以及同样无尽的修补。";
		this.m.Icon = "misc/inventory_chainmail_bracelet.png";
	}
});
