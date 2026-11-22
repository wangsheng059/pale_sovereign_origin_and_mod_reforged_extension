this.pale_summon_skeleton <- ::inherit("pale_sovereign/classes/pale_summon_undead", {
    m = {},
    function create()
    {
        this.pale_summon_undead.create();
        this.m.ID = "actives.pale_summon_skeleton";
        this.m.Name = "召唤骷髅";
        this.m.Description = "法杖敲击地面，一副锈甲裹身的古代骸骨从裂开的土缝中站起，空洞的眼窝里燃起魂火。";
        this.m.Icon = "skills/pale_soul_ancient.png";
        this.m.IconDisabled = "skills/pale_soul_ancient_sw.png";
        this.m.Script = "scripts/entity/tactical/bgp_undead/bgp_undead_skeleton_light";
        this.m.MinionName = "受缚古代辅兵";
    }
});
