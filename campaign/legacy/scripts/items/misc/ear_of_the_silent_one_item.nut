this.ear_of_the_silent_one_item <- this.inherit("scripts/items/misc/veteran_trinket_item", {
	m = {},
	function create()
	{
		this.veteran_trinket_item.create();
		this.m.ID = "misc.ear_of_the_silent_one";
		this.m.Name = "沉默者之耳";
		this.m.Description = "装在小盒子里的一只风干的耳朵，不知是谁的。%name%心里憋闷时就对着它倾诉，因为它比活人更会保守秘密。";
		this.m.Icon = "misc/inventory_ear_of_the_silent_one.png";
	}
});
