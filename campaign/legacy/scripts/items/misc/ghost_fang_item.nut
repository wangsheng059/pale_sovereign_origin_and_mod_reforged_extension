this.ghost_fang_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.ghost_fang";
		this.m.Name = "幽魂之牙";
		this.m.Description = "一块半透明的绿色石英碎片。%name%坚信这是他在夜战死灵法师大军时“打掉”的一颗“鬼牙”。到了夜里，这块石头会发出微光。你对此无法解释。";
		this.m.Icon = "misc/inventory_ghost_fang.png";
	}
});
