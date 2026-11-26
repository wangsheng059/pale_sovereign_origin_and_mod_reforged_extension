local A = ::BGP.Autopilot <- {
    Actions = {},
    function add( id, targets, score )
    {
        this.Actions["actives." + id] <- { Targets = targets, Score = score };
    },
    function zone( actor, tile )
    {
        return tile.getZoneOfControlCountOtherThan(actor.getAlliedFactions());
    },
    function nearest( tiles, tile )
    {
        local distance = 99;
        foreach (other in tiles) distance = ::Math.min(distance, tile.getDistanceTo(other));
        return distance;
    },
    function countNear( tiles, center, range = 1 )
    {
        local count = 0;
        foreach (tile in tiles) if (tile.getDistanceTo(center) <= range) ++count;
        return count;
    },
    function corpseValue( tile )
    {
        local info = ::BGP.Necro.getInfo(::BGP.Necro.getCorpse(tile));
        return info == null ? 0 : ::Math.minf(1.8, info.MaxHP / 140.0 + info.Armor / 600.0);
    },
    function weaponChance( s, t )
    {
        return ::Math.maxf(0.05, s.getHitchance(t.getEntity()) * 0.01);
    }
};

::MSU.AI.addBehavior("BGP_Tactics", "BGP.Tactics", 42, 200);
::MSU.AI.addBehavior("BGP_Frontline", "BGP.Frontline", 43, 200);
local page = ::Autopilot.msu.ModSettings.addPage("背景与亡灵");
page.addElement(::MSU.Class.BooleanSetting("bgpAutoBind", false, "自动收服敌方亡灵", "有空位时用驱役亡灵收服合格的濒死敌人。我方仆从始终由你决定是否收回。"));
page.addElement(::MSU.Class.BooleanSetting("bgpSmartFrontline", true, "远程评估等待与盾卫前顶", "战斗前期敌人无远程或远程弱于我方时原地等待，敌人进入 2 格内或同回合移动后即可攻击时再接敌，并优先由盾卫顶上举盾。"));

A.add("bgp_necro_raise", "Corpses", function(c, s, t) {
    local distance = A.nearest(c.Enemies, t);
    local pressure = A.zone(c.Actor, t);
    // Huge tactical bonus for raising a corpse adjacent to an enemy archer/caster (lock in ZoC)
    // or blocking an enemy closing in on our Mentor/ranged backline!
    local shutdownBonus = 0.0;
    local backlineScreenBonus = 0.0;
    local brothers = ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
    foreach (et in c.Enemies) {
        if (et.getDistanceTo(t) > 1) continue;
        local foe = et.getEntity();
        if (shutdownBonus == 0.0 && (foe.isArmedWithRangedWeapon() || foe.getSkills().hasSkill("actives.raise_undead")
            || foe.getSkills().hasSkill("actives.root") || foe.getSkills().hasSkill("actives.insect_swarm")
            || foe.getSkills().hasSkill("actives.horror") || foe.getSkills().hasSkill("actives.hex")))
        {
            shutdownBonus = 2.4;
        }
        if (backlineScreenBonus == 0.0 && foe.getMoraleState() != ::Const.MoraleState.Fleeing)
        {
            foreach (bro in brothers)
            {
                if (::MSU.isNull(bro) || !bro.isAlive() || !bro.isPlacedOnMap()) continue;
                if ((A.Frontline.isCasterRole(bro) || A.Frontline.isRangedRole(bro)) && et.getDistanceTo(bro.getTile()) <= 3)
                {
                    backlineScreenBonus = 2.0;
                    break;
                }
            }
        }
    }
    local aliveUndead = 0;
    foreach (at in c.Allies) {
        local u = at.getEntity();
        if (u != null && u.getFaction() == ::Const.Faction.PlayerAnimals && u.getFlags().has("undead"))
            ++aliveUndead;
    }
    // High urgency while building the first 4-5 undead meatshields; taper once >= 6 are already up so Mentor mixes in 3+ target Corpse Explosions!
    local urgencyBonus = 0.0;
    if (::Autopilot.conf("bgpSmartFrontline") && ::Time.getRound() >= 2 && ::Time.getRound() <= 8)
        urgencyBonus = aliveUndead < 4 ? 1.6 : (aliveUndead < 6 ? 0.8 : 0.0);
    return (distance <= 2 ? 7.0 : distance <= 5 ? 5.9 : 3.2) + A.corpseValue(t) * 1.6 + shutdownBonus + backlineScreenBonus + urgencyBonus
        + (c.Engaged && c.Origin.getDistanceTo(t) <= 2 ? 0.9 : 0)
        - (pressure > 2 ? 0.65 : 0) - (c.Behavior.hasNegativeTileEffect(t, c.Actor) ? 1.1 : 0);
});
A.add("bgp_necro_eternal_command", "Corpses", @(c, s, t) 8.0);
A.add("bgp_corpse_explosion", "Corpses", function(c, s, t) {
    local blast = s.getBlast(::BGP.Necro.getCorpse(t), c.Actor);
    if (blast == null) return 0;
    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local value = 0.0;
    local hits = 0;
    local armoredHits = 0;
    local lethalCount = 0;
    local moraleVulnerableHits = 0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1) continue;
        local enemy = tile.getEntity();
        ++hits;
        if (enemy.getArmor(::Const.BodyPart.Body) >= 130) ++armoredHits;
        if (!enemy.getFlags().has("undead")) ++moraleVulnerableHits;
        value += 1.1 + ::Math.minf(1.8, (blast.Blunt + blast.Cutting * 0.45) / 35.0);
        if (enemy.getHitpoints() <= blast.Blunt * 0.65) {
            value += 1.6;
            ++lethalCount;
        }
    }
    // Under 4 AP (3 AP with Mastery), avoid destroying scarce corpses on morale-immune Undead/Ancient Dead
    // before we have a meatshield screen, while still rewarding 3+ target blasts on living armored formations!
    if (smart) {
        if (hits < 2 && lethalCount == 0)
            return 0;
        local aliveUndead = 0;
        foreach (at in c.Allies) {
            local u = at.getEntity();
            if (u != null && u.getFaction() == ::Const.Faction.PlayerAnimals && u.getFlags().has("undead"))
                ++aliveUndead;
        }
        local totalCorpses = c.Behavior.targets(c, "Corpses").len();
        // Against pure morale-immune Undead/Skeletons with no kills, preserve scarce corpses for Raise Dead meatshields!
        if (moraleVulnerableHits == 0 && lethalCount == 0) {
            if (totalCorpses <= 2 || aliveUndead < 4)
                return 0;
            if (totalCorpses <= 4 || aliveUndead < 6)
                value *= 0.45;
        }
        if (hits >= 3 && aliveUndead >= 3 && (moraleVulnerableHits >= 2 || lethalCount >= 1)) {
            value += (hits >= 4 ? 3.8 : 2.4) + (armoredHits >= 2 ? 1.0 : 0.0) + (moraleVulnerableHits >= 3 ? 0.8 : 0.0);
        }
    }
    return value;
});
A.add("bgp_necro_curse_of_ages", "Centers", function(c, s, t) {
    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local alreadyCursed = 0;
    if (smart) {
        foreach (tile in c.Enemies) {
            if (tile.getEntity().getSkills().hasSkill("effects.bgp_curse_of_ages"))
                ++alreadyCursed;
        }
    }
    local value = 0.0;
    local hits = 0;
    local armoredHits = 0;
    local nonGoblinHits = 0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1) continue;
        local enemy = tile.getEntity();
        if (enemy.getMoraleState() == ::Const.MoraleState.Fleeing || enemy.getSkills().hasSkill("effects.bgp_curse_of_ages")) continue;
        ++hits;
        local isGoblin = enemy.getFlags().has("goblin");
        if (!isGoblin) ++nonGoblinHits;
        local w = 1.45 + ::Math.minf(0.9, enemy.getHitpointsMax() / 140.0);
        if (smart) {
            if (isGoblin) w *= 0.55;
            else if (enemy.getSkills().hasSkill("racial.champion") || enemy.getArmor(::Const.BodyPart.Body) >= 150 || enemy.getHitpointsMax() >= 140) {
                w += 0.65;
                ++armoredHits;
            }
        }
        value += w;
    }
    if (smart) {
        if (hits < 2) return 0;
        // Against Goblins, raising zombies / weakening Shamans beats 5-AP Curse unless 4+ goblins are stacked with no corpses to raise.
        if (nonGoblinHits == 0 && (hits < 4 || c.Behavior.targets(c, "Corpses").len() > 0)) return 0;
        // Once >= 3 active enemies are already cursed, switch back to Raise Dead / Weaken / Corpse Explosion instead of spamming Curse!
        if (alreadyCursed >= 3) value *= 0.40;
        else if (hits >= 3 && armoredHits >= 2 && ::Time.getRound() >= 2)
            value = ::Math.minf(10.2, value + 1.4);
        // Cap Curse peak score below urgent Raise Dead (~11-13) so Mentor keeps building the undead frontline first!
        value = ::Math.minf(10.2, value);
    }
    return value;
});
A.add("possess_undead", "Allies", function(c, s, t) {
    if (s.ClassName != "bgp_necro_possess_skill") return 0;
    local distance = A.nearest(c.Enemies, t);
    local unit = t.getEntity();
    return (distance <= 1 ? 6.4 : distance <= 3 ? 5.2 : 3.3)
        + ::Math.minf(1.0, unit.getCurrentProperties().MeleeSkill / 100.0) + (unit.isTurnDone() ? 0 : 0.45);
});
A.add("bgp_necro_infusion", "Allies", function(c, s, t) {
    local unit = t.getEntity();
    local wound = 1.0 - unit.getHitpointsPct();
    if (unit.getSkills().hasSkill("effects.bgp_necro_infusion") && wound < 0.35) return 0;
    local fatigue = unit.getFatigue() / ::Math.maxf(1.0, unit.getFatigueMax());
    return (A.nearest(c.Enemies, t) <= 2 ? 2.1 : 0.25) + 4.0 * wound + fatigue;
});
A.add("bgp_necro_flesh_reforge", "Allies", function(c, s, t) {
    return (A.nearest(c.Enemies, t) <= 3 ? 3.4 : 1.8) + (t.getEntity().getSkills().hasSkill("effects.bgp_graft_bone") ? 0.35 : 0);
});
A.add("bgp_necro_bind", "Enemies", @(c, s, t) ::Autopilot.conf("bgpAutoBind") ? 6.5 + t.getEntity().getHitpointsMax() / 200.0 : 0);
A.add("bgp_discerning", "Allies", function(c, s, t) {
    local talent = ::BGP.getTopTalent(t.getEntity());
    return talent == null ? 0 : 1.8 + 0.2 * talent.Stars + (A.nearest(c.Enemies, t) <= 3 ? 0.65 : 0);
});
A.add("bgp_seal_vanguard", "Allies", function(c, s, t) {
    local unit = t.getEntity(), weapon = unit.getMainhandItem();
    if (unit.isArmedWithRangedWeapon() || ::BGP.hasShield(unit) || weapon == null || unit.getSkills().hasSkill("actives.bgp_necro_raise")) return 0;
    if (!weapon.isItemType(::Const.Items.ItemType.TwoHanded) || !weapon.isItemType(::Const.Items.ItemType.MeleeWeapon)) return 0;
    return 9.2 + unit.getCurrentProperties().MeleeSkill / 120.0 + (A.nearest(c.Enemies, t) <= 3 ? 0.35 : 0);
});
A.add("bgp_seal_center", "Allies", function(c, s, t) {
    local unit = t.getEntity();
    return ::BGP.hasShield(unit) ? 9.0 + 0.12 * A.countNear(c.Allies, t) : 0;
});
A.add("bgp_seal_shadow", "Allies", function(c, s, t) {
    local unit = t.getEntity();
    if (unit.isArmedWithRangedWeapon()) return 9.0 + unit.getCurrentProperties().RangedSkill / 120.0;
    return unit.getSkills().hasSkill("perk.bgp_one_strike") || unit.getSkills().hasSkill("actives.puncture") ? 9.0 : 0;
});
A.add("bgp_feint", "Allies", function(c, s, t) {
    local relief = A.zone(c.Actor, c.Origin) - A.zone(c.Actor, t);
    if (relief <= 0 || t.getEntity().getHitpointsPct() < 0.6 || c.Behavior.hasNegativeTileEffect(t, c.Actor)) return 0;
    return c.Actor.getHitpointsPct() < 0.55 || relief >= 2 ? 3.5 + relief : 0;
});
A.add("bgp_hunting_hour", "Self", function(c, s, t) {
    local units = [c.Actor];
    units.extend(::BGP.getFriendlyBeasts());
    local value = 0.0;
    foreach (unit in units) {
        foreach (id in s.m.RemovedEffects) if (unit.getSkills().hasSkill(id)) { value += 3.3; break; }
        value += ::Math.minf(1.8, unit.getFatigue() / 28.0);
    }
    return value >= 2.0 ? value + 1.0 : 0;
});
local function devastating(c, s, t) {
    local targets = [t];
    if (s.getID() == "actives.bgp_devastating_sweep") targets.extend(s.getSweepTiles(c.Actor, t));
    local value = 0.0;
    foreach (tile in targets) {
        if (!tile.IsOccupiedByActor || tile.getEntity().isAlliedWith(c.Actor)) continue;
        value += A.weaponChance(s, tile) * (2.8 + ::Math.minf(1.0, tile.getEntity().getArmor(::Const.BodyPart.Body) / 160.0));
    }
    return value;
}
A.add("bgp_devastating_blow", "Enemies", devastating);
A.add("bgp_devastating_sweep", "Enemies", devastating);

