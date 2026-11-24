// 1.7.0 守墓死契（挂在导师身上）：冠军在 2 格内时，导师受到的生命伤害有 35% 转给冠军
this.pale_grave_pact_effect <- ::inherit("scripts/skills/skill", {
    m = { Champion = null, Pending = false },
    function create()
    {
        this.m.ID = "effects.pale_grave_pact";
        this.m.Name = "守墓死契";
        this.m.Description = "冠军以骨为盾，替导师分担了一部分死亡。冠军在 2 格内时，导师受到的生命伤害有 35% 由冠军承受。";
        this.m.Icon = "skills/pale_grave_pact_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function setChampion( _entity )
    {
        this.m.Champion = ::MSU.asWeakTableRef(_entity);
    }

    function champion()
    {
        local c = this.m.Champion;
        if (c == null || ::MSU.isNull(c))
            return null;
        local e = typeof c == "instance" ? c.get() : c;
        local actor = this.getContainer().getActor();
        if (!e.isAlive() || e.isDying() || !e.isPlacedOnMap() || !actor.isPlacedOnMap() || e.getTile().getDistanceTo(actor.getTile()) > 2)
            return null;
        return e;
    }

    function isHidden()
    {
        return this.champion() == null;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        this.m.Pending = this.champion() != null;
        if (this.m.Pending)
            _properties.DamageReceivedRegularMult *= 0.65;
    }

    function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
    {
        if (!this.m.Pending)
            return;
        this.m.Pending = false;
        local e = this.champion();
        if (e == null || _damageHitpoints <= 0)
            return;
        local share = ::Math.max(1, ::Math.floor(_damageHitpoints * 0.35 / 0.65));
        e.setHitpoints(::Math.max(1, e.getHitpoints() - share));
        e.setDirty(true);
        ::PaleSovereign.playActorArt("bone_ward", this.getContainer().getActor());
        ::PaleSovereign.playActorArt("bone_ward", e);
        local inscription = e.getSkills().getSkillByID("effects.pale_inscription");
        if (inscription != null)
            inscription.addRage();
    }
});
