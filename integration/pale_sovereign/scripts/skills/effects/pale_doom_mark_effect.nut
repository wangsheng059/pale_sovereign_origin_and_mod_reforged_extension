// 1.7.0 死兆导引：受到友方亡灵的伤害 +15%，受到尸爆的伤害 +25%
this.pale_doom_mark_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_doom_mark";
        this.m.Name = "死兆";
        this.m.Description = "魂玉统领的魂火盯上了这个被削弱的目标。受到亡灵的伤害 +15%，受到尸爆的伤害 +25%。";
        this.m.Icon = "skills/pale_mark_prey.png";
        this.m.IconDisabled = "skills/pale_mark_prey_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        if (_skill != null && _skill.getID() == "actives.bgp_corpse_explosion")
            _properties.DamageReceivedTotalMult *= 1.25;
        else if (_attacker != null && !::MSU.isNull(_attacker) && ::PaleSovereign.isFriendlyUndead(_attacker))
            _properties.DamageReceivedTotalMult *= 1.15;
    }
});
