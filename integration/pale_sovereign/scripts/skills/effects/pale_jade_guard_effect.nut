// 1.7.0 玉壳护体：受到的伤害 −50%
this.pale_jade_guard_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_jade_guard";
        this.m.Name = "玉壳护体";
        this.m.Description = "碎裂的玉壳仍护着残躯。";
        this.m.Icon = "skills/pale_jade_guard_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/armor_body.png", text = "受到的伤害 " + ::MSU.Text.colorPositive("-50%") });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.Turns + " 回合" });
        return ret;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        _properties.DamageReceivedTotalMult *= 0.5;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