// Tactical ranged assessment, hold-line gating, and shieldbearer vanguard helpers for Autopilot.
local F = A.Frontline <- {
    State = null,
    EnemyCasterSkills = [
        "actives.raise_undead", "actives.horror", "actives.miasma",
        "actives.insect_swarm", "actives.root", "actives.hex", "actives.sleep"
    ],

    function resetState()
    {
        this.State = {
            Round = -1,
            LastMinDist = 99,
            StallRounds = 0,
            LastOffenseRound = 0,
            StallBroken = false,
            MeleeJoined = false
        };
    },

    function battleState()
    {
        local round = ::Time.getRound();
        if (this.State == null || round < this.State.Round || (round == 1 && this.State.Round > 1))
            this.resetState();
        return this.State;
    },

    function navSettings( _entity, _navigator )
    {
        local s = _navigator.createSettings();
        s.ActionPointCosts = _entity.getActionPointCosts();
        s.FatigueCosts = _entity.getFatigueCosts();
        s.FatigueCostFactor = 1.0;
        s.ActionPointCostPerLevel = _entity.getLevelActionPointCost();
        s.FatigueCostPerLevel = _entity.getLevelFatigueCost();
        s.MaxLevelDifference = _entity.getMaxTraversibleLevels();
        s.AllowZoneOfControlPassing = false;
        s.ZoneOfControlCost = ::Const.AI.Behavior.ZoneOfControlAPPenalty;
        s.AlliedFactions = _entity.getAlliedFactions();
        s.Faction = _entity.getFaction();
        return s;
    },

    function isRangedRole( _actor )
    {
        if ("_autopilot" in _actor.m && _actor.m._autopilot.ranged && !_actor.m._autopilot.throwing)
            return true;
        return _actor.isArmedWithRangedWeapon() && !("_autopilot" in _actor.m && _actor.m._autopilot.throwing);
    },

    function isCasterRole( _actor )
    {
        local skills = _actor.getSkills();
        return skills.hasSkill("actives.bgp_necro_raise") || skills.hasSkill("actives.raise_undead")
            || skills.hasSkill("actives.pale_summon_zombie") || skills.hasSkill("actives.pale_summon_skeleton");
    },

    function hasUsableRangedAmmo( _actor, _weapon )
    {
        if (_weapon == null)
            return false;
        local maxAmmo = 0;
        local curAmmo = 0;
        try { maxAmmo = _weapon.getAmmoMax(); curAmmo = _weapon.getAmmo(); } catch (e) { maxAmmo = 0; curAmmo = 0; }
        if (maxAmmo <= 0 || curAmmo > 0)
            return true;
        // Bow/crossbow uses separate ammo slot; check ammo slot & backpack quivers.
        local ammoItem = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Ammo);
        if (ammoItem != null)
        {
            local a = 0;
            try { a = ammoItem.getAmmo(); } catch (e) { a = 0; }
            if (a > 0)
                return true;
        }
        return false;
    },

    function unitRangedScore( _actor, _isEnemy )
    {
        if (::MSU.isNull(_actor) || !_actor.isAlive() || _actor.isDying() || !_actor.isPlacedOnMap())
            return 0.0;
        if (_actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            return 0.0;
        local skills = _actor.getSkills();
        if (_isEnemy)
        {
            foreach (sid in this.EnemyCasterSkills)
            {
                if (skills.hasSkill(sid))
                    return 2.5;
            }
        }
        local score = 0.0;
        if (_actor.isArmedWithRangedWeapon())
        {
            local weapon = _actor.getMainhandItem();
            if (weapon != null && this.hasUsableRangedAmmo(_actor, weapon))
            {
                local isThrowing = weapon.isItemType(::Const.Items.ItemType.Ammo) || weapon.getRangeMax() <= 4;
                if (isThrowing)
                    score = 0.9;
                else
                {
                    score = 2.0;
                    if (_actor.getCurrentProperties().getRangedSkill() >= 65)
                        score += 0.5;
                }
            }
        }
        if (!_isEnemy && score < 1.0)
        {
            // Only true ranged spells count; pale_corpse_shot is shared by all Scourge melee bros and must not inflate ranged score.
            if (skills.hasSkill("actives.pale_weaken") || skills.hasSkill("actives.pale_arrow_rain"))
                score = 1.0;
        }
        return score;
    },

    function collectEnemies( _actor, _agent )
    {
        local seen = {};
        local enemies = [];
        local all = ::Tactical.Entities.getAllInstances();
        foreach (factionIdx, list in all)
        {
            if (list.len() == 0 || factionIdx == _actor.getFaction() || _actor.isAlliedWith(factionIdx))
                continue;
            foreach (e in list)
            {
                if (::MSU.isNull(e) || !e.isAlive() || e.isDying() || !e.isPlacedOnMap() || !e.isAttackable())
                    continue;
                if (e.isHiddenToPlayer() || !e.getTile().IsVisibleForPlayer)
                    continue;
                local id = e.getID();
                if (!(id in seen))
                {
                    seen[id] <- true;
                    enemies.push(e);
                }
            }
        }
        if (_agent != null)
        {
            foreach (entry in _agent.getKnownOpponents())
            {
                local e = entry.Actor;
                if (::MSU.isNull(e) || !e.isAlive() || e.isDying() || !e.isPlacedOnMap() || !e.isAttackable())
                    continue;
                if (e.isAlliedWith(_actor) || e.isHiddenToPlayer() || !e.getTile().IsVisibleForPlayer)
                    continue;
                local id = e.getID();
                if (!(id in seen))
                {
                    seen[id] <- true;
                    enemies.push(e);
                }
            }
        }
        return enemies;
    },

    function assessBattle( _actor, _agent )
    {
        local state = this.battleState();
        local enemies = this.collectEnemies(_actor, _agent);
        local brothers = [];
        local allAllies = [];
        local all = ::Tactical.Entities.getAllInstances();
        foreach (factionIdx, list in all)
        {
            if (list.len() == 0 || (factionIdx != _actor.getFaction() && !_actor.isAlliedWith(factionIdx)))
                continue;
            foreach (ally in list)
            {
                if (::MSU.isNull(ally) || !ally.isAlive() || ally.isDying() || !ally.isPlacedOnMap())
                    continue;
                allAllies.push(ally);
                if (factionIdx == ::Const.Faction.Player)
                    brothers.push(ally);
            }
        }

        local playerRanged = 0.0;
        foreach (ally in allAllies)
            playerRanged += this.unitRangedScore(ally, false);

        local enemyRanged = 0.0;
        local enemyProjectileRanged = 0.0;
        foreach (foe in enemies)
        {
            local rs = this.unitRangedScore(foe, true);
            enemyRanged += rs;
            if (foe.isArmedWithRangedWeapon())
                enemyProjectileRanged += rs;
        }

        local frontlineMinDist = 99;
        local engagedBrothers = 0;
        local activeEnemies = 0;
        local enemyChargers = 0;
        local enemyUrgentCasters = 0;
        foreach (foe in enemies)
        {
            if (foe.getMoraleState() != ::Const.MoraleState.Fleeing)
            {
                ++activeEnemies;
                local fs = foe.getSkills();
                if (fs.hasSkill("actives.charge"))
                    ++enemyChargers;
                if (fs.hasSkill("actives.raise_undead") || fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma"))
                    ++enemyUrgentCasters;
            }
        }
        foreach (bro in brothers)
        {
            local bt = bro.getTile();
            if (bt.getZoneOfControlCountOtherThan(bro.getAlliedFactions()) > 0)
                ++engagedBrothers;
            foreach (foe in enemies)
            {
                if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                    continue;
                local d = bt.getDistanceTo(foe.getTile());
                if (d < frontlineMinDist)
                    frontlineMinDist = d;
            }
        }

        // Hold-line is an early-battle opener only: once real melee has joined or enemies are routing,
        // never re-enter hold mode so brothers aggressively finish routing foes and backline casters.
        local round = ::Time.getRound();
        if (engagedBrothers >= 2 || (engagedBrothers >= 1 && round >= 2)
            || ::Tactical.Entities.isEnemyRetreating()
            || (enemies.len() > 0 && activeEnemies == 0))
        {
            state.MeleeJoined = true;
        }

        // Stall-breaker: if enemies refuse to close distance for 2 consecutive rounds and we dealt no damage, break hold.
        if (round > state.Round)
        {
            if (state.Round >= 1 && !state.MeleeJoined && activeEnemies > 0 && engagedBrothers == 0 && frontlineMinDist > 2)
            {
                if (frontlineMinDist >= state.LastMinDist && state.LastOffenseRound < round - 1)
                    ++state.StallRounds;
                else
                    state.StallRounds = 0;
                if (state.StallRounds >= 2)
                    state.StallBroken = true;
            }
            else if (engagedBrothers > 0 || frontlineMinDist <= 2)
            {
                state.StallRounds = 0;
            }
            state.LastMinDist = frontlineMinDist;
            state.Round = round;
        }

        local rangedAdvantage = enemyRanged <= 0.01 || enemyRanged < playerRanged;
        // Never passively wait in HoldLine against Orc Charger packs (>= 3) or past Round 1 against Enemy Necromancers / Ancient Priests (press in to stop infinite Raise/Miasma/Horror!).
        local casterPush = enemyUrgentCasters > 0 && round >= 2;
        local holdLine = rangedAdvantage && enemyChargers < 3 && !casterPush && !state.StallBroken && !state.MeleeJoined && activeEnemies > 0;

        return {
            Enemies = enemies,
            Brothers = brothers,
            PlayerRanged = playerRanged,
            EnemyRanged = enemyRanged,
            EnemyProjectileRanged = enemyProjectileRanged,
            EnemyChargers = enemyChargers,
            FrontlineMinDist = frontlineMinDist,
            EngagedBrothers = engagedBrothers,
            RangedAdvantage = rangedAdvantage,
            HoldLine = holdLine
        };
    },

    function nearestActiveEnemyDist( _actor, _enemies )
    {
        local origin = _actor.getTile();
        local best = 99;
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing || foe.getCurrentProperties().IsStunned)
                continue;
            local d = origin.getDistanceTo(foe.getTile());
            if (d < best)
                best = d;
        }
        return best;
    },

    function cheapestMeleeSkill( _actor )
    {
        local best = null;
        foreach (s in _actor.getSkills().m.Skills)
        {
            if (s == null || !s.m.IsActive || !s.m.IsAttack || !s.m.IsTargeted || s.m.IsRanged)
                continue;
            if (!s.m.IsWeaponSkill && s.getID() != "actives.hand_to_hand")
                continue;
            if (s.isHidden() || !s.isUsable() || !s.isAffordable())
                continue;
            if (best == null || s.getActionPointCost() < best.getActionPointCost()
                || (s.getActionPointCost() == best.getActionPointCost() && s.getFatigueCost() < best.getFatigueCost()))
                best = s;
        }
        return best;
    },

    function hasAdjacentTarget( _actor, _skill, _enemies )
    {
        local origin = _actor.getTile();
        foreach (foe in _enemies)
        {
            local ft = foe.getTile();
            if (origin.getDistanceTo(ft) <= _skill.getMaxRange() && _skill.isUsableOn(ft, origin))
                return true;
        }
        return false;
    },

    function isDangerousMeleeEnemy( _foe )
    {
        if (::MSU.isNull(_foe) || !_foe.isAlive() || _foe.isDying())
            return false;
        if (_foe.getMoraleState() == ::Const.MoraleState.Fleeing || _foe.getCurrentProperties().IsStunned)
            return false;
        // Pure ranged archers and enemy casters do not warrant wasting AP/fatigue on Shieldwall when we can kill them.
        if (_foe.isArmedWithRangedWeapon())
        {
            local w = _foe.getMainhandItem();
            if (w != null && !w.isItemType(::Const.Items.ItemType.Ammo))
                return false;
        }
        local tSkills = _foe.getSkills();
        if (tSkills.hasSkill("actives.raise_undead") || tSkills.hasSkill("actives.root") || tSkills.hasSkill("actives.hex"))
            return false;
        return true;
    },

    function countDangerousMeleeAdjacent( _actor, _enemies )
    {
        local origin = _actor.getTile();
        local n = 0;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe))
                continue;
            local ft = foe.getTile();
            if (origin.getDistanceTo(ft) == 1 && ::Math.abs(origin.Level - ft.Level) <= 1)
                ++n;
        }
        return n;
    },

    function countDangerousMeleeWithin( _actor, _enemies, _range )
    {
        local origin = _actor.getTile();
        local n = 0;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe))
                continue;
            if (origin.getDistanceTo(foe.getTile()) <= _range)
                ++n;
        }
        return n;
    },

    function nearestDangerousMeleeDist( _actor, _enemies )
    {
        local origin = _actor.getTile();
        local best = 99;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe))
                continue;
            local d = origin.getDistanceTo(foe.getTile());
            if (d < best)
                best = d;
        }
        return best;
    },

    // Fatigue-disciplined tank rule: a shieldbearer only spends fatigue attacking before Shieldwall when
    // (1) an adjacent enemy can be finished off this hit (expectedHP >= HP and hit >= 50%), or
    // (2) 1v1 melee with >= 60% hit and >= 30 fatigue left after Attack + Shieldwall, or
    // (3) <= 2 enemies with >= 70% hit and >= 20 fatigue left after Attack + Shieldwall.
    function shouldShieldbearerAttackFirst( _actor, _sw, _enemies, _zone )
    {
        if (_zone < 1 || _actor.getHitpointsPct() < 0.48)
            return false;
        local atk = this.cheapestMeleeSkill(_actor);
        if (atk == null)
            return false;
        local apLeft = _actor.getActionPoints() - atk.getActionPointCost() - _sw.getActionPointCost();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local fatLeft = availFat - atk.getFatigueCost() - _sw.getFatigueCost();
        if (apLeft < 0 || fatLeft < 0)
            return false;

        local origin = _actor.getTile();
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                continue;
            local ft = foe.getTile();
            if (origin.getDistanceTo(ft) > atk.getMaxRange() || !atk.isUsableOn(ft, origin))
                continue;
            local hit = 0;
            local expectedHP = 0.0;
            try {
                hit = atk.getHitchance(foe);
                local dmg = atk.getExpectedDamage(foe);
                expectedHP = dmg.HitpointDamage + dmg.DirectDamage;
            } catch (e) {}

            // Case 1: Lethal finish on wounded enemy (generates a corpse for Mentor immediately!).
            if (expectedHP >= foe.getHitpoints() && hit >= 40)
                return true;
            // Case 2: Good hit chance with healthy fatigue buffer (never into Riposte; tighter buffer for heavy Sipar tanks).
            if (!foe.getSkills().hasSkill("effects.riposte"))
            {
                if (_zone == 1 && hit >= 60 && fatLeft >= 22)
                    return true;
                if (_zone <= 2 && hit >= 68 && fatLeft >= 18)
                    return true;
            }
        }
        return false;
    },

    function findSameTurnStrikePlan( _actor, _enemies )
    {
        local skill = this.cheapestMeleeSkill(_actor);
        if (skill == null)
            return null;
        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local atkAP = skill.getActionPointCost();
        local atkFat = skill.getFatigueCost();
        local minRange = skill.getMinRange();
        local maxRange = skill.getMaxRange();
        local moveAPBudget = ap - atkAP;

        // Already in strike range without moving.
        foreach (foe in _enemies)
        {
            if (skill.isUsableOn(foe.getTile(), myTile))
                return { Tile = myTile, Enemy = foe, Skill = skill };
        }
        if (moveAPBudget < 2 || _actor.getCurrentProperties().IsRooted)
            return null;

        local maxSteps = ::Math.max(1, (moveAPBudget / 2).tointeger()) + 1;
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local bestPlan = null;
        local bestScore = -9999.0;

        foreach (foe in _enemies)
        {
            local ft = foe.getTile();
            if (myTile.getDistanceTo(ft) > maxRange + maxSteps)
                continue;
            local ring = this.tilesInRange(ft, minRange, maxRange);
            foreach (dest in ring)
            {
                if (!dest.IsEmpty || dest.ID == myTile.ID)
                    continue;
                // Avoid stepping into ZoC for 2-tile weapons.
                if (maxRange >= 2 && dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
                    continue;
                if (!skill.isUsableOn(ft, dest))
                    continue;
                if (!navigator.findPath(myTile, dest, settings, 0))
                    continue;
                local cost = navigator.getCostForPath(_actor, settings, ap, availFat);
                if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID)
                    continue;
                if (ap - cost.ActionPointsRequired < atkAP || availFat - cost.FatigueRequired < atkFat)
                    continue;
                local score = 10.0 + (dest.Level - ft.Level) * 2.0 - cost.ActionPointsRequired * 0.35
                    - (dest.IsBadTerrain ? 1.5 : 0.0) - (dest.Properties.Effect != null && dest.Properties.Effect.IsPositive == false ? 6.0 : 0.0);
                if (score > bestScore)
                {
                    bestScore = score;
                    bestPlan = { Tile = dest, Enemy = foe, Skill = skill };
                }
            }
        }
        return bestPlan;
    },

    function tilesInRange( _center, _minRange, _maxRange )
    {
        local visited = {};
        visited[_center.ID] <- 0;
        local queue = [_center];
        local out = [];
        for (local i = 0; i < queue.len(); ++i)
        {
            local cur = queue[i];
            local d = visited[cur.ID];
            if (d >= _minRange)
                out.push(cur);
            if (d >= _maxRange)
                continue;
            for (local dir = 0; dir < 6; ++dir)
            {
                if (!cur.hasNextTile(dir))
                    continue;
                local nxt = cur.getNextTile(dir);
                if (!(nxt.ID in visited))
                {
                    visited[nxt.ID] <- d + 1;
                    queue.push(nxt);
                }
            }
        }
        return out;
    },

    function shouldActorHold( _actor, _agent )
    {
        local info = this.assessBattle(_actor, _agent);
        if (!info.HoldLine)
            return { Hold = false, Info = info, StrikePlan = null };
        if (_actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return { Hold = false, Info = info, StrikePlan = null };
        if (info.EngagedBrothers > 0 || info.FrontlineMinDist <= 2)
            return { Hold = false, Info = info, StrikePlan = null };
        if (!::BGP.hasShield(_actor) && !this.isRangedRole(_actor) && !this.isCasterRole(_actor))
        {
            local plan = this.findSameTurnStrikePlan(_actor, info.Enemies);
            if (plan != null)
                return { Hold = false, Info = info, StrikePlan = plan };
        }
        return { Hold = true, Info = info, StrikePlan = null };
    },

    function hasUnactedShieldAlly( _actor, _info )
    {
        // Yield phase 1 during the opening clash (Rounds 1-2 while <= 1 bro engaged) so shieldbearers anchor first
        // instead of unshielded flank 2H/1H brothers (e.g. Greatsword / 1H Mace) diving ahead and getting surrounded.
        if (_info.EngagedBrothers > 1 || (_info.EngagedBrothers > 0 && ::Time.getRound() > 2))
            return false;
        local myTile = _actor.getTile();
        foreach (foe in _info.Enemies)
        {
            if (myTile.getDistanceTo(foe.getTile()) <= 1)
                return false;
        }
        foreach (ally in _info.Brothers)
        {
            if (ally.getID() == _actor.getID())
                continue;
            if (!::BGP.hasShield(ally) || ally.isTurnDone() || ally.getActionPoints() < 4)
                continue;
            if (ally.getMoraleState() == ::Const.MoraleState.Fleeing || ally.getCurrentProperties().IsStunned
                || ally.getCurrentProperties().IsRooted)
                continue;
            if (ally.getTile().getDistanceTo(myTile) > 4)
                continue;
            if (ally.getTile().getZoneOfControlCountOtherThan(ally.getAlliedFactions()) == 0)
                return true;
        }
        return false;
    },

    function findShieldInterceptTile( _behavior, _actor, _info )
    {
        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local sw = _actor.getSkills().getSkillByID("actives.shieldwall");
        local reserveAP = (sw != null && !sw.isHidden() && sw.isUsable()) ? sw.getActionPointCost() : 0;
        local reserveFat = (sw != null && !sw.isHidden() && sw.isUsable()) ? sw.getFatigueCost() : 0;
        local moveAPBudget = ap - reserveAP;
        if (moveAPBudget < 2)
            return null;

        // Limit vanguard step radius to at most 2 tiles so shieldbearers never dive solo out of formation.
        local maxSteps = ::Math.min(2, ::Math.max(1, (moveAPBudget / 2).tointeger()));
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);

        // Identify fragile allies we want to screen.
        local squishies = [];
        foreach (bro in _info.Brothers)
        {
            if (bro.getID() != _actor.getID() && (!::BGP.hasShield(bro) || this.isRangedRole(bro) || this.isCasterRole(bro)))
                squishies.push(bro.getTile());
        }

        local seen = {};
        local bestTile = null;
        local bestScore = 0.0;

        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                continue;
            local ft = foe.getTile();
            if (myTile.getDistanceTo(ft) > maxSteps + 1)
                continue;
            for (local dir = 0; dir < 6; ++dir)
            {
                if (!ft.hasNextTile(dir))
                    continue;
                local dest = ft.getNextTile(dir);
                if (!dest.IsEmpty || dest.ID == myTile.ID || (dest.ID in seen))
                    continue;
                seen[dest.ID] <- true;
                if (::Math.abs(dest.Level - ft.Level) > 1)
                    continue;
                if (_behavior.hasNegativeTileEffect(dest, _actor))
                    continue;
                if (!navigator.findPath(myTile, dest, settings, 0))
                    continue;
                local cost = navigator.getCostForPath(_actor, settings, ap, availFat);
                if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.Tiles > 2)
                    continue;
                if (ap - cost.ActionPointsRequired < reserveAP)
                    continue;
                if (reserveFat > 0 && availFat - cost.FatigueRequired < reserveFat)
                    continue;

                // Evaluate enemy exposure vs allied line cohesion (Shieldwall adjacency & anti-surround).
                local adjEnemies = 0;
                local unengagedEnemies = 0;
                local adjAllies = 0;
                local adjShieldAllies = 0;
                for (local d2 = 0; d2 < 6; ++d2)
                {
                    if (!dest.hasNextTile(d2))
                        continue;
                    local adj = dest.getNextTile(d2);
                    if (!adj.IsOccupiedByActor || ::Math.abs(adj.Level - dest.Level) > 1)
                        continue;
                    local occ = adj.getEntity();
                    if (occ.getID() == _actor.getID() || !occ.isAlive())
                        continue;
                    if (!occ.isAlliedWith(_actor) && occ.getMoraleState() != ::Const.MoraleState.Fleeing)
                    {
                        ++adjEnemies;
                        if (adj.getZoneOfControlCountOtherThan(occ.getAlliedFactions()) == 0)
                            ++unengagedEnemies;
                    }
                    else if (occ.isAlliedWith(_actor))
                    {
                        ++adjAllies;
                        if (::BGP.hasShield(occ))
                            ++adjShieldAllies;
                    }
                }

                // Never dive solo into 3+ enemies with zero adjacent allies.
                if (adjEnemies >= 3 && adjAllies == 0)
                    continue;

                local score = 8.0 + ::Math.min(2, unengagedEnemies) * 5.0;
                // Reward staying connected to the allied line and adjacent to fellow shieldbearers!
                score += ::Math.min(2, adjAllies) * 4.5 + ::Math.min(2, adjShieldAllies) * 3.5;
                // Penalize taking 3+ enemies at once (heavy surround penalty).
                if (adjEnemies >= 3)
                    score -= (adjEnemies - 2) * 7.0;
                foreach (sq in squishies)
                {
                    local sqDist = sq.getDistanceTo(ft);
                    if (dest.getDistanceTo(sq) <= 2 && dest.getDistanceTo(ft) < sqDist)
                    {
                        score += 3.5;
                        break;
                    }
                }
                score += (dest.Level - ft.Level) * 2.5 - cost.ActionPointsRequired * 0.6 - (dest.IsBadTerrain ? 2.0 : 0.0);
                if (score > bestScore)
                {
                    bestScore = score;
                    bestTile = dest;
                }
            }
        }
        return bestTile;
    },

    function shouldSuppressEngageMelee( _actor, _agent )
    {
        if (!::Autopilot.isUnderAIControl(_actor) || !::Autopilot.conf("bgpSmartFrontline"))
            return false;
        if (::Tactical.State.isAutoRetreat() || _actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            return false;
        // Never walk away and cancel an active Shieldwall or Spearwall raised this turn.
        if (_actor.getSkills().hasSkill("effects.shieldwall") || _actor.getSkills().hasSkill("effects.spearwall"))
            return true;
        local decision = this.shouldActorHold(_actor, _agent);
        if (decision.Hold)
            return true;
        if (!::BGP.hasShield(_actor) && !this.isRangedRole(_actor) && !this.isCasterRole(_actor)
            && ::Tactical.TurnSequenceBar.canEntityWait(_actor)
            && _actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) == 0
            && this.hasUnactedShieldAlly(_actor, decision.Info))
            return true;
        return false;
    },

    function shouldSuppressEngageRanged( _actor, _agent, _targetTile )
    {
        if (_targetTile == null || !::Autopilot.isUnderAIControl(_actor) || !::Autopilot.conf("bgpSmartFrontline"))
            return false;
        if (::Tactical.State.isAutoRetreat() || _actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            return false;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return false;
        local decision = this.shouldActorHold(_actor, _agent);
        if (decision.Info.Enemies.len() == 0)
            return false;
        // Never allow Mentor (caster) to walk forward into enemy archer sniper range (<= 7) or into unengaged melee range (<= 2)!
        if (this.isCasterRole(_actor))
        {
            local curArch = this.nearestEnemyArcherDist(myTile, decision.Info.Enemies);
            local newArch = this.nearestEnemyArcherDist(_targetTile, decision.Info.Enemies);
            if (decision.Info.EnemyProjectileRanged >= 3.0 && newArch <= 7 && newArch < curArch)
                return true;
            local newMelee = 99;
            foreach (foe in decision.Info.Enemies)
                if (this.isLiveBacklineThreat(foe))
                    newMelee = ::Math.min(newMelee, _targetTile.getDistanceTo(foe.getTile()));
            if (newMelee <= 2)
                return true;
        }
        if (!decision.Hold)
            return false;
        // Suppress forward advance while holding; allow retreating or holding tile.
        local curDist = 99;
        local newDist = 99;
        foreach (foe in decision.Info.Enemies)
        {
            local ft = foe.getTile();
            curDist = ::Math.min(curDist, myTile.getDistanceTo(ft));
            newDist = ::Math.min(newDist, _targetTile.getDistanceTo(ft));
        }
        return newDist < curDist;
    },

    // Focus-fire, lethal execution, weapon-matched ranged targeting, backline-breach peel, and riposte/shieldwall avoidance.
    function scoreFocusTarget( _score, _actor, _target, _skill )
    {
        if (_score <= 0.0 || _skill == null || !_skill.isAttack() || _actor == null || _target == null)
            return _score;
        if (::MSU.isNull(_actor) || ::MSU.isNull(_target) || _target.isAlliedWith(_actor))
            return _score;
        if (!::Autopilot.isUnderAIControl(_actor) || !::Autopilot.conf("bgpSmartFrontline"))
            return _score;

        local mult = 1.0;
        local hit = 50;
        local expectedHP = 0.0;
        try {
            hit = _skill.getHitchance(_target);
            local dmg = _skill.getExpectedDamage(_target);
            expectedHP = dmg.HitpointDamage + dmg.DirectDamage;
        } catch (e) {}

        local hp = _target.getHitpoints();
        local hpPct = _target.getHitpointsPct();
        local fleeing = _target.getMoraleState() == ::Const.MoraleState.Fleeing;
        local bodyArmor = _target.getArmor(::Const.BodyPart.Body);
        local isLethal = !fleeing && expectedHP >= hp && hit >= 40;

        // 1. Strongly prioritize guaranteed / likely kills on active enemies (extra weight for Berserk chaining).
        if (isLethal)
        {
            mult *= 1.60 + 0.40 * ::Math.minf(1.0, (hit - 35) / 45.0);
            if (_actor.getSkills().hasSkill("perk.berserk"))
                mult *= 1.15;
        }
        else if (!fleeing && hpPct <= 0.45)
            mult *= 1.0 + (0.50 - hpPct) * 1.15;

        // 2. Focus armor-stripped enemies so follow-ups finish them rapidly.
        if (!fleeing && _target.getArmorMax(::Const.BodyPart.Body) > 30 && bodyArmor <= 10)
            mult *= 1.20;

        // 3. Priority targets: hostile casters, Orc Berserkers, archers/crossbowmen, bannermen/drummers/officers, and heavy 2H elites.
        local tSkills = _target.getSkills();
        if (!fleeing)
        {
            local isPriestOrNecro = tSkills.hasSkill("actives.raise_undead") || tSkills.hasSkill("actives.horror") || tSkills.hasSkill("actives.miasma");
            local isCaster = isPriestOrNecro;
            if (!isCaster)
            {
                foreach (sid in this.EnemyCasterSkills)
                {
                    if (tSkills.hasSkill(sid)) { isCaster = true; break; }
                }
            }
            // Reforged Noble Squire rule: avoid killing RF_Squire while an enemy Knight is alive (killing Squire buffs the Knight!).
            local isSquireWithLiveKnight = false;
            try {
                if (_target.ClassName == "rf_squire") {
                    foreach (fi, list in ::Tactical.Entities.getAllInstances()) {
                        if (fi == ::Const.Faction.Player || fi == ::Const.Faction.PlayerAnimals) continue;
                        foreach (e in list) {
                            if (e != null && !::MSU.isNull(e) && e.isAlive() && !e.isDying()
                                && (e.ClassName == "knight" || e.ClassName == "rf_knight_anointed")) {
                                isSquireWithLiveKnight = true; break;
                            }
                        }
                        if (isSquireWithLiveKnight) break;
                    }
                }
            } catch (e) {}

            local isGhostOrBanshee = _target.ClassName == "ghost" || _target.ClassName == "rf_banshee" || tSkills.hasSkill("actives.ghastly_touch");
            if (isSquireWithLiveKnight)
                mult *= 0.42;
            else if (isPriestOrNecro)
                mult *= _skill.isRanged() ? 2.30 : 1.75;
            else if (isGhostOrBanshee)
                mult *= _skill.isRanged() ? 1.50 : 1.75;
            else if (isCaster)
                mult *= _skill.isRanged() ? 1.70 : 1.50;
            else if (tSkills.hasSkill("effects.berserker_rage") || _target.ClassName == "orc_berserker")
                // Delete unarmored high-burst Orc Berserkers BEFORE Rage ramps up and one-shots frontliners!
                mult *= _skill.isRanged() ? 1.70 : 1.55;
            else if (_target.ClassName == "desert_stalker")
                mult *= _skill.isRanged() ? 1.70 : 1.55;
            else if (_target.isArmedWithRangedWeapon())
                mult *= _skill.isRanged() ? 1.45 : 1.30;
            else if (tSkills.hasSkill("actives.rally_the_troops") || tSkills.hasSkill("actives.barbarian_drum")
                || tSkills.hasSkill("actives.warcry") || _target.ClassName == "rf_skeleton_legatus"
                || _target.ClassName == "rf_skeleton_centurion" || _target.ClassName == "rf_skeleton_decanus"
                || _target.ClassName == "rf_marshal")
                mult *= 1.50;
            else if (_target.ClassName == "executioner")
                mult *= 1.45;
            else
            {
                local w = _target.getMainhandItem();
                if (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon))
                    mult *= _target.isArmedWithShield() ? 1.22 : 1.34;
            }

            // Against Ancient Dead: deprioritize shielded high-armor skeletons for ranged weapons and prioritize unshielded 2-tile Ancient Polearms!
            if (_target.getFlags().has("skeleton") && !isPriestOrNecro)
            {
                if (!_target.isArmedWithShield() && _target.getIdealRange() >= 2)
                {
                    mult *= 1.38;
                }
                else if (_skill.isRanged() && bodyArmor >= 90)
                {
                    local weapon = _actor.getMainhandItem();
                    local isBow = weapon != null && weapon.isWeaponType(::Const.Items.WeaponType.Bow);
                    if (isBow)
                        mult *= 0.38;
                    else if (_target.isArmedWithShield())
                        mult *= 0.55;
                }
            }

            // 3b. Backline breach protection: prioritize any enemy within 2 tiles of our Mentor or archers!
            local targetTile = _target.getTile();
            local brothers = ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
            foreach (bro in brothers)
            {
                if (::MSU.isNull(bro) || !bro.isAlive() || !bro.isPlacedOnMap()) continue;
                if (this.isCasterRole(bro) || this.isRangedRole(bro))
                {
                    if (targetTile.getDistanceTo(bro.getTile()) <= 2)
                    {
                        mult *= 1.45;
                        break;
                    }
                }
            }
        }

        // 4. Ranged weapon specialization: reward clean open shots, bows shred light armor, delete squishy 1-2 shot killers, avoid heavy shieldwall tanks.
        if (_skill.isRanged() && !isLethal)
        {
            if (_target.getTile().getZoneOfControlCountOtherThan(_target.getAlliedFactions()) == 0)
                mult *= 1.24;
            local weapon = _actor.getMainhandItem();
            local isBow = weapon != null && weapon.isWeaponType(::Const.Items.WeaponType.Bow);
            if (tSkills.hasSkill("effects.shieldwall"))
                mult *= 0.48;
            if (isBow)
            {
                if (bodyArmor <= 90)
                    mult *= 1.35;
                else if (bodyArmor >= 170)
                    mult *= 0.48;
            }
            else if (bodyArmor >= 220 && _target.isArmedWithShield())
            {
                mult *= 0.65;
            }
            // Extra ranged snipe priority on light-armor high-damage chargers/berserkers & 2-shot kills (Goblins, Berserkers, Arbalesters, Shamans).
            if (bodyArmor <= 80 && !fleeing)
            {
                if (_target.getHitpointsMax() >= 120 || tSkills.hasSkill("actives.charge") || tSkills.hasSkill("actives.werewolf_bite"))
                    mult *= 1.32;
                if (expectedHP > 0.0 && hp <= expectedHP * 1.55 && hit >= 45)
                    mult *= 1.32;
            }
        }

        // 5. Avoid feeding free Riposte counterattacks or wasting melee swings on Shieldwall / ultra-heavy shielded tanks; boost Knock Out stuns on heavy threats.
        if (!_skill.isRanged() && !isLethal)
        {
            if (tSkills.hasSkill("effects.riposte"))
                mult *= 0.48;
            if (tSkills.hasSkill("effects.shieldwall") && _skill.getID() != "actives.split_shield" && hit < 65)
                mult *= 0.52;
            // Deprioritize ultra-heavy armored shield tanks for normal blades/spears, EXCEPT armor-shredding Hammers (smite/shatter/rf_pummel) which LOVE heavy armor!
            local sid = _skill.getID();
            local isArmorBreaker = sid == "actives.split_shield" || sid == "actives.destroy_armor" || sid == "actives.crush_armor"
                || sid == "actives.smite" || sid == "actives.shatter" || sid == "actives.rf_pummel";
            if (isArmorBreaker && bodyArmor >= 140)
                mult *= 1.22;
            else if (bodyArmor >= 200 && _target.isArmedWithShield() && !isArmorBreaker)
                mult *= 0.72;
            if (_skill.getID() == "actives.knock_out")
            {
                if (!fleeing && !_target.getCurrentProperties().IsImmuneToStun && !_target.getCurrentProperties().IsStunned)
                {
                    local w = _target.getMainhandItem();
                    local heavy = (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded))
                        || _target.getHitpointsMax() >= 110 || tSkills.hasSkill("racial.champion");
                    mult *= heavy ? 1.45 : 1.0;
                }
                else
                {
                    mult *= 0.45;
                }
            }
        }

        return _score * mult;
    },

    function isHeavyMeleeThreat( _foe )
    {
        if (!this.isDangerousMeleeEnemy(_foe))
            return false;
        local w = _foe.getMainhandItem();
        if (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon))
            return true;
        local skills = _foe.getSkills();
        if (skills.hasSkill("actives.charge") || skills.hasSkill("actives.line_breaker")
            || skills.hasSkill("racial.champion") || skills.hasSkill("actives.warcry"))
            return true;
        return _foe.getHitpointsMax() >= 140;
    },

    function hasHeavyMeleeAdjacent( _actor, _enemies )
    {
        local origin = _actor.getTile();
        foreach (foe in _enemies)
        {
            if (!this.isHeavyMeleeThreat(foe))
                continue;
            local ft = foe.getTile();
            if (origin.getDistanceTo(ft) == 1 && ::Math.abs(origin.Level - ft.Level) <= 1)
                return true;
        }
        return false;
    },

    // Detect imminent Orc Charge / Warrior Push (distance 2-3 unengaged) so frontliners can pre-cast Indomitable for Stun/Push immunity!
    function hasIncomingChargerWithin( _actor, _enemies, _maxDist )
    {
        local origin = _actor.getTile();
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe))
                continue;
            local ft = foe.getTile();
            local d = origin.getDistanceTo(ft);
            if (d < 2 || d > _maxDist)
                continue;
            if (ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0)
                continue;
            local skills = foe.getSkills();
            if (skills.hasSkill("actives.charge") || skills.hasSkill("actives.line_breaker"))
                return true;
        }
        return false;
    },

    // Find the best 1H melee weapon stashed in the backpack for a ranged brother caught in enemy ZoC.
    function findBestBagMeleeWeapon( _actor )
    {
        local bag = _actor.getItems().getAllItemsAtSlot(::Const.ItemSlot.Bag);
        local best = null;
        local bestVal = -1;
        foreach (item in bag)
        {
            if (item == null || !item.isItemType(::Const.Items.ItemType.MeleeWeapon))
                continue;
            local v = item.getValue();
            if (v > bestVal)
            {
                bestVal = v;
                best = item;
            }
        }
        return best;
    },

    // Count unengaged dangerous melee enemies at distance 2 (about to step in and surround our Shieldbearer).
    function countUnengagedMeleeAtDist2( _actor, _enemies )
    {
        local origin = _actor.getTile();
        local n = 0;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe))
                continue;
            local ft = foe.getTile();
            if (origin.getDistanceTo(ft) == 2 && ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0)
                ++n;
        }
        return n;
    },

    // Check if an enemy can genuinely reach/strike our backliner from <= 2 tiles (either UNENGAGED, or polearm/2-tile weapon, or Wolfrider/Footwork).
    function isLiveBacklineThreat( _foe )
    {
        if (!this.isDangerousMeleeEnemy(_foe))
            return false;
        local ft = _foe.getTile();
        if (ft.getZoneOfControlCountOtherThan(_foe.getAlliedFactions()) == 0)
            return true;
        if (_foe.getIdealRange() >= 2)
            return true;
        local s = _foe.getSkills();
        return s.hasSkill("actives.footwork") || s.hasSkill("actives.werewolf_bite");
    },

    function nearestLiveBacklineThreatDist( _actor, _enemies )
    {
        local origin = _actor.getTile();
        local best = 99;
        foreach (foe in _enemies)
        {
            if (!this.isLiveBacklineThreat(foe))
                continue;
            local d = origin.getDistanceTo(foe.getTile());
            if (d < best)
                best = d;
        }
        return best;
    },

    function nearestEnemyArcherDist( _tile, _enemies )
    {
        local best = 99;
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing || !foe.isArmedWithRangedWeapon())
                continue;
            local w = foe.getMainhandItem();
            if (w != null && w.isItemType(::Const.Items.ItemType.Ammo))
                continue;
            local d = _tile.getDistanceTo(foe.getTile());
            if (d < best)
                best = d;
        }
        return best;
    },

    // Check if an ally stands adjacent to _tile in the direction of enemy shooters (provides BB soft ranged cover).
    function hasRangedCoverAt( _tile, _actor, _enemies )
    {
        local nearestArch = null;
        local bestD = 99;
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing || !foe.isArmedWithRangedWeapon())
                continue;
            local d = _tile.getDistanceTo(foe.getTile());
            if (d < bestD) { bestD = d; nearestArch = foe.getTile(); }
        }
        if (nearestArch == null) return true;
        for (local dir = 0; dir < 6; ++dir)
        {
            if (!_tile.hasNextTile(dir)) continue;
            local nt = _tile.getNextTile(dir);
            if (!nt.IsOccupiedByActor) continue;
            local occ = nt.getEntity();
            if (occ.getID() != _actor.getID() && occ.isAlliedWith(_actor) && nt.getDistanceTo(nearestArch) < bestD)
                return true;
        }
        return false;
    },

    // Safe 1-2 tile kiting retreat for Mentor (caster) or Ranged brothers ONLY when:
    // (a) a LIVE backline threat (unengaged melee / polearm / Wolfrider) closes to <= 2 tiles, OR
    // (b) Mentor is exposed to heavy enemy archers (EnemyProjectileRanged >= 3.0) inside range <= 7 without cover!
    // Never panics Bow/Crossbow over enemies already pinned in our frontline ZoC, and keeps AP to shoot!
    function findBacklineSafeTile( _behavior, _actor, _info )
    {
        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local isCaster = this.isCasterRole(_actor);
        if (_actor.getCurrentProperties().IsRooted)
            return null;

        local curMeleeDist = this.nearestLiveBacklineThreatDist(_actor, _info.Enemies);
        local meleeDanger = curMeleeDist <= 2;
        local curArcherDist = isCaster ? this.nearestEnemyArcherDist(myTile, _info.Enemies) : 99;
        local hasCoverNow = isCaster ? this.hasRangedCoverAt(myTile, _actor, _info.Enemies) : true;
        local sniperRange = _info.EnemyProjectileRanged >= 5.0 ? 8 : 7;
        local sniperDanger = isCaster && _info.EnemyProjectileRanged >= 2.0 && curArcherDist <= sniperRange && (!hasCoverNow || curArcherDist <= 6);

        if (!meleeDanger && !sniperDanger)
            return null;

        // Mentor has MaxRange=99 on Raise Dead, so stepping 1-2 tiles out of Ambusher/Arbalester range still lets him raise corpses!
        // Bug fix: when Mentor has leftover 2 AP after Round 1 summons (cannot cast any 3-AP spell anyway), spend that 2 AP to step back into cover!
        // Ranged bros step at most 1 tile (2 AP) when they have >= 6 AP so they STILL fire their bow/crossbow this turn!
        local maxMoveAP = isCaster ? (meleeDanger ? ::Math.min(ap, 4) : (ap >= 7 ? 4 : (ap <= 2 ? ap : ::Math.min(ap - 3, 2))))
                                   : (ap >= 6 ? 2 : 0);
        if (maxMoveAP < 2)
            return null;

        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local candidates = this.tilesInRange(myTile, 1, maxMoveAP >= 4 ? 2 : 1);
        local bestTile = null;
        local bestScore = 0.0;

        foreach (dest in candidates)
        {
            if (!dest.IsEmpty || dest.ID == myTile.ID)
                continue;
            if (dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
                continue;
            if (_behavior.hasNegativeTileEffect(dest, _actor))
                continue;
            if (!navigator.findPath(myTile, dest, settings, 0))
                continue;
            local cost = navigator.getCostForPath(_actor, settings, maxMoveAP, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.ActionPointsRequired > maxMoveAP)
                continue;

            local minMeleeDist = 99;
            foreach (foe in _info.Enemies)
            {
                if (!this.isLiveBacklineThreat(foe))
                    continue;
                local d = dest.getDistanceTo(foe.getTile());
                if (d < minMeleeDist)
                    minMeleeDist = d;
            }
            local newArcherDist = isCaster ? this.nearestEnemyArcherDist(dest, _info.Enemies) : 99;
            local newCover = isCaster ? this.hasRangedCoverAt(dest, _actor, _info.Enemies) : false;

            if (meleeDanger && minMeleeDist <= curMeleeDist)
                continue;
            if (!meleeDanger && sniperDanger)
            {
                if (minMeleeDist <= 2) continue;
                if (newArcherDist <= curArcherDist && !(newCover && !hasCoverNow)) continue;
            }

            // Prefer staying near friendly melee screens so we don't isolate ourselves into a corner.
            local nearAllies = 0;
            local openExits = 0;
            foreach (bro in _info.Brothers)
            {
                if (bro.getID() == _actor.getID()) continue;
                local d = dest.getDistanceTo(bro.getTile());
                if (d <= 2 && !this.isRangedRole(bro) && !this.isCasterRole(bro))
                    ++nearAllies;
            }
            for (local dir = 0; dir < 6; ++dir)
            {
                if (dest.hasNextTile(dir) && dest.getNextTile(dir).IsEmpty)
                    ++openExits;
            }

            local score = 0.0;
            if (meleeDanger)
                score += (minMeleeDist - curMeleeDist) * 12.0;
            if (sniperDanger)
                score += ::Math.max(0, newArcherDist - curArcherDist) * 8.0 + (newArcherDist >= 8 ? 10.0 : 0.0) + (newCover ? 7.0 : 0.0);
            score += ::Math.min(3, nearAllies) * 3.5 + ::Math.min(3, openExits) * 1.2 + (dest.Level - myTile.Level) * 2.0
                - cost.ActionPointsRequired * 1.1 - (dest.IsBadTerrain ? 2.5 : 0.0);
            if (score > bestScore)
            {
                bestScore = score;
                bestTile = dest;
            }
        }
        return bestTile;
    },

    // Find the safest adjacent clean tile to step out of Miasma / Fire / negative tile effects (2-3 AP, leaving AP to shoot/cast/strike).
    function findHazardEscapeTile( _behavior, _actor, _info )
    {
        local myTile = _actor.getTile();
        if (!_behavior.hasNegativeTileEffect(myTile, _actor))
            return null;
        if (_actor.getCurrentProperties().IsRooted || myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local maxMoveAP = ::Math.min(ap, 3);
        if (maxMoveAP < 2)
            return null;

        local isBackline = this.isCasterRole(_actor) || this.isRangedRole(_actor);
        local isPolearm = !isBackline && _actor.getIdealRange() >= 2;
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local bestTile = null;
        local bestScore = -9999.0;

        for (local d = 0; d < 6; ++d)
        {
            if (!myTile.hasNextTile(d)) continue;
            local dest = myTile.getNextTile(d);
            if (!dest.IsEmpty || _behavior.hasNegativeTileEffect(dest, _actor)) continue;
            local zones = dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions());
            if ((isBackline || isPolearm) && zones > 0) continue;
            if (!isBackline && zones >= 2) continue;
            if (!navigator.findPath(myTile, dest, settings, 0)) continue;
            local cost = navigator.getCostForPath(_actor, settings, maxMoveAP, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.ActionPointsRequired > maxMoveAP) continue;

            local minThreat = 99;
            foreach (foe in _info.Enemies)
            {
                if (!this.isDangerousMeleeEnemy(foe)) continue;
                local dist = dest.getDistanceTo(foe.getTile());
                if (dist < minThreat) minThreat = dist;
            }
            local nearAllies = 0;
            foreach (bro in _info.Brothers)
            {
                if (bro.getID() != _actor.getID() && dest.getDistanceTo(bro.getTile()) <= 2)
                    ++nearAllies;
            }
            local score = 20.0 + ::Math.min(3, nearAllies) * 3.0 + (dest.Level - myTile.Level) * 2.0
                - cost.ActionPointsRequired * 1.5 - (dest.IsBadTerrain ? 2.5 : 0.0) - zones * 8.0;
            if (isBackline)
                score += ::Math.min(5, minThreat) * 4.0 + (this.hasRangedCoverAt(dest, _actor, _info.Enemies) ? 5.0 : 0.0);
            else if (isPolearm)
                score += (minThreat == 2 ? 8.0 : (minThreat == 3 ? 4.0 : 0.0));
            else
                score += (minThreat <= 2 ? 5.0 : 0.0);

            if (score > bestScore)
            {
                bestScore = score;
                bestTile = dest;
            }
        }
        return bestTile;
    },

    // Check if an unshielded melee engage destination dives into dangerous surround without sufficient allied support.
    function isSuicidalSoloDive( _actor, _destTile )
    {
        if (_destTile == null || ::BGP.hasShield(_actor) || this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return false;
        if (_actor.getTile().ID == _destTile.ID || _actor.getSkills().hasSkill("effects.indomitable"))
            return false;
        local adjEnemies = 0;
        local adjAllies = 0;
        local adjShieldAllies = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!_destTile.hasNextTile(d)) continue;
            local adj = _destTile.getNextTile(d);
            if (!adj.IsOccupiedByActor || ::Math.abs(adj.Level - _destTile.Level) > 1) continue;
            local occ = adj.getEntity();
            if (occ.getID() == _actor.getID() || !occ.isAlive()) continue;
            if (occ.isAlliedWith(_actor))
            {
                ++adjAllies;
                if (::BGP.hasShield(occ)) ++adjShieldAllies;
            }
            else if (this.isDangerousMeleeEnemy(occ))
                ++adjEnemies;
        }
        local skills = _actor.getSkills();
        local hasDefPerk = skills.hasSkill("perk.battle_forged") || skills.hasSkill("perk.nimble");
        local hasUnderdog = skills.hasSkill("perk.underdog");
        local mdef = _actor.getCurrentProperties().getMeleeDefense();
        // Discourage unshielded medium-MDef bruisers from diving into 4+ enemies, solo 3+ dives, or unsupported 3+ pockets with no shieldbearer.
        if (adjEnemies >= 4)
            return true;
        if (adjEnemies >= 3 && (adjAllies == 0 || (adjShieldAllies == 0 && mdef < 35)))
            return true;
        if (!hasDefPerk && !hasUnderdog && adjEnemies >= 3 && adjShieldAllies == 0)
            return true;
        if (!hasDefPerk && adjEnemies >= 2 && adjAllies == 0)
            return true;
        return false;
    },

    // Check if a target enemy is afflicted by any necromantic debuff (for Hex-Eater / 嗜咒 AI synergy).
    function hasNecroDebuff( _target )
    {
        if (_target == null || ::MSU.isNull(_target)) return false;
        local skills = _target.getSkills();
        if (skills == null) return false;
        if (skills.hasSkill("effects.pale_weaken") || skills.hasSkill("effects.bgp_curse_of_ages")
            || skills.hasSkill("effects.pale_corpse_poison") || skills.hasSkill("effects.bgp_undead_poison")
            || skills.hasSkill("effects.pale_prey"))
            return true;
        local st = skills.getSkillByID("effects.staggered");
        return st != null && ("BGP_FromCorpseExplosion" in st.m) && st.m.BGP_FromCorpseExplosion;
    },

    // Smart evaluation & tile selection for regular combat pets (warhounds, dreadwolves, beasts - NOT Pale Sovereign Lich King).
    // Holds pets during the opening so they don't suicide on Round 1-2 and feed enemy Confident morale;
    // unleashes when: (1) owner is surrounded / low HP needing survival peel, (2) owner needs surround hit-chance bonus
    // against a tough/high-value engaged enemy and can attack same turn, or (3) late battle / enemy routing cleanup.
    function evaluateSmartPetUnleash( _behavior, _entity, _skill )
    {
        local myTile = _entity.getTile();
        local info = this.assessBattle(_entity, _behavior.getAgent());
        if (info.Enemies.len() == 0)
            return { Score = 0.0, Tile = null };

        local round = ::Time.getRound();
        local ap = _entity.getActionPoints();
        local unleashAP = _skill.getActionPointCost();
        local hpPct = _entity.getHitpointsPct();
        local hasInjury = _entity.getSkills().hasSkillOfType(::Const.SkillType.TemporaryInjury);
        local isShield = ::BGP.hasShield(_entity);
        local meleeAdj = this.countDangerousMeleeAdjacent(_entity, info.Enemies);
        local alliesAdj = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!myTile.hasNextTile(d)) continue;
            local nt = myTile.getNextTile(d);
            if (nt.IsOccupiedByActor && nt.getEntity().isAlliedWith(_entity) && nt.getEntity().isAlive())
                ++alliesAdj;
        }

        // Count active vs fleeing enemies & detect any threatened fragile/Mentor ally nearby.
        local activeEnemies = 0;
        local fleeingEnemies = 0;
        foreach (foe in info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) ++fleeingEnemies;
            else ++activeEnemies;
        }
        local fragileThreatTile = null;
        foreach (bro in info.Brothers)
        {
            if (bro.getID() == _entity.getID()) continue;
            if (!(this.isCasterRole(bro) || this.isRangedRole(bro) || bro.getHitpointsPct() <= 0.40)) continue;
            local bt = bro.getTile();
            if (myTile.getDistanceTo(bt) > 2) continue;
            if (bt.getZoneOfControlCountOtherThan(bro.getAlliedFactions()) > 0)
            {
                fragileThreatTile = bt;
                break;
            }
        }

        // Trigger 1: Emergency survival / peel (stricter on Rounds 1-2 so healthy owners don't feed pets into full enemy waves).
        local emergencySurvival = (round <= 2)
            ? ((meleeAdj >= 3 && (!isShield || hpPct <= 0.60))
                || (meleeAdj >= 1 && hpPct <= 0.50)
                || (fragileThreatTile != null && round >= 2))
            : ((meleeAdj >= 3)
                || (meleeAdj >= 2 && (!isShield || hpPct <= 0.60 || alliesAdj == 0))
                || (meleeAdj >= 1 && (hpPct <= 0.50 || (hasInjury && hpPct <= 0.65)))
                || (fragileThreatTile != null));

        // Trigger 2: Surround hit-chance bonus against a tough/evasive/high-value engaged enemy (mid-battle, Round >= 2, melee joined).
        local surroundTarget = null;
        local surroundNeed = false;
        if (!emergencySurvival && round >= 2 && meleeAdj >= 1 && info.EngagedBrothers >= 1)
        {
            local atk = this.cheapestMeleeSkill(_entity);
            local canComboAtk = atk != null && (ap - unleashAP >= atk.getActionPointCost());
            local bestTargetScore = 0.0;
            foreach (foe in info.Enemies)
            {
                if (!this.isDangerousMeleeEnemy(foe)) continue;
                local ft = foe.getTile();
                if (myTile.getDistanceTo(ft) != 1 || ::Math.abs(myTile.Level - ft.Level) > 1) continue;
                local hit = 70;
                if (atk != null) { try { hit = atk.getHitchance(foe); } catch (e) {} }
                local tough = foe.getSkills().hasSkill("racial.champion") || foe.isArmedWithShield()
                    || foe.getHitpointsMax() >= 115 || foe.getCurrentProperties().getMeleeDefense() >= 20;
                if ((hit <= 68 || tough) && (canComboAtk || round >= 3))
                {
                    local ts = (100 - hit) + (tough ? 25.0 : 0.0) + (foe.getSkills().hasSkill("racial.champion") ? 30.0 : 0.0);
                    if (ts > bestTargetScore) { bestTargetScore = ts; surroundTarget = foe; }
                }
            }
            if (surroundTarget != null)
                surroundNeed = true;
        }

        // Trigger 3: Safe late-battle cleanup or enemy routing chase.
        local safeCleanup = ::Tactical.Entities.isEnemyRetreating()
            || (fleeingEnemies >= 2 && fleeingEnemies >= activeEnemies)
            || (round >= 5 && activeEnemies > 0 && activeEnemies <= 5 && info.EngagedBrothers >= 1);

        if (!emergencySurvival && !surroundNeed && !safeCleanup)
            return { Score = 0.0, Tile = null };

        // Score every valid adjacent empty tile for optimal surround & pet survivability.
        local bestTile = null;
        local bestTileScore = -9999.0;
        for (local d = 0; d < 6; ++d)
        {
            if (!myTile.hasNextTile(d)) continue;
            local tile = myTile.getNextTile(d);
            if (!tile.IsEmpty || !_skill.onVerifyTarget(myTile, tile)) continue;
            if (_behavior.hasNegativeTileEffect(tile, _entity)) continue;

            local adjDang = 0;
            local adjAllies = 0;
            local adjToSurround = (surroundTarget != null && tile.getDistanceTo(surroundTarget.getTile()) == 1 && ::Math.abs(tile.Level - surroundTarget.getTile().Level) <= 1);
            local adjToAnyMelee = false;
            local screensFragile = (fragileThreatTile != null && tile.getDistanceTo(fragileThreatTile) <= 2);
            for (local d2 = 0; d2 < 6; ++d2)
            {
                if (!tile.hasNextTile(d2)) continue;
                local n = tile.getNextTile(d2);
                if (!n.IsOccupiedByActor || ::Math.abs(n.Level - tile.Level) > 1) continue;
                local occ = n.getEntity();
                if (!occ.isAlive()) continue;
                if (occ.isAlliedWith(_entity)) ++adjAllies;
                else if (this.isDangerousMeleeEnemy(occ)) { ++adjDang; adjToAnyMelee = true; }
            }

            // For non-emergency surround/cleanup, NEVER drop a fragile pet directly adjacent to 3+ dangerous enemies!
            if (!emergencySurvival && adjDang >= 3)
                continue;
            // For surround trigger, require the pet tile to actually flank the target (or at least an adjacent enemy).
            if (surroundNeed && !emergencySurvival && !adjToSurround && !adjToAnyMelee)
                continue;

            local ts = 20.0 + ::Math.min(3, adjAllies) * 6.0;
            if (adjToSurround) ts += 40.0;
            else if (adjToAnyMelee) ts += 18.0;
            if (screensFragile) ts += 28.0;
            if (adjDang >= 3) ts -= (adjDang - 2) * 35.0;
            else if (adjDang == 2) ts -= 8.0;
            if (tile.IsBadTerrain) ts -= 8.0;

            if (ts > bestTileScore)
            {
                bestTileScore = ts;
                bestTile = tile;
            }
        }

        if (bestTile == null)
            return { Score = 0.0, Tile = null };

        // Score above normal weapon attack (~150-400) so owner unleashes FIRST to gain +5% surround hit bonus before swinging,
        // while staying below emergency Rotation / Shieldwall (~900) unless truly critical.
        local finalScore = 0.0;
        if (emergencySurvival)
            finalScore = (hpPct <= 0.45 || meleeAdj >= 3) ? 820.0 : 620.0;
        else if (surroundNeed)
            finalScore = 540.0;
        else if (safeCleanup)
            finalScore = 460.0;

        return { Score = finalScore, Tile = bestTile };
    }
};

