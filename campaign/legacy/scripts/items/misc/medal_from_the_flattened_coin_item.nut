this.medal_from_the_flattened_coin_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.medal_from_the_flattened_coin";
		this.m.Name = "压扁硬币勋章";
		this.m.Description = "一枚被辎重车碾扁的旧克朗。%name%把它当“服役勋章”佩戴，声称是皇帝（已经死了好几百年）亲手颁给他的。";
		this.m.Icon = "misc/inventory_medal_from_the_flattened_coin.png";
	}
});
