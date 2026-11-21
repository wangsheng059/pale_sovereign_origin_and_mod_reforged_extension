this.pale_undead_background <- ::inherit("scripts/skills/backgrounds/character_background", {
    m = { PaleSkeleton = false },
    function create()
    {
        this.character_background.create();
        this.m.HiringCost = 0;
        this.m.DailyCost = 0;
        this.m.Titles = [];
        this.m.GoodEnding = "%name% 回到醒来的地方，将武器留在了墓门前。";
        this.m.BadEnding = "战团散去以后，再也没人听见 %name% 的脚步声。";
        this.m.ExcludedTalents = [::Const.Attributes.Bravery];
    }

    function onBuildDescription()
    {
        return "{%name% 从盐封棺中醒来。它记不清自己的名字，却还记得如何列阵。}";
    }

    function getTooltip()
    {
        local ret = this.character_background.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "常驻亡灵。零薪水、零粮耗，免疫常规士气变化。受伤时需要用防腐尸骸修复。" });
        return ret;
    }

    function onAdded()
    {
        this.character_background.onAdded();
        if (this.m.PaleSkeleton && !this.getContainer().hasSkill("racial.skeleton"))
            this.getContainer().add(::new("scripts/skills/racial/skeleton_racial"));
    }

    function onUpdate( _properties )
    {
        this.character_background.onUpdate(_properties);
        _properties.IsAffectedByDyingAllies = false;
        _properties.IsAffectedByFleeingAllies = false;
        _properties.IsAffectedByFreshInjuries = false;
        _properties.IsAffectedByInjuries = false;
        _properties.IsAffectedByLosingHitpoints = false;
        _properties.IsAffectedByNight = false;
        _properties.IsImmuneToBleeding = true;
        _properties.IsImmuneToPoison = true;
    }
});
