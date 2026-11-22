local S = ::PaleSovereign;

S.tierActorOnMap <- function( _actor )
{
    return !::MSU.isNull(_actor) && _actor.isAlive() && !_actor.isDying() && _actor.isPlacedOnMap();
};

S.applyTierStatus <- function( _actor, _kind )
{
    local effect = ::new(this.SkillDir + "effects/pale_tier_status");
    effect.configure(_kind);
    _actor.getSkills().add(effect);
};

S.applyTierStagger <- function( _actor )
{
    local skills = _actor.getSkills();
    skills.add(::new("scripts/skills/effects/staggered_effect"));
    if (!_actor.isTurnStarted() && !_actor.isTurnDone())
    {
        ::Tactical.TurnSequenceBar.pushEntityBack(_actor.getID());
    }
    else
    {
        local status = skills.getSkillByID("effects.staggered");
        if (status != null)
            status.m.PaleLastRound <- ::Tactical.TurnSequenceBar.getCurrentRound() + 1;
    }
};

S.burstUndead <- function( _burst )
{
    if (this.Battle != _burst.Battle || !::Tactical.isActive() || _burst.Blast == null)
        return;
    local center = _burst.Tile;
    local corpse = ::BGP.Necro.getCorpse(center);
    if (corpse == null || corpse == _burst.Previous || ::BGP.Necro.isPendingResurrection(corpse)
        || ::BGP.Necro.isGuardCorpse(corpse))
        return;

    local blast = _burst.Blast;
    ::BGP.Necro.removeCorpse(center);
    ::BGP.Necro.spawnBloodbath(center);
    this.playBattleArt("burst", center, 15, 1.3);
    if (_burst.Name != "")
        ::Tactical.EventLog.log(_burst.Name + "的尸体轰然炸开，腐液溅满了四周。");

    local visited = {};
    foreach (nearby in this.area(center))
    {
        foreach (tile in this.area(nearby))
        {
            if (tile.ID in visited)
                continue;
            visited[tile.ID] <- true;
            if (!tile.IsOccupiedByActor)
                continue;

            local target = tile.getEntity();
            if (!this.tierActorOnMap(target) || target.isAlliedWith(_burst.Faction))
                continue;
            ::BGP.Necro.applyBlast(null, _burst.Skill, target, 2 * blast.Blunt, 1.0,
                ::Const.Injury.BluntBody, ::Const.Injury.BluntHead, ::Const.Damage.DamageType.Blunt);
            ::BGP.Necro.applyBlast(null, _burst.Skill, target, 2 * blast.Cutting, _burst.ArmorEfficiency,
                ::Const.Injury.CuttingBody, ::Const.Injury.CuttingHead, ::Const.Damage.DamageType.Cutting);
            if (this.tierActorOnMap(target))
            {
                this.applyTierStagger(target);
                try { target.checkMorale(-1, -::BGP.Necro.WillScale.BlastMorale(_burst.Will)); } catch (e) {}
            }
        }
    }
};

S.refreshDeadCommand <- function()
{
    if (this.Battle == null || !::Tactical.isActive())
        return;
    local commanders = ::World.getPlayerRoster().getAll().filter(@(_, bro) S.tierActorOnMap(bro)
        && bro.getSkills().hasSkill("effects.pale_dead_command"));
    if (commanders.len() == 0 && !("HadDeadCommand" in this.Battle))
        return;
    this.Battle.HadDeadCommand <- true;

    foreach (faction in ::Tactical.Entities.getAllInstances())
    {
        foreach (actor in faction)
        {
            if (!this.tierActorOnMap(actor))
                continue;
            local hasStatus = actor.getSkills().hasSkill("effects.pale_dead_command_status");
            local inRange = false;
            foreach (king in commanders)
            {
                if (actor.isAlliedWith(king) && actor.getTile().getDistanceTo(king.getTile()) <= 4 && this.isPaleUndeadActor(actor))
                {
                    inRange = true;
                    break;
                }
            }
            if (inRange && !hasStatus)
                this.applyTierStatus(actor, "dead_command");
            else if (!inRange && hasStatus)
                actor.getSkills().removeByID("effects.pale_dead_command_status");
        }
    }
    if (commanders.len() == 0)
        delete this.Battle.HadDeadCommand;
};

