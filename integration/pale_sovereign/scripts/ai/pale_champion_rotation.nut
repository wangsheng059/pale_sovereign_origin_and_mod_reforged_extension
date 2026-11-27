// Dedicated Rotation AI behavior for the Pale Sovereign Lich King / Champion.
// Enables three high-value rotations:
// 1. Rescue the Mentor (PaleChief) from enemy Zone of Control.
// 2. Peel for a wounded or fragile/ranged ally trapped in enemy ZoC.
// 3. Breakthrough past a blocking summon/ally to enter melee (especially against marked Prey).
this.pale_champion_rotation <- ::inherit("scripts/ai/tactical/behavior", {
    m = {
        Skill = null,
        TargetTile = null,
        UsedRound = -1
    },

    function create()
    {
        this.m.ID = ::Const.AI.Behavior.ID.PaleChampionRotation;
        this.m.Order = ::Const.AI.Behavior.Order.PaleChampionRotation;
        this.behavior.create();
    }

    function onTurnStarted()
    {
        this.m.Skill = null;
        this.m.TargetTile = null;
    }

    function onEvaluate( _entity )
    {
        this.m.Skill = null;
        this.m.TargetTile = null;

        local S = ::PaleSovereign;
        if (!S.isChampionAI(_entity))
            return ::Const.AI.Behavior.Score.Zero;
        if (this.m.UsedRound == ::Time.getRound())
            return ::Const.AI.Behavior.Score.Zero;
        if (_entity.getMoraleState() == ::Const.MoraleState.Fleeing || _entity.getCurrentProperties().IsStunned
            || _entity.getCurrentProperties().IsRooted || ::Tactical.State.isAutoRetreat())
            return ::Const.AI.Behavior.Score.Zero;

        local skill = _entity.getSkills().getSkillByID("actives.rotation");
        if (skill == null || skill.isHidden() || !skill.isUsable() || !skill.isAffordable())
            return ::Const.AI.Behavior.Score.Zero;

        local myTile = _entity.getTile();
        local allies = _entity.getAlliedFactions();
        local myZone = myTile.getZoneOfControlCountOtherThan(allies);
        local myHP = _entity.getHitpointsPct();
        local myHasSW = _entity.getSkills().hasSkill("effects.shieldwall");
        local chief = S.chief();
        local chiefID = (chief != null && !::MSU.isNull(chief)) ? chief.getID() : -1;
        local chiefTile = (chief != null && !::MSU.isNull(chief) && chief.isAlive() && chief.isPlacedOnMap()) ? chief.getTile() : null;
        local apAfter = _entity.getActionPoints() - skill.getActionPointCost();

        local bestTile = null;
        local bestScore = 0.0;

        for (local d = 0; d < 6; ++d)
        {
            if (!myTile.hasNextTile(d))
                continue;
            local t = myTile.getNextTile(d);
            if (!t.IsOccupiedByActor || !skill.isUsableOn(t))
                continue;
            local ally = t.getEntity();
            if (ally == null || ::MSU.isNull(ally) || !ally.isAlive() || ally.isDying() || !ally.isAlliedWith(_entity))
                continue;

            local allyZone = t.getZoneOfControlCountOtherThan(ally.getAlliedFactions());
            local isChief = ally.getID() == chiefID;
            local negTile = this.hasNegativeTileEffect(t, _entity);
            if (negTile && !isChief)
                continue;
            // Never cancel our own active Shieldwall by rotating unless rescuing the Mentor from immediate ZoC!
            if (myHasSW && !(isChief && allyZone > 0))
                continue;

            local score = 0.0;

            // Priority 1: Rescue Mentor from enemy ZoC onto a strictly safer tile (especially 0-ZoC full rescue!).
            if (isChief && allyZone > 0 && myZone < allyZone)
            {
                score = (myZone == 0 ? 1550.0 : 1380.0) + allyZone * 150.0 + (1.0 - ally.getHitpointsPct()) * 300.0;
            }
            else if (allyZone > 0)
            {
                // Do not pull a healthy shieldwall/spearwall tank out of position unless critically hurt.
                local allyHP = ally.getHitpointsPct();
                local holdingWall = ally.getSkills().hasSkill("effects.shieldwall") || ally.getSkills().hasSkill("effects.spearwall");
                if (holdingWall && allyHP >= 0.35)
                    continue;

                local allyIsFragile = ally.isArmedWithRangedWeapon() || ally.getSkills().hasSkill("actives.bgp_necro_raise")
                    || ally.getSkills().hasSkill("actives.raise_undead");
                local allyIsSummon = ally.getFaction() == ::Const.Faction.PlayerAnimals;

                // Priority 2: Peel for a fragile/ranged or critically wounded brother.
                if (!allyIsSummon && (allyIsFragile || allyHP < 0.55) && myZone < allyZone && myHP >= allyHP + 0.10)
                {
                    score = (allyIsFragile ? 980.0 : 880.0) + (1.0 - allyHP) * 260.0 + (allyZone - myZone) * 80.0;
                }
                // Priority 3: Breakthrough past a blocking summon (or non-shield ally) when Lich King is out of melee.
                else if (myZone == 0 && (allyIsSummon || (!::BGP.hasShield(ally) && myHP >= allyHP)))
                {
                    local preyAdj = false;
                    local hvtAdj = false;
                    local chiefThreatAdj = false;
                    local adjEnemies = 0;
                    for (local d2 = 0; d2 < 6; ++d2)
                    {
                        if (!t.hasNextTile(d2))
                            continue;
                        local n = t.getNextTile(d2);
                        if (!n.IsOccupiedByActor || ::Math.abs(n.Level - t.Level) > 1)
                            continue;
                        local occ = n.getEntity();
                        if (!occ.isAlliedWith(_entity) && occ.isAlive() && !occ.isDying() && occ.getMoraleState() != ::Const.MoraleState.Fleeing)
                        {
                            ++adjEnemies;
                            local oSkills = occ.getSkills();
                            if (oSkills.hasSkill("effects.pale_prey"))
                                preyAdj = true;
                            if (occ.isArmedWithRangedWeapon() || oSkills.hasSkill("actives.raise_undead")
                                || oSkills.hasSkill("actives.root") || oSkills.hasSkill("actives.rally_the_troops"))
                                hvtAdj = true;
                            if (chiefTile != null && n.getDistanceTo(chiefTile) <= 2)
                                chiefThreatAdj = true;
                        }
                    }
                    if (adjEnemies > 0 && (chiefThreatAdj || (adjEnemies <= 2 && myHP >= 0.45 && (apAfter >= 4 || preyAdj || hvtAdj || allyIsSummon))))
                    {
                        score = (allyIsSummon ? 700.0 : 560.0) + (preyAdj ? 180.0 : 0.0)
                            + (hvtAdj ? 160.0 : 0.0) + (chiefThreatAdj ? 220.0 : 0.0)
                            + (apAfter >= 4 ? 120.0 : 0.0) + ::Math.min(2, adjEnemies) * 40.0;
                    }
                }
            }

            if (score > bestScore)
            {
                bestScore = score;
                bestTile = t;
            }
        }

        if (bestTile == null || bestScore <= 0.0)
            return ::Const.AI.Behavior.Score.Zero;

        this.m.Skill = skill;
        this.m.TargetTile = bestTile;
        return bestScore;
    }

    function onExecute( _entity )
    {
        local skill = this.m.Skill;
        local tile = this.m.TargetTile;
        this.m.Skill = null;
        this.m.TargetTile = null;
        if (skill != null && tile != null && skill.isUsable() && skill.isAffordable() && skill.isUsableOn(tile))
        {
            if (skill.use(tile))
            {
                this.m.UsedRound = ::Time.getRound();
                if (!_entity.isHiddenToPlayer())
                    this.getAgent().declareAction();
                if (skill.getDelay() != 0)
                    this.getAgent().declareEvaluationDelay(skill.getDelay());
            }
        }
        return true;
    }
});
