this.bgp_autopilot_tactics <- ::inherit("scripts/ai/tactical/behavior", {
    m = { Skill = null, TargetTile = null, Failed = null, Round = -1 },

    function create()
    {
        this.m.ID = ::Const.AI.Behavior.ID.BGP_Tactics;
        this.m.Order = ::Const.AI.Behavior.Order.BGP_Tactics;
        this.behavior.create();
        this.m.Failed = {};
    }

    function makeContext( actor )
    {
        local c = { Actor = actor, Behavior = this, Origin = actor.getTile(), Enemies = [], Allies = [], Cache = {} };
        foreach (opponent in this.getAgent().getKnownOpponents()) {
            local unit = opponent.Actor;
            if (::MSU.isNull(unit) || !unit.isAlive() || unit.isDying() || !unit.isPlacedOnMap() || !unit.isAttackable()
                || unit.isAlliedWith(actor) || unit.isHiddenToPlayer() || !unit.getTile().IsVisibleForPlayer) continue;
            c.Enemies.push(unit.getTile());
        }
        foreach (unit in this.getAgent().getKnownAllies()) {
            if (!::MSU.isNull(unit) && unit.isAlive() && !unit.isDying() && unit.isPlacedOnMap() && unit.isAlliedWith(actor))
                c.Allies.push(unit.getTile());
        }
        c.Engaged <- ::BGP.Autopilot.zone(actor, c.Origin) > 0;
        return c;
    }

    function targets( c, type )
    {
        if (type == "Enemies") return c.Enemies;
        if (type == "Allies") return c.Allies;
        if (type in c.Cache) return c.Cache[type];
        local tiles = [];
        if (type == "Corpses") {
            foreach (tile in ::Tactical.Entities.getCorpses())
                if (tile.IsVisibleForPlayer && ::BGP.Necro.getCorpse(tile) != null) tiles.push(tile);
        } else if (type == "Centers") {
            local seen = {};
            foreach (enemy in c.Enemies) {
                if (!(enemy.ID in seen)) { seen[enemy.ID] <- true; tiles.push(enemy); }
                foreach (tile in ::std.Tile.iterAdjacent(enemy)) {
                    if (tile.ID in seen || !tile.IsVisibleForPlayer) continue;
                    seen[tile.ID] <- true;
                    tiles.push(tile);
                }
            }
        } else if (type == "Adjacent") {
            foreach (tile in ::std.Tile.iterAdjacent(c.Origin)) if (tile.IsEmpty) tiles.push(tile);
        } else {
            tiles.push(c.Origin);
        }
        c.Cache[type] <- tiles;
        return tiles;
    }

    function validTarget( skill, tile )
    {
        if (!skill.isTargeted()) return true;
        if (skill.ClassName == "bgp_necro_possess_skill" && (!tile.IsOccupiedByActor
            || tile.getEntity().getSkills().hasSkill("effects.possessed_undead")
            || (skill.m.BGPAutoPossessTargets != null && skill.m.BGPAutoPossessRound == ::Time.getRound()
                && tile.getEntity().getID() in skill.m.BGPAutoPossessTargets))) return false;
        return skill.isInRange(tile) && skill.isUsableOn(tile);
    }

    function canUse( skill, tile )
    {
        return skill != null && !skill.isHidden() && skill.isUsable() && skill.isAffordable()
            && this.validTarget(skill, tile);
    }

    function onEvaluate( actor )
    {
        this.m.Skill = null;
        this.m.TargetTile = null;
        if (actor.getMoraleState() == ::Const.MoraleState.Fleeing || !::Autopilot.isUnderAIControl(actor)) return 0;
        if (this.m.Round != ::Time.getRound()) {
            this.m.Round = ::Time.getRound();
            this.m.Failed.clear();
        }
        local actions = ::BGP.Autopilot.Actions;
        local skills = actor.getSkills().getSkillsByFunction(@(s) s.getID() in actions && !s.isHidden() && s.isUsable() && s.isAffordable());
        if (skills.len() == 0) return 0;
        local c = this.makeContext(actor);
        local best = 0.0;
        foreach (skill in skills) {
            if (skill.getID() in this.m.Failed) continue;
            local action = actions[skill.getID()];
            foreach (tile in this.targets(c, action.Targets)) {
                if (!this.validTarget(skill, tile)) continue;
                local value = action.Score(c, skill, tile);
                if (value > best) {
                    this.m.Skill = skill;
                    this.m.TargetTile = tile;
                    best = value;
                }
            }
        }
        return best * ::Const.AI.Behavior.Score.Attack * this.getProperties().BehaviorMult[this.m.ID];
    }

    function onExecute( actor )
    {
        local skill = this.m.Skill, tile = this.m.TargetTile;
        this.m.Skill = null;
        this.m.TargetTile = null;
        if (skill != null) {
            if (tile == null || !this.canUse(skill, tile) || !skill.use(tile))
                this.m.Failed[skill.getID()] <- true;
            else {
                if (!actor.isHiddenToPlayer()) this.getAgent().declareAction();
                if (skill.getDelay() != 0) this.getAgent().declareEvaluationDelay(skill.getDelay());
            }
        }
        return true;
    }
});
