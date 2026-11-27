local S = ::PaleSovereign;

S.isChampionAI <- function( _actor )
{
    return this.Battle != null && _actor.getFaction() == ::Const.Faction.PlayerAnimals && !_actor.isPlayerControlled()
        && this.isDeployed(this.mainPet(), _actor);
};

S.isRaisedFighter <- function( _actor )
{
    return _actor.getFaction() == ::Const.Faction.PlayerAnimals && !_actor.isPlayerControlled()
        && _actor.getSkills().hasSkill(::BGP.Necro.MinionEffect);
};

S.undeadTargetPriority <- function( _actor, _target, _champion )
{
    if (_target.getMoraleState() == ::Const.MoraleState.Fleeing)
        return 0.0;

    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local priority = 0.0;
    local tSkills = _target.getSkills();
    if (this.Battle != null && tSkills.hasSkill("effects.pale_prey"))
        priority = smart ? 0.85 : 0.65;

    if (_target.getCurrentProperties().IsStunned || tSkills.hasSkill("effects.sleeping") || _target.isNonCombatant())
        return priority * 0.5;

    local chief = _champion ? this.chief() : ::BGP.Necro.getMaster(_actor);
    if (chief == null || ::MSU.isNull(chief)) chief = this.chief();
    local tile = _target.getTile();
    if (chief != null && !::MSU.isNull(chief) && chief.isAlive() && chief.isPlacedOnMap())
    {
        local chiefTile = chief.getTile();
        local distance = tile.getDistanceTo(chiefTile);
        if (smart && distance == 1 && ::Math.abs(tile.Level - chiefTile.Level) <= 1)
        {
            // Strict dist==1 peel: any enemy actively standing in Mentor's ZoC gets top priority over dist==2 threats!
            local chiefHurt = chief.getHitpointsPct() <= 0.75 || chiefTile.getZoneOfControlCountOtherThan(chief.getAlliedFactions()) >= 2;
            priority = ::Math.maxf(priority, chiefHurt ? (_champion ? 3.8 : 2.6) : (_champion ? 2.8 : 2.0));
        }
        else if (smart && distance == 2 && ::Math.abs(tile.Level - chiefTile.Level) <= 1)
        {
            local threatened = chief.getHitpointsPct() <= 0.65;
            priority = ::Math.maxf(priority, threatened ? (_champion ? 1.85 : 1.45) : (_champion ? 1.30 : 1.10));
        }
        else if (smart && distance == 3 && tile.getZoneOfControlCountOtherThan(_target.getAlliedFactions()) == 0)
        {
            // Intercept unengaged melee threats closing in on Mentor before they enter strike range.
            priority = ::Math.maxf(priority, _champion ? 1.25 : 1.05);
        }
        else if (!smart && distance <= 2 && distance <= _target.getIdealRange() && ::Math.abs(tile.Level - chiefTile.Level) <= 1)
        {
            local threatened = chief.getHitpoints() * 2 <= chief.getHitpointsMax();
            priority = ::Math.maxf(priority, threatened ? (_champion ? 2.0 : 1.25) : (_champion ? 0.7 : 0.4));
        }
    }

    if (smart)
    {
        // Peel enemies adjacent to our living Bow/Crossbow backliners too.
        foreach (bro in this.fieldBrothers())
        {
            if (::BGP.Autopilot.Frontline.isRangedRole(bro) && tile.getDistanceTo(bro.getTile()) <= 1)
            {
                priority = ::Math.maxf(priority, 0.90);
                break;
            }
        }
        // High-value casters, Banshees/Geists, Orc Berserkers, bannermen/drummers/warlords/officers, ranged shooters, Ancient polearms, and unshielded 2H killers.
        if (tSkills.hasSkill("actives.raise_undead") || tSkills.hasSkill("actives.horror") || tSkills.hasSkill("actives.miasma"))
            priority = ::Math.maxf(priority, 1.85);
        else if (tSkills.hasSkill("actives.root") || tSkills.hasSkill("actives.insect_swarm")
            || tSkills.hasSkill("actives.hex") || tSkills.hasSkill("actives.sleep")
            || _target.ClassName == "rf_banshee" || _target.ClassName == "ghost" || tSkills.hasSkill("actives.ghastly_touch"))
            priority = ::Math.maxf(priority, 1.45);
        else if (tSkills.hasSkill("effects.berserker_rage") || _target.ClassName == "orc_berserker"
            || _target.ClassName == "desert_stalker" || _target.ClassName == "executioner")
            priority = ::Math.maxf(priority, 1.15);
        else if (tSkills.hasSkill("actives.rally_the_troops") || tSkills.hasSkill("actives.barbarian_drum")
            || tSkills.hasSkill("actives.warcry") || _target.ClassName == "rf_skeleton_legatus"
            || _target.ClassName == "rf_skeleton_centurion" || _target.ClassName == "rf_skeleton_decanus"
            || _target.ClassName == "rf_marshal")
            priority = ::Math.maxf(priority, 1.10);
        else if (_target.getFlags().has("skeleton") && !_target.isArmedWithShield() && _target.getIdealRange() >= 2)
            priority = ::Math.maxf(priority, 0.95);
        else if (_target.isArmedWithRangedWeapon())
            priority = ::Math.maxf(priority, 0.85);
        else
        {
            local w = _target.getMainhandItem();
            if (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon)
                && !_target.isArmedWithShield())
                priority = ::Math.maxf(priority, 0.80);
        }
        // Avoid killing RF_Squire before enemy Knight is down (killing Squire buffs the Knight!).
        if (_target.ClassName == "rf_squire")
            priority *= 0.25;
        // Relative squad threat & turn-order awareness: prioritize foes with high hit chance against our squad & unacted threats!
        local st = ::BGP.Autopilot.Frontline.enemyLiveStats(_target);
        local sq = ::BGP.Autopilot.Frontline.enemySquadThreat(_target, null);
        if (sq.MaxHit >= 55 && !st.IsExhausted)
            priority += 0.45;
        if (st.CanActThisRound && st.TurnsUntil <= 3)
            priority += 0.30;
        if (st.IsExhausted && priority < 2.0)
            priority *= 0.85;
        // Wounded & armor-stripped focus-fire bonus so undead swarm collapses single enemies fast.
        local hpPct = _target.getHitpointsPct();
        if (hpPct <= 0.50)
            priority += (0.55 - hpPct) * 0.95;
        if (_target.getArmorMax(::Const.BodyPart.Body) > 30 && _target.getArmor(::Const.BodyPart.Body) <= 10)
            priority += 0.25;
        return priority;
    }

    local support = tSkills.hasSkill("actives.raise_undead") || tSkills.hasSkill("actives.barbarian_drum");
    return ::Math.maxf(priority, support ? 0.65 : (_target.isArmedWithRangedWeapon() ? 0.35 : 0.0));
};

