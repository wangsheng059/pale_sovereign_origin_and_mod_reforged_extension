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
page.addElement(::MSU.Class.BooleanSetting("bgpAutoEquippedNet", true, "自动投掷已手持投网", "开启智能前线时，即使关闭自动掏网，已直接装备在副手的投网仍会择机投向精锐或高威胁敌人。"));

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
    // Prioritize Raise Dead while building the early undead frontline.
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
    local goblinHits = 0;
    local cursedHits = 0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1) continue;
        local enemy = tile.getEntity();
        ++hits;
        if (enemy.getArmor(::Const.BodyPart.Body) >= 130) ++armoredHits;
        if (!enemy.getFlags().has("undead")) ++moraleVulnerableHits;
        if (enemy.getFlags().has("goblin")) ++goblinHits;
        if (enemy.getSkills().hasSkill("effects.bgp_curse_of_ages")) ++cursedHits;
        value += 1.1 + ::Math.minf(1.8, (blast.Blunt + blast.Cutting * 0.45) / 35.0);
        if (enemy.getHitpoints() <= blast.Blunt * 0.65) {
            value += 1.6;
            ++lethalCount;
        }
    }
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
        if (lethalCount == 0 && aliveUndead < 5 && totalCorpses <= 2)
            return 0;
        if (goblinHits == hits && lethalCount < 2 && (hits < 4 || aliveUndead < 7))
            value *= 0.55;
        if (moraleVulnerableHits == 0 && lethalCount == 0) {
            if (hits >= 4 && aliveUndead >= 6) {
                value += 1.6;
            } else {
                if (totalCorpses <= 3 || aliveUndead < 6)
                    return 0;
                if (totalCorpses <= 5 || aliveUndead < 7)
                    value *= 0.45;
            }
        }
        // Protect our undead frontline: when fewer than 5 undead are alive, prioritize Raise Dead over blowing up corpses (unless multi-kill).
        if (aliveUndead < 5 && lethalCount < 2) {
            value = ::Math.minf(9.5, value * 0.55);
        } else if (hits >= 3 && (aliveUndead >= 6 || totalCorpses >= 5) && (moraleVulnerableHits >= 2 || lethalCount >= 1)
            && (armoredHits >= 2 || cursedHits >= 2 || lethalCount >= 1)) {
            value += (hits >= 4 ? 3.5 : 2.1) + (armoredHits >= 2 ? 0.9 : 0.0) + (moraleVulnerableHits >= 3 ? 0.8 : 0.0) + (cursedHits >= 2 ? 1.2 : 0.0);
        }
    }
    return value;
});
A.add("bgp_necro_curse_of_ages", "Centers", function(c, s, t) {
    local smart = ::Autopilot.conf("bgpSmartFrontline");
    local alreadyCursed = 0;
    local aliveUndead = 0;
    local corpseCount = 0;
    local roundsSinceCurse = 99;
    if (smart) {
        foreach (tile in c.Enemies) {
            if (tile.getEntity().getSkills().hasSkill("effects.bgp_curse_of_ages"))
                ++alreadyCursed;
        }
        foreach (u in ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.PlayerAnimals)) {
            if (u != null && !::MSU.isNull(u) && u.isAlive() && !u.isDying() && u.isPlacedOnMap() && u.getFlags().has("undead"))
                ++aliveUndead;
        }
        corpseCount = c.Behavior.targets(c, "Corpses").len();
        roundsSinceCurse = ::Time.getRound() - A.Frontline.battleState().LastCurseRound;
    }
    local value = 0.0;
    local hits = 0;
    local engagedHits = 0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1) continue;
        local enemy = tile.getEntity();
        if (enemy.getMoraleState() == ::Const.MoraleState.Fleeing || enemy.getSkills().hasSkill("effects.bgp_curse_of_ages")) continue;
        ++hits;
        local w = 1.75 + ::Math.minf(0.9, enemy.getHitpointsMax() / 140.0);
        if (smart) {
            if (enemy.getSkills().hasSkill("racial.champion"))
                w += 0.75;
            if (tile.getZoneOfControlCountOtherThan(enemy.getAlliedFactions()) > 0) {
                w += 0.35;
                ++engagedHits;
            }
        }
        value += w;
    }
    if (smart) {
        if (hits < 2) return 0;
        // 2-round pacing cooldown prevents consecutive-turn Curse spam (T03+T04) and late-game fatigue burnout,
        // unless almost no enemies remain cursed (< 2) and a fresh 4+ uncursed clump appears.
        if (roundsSinceCurse < 2 && !(alreadyCursed < 2 && hits >= 4))
            return 0;

        // Core rule: >= 4 uncursed enemies in the 7-tile AoE (regardless of armor class) gets high casting priority
        // (enabling Round-2 Summon 4 AP + Curse 5 AP); fewer than 4 stays low priority below Raise Dead / Corpse Explosion!
        local cap = 9.8;
        if (hits >= 4) {
            value += 4.2 + ::Math.minf(2.0, (hits - 4) * 0.9) + (engagedHits >= 2 ? 0.5 : 0.0);
            cap = 16.5;
            // Still protect Raise Dead if our undead frontline is critically thin (< 4) and corpses are waiting after an initial Curse.
            if (alreadyCursed >= 3 && corpseCount > 0 && aliveUndead < 4)
                cap = 10.5;
        } else {
            value *= (alreadyCursed >= 3 ? 0.55 : 0.78);
            cap = 9.8;
        }
        // Stay below opening Lich King (~28.7), Round-1/first-R2 free Summons (~21.7-22.7), emergency reserve summon (~25), and Lich Possess (19.0).
        value = ::Math.minf(cap, value);
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
            LastCurseRound = -99,
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
        local enemyMiasmaPriests = 0;
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
                if (fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma"))
                    ++enemyMiasmaPriests;
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
        // Disable passive HoldLine against charger packs, Miasma/Horror priests, or enemy necromancers.
        local casterPush = (enemyMiasmaPriests > 0) || (enemyUrgentCasters > 0 && round >= 2);
        local holdLine = rangedAdvantage && enemyChargers < 3 && !casterPush && !state.StallBroken && !state.MeleeJoined && activeEnemies > 0;

        return {
            Enemies = enemies,
            Brothers = brothers,
            PlayerRanged = playerRanged,
            EnemyRanged = enemyRanged,
            EnemyProjectileRanged = enemyProjectileRanged,
            EnemyChargers = enemyChargers,
            EnemyUrgentCasters = enemyUrgentCasters,
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

    function cheapestMeleeSkill( _actor, _ignoreAffordable = false )
    {
        local best = null;
        foreach (s in _actor.getSkills().m.Skills)
        {
            if (s == null || !s.m.IsActive || !s.m.IsAttack || !s.m.IsTargeted || s.m.IsRanged)
                continue;
            if (!s.m.IsWeaponSkill && s.getID() != "actives.hand_to_hand")
                continue;
            if (s.isHidden() || !s.isUsable() || (!_ignoreAffordable && !s.isAffordable()))
                continue;
            if (best == null || s.getActionPointCost() < best.getActionPointCost()
                || (s.getActionPointCost() == best.getActionPointCost() && s.getFatigueCost() < best.getFatigueCost()))
                best = s;
        }
        return best;
    },

    // Compute exact post-movement AP and Fatigue costs of _skill after executing _moveCost across all installed mods:
    // starts from live getActionPointCost()/getFatigueCost() (covering all static/current-state modifiers across all mods)
    // and simulates Reforged's 4 movement-dependent perks (Spear Mastery expiry, Vigorous Assault, Opportunist, Vanquisher).
    function previewSkillCostsAfterMove( _actor, _skill, _moveCost )
    {
        local effAP = _skill.getActionPointCost();
        local effFat = _skill.getFatigueCost();
        local bonus = false;
        if (_moveCost == null || _moveCost.Tiles <= 0)
            return { AP = effAP, Fat = effFat, Bonus = false };

        local skills = _actor.getSkills();
        local spearExpired = false;

        // 1. Reforged Spear Mastery (reverse trap): 0 AP / 0.5x Fat expires if total tiles moved exceeds allowed limit
        // (1 tile for 1H spears, 0 tiles for 2H spears); if it stays active after a 1-tile 1H move, flag Bonus = true.
        local sp = skills.getSkillByID("perk.mastery.spear");
        if (sp != null)
        {
            try {
                if (!sp.m.IsSpent && sp.isSkillValid(_skill))
                {
                    if (sp.m.TilesMoved + _moveCost.Tiles > sp.getMaxTilesAllowed())
                    {
                        spearExpired = true;
                        local baseAP = 4;
                        try {
                            baseAP = _skill.getBaseValue("ActionPointCost");
                        } catch (e2) {
                            local w = _skill.getItem();
                            baseAP = (w != null && !::MSU.isNull(w) && w.isItemType(::Const.Items.ItemType.TwoHanded)) ? 6 : 4;
                        }
                        effAP = ::Math.max(0, baseAP + _actor.getCurrentProperties().AdditionalActionPointCost);
                        effFat = ::Math.ceil(effFat / ::Math.maxf(0.1, sp.m.FatigueCostMultMult)).tointeger();
                    }
                    else
                    {
                        bonus = true;
                    }
                }
            } catch (e) {}
        }

        // 2. Reforged Vigorous Assault: every BonusEveryXTiles (2) moved grants -1 AP (min 1) & -10% Fat on next attack.
        // Note: Autopilot keeps IsControlledByPlayer == true, so Reforged does not pre-discount live ActionPointCost.
        local va = skills.getSkillByID("perk.rf_vigorous_assault");
        if (va != null)
        {
            try {
                if (va.isSkillValid(_skill))
                {
                    local step = ::Math.max(1, va.m.BonusEveryXTiles);
                    local curStacks = (va.m.NumTilesMoved / step).tointeger();
                    local newStacks = ((va.m.NumTilesMoved + _moveCost.Tiles) / step).tointeger();
                    local apDrop = spearExpired ? newStacks : (newStacks - curStacks);
                    if (apDrop > 0)
                    {
                        if (effAP > 1)
                            effAP = ::Math.max(1, effAP - apDrop);
                        bonus = true;
                    }
                    if (newStacks > curStacks)
                    {
                        local curMult = ::Math.maxf(0.0, 1.0 - 0.1 * curStacks);
                        local newMult = ::Math.maxf(0.0, 1.0 - 0.1 * newStacks);
                        effFat = curMult > 0.01 ? ::Math.floor(effFat * newMult / curMult).tointeger() : 0;
                        bonus = true;
                    }
                }
            } catch (e) {}
        }

        // 3. Reforged Opportunist: stepping onto an unused enemy corpse primes 0 AP & reduced Fat for next Throwing attack.
        local opp = skills.getSkillByID("perk.rf_opportunist");
        if (opp != null && _moveCost.End != null)
        {
            try {
                if (!opp.m.IsPrimed && opp.isSkillValid(_skill) && opp.canProcOntile(_moveCost.End))
                {
                    effAP = 0;
                    effFat = ::Math.floor(effFat * opp.m.FatigueCostMult).tointeger();
                    bonus = true;
                }
            } catch (e) {}
        }

        // 4. Reforged Vanquisher: stepping onto a tile where this actor killed an enemy this turn halves next skill AP (>1).
        local vanq = skills.getSkillByID("perk.rf_vanquisher");
        if (vanq != null && _moveCost.End != null)
        {
            try {
                if (!vanq.m.IsSpent && !vanq.m.IsInEffect && vanq.isTileValid(_moveCost.End))
                {
                    if (effAP > 1)
                        effAP = (effAP / 2).tointeger();
                    bonus = true;
                }
            } catch (e) {}
        }

        return { AP = effAP, Fat = effFat, Bonus = bonus };
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

    // Check whether a shieldbearer is currently adjacent to a live enemy engaged in melee with Mentor (dist <= 1)
    // and can immediately strike that enemy (so the shieldbearer attacks directly to save Mentor instead of raising Shieldwall).
    function isPeelingMentorMelee( _actor, _info )
    {
        if (!::BGP.hasShield(_actor) || _actor.getHitpointsPct() < 0.40)
            return false;
        local chief = null;
        foreach (bro in _info.Brothers)
        {
            if (this.isCasterRole(bro)) { chief = bro; break; }
        }
        if (chief == null)
            return false;
        local chiefTile = chief.getTile();
        if (chiefTile.getZoneOfControlCountOtherThan(chief.getAlliedFactions()) <= 0)
            return false;
        local atk = this.cheapestMeleeSkill(_actor);
        if (atk == null)
            return false;
        local myTile = _actor.getTile();
        foreach (foe in _info.Enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe)) continue;
            local ft = foe.getTile();
            if (chiefTile.getDistanceTo(ft) <= 1 && ::Math.abs(chiefTile.Level - ft.Level) <= 1
                && myTile.getDistanceTo(ft) <= atk.getMaxRange() && atk.isUsableOn(ft, myTile))
            {
                return true;
            }
        }
        return false;
    },

    // Check whether an engaged shieldbearer should strike before raising Shieldwall.
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
        // Reserve Rotation fatigue when standing beside a wounded engaged unshielded ally.
        local rot = _actor.getSkills().getSkillByID("actives.rotation");
        local reserveRotFat = 0;
        if (rot != null && !rot.isHidden() && rot.isUsable())
        {
            local myT = _actor.getTile();
            for (local d = 0; d < 6; ++d)
            {
                if (!myT.hasNextTile(d)) continue;
                local nt = myT.getNextTile(d);
                if (!nt.IsOccupiedByActor) continue;
                local a = nt.getEntity();
                if (a != null && a.getFaction() == ::Const.Faction.Player && a.isAlive() && !::BGP.hasShield(a)
                    && a.getHitpointsPct() <= 0.65 && nt.getZoneOfControlCountOtherThan(a.getAlliedFactions()) > 0)
                {
                    reserveRotFat = rot.getFatigueCost();
                    break;
                }
            }
        }
        if (reserveRotFat > 0 && fatLeft < reserveRotFat)
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

            if (expectedHP >= foe.getHitpoints() && hit >= 40)
                return true;
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
        local skill = this.cheapestMeleeSkill(_actor, true);
        if (skill == null)
            return null;
        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local atkAP = skill.getActionPointCost();
        local atkFat = skill.getFatigueCost();
        local minRange = skill.getMinRange();
        local maxRange = skill.getMaxRange();

        // Already in strike range without moving.
        if (ap >= atkAP && availFat >= atkFat)
        {
            foreach (foe in _enemies)
            {
                if (skill.isUsableOn(foe.getTile(), myTile))
                    return { Tile = myTile, Enemy = foe, Skill = skill, APAfter = ap, EffAP = atkAP };
            }
        }
        // Allow up to +2 AP optimistic move budget when movement-discount perks (Vigorous Assault / Vanquisher) exist.
        local skills = _actor.getSkills();
        local hasMoveDiscount = skills.hasSkill("perk.rf_vigorous_assault") || skills.hasSkill("perk.rf_vanquisher");
        local optimisticMinAP = hasMoveDiscount ? ::Math.max(1, atkAP - 2) : atkAP;
        local moveAPBudget = ap - optimisticMinAP;
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
                local eff = this.previewSkillCostsAfterMove(_actor, skill, cost);
                local apAfter = ap - cost.ActionPointsRequired;
                if (apAfter < eff.AP || availFat - cost.FatigueRequired < eff.Fat)
                    continue;
                local score = 10.0 + (eff.Bonus ? 2.5 : 0.0) + (dest.Level - ft.Level) * 2.0 - cost.ActionPointsRequired * 0.35
                    - (dest.IsBadTerrain ? 1.5 : 0.0) - (dest.Properties.Effect != null && dest.Properties.Effect.IsPositive == false ? 6.0 : 0.0);
                if (score > bestScore)
                {
                    bestScore = score;
                    bestPlan = { Tile = dest, Enemy = foe, Skill = skill, APAfter = apAfter, EffAP = eff.AP };
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
        // Yield Round 1 Phase 1 (zero turns lost: actor still acts in Round 1 Phase 2 with full AP!)
        // to nearby unacted shieldbearers or our unacted summoner Mentor so tanks & undead summons take the frontline first
        // — especially critical against Noble Halberdiers/Arbalesters, Orc Chargers, and Goblin skirmishers!
        if (::Time.getRound() > 1 || _info.EngagedBrothers > 0)
            return false;
        local myTile = _actor.getTile();
        foreach (foe in _info.Enemies)
        {
            if (myTile.getDistanceTo(foe.getTile()) <= 2)
                return false;
        }
        local isFragile = this.isFragileMelee(_actor);
        foreach (ally in _info.Brothers)
        {
            if (ally.getID() == _actor.getID())
                continue;
            if (ally.isTurnDone() || ally.getActionPoints() < 4)
                continue;
            if (ally.getMoraleState() == ::Const.MoraleState.Fleeing || ally.getCurrentProperties().IsStunned
                || ally.getCurrentProperties().IsRooted)
                continue;
            local dist = ally.getTile().getDistanceTo(myTile);
            if (::BGP.hasShield(ally) && ally.getInitiative() >= 40 && dist <= 5
                && ally.getTile().getZoneOfControlCountOtherThan(ally.getAlliedFactions()) == 0)
                return true;
            // All non-shield melee bros yield Round 1 Phase 1 to our unacted summoner Mentor so Lich King + Skeleton deploy first.
            if (this.isCasterRole(ally) && ally.getInitiative() >= 40 && dist <= 5)
            {
                local sk = ally.getSkills();
                local hasOpener = false;
                foreach (sid in ["actives.unleash_companion", "actives.pale_summon_skeleton", "actives.pale_summon_zombie"])
                {
                    local s = sk.getSkillByID(sid);
                    if (s != null && !s.isHidden() && s.isUsable() && s.isAffordable())
                    {
                        hasOpener = true;
                        break;
                    }
                }
                if (hasOpener)
                    return true;
            }
        }
        return false;
    },

    function isFragileMelee( _actor )
    {
        if (::BGP.hasShield(_actor))
            return false;
        local skills = _actor.getSkills();
        local hasDefPerk = skills.hasSkill("perk.battle_forged") || skills.hasSkill("perk.nimble");
        local mdef = _actor.getCurrentProperties().getMeleeDefense();
        local bodyArm = _actor.getArmor(::Const.BodyPart.Body);
        return mdef < 20 || !hasDefPerk || bodyArm < 80 || _actor.getHitpointsPct() <= 0.50;
    },

    // Continuous enemy elite threat rating (scales cleanly from Day 1 Lv1 fights to Day 100+ late-game camps).
    function enemyEliteScore( _foe, _info = null )
    {
        if (!this.isDangerousMeleeEnemy(_foe))
            return 0.0;
        local score = 0.0;
        local skills = _foe.getSkills();
        if (skills.hasSkill("racial.champion"))
            score += 2.5;
        local w = _foe.getMainhandItem();
        if (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon))
            score += 1.4;
        if (skills.hasSkill("actives.charge") || skills.hasSkill("actives.line_breaker")
            || skills.hasSkill("actives.warcry") || skills.hasSkill("actives.adrenaline")
            || skills.hasSkill("effects.berserker_rage"))
            score += 0.9;
        local cn = _foe.ClassName;
        if (cn == "barbarian_marauder" || cn == "barbarian_chosen" || cn == "barbarian_champion"
            || cn == "orc_warlord" || cn == "orc_warrior" || cn == "orc_berserker"
            || cn == "knight" || cn == "rf_knight_anointed" || cn == "executioner"
            || cn == "rf_skeleton_heavy_elite" || cn == "rf_skeleton_legatus"
            || cn == "rf_zombie_hero" || cn == "zombie_knight"
            || cn == "swordmaster" || cn == "blade_dancer" || cn == "rf_fencer"
            || cn == "lindwurm" || cn == "unhold" || cn == "schrat")
            score += 1.25;
        // Relative durability tier compared to other enemies on the field.
        local avgHP = 90.0;
        local avgArm = 70.0;
        if (_info != null && _info.Enemies.len() > 1)
        {
            local sumHP = 0.0, sumArm = 0.0, cnt = 0;
            foreach (e in _info.Enemies)
            {
                if (e.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                sumHP += e.getHitpointsMax();
                sumArm += e.getArmorMax(::Const.BodyPart.Body);
                ++cnt;
            }
            if (cnt > 0)
            {
                avgHP = sumHP / cnt;
                avgArm = sumArm / cnt;
            }
        }
        if (_foe.getHitpointsMax() >= avgHP * 1.25 || _foe.getHitpointsMax() >= 140)
            score += 1.1;
        if (_foe.getArmorMax(::Const.BodyPart.Body) >= 60 && _foe.getArmorMax(::Const.BodyPart.Body) >= avgArm * 1.35)
            score += 0.6;
        return score;
    },

    // Identify weaker or fragile high-threat targets that unshielded DPS should focus down first.
    function isFragileHighThreat( _foe, _info = null )
    {
        if (::MSU.isNull(_foe) || !_foe.isAlive() || _foe.isDying() || _foe.getMoraleState() == ::Const.MoraleState.Fleeing)
            return false;
        local bodyArm = _foe.getArmor(::Const.BodyPart.Body);
        local hp = _foe.getHitpoints();
        local skills = _foe.getSkills();
        if (skills.hasSkill("effects.net") || _foe.getCurrentProperties().IsStunned)
            return true;
        if (skills.hasSkill("effects.berserker_rage") || _foe.ClassName == "orc_berserker"
            || _foe.ClassName == "desert_stalker" || _foe.ClassName == "rf_banshee" || _foe.ClassName == "ghost")
            return true;
        if (skills.hasSkill("actives.raise_undead") || skills.hasSkill("actives.horror")
            || skills.hasSkill("actives.miasma") || skills.hasSkill("actives.root") || skills.hasSkill("actives.hex"))
            return true;
        if (!_foe.isArmedWithShield() && (bodyArm <= 55 || hp <= 65 || _foe.getHitpointsPct() <= 0.55))
            return true;
        return false;
    },

    // Count friendly melee/shield/undead allies standing physically between _tile and _threatTile (providing ZoC screen).
    function countScreenBlockersBetween( _tile, _actor, _threatTile )
    {
        local dist = _tile.getDistanceTo(_threatTile);
        local blockers = 0;
        local strongBlockers = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!_tile.hasNextTile(d)) continue;
            local nt = _tile.getNextTile(d);
            if (!nt.IsOccupiedByActor || ::Math.abs(nt.Level - _tile.Level) > 1) continue;
            local occ = nt.getEntity();
            if (occ.getID() == _actor.getID() || !occ.isAlive() || !occ.isAlliedWith(_actor)) continue;
            if (this.isCasterRole(occ) || this.isRangedRole(occ)) continue;
            if (nt.getDistanceTo(_threatTile) < dist)
            {
                ++blockers;
                if (::BGP.hasShield(occ) || occ.getFaction() == ::Const.Faction.PlayerAnimals)
                    ++strongBlockers;
            }
        }
        return { Blockers = blockers, Strong = strongBlockers };
    },

    // Unified terrain & elevation tactical scorer: rewards high ground (+10% MAtk/MDef/RAtk per level),
    // penalizes fighting uphill or stepping off high ground, avoids bad terrain (swamp/deep snow),
    // and rewards natural flank protection (trees/rocks/cliffs limiting surround slots).
    function scoreTerrainAdvantage( _actor, _tile, _originTile, _enemies, _role = "melee" )
    {
        if (_tile == null)
            return 0.0;
        local score = 0.0;
        local myLvl = _tile.Level;
        local isRangedOrCaster = (_role == "ranged" || _role == "caster");
        local isTank = (_role == "tank");
        local isFragile = (_role == "dps" && this.isFragileMelee(_actor));

        // 1. Elevation delta against nearby live enemies (within 4 tiles, or nearest enemy if farther).
        local enemyLvlSum = 0.0;
        local enemyCnt = 0;
        local nearestDist = 99;
        local nearestLvl = myLvl;
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            local ft = foe.getTile();
            local d = _tile.getDistanceTo(ft);
            if (d < nearestDist) { nearestDist = d; nearestLvl = ft.Level; }
            if (d <= 4)
            {
                enemyLvlSum += ft.Level;
                ++enemyCnt;
            }
        }
        local refLvl = enemyCnt > 0 ? (enemyLvlSum / enemyCnt) : nearestLvl.tofloat();
        local dLvl = myLvl - refLvl;
        if (dLvl > 0.0)
            score += dLvl * (isRangedOrCaster ? 14.0 : 12.0);
        else if (dLvl < 0.0)
            score += dLvl * (isFragile ? 18.0 : (isRangedOrCaster ? 10.0 : 14.0));

        // Penalize stepping DOWN off high ground we already hold (force enemies to climb uphill into us).
        if (_originTile != null && myLvl < _originTile.Level && nearestDist <= 5)
            score -= (_originTile.Level - myLvl) * (isRangedOrCaster ? 8.0 : 10.0);

        // 2. Bad terrain (Swamp -25% MAtk/MDef, Deep Snow, etc.) & movement AP cost preference.
        if (_tile.IsBadTerrain)
        {
            if (_originTile == null || !_originTile.IsBadTerrain)
                score -= isTank ? 14.0 : 16.0;
            else
                score -= 6.0;
        }
        else if (_originTile != null && _originTile.IsBadTerrain)
        {
            // Strong incentive to step OUT of Swamp / bad terrain onto firm ground!
            score += 10.0;
        }
        try {
            local moveAP = _actor.getActionPointCosts()[_tile.Type];
            if (moveAP >= 3)
                score -= (moveAP - 2) * 2.5;
        } catch (e) {}

        // 3. Natural chokepoint / flank protection (impassable tiles or cliff edges |dLevel| > 1)
        // plus forcing incoming enemies to attack from lower elevation or bad terrain.
        local blockedSides = 0;
        local openExits = 0;
        local hostileBadApproaches = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!_tile.hasNextTile(d))
            {
                ++blockedSides;
                continue;
            }
            local nt = _tile.getNextTile(d);
            if ((!nt.IsEmpty && !nt.IsOccupiedByActor) || ::Math.abs(nt.Level - myLvl) > 1)
            {
                ++blockedSides;
            }
            else
            {
                if (nt.IsEmpty) ++openExits;
                if (nt.Level < myLvl || nt.IsBadTerrain)
                {
                    if (nearestDist <= 5 && enemyCnt > 0)
                        ++hostileBadApproaches;
                }
            }
        }
        if (isTank)
            score += ::Math.min(3, blockedSides) * 5.5 + ::Math.min(3, hostileBadApproaches) * 4.5;
        else if (!isRangedOrCaster)
            score += ::Math.min(3, blockedSides) * 4.0 + ::Math.min(2, hostileBadApproaches) * 3.5;
        else
        {
            score += ::Math.min(2, blockedSides) * 3.0;
            if (openExits == 0)
                score -= 12.0; // Never trap Mentor/ranged in a dead-end corner!
        }

        return score;
    },

    // Check whether an enemy Elite is already pinned by a friendly shieldbearer or undead tank
    // while weaker non-elite enemies are still alive (so fragile 1-tile DPS shouldn't steal Elite aggro off the tank).
    function isElitePinnedByTank( _actor, _foe, _info )
    {
        if (_foe == null || _foe.getMoraleState() == ::Const.MoraleState.Fleeing)
            return false;
        if (_foe.getSkills().hasSkill("effects.net") || _foe.getCurrentProperties().IsStunned)
            return false;
        if (_foe.getHitpointsPct() <= 0.45)
            return false;
        if (this.enemyEliteScore(_foe, _info) < 1.5)
            return false;

        // Check if other weaker non-elite active enemies still exist on the field.
        local otherWeakAlive = false;
        local chiefTile = null;
        foreach (bro in _info.Brothers)
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }
        local ft = _foe.getTile();
        if (chiefTile != null && ft.getDistanceTo(chiefTile) <= 2)
            return false; // Always peel an elite threatening Mentor!
        foreach (e in _info.Enemies)
        {
            if (e.getID() == _foe.getID() || e.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            if (this.enemyEliteScore(e, _info) < 1.5) { otherWeakAlive = true; break; }
        }
        if (!otherWeakAlive)
            return false;

        // Check if a friendly shieldbearer or undead tank is already pinning this Elite.
        for (local d = 0; d < 6; ++d)
        {
            if (!ft.hasNextTile(d)) continue;
            local nt = ft.getNextTile(d);
            if (!nt.IsOccupiedByActor || ::Math.abs(nt.Level - ft.Level) > 1) continue;
            local occ = nt.getEntity();
            if (occ.getID() == _actor.getID() || !occ.isAlive() || !occ.isAlliedWith(_actor)) continue;
            if (::BGP.hasShield(occ) || occ.getFaction() == ::Const.Faction.PlayerAnimals)
                return true;
        }
        return false;
    },

    // Check whether ANY enemy adjacent to _tile is a full-HP Elite already pinned by our shieldbearer/undead tank.
    function hasAdjacentPinnedElite( _actor, _tile, _info )
    {
        if (_tile == null)
            return false;
        for (local d = 0; d < 6; ++d)
        {
            if (!_tile.hasNextTile(d)) continue;
            local nt = _tile.getNextTile(d);
            if (!nt.IsOccupiedByActor || ::Math.abs(nt.Level - _tile.Level) > 1) continue;
            local occ = nt.getEntity();
            if (occ.isAlive() && !occ.isAlliedWith(_actor) && this.isElitePinnedByTank(_actor, occ, _info))
                return true;
        }
        return false;
    },

    // Unified gate for critically wounded unshielded retreat (<= 28% HP):
    // protects fragile early/mid-game bros while never pulling armored Battle Forged tanks or stalling late-battle cleanup!
    function shouldWoundedRetreat( _actor, _info )
    {
        if (::BGP.hasShield(_actor) || this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return false;
        if (_actor.getHitpointsPct() > 0.28 || _actor.getCurrentProperties().IsRooted)
            return false;
        if (_actor.getSkills().hasSkill("perk.battle_forged") && _actor.getArmor(::Const.BodyPart.Body) >= 100)
            return false;
        if (::Time.getRound() >= 14)
            return false;
        local activeEnemies = 0;
        foreach (foe in _info.Enemies)
            if (foe.getMoraleState() != ::Const.MoraleState.Fleeing) ++activeEnemies;
        if (activeEnemies <= 2)
            return false;
        local otherFighters = 0;
        foreach (bro in _info.Brothers)
            if (bro.getID() != _actor.getID() && bro.getHitpointsPct() > 0.28 && !this.isCasterRole(bro)) ++otherFighters;
        if (otherFighters < 2)
            return false;
        return true;
    },

    // Critically wounded unshielded melee bro (<= 28% HP) who is currently free (zoc == 0) retreats behind healthy allies!
    function findWoundedRetreatTile( _behavior, _actor, _info )
    {
        if (!this.shouldWoundedRetreat(_actor, _info))
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local curDist = this.nearestDangerousMeleeDist(_actor, _info.Enemies);
        if (curDist > 4)
            return null;

        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        if (ap < 2) return null;
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local candidates = this.tilesInRange(myTile, 1, ap >= 4 ? 2 : 1);
        local bestTile = null;
        local bestScore = 0.0;

        local nearestThreatTile = null;
        local ndBest = 99;
        foreach (foe in _info.Enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe)) continue;
            local d = myTile.getDistanceTo(foe.getTile());
            if (d < ndBest) { ndBest = d; nearestThreatTile = foe.getTile(); }
        }

        foreach (dest in candidates)
        {
            if (!dest.IsEmpty || dest.ID == myTile.ID) continue;
            if (dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0) continue;
            if (_behavior.hasNegativeTileEffect(dest, _actor)) continue;
            if (!navigator.findPath(myTile, dest, settings, 0)) continue;
            local cost = navigator.getCostForPath(_actor, settings, ap, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID) continue;

            local minD = this.nearestDangerousMeleeDistAt(dest, _info.Enemies);
            if (minD <= curDist && minD <= 2) continue;
            local scr = nearestThreatTile != null ? this.countScreenBlockersBetween(dest, _actor, nearestThreatTile) : { Blockers = 0, Strong = 0 };
            local score = (minD - curDist) * 10.0 + scr.Blockers * 14.0 + scr.Strong * 6.0
                + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, "ranged") * 0.4
                - cost.ActionPointsRequired * 0.6;
            if (score > bestScore) { bestScore = score; bestTile = dest; }
        }
        return bestTile;
    },

    function nearestDangerousMeleeDistAt( _tile, _enemies )
    {
        local best = 99;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe)) continue;
            local d = _tile.getDistanceTo(foe.getTile());
            if (d < best) best = d;
        }
        return best;
    },

    // Proactive terrain repositioning when holding/waiting (climb high ground within 1-2 tiles, leave Swamp/bad terrain,
    // or anchor beside chokepoints/shieldbearers instead of sitting idle on poor ground).
    function findTacticalTerrainTile( _behavior, _actor, _info )
    {
        if (_actor.getCurrentProperties().IsRooted)
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local isShield = ::BGP.hasShield(_actor);
        local isCaster = this.isCasterRole(_actor);
        local isRanged = this.isRangedRole(_actor);
        local role = isShield ? "tank" : (isCaster ? "caster" : (isRanged ? "ranged" : "dps"));
        local curDist = this.nearestDangerousMeleeDist(_actor, _info.Enemies);
        if (curDist > 8 || curDist <= 1)
            return null;
        if (isCaster && curDist <= 3)
            return null; // Backline kite handles close threats for Mentor.

        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local reserveAP = 0;
        if (isShield)
        {
            local sw = _actor.getSkills().getSkillByID("actives.shieldwall");
            if (sw != null && !sw.isHidden() && sw.isUsable())
                reserveAP = sw.getActionPointCost();
        }
        else if (isCaster)
        {
            reserveAP = 4; // Keep enough AP for Mentor summon/weaken/raise after stepping onto high ground.
        }
        local maxMoveAP = ::Math.min(ap - reserveAP, isCaster ? 3 : 6);
        if (maxMoveAP < 2)
            return null;

        local curScore = this.scoreTerrainAdvantage(_actor, myTile, null, _info.Enemies, role);
        local maxNearbyEnemyLvl = -99;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            local ft = foe.getTile();
            if (myTile.getDistanceTo(ft) <= 6 && ft.Level > maxNearbyEnemyLvl)
                maxNearbyEnemyLvl = ft.Level;
        }
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local maxRange = (!isCaster && maxMoveAP >= 4) ? 2 : 1;
        local candidates = this.tilesInRange(myTile, 1, maxRange);
        local bestTile = null;
        local bestGain = 10.0; // Require clear meaningful terrain improvement (e.g. +1 elevation or leaving bad terrain).
        local bestHighPriority = false;

        foreach (dest in candidates)
        {
            if (!dest.IsEmpty || dest.ID == myTile.ID || _behavior.hasNegativeTileEffect(dest, _actor)) continue;
            if (dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0) continue;
            local newDist = this.nearestDangerousMeleeDistAt(dest, _info.Enemies);
            // Never step closer into enemy range while repositioning as a fragile, ranged, or caster bro.
            if (isCaster && newDist < 4) continue;
            if ((isRanged || !isShield) && newDist <= 2) continue;
            if (!isShield && newDist < curDist && curDist <= 4) continue;
            // Don't retreat farther away from the fight just to climb an even higher ridge once we already hold high ground above enemies.
            if (!isCaster && !isRanged && maxNearbyEnemyLvl > -99 && myTile.Level >= maxNearbyEnemyLvl + 1 && newDist > curDist) continue;
            if (!navigator.findPath(myTile, dest, settings, 0)) continue;
            local cost = navigator.getCostForPath(_actor, settings, maxMoveAP, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.ActionPointsRequired > maxMoveAP) continue;

            local exp = this.evaluateTileExposure(_actor, dest, _info);
            if (exp.NearAllies2 == 0) continue; // Stay connected to the company line!
            if (isCaster && exp.NearAllies2 < 2) continue;
            local highPriority = (dest.Level > myTile.Level) || (myTile.IsBadTerrain && !dest.IsBadTerrain);
            if (isCaster && !highPriority) continue;
            local destScore = this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, role);
            local gain = destScore - curScore + ::Math.min(2, exp.AdjAllies) * 2.5 - cost.ActionPointsRequired * 0.8;
            if (gain > bestGain)
            {
                bestGain = gain;
                bestTile = dest;
                bestHighPriority = highPriority;
            }
        }
        if (bestTile == null)
            return null;
        return { Tile = bestTile, HighPriority = bestHighPriority, Gain = bestGain };
    },

    // Evaluate immediate and next-turn surround exposure at a candidate tile (including 2-tile polearms like Noble Halberdiers / Ancient Polearms).
    function evaluateTileExposure( _actor, _tile, _info )
    {
        local adjEnemies = 0;
        local adjElites = 0;
        local threatDist2 = 0;
        local polearms2 = 0;
        local adjAllies = 0;
        local adjShieldAllies = 0;
        local nearAllies2 = 0;
        for (local d = 0; d < 6; ++d)
        {
            if (!_tile.hasNextTile(d)) continue;
            local adj = _tile.getNextTile(d);
            if (!adj.IsOccupiedByActor || ::Math.abs(adj.Level - _tile.Level) > 1) continue;
            local occ = adj.getEntity();
            if (occ.getID() == _actor.getID() || !occ.isAlive()) continue;
            if (occ.isAlliedWith(_actor))
            {
                ++adjAllies;
                if (::BGP.hasShield(occ) || occ.getFaction() == ::Const.Faction.PlayerAnimals)
                    ++adjShieldAllies;
            }
            else if (this.isDangerousMeleeEnemy(occ))
            {
                ++adjEnemies;
                if (this.enemyEliteScore(occ, _info) >= 1.5)
                    ++adjElites;
            }
        }
        foreach (foe in _info.Enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe)) continue;
            local ft = foe.getTile();
            if (_tile.getDistanceTo(ft) == 2)
            {
                if (foe.getIdealRange() >= 2 && ::Math.abs(ft.Level - _tile.Level) <= 1)
                    ++polearms2;
                else if (ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0)
                    ++threatDist2;
            }
        }
        foreach (bro in _info.Brothers)
        {
            if (bro.getID() == _actor.getID()) continue;
            local d = _tile.getDistanceTo(bro.getTile());
            if (d <= 2 && !this.isCasterRole(bro) && !this.isRangedRole(bro))
                ++nearAllies2;
        }
        return {
            AdjEnemies = adjEnemies,
            AdjElites = adjElites,
            ThreatDist2 = threatDist2,
            Polearms2 = polearms2,
            PotentialSurround = adjEnemies + ::Math.min(3, threatDist2 + polearms2),
            AdjAllies = adjAllies,
            AdjShieldAllies = adjShieldAllies,
            NearAllies2 = nearAllies2
        };
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

        // Identify fragile allies & Mentor we want to screen.
        local squishies = [];
        local chiefTile = null;
        foreach (bro in _info.Brothers)
        {
            if (bro.getID() == _actor.getID()) continue;
            if (this.isCasterRole(bro)) chiefTile = bro.getTile();
            if (!::BGP.hasShield(bro) || this.isRangedRole(bro) || this.isCasterRole(bro))
                squishies.push(bro.getTile());
        }

        local seen = {};
        local bestTile = null;
        local bestScore = 0.0;
        local bestUrgent = false;
        local largeBattle = _info.Enemies.len() >= 12;

        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                continue;
            local ft = foe.getTile();
            local foeElite = this.enemyEliteScore(foe, _info);
            local foeNearChief = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 3);
            local foeBreachChief = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 2 && this.isDangerousMeleeEnemy(foe));
            // Always preserve Shieldwall AP/Fat in large battles except for emergency Mentor peels;
            // allow early low-tier single-elite intercepts (<10 enemies) to pin Marauders in snow.
            local allowFullMove = (foeNearChief || (!largeBattle && foeElite >= 1.5)) && _actor.getHitpointsPct() >= (foeBreachChief ? 0.45 : 0.65);
            local effAP = allowFullMove ? ::Math.max(moveAPBudget, ::Math.min(ap, foeBreachChief ? 7 : 6)) : moveAPBudget;
            local maxTileCap = foeBreachChief ? 3 : 2;
            local effSteps = ::Math.min(maxTileCap, ::Math.max(maxSteps, (effAP / 2).tointeger()));
            if (myTile.getDistanceTo(ft) > effSteps + 1)
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
                if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.Tiles > maxTileCap)
                    continue;
                local canSWAfter = (ap - cost.ActionPointsRequired >= reserveAP)
                    && (reserveFat <= 0 || availFat - cost.FatigueRequired >= reserveFat);
                if (!canSWAfter && !allowFullMove)
                    continue;

                // Evaluate enemy exposure, elite pinning, and allied line cohesion.
                local adjEnemies = 0;
                local unengagedEnemies = 0;
                local unengagedEliteSum = 0.0;
                local pinsChiefThreat = false;
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
                        local isUneng = adj.getZoneOfControlCountOtherThan(occ.getAlliedFactions()) == 0;
                        if (isUneng)
                        {
                            ++unengagedEnemies;
                            unengagedEliteSum += this.enemyEliteScore(occ, _info);
                        }
                        if (chiefTile != null && adj.getDistanceTo(chiefTile) <= 3
                            && (adj.getDistanceTo(chiefTile) <= 2 || dest.getDistanceTo(chiefTile) < adj.getDistanceTo(chiefTile)))
                            pinsChiefThreat = true;
                    }
                    else if (occ.isAlliedWith(_actor))
                    {
                        ++adjAllies;
                        if (::BGP.hasShield(occ))
                            ++adjShieldAllies;
                    }
                }

                // Never dive solo into 3+ enemies with zero adjacent allies, or jump 2 tiles into an isolated 2+ surround,
                // or step without Shieldwall AP into 2+ enemies (or any non-Mentor intercept in large camps).
                if (adjEnemies >= 3 && adjAllies == 0)
                    continue;
                if (cost.Tiles >= 2 && adjAllies == 0 && adjEnemies >= 2 && !pinsChiefThreat)
                    continue;
                if (!canSWAfter && (adjEnemies >= 2 || (largeBattle && !pinsChiefThreat)))
                    continue;

                local score = 8.0 + ::Math.min(2, unengagedEnemies) * 5.0 + unengagedEliteSum * 8.5;
                if (pinsChiefThreat)
                    score += foeBreachChief ? 28.0 : 18.0;
                if (foeBreachChief && chiefTile != null)
                {
                    if (dest.getDistanceTo(chiefTile) < ft.getDistanceTo(chiefTile))
                        score += 8.0;
                    // When Mentor is engaged in melee (dist <= 1), reward arriving with enough AP to strike immediately instead of Shieldwalling!
                    if (ft.getDistanceTo(chiefTile) <= 1)
                    {
                        local shAtk = this.cheapestMeleeSkill(_actor, true);
                        if (shAtk != null)
                        {
                            local effSh = this.previewSkillCostsAfterMove(_actor, shAtk, cost);
                            if (ap - cost.ActionPointsRequired >= effSh.AP && availFat - cost.FatigueRequired >= effSh.Fat)
                                score += 14.0;
                        }
                    }
                }
                if (!canSWAfter)
                    score -= 4.0;
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
                        score += 4.5;
                        break;
                    }
                }
                score += (dest.Level - ft.Level) * 6.0 + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, "tank") * 0.65
                    - cost.ActionPointsRequired * 0.6;
                if (score > bestScore)
                {
                    bestScore = score;
                    bestTile = dest;
                    // Only true Mentor-breach peels override early Spearwall (870); regular intercepts stay at 850.
                    bestUrgent = pinsChiefThreat || (!largeBattle && unengagedEliteSum >= 1.5);
                }
            }
        }
        if (bestTile != null)
            return { Tile = bestTile, Urgent = bestUrgent, Score = bestScore };

        // Secondary: if an unengaged Enemy Elite or Mentor-breacher is 3-5 tiles away,
        // step 1 tile into a blocking lane directly between that threat and our Mentor/fragiles with AP left for Shieldwall/Spearwall!
        if (moveAPBudget >= 2)
        {
            local laneThreat = null;
            local laneThreatScore = 0.0;
            foreach (foe in _info.Enemies)
            {
                if (!this.isDangerousMeleeEnemy(foe)) continue;
                local ft = foe.getTile();
                if (ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0) continue;
                local dMe = myTile.getDistanceTo(ft);
                if (dMe < 3 || dMe > 5) continue;
                local es = this.enemyEliteScore(foe, _info);
                local breachCh = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 3);
                local nearCh = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 5);
                // Always allow Mentor-breach lane-blocking even under enemy ranged fire; gate regular elite blocking as before.
                if (!breachCh && _info.EnemyProjectileRanged >= 3.0) continue;
                if (largeBattle && !nearCh) continue;
                if (es < 1.4 && !nearCh) continue;
                local sc = es * 10.0 + (breachCh ? 24.0 : (nearCh ? 12.0 : 0.0)) - dMe * 2.0;
                if (sc > laneThreatScore) { laneThreatScore = sc; laneThreat = foe; }
            }
            if (laneThreat != null)
            {
                local lft = laneThreat.getTile();
                local curDist = myTile.getDistanceTo(lft);
                local bestLaneTile = null;
                local bestLaneScore = 0.0;
                for (local d = 0; d < 6; ++d)
                {
                    if (!myTile.hasNextTile(d)) continue;
                    local step = myTile.getNextTile(d);
                    if (!step.IsEmpty || _behavior.hasNegativeTileEffect(step, _actor)) continue;
                    if (step.getDistanceTo(lft) >= curDist) continue;
                    if (!navigator.findPath(myTile, step, settings, 0)) continue;
                    local cost = navigator.getCostForPath(_actor, settings, moveAPBudget, availFat);
                    if (!cost.IsComplete || cost.End == null || cost.End.ID != step.ID) continue;
                    if (ap - cost.ActionPointsRequired < reserveAP) continue;
                    if (reserveFat > 0 && availFat - cost.FatigueRequired < reserveFat) continue;
                    local adjAllies = 0;
                    for (local d2 = 0; d2 < 6; ++d2)
                    {
                        if (!step.hasNextTile(d2)) continue;
                        local nt = step.getNextTile(d2);
                        if (nt.IsOccupiedByActor && nt.getEntity().isAlliedWith(_actor) && nt.getEntity().getID() != _actor.getID())
                            ++adjAllies;
                    }
                    local ls = 10.0 + (curDist - step.getDistanceTo(lft)) * 6.0 + ::Math.min(2, adjAllies) * 4.0
                        + this.scoreTerrainAdvantage(_actor, step, myTile, _info.Enemies, "tank") * 0.7;
                    if (chiefTile != null && step.getDistanceTo(chiefTile) <= 4 && step.getDistanceTo(lft) < chiefTile.getDistanceTo(lft))
                        ls += 8.0;
                    if (ls > bestLaneScore) { bestLaneScore = ls; bestLaneTile = step; }
                }
                if (bestLaneTile != null)
                    return { Tile = bestLaneTile, Urgent = true, Score = bestLaneScore };
            }
        }
        return null;
    },

    // Dynamic safe melee routing for unshielded DPS: flank weaker/fragile/already-engaged enemies with allies,
    // avoid suicidal solo snow-dives into 3+ enemy convergence traps, and peel threats closing on Mentor.
    function findSmartDpsMeleeTile( _behavior, _actor, _info )
    {
        if (::BGP.hasShield(_actor) || this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return null;
        if (_actor.getCurrentProperties().IsRooted)
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local atk = this.cheapestMeleeSkill(_actor, true);
        if (atk == null)
            return null;

        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local minRange = atk.getMinRange();
        local maxRange = atk.getMaxRange();
        // Polearm / 2-tile weapons are already handled cleanly by autopilot_step_n_hit.
        if (maxRange >= 2)
            return null;
        // Already in melee attack range without moving.
        if (atk.isAffordable() && this.hasAdjacentTarget(_actor, atk, _info.Enemies))
            return null;

        local hasTeamTank = false;
        local chiefTile = null;
        foreach (bro in _info.Brothers)
        {
            if (bro.getID() == _actor.getID()) continue;
            if (::BGP.hasShield(bro)) hasTeamTank = true;
            if (this.isCasterRole(bro)) chiefTile = bro.getTile();
        }
        if (!hasTeamTank)
        {
            foreach (u in ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.PlayerAnimals))
            {
                if (u != null && !::MSU.isNull(u) && u.isAlive() && u.isPlacedOnMap() && u.getFlags().has("undead"))
                {
                    hasTeamTank = true;
                    break;
                }
            }
        }

        local netSkill = _actor.getSkills().getSkillByID("actives.throw_net");
        local canUseNet = netSkill != null && !netSkill.isHidden() && netSkill.isUsable() && netSkill.isAffordable()
            && (::Autopilot.conf("nets") || ::Autopilot.conf("bgpAutoEquippedNet"));
        local isFragile = this.isFragileMelee(_actor);
        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local seen = {};
        local bestTile = null;
        local bestScore = 0.0;
        local bestChiefPeel = false;

        foreach (foe in _info.Enemies)
        {
            local ft = foe.getTile();
            if (myTile.getDistanceTo(ft) > 4)
                continue;
            local fleeing = foe.getMoraleState() == ::Const.MoraleState.Fleeing;
            local foeElite = this.enemyEliteScore(foe, _info);
            local foeFragile = this.isFragileHighThreat(foe, _info);
            local foeEngaged = ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0;
            local foeNearChief = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 3 && !fleeing);
            local foeBreachChief = (chiefTile != null && !fleeing && ft.getDistanceTo(chiefTile) <= 2 && this.isDangerousMeleeEnemy(foe));

            for (local dir = 0; dir < 6; ++dir)
            {
                if (!ft.hasNextTile(dir)) continue;
                local dest = ft.getNextTile(dir);
                if (!dest.IsEmpty || dest.ID == myTile.ID || (dest.ID in seen)) continue;
                seen[dest.ID] <- true;
                if (::Math.abs(dest.Level - ft.Level) > 1) continue;
                if (_behavior.hasNegativeTileEffect(dest, _actor)) continue;
                if (!atk.isUsableOn(ft, dest)) continue;
                if (!navigator.findPath(myTile, dest, settings, 0)) continue;
                local cost = navigator.getCostForPath(_actor, settings, ap, availFat);
                if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID) continue;

                local apLeft = ap - cost.ActionPointsRequired;
                local fatLeft = availFat - cost.FatigueRequired;
                local eff = this.previewSkillCostsAfterMove(_actor, atk, cost);
                local canStrike = (apLeft >= eff.AP && fatLeft >= eff.Fat);
                local isLethalStrike = false;
                if (canStrike)
                {
                    try {
                        local hit = atk.getHitchance(foe);
                        local dmg = atk.getExpectedDamage(foe);
                        if (hit >= 40 && dmg.HitpointDamage + dmg.DirectDamage >= foe.getHitpoints())
                            isLethalStrike = true;
                    } catch (e) {}
                }

                // Critically wounded unshielded bro never re-enters melee unless securing a same-turn kill or fleeing cleanup.
                if (this.shouldWoundedRetreat(_actor, _info) && !fleeing && !isLethalStrike)
                    continue;
                // Hard anti-surround veto: never step into suicidal solo or 3+ surround pockets.
                if (!fleeing && this.isSuicidalDiveV2(_actor, dest, _info, apLeft, eff.AP))
                    continue;
                // Fragile bros must not burn all AP walking into melee with zero attack left (except healthy Mentor breach peel).
                local urgentMentorPeel = (foeBreachChief && _actor.getHitpointsPct() >= 0.45);
                if (isFragile && !canStrike && !fleeing && !urgentMentorPeel)
                    continue;

                // Never steal aggro of a full-HP Elite that our Shieldbearer/undead tank is already pinning while weaker foes live!
                local pinnedElite = this.isElitePinnedByTank(_actor, foe, _info) || this.hasAdjacentPinnedElite(_actor, dest, _info);
                if (pinnedElite && isFragile && _actor.getCurrentProperties().getMeleeDefense() < 18 && !isLethalStrike)
                    continue;

                local exp = this.evaluateTileExposure(_actor, dest, _info);
                // For sturdy late-game heavy frontliners (!isFragile, e.g. BF 2H / high-MDef Duelists),
                // only override vanilla EngageMelee for cohesive same-turn strikes beside allies, lethal finishes, or urgent Mentor peels,
                // so Vigorous Assault never launches them solo ahead of tanks and undead screens on Round 1-2.
                if (!isFragile && !fleeing)
                {
                    if (!canStrike && !urgentMentorPeel)
                        continue;
                    if (exp.AdjEnemies >= 3 || (exp.PotentialSurround >= 4 && exp.AdjShieldAllies == 0 && !urgentMentorPeel))
                        continue;
                    if (exp.AdjAllies == 0 && !isLethalStrike && !foeNearChief)
                        continue;
                }
                local score = 12.0;
                if (canStrike)
                {
                    score += 22.0 + (eff.Bonus ? 4.0 : 0.0);
                    if (isLethalStrike)
                        score += 18.0;
                }
                if (foeEngaged && !pinnedElite) score += 14.0;
                if (pinnedElite) score -= 28.0;
                if (foe.getSkills().hasSkill("effects.net") || foe.getCurrentProperties().IsStunned) score += 12.0;
                if (foeFragile) score += 11.0;
                if (!fleeing && foe.getHitpointsPct() <= 0.60) score += (0.65 - foe.getHitpointsPct()) * 16.0;
                if (foeBreachChief)
                {
                    score += 34.0;
                    if (dest.getDistanceTo(chiefTile) < ft.getDistanceTo(chiefTile))
                        score += 10.0;
                }
                else if (foeNearChief)
                {
                    score += 18.0;
                }
                // Discourage fragile unshielded DPS from solo-engaging full-HP unengaged elites when our tank/undead can pin them.
                if (isFragile && hasTeamTank && !foeEngaged && foeElite >= 1.5 && foe.getHitpointsPct() >= 0.70)
                    score -= 18.0;
                // Bonus if moving here also lets us throw our held net at an elite/high-threat target this turn.
                if (canUseNet && apLeft >= netSkill.getActionPointCost() && !fleeing && foeElite >= 1.2
                    && !foe.getSkills().hasSkill("effects.net") && !foe.getCurrentProperties().IsRooted)
                    score += 10.0;

                // Cohesion, anti-surround, and terrain/elevation scoring.
                score += ::Math.min(2, exp.AdjAllies) * 10.0 + ::Math.min(2, exp.AdjShieldAllies) * 8.0 + ::Math.min(2, exp.NearAllies2) * 3.0;
                if (exp.PotentialSurround >= 3)
                    score -= (exp.PotentialSurround - 2) * 14.0;
                if (isFragile && exp.AdjEnemies >= 2)
                    score -= 12.0;
                score += (dest.Level - ft.Level) * 7.5 + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, "dps") * 0.65
                    - cost.ActionPointsRequired * 0.8;

                if (score > bestScore)
                {
                    bestScore = score;
                    bestTile = dest;
                    bestChiefPeel = urgentMentorPeel;
                }
            }
        }
        return bestTile != null ? { Tile = bestTile, ChiefPeel = bestChiefPeel } : null;
    },

    // Smart target selection for equipped Throwing Nets (prioritizes enemy elites, Mentor-breachers, and high-MDef threats).
    function findBestNetTarget( _actor, _info )
    {
        if (!::Autopilot.conf("nets") && !::Autopilot.conf("bgpAutoEquippedNet"))
            return null;
        local skill = _actor.getSkills().getSkillByID("actives.throw_net");
        if (skill == null || skill.isHidden() || !skill.isUsable() || !skill.isAffordable())
            return null;

        local myTile = _actor.getTile();
        local maxRng = skill.getMaxRange();
        local chiefTile = null;
        foreach (bro in _info.Brothers)
        {
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }
        }

        local bestTile = null;
        local bestScore = 0.0;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            if (foe.getCurrentProperties().IsRooted || foe.getCurrentProperties().IsStunned) continue;
            if (foe.getSkills().hasSkill("effects.net")) continue;
            local ft = foe.getTile();
            if (myTile.getDistanceTo(ft) > maxRng || !skill.isUsableOn(ft, myTile)) continue;

            local elite = this.enemyEliteScore(foe, _info);
            // Never waste a net on a nearly dead non-elite trash mob.
            if (foe.getHitpoints() <= 22 && elite < 1.0)
                continue;

            local unengaged = ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0;
            local nearChief = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 3);
            local mdef = foe.getCurrentProperties().getMeleeDefense();
            local sc = 15.0 + elite * 24.0;
            if (nearChief) sc += 22.0;
            if (unengaged) sc += 14.0;
            if (mdef >= 18) sc += 12.0;
            if (foe.getHitpointsPct() >= 0.60) sc += 8.0;
            if (foe.getArmor(::Const.BodyPart.Body) >= 70) sc += 6.0;
            // Bonus if netting stops an enemy currently adjacent to a fragile ally.
            for (local d = 0; d < 6; ++d)
            {
                if (!ft.hasNextTile(d)) continue;
                local nt = ft.getNextTile(d);
                if (nt.IsOccupiedByActor && nt.getEntity().isAlliedWith(_actor) && nt.getEntity().getFaction() == ::Const.Faction.Player
                    && !::BGP.hasShield(nt.getEntity()))
                {
                    sc += 10.0;
                    break;
                }
            }
            if (sc > bestScore)
            {
                bestScore = sc;
                bestTile = ft;
            }
        }
        return bestTile != null ? { Skill = skill, Tile = bestTile, Score = bestScore } : null;
    },

    // Count free unlocked backpack slots cleanly (vanilla/Reforged item_container has getUnlockedBagSlots(), not getNumberOfEmptyBagSlots()).
    function emptyBagSlots( _items )
    {
        return ::Math.max(0, _items.getUnlockedBagSlots() - _items.getAllItemsAtSlot(::Const.ItemSlot.Bag).len());
    },

    // Smart backpack Throwing Net unbagging for ANY brother (including 2H Crossbow/Bow/Polearm backliners,
    // whom upstream autopilot_unbag_net skips due to BlockedSlotType == Offhand!):
    // requires same-turn unbag + throw AP/Fatigue and a genuinely high-threat target within exact throw_net range.
    function findBagNetPlan( _actor, _info )
    {
        if (!::Autopilot.conf("nets") && !::Autopilot.conf("bgpAutoEquippedNet"))
            return null;
        // Already holding an equipped throwing net (handled by findBestNetTarget).
        if (_actor.getSkills().hasSkill("actives.throw_net"))
            return null;
        if (_actor.getCurrentProperties().IsStunned)
            return null;
        local items = _actor.getItems();
        local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
        if (curOff != null)
        {
            local emptyAmmo = false;
            try { emptyAmmo = curOff.isItemType(::Const.Items.ItemType.Ammo) && curOff.getAmmo() == 0; } catch (e) {}
            if (!emptyAmmo)
                return null; // Never drop an active Shield or offhand tool to unbag a net.
        }
        // Keep Mentor focused on summons/spells unless an urgent melee threat is right on top of him and no free summons remain.
        local isCaster = this.isCasterRole(_actor);
        if (isCaster)
        {
            foreach (sid in ["actives.unleash_companion", "actives.pale_summon_skeleton", "actives.pale_summon_zombie"])
            {
                local sk = _actor.getSkills().getSkillByID(sid);
                if (sk != null && !sk.isHidden() && sk.isUsable() && sk.isAffordable())
                    return null;
            }
        }

        local bag = items.getAllItemsAtSlot(::Const.ItemSlot.Bag);
        if (bag.len() == 0)
            return null;
        local bestNet = null;
        local bestNetVal = -1;
        foreach (it in bag)
        {
            if (it == null) continue;
            local id = it.getID();
            if (id != "tool.throwing_net" && id != "tool.reinforced_throwing_net") continue;
            local emptyAmmo = false;
            try { emptyAmmo = it.isItemType(::Const.Items.ItemType.Ammo) && it.getAmmo() == 0; } catch (e) {}
            if (emptyAmmo) continue;
            if (it.getValue() > bestNetVal) { bestNetVal = it.getValue(); bestNet = it; }
        }
        if (bestNet == null)
            return null;

        local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
        local needUnequipMain = (curMain != null && curMain.getBlockedSlotType() == ::Const.ItemSlot.Offhand);
        if (needUnequipMain && curOff != null && this.emptyBagSlots(items) <= 0)
            return null;
        local swapList = needUnequipMain ? [curMain, bestNet] : [bestNet];
        if (!items.isActionAffordable(swapList))
            return null;

        // Probe exact runtime throw_net AP, Fatigue, Range, and target legality (Reforged: 5 AP, MaxRange 2, Reach immune check).
        local probe = null;
        local throwAP = 5;
        local throwFat = 15;
        local maxRng = 2;
        try {
            probe = ::new("scripts/skills/actives/throw_net");
            probe.setContainer(_actor.getSkills());
            try { probe.onAfterUpdate(_actor.getCurrentProperties()); } catch (e2) {}
            throwAP = probe.getActionPointCost();
            throwFat = probe.getFatigueCost();
            maxRng = probe.getMaxRange();
        } catch (e) { probe = null; }

        local swapAP = items.getActionCost(swapList);
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        // Reserve +4 Fatigue buffer so equipping the net from bag (max stamina penalty) cannot push availFat below throwFat!
        if (ap - swapAP < throwAP || availFat < throwFat + 4)
            return null;

        // With Quick Hands (0 AP swap) and a LOADED Crossbow at >= 8 AP, shoot the Crossbow FIRST (3 AP),
        // then immediately unbag (0 AP) and throw the Net (5 AP) on the same turn!
        if (needUnequipMain && swapAP == 0 && curMain != null)
        {
            local isLoadedXbow = false;
            try {
                isLoadedXbow = (curMain.isWeaponType(::Const.Items.WeaponType.Crossbow) || curMain.isWeaponType(::Const.Items.WeaponType.Firearm))
                    && curMain.isLoaded();
            } catch (e) {}
            if (isLoadedXbow && ap >= 3 + throwAP && _actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) == 0)
                return null;
        }

        // For 2H brothers WITHOUT Quick Hands (4 AP unbag + 5 AP throw + 4 AP re-equip = 13 AP across 2 turns),
        // reserve backpack nets strictly for genuine crises: adjacent attacker (d==1), Mentor breach (<=2),
        // unengaged Knight/Orc Warlord/Berserker/charger about to crash our line, or Goblin Champion.
        // Do NOT spend 13 AP netting ordinary Goblins or regular elites already pinned in our frontline ZoC!
        local highCost2H = (needUnequipMain && swapAP > 0);

        local myTile = _actor.getTile();
        local chiefTile = null;
        foreach (bro in _info.Brothers)
        {
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }
        }

        local bestTargetScore = 0.0;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            if (foe.getCurrentProperties().IsRooted || foe.getCurrentProperties().IsStunned || foe.getCurrentProperties().IsImmuneToRoot) continue;
            if (foe.getSkills().hasSkill("effects.net")) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < 1 || d > maxRng || ::Math.abs(myTile.Level - ft.Level) > 1) continue;
            if (probe != null)
            {
                local ok = false;
                try { ok = probe.isUsableOn(ft, myTile); } catch (e) { ok = false; }
                if (!ok) continue;
            }
            local elite = this.enemyEliteScore(foe, _info);
            if (foe.getHitpoints() <= 28 && elite < 1.2) continue;
            local unengaged = (ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0);
            local nearChief = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 2);
            local inMyFace = (d == 1 && (this.isRangedRole(_actor) || isCaster));
            local mdef = foe.getCurrentProperties().getMeleeDefense();
            local isGoblin = foe.getFlags().has("goblin");
            local isChampion = foe.getSkills().hasSkill("racial.champion");
            local isChargerOrApexBoss = foe.getSkills().hasSkill("effects.berserker_rage") || foe.getSkills().hasSkill("actives.charge")
                || foe.ClassName == "orc_berserker" || foe.ClassName == "orc_warlord"
                || foe.ClassName == "knight" || foe.ClassName == "rf_knight_anointed";
            local isApexThreat = isChampion || isChargerOrApexBoss
                || foe.ClassName == "rf_man_at_arms" || foe.ClassName == "noble_greatsword"
                || foe.ClassName == "rf_skeleton_legatus" || foe.ClassName == "rf_skeleton_centurion";
            local isHighThreat = false;
            if (highCost2H)
            {
                if (isGoblin)
                    isHighThreat = isChampion || inMyFace || nearChief;
                else
                    isHighThreat = inMyFace || nearChief || (unengaged && isChargerOrApexBoss);
            }
            else
            {
                isHighThreat = inMyFace || nearChief || isApexThreat || (elite >= 1.2) || (!foe.isArmedWithShield() && mdef >= 22);
            }
            if (!isHighThreat)
                continue;
            if (isCaster && !nearChief && d > 1)
                continue;

            local sc = 20.0 + elite * 24.0 + (nearChief ? 28.0 : 0.0) + (inMyFace ? 22.0 : 0.0)
                + (isApexThreat ? 18.0 : 0.0) + (unengaged ? 10.0 : 0.0) + (foe.getHitpointsPct() >= 0.50 ? 8.0 : 0.0);
            if (sc > bestTargetScore)
                bestTargetScore = sc;
        }
        if (bestTargetScore <= 0.0)
            return null;
        return { Net = bestNet, NeedUnequipMain = needUnequipMain, Score = 895.0 };
    },

    // Automatically re-equip a primary weapon from backpack whenever Mainhand is empty (e.g. right after a 2H backliner
    // unequipped their Crossbow/Bow/Polearm to throw a backpack Net!).
    function findReequipMainWeapon( _actor, _info )
    {
        local items = _actor.getItems();
        if (items.getItemAtSlot(::Const.ItemSlot.Mainhand) != null)
            return null;
        // Wait until an equipped Throwing Net has actually been thrown first.
        if (_actor.getSkills().hasSkill("actives.throw_net"))
            return null;
        local bag = items.getAllItemsAtSlot(::Const.ItemSlot.Bag);
        if (bag.len() == 0)
            return null;

        local inZoC = _actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0;
        local isRanged = this.isRangedRole(_actor);
        local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
        local best = null;
        local bestScore = -1.0;
        foreach (it in bag)
        {
            if (it == null || !it.isItemType(::Const.Items.ItemType.Weapon))
                continue;
            local is2H = it.getBlockedSlotType() == ::Const.ItemSlot.Offhand;
            if (is2H && curOff != null && this.emptyBagSlots(items) <= 0)
                continue;
            local swapList = (is2H && curOff != null) ? [curOff, it] : [it];
            if (!items.isActionAffordable(swapList))
                continue;

            local isRngWep = it.isItemType(::Const.Items.ItemType.RangedWeapon);
            local isThrow = false;
            try { isThrow = it.isWeaponType(::Const.Items.WeaponType.Throwing); } catch (e) {}
            if (isRngWep && !this.hasUsableRangedAmmo(_actor, it))
                continue;

            local sc = it.getValue().tofloat();
            if (inZoC)
            {
                if (!isRngWep) sc += 10000.0;
            }
            else if (isRanged)
            {
                if (isRngWep && !isThrow) sc += 10000.0;
                else if (isThrow) sc += 8000.0;
            }
            else
            {
                if (!isRngWep) sc += 10000.0;
            }
            if (sc > bestScore) { bestScore = sc; best = it; }
        }
        return best;
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
        // Never allow Mentor (caster) to walk forward into unscreened enemy archer sniper fire (or into sniper range when HP < 55%) or into unscreened melee range!
        if (this.isCasterRole(_actor))
        {
            local curArch = this.nearestEnemyArcherDist(myTile, decision.Info.Enemies);
            local newArch = this.nearestEnemyArcherDist(_targetTile, decision.Info.Enemies);
            local lowHpMentor = _actor.getHitpointsPct() < 0.55;
            local destHasCover = this.hasRangedCoverAt(_targetTile, _actor, decision.Info.Enemies, 8);
            if (decision.Info.EnemyProjectileRanged >= 3.0 && newArch <= 7 && newArch < curArch && (lowHpMentor || !destHasCover))
                return true;
            local curMelee = 99;
            local newMelee = 99;
            local nearestThreatTile = null;
            foreach (foe in decision.Info.Enemies)
            {
                if (!this.isLiveBacklineThreat(foe)) continue;
                local ft = foe.getTile();
                local cd = myTile.getDistanceTo(ft);
                local nd = _targetTile.getDistanceTo(ft);
                if (cd < curMelee) curMelee = cd;
                if (nd < newMelee) { newMelee = nd; nearestThreatTile = ft; }
            }
            if (newMelee <= 2)
                return true;
            if (newMelee <= 4 && newMelee < curMelee && nearestThreatTile != null)
            {
                local scr = this.countScreenBlockersBetween(_targetTile, _actor, nearestThreatTile);
                if (scr.Blockers == 0)
                    return true;
            }
            // Never walk Mentor onto an isolated tile with zero adjacent allies while live melee threats exist within 4 tiles.
            if (newMelee <= 4)
            {
                local adjAllies = 0;
                for (local d = 0; d < 6; ++d)
                {
                    if (!_targetTile.hasNextTile(d)) continue;
                    local nt = _targetTile.getNextTile(d);
                    if (nt.IsOccupiedByActor && nt.getEntity().isAlliedWith(_actor) && nt.getEntity().getID() != _actor.getID())
                        ++adjAllies;
                }
                if (adjAllies == 0)
                    return true;
            }
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
                else if (_skill.isRanged() && bodyArmor >= 90 && _skill.getID() != "actives.throw_axe")
                {
                    local weapon = _actor.getMainhandItem();
                    local isBow = weapon != null && weapon.isWeaponType(::Const.Items.WeaponType.Bow);
                    if (isBow)
                        mult *= 0.38;
                    else if (_target.isArmedWithShield())
                        mult *= 0.55;
                }
            }

            // 3b. Backline breach protection: prioritize any enemy within 2 tiles of our Mentor (1.85x) or archers (1.45x)!
            local targetTile = _target.getTile();
            local brothers = ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
            local breachMult = 1.0;
            foreach (bro in brothers)
            {
                if (::MSU.isNull(bro) || !bro.isAlive() || !bro.isPlacedOnMap()) continue;
                local isCh = this.isCasterRole(bro);
                if (isCh || this.isRangedRole(bro))
                {
                    if (targetTile.getDistanceTo(bro.getTile()) <= 2)
                    {
                        breachMult = ::Math.maxf(breachMult, isCh ? 1.85 : 1.45);
                    }
                }
            }
            mult *= breachMult;
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
            if (tSkills.hasSkill("effects.net") && !fleeing)
                mult *= 1.28;
            // Avoid wasting -15% hitchance Puncture on low-armor enemies where normal Stab deals more reliable damage.
            if (sid == "actives.puncture" && bodyArmor < 80)
                mult *= 0.22;
            // Role-differentiated focus: shieldbearers pin heavy elites; unshielded DPS melt fragile/weaker targets first.
            if (!fleeing)
            {
                local targetElite = this.enemyEliteScore(_target, null);
                if (::BGP.hasShield(_actor))
                {
                    if (targetElite >= 1.5)
                        mult *= 1.24;
                }
                else
                {
                    if (this.isFragileHighThreat(_target, null) && targetElite < 1.8)
                        mult *= 1.22;
                    else if (targetElite >= 1.8 && hp >= 100 && bodyArmor >= 75)
                        mult *= 0.86;
                }
            }
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

    // Smart weapon swapping for Crossbow/Bow + Throwing hybrids (especially Reforged perk.rf_hybridization / Quick Hands):
    // 1. Crossbow/Bow -> Throwing (free 0-AP swap): after firing Crossbow (now unloaded) or when Crossbow is unloaded
    //    and a live enemy is within 2-4 tiles with >= 4 AP left, swap free and throw Javelins/Axes (enabling Shoot + Free Swap + Throw
    //    or Unloaded -> Free Swap -> Throw x2 in one turn). Also swaps Bow -> Throwing vs armored/skeleton close targets.
    // 2. Throwing -> next Throwing bundle or back to Crossbow/Bow: immediately replace empty 0-ammo bundles; free-swap back
    //    to Crossbow/Bow when no targets remain in 4-tile throwing range (or when 3 AP left + loaded Crossbow in bag).
    function findHybridRangedSwap( _actor, _info )
    {
        if (!this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local items = _actor.getItems();
        local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
        local curOff = items.getItemAtSlot(::Const.ItemSlot.Offhand);
        if (curMain == null || !curMain.isItemType(::Const.Items.ItemType.RangedWeapon))
            return null;

        local bag = items.getAllItemsAtSlot(::Const.ItemSlot.Bag);
        if (bag.len() == 0)
            return null;

        local ap = _actor.getActionPoints();
        local isHoldingThrow = false;
        try { isHoldingThrow = curMain.isWeaponType(::Const.Items.WeaponType.Throwing); } catch (e) {}

        // Scan enemies in throwing range (2..4 + elevation) and long ranged range (2..7).
        local throwMaxRng = 4 + ::Math.max(0, myTile.Level);
        local closeLive = 0;
        local closeArmoredOrSkel = 0;
        local closeSkel = 0;
        local longLive = 0;
        local anyLive = 0;
        foreach (foe in _info.Enemies)
        {
            local d = myTile.getDistanceTo(foe.getTile());
            if (d < 2) continue;
            local active = foe.getMoraleState() != ::Const.MoraleState.Fleeing;
            if (active) ++anyLive;
            if (d <= throwMaxRng && (active || anyLive == 0))
            {
                ++closeLive;
                if (foe.getFlags().has("skeleton"))
                {
                    ++closeSkel;
                    ++closeArmoredOrSkel;
                }
                else if (foe.getArmor(::Const.BodyPart.Body) >= 120)
                {
                    ++closeArmoredOrSkel;
                }
            }
            if (d >= 5 && d <= 7 + ::Math.max(0, myTile.Level) && active)
                ++longLive;
        }

        // Locate best loaded Throwing bundle and best usable Crossbow/Bow in backpack.
        local bestThrow = null;
        local bestThrowScore = -1.0;
        local bestLongRanged = null;
        local bestLongLoaded = false;
        local bestLongScore = -1.0;
        foreach (it in bag)
        {
            if (it == null || !it.isItemType(::Const.Items.ItemType.Weapon))
                continue;
            local isThrow = false;
            try { isThrow = it.isWeaponType(::Const.Items.WeaponType.Throwing); } catch (e) {}
            if (isThrow)
            {
                local ammo = 0;
                try { ammo = it.getAmmo(); } catch (e) {}
                if (ammo <= 0) continue;
                local sc = it.getValue().tofloat();
                local isAxe = false;
                try { isAxe = it.isWeaponType(::Const.Items.WeaponType.Axe); } catch (e) {}
                if (closeSkel > 0 && isAxe) sc += 5000.0;
                else if (closeSkel == 0 && !isAxe) sc += 1000.0;
                if (sc > bestThrowScore) { bestThrowScore = sc; bestThrow = it; }
            }
            else if (it.isItemType(::Const.Items.ItemType.RangedWeapon) && this.hasUsableRangedAmmo(_actor, it))
            {
                local loaded = false;
                try { loaded = it.isLoaded(); } catch (e) {}
                local sc = it.getValue().tofloat() + (loaded ? 3000.0 : 0.0);
                if (sc > bestLongScore) { bestLongScore = sc; bestLongRanged = it; bestLongLoaded = loaded; }
            }
        }

        // Minimum AP needed for one throw (2 AP if Reforged Opportunist is primed/active on turns 1-2, otherwise 4 AP).
        local minThrowAP = 4;
        local opp = _actor.getSkills().getSkillByID("perk.rf_opportunist");
        if (opp != null)
        {
            try {
                if (opp.m.IsPrimed) minThrowAP = 0;
                else if (opp.m.AttacksRemaining > 0 && opp.m.TurnsRemaining > 0) minThrowAP = 2;
            } catch (e) {}
        }

        // Case 1: Currently holding Crossbow/Bow/Firearm -> consider free swap to loaded Throwing weapon.
        if (!isHoldingThrow)
        {
            if (bestThrow == null || closeLive == 0)
                return null;
            local swapList = [curMain, bestThrow];
            if (!items.isActionAffordable(swapList))
                return null;
            local swapAP = items.getActionCost(swapList);
            local curHasAmmo = this.hasUsableRangedAmmo(_actor, curMain);
            // Require 0-AP free swap (perk.rf_hybridization / perk.quick_hands) unless current ranged weapon is completely out of ammo.
            if (swapAP > 0 && curHasAmmo)
                return null;
            if (ap - swapAP < minThrowAP)
                return null;
            if (curHasAmmo && (_actor.getFatigueMax() - _actor.getFatigue()) < 12)
                return null;

            local isCrossbowOrGun = false;
            local isBow = false;
            try {
                isCrossbowOrGun = curMain.isWeaponType(::Const.Items.WeaponType.Crossbow) || curMain.isWeaponType(::Const.Items.WeaponType.Firearm);
                isBow = curMain.isWeaponType(::Const.Items.WeaponType.Bow);
            } catch (e) {}

            local shouldSwap = !curHasAmmo;
            if (!shouldSwap && isCrossbowOrGun)
            {
                // Shoot loaded Crossbow FIRST (3 AP -> becomes unloaded); then immediately free-swap & Throw with remaining >= 4 AP!
                // If Crossbow starts the turn unloaded, free-swap immediately to Throw x2 instead of spending 4 AP reloading!
                local loaded = false;
                try { loaded = curMain.isLoaded(); } catch (e) {}
                if (!loaded)
                    shouldSwap = true;
            }
            else if (!shouldSwap && isBow)
            {
                // Swap Bow -> Throwing when close targets are armored or skeletons (or Throwing Mastery gives huge close-range burst).
                if (closeArmoredOrSkel > 0 || _actor.getSkills().hasSkill("perk.mastery.throwing"))
                    shouldSwap = true;
            }
            if (shouldSwap)
                return { Weapon = bestThrow, Score = 685.0, EmptyBundle = false };
            return null;
        }

        // Case 2: Currently holding a Throwing weapon.
        local curAmmo = 0;
        try { curAmmo = curMain.getAmmo(); } catch (e) {}

        // 2a. Current Throwing bundle is empty (0 ammo): replace with another loaded bundle or switch back to Crossbow/Bow.
        if (curAmmo <= 0)
        {
            local targetWep = (bestThrow != null && closeLive > 0) ? bestThrow : (bestLongRanged != null ? bestLongRanged : bestThrow);
            if (targetWep == null)
                return null;
            if (curOff != null && targetWep.getBlockedSlotType() == ::Const.ItemSlot.Offhand && this.emptyBagSlots(items) <= 0)
                return null;
            local swapList = (curOff != null && targetWep.getBlockedSlotType() == ::Const.ItemSlot.Offhand) ? [curMain, curOff, targetWep] : [curMain, targetWep];
            if (!items.isActionAffordable(swapList))
                return null;
            return { Weapon = targetWep, Score = 720.0, EmptyBundle = true };
        }

        // 2b. Current Throwing bundle still has ammo: free-swap back to Crossbow/Bow if:
        //   - No target in throwing range AND enemies exist at 5-7 tiles (long range), OR
        //   - Cannot afford another throw (ap == 3 < minThrowAP) AND bag holds a LOADED Crossbow ready to fire for 3 AP!
        if (bestLongRanged != null)
        {
            if (curOff != null && bestLongRanged.getBlockedSlotType() == ::Const.ItemSlot.Offhand && this.emptyBagSlots(items) <= 0)
                return null;
            local swapList = (curOff != null && bestLongRanged.getBlockedSlotType() == ::Const.ItemSlot.Offhand) ? [curMain, curOff, bestLongRanged] : [curMain, bestLongRanged];
            if (items.isActionAffordable(swapList))
            {
                local swapAP = items.getActionCost(swapList);
                if (swapAP == 0)
                {
                    if (closeLive == 0 && longLive > 0 && ap >= 3)
                        return { Weapon = bestLongRanged, Score = 680.0, EmptyBundle = false };
                    if (ap < minThrowAP && ap >= 3 && bestLongLoaded && (closeLive > 0 || longLive > 0))
                        return { Weapon = bestLongRanged, Score = 680.0, EmptyBundle = false };
                }
            }
        }
        return null;
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

    // Check if an enemy can genuinely reach/strike our backliner from <= 2 tiles (either UNENGAGED and not rooted/netted, or polearm/2-tile weapon, or Wolfrider/Footwork).
    function isLiveBacklineThreat( _foe )
    {
        if (!this.isDangerousMeleeEnemy(_foe))
            return false;
        local ft = _foe.getTile();
        if (_foe.getIdealRange() >= 2)
            return true;
        if (_foe.getCurrentProperties().IsRooted || _foe.getSkills().hasSkill("effects.net"))
            return false;
        if (ft.getZoneOfControlCountOtherThan(_foe.getAlliedFactions()) == 0)
            return true;
        local s = _foe.getSkills();
        return s.hasSkill("actives.footwork") || s.hasSkill("actives.werewolf_bite");
    },

    // Rate whether a live melee threat near Mentor is truly dangerous (high burst/elite/polearm/swarm/hurt-or-fragile Mentor)
    // vs a lone low-threat fodder unit (Zombie, Ancient Auxiliary, Goblin Skirmisher) that a healthy armored/Nimble Mentor can tolerate briefly.
    function isHighBacklineThreat( _actor, _foe, _info )
    {
        if (_actor.getHitpointsPct() <= 0.65)
            return true;
        local aSkills = _actor.getSkills();
        if (!aSkills.hasSkill("perk.nimble") && !aSkills.hasSkill("perk.battle_forged")
            && _actor.getArmor(::Const.BodyPart.Body) < 70)
            return true;
        if (this.isHeavyMeleeThreat(_foe) || this.enemyEliteScore(_foe, _info) >= 1.2)
            return true;
        if (_foe.getIdealRange() >= 2)
            return true;
        local cn = _foe.ClassName;
        if (cn == "orc_berserker" || cn == "goblin_wolfrider" || cn == "ghost" || cn == "rf_banshee")
            return true;
        local fs = _foe.getSkills();
        return fs.hasSkill("actives.ghastly_touch") || fs.hasSkill("actives.werewolf_bite") || fs.hasSkill("effects.berserker_rage");
    },

    function assessBacklineThreat( _actor, _info )
    {
        local myTile = _actor.getTile();
        local nearestDist = 99;
        local nearestTile = null;
        local highNearestDist = 99;
        local highNearestTile = null;
        local closeCount2 = 0;
        foreach (foe in _info.Enemies)
        {
            if (!this.isLiveBacklineThreat(foe))
                continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < nearestDist) { nearestDist = d; nearestTile = ft; }
            if (d <= 2) ++closeCount2;
            if (this.isHighBacklineThreat(_actor, foe, _info) && d < highNearestDist)
            {
                highNearestDist = d;
                highNearestTile = ft;
            }
        }
        // Two or more live melee threats within 2 tiles always escalate to urgent high threat.
        local urgentHigh = (highNearestDist <= 2) || (closeCount2 >= 2);
        local unscreenedHigh3 = (!urgentHigh && highNearestDist == 3 && highNearestTile != null
            && this.countScreenBlockersBetween(myTile, _actor, highNearestTile).Blockers == 0);
        return {
            NearestDist = nearestDist,
            NearestTile = nearestTile,
            HighDist = highNearestDist,
            HighTile = highNearestTile,
            CloseCount2 = closeCount2,
            UrgentHigh = urgentHigh,
            UnscreenedHigh3 = unscreenedHigh3,
            LowThreatClose = (!urgentHigh && nearestDist <= 2)
        };
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

    // Check if adjacent allies (exact Battle Brothers dist == 1 soft ranged cover: +50% obstruction) block enemy shooters' line of fire to _tile.
    // Note: an ally at dist == 2 does NOT grant BB ranged cover! Require zero unobstructed shooters within 7 tiles and >= 75% covered overall.
    function hasRangedCoverAt( _tile, _actor, _enemies, _maxDist = 9 )
    {
        local shooters = [];
        foreach (foe in _enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing || !foe.isArmedWithRangedWeapon())
                continue;
            local w = foe.getMainhandItem();
            if (w != null && w.isItemType(::Const.Items.ItemType.Ammo))
                continue;
            local ft = foe.getTile();
            local d = _tile.getDistanceTo(ft);
            if (d <= _maxDist)
                shooters.push({ Tile = ft, Dist = d });
        }
        if (shooters.len() == 0)
            return true;

        local adjBlockers = [];
        for (local dir = 0; dir < 6; ++dir)
        {
            if (!_tile.hasNextTile(dir)) continue;
            local nt = _tile.getNextTile(dir);
            if (!nt.IsOccupiedByActor) continue;
            local occ = nt.getEntity();
            if (occ == null || ::MSU.isNull(occ) || !occ.isAlive() || occ.isDying()) continue;
            if (occ.getID() != _actor.getID() && occ.isAlliedWith(_actor))
                adjBlockers.push(nt);
        }
        if (adjBlockers.len() == 0)
            return false;

        local covered = 0;
        local uncoveredClose = 0;
        foreach (sh in shooters)
        {
            local isBlocked = false;
            foreach (bt in adjBlockers)
            {
                if (bt.getDistanceTo(sh.Tile) < sh.Dist)
                {
                    isBlocked = true;
                    break;
                }
            }
            if (isBlocked)
                ++covered;
            else if (sh.Dist <= 7)
                ++uncoveredClose;
        }
        return uncoveredClose == 0 && covered * 4 >= shooters.len() * 3;
    },

    // Find a safe kiting/ally-screened tile for backline casters and ranged units under melee or sniper pressure.
    function findBacklineSafeTile( _behavior, _actor, _info )
    {
        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local isCaster = this.isCasterRole(_actor);
        if (_actor.getCurrentProperties().IsRooted)
            return null;

        local threat = this.assessBacklineThreat(_actor, _info);
        local curMeleeDist = threat.NearestDist;
        local nearestThreatTile = threat.HighTile != null ? threat.HighTile : threat.NearestTile;
        local curScreen = (isCaster && nearestThreatTile != null)
            ? this.countScreenBlockersBetween(myTile, _actor, nearestThreatTile)
            : { Blockers = 1, Strong = 0 };
        local meleeDanger = isCaster
            ? (threat.UrgentHigh || threat.UnscreenedHigh3 || threat.LowThreatClose)
            : (curMeleeDist <= 2);
        local curArcherDist = isCaster ? this.nearestEnemyArcherDist(myTile, _info.Enemies) : 99;
        local lowHpMentor = isCaster && _actor.getHitpointsPct() < 0.55;
        local sniperRange = _info.EnemyProjectileRanged >= 5.0 ? (lowHpMentor ? 9 : 8) : 7;
        local hasCoverNow = isCaster ? this.hasRangedCoverAt(myTile, _actor, _info.Enemies, sniperRange) : true;
        // Stay put and keep casting when frontline allies block enemy ranged line of fire, unless Mentor HP drops below 55%.
        local sniperDanger = isCaster && _info.EnemyProjectileRanged >= 2.0 && curArcherDist <= sniperRange && (!hasCoverNow || lowHpMentor);

        if (!meleeDanger && !sniperDanger)
            return null;

        // Threat-tiered AP budget for Mentor:
        // - Urgent high threat (dist <= 2 or swarm or fragile/hurt): up to 6 AP (escapes snow/swamp).
        // - Unscreened high threat at dist 3: up to 4 AP (leaves AP for spells).
        // - Single low-threat fodder at dist 2 (healthy armored/Nimble Mentor): cheap 2-AP sidestep only (never burns a spell turn!).
        // - Sniper exposure with >= 55% HP: prefer a cheap 2-AP step behind cover so Mentor still casts spells.
        local maxMoveAP = 0;
        if (isCaster)
        {
            if (threat.UrgentHigh)
                maxMoveAP = ::Math.min(ap, 6);
            else if (threat.UnscreenedHigh3)
                maxMoveAP = ::Math.min(ap, 4);
            else if (threat.LowThreatClose && !sniperDanger)
                maxMoveAP = ::Math.min(ap, 2);
            else if (sniperDanger && !lowHpMentor)
                maxMoveAP = ::Math.min(ap, 2);
            else
                maxMoveAP = ap >= 7 ? 4 : (ap <= 2 ? ap : ::Math.min(ap - 3, 2));
        }
        else
        {
            maxMoveAP = ap >= 6 ? 2 : 0;
        }
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
            local destNearestThreat = null;
            foreach (foe in _info.Enemies)
            {
                if (!this.isLiveBacklineThreat(foe))
                    continue;
                local ft = foe.getTile();
                local d = dest.getDistanceTo(ft);
                if (d < minMeleeDist) { minMeleeDist = d; destNearestThreat = ft; }
            }
            local newArcherDist = isCaster ? this.nearestEnemyArcherDist(dest, _info.Enemies) : 99;
            local newCover = isCaster ? this.hasRangedCoverAt(dest, _actor, _info.Enemies, sniperRange) : false;
            local newScreen = (isCaster && destNearestThreat != null)
                ? this.countScreenBlockersBetween(dest, _actor, destNearestThreat)
                : { Blockers = 0, Strong = 0 };

            // Allow stepping behind a friendly blocker at same distance if we were unscreened at dist 3, otherwise require more distance.
            if (meleeDanger && minMeleeDist < curMeleeDist)
                continue;
            if (meleeDanger && minMeleeDist == curMeleeDist && !(newScreen.Blockers > curScreen.Blockers && minMeleeDist >= 3))
                continue;
            if (!meleeDanger && sniperDanger)
            {
                if (minMeleeDist <= 2) continue;
                if (newArcherDist <= curArcherDist && !(newCover && !hasCoverNow)) continue;
            }

            // Strongly prefer staying behind friendly melee/shield/undead blockers rather than isolating into an open corner.
            local nearAllies = 0;
            local openExits = 0;
            foreach (bro in _info.Brothers)
            {
                if (bro.getID() == _actor.getID()) continue;
                local d = dest.getDistanceTo(bro.getTile());
                if (d <= 2 && !this.isRangedRole(bro) && !this.isCasterRole(bro))
                    ++nearAllies;
            }
            foreach (u in ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.PlayerAnimals))
            {
                if (u != null && !::MSU.isNull(u) && u.isAlive() && u.isPlacedOnMap() && dest.getDistanceTo(u.getTile()) <= 2)
                    ++nearAllies;
            }
            for (local dir = 0; dir < 6; ++dir)
            {
                if (dest.hasNextTile(dir) && dest.getNextTile(dir).IsEmpty)
                    ++openExits;
            }

            local score = 0.0;
            if (meleeDanger)
            {
                score += (minMeleeDist - curMeleeDist) * 12.0;
                if (newScreen.Blockers > 0)
                    score += 18.0 + (newScreen.Strong > 0 ? 8.0 : 0.0);
                if (nearAllies == 0)
                    score -= 14.0;
            }
            if (sniperDanger)
                score += ::Math.max(0, newArcherDist - curArcherDist) * 8.0 + (newArcherDist >= 8 ? 10.0 : 0.0) + (newCover ? (lowHpMentor ? 8.0 : 16.0) : 0.0);
            score += ::Math.min(3, nearAllies) * 4.0 + ::Math.min(3, openExits) * 1.2
                + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, isCaster ? "caster" : "ranged") * 0.55
                - cost.ActionPointsRequired * 1.0;
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

    // Strict anti-surround check: catches immediate 3+ surrounds, next-turn 2-tile convergence traps,
    // zero-attack solo snow-dives by fragile unshielded bros, and critically wounded suicides.
    function isSuicidalDiveV2( _actor, _destTile, _info, _apAfter = 9, _effMinAtkAP = null )
    {
        if (_destTile == null || ::BGP.hasShield(_actor) || this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return false;
        if (_actor.getTile().ID == _destTile.ID || _actor.getSkills().hasSkill("effects.indomitable"))
            return false;
        local exp = this.evaluateTileExposure(_actor, _destTile, _info);
        local skills = _actor.getSkills();
        local hasDefPerk = skills.hasSkill("perk.battle_forged") || skills.hasSkill("perk.nimble");
        local hasUnderdog = skills.hasSkill("perk.underdog");
        local mdef = _actor.getCurrentProperties().getMeleeDefense();
        local isFragile = this.isFragileMelee(_actor);
        local atk = _effMinAtkAP == null ? this.cheapestMeleeSkill(_actor, true) : null;
        local minAtkAP = _effMinAtkAP != null ? _effMinAtkAP : (atk != null ? atk.getActionPointCost() : 4);
        local hpPct = _actor.getHitpointsPct();

        if (exp.AdjEnemies >= 4)
            return true;
        if (exp.AdjEnemies >= 3 && (exp.AdjAllies == 0 || (exp.AdjShieldAllies == 0 && (mdef < 35 || isFragile))))
            return true;
        // Never walk into a Halberdier/Polearm kill-box (2+ adjacent + 2+ reach-2 polearms) with zero shield support and zero attack AP left!
        if (exp.AdjEnemies >= 2 && exp.Polearms2 >= 2 && exp.AdjShieldAllies == 0 && _apAfter < minAtkAP && mdef < 35)
            return true;
        if (exp.AdjEnemies >= 2 && exp.AdjAllies == 0 && _apAfter < minAtkAP && (exp.Polearms2 >= 1 || exp.ThreatDist2 >= 2) && mdef < 30)
            return true;
        if (!hasDefPerk && !hasUnderdog && exp.AdjEnemies >= 3 && exp.AdjShieldAllies == 0)
            return true;
        if (isFragile && exp.AdjAllies == 0 && exp.AdjEnemies >= 2)
            return true;
        if (isFragile && exp.AdjAllies == 0 && exp.AdjEnemies >= 1 && exp.ThreatDist2 >= 2)
            return true;
        // Prevent fragile low-MDef 1H unshielded bros from burning AP walking into melee contact with zero AP left to strike
        // against non-ranged/non-caster melee waves (do NOT paralyze 2H 6-AP heavy frontliners who normally move 2 tiles!).
        if (isFragile && mdef < 18 && minAtkAP <= 4 && _apAfter < minAtkAP)
        {
            if (exp.AdjEnemies >= 2)
                return true;
            if (exp.AdjAllies == 0 && (exp.AdjEnemies >= 1 || exp.ThreatDist2 >= 2))
                return true;
            if (exp.PotentialSurround >= 3 && exp.AdjShieldAllies == 0)
                return true;
            local urgentAdvance = _info.EnemyProjectileRanged >= 3.0 || _info.EnemyUrgentCasters > 0 || _info.EnemyChargers >= 3;
            if (!urgentAdvance && exp.AdjEnemies >= 1 && exp.AdjShieldAllies == 0)
            {
                // Still allow peeling an enemy standing within 2 tiles of our Mentor.
                local peelingChief = false;
                foreach (bro in _info.Brothers)
                {
                    if (this.isCasterRole(bro) && _destTile.getDistanceTo(bro.getTile()) <= 2)
                    {
                        peelingChief = true;
                        break;
                    }
                }
                if (!peelingChief)
                    return true;
            }
        }
        if (this.shouldWoundedRetreat(_actor, _info) && exp.AdjEnemies >= 1)
            return true;
        if (hpPct <= 0.35 && mdef < 18 && (exp.AdjEnemies >= 2 || (exp.AdjEnemies >= 1 && exp.AdjAllies == 0)))
            return true;
        return false;
    },

    // Check if a target enemy is afflicted by any necromantic debuff.
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

        // Trigger 1: Emergency survival / peel (stricter on Round 1; on Round 2 allow fragile unshielded owners in 2+ melee to peel early).
        local emergencySurvival = (round <= 1)
            ? ((meleeAdj >= 3 && (!isShield || hpPct <= 0.60))
                || (meleeAdj >= 1 && hpPct <= 0.50))
            : (round == 2)
                ? ((meleeAdj >= 3 && (!isShield || hpPct <= 0.60))
                    || (meleeAdj >= 2 && this.isFragileMelee(_entity))
                    || (meleeAdj >= 1 && hpPct <= 0.55)
                    || (fragileThreatTile != null))
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

// Prevent shieldbearers with Reforged Line Breaker from breaking Phalanx cohesion or diving into surrounds.
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

// Skip Break Free for safe backline ranged/caster units when no immediate threat is in range.
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

// Gate ai_engage_melee during hold-line, shieldbearer yield, or suicidal unshielded dives into 3+ enemy surrounds.
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
            && this.m.TargetTile != null && !this.m.IsWaitingBeforeMove)
        {
            local info = F.assessBattle(_entity, this.getAgent());
            local myTile = _entity.getTile();
            local ap = _entity.getActionPoints();
            local approxApAfter = ap;
            local effAtkAP = null;
            try {
                local nav = ::Tactical.getNavigator();
                local st = F.navSettings(_entity, nav);
                if (nav.findPath(myTile, this.m.TargetTile, st, 0))
                {
                    local cost = nav.getCostForPath(_entity, st, ap, _entity.getFatigueMax() - _entity.getFatigue());
                    if (cost.Tiles > 0)
                    {
                        approxApAfter = ap - cost.ActionPointsRequired;
                        local atk = F.cheapestMeleeSkill(_entity, true);
                        if (atk != null)
                            effAtkAP = F.previewSkillCostsAfterMove(_entity, atk, cost).AP;
                    }
                }
                else
                {
                    local stepCost = _entity.getActionPointCosts()[this.m.TargetTile.Type];
                    if (stepCost < 2) stepCost = 2;
                    approxApAfter = ap - myTile.getDistanceTo(this.m.TargetTile) * stepCost;
                }
            } catch (e) {
                local stepCost = this.m.TargetTile.IsBadTerrain ? 3 : 2;
                approxApAfter = ap - myTile.getDistanceTo(this.m.TargetTile) * stepCost;
            }
            local veto = F.isSuicidalDiveV2(_entity, this.m.TargetTile, info, approxApAfter, effAtkAP);
            // Keep critically wounded unshielded melee bros (free of ZoC) from undoing wounded_retreat via EngageMelee!
            if (!veto && F.shouldWoundedRetreat(_entity, info)
                && myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) == 0
                && this.m.TargetTile.ID != myTile.ID
                && (this.m.TargetActor == null || ::MSU.isNull(this.m.TargetActor) || this.m.TargetActor.getMoraleState() != ::Const.MoraleState.Fleeing))
            {
                veto = true;
            }
            // Also block fragile 1-tile DPS from stepping adjacent to ANY Elite already pinned by our Shieldbearer/undead tank while weaker foes live.
            if (!veto && !::BGP.hasShield(_entity) && !F.isRangedRole(_entity) && !F.isCasterRole(_entity)
                && _entity.getCurrentProperties().getMeleeDefense() < 18
                && ((this.m.TargetActor != null && !::MSU.isNull(this.m.TargetActor) && F.isElitePinnedByTank(_entity, this.m.TargetActor, info))
                    || F.hasAdjacentPinnedElite(_entity, this.m.TargetTile, info)))
            {
                veto = true;
            }
            // Penalize walking off high ground into uphill/bad-terrain fights against melee-only enemies when not lethal.
            if (!veto && !::BGP.hasShield(_entity) && info.EnemyProjectileRanged < 3.0 && info.EnemyUrgentCasters == 0
                && this.m.TargetTile.ID != myTile.ID && this.m.TargetActor != null && !::MSU.isNull(this.m.TargetActor)
                && this.m.TargetActor.getMoraleState() != ::Const.MoraleState.Fleeing)
            {
                local tgtLvl = this.m.TargetActor.getTile().Level;
                local destLvl = this.m.TargetTile.Level;
                local badJump = this.m.TargetTile.IsBadTerrain && !myTile.IsBadTerrain;
                if ((destLvl < tgtLvl || destLvl < myTile.Level || badJump) && F.isFragileMelee(_entity))
                {
                    local reqAP = effAtkAP != null ? effAtkAP : 4;
                    if (approxApAfter < reqAP)
                        veto = true;
                    else
                        this.m.Score *= 0.45;
                }
            }
            // Also stop shieldbearers from being dragged by vanilla EngageMelee into 3+ enemy surrounds without Shieldwall AP.
            if (!veto && ::BGP.hasShield(_entity) && this.m.TargetTile.ID != myTile.ID)
            {
                local exp = F.evaluateTileExposure(_entity, this.m.TargetTile, info);
                local sw = _entity.getSkills().getSkillByID("actives.shieldwall");
                local swAP = (sw != null && !sw.isHidden() && sw.isUsable()) ? sw.getActionPointCost() : 4;
                if (exp.AdjEnemies >= 3 && (exp.AdjAllies == 0 || (approxApAfter < swAP && _entity.getCurrentProperties().getMeleeDefense() < 40)))
                    veto = true;
            }
            if (veto)
            {
                // Hard veto suicidal solo/3+ surround dives so BGP_Frontline dynamic routing or Wait takes over.
                this.m.TargetTile = null;
                this.m.TargetActor = null;
                this.m.Score = 0;
            }
        }
        return done;
    };
});

