this.emperors_skull_fragment_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.emperors_skull_fragment";
		this.m.Name = "皇帝头骨碎片";
		this.m.Description = "一块残留着雕刻纹样的人类头骨。%name%发誓这块发黄的骨头来自骷髅王本人的头骨，还相信它会低语帝国军团早已失传的战术。战团里多数人觉得这不过是块老骨头，但看到%name%每晚睡前满心欢喜地擦拭这件“圣物”，谁也不忍心说破。";
		this.m.Icon = "misc/inventory_emperors_skull_fragment.png";
	}
});
