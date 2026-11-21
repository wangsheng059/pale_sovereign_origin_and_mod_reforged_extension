this.pale_chain_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "冠军立誓后可标记重伤的亡灵精锐。胜利后完成注魂才会消耗。";
        this.m.Icon = "pale/chain_item.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc | ::Const.Items.ItemType.Quest;
        this.m.Value = 0;
    }
});
