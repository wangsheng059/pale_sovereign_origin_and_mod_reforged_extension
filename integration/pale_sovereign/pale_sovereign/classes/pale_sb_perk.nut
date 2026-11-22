// 锁魂者专属特技的共用类。数值与说明见 pale_sovereign/soulbound.nut 的 S.SoulPerks
this.pale_sb_perk <- ::inherit("scripts/skills/skill", {
    m = { PaleKey = "", Used = false, Pending = false, Stacks = 0 },

    function create()
    {
        local def = ::PaleSovereign.SoulPerks[this.m.PaleKey];
        this.m.ID = "perk.pale_sb_" + this.m.PaleKey;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Icon = def.Icon + ".png";
        this.m.IconDisabled = def.Icon + "_sw.png";
        this.m.Type = ::Const.SkillType.Perk;
        this.m.Order = ::Const.SkillOrder.Perk;
        this.m.IsActive = false;
        this.m.IsStacking = false;
        this.m.IsHidden = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        if (this.m.PaleKey == "blood_feast" && this.m.Stacks > 0)
            ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "本场已叠加 " + this.m.Stacks + " 层：伤害 +" + (this.m.Stacks * 5) + "%，主动性 +" + (this.m.Stacks * 20) });
        return ret;
    }

    function reset()
    {
        this.m.Used = false;
        this.m.Pending = false;
        this.m.Stacks = 0;
    }

    function onCombatStarted()
    {
        this.reset();
    }

    function onCombatFinished()
    {
        this.reset();
    }

    function getActor()
    {
        return this.getContainer().getActor();
    }

    function enemiesWithin( _range )
    {
        local actor = this.getActor();
        local ret = [];
        if (!actor.isPlacedOnMap())
            return ret;
        local tile = actor.getTile();
        foreach (faction in ::Tactical.Entities.getAllInstances())
            foreach (other in faction)
                if (other != null && other.isAlive() && !other.isDying() && other.isPlacedOnMap()
                    && !other.isAlliedWith(actor) && other.getTile().getDistanceTo(tile) <= _range)
                    ret.push(other);
        return ret;
    }

    function applyAura( _script, _id )
    {
        foreach (enemy in this.enemiesWithin(3))
        {
            local effect = enemy.getSkills().getSkillByID(_id);
            if (effect == null)
                enemy.getSkills().add(::new(_script));
            else
                effect.m.Turns = 1;
        }
    }

    function onUpdate( _properties )
    {
        local actor = this.getActor();
        switch (this.m.PaleKey)
        {
            case "barrow_lord":
                local lost = 1.0 - actor.getHitpoints().tofloat() / ::Math.max(1, actor.getHitpointsMax());
                _properties.DamageTotalMult *= 1.0 + 0.1 * ::Math.floor(::Math.maxf(0.0, lost) * 10.0);
                break;
            case "blood_feast":
                _properties.DamageTotalMult *= 1.0 + 0.05 * this.m.Stacks;
                _properties.Initiative += 20 * this.m.Stacks;
                break;
            case "night_walker":
                if (::PaleSovereign.Battle != null && ::PaleSovereign.Battle.Night)
                    _properties.Initiative += 20;
                break;
        }
    }

    function onTurnStart()
    {
        switch (this.m.PaleKey)
        {
            case "barrow_lord":
                local actor = this.getActor();
                actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + 25));
                actor.setDirty(true);
                break;
            case "hex_domain":
                this.applyAura("scripts/skills/effects/pale_hex_domain_effect", "effects.pale_hex_domain");
                break;
            case "barrow_chant":
                this.applyAura("scripts/skills/effects/pale_chant_effect", "effects.pale_chant");
                break;
        }
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        if (this.m.PaleKey != "eternal_legion")
            return;
        local actor = this.getActor();
        if (!actor.isPlacedOnMap())
            return;
        local tile = actor.getTile();
        local count = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!tile.hasNextTile(d))
                continue;
            local next = tile.getNextTile(d);
            if (!next.IsOccupiedByActor)
                continue;
            local other = next.getEntity();
            if (other != null && other.isAlive() && other.isAlliedWith(actor) && other.getFlags().has("undead"))
                ++count;
        }
        _properties.DamageReceivedTotalMult *= 1.0 - 0.08 * ::Math.min(4, count);
    }

    function onAnySkillUsed( _skill, _targetEntity, _properties )
    {
        if (this.m.PaleKey == "death_ride" && !this.m.Used && _skill != null && _skill.isAttack())
        {
            _properties.DamageTotalMult *= 1.3;
            this.m.Pending = true;
        }
    }

    function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        if (_skill == null || !_skill.isAttack() || _targetEntity == null || ::MSU.isNull(_targetEntity))
            return;
        switch (this.m.PaleKey)
        {
            case "death_ride":
                if (!this.m.Pending)
                    return;
                this.m.Pending = false;
                this.m.Used = true;
                if (_targetEntity.isAlive() && !_targetEntity.isDying())
                {
                    local state = _targetEntity.getMoraleState();
                    if (state != ::Const.MoraleState.Ignore && state > ::Const.MoraleState.Fleeing)
                        _targetEntity.setMoraleState(state - 1);
                }
                break;
            case "blinding_hex":
                if (!_targetEntity.isAlive() || _targetEntity.isDying())
                    return;
                local blind = _targetEntity.getSkills().getSkillByID("effects.pale_blind");
                if (blind == null)
                    _targetEntity.getSkills().add(::new("scripts/skills/effects/pale_blind_effect"));
                else
                    blind.m.Turns = 1;
                break;
            case "blood_thirst":
                if (_damageInflictedHitpoints < 1)
                    return;
                local actor = this.getActor();
                actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + ::Math.max(1, ::Math.floor(_damageInflictedHitpoints * 0.35))));
                actor.setDirty(true);
                break;
        }
    }

    function onTargetMissed( _skill, _targetEntity )
    {
        if (this.m.PaleKey == "death_ride" && this.m.Pending)
        {
            this.m.Pending = false;
            this.m.Used = true;
        }
    }

    function onTargetKilled( _targetEntity, _skill )
    {
        if (this.m.PaleKey != "blood_feast")
            return;
        ++this.m.Stacks;
        this.getActor().getSkills().update();
    }
});
