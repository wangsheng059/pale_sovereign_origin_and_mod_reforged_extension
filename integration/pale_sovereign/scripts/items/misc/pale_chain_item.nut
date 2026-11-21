this.pale_chain_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "以黑铁与墓土锻打而成的沉重锁链，链环间隐约回荡着不甘安息的低鸣。立下亡灵冠军誓约后，可在战场上标记重伤的强敌；唯有战胜并完成注魂时才会消耗。";
        this.m.Icon = "pale/chain_item.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc | ::Const.Items.ItemType.Quest;
        this.m.Value = 0;
    }
});
