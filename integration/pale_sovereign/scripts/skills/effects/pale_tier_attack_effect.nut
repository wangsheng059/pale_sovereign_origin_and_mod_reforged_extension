this.pale_tier_attack_effect <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = { UsedRound = -1, ChargeReady = true },

    function create()
    {
        this.pale_tier_passive.create();
        this.m.Order = ::Const.SkillOrder.Last;
    }

    function onCombatStarted()
    {
        this.m.UsedRound = -1;
        this.m.ChargeReady = true;
    }

    function getFrenzyBonus()
    {
        local actor = this.getContainer().getActor();
        local missing = 1.0 - actor.getHitpointsPct();
        return ::Math.min(6, ::Math.floor(missing * 10.0 + 0.0001)) * 5;
    }

    function isSpent()
    {
        return ::Tactical.isActive() && (this.m.TierTalent == "death_charge" && !this.m.ChargeReady
            || this.m.TierTalent == "chain_slash" && this.m.UsedRound == ::Time.getRound());
    }

    function getIcon()
    {
        return this.isSpent() ? this.m.IconDisabled : this.m.Icon;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        if (this.m.TierTalent == "flesh_frenzy")
            ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png",
                text = "当前伤害 +" + this.getFrenzyBonus() + "%。" });
        else if (this.isSpent())
            ret.push({ id = 10, type = "text", icon = "ui/icons/special.png",
                text = this.m.TierTalent == "death_charge" ? "本场已用。" : "本回合已用。" });
        return ret;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (!_skill.isAttack())
            return;
        if (this.m.TierTalent == "flesh_frenzy")
        {
            _properties.DamageTotalMult *= 1.0 + this.getFrenzyBonus() * 0.01;
        }
        else if (this.m.TierTalent == "first_strike" && _target != null && !_target.isAlliedWith(this.getContainer().getActor()))
        {
            if (!_target.isTurnStarted() && !_target.isTurnDone())
                _properties.DamageTotalMult *= 1.25;
            if (_target.getHitpointsPct() < 0.5 && !_target.getCurrentProperties().IsImmuneToHeadshots)
            {
                _properties.HitChance[::Const.BodyPart.Head] = 100.0;
                _properties.HitChanceMult[::Const.BodyPart.Head] = 1.0;
                _properties.HitChanceMult[::Const.BodyPart.Body] = 0.0;
            }
        }
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (_skill == null || !_skill.isAttack() || !::PaleSovereign.tierActorOnMap(_target)
            || _target.isAlliedWith(this.getContainer().getActor()))
            return;
        if (this.m.TierTalent == "grave_blade")
            ::PaleSovereign.applyTierStatus(_target, "grave_blade");
        else if (this.m.TierTalent == "bone_break")
        {
            local item = _skill.getItem();
            if (::MSU.isKindOf(item, "weapon") && item.isWeaponType(::Const.Items.WeaponType.Polearm))
                ::PaleSovereign.applyTierStatus(_target, "bone_break");
        }
    }

    function onTargetKilled( _target, _skill )
    {
        if (this.m.TierTalent != "chain_slash" || this.m.UsedRound == ::Time.getRound())
            return;
        local actor = this.getContainer().getActor();
        if (!::PaleSovereign.tierActorOnMap(actor) || _target.isAlliedWith(actor))
            return;
        this.m.UsedRound = ::Time.getRound();
        actor.setActionPoints(::Math.min(actor.getActionPointsMax(), actor.getActionPoints() + 4));
        actor.setDirty(true);
    }
});