// Smart pet unleash timing for Autopilot (replaces vanilla Round 1 "Playing with dog" / suicidal "Bullying with dog").
::BGP.HooksMod.hook("scripts/ai/autopilot_unleash_dog", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (!::Autopilot.isUnderAIControl(_entity) || !::Autopilot.conf("bgpSmartFrontline"))
            return __original(_entity);
        // Never interfere with Pale Sovereign Mentor's Lich King (handled by pale_sovereign/autopilot.nut).
        if ("PaleSovereign" in ::getroottable() && ::PaleSovereign.isChief(_entity) && ::PaleSovereign.mainPet() != null)
            return ::Const.AI.Behavior.Score.Zero;
        this.m.Skill = null;
        this.m.TargetTile = null;
        if (_entity.getActionPoints() < ::Const.Movement.AutoEndTurnBelowAP)
            return ::Const.AI.Behavior.Score.Zero;
        if (_entity.getMoraleState() == ::Const.MoraleState.Fleeing || ::Tactical.State.isAutoRetreat())
            return ::Const.AI.Behavior.Score.Zero;
        this.m.Skill = this.selectSkill(this.m.PossibleSkills);
        if (this.m.Skill == null)
            return ::Const.AI.Behavior.Score.Zero;
        local plan = F.evaluateSmartPetUnleash(this, _entity, this.m.Skill);
        if (plan.Tile == null || plan.Score <= 0.0)
        {
            this.m.Skill = null;
            return ::Const.AI.Behavior.Score.Zero;
        }
        this.m.TargetTile = plan.Tile;
        return plan.Score;
    };
});

