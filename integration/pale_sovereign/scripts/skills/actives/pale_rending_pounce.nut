this.pale_rending_pounce <- ::inherit("scripts/skills/actives/pale_tier_attack", {
    m = { UsedRound = -1, PreparedHits = null },

    function create()
    {
        this.pale_tier_attack.create();
        this.m.Overlay = "";
        this.m.ActionPointCost = 5;
        this.m.FatigueCost = 20;
        this.m.MaxRange = 2;
        this.m.DamageLow = 32;
        this.m.DamageHigh = 56;
        this.m.ArmorEfficiency = 1.1;
        this.m.DirectDamageMult = 0.25;
        this.m.InjuriesOnBody = ::Const.Injury.CuttingBody;
        this.m.InjuriesOnHead = ::Const.Injury.CuttingHead;
        this.m.DamageType.add(::Const.Damage.DamageType.Cutting);
    }

    function getAttackCount( _actor )
    {
        return ::Math.max(1, ::Math.floor(_actor.getInitiative() / 60.0));
    }

    function getTooltip()
    {
        local ret = this.getDefaultTooltip();
        local actor = this.getContainer().getActor();
        ret.push({ id = 10, type = "text", icon = "ui/icons/initiative.png", text = "当前先手 " + actor.getInitiative()
            + "，连续攻击 " + this.getAttackCount(actor) + " 次。伤害独立于手持武器，适用砍刀特技。" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png",
            text = "每回合 1 次。可跃过其他单位，落在目标相邻的空格。起跳时无视借机攻击。目标死亡后结束连击。" });
        return ret;
    }

    function onCombatStarted()
    {
        this.m.UsedRound = -1;
        this.m.PreparedHits = null;
    }

    function onAfterUpdate( _properties )
    {
        this.m.FatigueCostMult = _properties.IsSpecializedInCleavers ? ::Const.Combat.WeaponSpecFatigueMult : 1.0;
    }

    function isUsable()
    {
        local actor = this.getContainer().getActor();
        return this.m.UsedRound != ::Time.getRound() && !actor.getCurrentProperties().IsRooted && this.skill.isUsable();
    }

    function getLanding( _origin, _target )
    {
        local landing = null;
        local best = 4;
        foreach (tile in ::PaleSovereign.area(_target))
        {
            if (tile.ID == _target.ID || !tile.IsEmpty || ::Math.abs(tile.Level - _target.Level) > 1)
                continue;
            local distance = _origin.getDistanceTo(tile);
            if (distance < best)
            {
                best = distance;
                landing = tile;
            }
        }
        return landing;
    }

    function onVerifyTarget( _origin, _tile )
    {
        local distance = _origin.getDistanceTo(_tile);
        return distance >= 1 && distance <= 2 && this.skill.onVerifyTarget(_origin, _tile)
            && ::PaleSovereign.isEnemy(this.getContainer().getActor(), _tile)
            && this.getLanding(_origin, _tile) != null;
    }

    function onBeforeAnySkillExecuted( _skill, _tile, _target, _forFree )
    {
        if (_skill == this)
            this.m.PreparedHits = this.getAttackCount(this.getContainer().getActor());
    }

    function onUse( _user, _tile )
    {
        if (this.m.UsedRound == ::Time.getRound() || !this.onVerifyTarget(_user.getTile(), _tile))
            return false;
        local destination = this.getLanding(_user.getTile(), _tile);
        local hits = this.m.PreparedHits == null ? this.getAttackCount(_user) : this.m.PreparedHits;
        this.m.PreparedHits = null;
        this.m.UsedRound = ::Time.getRound();
        ::PaleSovereign.playBattleArt("launch", _user.getTile(), 6);
        this.getContainer().setBusy(true);
        ::Tactical.getNavigator().teleport(_user, destination, this.onPounceLanded.bindenv(this),
            { Target = _tile.getEntity(), Hits = hits }, false, 3.0);
        return true;
    }

    function onPounceLanded( _user, _tag )
    {
        this.getContainer().setBusy(false);
        local S = ::PaleSovereign;
        local target = _tag.Target;
        if (S.tierActorOnMap(_user))
            S.playBattleArt("launch", _user.getTile(), 6, 0.65);
        for (local i = 0; i < _tag.Hits; ++i)
        {
            if (!S.tierActorOnMap(_user) || !S.tierActorOnMap(target) || target.isAlliedWith(_user)
                || _user.getTile().getDistanceTo(target.getTile()) != 1)
                break;
            // Melee attacks resolve immediately when no projectile is shown.
            local tile = target.getTile();
            local hit = this.attackEntity(_user, target);
            S.playBattleArt(hit ? "claws" : "whiff", tile, 34, 0.88, i * 85);
        }
    }

    function onTargetHit( _skill, _target, _part, _hp, _armor )
    {
        if (_skill == this && ::PaleSovereign.tierActorOnMap(_target) && !_target.getCurrentProperties().IsImmuneToBleeding)
            _target.getSkills().add(::new("scripts/skills/effects/bleeding_effect"));
    }
});
