this.wooden_jaw_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.wooden_jaw";
		this.m.Name = "木下巴";
		this.m.Description = "%name%见识过兽人连枷能把人脸打成什么样之后，“以防万一”给自己刻的备用假下巴。看着吓人，闻着有股松木味。";
		this.m.Icon = "misc/inventory_wooden_jaw.png";
	}
});