// Prevent Shieldbearers with Reforged Line Breaker (破阵者) from breaking formation / diving into 3+ enemies and losing Phalanx cohesion.
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_line_breaker", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        local score = __original(_entity);
        if (score <= 0 || !::Autopilot.isUnderAIControl(_entity) || !::Autopilot.conf("bgpSmartFrontline"))
            return score;
        if (::BGP.hasShield(_entity))
        {
            // Never push out of an active Shieldwall/Spearwall or dive solo into 3+ enemies.
            if (_entity.getSkills().hasSkill("effects.shieldwall") || _entity.getSkills().hasSkill("effects.spearwall"))
                return ::Const.AI.Behavior.Score.Zero;
            if (this.m.TargetTile != null)
            {
                local destZones = this.m.TargetTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions());
                if (destZones >= 3 || _entity.getSkills().hasSkill("perk.rf_phalanx"))
                    return ::Const.AI.Behavior.Score.Zero;
            }
        }
        return score;
    };
});

// Focus-fire target scoring for Autopilot-controlled player brothers.
::BGP.HooksMod.hook("scripts/ai/tactical/behavior", function(q) {
    q.queryTargetValue = @(__original) function( _entity, _target, _skill = null ) {
        return F.scoreFocusTarget(__original(_entity, _target, _skill), _entity, _target, _skill);
    };
});

