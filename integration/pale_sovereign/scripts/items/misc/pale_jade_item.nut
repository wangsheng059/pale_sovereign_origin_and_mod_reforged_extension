this.pale_jade_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_jade";
        this.m.Name = "古代魂玉";
        this.m.Description = "一块封有残魂的碧石。可在扎营时晋升墓穴守卫，也能用于定制锁链。";
        this.m.Icon = "pale/jade.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc | ::Const.Items.ItemType.Quest;
        this.m.Value = 0;
    }
});
