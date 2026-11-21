this.pale_witch_hunter <- ::inherit("scripts/entity/tactical/humans/bounty_hunter_ranged", {
    m = {},

    function create()
    {
        this.bounty_hunter_ranged.create();
        this.m.Name = "猎巫人";
    }
});