// Prevent safe ranged/caster brothers rooted by Goblin Shamans from wasting 8 AP on Break Free when they can still shoot & cast freely!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_break_free", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && (F.isRangedRole(_entity) || F.isCasterRole(_entity))
            && _entity.getTile().getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) == 0)
        {
            local enemies = F.collectEnemies(_entity, this.getAgent());
            local liveDist = F.nearestLiveBacklineThreatDist(_entity, enemies);
            local onlyVines = _entity.getSkills().hasSkill("effects.rooted") && !_entity.getSkills().hasSkill("effects.net");
            if (liveDist > (onlyVines ? 1 : 2))
                return ::Const.AI.Behavior.Score.Zero;
        }
        return __original(_entity);
    };
});

// Track offensive hits from player side for the hold-line stall-breaker.
::BGP.HooksMod.hook("scripts/entity/tactical/actor", function(q) {
    q.onDamageReceived = @(__original) function( _attacker, _skill, _hitInfo ) {
        local ret = __original(_attacker, _skill, _hitInfo);
        if (_attacker != null && !::MSU.isNull(_attacker) && (_attacker.getFaction() == ::Const.Faction.Player || _attacker.getFaction() == ::Const.Faction.PlayerAnimals)
            && !this.isAlliedWith(_attacker))
        {
            F.battleState().LastOffenseRound = ::Time.getRound();
        }
        return ret;
    };
});

