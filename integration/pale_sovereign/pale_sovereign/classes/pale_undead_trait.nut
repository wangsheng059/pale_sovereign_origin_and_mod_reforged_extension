// 1.6.8 亡灵专属特质：数据在 ::PaleSovereign.UndeadTraits（undead_recruits.nut），叶子脚本只写 PaleKey
this.pale_undead_trait <- ::inherit("scripts/skills/traits/character_trait", {
    m = { PaleKey = "" },
    function create()
    {
        this.character_trait.create();
        local def = ::PaleSovereign.UndeadTraits[this.m.PaleKey];
        this.m.ID = "trait.pale_" + this.m.PaleKey;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Excluded = clone def.Excluded;
        this.m.Icon = "ui/traits/trait_icon_01.png";
        try { this.m.Icon = ::new("scripts/skills/traits/" + def.Icon).m.Icon; } catch (e) {}
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
            _properties.DamageReceivedTotalMult *= 0.95;
        else if (key == "old_drill")
        {
            _properties.MeleeSkill += 4;
            _properties.RangedSkill += 4;
        }
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
        if (this.m.PaleKey == "hollow_skull" && _hitInfo.BodyPart == ::Const.BodyPart.Head)
            _properties.DamageReceivedTotalMult *= 0.75;
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
