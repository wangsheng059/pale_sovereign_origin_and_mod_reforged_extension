this.collection_of_dried_mushrooms_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.collection_of_dried_mushrooms";
		this.m.Name = "干蘑菇串";
		this.m.Description = "一根绳上串着五只干瘪的蘑菇。%name%常说其中两只能治病，两只是剧毒，最后一只能让人看见未来。问题是，你已经完全记不清哪只是哪只了。";
		this.m.Icon = "misc/inventory_collection_of_dried_mushrooms.png";
	}
});
