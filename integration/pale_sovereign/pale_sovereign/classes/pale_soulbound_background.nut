// 锁魂者的共用背景。具体类别见 pale_sovereign/soulbound.nut 的 S.SoulboundClasses
this.pale_soulbound_background <- ::inherit("scripts/skills/backgrounds/pale_undead_background", {
    m = { PaleSoulClass = "", PaleLook = "" },

    function create()
    {
        this.pale_undead_background.create();
        local def = ::PaleSovereign.SoulboundClasses[this.m.PaleSoulClass];
        this.m.ID = "background.pale_sb_" + this.m.PaleSoulClass;
        this.m.Name = def.Name;
        this.m.PaleSkeleton = def.Skeleton;
        this.m.PaleLook = def.Look;
        this.m.Icon = "ui/backgrounds/pale_sb_" + this.m.PaleSoulClass + ".png";
        this.m.BackgroundDescription = def.Description;
    }

    function onBuildDescription()
    {
        return this.m.BackgroundDescription;
    }

    function getTooltip()
    {
        local ret = this.pale_undead_background.getTooltip();
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "锁魂者：以缚魂锁链收编的亡灵强敌，使用" + this.m.Name + "专属技能树，不参与常驻亡灵升阶。" });
        try
        {
            local legacy = this.getContainer().getActor().getFlags().get("PaleLegacy");
            if (typeof legacy == "string" && legacy != "")
                ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "生前特技：" + legacy });
        }
        catch (e)
        {
        }
        return ret;
    }

    function createPerkTreeBlueprint()
    {
        local S = ::PaleSovereign;
        local def = S.SoulboundClasses[this.m.PaleSoulClass];
        local groups = {
            ["pgc.rf_weapon"] = def.Groups[0].map(@(group) "pg.rf_" + group),
            ["pgc.rf_fighting_style"] = def.Groups[1].map(@(group) "pg.rf_" + group),
            ["pgc.rf_armor"] = def.Groups[2].map(@(group) "pg.rf_" + group),
            ["pgc.rf_shared_1"] = def.Groups[3].map(@(group) "pg.rf_" + group),
            ["pgc.rf_exclusive_1"] = ["pg.pale_sb_" + this.m.PaleSoulClass]
        };
        return ::new(::DynamicPerks.Class.PerkTree).init({ DynamicMap = groups });
    }

    function getPerkGroupMultiplier( _groupID, _tree )
    {
        local def = ::PaleSovereign.SoulboundClasses[this.m.PaleSoulClass];
        if (_groupID.find("pg.rf_") == 0)
        {
            local group = _groupID.slice(6);
            if (def.Excluded.find(group) != null)
                return 0;
            if (def.Weighted.find(group) != null)
                return 3;
        }
        if (this.m.PaleSoulClass == "hex" && _groupID == "pg.special.rf_leadership")
            return 3;
        return this.pale_undead_background.getPerkGroupMultiplier(_groupID, _tree);
    }
});