S.championAttackScore <- function( _score, _actor, _target, _skill )
{
    if (_score <= 0 || _skill == null || !_skill.isAttack() || _target.isAlliedWith(_actor) || !_target.getTile().IsVisibleForEntity)
        return _score;
    if (_actor.isPlayerControlled()) return _score;
    // Permanent player-faction undead under Autopilot also prioritize marked Prey.
    if (_actor.getFaction() != ::Const.Faction.PlayerAnimals)
    {
        if (this.Battle == null || !this.isFriendlyUndead(_actor) || !_target.getSkills().hasSkill("effects.pale_prey")) return _score;
        return _score * (1.0 + 0.65 * ::Math.maxf(0.0, ::Math.minf(1.0, (_skill.getHitchance(_target) - 25) / 25.0)));
    }
    local champion = this.isChampionAI(_actor);
    if (!champion && !this.isRaisedFighter(_actor) && !this.isFormationUndead(_actor))
    {
        if (this.Battle == null || !this.isFriendlyUndead(_actor)
            || !_target.getSkills().hasSkill("effects.pale_prey")) return _score;
        return _score * (1.0 + 0.65 * ::Math.maxf(0.0, ::Math.minf(1.0, (_skill.getHitchance(_target) - 25) / 25.0)));
    }

    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local hit = _skill.getHitchance(_target);
    local bonus = this.undeadTargetPriority(_actor, _target, champion);
    local isLethal = false;
    if (hit >= (smart ? 40 : 55) && (smart || _target.getHitpoints() * 2 <= _target.getHitpointsMax()))
    {
        local damage = _skill.getExpectedDamage(_target);
        if (damage.DirectDamage + damage.HitpointDamage >= _target.getHitpoints())
        {
            isLethal = true;
            bonus = ::Math.maxf(bonus, _target.getMoraleState() == ::Const.MoraleState.Fleeing ? 0.15 : (smart ? 1.05 : 0.75));
        }
    }
    // Accept a lower hit chance when the mentor is at immediate risk.
    local confidence = bonus > 1.0 ? (hit - 20) / 15.0 : (hit - 25) / 25.0;
    bonus *= ::Math.maxf(0.0, ::Math.minf(1.0, confidence));
    local tSkills = _target.getSkills();
    if (!_skill.isRanged() && _actor.getTile().getDistanceTo(_target.getTile()) == 1
        && tSkills.hasSkill("effects.riposte") && !isLethal)
        bonus -= (_actor.getHitpointsPct() < 0.45 ? 0.65 : 0.35) * (1.0 - hit / 100.0);

    local stLive = smart ? ::BGP.Autopilot.Frontline.enemyLiveStats(_target) : null;
    if (isLethal && stLive != null && stLive.CanActThisRound)
        bonus += (stLive.TurnsUntil <= 3 ? 0.35 : 0.20);
    local mult = ::Math.maxf(0.20, 1.0 + bonus);
    // Use live engine hitchance (already fuses Lich King's MSk - foe MDef + real-time surround bonus + height!)
    // instead of absolute MDef cutoffs: low-hit attackers pivot away, while high-MSk/surrounding Lich King smashes through!
    if (smart && !_skill.isRanged() && !isLethal && bonus < 2.5)
    {
        if (_skill.getID() != "actives.split_shield" && ((tSkills.hasSkill("effects.shieldwall") && hit < 55) || hit < 35))
            mult *= 0.45;
        else if (_target.getArmor(::Const.BodyPart.Body) >= 200 && _target.isArmedWithShield() && _skill.getID() != "actives.split_shield" && hit < 65)
            mult *= 0.72;
    }
    return _score * mult;
};

