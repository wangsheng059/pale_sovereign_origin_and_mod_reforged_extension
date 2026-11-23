this.pale_chain_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "以黑铁与墓土锻打而成的沉重锁链，链环间隐约回荡着不甘安息的低鸣。立下亡灵冠军誓约后，可在战场上标记重伤的强敌；唯有战胜并完成注魂时才会消耗。两条路线都可在营地把它与一件贵重品锻成缚魂镣铐。立下亡灵天灾誓约后，可用“锁魂复生”唤起亡灵强敌的尸体并在战后收编。";
        this.m.Icon = "pale/chain_item.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc;
        this.m.Value = 400;
    }

    // 1.6.21 出售价固定 400
    function getSellPrice()
    {
        return 400;
    }
});
