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
        this.m.MasteryScript = "scripts/entity/tactical/bgp_undead/bgp_undead_skeleton_medium";
        this.m.MinionName = "受缚古代辅兵";
        this.m.MasteryName = "受缚古代军团士兵";
        this.m.EliteScript = "scripts/entity/tactical/bgp_undead/bgp_undead_skeleton_heavy";
        this.m.EliteName = "受缚古代禁卫军";
        this.m.EliteGear = {
            ReplaceWeapon = true,
            Mainhand = ["weapons/ancient/crypt_cleaver", "weapons/ancient/khopesh", "weapons/ancient/ancient_sword",
                "weapons/ancient/bladed_pike", "weapons/ancient/rhomphaia", "weapons/ancient/warscythe"],
            Offhand = ["shields/ancient/tower_shield", "shields/ancient/coffin_shield"],
            Body = ["armor/ancient/ancient_plate_harness", "armor/ancient/ancient_plated_scale_hauberk", "armor/ancient/ancient_double_layer_mail"],
            Head = ["helmets/ancient/ancient_honorguard_helmet", "helmets/ancient/ancient_legionary_helmet"]
        };
        this.m.Gear = {
            Mainhand = ["weapons/ancient/ancient_sword", "weapons/ancient/ancient_spear", "weapons/ancient/broken_ancient_sword"],
            Body = ["armor/ancient/ancient_ripped_cloth", "armor/ancient/ancient_scale_harness"],
            Head = null
        };
        this.m.MasteryGear = {
            Mainhand = ["weapons/ancient/ancient_sword", "weapons/ancient/ancient_spear", "weapons/ancient/crypt_cleaver"],
            Body = ["armor/ancient/ancient_scale_harness", "armor/ancient/ancient_mail", "armor/ancient/ancient_double_layer_mail"],
            Head = ["helmets/ancient/ancient_household_helmet", "helmets/ancient/ancient_legionary_helmet"]
        };
    }
});