S.isSafeChampionStep <- function( _behavior, _actor, _tile, _origin, _zones )
{
    if (_tile == null || (_tile.IsBadTerrain && !_origin.IsBadTerrain)
        || _tile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > _zones
        || _behavior.hasNegativeTileEffect(_tile, _actor))
        return false;

    foreach (neighbor in this.area(_tile))
    {
        if (!neighbor.IsOccupiedByActor || ::Math.abs(neighbor.Level - _tile.Level) > 1)
            continue;
        local enemy = neighbor.getEntity();
        if (!enemy.isAlliedWith(_actor) && enemy.getCurrentProperties().IsAttackingOnZoneOfControlEnter)
            return false;
    }
    return true;
};

S.planChampionEngagement <- function( _behavior, _actor )
{
    local origin = _actor.getTile();
    local allies = _actor.getAlliedFactions();
    if (origin.hasZoneOfControlOtherThan(allies))
        return null;

    local attack = _behavior.getAgent().getBehavior(::Const.AI.Behavior.ID.AttackDefault);
    if (attack == null)
        return null;
    local skill = attack.selectSkill(attack.m.PossibleSkills);
    if (skill == null || !skill.isAttack() || skill.isRanged() || !skill.isTargeted())
        return null;

    local ap = _actor.getActionPoints() - skill.getActionPointCost() - _actor.getCurrentProperties().AdditionalActionPointCost;
    local fatigue = _actor.getFatigueMax() - _actor.getFatigue() - skill.getFatigueCost();
    if (ap < 2 || fatigue < 0)
        return null;

    local minRange = skill.getMinRange();
    local maxRange = skill.getMaxRange();
    local height = skill.getMaxLevelDifference();
    local hits = _behavior.queryTargetsInMeleeRange(minRange, maxRange, height);
    // When a strike is available already, keep the native action and spend the AP on it.
    foreach (enemy in hits)
        if (skill.isUsableOn(enemy.getTile()))
            return null;

    local nav = ::Tactical.getNavigator();
    local settings = nav.createSettings();
    settings.ActionPointCosts = _actor.getActionPointCosts();
    settings.FatigueCosts = _actor.getFatigueCosts();
    settings.FatigueCostFactor = 0.0;
    settings.ActionPointCostPerLevel = _actor.getLevelActionPointCost();
    settings.FatigueCostPerLevel = _actor.getLevelFatigueCost();
    settings.MaxLevelDifference = _actor.getMaxTraversibleLevels();
    settings.AllowZoneOfControlPassing = false;
    settings.ZoneOfControlCost = ::Const.AI.Behavior.ZoneOfControlAPPenalty;
    settings.AlliedFactions = allies;
    settings.Faction = _actor.getFaction();

    local best = null;
    local bestValue = 0.0;
    local routes = {};
    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local isChamp = this.isChampionAI(_actor);
    // Champion uses conservative edge-tanking; disposable summons dive deeper to pin enemies.
    local maxZones = smart ? (isChamp ? 1 : 3) : 1;
    local master = ::BGP.Necro.getMaster(_actor);
    if (master == null || ::MSU.isNull(master)) master = this.chief();
    local masterTile = (master != null && !::MSU.isNull(master) && master.isAlive() && master.isPlacedOnMap()) ? master.getTile() : null;
    local guard = masterTile != null
        && (smart ? masterTile.hasZoneOfControlOtherThan(master.getAlliedFactions())
                  : (master.getHitpointsPct() <= 0.5 && origin.getDistanceTo(masterTile) <= 3 && masterTile.hasZoneOfControlOtherThan(master.getAlliedFactions())));
    foreach (opponent in _behavior.getAgent().getKnownOpponents())
    {
        if (::MSU.isNull(opponent.Actor))
            continue;
        local enemy = opponent.Actor.get();
        if (!enemy.isAlive() || enemy.isDying() || !enemy.isAttackable() || !enemy.isPlacedOnMap()
            || enemy.isAlliedWith(_actor) || enemy.getMoraleState() == ::Const.MoraleState.Fleeing)
            continue;
        local target = enemy.getTile();
        if (!target.IsVisibleForEntity || enemy.isHiddenToPlayer() || origin.getDistanceTo(target) > maxRange + 2
            || skill.getHitchance(enemy) < (smart && !isChamp ? 25 : 35))
            continue;

        local value = _behavior.queryTargetValue(_actor, enemy, skill);
        local eSkills = enemy.getSkills();
        local isHVT = enemy.isArmedWithRangedWeapon() || eSkills.hasSkill("actives.raise_undead")
            || eSkills.hasSkill("actives.root") || eSkills.hasSkill("actives.insect_swarm")
            || eSkills.hasSkill("actives.rally_the_troops");
        local nearMaster = masterTile != null && target.getDistanceTo(masterTile) <= 3;

        foreach (tile in _behavior.queryDestinationsInRange(target, minRange, maxRange, height))
        {
            if (!tile.IsEmpty || origin.getDistanceTo(tile) > 2 || !skill.isUsableOn(target, tile))
                continue;
            if (!(tile.ID in routes))
            {
                local cost = null;
                if (this.isSafeChampionStep(_behavior, _actor, tile, origin, maxZones) && nav.findPath(origin, tile, settings, 0))
                {
                    local path = nav.getCostForPath(_actor, settings, ap, fatigue);
                    if (path.IsComplete && path.End.ID == tile.ID && path.Tiles <= 2
                        && (path.Tiles <= 1 || this.isSafeChampionStep(_behavior, _actor, path.First, origin, 0)))
                        cost = path.ActionPointsRequired;
                }
                routes[tile.ID] <- cost;
            }
            if (routes[tile.ID] == null)
                continue;

            local candidate = value / (1.0 + 0.15 * routes[tile.ID]) * (tile.Level < target.Level ? 0.85 : 1.0);
            if (tile.getZoneOfControlCount(_actor.getFaction()) > 0 || tile.getZoneOfControlCount(::Const.Faction.Player) > 0)
                candidate *= 1.15;
            if (smart && !isChamp)
            {
                // Disposable summons excel at locking down enemy casters/archers, peeling for Mentor, and absorbing multi-enemy pressure!
                if (isHVT) candidate *= 1.60;
                if (nearMaster) candidate *= 1.50;
                local tileZones = tile.getZoneOfControlCountOtherThan(allies);
                if (tileZones >= 2) candidate *= 1.25;
            }
            if (guard && masterTile != null && tile.getDistanceTo(masterTile) > origin.getDistanceTo(masterTile))
                candidate *= 0.55;
            if (candidate > bestValue)
            {
                bestValue = candidate;
                best = { Tile = tile, Actor = enemy };
            }
        }
    }
    return best;
};