// Gate ai_engage_melee during hold-line, shieldbearer yield, or suicidal unshielded solo dives into 3+ enemies.
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_engage_melee", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (F.shouldSuppressEngageMelee(_entity, this.getAgent()))
        {
            this.m.Thread = null;
            this.m.TargetTile = null;
            this.m.TargetActor = null;
            this.m.Score = 0;
            return true;
        }
        local done = __original(_entity);
        if (done && this.m.Score > 0 && ::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && this.m.TargetTile != null && !this.m.IsWaitingBeforeMove && F.isSuicidalSoloDive(_entity, this.m.TargetTile))
        {
            // Discourage unshielded bros from diving completely solo into 3+ melee enemies without paralyzing normal line contact.
            this.m.Score *= 0.35;
        }
        return done;
    };
});

// Gate forward movement of ranged/caster units during hold-line.
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_engage_ranged", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        local done = __original(_entity);
        if (done && this.m.Score > 0 && F.shouldSuppressEngageRanged(_entity, this.getAgent(), this.m.TargetTile))
        {
            this.m.TargetTile = null;
            this.m.Score = 0;
        }
        return done;
    };
});

// Let non-shield 2-tile bros yield phase 1 to unacted shieldbearers before stepping in,
// and fix snh_isTileInDanger so healthy Billhook/polearm bros don't get paralyzed by enemies already locked in our frontline's ZoC!
::BGP.HooksMod.hook("scripts/ai/autopilot_step_n_hit", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && !::BGP.hasShield(_entity) && ::Tactical.TurnSequenceBar.canEntityWait(_entity)
            && _entity.getTile().getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) == 0)
        {
            local decision = F.shouldActorHold(_entity, this.getAgent());
            if (F.hasUnactedShieldAlly(_entity, decision.Info))
                return 0;
        }
        return __original(_entity);
    };
    q.snh_isTileInDanger = @(__original) function( _entity, _tile ) {
        if (!::Autopilot.isUnderAIControl(_entity) || !::Autopilot.conf("bgpSmartFrontline") || F.isCasterRole(_entity) || _entity.getHitpointsPct() < 0.50)
            return __original(_entity, _tile);
        foreach (op in this.getAgent().getKnownOpponents()) {
            local opp = op.Actor;
            if (opp == null || ::MSU.isNull(opp) || !opp.isAlive() || opp.isDying() || opp.isNonCombatant()) continue;
            if (opp.getMoraleState() == ::Const.MoraleState.Fleeing || opp.getCurrentProperties().IsStunned) continue;
            // Enemies already locked in our frontline ZoC cannot walk over to hit a 2-tile polearm bro (unless reach >= 2 or Footwork).
            local ot = opp.getTile();
            if (ot.getZoneOfControlCountOtherThan(opp.getAlliedFactions()) > 0
                && opp.getIdealRange() < 2 && !opp.getSkills().hasSkill("actives.footwork"))
                continue;
            if (this.queryActorTurnsNearTarget(opp, _tile, _entity).TurnsWithAttack <= 1.0)
                return true;
        }
        return false;
    };
});

