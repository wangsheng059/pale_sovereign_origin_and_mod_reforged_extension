this.pale_gilded_bones <- ::inherit("scripts/items/armor/tattered_sackcloth", {
    m = {},

    function create()
    {
        this.tattered_sackcloth.create();
        this.m.ID = "armor.pale_gilded_bones";
        this.m.Name = "镀金骨骸";
        this.m.ConditionMax = 1;
        this.m.Condition = 1;
        this.m.IsDroppedAsLoot = false;
    }
});
