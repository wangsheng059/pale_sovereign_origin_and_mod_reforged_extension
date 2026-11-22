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

    local priority = 0.0;
    local prey = this.Battle == null ? null : this.Battle.Prey;
    if (prey != null && !::MSU.isNull(prey) && prey.getID() == _target.getID()
        && _target.getSkills().hasSkill("effects.pale_prey"))
        priority = 0.65;

    if (_target.getCurrentProperties().IsStunned || _target.getSkills().hasSkill("effects.sleeping") || _target.isNonCombatant())
        return priority * 0.5;

    local chief = _champion ? this.chief() : ::BGP.Necro.getMaster(_actor);
    if (chief != null && !::MSU.isNull(chief) && chief.isAlive() && chief.isPlacedOnMap())
    {
        local tile = _target.getTile();
        local chiefTile = chief.getTile();
        local distance = tile.getDistanceTo(chiefTile);
        if (distance <= 2 && distance <= _target.getIdealRange() && ::Math.abs(tile.Level - chiefTile.Level) <= 1)
        {
            local threatened = chief.getHitpoints() * 2 <= chief.getHitpointsMax();
            priority = ::Math.maxf(priority, threatened ? (_champion ? 2.0 : 1.25) : (_champion ? 0.7 : 0.4));
        }
    }
    local support = _target.getSkills().hasSkill("actives.raise_undead") || _target.getSkills().hasSkill("actives.barbarian_drum");
    return ::Math.maxf(priority, support ? 0.65 : (_target.isArmedWithRangedWeapon() ? 0.35 : 0.0));
};

S.championAttackScore <- function( _score, _actor, _target, _skill )
{
    if (_score <= 0 || _skill == null || !_skill.isAttack() || _target.isAlliedWith(_actor) || !_target.getTile().IsVisibleForEntity)
        return _score;
    if (_actor.getFaction() != ::Const.Faction.PlayerAnimals || _actor.isPlayerControlled()) return _score;
    local champion = this.isChampionAI(_actor);
    if (!champion && !this.isRaisedFighter(_actor))
    {
        if (this.Battle == null || this.Battle.Prey == null || !_actor.getFlags().has("undead")
            || !_target.getSkills().hasSkill("effects.pale_prey")) return _score;
        return _score * (1.0 + 0.65 * ::Math.maxf(0.0, ::Math.minf(1.0, (_skill.getHitchance(_target) - 25) / 25.0)));
    }

    local hit = _skill.getHitchance(_target);
    local bonus = this.undeadTargetPriority(_actor, _target, champion);
    if (hit >= 55 && _target.getHitpoints() * 2 <= _target.getHitpointsMax())
    {
        local damage = _skill.getExpectedDamage(_target);
        if (damage.DirectDamage + damage.HitpointDamage >= _target.getHitpoints())
            bonus = ::Math.maxf(bonus, _target.getMoraleState() == ::Const.MoraleState.Fleeing ? 0.15 : 0.75);
    }
    // Accept a lower hit chance when the mentor is at immediate risk.
    local confidence = bonus > 1.0 ? (hit - 20) / 15.0 : (hit - 25) / 25.0;
    bonus *= ::Math.maxf(0.0, ::Math.minf(1.0, confidence));
    if (!_skill.isRanged() && _actor.getTile().getDistanceTo(_target.getTile()) == 1
        && _target.getSkills().hasSkill("effects.riposte"))
        bonus -= (_actor.getHitpointsPct() < 0.45 ? 0.65 : 0.30) * (1.0 - hit / 100.0);
    return _score * (1.0 + bonus);
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
    local master = ::BGP.Necro.getMaster(_actor);
    local guard = master != null && !::MSU.isNull(master) && master.isAlive() && master.isPlacedOnMap()
        && master.getHitpointsPct() <= 0.5 && origin.getDistanceTo(master.getTile()) <= 3
        && master.getTile().hasZoneOfControlOtherThan(master.getAlliedFactions());
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
            || skill.getHitchance(enemy) < 35)
            continue;

        local value = _behavior.queryTargetValue(_actor, enemy, skill);
        foreach (tile in _behavior.queryDestinationsInRange(target, minRange, maxRange, height))
        {
            if (!tile.IsEmpty || origin.getDistanceTo(tile) > 2 || !skill.isUsableOn(target, tile))
                continue;
            if (!(tile.ID in routes))
            {
                local cost = null;
                if (this.isSafeChampionStep(_behavior, _actor, tile, origin, 1) && nav.findPath(origin, tile, settings, 0))
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
            if (tile.getZoneOfControlCount(_actor.getFaction()) > 0) candidate *= 1.12;
            if (guard && tile.getDistanceTo(master.getTile()) > origin.getDistanceTo(master.getTile())) candidate *= 0.55;
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
