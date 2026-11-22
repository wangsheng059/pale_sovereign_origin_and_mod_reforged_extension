this.pale_summon_zombie <- ::inherit("pale_sovereign/classes/pale_summon_undead", {
    m = {},
    function create()
    {
        this.pale_summon_undead.create();
        this.m.ID = "actives.pale_summon_zombie";
        this.m.Name = "召唤僵尸";
        this.m.Description = "低声念出一个早被遗忘的名字，泥土翻涌，一具腐烂的尸身攥着生前的兵器挣扎着爬出地面。";
        this.m.Icon = "skills/pale_summon_zombie.png";
        this.m.IconDisabled = "skills/pale_summon_zombie_sw.png";
        this.m.ArtStem = "pale_summon_zombie";
        this.m.Script = "scripts/entity/tactical/bgp_undead/bgp_undead_zombie";
        this.m.MasteryScript = "scripts/entity/tactical/bgp_undead/bgp_undead_zombie_yeoman";
        this.m.MinionName = "受缚僵尸";
        this.m.MasteryName = "受缚披甲僵尸";
        this.m.EliteScript = "scripts/entity/tactical/bgp_undead/bgp_undead_zombie_knight";
        this.m.EliteName = "受缚堕落英雄";
        this.m.EliteGear = {
            ReplaceWeapon = true,
            Mainhand = ["weapons/winged_mace", "weapons/fighting_axe", "weapons/noble_sword", "weapons/flail",
                "weapons/greataxe", "weapons/two_handed_flail", "weapons/greatsword"],
            Offhand = ["shields/kite_shield", "shields/heater_shield"],
            Body = ["armor/mail_hauberk", "armor/reinforced_mail_hauberk", "armor/scale_armor"],
            Head = ["helmets/flat_top_helmet", "helmets/kettle_hat_with_mail", "helmets/nasal_helmet_with_mail"]
        };
        this.m.ForNecromancers = true;
        this.m.FearInsteadOfOverwhelm = true;
        // 恐惧之容（perk.rf_terrifying_visage）：造成生命伤害时目标做一次士气检定，失败则惊骇（effects.horrified）
        this.m.EliteExtraSkills = ["scripts/skills/perks/perk_rf_terrifying_visage"];
        this.m.EliteExtraText = "受缚堕落英雄另有“恐惧之容”：造成生命伤害时目标做士气检定，失败则惊骇（直到下回合都无法行动）";
        this.m.Gear = {
            Mainhand = ["weapons/hatchet", "weapons/militia_spear", "weapons/butchers_cleaver", "weapons/wooden_flail", "weapons/knife"],
            Body = ["armor/leather_tunic", "armor/linen_tunic", "armor/padded_surcoat"],
            Head = null
        };
        this.m.MasteryGear = {
            Mainhand = ["weapons/hand_axe", "weapons/morning_star", "weapons/boar_spear", "weapons/scramasax", "weapons/military_pick"],
            Body = ["armor/gambeson", "armor/padded_leather", "armor/basic_mail_shirt"],
            Head = ["helmets/nasal_helmet", "helmets/padded_kettle_hat", "helmets/padded_nasal_helmet"]
        };
    }
});
