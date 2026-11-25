this.strange_rosary_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.strange_rosary";
		this.m.Name = "怪异牙串念珠";
		this.m.Description = "用驴牙串成的念珠。%name%总说这些是他杀死的流浪骑士的牙。拨动时的咔嗒声像马蹄声，在漫长的行军中莫名让人安心。";
		this.m.Icon = "misc/inventory_strange_rosary.png";
	}
});
