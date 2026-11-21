this.pale_wight_order_effect <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_wight_order";
        this.m.Name = "尸妖王的号令";
        this.m.Description = "侍卫长的号令让冠军在第 1 回合获得 +10 近战技能。";
        this.m.Icon = "skills/pale_honor.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function onUpdate( _properties )
    {
        if (::Time.getRound() <= 1)
            _properties.MeleeSkill += 10;
    }

    function onRoundStart()
    {
        if (::Time.getRound() > 1)
            this.removeSelf();
    }
});
