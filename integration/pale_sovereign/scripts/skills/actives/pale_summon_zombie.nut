this.pale_summon_zombie <- ::inherit("pale_sovereign/classes/pale_summon_undead", {
    m = {},
    function create()
    {
        this.pale_summon_undead.create();
        this.m.ID = "actives.pale_summon_zombie";
        this.m.Name = "召唤僵尸";
        this.m.Description = "导师低声念出一个早被遗忘的名字，泥土翻涌，一具腐烂的尸身挣扎着爬出地面。";
        this.m.Icon = "skills/pale_fallen.png";
        this.m.IconDisabled = "skills/pale_fallen_sw.png";
        this.m.Script = "scripts/entity/tactical/bgp_undead/bgp_undead_zombie";
        this.m.MinionName = "受缚僵尸";
    }
});
