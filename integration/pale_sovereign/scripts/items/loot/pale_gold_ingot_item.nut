this.pale_gold_ingot_item <- ::inherit("scripts/items/loot/golden_chalice_item", {
    m = {},

    function create()
    {
        this.golden_chalice_item.create();
        this.m.ID = "loot.pale_gold_ingot";
        this.m.Name = "金锭";
        this.m.Description = "从古堡金矿炼出的金锭，沉甸甸的。可在魂炉为亡灵镀金骨甲，也能卖个好价钱。";
        this.m.Icon = "pale/gold_ingot.png";
        this.m.IconLarge = this.m.Icon;
        this.m.Value = 350;
    }
});