// Keep per-target history on the skill so toggling Autopilot cannot reset it mid-round.
::BGP.HooksMod.hook("scripts/skills/actives/bgp_necro_possess_skill", function(q) {
    q.m.BGPAutoPossessRound <- -1;
    q.m.BGPAutoPossessTargets <- null;
    q.onCombatStarted = @(__original) function() {
        __original();
        this.m.BGPAutoPossessRound = -1;
        this.m.BGPAutoPossessTargets = null;
    };
    q.onUse = @(__original) function(user, tile) {
        local id = tile.getEntity().getID();
        local result = __original(user, tile);
        if (result) {
            if (this.m.BGPAutoPossessRound != ::Time.getRound()) {
                this.m.BGPAutoPossessRound = ::Time.getRound();
                this.m.BGPAutoPossessTargets = {};
            }
            this.m.BGPAutoPossessTargets[id] <- true;
        }
        return result;
    };
});

::BGP.HooksMod.hook("scripts/entity/tactical/player", function(q) {
    q.enableAIControl = @(__original) function() {
        __original();
        local agent = this.getAIAgent();
        agent.addBehavior(::new("scripts/ai/bgp_autopilot_frontline"));
        local skills = this.getSkills();
        local weights = "autopilot_mults" in agent ? agent.autopilot_mults : agent.m.Properties.BehaviorMult;

        // Ranged brothers: prevent -0.8 friendly-fire paralysis around undead summons, and prefer drawing backup melee weapon over eating ZoC AoO.
        if (::Autopilot.conf("bgpSmartFrontline") && F.isRangedRole(this)) {
            agent.m.Properties.TargetPriorityHittingAlliesMult = -0.15;
            if (!skills.hasSkill("actives.footwork") && !skills.hasSkill("actives.rf_move_under_cover")
                && F.findBestBagMeleeWeapon(this) != null) {
                weights[::Const.AI.Behavior.ID.Disengage] = 0.35;
                if (::Const.AI.Behavior.ID.SwitchToMelee < weights.len())
                    weights[::Const.AI.Behavior.ID.SwitchToMelee] = 3.0;
            }
        }

        local eligible = skills.getSkillsByFunction(@(s) s.getID() in A.Actions
            && (s.getID() != "actives.possess_undead" || s.ClassName == "bgp_necro_possess_skill")
            && s.getID() != "actives.unleash_companion");
        if (eligible.len() > 0) {
            agent.addBehavior(::new("scripts/ai/bgp_autopilot_tactics"));
            local possess = skills.getSkillByID("actives.possess_undead");
            if (possess != null && possess.ClassName == "bgp_necro_possess_skill")
                agent.removeBehavior(::Const.AI.Behavior.ID.PossessUndead);
            if (skills.hasSkill("actives.bgp_necro_raise")) {
                if (agent.getBehavior(::Const.AI.Behavior.ID.EngageRanged) == null)
                    agent.addBehavior(::new("scripts/ai/tactical/behaviors/ai_engage_ranged"));
                agent.removeBehavior(::Const.AI.Behavior.ID.Protect);
                weights[::Const.AI.Behavior.ID.EngageMelee] = ::Autopilot.conf("bgpSmartFrontline") ? 0.0 : 0.18;
                weights[::Const.AI.Behavior.ID.Disengage] = ::Autopilot.conf("bgpSmartFrontline") ? 3.0 : 2.0;
            }
        }
        agent.finalizeBehaviors();
    };
});
