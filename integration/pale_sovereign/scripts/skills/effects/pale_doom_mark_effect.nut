// 1.7.0 死兆导引：受到友方亡灵的伤害 +15%，受到尸爆的伤害 +25%
this.pale_doom_mark_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_doom_mark";
        this.m.Name = "死兆";
        this.m.Description = "魂玉统领的魂火盯上了这个被削弱的目标。";
        this.m.Icon = "skills/pale_doom_mark_status.png";
        this.m.IconDisabled = "skills/pale_doom_mark_status_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "受到友方亡灵的伤害 " + ::MSU.Text.colorNegative("+15%") });
        ret.push({ id = 11, type = "text", icon = "ui/icons/regular_damage.png", text = "受到尸爆的伤害 " + ::MSU.Text.colorNegative("+25%") });
        return ret;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        if (_skill != null && _skill.getID() == "actives.bgp_corpse_explosion")
            _properties.DamageReceivedTotalMult *= 1.25;
        else if (_attacker != null && !::MSU.isNull(_attacker) && ::PaleSovereign.isFriendlyUndead(_attacker))
            _properties.DamageReceivedTotalMult *= 1.15;
    }
});
