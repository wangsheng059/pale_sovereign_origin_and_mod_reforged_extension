this.pale_gilded_skull <- ::inherit("scripts/items/helmets/hood", {
    m = {},

    function create()
    {
        this.hood.create();
        this.m.ID = "helmet.pale_gilded_skull";
        this.m.Name = "镀金颅骨";
        this.m.ConditionMax = 1;
        this.m.Condition = 1;
        this.m.IsDroppedAsLoot = false;
    }
});