// Prevent unengaged brothers who just raised Spearwall from burning 20 extra fatigue stacking vanilla Shieldwall on the same turn,
// and prevent shieldbearers peeling a melee enemy off Mentor from wasting attack AP on Shieldwall instead of striking!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_defend_shieldwall", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
        {
            if (_entity.getSkills().hasSkill("effects.spearwall")
                && _entity.getTile().getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) == 0)
            {
                return ::Const.AI.Behavior.Score.Zero;
            }
            if (::BGP.hasShield(_entity) && F.isPeelingMentorMelee(_entity, F.assessBattle(_entity, this.getAgent())))
            {
                return ::Const.AI.Behavior.Score.Zero;
            }
        }
        return __original(_entity);
    };
});

// Let BGP_Frontline handle smart Throwing Net unbagging & targeting when bgpSmartFrontline is enabled so nets are not wasted on trash
// or unbagged without a valid same-turn target.
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_throw_net", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
        {
            this.m.Thread = null;
            this.m.TargetTile = null;
            this.m.Skill = null;
            this.m.Score = 0;
            return true;
        }
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/autopilot_unbag_net", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
            return ::Const.AI.Behavior.Score.Zero;
        return __original(_entity);
    };
});

// Guard upstream autopilot_swap_quiver against throwing weapons (ItemType.Ammo without getAmmoType()) crashing in an infinite loop when a quiver empties!
::BGP.HooksMod.hook("scripts/ai/autopilot_swap_quiver", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        this.m.QuiverToEquip = null;
        local scoreMult = this.getProperties().BehaviorMult[this.m.ID];
        if (_entity.getMoraleState() == ::Const.MoraleState.Fleeing || _entity.getCurrentProperties().IsStunned)
            return 0;
        if (!_entity.getItems().isActionAffordable([]) || this.queryTargetsInMeleeRange().len() != 0)
            return 0;
        local ammoItem = _entity.getItems().getItemAtSlot(::Const.ItemSlot.Ammo);
        if (ammoItem == null || ammoItem.getAmmo() != 0)
            return 0;
        local ammoType = null;
        try { ammoType = ammoItem.getAmmoType(); } catch (e) { return 0; }
        local bestQuiver = null;
        foreach (item in _entity.getItems().getAllItemsAtSlot(::Const.ItemSlot.Bag))
        {
            if (item == null || item.getSlotType() != ::Const.ItemSlot.Ammo)
                continue;
            local itType = null;
            try { itType = item.getAmmoType(); } catch (e) { continue; }
            if (item.getAmmo() > 0 && itType == ammoType)
            {
                if (bestQuiver == null || item.getAmmo() > bestQuiver.getAmmo())
                    bestQuiver = item;
            }
        }
        if (bestQuiver == null)
            return 0;
        this.m.QuiverToEquip = bestQuiver;
        return ::Const.AI.Behavior.Score.AP_SwapQuiver * scoreMult;
    };
});

