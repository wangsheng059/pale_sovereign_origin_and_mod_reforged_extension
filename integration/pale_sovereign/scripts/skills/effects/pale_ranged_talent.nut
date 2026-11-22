this.pale_ranged_talent <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = { UsedRound = -1, TurnRound = -1, TurnTile = -1, Moved = false },

    function onCombatStarted()
    {
        this.m.UsedRound = -1;
        this.m.TurnRound = -1;
        this.m.TurnTile = -1;
        this.m.Moved = false;
    }

    function onTurnStart()
    {
        local actor = this.getContainer().getActor();
        if (this.m.TierTalent != "fixed_shot" || this.m.TurnRound == ::Time.getRound() || !actor.isPlacedOnMap())
            return;
        this.m.TurnRound = ::Time.getRound();
        this.m.TurnTile = actor.getTile().ID;
        this.m.Moved = false;
    }

    function onMovementFinished()
    {
        local actor = this.getContainer().getActor();
        if (this.m.TierTalent == "fixed_shot" && actor.isPlacedOnMap() && actor.getTile().ID != this.m.TurnTile)
            this.m.Moved = true;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (this.m.TierTalent == "soulfire_lock")
        {
            if (_skill.isAttack() && !::MSU.isNull(_target)
                && !_target.isAlliedWith(this.getContainer().getActor()) && this.meetsLockCondition(_target))
            {
                _properties.DamageTotalMult *= 1.25;
                _properties.HitChance[::Const.BodyPart.Head] += 25;
            }
            return;
        }

        local S = ::PaleSovereign;
        local weapon = S.rangedAttackWeapon(_skill);
        if (weapon == null)
            return;
        local types = ::Const.Items.WeaponType;
        switch (this.m.TierTalent)
        {
            case "bone_piercing_arrow":
                if (weapon.isWeaponType(types.Bow))
                    _properties.DamageDirectRangedAdd += 0.20;
                break;
            case "fixed_shot":
                if (!this.m.Moved && weapon.isWeaponType(types.Crossbow | types.Firearm))
                {
                    if (_properties.RangedSkillMult > 0)
                        _properties.RangedSkill += 10.0 / _properties.RangedSkillMult;
                    _properties.DamageTotalMult *= 1.15;
                }
                break;
            case "armor_shattering_bolt":
                if (weapon.isWeaponType(types.Crossbow | types.Firearm))
                    _properties.DamageArmorMult *= 1.5;
                break;
        }
    }

    function meetsLockCondition( _target )
    {
        local skills = _target.getSkills();
        if (skills.hasSkill("effects.pale_weaken") || skills.hasSkill("effects.bgp_curse_of_ages"))
            return true;
        local actor = this.getContainer().getActor();
        return actor.isPlacedOnMap() && _target.isPlacedOnMap() && actor.getTile().getDistanceTo(_target.getTile()) > 4;
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (this.m.TierTalent != "armor_shattering_bolt")
            return;
        local S = ::PaleSovereign;
        local weapon = S.rangedAttackWeapon(_skill);
        local types = ::Const.Items.WeaponType;
        if (weapon != null && weapon.isWeaponType(types.Crossbow | types.Firearm)
            && S.tierActorOnMap(_target) && !_target.isAlliedWith(this.getContainer().getActor()))
            S.applyTierStagger(_target);
    }
});
