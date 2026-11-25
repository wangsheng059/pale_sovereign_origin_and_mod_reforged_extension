this.orc_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.orc_figurine";
		this.m.Name = "兽人雕像";
		this.m.Description = "一大块隐约像兽人的橡木。这尊雕像又沉又疙瘩，本身就能当武器使。";
		this.m.Icon = "misc/inventory_orc_figurine.png";
	}
});