// Prevent vanilla SwitchToMelee (6000 score when Mainhand == null!) / SwitchToRanged from hijacking a 2H backliner
// right after unbag_net (before throw_net fires) or right after throwing a net (before reequip_main restores their Bow/Crossbow)!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_switchto_melee", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
        {
            local hasNet = _entity.getSkills().hasSkill("actives.throw_net");
            local emptyMain = _entity.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand) == null;
            if (hasNet || emptyMain)
            {
                local info = F.assessBattle(_entity, this.getAgent());
                if (hasNet && F.findBestNetTarget(_entity, info) != null)
                    return ::Const.AI.Behavior.Score.Zero;
                if (emptyMain && F.findReequipMainWeapon(_entity, info) != null)
                    return ::Const.AI.Behavior.Score.Zero;
            }
        }
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_switchto_ranged", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
        {
            if (_entity.getSkills().hasSkill("actives.throw_net"))
            {
                local info = F.assessBattle(_entity, this.getAgent());
                if (F.findBestNetTarget(_entity, info) != null)
                    return ::Const.AI.Behavior.Score.Zero;
            }
        }
        return __original(_entity);
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

// Track last round player-side Curse of Ages was cast for 2-round AI pacing cooldown.
::BGP.HooksMod.hook("scripts/skills/actives/bgp_necro_curse_of_ages_skill", function(q) {
    q.onUse = @(__original) function( _user, _targetTile ) {
        local ret = __original(_user, _targetTile);
        if (ret && _user != null && !::MSU.isNull(_user) && _user.getFaction() == ::Const.Faction.Player)
            F.battleState().LastCurseRound = ::Time.getRound();
        return ret;
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
