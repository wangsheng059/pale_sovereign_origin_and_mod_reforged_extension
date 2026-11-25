this.kern_of_the_ancients_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.kern_of_the_ancients";
		this.m.Name = "古人之核";
		this.m.Description = "一座小石头金字塔，即使在最热的天里摸上去也是冰凉的。%name%发誓这是他从黑沼泽一座祭坛的基座里抠出来的。他常拿它压腌肉，说“亡者的寒气”能让食物保鲜。";
		this.m.Icon = "misc/inventory_kern_of_the_ancients.png";
	}
});
