this.pale_soul_strike <- ::inherit("scripts/skills/skill", {
    m = { Champion = false },
    function create()
    {
        this.m.ID = "actives.pale_soul_strike";
        this.m.Name = "魂火敲击";
        this.m.Description = "以法杖重击敌人。杖头迸发的幽蓝魂火将穿透护甲，直刺生者的筋骨与心神。";
        this.m.Icon = "skills/pale_strike.png";
        this.m.IconDisabled = "skills/pale_strike_sw.png";
        this.m.Overlay = "active_01";
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.OffensiveTargeted;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsAttack = true;
        this.m.IsWeaponSkill = true;
        this.m.IsSerialized = false;
        this.m.ActionPointCost = 6;
        this.m.FatigueCost = 16;
        this.m.MinRange = 1;
        this.m.MaxRange = 2;
        this.m.DirectDamageMult = 0.4;
        this.m.InjuriesOnBody = ::Const.Injury.BluntBody;
        this.m.InjuriesOnHead = ::Const.Injury.BluntHead;
        this.m.DamageType.add(::Const.Damage.DamageType.Blunt);
    }

    function getTooltip()
    {
        local ret = this.getDefaultTooltip();
        local actor = this.getContainer().getActor();
        local bonus = ::Math.floor(::BGP.Necro.getWill(actor) * 0.10);
        ret.push({ id = 11, type = "text", icon = "ui/icons/direct_damage.png", text = "距离 1–2 格。命中追加 " + bonus + " 点无视护甲伤害，目标疲劳 +5。" });
        if (!actor.getCurrentProperties().IsSpecializedInPolearms)
            ret.push({ id = 12, type = "text", icon = "ui/icons/hitchance.png", text = "贴身命中 −15。长柄专精取消此惩罚并降低疲劳消耗。" });
        return ret;
    }

    function onAfterUpdate( _properties )
    {
        local mastery = _properties.IsSpecializedInPolearms;
        this.m.FatigueCostMult = mastery ? ::Const.Combat.WeaponSpecFatigueMult : 1.0;
        this.m.ActionPointCost = this.m.Champion ? (mastery ? 4 : 5) : 6;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (_skill != this || _target == null || _properties.IsSpecializedInPolearms)
            return;
        if (this.getContainer().getActor().getTile().getDistanceTo(_target.getTile()) == 1)
            _properties.MeleeSkill -= 15;
    }

    function onUse( _user, _tile )
    {
        return this.attackEntity(_user, _tile.getEntity());
    }

    function onScheduledTargetHit( _info )
    {
        local strike = _info.Skill;
        strike.skill.onScheduledTargetHit.call(strike, _info);
        local target = _info.TargetEntity;
        if (target == null || ::MSU.isNull(target) || !target.isAlive() || target.isDying())
            return;
        target.setFatigue(::Math.min(target.getFatigueMax(), target.getFatigue() + 5));
        local spell = strike.getContainer().getSkillByID("actives.pale_weaken");
        ::PaleSovereign.directDamage(_info.User, spell, target, ::BGP.Necro.getWill(_info.User) * 0.10);
    }
});
