this.orc_shield_mirror_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.orc_shield_mirror";
		this.m.Name = "兽人盾镜";
		this.m.Description = "一块擦得锃亮的金属片，%name%拿它当刮胡子的镜子。";
		this.m.Icon = "misc/inventory_orc_shield_mirror.png";
	}
});
