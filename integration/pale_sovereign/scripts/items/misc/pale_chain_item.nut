this.pale_chain_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_chain";
        this.m.Name = "缚魂锁链";
        this.m.Description = "以黑铁与墓土锻打而成的沉重锁链，链环间隐约回荡着不甘安息的低鸣。\n\n· 勇士路线：在战场上标记重伤的强敌（被标记者无法溃逃、近战防御 −10、对导师伤害 −20%），胜利后注魂时消耗；营地可用 1 条剥离一个吞魂特质，2 条锚定双生魂链。\n· 天灾路线：用“锁魂复生”唤起亡灵强敌的尸体，战后收编为锁魂者。\n· 两条路线：锻造缚魂镣铐；胜仗后 1 条锁链 + 4 点防腐尸骸召返阵亡的中阶以上常驻亡灵或锁魂者；也可代替魂玉完成阵亡回收。";
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
