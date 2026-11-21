this.pale_guard_shield <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_guard_shield";
        this.m.Name = "王座护卫的骨甲";
        this.m.Description = "吸收本场战斗首次遭到的攻击伤害。";
        this.m.Icon = "skills/pale_honor.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hit, _properties )
    {
        if (_skill == null || !_skill.isAttack() || (_hit.DamageRegular <= 0 && _hit.DamageArmor <= 0))
            return;
        _properties.DamageReceivedTotalMult = 0.0;
        ::Tactical.EventLog.log("王座护卫的骨甲挡下了这次攻击。");
        this.removeSelf();
    }
});
