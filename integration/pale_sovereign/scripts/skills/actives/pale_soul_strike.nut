this.pale_soul_strike <- ::inherit("scripts/skills/skill", {
    m = { Champion = false },
    function create()
    {
        this.m.ID = "actives.pale_soul_strike";
        this.m.Name = "魂火敲击";
        this.m.Description = "以法杖重击敌人。杖头迸发的幽蓝魂火将穿透护甲，直刺生者的筋骨与心神。";
        this.m.Icon = "skills/pale_strike.png";
        this.m.IconDisabled = "skills/pale_strike_sw.png";
        this.m.Overlay = "";
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
        local resolve = ::BGP.Necro.getResolve(actor);
        local bonus = ::Math.floor(::BGP.Necro.getWill(actor) * 0.10);
        local staff = actor.getMainhandItem();
        local low = staff == null ? 0 : staff.m.RegularDamage, high = staff == null ? 0 : staff.m.RegularDamageMax;
        ret.push({ id = 11, type = "text", icon = "ui/icons/direct_damage.png", text = "距离 1–2 格。伤害 = 法杖伤害 " + low + "–" + high
            + "（其中 " + ::Math.round(this.m.DirectDamageMult * 100) + "% 无视护甲）+ 追加 ⌊(决心 − " + ::BGP.Necro.WillOffset + ") × 10%⌋ 点无视护甲伤害。"
            + "当前决心 " + resolve + "，追加 " + bonus + " 点。命中后目标疲劳 +5。" });
        ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "命中后把目标标记为猎物（2 回合，同一时间只有一个）：亡灵宠物与仆从优先攻击它，导师与冠军对其命中 +10、伤害 +20%。" });
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
        if (_info.TargetEntity != null && !::MSU.isNull(_info.TargetEntity) && _info.TargetEntity.isPlacedOnMap())
            ::PaleSovereign.playBattleArt("soulfire", _info.TargetEntity.getTile(), 35);
        strike.skill.onScheduledTargetHit.call(strike, _info);
        local target = _info.TargetEntity;
        if (target == null || ::MSU.isNull(target) || !target.isAlive() || target.isDying())
            return;
        target.setFatigue(::Math.min(target.getFatigueMax(), target.getFatigue() + 5));
        if (::PaleSovereign.isEnemy(_info.User, target.getTile()))
            ::PaleSovereign.markPrey(target);
        local spell = strike.getContainer().getSkillByID("actives.pale_weaken");
        ::PaleSovereign.directDamage(_info.User, spell, target, ::BGP.Necro.getWill(_info.User) * 0.10);
    }
});
