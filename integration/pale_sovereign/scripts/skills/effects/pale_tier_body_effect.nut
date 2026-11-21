this.pale_tier_body_effect <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = { BurstQueued = false },

    function onCombatStarted()
    {
        this.m.BurstQueued = false;
    }

    function getIcon()
    {
        if (this.m.TierTalent == "unyielding" && this.getContainer().getActor().getHitpointsPct() >= 0.5)
            return this.m.IconDisabled;
        return this.m.Icon;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hit, _properties )
    {
        if (this.m.TierTalent == "unyielding" && this.getContainer().getActor().getHitpointsPct() < 0.5)
            _properties.DamageReceivedTotalMult *= 0.85;
    }

    function onTurnStart()
    {
        if (this.m.TierTalent != "rot_regen")
            return;
        local actor = this.getContainer().getActor();
        local maxHP = actor.getHitpointsMax();
        actor.setHitpoints(::Math.min(maxHP, actor.getHitpoints() + ::Math.floor(maxHP * 0.1)));
        actor.setDirty(true);
    }

    function onDeathWithInfo( _killer, _skill, _deathTile, _corpseTile, _fatality )
    {
        local S = ::PaleSovereign;
        if (this.m.TierTalent != "death_burst" || this.m.BurstQueued || S.Battle == null
            || _corpseTile == null || _fatality == ::Const.FatalityType.Unconscious)
            return;
        this.m.BurstQueued = true;
        local actor = this.getContainer().getActor();
        local explosion = ::new(S.SkillDir + "actives/bgp_corpse_explosion_skill");
        local snapshot = { BGP_Necro = ::BGP.Necro.makeDeathInfo(actor) };
        // The engine invalidates the actor's native faction and ID after death.
        ::Time.scheduleEvent(::TimeUnit.Virtual, 1, S.burstUndead.bindenv(S), {
            Battle = S.Battle,
            Faction = actor.getFaction(),
            Name = actor.isHiddenToPlayer() ? "" : ::Const.UI.getColorizedEntityName(actor),
            Blast = explosion.getBlast(snapshot, actor),
            ArmorEfficiency = explosion.m.ArmorEfficiency,
            Will = ::BGP.Necro.getWill(actor),
            Skill = this,
            Tile = _corpseTile,
            Previous = ::BGP.Necro.getCorpse(_corpseTile)
        });
    }
});
