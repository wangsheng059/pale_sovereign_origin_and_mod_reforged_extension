this.pale_wight_order_effect <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_wight_order";
        this.m.Name = "尸妖王的号令";
        this.m.Description = "侍卫长用一句早已失传的口令催促冠军上前。第 1 回合近战技能 +10。";
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
