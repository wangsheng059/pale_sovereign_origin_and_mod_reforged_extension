this.pale_formation_move <- ::inherit("scripts/ai/tactical/behavior", {
    m = { NextTile = null, Moving = false, Joined = false, BlockedRound = -1 },

    function create()
    {
        this.m.ID = ::Const.AI.Behavior.ID.PaleFormation;
        this.m.Order = ::Const.AI.Behavior.Order.PaleFormation;
        this.behavior.create();
    }

    function settingsFor(actor)
    {
        local settings = ::Tactical.getNavigator().createSettings();
        settings.ActionPointCosts = actor.getActionPointCosts();
        settings.FatigueCosts = actor.getFatigueCosts();
        settings.FatigueCostFactor = 0.0;
        settings.ActionPointCostPerLevel = actor.getLevelActionPointCost();
        settings.FatigueCostPerLevel = actor.getLevelFatigueCost();
        settings.MaxLevelDifference = actor.getMaxTraversibleLevels();
        settings.AllowZoneOfControlPassing = false;
        settings.ZoneOfControlCost = ::Const.AI.Behavior.ZoneOfControlAPPenalty;
        settings.AlliedFactions = actor.getAlliedFactions();
        settings.Faction = actor.getFaction();
        return settings;
    }

    function firstStep(actor, settings, goal, range)
    {
        local nav = ::Tactical.getNavigator(), origin = actor.getTile();
        if (!nav.findPath(origin, goal, settings, range)) return null;
        local path = nav.getCostForPath(actor, settings, actor.getActionPoints(), actor.getFatigueMax() - actor.getFatigue());
        if (path.Tiles < 1 || path.End == null || path.End.ID == origin.ID) return null;
        local first = path.Tiles == 1 ? path.End : path.First;
        return first != null && first.IsEmpty && origin.getDistanceTo(first) == 1 ? first : null;
    }

    function regroup(actor, group, threats, settings)
    {
        local origin = actor.getTile(), nearest = 99;
        foreach (t in group.Tiles) nearest = ::Math.min(nearest, t.getDistanceTo(origin));
        local smart = ::Autopilot.conf("bgpSmartFrontline");
        local isDisposable = !::PaleSovereign.isChampionAI(actor);
        local enemyRanged = 0;
        if (smart) {
            foreach (e in threats) {
                if (e.Tile.IsOccupiedByActor && e.Tile.getEntity().isArmedWithRangedWeapon())
                    ++enemyRanged;
            }
        }
        // Under heavy enemy archer fire (>= 3 shooters like Goblins/Nobles/Bandits), arrow-resistant Skeletons & Lich King screen AHEAD of our living brothers!
        local maxLead = 0;
        if (smart) {
            if (isDisposable) maxLead = enemyRanged >= 3 ? 2 : 1;
            else if (enemyRanged >= 3) maxLead = 1;
        }
        local lead = ::PaleSovereign.formationLead(origin, threats);
        if (lead <= maxLead && nearest <= 2 && origin.getDistanceTo(group.Anchor) <= 3 && (!smart || maxLead == 0 || lead >= 1))
            return null;

        local seen = {}, candidates = [];
        foreach (at in group.Tiles) foreach (t in ::PaleSovereign.area(at)) {
            if (t.ID in seen || !t.IsEmpty) continue;
            seen[t.ID] <- true;
            local tLead = ::PaleSovereign.formationLead(t, threats);
            if (tLead > maxLead || !::PaleSovereign.isSafeChampionStep(this, actor, t, origin, 0)) continue;
            // Strongly prefer front-screen tiles ahead of our brothers to absorb arrows & Orc charges.
            local screenPref = (smart && maxLead > 0 && tLead >= 1) ? (-2.2 * tLead) : 0.0;
            candidates.push({ Tile = t, Cost = origin.getDistanceTo(t) + 0.75 * t.getDistanceTo(group.Anchor) + screenPref });
        }
        candidates.sort(@(a, b) a.Cost != b.Cost ? a.Cost <=> b.Cost : a.Tile.ID <=> b.Tile.ID);
        foreach (candidate in candidates) {
            local first = this.firstStep(actor, settings, candidate.Tile, 0);
            if (first != null && ::PaleSovereign.formationLead(first, threats) <= ::Math.max(lead, maxLead)
                && ::PaleSovereign.isSafeChampionStep(this, actor, first, origin, 0)) return first;
        }
        return null;
    }

    function reinforce(actor, threats, settings)
    {
        local origin = actor.getTile(), range = ::Math.max(1, actor.getIdealRange());
        local smart = ::Autopilot.conf("bgpSmartFrontline");
        local isChamp = ::PaleSovereign.isChampionAI(actor);
        local maxZones = smart ? (isChamp ? 2 : 3) : 1;
        // An outlying brother can make contact beyond this unit's personal sight.
        if (threats.len() == 0 && "ContactTile" in ::PaleSovereign.Battle)
            threats.push({ Tile = ::PaleSovereign.Battle.ContactTile, Front = 0 });
        foreach (enemy in threats) {
            if (origin.getDistanceTo(enemy.Tile) <= range && ::Math.abs(origin.Level - enemy.Tile.Level) <= 1) {
                this.m.Joined = true;
                return null;
            }
            local hvtDiscount = 0;
            if (smart && enemy.Tile.IsOccupiedByActor) {
                local foe = enemy.Tile.getEntity();
                local fs = foe.getSkills();
                if (foe.isArmedWithRangedWeapon() || fs.hasSkill("actives.raise_undead")
                    || fs.hasSkill("actives.miasma") || fs.hasSkill("actives.horror")
                    || fs.hasSkill("actives.root") || fs.hasSkill("actives.rally_the_troops"))
                    hvtDiscount = 3;
            }
            enemy.Cost <- origin.getDistanceTo(enemy.Tile) + (enemy.Front <= 2 ? 0 : 3) - hvtDiscount;
        }
        threats.sort(@(a, b) a.Cost <=> b.Cost);
        foreach (enemy in threats) {
            local first = this.firstStep(actor, settings, enemy.Tile, range);
            if (first != null && ::PaleSovereign.isSafeChampionStep(this, actor, first, origin, maxZones)) return first;
        }
        return null;
    }

    function onEvaluate(actor)
    {
        this.m.NextTile = null;
        this.m.Moving = false;
        local S = ::PaleSovereign;
        if (!S.isFormationUndead(actor)) return 0;
        if (!S.Battle.CompanyContact) this.m.Joined = false;
        if (this.m.Joined || this.m.BlockedRound == ::Time.getRound() || actor.getCurrentProperties().IsRooted
            || actor.getMoraleState() == ::Const.MoraleState.Fleeing || ::Tactical.State.isAutoRetreat()
            || actor.getActionPoints() < ::Const.Movement.AutoEndTurnBelowAP) return 0;
        local brothers = S.fieldBrothers();
        if (brothers.len() == 0) { S.Battle.CompanyContact = true; return 0; }
        if (actor.getTile().hasZoneOfControlOtherThan(actor.getAlliedFactions())) {
            if (S.Battle.CompanyContact) this.m.Joined = true;
            return 0;
        }
        local group = S.formationGroup(brothers), threats = S.formationThreats(this.getAgent(), group);
        this.m.NextTile = S.Battle.CompanyContact ? this.reinforce(actor, threats, this.settingsFor(actor))
            : this.regroup(actor, group, threats, this.settingsFor(actor));
        return this.m.NextTile == null ? 0 : ::Const.AI.Behavior.Score.Attack * (S.Battle.CompanyContact ? 1.6 : 3.0);
    }

    function onExecute(actor)
    {
        if (!::PaleSovereign.isFormationUndead(actor)) return true;
        local nav = ::Tactical.getNavigator();
        if (this.m.IsFirstExecuted) {
            this.m.IsFirstExecuted = false;
            this.m.BlockedRound = ::Time.getRound();
            local tile = this.m.NextTile;
            if (tile == null || !tile.IsEmpty || actor.getTile().getDistanceTo(tile) != 1) return true;
            local settings = this.settingsFor(actor);
            if (!nav.findPath(actor.getTile(), tile, settings, 0)) return true;
            local path = nav.getCostForPath(actor, settings, actor.getActionPoints(), actor.getFatigueMax() - actor.getFatigue());
            if (!path.IsComplete || path.End.ID != tile.ID || path.Tiles != 1) return true;
            this.getAgent().adjustCameraToTarget(tile);
            this.m.Moving = true;
            return false;
        }
        if (this.m.Moving) {
            if (!nav.travel(actor, actor.getActionPoints(), actor.getFatigueMax() - actor.getFatigue())) {
                this.m.Moving = false;
            }
            return false;
        }
        if (this.m.NextTile != null && actor.getTile().ID == this.m.NextTile.ID) this.m.BlockedRound = -1;
        return true;
    }
});
