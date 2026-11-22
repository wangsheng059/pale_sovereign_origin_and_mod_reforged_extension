this.pale_witch_hunter <- ::inherit("scripts/entity/tactical/humans/bounty_hunter_ranged", {
    m = {},

    function create()
    {
        this.bounty_hunter_ranged.create();
        this.m.Name = "猎巫人";
    }

    function onInit()
    {
        this.bounty_hunter_ranged.onInit();
        this.addSprite("pale_reliquary").setBrush("pale_reliquary_hunter");
    }
});
