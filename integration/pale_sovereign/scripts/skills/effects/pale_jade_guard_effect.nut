// 1.7.0 玉壳护体：受到的伤害 −50%
this.pale_jade_guard_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_jade_guard";
        this.m.Name = "玉壳护体";
        this.m.Description = "碎裂的玉壳仍护着残躯。受到的伤害 −50%。";
        this.m.Icon = "skills/pale_guard_shield.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
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
