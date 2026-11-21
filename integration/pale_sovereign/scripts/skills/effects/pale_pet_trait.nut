// 冠军吞魂特质，编号和说明见 pale_sovereign/souls.nut 的 S.Souls
this.pale_pet_trait <- ::inherit("scripts/skills/skill", {
    m = { Species = 0, Intercepted = false, PendingInterception = false },
    function create()
    {
        this.m.Type = ::Const.SkillType.Trait;
        this.m.IsSerialized = false;
        this.m.IsStacking = false;
    }

    function configure( _species )
    {
        local soul = ::PaleSovereign.Souls[_species];
        this.m.Species = _species;
        this.m.ID = "trait.pale_soul_" + _species;
        this.m.Name = soul.Name;
        this.m.Description = soul.Desc;
        this.m.Icon = soul.Icon + ".png";
        this.m.IconDisabled = soul.Icon + "_sw.png";
    }

    function heal( _pct )
    {
        local actor = this.getContainer().getActor();
        if (!actor.isAlive() || actor.isDying())
            return;
        local amount = ::Math.max(1, ::Math.floor(actor.getHitpointsMax() * _pct));
        actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + amount));
        actor.setDirty(true);
    }

    function onUpdate( _properties )
    {
        switch (this.m.Species)
        {
            case 1:
                _properties.IsSpecializedInShields = true;
                break;
            case 2:
                _properties.MeleeSkill += 5;
                _properties.MeleeDamageMult *= 1.1;
                break;
            case 5:
                _properties.MeleeSkill += 5;
                _properties.MeleeDefense += 5;
                _properties.Bravery += 10;
                break;
            case 6:
                _properties.Bravery += 15;
                break;
            case 8:
                if (this.getContainer().getActor().getHitpoints() * 2 < this.getContainer().getActor().getHitpointsMax())
                    _properties.MeleeDamageMult *= 1.25;
                break;
            case 9:
                _properties.Hitpoints += 30;
                _properties.IsImmuneToKnockBackAndGrab = true;
                break;
            case 11:
                _properties.Hitpoints += 15;
                _properties.DamageReceivedRangedMult *= 0.75;
                break;
            case 12:
                _properties.MeleeDefense += 7;
                _properties.RangedDefense += 7;
                break;
            case 14:
                _properties.MeleeSkill += 7;
                _properties.Initiative += 10;
                break;
            case 15:
                _properties.MeleeDefense += 5;
                _properties.DamageReceivedMeleeMult *= 0.9;
                break;
            case 16:
                _properties.Initiative += 20;
                _properties.MeleeSkill += 3;
                break;
            case 17:
                _properties.DamageReceivedTotalMult *= 0.85;
                break;
        }
    }

    function onTurnStart()
    {
        if (this.m.Species == 10)
            this.heal(0.1);
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (_skill == null || !_skill.isAttack())
            return;
        if (this.m.Species == 3 && _hp >= 1)
        {
            local actor = this.getContainer().getActor();
            actor.setHitpoints(::Math.minf(actor.getHitpointsMax(), actor.getHitpoints() + ::Math.max(1, ::Math.floor(_hp * 0.25))));
        }
        else if (this.m.Species == 6 && _target != null && !::MSU.isNull(_target) && _target.isAlive() && !_target.isDying())
        {
            local blind = _target.getSkills().getSkillByID("effects.pale_blind");
            if (blind == null)
                _target.getSkills().add(::new("scripts/skills/effects/pale_blind_effect"));
            else
                blind.m.Turns = 1;
        }
    }

    function onTargetKilled( _target, _skill )
    {
        if (this.m.Species == 7)
        {
            local actor = this.getContainer().getActor();
            actor.setActionPoints(::Math.min(actor.getActionPointsMax(), actor.getActionPoints() + 3));
            actor.setDirty(true);
        }
        else if (this.m.Species == 13)
            this.heal(0.2);
    }

    function onBeforeDamageReceived( _attacker, _skill, _hit, _properties )
    {
        this.m.PendingInterception = false;
        if (this.m.Species != 4 || this.m.Intercepted || _attacker == null || _skill == null || !_skill.isAttack())
            return;
        local actor = this.getContainer().getActor();
        local chief = ::PaleSovereign.chief();
        if (chief == null || !chief.isAlive() || !chief.isPlacedOnMap()
            || actor.getTile().getDistanceTo(chief.getTile()) != 1 || _attacker.isAlliedWith(actor))
            return;
        this.m.PendingInterception = true;
        _hit.DamageRegular *= 0.5;
        _hit.DamageArmor *= 0.5;
    }

    function onDamageReceived( _attacker, _hp, _armor )
    {
        if (this.m.PendingInterception)
            this.m.Intercepted = true;
        this.m.PendingInterception = false;
    }
});
