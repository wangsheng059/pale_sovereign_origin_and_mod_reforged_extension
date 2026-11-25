this.nachzehrer_figurine_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.nachzehrer_figurine";
		this.m.Name = "食尸鬼雕像";
		this.m.Description = "一尊雕工精细的雕像，下颚大得不成比例。%name%在它嘴里放盐，说这是世上唯一和行军中的佣兵一样能吃的生物。";
		this.m.Icon = "misc/inventory_nachzehrer_figurine.png";
	}
});
