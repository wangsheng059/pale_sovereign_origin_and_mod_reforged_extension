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
        local rows = [];
        foreach (row in ::PaleSovereign.SoulboundClasses[this.m.PaleSoulClass].Tree)
        {
            local valid = [];
            foreach (id in row)
            {
                if (::Const.Perks.findById(id) != null)
                    valid.push(id);
                else
                    ::logWarning("Pale Sovereign: soulbound perk " + id + " not found");
            }
            rows.push(valid);
        }
        return ::new(::DynamicPerks.Class.PerkTree).init({ Template = rows });
    }
});
