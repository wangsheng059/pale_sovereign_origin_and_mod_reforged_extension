// 1.6.8 亡灵专属特质：数据在 ::PaleSovereign.UndeadTraits（undead_recruits.nut），叶子脚本只写 PaleKey
this.pale_undead_trait <- ::inherit("scripts/skills/traits/character_trait", {
    m = { PaleKey = "", PalePetMode = false },
    function create()
    {
        this.character_trait.create();
        if (this.m.DamageType == null)
            this.m.DamageType = ::MSU.Class.DamageType();
        local def = ::PaleSovereign.UndeadTraits[this.m.PaleKey];
        this.m.ID = "trait.pale_" + this.m.PaleKey;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Excluded = clone def.Excluded;
        this.m.Icon = "ui/traits/pale_" + ("Icon" in def ? def.Icon : this.m.PaleKey) + ".png";
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        foreach (i, line in ::PaleSovereign.UndeadTraits[this.m.PaleKey].Effects)
            ret.push({ id = 10 + i, type = "text", icon = line[0], text = line[1] });
        return ret;
    }

    function onUpdate( _properties )
    {
        local key = this.m.PaleKey;
        if (key == "salted")
            _properties.Hitpoints += 12;
        else if (key == "putrid")
            _properties.Hitpoints -= 12;
        else if (key == "deathgrip")
            _properties.IsImmuneToKnockBackAndGrab = true;
        else if (key == "dense_bone")
            _properties.DamageReceivedTotalMult *= 0.90;
        else if (key == "old_drill")
        {
            _properties.MeleeSkill += 4;
            _properties.RangedSkill += 4;
            _properties.MeleeDefense += 4;
            _properties.RangedDefense += 4;
        }
        else if (key == "thick_hide")
            _properties.ThresholdToReceiveInjuryMult *= 1.25;
        else if (key == "refined_joints")
        {
            _properties.Stamina += 10;
            _properties.FatigueRecoveryRate += 2;
        }
        else if (key == "tall_frame")
        {
            _properties.MeleeDamageMult *= 1.10;
            _properties.Hitpoints += 8;
            _properties.MeleeDefense -= 5;
            _properties.RangedDefense -= 5;
        }
        else if (key == "frail_bone")
            _properties.Hitpoints -= 10;
        else if (key == "brittle")
        {
            _properties.Initiative -= 10;
            _properties.MeleeDefense -= 3;
        }
        else if (key == "sleepless")
            _properties.FatigueRecoveryRate += 3;
        else if (key == "soulfire")
            _properties.Initiative += 10;
        else if (key == "legion_discipline")
            _properties.MeleeDefense += 3 * this.countUndeadNeighbours();
        // 1.6.18 负面特质
        else if (key == "stiff_corpse")
        {
            _properties.Initiative -= 15;
            _properties.MeleeDefense -= 3;
        }
        else if (key == "broken_fingers")
            _properties.MeleeDamageMult *= 0.90;
        else if (key == "maggot_ridden")
            _properties.HitpointsMult *= 0.90;
        else if (key == "rusted_pins")
        {
            _properties.Stamina -= 10;
            _properties.FatigueRecoveryRate -= 2;
        }
        else if (key == "dim_soulfire")
        {
            _properties.Initiative -= 10;
            _properties.Vision -= 1;
        }
        else if (key == "death_indenture")
        {
            _properties.Bravery += 4;
            _properties.DailyWageMult *= 0.5;
        }
        else if (key == "fallen_saint")
            _properties.Bravery += 4;
        else if (key == "gem_eyes")
        {
            if (!this.m.PalePetMode)
            {
                _properties.Initiative += 10;
                _properties.RangedDefense += 5;
            }
            _properties.Vision += 3;
        }
        else if (key == "former_comrade" && ::PaleSovereign.hasLivingNeighbour(this.getContainer().getActor()))
        {
            _properties.MeleeDefense += 3;
            _properties.Bravery += 5;
        }
        else if (key == "forgotten_drill")
        {
            _properties.MeleeSkill -= 5;
            _properties.RangedSkill -= 5;
        }
    }

    function countUndeadNeighbours()
    {
        local actor = this.getContainer().getActor();
        if (!::Tactical.isActive() || !actor.isPlacedOnMap())
            return 0;
        local tile = actor.getTile();
        local count = 0;
        for (local i = 0; i < 6; ++i)
        {
            if (!tile.hasNextTile(i))
                continue;
            local next = tile.getNextTile(i);
            if (!next.IsOccupiedByActor)
                continue;
            local other = next.getEntity();
            if (other != null && other.isAlive() && other.isAlliedWith(actor) && other.getFlags().has("undead"))
                ++count;
        }
        return ::Math.min(3, count);
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        local key = this.m.PaleKey;
        if (key == "hollow_skull" && _hitInfo.BodyPart == ::Const.BodyPart.Head)
            _properties.DamageReceivedTotalMult *= 0.75;
        else if (key == "thick_hide" && _hitInfo.BodyPart == ::Const.BodyPart.Head && _hitInfo.BodyDamageMult > 1.0)
            _hitInfo.BodyDamageMult = 1.0 + (_hitInfo.BodyDamageMult - 1.0) * 0.75;
        else if (key == "frail_bone" && _hitInfo.DamageType == ::Const.Damage.DamageType.Blunt)
            _properties.DamageReceivedTotalMult *= 1.10;
        else if (key == "loose_skull" && _hitInfo.BodyPart == ::Const.BodyPart.Head)
            _properties.DamageReceivedTotalMult *= 1.15;
        else if (key == "cracked_ribs" && _hitInfo.BodyPart == ::Const.BodyPart.Body)
            _properties.DamageReceivedTotalMult *= 1.10;
    }

    function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
    {
        if (this.m.PaleKey != "toxic_flesh" || _damageHitpoints <= 0 || _attacker == null || ::MSU.isNull(_attacker)
            || !_attacker.isAlive() || _attacker.getFlags().has("undead") || !_attacker.isPlacedOnMap())
            return;
        local actor = this.getContainer().getActor();
        if (!actor.isPlacedOnMap() || actor.getTile().getDistanceTo(_attacker.getTile()) > 1)
            return;
        _attacker.setFatigue(::Math.min(_attacker.getFatigueMax(), _attacker.getFatigue() + 5));
    }

    function onAnySkillUsed( _skill, _targetEntity, _properties )
    {
        if (this.m.PaleKey == "grudge" && _skill.isAttack() && this.getContainer().getActor().getHitpointsPct() < 0.5)
            _properties.DamageTotalMult *= 1.15;
    }

    function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
    {
        if (this.m.PaleKey != "gnawing" || !_skill.isAttack() || _skill.isRanged())
            return;
        local actor = this.getContainer().getActor();
        actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + 5));
    }
});