S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.m.PaleStenchRound <- -1;

    q.onCombatStarted = @(__original) function()
    {
        this.m.PaleStenchRound = -1;
        __original();
        S.refreshDeadCommand();
    };

    q.onMovementFinished = @(__original) function()
    {
        __original();
        S.refreshDeadCommand();
    };

    q.onTurnStart = @(__original) function()
    {
        __original();
        if (S.Battle == null)
            return;
        S.refreshDeadCommand();
        local actor = this.getActor();
        if (!S.tierActorOnMap(actor) || this.m.PaleStenchRound == ::Time.getRound())
            return;
        foreach (tile in S.area(actor.getTile()))
        {
            if (S.isEnemy(actor, tile) && tile.getEntity().getSkills().hasSkill("effects.pale_stench_aura"))
            {
                this.m.PaleStenchRound = ::Time.getRound();
                actor.setFatigue(::Math.min(actor.getFatigueMax(), actor.getFatigue() + 8));
                S.applyTierStatus(actor, "stench");
                actor.setDirty(true);
                break;
            }
        }
    };
});

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.getTurnOrderInitiative = @(__original) function()
    {
        if (S.Battle != null)
        {
            local stagger = this.getSkills().getSkillByID("effects.staggered");
            if (stagger != null && "PaleLastRound" in stagger.m
                && stagger.m.PaleLastRound >= ::Tactical.TurnSequenceBar.getCurrentRound())
                return -100000;
        }
        return __original();
    };
});

S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.onDeath = @(__original) function( _killer, _skill, _tile, _fatality )
    {
        local background = S.getUndeadBackground(this);
        local bound = S.isSoulbound(this);
        if (background == null || background.m.PaleRanged || (background.m.PaleTier < 2 && !bound))
            return __original(_killer, _skill, _tile, _fatality);

        local appearance = this.getItems().getAppearance();
        local before = { Corpse = appearance.Corpse, Head = appearance.HideCorpseHead, Hair = appearance.HideHair, Beard = appearance.HideBeard };
        appearance.HideHair = true;
        appearance.HideBeard = true;
        local skeleton = background.m.PaleSkeleton;
        if ((skeleton && !bound) || _fatality == ::Const.FatalityType.Decapitated || _fatality == ::Const.FatalityType.Smashed)
        {
            // Use the engine's separate corpse layers for skeletons and detached heads.
            this.getSprite("body").setBrush(skeleton ? "bust_skeleton_body_01" : "bust_naked_body_01");
            this.getSprite("head").setBrush(skeleton ? "bust_skeleton_head" : "bgpu_bust_head_01");
        }
        else
        {
            // The generated corpse brush includes the head.
            appearance.HideCorpseHead = true;
        }
        // The engine derives its arrow and javelin overlays from this name.
        appearance.Corpse = "bust_naked_body_01_dead";
        local result = __original(_killer, _skill, _tile, _fatality);
        appearance.Corpse = before.Corpse;
        appearance.HideCorpseHead = before.Head;
        appearance.HideHair = before.Hair;
        appearance.HideBeard = before.Beard;
        return result;
    };
});

S.Mod.hook("scripts/skills/skill", function(q)
{
    q.MV_onAttackRolled = @(__original) function( _info )
    {
        __original(_info);
        if (S.Battle == null || !this.isAttack() || _info.Target.isAlliedWith(_info.User))
            return;
        local charge = _info.User.getSkills().getSkillByID("effects.pale_death_charge");
        if (charge != null && charge.m.ChargeReady)
        {
            charge.m.ChargeReady = false;
            _info.PropertiesForUse.DamageTotalMult *= 1.3;
            _info.PaleDeathCharge <- true;
        }
    };

    q.onScheduledTargetHit = @(__original) function( _info )
    {
        __original(_info);
        if ("MV_AttackInfo" in _info && _info.MV_AttackInfo != null && "PaleDeathCharge" in _info.MV_AttackInfo
            && S.tierActorOnMap(_info.TargetEntity))
            S.applyTierStagger(_info.TargetEntity);
    };
});

// A natural cleaver attack qualifies for the Reforged cleaver group while using no item.
foreach (perk in ["perk_mastery_cleaver", "perk_rf_sanguinary", "perk_rf_mauler"])
{
    S.Mod.hook("scripts/skills/perks/" + perk, function(q)
    {
        q.isSkillValid = @(__original) function( _skill )
        {
            return _skill.getID() == "actives.pale_rending_pounce" || __original(_skill);
        };
    });
}
