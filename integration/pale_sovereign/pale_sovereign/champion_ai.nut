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
        if (smart && distance <= 2 && ::Math.abs(tile.Level - chiefTile.Level) <= 1)
        {
            local threatened = chief.getHitpoints() * 2 <= chief.getHitpointsMax();
            priority = ::Math.maxf(priority, threatened ? (_champion ? 2.2 : 1.7) : (_champion ? 1.55 : 1.30));
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
        // High-value casters, bannermen/warlords, ranged shooters, and unshielded 2H/polearm killers.
        if (tSkills.hasSkill("actives.raise_undead") || tSkills.hasSkill("actives.root")
            || tSkills.hasSkill("actives.insect_swarm") || tSkills.hasSkill("actives.hex")
            || tSkills.hasSkill("actives.horror") || tSkills.hasSkill("actives.sleep"))
            priority = ::Math.maxf(priority, 1.35);
        else if (tSkills.hasSkill("actives.rally_the_troops") || tSkills.hasSkill("actives.barbarian_drum")
            || tSkills.hasSkill("actives.warcry"))
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
        // Wounded & armor-stripped focus-fire bonus so undead swarm collapses single enemies fast.
        local hpPct = _target.getHitpointsPct();
        if (hpPct <= 0.50)
            priority += (0.55 - hpPct) * 0.95;
        if (_target.getArmorMax(::Const.BodyPart.Body) > 30 && _target.getArmor(::Const.BodyPart.Body) <= 10)
            priority += 0.25;
        // Hex-Eater (嗜咒) synergy: non-permanent undead prioritize targets afflicted by necromantic debuffs (+10% armor pen, +6 fatigue/hit).
        if (_actor.getSkills().hasSkill("effects.bgp_necro_hunger") && ::BGP.Autopilot.Frontline.hasNecroDebuff(_target))
            priority += (_target.getArmor(::Const.BodyPart.Body) >= 120 ? 0.50 : 0.35);
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
    // 1.6.33 常驻亡灵交给自动战斗时（阵营是 Player）也优先攻击猎物
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

    local mult = ::Math.maxf(0.20, 1.0 + bonus);
    // Stop Lich King and undead minions from mindlessly whacking Shieldwall / ultra-heavy armored shield tanks when non-lethal.
    if (smart && !_skill.isRanged() && !isLethal)
    {
        if (tSkills.hasSkill("effects.shieldwall") && _skill.getID() != "actives.split_shield" && hit < 65)
            mult *= 0.50;
        else if (_target.getArmor(::Const.BodyPart.Body) >= 200 && _target.isArmedWithShield() && _skill.getID() != "actives.split_shield")
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
    // Lich King plays smart anti-surround (<=2 ZoC when healthy, <=1 when hurt); disposable zombies/skeletons dive into up to 3 ZoC to tie down enemies & archers!
    local maxZones = smart ? (isChamp ? (_actor.getHitpointsPct() < 0.50 ? 1 : 2) : 3) : 1;
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
        return done;
    };
});
