this.pale_gold_ingot_item <- ::inherit("scripts/items/loot/golden_chalice_item", {
    m = {},

    function create()
    {
        this.golden_chalice_item.create();
        this.m.ID = "loot.pale_gold_ingot";
        this.m.Name = "金锭";
        this.m.Description = "古堡金矿出产的金锭，可用于在魂炉为亡灵镀金骨甲。";
        this.m.Value = 350;
    }
});
