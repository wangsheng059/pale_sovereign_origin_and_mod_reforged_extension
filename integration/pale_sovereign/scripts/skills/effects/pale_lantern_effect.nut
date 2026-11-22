this.pale_lantern_effect <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_lantern";
        this.m.Name = "守夜人的骨灯";
        this.m.Description = "夜战中免疫视野和远程命中惩罚，决心 +6，命中头部概率 +10 个百分点。";
        this.m.Icon = "skills/pale_lantern.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
    }

    function isHidden()
    {
        local battle = ::PaleSovereign.Battle;
        return battle == null || !battle.Night;
    }

    function onBeforeUpdate( _properties )
    {
        if (!this.isHidden())
            _properties.IsAffectedByNight = false;
    }

    function onUpdate( _properties )
    {
        if (this.isHidden())
            return;
        _properties.IsAffectedByNight = false;
        _properties.Bravery += 6;
        _properties.HitChance[::Const.BodyPart.Head] += 10;
    }
});
