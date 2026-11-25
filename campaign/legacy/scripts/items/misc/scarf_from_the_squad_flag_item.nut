this.scarf_from_the_squad_flag_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.scarf_from_the_squad_flag";
		this.m.Name = "战旗手帕";
		this.m.Description = "%name%偷偷从军旗上剪下的一小块布，改成了手帕。上面有汗水、钢铁和劣酒的味道。";
		this.m.Icon = "misc/inventory_scarf_from_the_squad_flag.png";
	}
});
