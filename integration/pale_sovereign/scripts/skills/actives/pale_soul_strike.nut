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
        local bonus = ::Math.floor(::BGP.Necro.getWill(actor) * 0.20);
        local turns = 2 + ::BGP.Necro.spellDurationBonus(actor);
        ret.push({ id = 11, type = "text", icon = "ui/icons/direct_damage.png", text = "距离 1–2 格。命中时额外追加 ⌊(决心 − " + ::BGP.Necro.WillOffset + ") × 20%⌋ 点无视护甲伤害（当前决心 " + resolve + "，追加 " + bonus + " 点），使目标疲劳 +5，并对不免疫茫然的目标施加【茫然】状态（伤害、主动值与最大疲劳 -25%，持续 2 回合）。" });
        ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "命中后把目标标记为猎物（" + turns + " 回合，同一时间只有一个）：所有友方亡灵优先攻击它，导师与所有友方亡灵对其命中 +10、伤害 +20%。" });
        if (!actor.getCurrentProperties().IsSpecializedInPolearms)
            ret.push({ id = 12, type = "text", icon = "ui/icons/hitchance.png", text = "贴身命中 −15。长柄专精取消此惩罚、降低疲劳消耗" + (this.m.Champion ? "，并将行动点消耗降为 4 点。" : "。") });
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
        if (!target.getCurrentProperties().IsImmuneToDaze)
        {
            target.getSkills().add(::new("scripts/skills/effects/dazed_effect"));
            if (!_info.User.isHiddenToPlayer() && target.getTile().IsVisibleForPlayer)
                ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_info.User) + "使" + ::Const.UI.getColorizedEntityName(target) + "陷入了茫然");
        }
        if (::PaleSovereign.isEnemy(_info.User, target.getTile()))
            ::PaleSovereign.markPrey(target, 2 + ::BGP.Necro.spellDurationBonus(_info.User));
        local spell = strike.getContainer().getSkillByID("actives.pale_weaken");
        ::PaleSovereign.directDamage(_info.User, spell, target, ::BGP.Necro.getWill(_info.User) * 0.20);
    }
});