S.Mod.hook("scripts/ai/tactical/behavior", function(q)
{
    q.queryTargetValue = @(__original) function( _entity, _target, _skill = null )
    {
        return S.championAttackScore(__original(_entity, _target, _skill), _entity, _target, _skill);
    };
    q.evaluate = @(__original) function( _entity )
    {
        // Melee engagement is a generator. Inspect its plan only once the engine finishes evaluating it.
        local done = __original(_entity);
        if (!done || this.getID() != ::Const.AI.Behavior.ID.EngageMelee || this.getScore() <= 0
            || (!S.isRaisedFighter(_entity) && !S.isChampionAI(_entity)) || this.m.Skill != null || this.m.TargetTile == null
            || this.m.IsWaitingBeforeMove || this.m.IsWaitingAfterMove)
            return done;

        local plan = S.planChampionEngagement(this, _entity);
        if (plan != null)
        {
            this.m.TargetTile = plan.Tile;
            this.m.TargetActor = plan.Actor;
            this.m.TargetDistance = 0;
            this.getAgent().getIntentions().TargetTile = plan.Tile;
        }
        else if (S.isChampionAI(_entity) && ::Autopilot.conf("bgpSmartFrontline") && this.m.TargetTile.ID != _entity.getTile().ID)
        {
            // Prevent Lich King from marching 3+ tiles (burning Shieldwall & attack AP) into an exposed multi-enemy corner pocket!
            local origin = _entity.getTile();
            local dest = this.m.TargetTile;
            local dist = origin.getDistanceTo(dest);
            local destZones = dest.getZoneOfControlCountOtherThan(_entity.getAlliedFactions());
            local adjAllies = 0;
            foreach (nb in S.area(dest))
            {
                if (nb.ID != dest.ID && nb.IsOccupiedByActor && nb.getEntity().isAlliedWith(_entity) && nb.getEntity().getID() != _entity.getID())
                    ++adjAllies;
            }
            local dist2Enemies = 0;
            foreach (op in this.getAgent().getKnownOpponents())
            {
                local opp = op.Actor;
                if (opp == null || ::MSU.isNull(opp) || !opp.isAlive() || opp.isDying() || !opp.isPlacedOnMap() || opp.isAlliedWith(_entity)) continue;
                if (opp.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                if (dest.getDistanceTo(opp.getTile()) == 2) ++dist2Enemies;
            }
            if ((destZones >= 3 && adjAllies == 0)
                || (dist >= 3 && (destZones >= 2 || (destZones >= 1 && adjAllies <= 1 && dist2Enemies >= 2))))
            {
                this.m.TargetTile = null;
                this.m.TargetActor = null;
                this.m.Score = 0;
            }
        }
        return done;
    };
});
