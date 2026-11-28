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
    local enemyHasNecro = false;
    local liveEnemies = 0;
    foreach (et in c.Enemies) {
        local foe = et.getEntity();
        if (foe.getMoraleState() != ::Const.MoraleState.Fleeing) ++liveEnemies;
        if (foe.getSkills().hasSkill("actives.raise_undead")) enemyHasNecro = true;
    }
    // Prioritize Raise Dead while building/rebuilding the undead frontline, and aggressively deny high-value corpses vs enemy Necromancers!
    local urgencyBonus = 0.0;
    if (::Autopilot.conf("bgpSmartFrontline")) {
        if (aliveUndead < 4)
            urgencyBonus = 2.2;
        else if (aliveUndead < 6 && ::Time.getRound() >= 2)
            urgencyBonus = 1.2;
        // Champion-route casters rely on Raise Dead to maintain meatshields alongside Lich King (no Curse/CE).
        if (aliveUndead < 5 && !c.Actor.getSkills().hasSkill("actives.bgp_corpse_explosion"))
            urgencyBonus += 1.0;
        if (enemyHasNecro) {
            urgencyBonus += 2.2;
            // Steal Fallen Hero / heavy-armor corpses FIRST before the enemy Necromancer raises them!
            if (A.corpseValue(t) >= 1.1)
                urgencyBonus += 1.5;
        }
    }
    local score = (distance <= 2 ? 7.0 : distance <= 5 ? 5.9 : 3.2) + A.corpseValue(t) * 1.6 + shutdownBonus + backlineScreenBonus + urgencyBonus
        + (c.Engaged && c.Origin.getDistanceTo(t) <= 2 ? 0.9 : 0)
        - (pressure > 2 ? 0.65 : 0) - (c.Behavior.hasNegativeTileEffect(t, c.Actor) ? 1.1 : 0);
    // Endgame cleanup discipline: when <= 2 active enemies remain (or <= 3 from round 14+), no enemy Necromancer is alive,
    // and 5+ undead already swarm them, throttle redundant Raise Dead so Mentor finishes holdouts with armor-ignoring pale_weaken / buffs!
    if (::Autopilot.conf("bgpSmartFrontline") && (liveEnemies <= 2 || (liveEnemies <= 3 && ::Time.getRound() >= 14))
        && !enemyHasNecro && aliveUndead >= 5 && backlineScreenBonus == 0.0)
        score *= 0.65;
    // On Champion route, if Lich King / Eternal Guard is freshly revived or low-HP (<= 55%) and missing Possess or Infusion,
    // yield slightly below Possess (13.2) & emergency Infusion (13.1) so Mentor stabilizes Lich King first, then raises with remaining AP!
    if (::Autopilot.conf("bgpSmartFrontline") && backlineScreenBonus == 0.0
        && !c.Actor.getSkills().hasSkill("actives.bgp_corpse_explosion")) {
        local canPossess = false;
        local canInfuse = false;
        local pSk = c.Actor.getSkills().getSkillByID("actives.possess_undead");
        if (pSk != null && !pSk.isHidden() && pSk.isUsable() && pSk.isAffordable() && !c.Actor.getSkills().hasSkill("effects.possessing_undead"))
            canPossess = true;
        local iSk = c.Actor.getSkills().getSkillByID("actives.bgp_necro_infusion");
        if (iSk != null && !iSk.isHidden() && iSk.isUsable() && iSk.isAffordable())
            canInfuse = true;
        if (canPossess || canInfuse) {
            foreach (at in c.Allies) {
                local u = at.getEntity();
                if (u == null || ::MSU.isNull(u) || !u.isAlive() || u.isDying()) continue;
                local isChampPet = ::BGP.Champion.isGuard(u);
                if (!isChampPet) {
                    try { isChampPet = ("PaleSovereign" in ::getroottable()) && ::PaleSovereign.isActive() && ::PaleSovereign.isDeployed(::PaleSovereign.mainPet(), u); } catch (e) {}
                }
                if (isChampPet && u.getHitpointsPct() <= 0.55) {
                    local needP = canPossess && !u.getSkills().hasSkill("effects.possessed_undead");
                    local needI = canInfuse && (!u.getSkills().hasSkill("effects.bgp_necro_infusion") || u.getHitpointsPct() <= 0.50)
                        && c.Origin.getDistanceTo(at) <= iSk.getMaxRange();
                    if (needP || needI) {
                        score = ::Math.minf(score, 12.6);
                        break;
                    }
                }
            }
        }
    }
    return score;
});
A.add("bgp_corpse_explosion", "Corpses", function(c, s, t) {
    local corpse = ::BGP.Necro.getCorpse(t);
    if (::BGP.Necro.isGuardCorpse(corpse)) return 0;
    local blast = s.getBlast(corpse, c.Actor);
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
        // Variant B tiered detonation thresholds:
        // - >= 5 enemies: HIGH priority detonation (beats Raise Dead when undead screen >= 5 or plentiful corpses).
        // - 4 enemies: DEMOTED moderate priority (yields to Raise Dead when frontline needs bodies; fires once screen is thick or corpses plentiful).
        // - <= 3 enemies: HEAVILY DEMOTED (only fires on 2+ instant multi-kill or when nothing else useful is available).
        local cursedCombo5 = (hits >= 5 && cursedHits >= 2 && (moraleVulnerableHits >= 2 || cursedHits >= 3)
            && (aliveUndead >= 5 || (aliveUndead >= 4 && (totalCorpses >= 4 || lethalCount >= 2))));
        if (lethalCount == 0 && aliveUndead < 5 && totalCorpses <= 2 && !cursedCombo5)
            return 0;
        if (goblinHits == hits && !cursedCombo5 && (aliveUndead < 6 || (lethalCount < 2 && (hits < 5 || aliveUndead < 7))))
            value *= 0.50;
        if (moraleVulnerableHits == 0) {
            // Against pure-undead armies (Ancient Dead / Zombies), strictly preserve corpses for Raise Dead unless 5+ cursed clump or thick undead screen!
            if (hits >= 5 && cursedHits >= 3 && aliveUndead >= 5) {
                value += 2.6;
            } else if (lethalCount >= 2 && aliveUndead >= 5) {
                value += 1.2;
            } else if (hits >= 5 && aliveUndead >= 7) {
                value += 1.4;
            } else {
                if (totalCorpses <= 4 || aliveUndead < 7)
                    return 0;
                value *= 0.40;
            }
        }
        // Protect our undead frontline: when fewer than 4 undead are alive, NEVER blow up corpses!
        local heavyCorpse = blast.Cutting >= 40;
        if (aliveUndead < 4) {
            return 0;
        } else if (c.Engaged && aliveUndead < 6 && lethalCount == 0) {
            value = ::Math.minf(5.0, value * 0.40);
        } else if (cursedCombo5) {
            // High-value payoff for >= 5 enemy Cursed cluster detonation!
            value += 4.8 + 0.60 * ::Math.min(5, cursedHits) + ::Math.minf(2.0, (hits - 5) * 0.85)
                + (armoredHits >= 2 ? 0.9 : 0.0) + (moraleVulnerableHits >= 3 ? 0.8 : 0.0);
        } else if (hits >= 5 && (aliveUndead >= 5 || totalCorpses >= 5) && (moraleVulnerableHits >= 2 || lethalCount >= 1 || cursedHits >= 2)) {
            value += 4.0 + ::Math.minf(2.0, (hits - 5) * 0.80) + (armoredHits >= 2 ? 0.9 : 0.0)
                + (moraleVulnerableHits >= 3 ? 0.8 : 0.0) + (cursedHits >= 2 ? 1.5 : 0.0);
        } else if (hits == 4 && lethalCount < 2) {
            // Demote 4-enemy non-multi-kill detonations below early Raise Dead (~9.5-12.5); allow when frontline is thick (>= 6) & cursed/plentiful.
            local cap4 = (cursedHits >= 2 && aliveUndead >= 6 && (moraleVulnerableHits >= 2 || cursedHits >= 3))
                ? 9.6
                : (aliveUndead >= 7 && totalCorpses >= 4 ? 8.6 : 7.2);
            value = ::Math.minf(cap4, value * (cursedHits >= 2 ? 0.78 : 0.65));
        } else if (hits <= 3 && lethalCount < 2) {
            // Heavily demote 2-3 enemy non-multi-kill detonations strictly below Raise Dead & Weaken!
            local cap3 = (hits == 3 && cursedHits >= 2 && aliveUndead >= 7 && totalCorpses >= 5) ? 5.0 : 3.6;
            value = ::Math.minf(cap3, value * (hits == 3 && cursedHits >= 2 ? 0.42 : 0.32));
        } else if ((goblinHits == hits && aliveUndead < 6)
            || (aliveUndead < 5 && lethalCount < 2)
            || (heavyCorpse && aliveUndead < 6 && totalCorpses <= 3 && lethalCount < 2)) {
            value = ::Math.minf(5.0, value * 0.42);
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
    local ceComboReady = false;
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
        // Detect same-turn Curse of Ages -> Corpse Explosion combo on a corpse sitting inside an uncursed >= 5 enemy cluster!
        local corpseHere = ::BGP.Necro.getCorpse(t);
        if (!c.Engaged && aliveUndead >= 5 && corpseHere != null && !::BGP.Necro.isGuardCorpse(corpseHere)) {
            local ce = c.Actor.getSkills().getSkillByID("actives.bgp_corpse_explosion");
            if (ce != null && !ce.isHidden() && ce.isUsable() && ce.isInRange(t) && ce.onVerifyTarget(c.Origin, t)) {
                local apNeed = s.getActionPointCost() + ce.getActionPointCost();
                local fatNeed = s.getFatigueCost() + ce.getFatigueCost();
                if (c.Actor.getActionPoints() >= apNeed && (c.Actor.getFatigueMax() - c.Actor.getFatigue()) >= fatNeed)
                    ceComboReady = true;
            }
        }
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
        local isComboCurse = ceComboReady && hits >= 5;
        // Keep the 2-round pacing cooldown even for combos (unless almost no enemies remain cursed < 2),
        // preventing consecutive-round Curse+CE spam from starving Raise Dead.
        if (roundsSinceCurse < 2 && !(alreadyCursed < 2 && hits >= 4))
            return 0;

        // Core rule: >= 4 uncursed enemies in the 7-tile AoE (regardless of armor class) gets high casting priority
        // (enabling Round-2 Summon 4 AP + Curse 5 AP); same-turn Curse -> CE combo on a >= 5 uncursed cluster with a corpse
        // scores strictly above Corpse Explosion so Curse lands FIRST and CE immediately triggers armor decay!
        local cap = 9.8;
        if (isComboCurse) {
            value += 6.5 + ::Math.minf(2.4, (hits - 5) * 0.9) + (engagedHits >= 2 ? 0.5 : 0.0);
            cap = 17.8;
        } else if (hits >= 4) {
            value += 4.2 + ::Math.minf(2.0, (hits - 4) * 0.9) + (engagedHits >= 2 ? 0.5 : 0.0);
            cap = 16.5;
            // After our first Curse of the battle, if corpses are waiting and our undead frontline is thin (< 5),
            // raise meatshields first so we never wipe with 0-6 Raises while spamming 2nd/3rd Curses!
            local castBefore = A.Frontline.battleState().LastCurseRound > 0;
            if (corpseCount > 0 && ((castBefore && aliveUndead < 5) || (alreadyCursed >= 3 && aliveUndead < 5)))
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
    // Never overwrite an active Possession on another undead.
    if (::Autopilot.conf("bgpSmartFrontline") && c.Actor.getSkills().hasSkill("effects.possessing_undead"))
        return 0;
    local distance = A.nearest(c.Enemies, t);
    local unit = t.getEntity();
    return (distance <= 1 ? 6.4 : distance <= 3 ? 5.2 : 3.3)
        + ::Math.minf(1.0, unit.getCurrentProperties().MeleeSkill / 100.0) + (unit.isTurnDone() ? 0 : 0.45);
});
A.add("bgp_necro_infusion", "Allies", function(c, s, t) {
    local unit = t.getEntity();
    // Never cast Infusion twice on the same target in the exact same round.
    if (::Autopilot.conf("bgpSmartFrontline") && "BGPAutoInfuseRound" in s.m
        && s.m.BGPAutoInfuseRound == ::Time.getRound() && s.m.BGPAutoInfuseTargets != null
        && (unit.getID() in s.m.BGPAutoInfuseTargets))
        return 0;
    local wound = 1.0 - unit.getHitpointsPct();
    local hasInf = unit.getSkills().hasSkill("effects.bgp_necro_infusion");
    local fatigue = unit.getFatigue() / ::Math.maxf(1.0, unit.getFatigueMax());
    local dist = A.nearest(c.Enemies, t);
    if (::Autopilot.conf("bgpSmartFrontline")) {
        local isGuard = ::BGP.Champion.isGuard(unit);
        local isMainPet = false;
        try { isMainPet = ("PaleSovereign" in ::getroottable()) && ::PaleSovereign.isActive() && ::PaleSovereign.isDeployed(::PaleSovereign.mainPet(), unit); } catch (e) {}
        local isPermUndeadBro = (unit.getFaction() == ::Const.Faction.Player && unit.getFlags().has("undead"));
        local aliveUndead = 0;
        foreach (at in c.Allies) {
            local u = at.getEntity();
            if (u != null && u.getFaction() == ::Const.Faction.PlayerAnimals && u.getFlags().has("undead"))
                ++aliveUndead;
        }
        local corpseCount = c.Behavior.targets(c, "Corpses").len();
        local enemyHasNecro = false;
        foreach (et in c.Enemies) {
            if (et.getEntity().getSkills().hasSkill("actives.raise_undead")) { enemyHasNecro = true; break; }
        }
        // Keep ALL Infusion scores <= 13.1 (*130 = 1703) so Mentor ALWAYS executes deepVolleyZone backline_kite (1750) first!
        if (isGuard || isMainPet) {
            if (hasInf) {
                // Never spam Infusion every round just for fatigue; only refresh on already-infused Lich King for genuine low-HP emergency heal (<= 50% HP)!
                if (wound < 0.50) return 0;
                return ::Math.minf(13.1, 11.4 + 3.2 * wound);
            }
            if (dist > 6 && ::Time.getRound() < 2) return 0;
            // Revived or wounded Lich King (<= 60% HP) gets immediate emergency Infusion (heal + 16 AP) above capped Raise Dead (12.6)!
            if (wound >= 0.40)
                return 13.1;
            // Opening R2-3 spike: always get Lich King to 16 AP first instead of throttling behind a single corpse!
            if (::Time.getRound() <= 3)
                return ::Math.minf(13.0, 12.4 + (unit.isTurnDone() ? 0.0 : 0.6));
            // Later rounds when our undead frontline is thin (< 4) and corpses are ready to raise, rebuild blockers FIRST before routine buffs!
            if (aliveUndead < 4 && corpseCount > 0)
                return 8.5;
            return ::Math.minf(13.0, 12.1 + (unit.isTurnDone() ? 0.0 : 0.7) + 1.5 * wound);
        }
        if (isPermUndeadBro) {
            local isShield = ::BGP.hasShield(unit);
            if (hasInf) {
                // Only emergency-heal already-infused permanent undead brothers below 45% HP.
                if (wound < 0.55) return 0;
                return ::Math.minf(12.2, 10.5 + 3.0 * wound);
            }
            // Wait until our undead meatshield line is healthy (>= 5, or >= 6 vs enemy Necromancer stealing corpses) before infusing permanent undead bros!
            local minScreen = enemyHasNecro ? 6 : 5;
            if (!isShield && dist <= 3 && (aliveUndead >= minScreen || corpseCount == 0)) {
                return ::Math.minf(11.8, 10.2 + (unit.isTurnDone() ? 0.0 : 0.8) + 2.0 * wound);
            }
            if (wound >= 0.45)
                return ::Math.minf(11.8, 10.4 + 2.8 * wound);
            return 0;
        }
        // Never waste Mentor AP/Fatigue infusing disposable summoned/raised zombies.
        return 0;
    }
    if (hasInf && wound < 0.35) return 0;
    return (dist <= 2 ? 2.1 : 0.25) + 4.0 * wound + fatigue;
});
A.add("bgp_necro_flesh_reforge", "Allies", function(c, s, t) {
    local graftTile = ::BGP.Champion.findGraftTile(t);
    if (graftTile == null || ::BGP.Necro.isGuardCorpse(::BGP.Necro.getCorpse(graftTile)))
        return 0;
    local unit = t.getEntity();
    local dist = A.nearest(c.Enemies, t);
    if (::Autopilot.conf("bgpSmartFrontline")) {
        local isGuard = ::BGP.Champion.isGuard(unit);
        local isMainPet = false;
        try { isMainPet = ("PaleSovereign" in ::getroottable()) && ::PaleSovereign.isActive() && ::PaleSovereign.isDeployed(::PaleSovereign.mainPet(), unit); } catch (e) {}
        local aliveUndead = 0;
        foreach (at in c.Allies) {
            local u = at.getEntity();
            if (u != null && u.getFaction() == ::Const.Faction.PlayerAnimals && u.getFlags().has("undead"))
                ++aliveUndead;
        }
        local corpseCount = c.Behavior.targets(c, "Corpses").len();
        local hasBone = unit.getSkills().hasSkill("effects.bgp_graft_bone");
        // Keep Reforge <= 13.0 (*130 = 1690) so Mentor NEVER overrides deepVolleyZone backline_kite (1750)!
        if (isGuard || isMainPet) {
            if (aliveUndead < 4 && corpseCount <= 1)
                return 6.0;
            if (!hasBone)
                return ::Math.minf(13.0, 12.5 + (dist <= 3 ? 0.5 : 0.0));
            // Graft 2 (+2 Max AP): prioritize once undead screen is stable (>= 5) or corpses are plentiful (>= 2).
            if (aliveUndead >= 5 || corpseCount >= 2)
                return ::Math.minf(12.4, 11.8 + (dist <= 3 ? 0.5 : 0.0));
            return 7.0;
        }
        // Only graft onto high-HP elite raised undead when our undead screen is thick (>= 6) and corpses are plentiful (>= 3).
        if (aliveUndead >= 6 && corpseCount >= 3 && dist <= 3 && unit.getHitpointsMax() >= 110)
            return 6.8 + (hasBone ? 0.35 : 0.0);
        return 0;
    }
    return (dist <= 3 ? 3.4 : 1.8) + (unit.getSkills().hasSkill("effects.bgp_graft_bone") ? 0.35 : 0);
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
            HillBaitRounds = 0,
            HillCampStall = false,
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
        // If a former ranged brother switched to a melee weapon after running completely out of all ranged ammo, treat them as melee!
        local curMain = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
        if (curMain != null && !curMain.isItemType(::Const.Items.ItemType.RangedWeapon) && !this.hasAnyRangedAmmoLeft(_actor))
            return false;
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
        if (maxAmmo > 0)
            return curAmmo > 0;
        // Loaded crossbow / handgonne still has 1 chambered shot even when quiver hits 0.
        local loaded = false;
        try { if ("isLoaded" in _weapon) loaded = _weapon.isLoaded(); } catch (e) {}
        if (loaded)
            return true;
        local isBow = false, isCrossbow = false, isFirearm = false;
        try {
            isBow = _weapon.isWeaponType(::Const.Items.WeaponType.Bow);
            isCrossbow = _weapon.isWeaponType(::Const.Items.WeaponType.Crossbow);
            isFirearm = _weapon.isWeaponType(::Const.Items.WeaponType.Firearm);
        } catch (e) {}
        // Slings / staves that do not consume ammo quivers have infinite ammo.
        if (!isBow && !isCrossbow && !isFirearm)
            return true;
        local wantType = null;
        try {
            if (isBow) wantType = ::Const.Items.AmmoType.Arrows;
            else if (isCrossbow) wantType = ::Const.Items.AmmoType.Bolts;
            else if (isFirearm) wantType = ::Const.Items.AmmoType.Powder;
        } catch (e) { wantType = null; }
        // Bow/crossbow/handgonne uses separate ammo slot; check ammo slot & matching backpack quivers.
        local items = _actor.getItems();
        local ammoItem = items.getItemAtSlot(::Const.ItemSlot.Ammo);
        if (ammoItem != null)
        {
            local a = 0;
            local aType = null;
            try { a = ammoItem.getAmmo(); aType = ammoItem.getAmmoType(); } catch (e) { a = 0; }
            if (a > 0 && (wantType == null || aType == null || aType == wantType))
                return true;
        }
        foreach (bi in items.getAllItemsAtSlot(::Const.ItemSlot.Bag))
        {
            if (bi == null || bi.getSlotType() != ::Const.ItemSlot.Ammo) continue;
            local ba = 0;
            local bType = null;
            try { ba = bi.getAmmo(); bType = bi.getAmmoType(); } catch (e) { ba = 0; }
            if (ba > 0 && (wantType == null || bType == null || bType == wantType))
                return true;
        }
        return false;
    },

    // Return true if _actor still has ANY usable ranged weapon ammo anywhere (equipped weapon, chamber, ammo slot, or backpack quivers/throwing bundles).
    function hasAnyRangedAmmoLeft( _actor )
    {
        local items = _actor.getItems();
        local curMain = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
        if (curMain != null && curMain.isItemType(::Const.Items.ItemType.RangedWeapon) && this.hasUsableRangedAmmo(_actor, curMain))
            return true;
        foreach (bi in items.getAllItemsAtSlot(::Const.ItemSlot.Bag))
        {
            if (bi != null && bi.isItemType(::Const.Items.ItemType.RangedWeapon) && this.hasUsableRangedAmmo(_actor, bi))
                return true;
        }
        return false;
    },

    // Late-battle out-of-ammo melee join: when an archer/crossbowman has 0 ranged ammo left anywhere,
    // has a backup melee weapon and healthy HP (>= 45%), and enemies are wounded/routing/late-battle, switch to melee and help surround!
    function shouldOutOfAmmoJoinMelee( _actor, _info )
    {
        if (this.isCasterRole(_actor) || _actor.getHitpointsPct() < 0.45)
            return false;
        if (this.hasAnyRangedAmmoLeft(_actor))
            return false;
        local curMain = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
        local hasMelee = (curMain != null && !curMain.isItemType(::Const.Items.ItemType.RangedWeapon))
            || (this.findBestBagMeleeWeapon(_actor) != null);
        if (!hasMelee)
            return false;
        if (::Tactical.Entities.isEnemyRetreating())
            return true;
        local activeEnemies = 0;
        local fleeingEnemies = 0;
        local woundedOrStripped = 0;
        local engagedEnemies = 0;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
            {
                ++fleeingEnemies;
                continue;
            }
            ++activeEnemies;
            local maxArm = foe.getArmorMax(::Const.BodyPart.Body);
            local stripped = maxArm >= 40 && foe.getArmor(::Const.BodyPart.Body) <= maxArm * 0.25;
            if (foe.getHitpointsPct() <= 0.70 || stripped
                || foe.getCurrentProperties().IsStunned || foe.getSkills().hasSkill("effects.net"))
                ++woundedOrStripped;
            if (foe.getTile().getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0)
                ++engagedEnemies;
        }
        if (activeEnemies == 0 || fleeingEnemies >= activeEnemies)
            return true;
        local rnd = ::Time.getRound();
        if (rnd >= 5 && (woundedOrStripped * 2 >= activeEnemies || activeEnemies <= 5 || (engagedEnemies >= 2 && woundedOrStripped >= 2)))
            return true;
        if (rnd >= 8 && woundedOrStripped >= 1)
            return true;
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
        local enemyStrongMelee = 0;
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
                if (this.isDangerousMeleeEnemy(foe))
                {
                    local w = foe.getMainhandItem();
                    local is2H = (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded) && w.isItemType(::Const.Items.ItemType.MeleeWeapon));
                    local msk = 50;
                    try { msk = foe.getCurrentProperties().getMeleeSkill(); } catch (e) {}
                    if (foe.getHitpointsMax() >= 100 || foe.getArmorMax(::Const.BodyPart.Body) >= 110
                        || is2H || msk >= 70
                        || (fs.hasSkill("racial.champion") && foe.getHitpointsMax() >= 75))
                        ++enemyStrongMelee;
                }
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

        // Stall-breaker: if enemies refuse to close distance for 2 consecutive rounds while no brother is engaged (e.g. lone backline Necromancer), break hold.
        // Also track whether melee enemies stubbornly camp on high ground above our frontline for 2 rounds so uphill bait escalates to flanking/climbing.
        local enemyCampingHighGround = false;
        if (engagedBrothers == 0 && activeEnemies > 0 && brothers.len() > 0)
        {
            foreach (foe in enemies)
            {
                if (!this.isDangerousMeleeEnemy(foe)) continue;
                local ft = foe.getTile();
                local nearBroDist = 99;
                local nearBroLvl = ft.Level;
                foreach (bro in brothers)
                {
                    if (this.isCasterRole(bro) || this.isRangedRole(bro)) continue;
                    local bt = bro.getTile();
                    local d = ft.getDistanceTo(bt);
                    if (d < nearBroDist) { nearBroDist = d; nearBroLvl = bt.Level; }
                }
                if (nearBroDist <= 5 && ft.Level > nearBroLvl)
                {
                    enemyCampingHighGround = true;
                    break;
                }
            }
        }
        if (round > state.Round)
        {
            if (state.Round >= 1 && activeEnemies > 0 && engagedBrothers == 0 && frontlineMinDist > 2)
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
            if (state.Round >= 1 && engagedBrothers == 0 && enemyCampingHighGround && frontlineMinDist >= state.LastMinDist)
            {
                ++state.HillBaitRounds;
                if (state.HillBaitRounds >= 2)
                    state.HillCampStall = true;
            }
            else if (engagedBrothers > 0 || !enemyCampingHighGround || frontlineMinDist < state.LastMinDist)
            {
                state.HillBaitRounds = 0;
            }
            state.LastMinDist = frontlineMinDist;
            state.Round = round;
        }

        local rangedAdvantage = enemyRanged <= 0.01 || enemyRanged < playerRanged;
        // Only long-range AoE/CC punishers (Ancient Priests with Miasma/Horror) force immediate Round-1/2 charges;
        // enemy Necromancers behind slow Zombies do NOT force our melee brothers to charge into Zombies and gift first strike!
        local casterPush = (enemyMiasmaPriests > 0);
        local holdLine = rangedAdvantage && enemyChargers < 3 && !casterPush && !state.StallBroken && !state.MeleeJoined && activeEnemies > 0;
        local noEnemyRanged = (enemyProjectileRanged <= 0.01 && enemyMiasmaPriests == 0 && enemyChargers < 3
            && !state.StallBroken && !::Tactical.Entities.isEnemyRetreating() && activeEnemies > 0);
        // Distinguish pure light-melee archer swarms (e.g. Goblins: rush to silence bows) from hybrid heavy-ranged + elite-melee armies
        // (e.g. Nomads with Executioners/Desert Devils, Noble/Southern armies: advance cohesively behind Shieldwalls instead of scatter-sprinting!).
        local lightMeleeVolleyRush = (enemyProjectileRanged >= 10.0 && enemyStrongMelee <= 4);
        local hybridRangedHeavyMelee = (enemyProjectileRanged >= 5.0 && enemyStrongMelee >= 5);

        return {
            Enemies = enemies,
            Brothers = brothers,
            ActiveEnemies = activeEnemies,
            PlayerRanged = playerRanged,
            EnemyRanged = enemyRanged,
            EnemyProjectileRanged = enemyProjectileRanged,
            EnemyChargers = enemyChargers,
            EnemyUrgentCasters = enemyUrgentCasters,
            EnemyMiasmaPriests = enemyMiasmaPriests,
            EnemyStrongMelee = enemyStrongMelee,
            LightMeleeVolleyRush = lightMeleeVolleyRush,
            HybridRangedHeavyMelee = hybridRangedHeavyMelee,
            FrontlineMinDist = frontlineMinDist,
            EngagedBrothers = engagedBrothers,
            RangedAdvantage = rangedAdvantage,
            HoldLine = holdLine,
            NoEnemyRanged = noEnemyRanged,
            StallBroken = state.StallBroken,
            HillCampStall = state.HillCampStall
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

    // Check if any live melee enemy is breaching within 2 tiles of our Mentor or a ranged backliner.
    function hasBacklineBreach( _info )
    {
        foreach (bro in _info.Brothers)
        {
            if (!this.isCasterRole(bro) && !this.isRangedRole(bro)) continue;
            local bt = bro.getTile();
            foreach (foe in _info.Enemies)
            {
                if (!this.isDangerousMeleeEnemy(foe)) continue;
                if (bt.getDistanceTo(foe.getTile()) <= 2)
                    return true;
            }
        }
        return false;
    },

    // Against melee-only enemies with NO ranged weapons (no bows/crossbows/slings/javelins) and NO Miasma/Horror priests,
    // never walk an unengaged melee brother into enemy melee strike range (dist == 1, or dist == 2 of an unengaged enemy)
    // without enough AP left to strike first! Let the enemy spend their AP closing in so WE strike first.
    function isGivingMeleeFirstStrike( _actor, _destTile, _info, _apAfter, _effAtkAP )
    {
        if (!_info.NoEnemyRanged || _destTile == null)
            return false;
        if (this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return false;
        local myTile = _actor.getTile();
        if (_destTile.ID == myTile.ID || myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return false;
        local reqAP = _effAtkAP != null ? _effAtkAP : 4;
        if (_effAtkAP == null)
        {
            local atk = this.cheapestMeleeSkill(_actor, true);
            if (atk != null) reqAP = atk.getActionPointCost();
        }
        if (_apAfter >= reqAP)
            return false;

        // Allow peeling any enemy threatening Mentor or a ranged backliner (<= 2 tiles), locking down enemy casters, or chasing fleeing enemies.
        local dangerousAdj = false;
        local steppingIntoUnengaged2 = false;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                continue;
            local ft = foe.getTile();
            local nd = _destTile.getDistanceTo(ft);
            if (nd <= 1 && ::Math.abs(_destTile.Level - ft.Level) <= 1)
            {
                local fs = foe.getSkills();
                if (fs.hasSkill("actives.raise_undead") || fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma")
                    || fs.hasSkill("actives.hex") || fs.hasSkill("actives.root") || fs.hasSkill("actives.sleep"))
                    return false;
                local foePinned = ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0;
                foreach (bro in _info.Brothers)
                {
                    if (!this.isCasterRole(bro) && !this.isRangedRole(bro)) continue;
                    local bd = ft.getDistanceTo(bro.getTile());
                    if (bd <= 1 || (bd == 2 && (!foePinned || this.isCasterRole(bro))))
                        return false;
                }
                if (this.isDangerousMeleeEnemy(foe))
                    dangerousAdj = true;
            }
            else if (nd == 2 && this.isDangerousMeleeEnemy(foe)
                && ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0
                && nd < myTile.getDistanceTo(ft))
            {
                steppingIntoUnengaged2 = true;
            }
        }
        return dangerousAdj || steppingIntoUnengaged2;
    },

    function shouldActorHold( _actor, _agent )
    {
        local info = this.assessBattle(_actor, _agent);
        if (!info.HoldLine)
            return { Hold = false, Info = info, StrikePlan = null };
        if (_actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return { Hold = false, Info = info, StrikePlan = null };
        if (this.hasBacklineBreach(info))
            return { Hold = false, Info = info, StrikePlan = null };
        if (!this.isRangedRole(_actor) && !this.isCasterRole(_actor))
        {
            // Per-brother first-strike check: only break Hold for brothers who can ACTUALLY strike this turn (or shieldbearers raising Spearwall),
            // instead of globally releasing the whole squad to charge into Zombies when one enemy touches dist 2!
            local plan = this.findSameTurnStrikePlan(_actor, info.Enemies);
            if (plan != null)
                return { Hold = false, Info = info, StrikePlan = plan };
            if (::BGP.hasShield(_actor) && !_actor.getSkills().hasSkill("effects.spearwall"))
            {
                local spw = _actor.getSkills().getSkillByID("actives.spearwall");
                if (spw != null && !spw.isHidden() && spw.isUsable() && spw.isAffordable()
                    && this.countDangerousMeleeWithin(_actor, info.Enemies, 3) >= 2)
                    return { Hold = false, Info = info, StrikePlan = null };
            }
            return { Hold = true, Info = info, StrikePlan = null };
        }
        if (info.EngagedBrothers > 0 || info.FrontlineMinDist <= 2)
            return { Hold = false, Info = info, StrikePlan = null };
        return { Hold = true, Info = info, StrikePlan = null };
    },

    function hasUnactedShieldAlly( _actor, _info )
    {
        // Yield Round 1 Phase 1 (and Round 2 Phase 1 while frontline hasn't engaged yet or actor is fragile)
        // to nearby unacted shieldbearers or our unacted summoner Mentor so heavy BF tanks & undead summons take the frontline first!
        // Note: do NOT filter by ally.getInitiative() >= 40 — heavy Battle Forged shield tanks have Initiative ~15-30 and STILL act
        // in Phase 1 before any Waiting brother resumes in Phase 2!
        local rnd = ::Time.getRound();
        if (rnd > 2)
            return false;
        if (_info.EngagedBrothers > 0)
            return false;
        local myTile = _actor.getTile();
        foreach (foe in _info.Enemies)
        {
            if (myTile.getDistanceTo(foe.getTile()) <= 2)
                return false;
        }
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
            if (::BGP.hasShield(ally) && dist <= 6
                && ally.getTile().getZoneOfControlCountOtherThan(ally.getAlliedFactions()) == 0)
                return true;
            // All non-shield melee bros yield Round 1 Phase 1 to our unacted summoner Mentor so Lich King + Skeleton deploy first.
            if (rnd == 1 && this.isCasterRole(ally) && dist <= 6)
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

    // Read live effective enemy combat attributes, real-time fatigue headroom, and current-round turn order / remaining AP.
    function enemyLiveStats( _foe )
    {
        local msk = 50, mdef = 0, rsk = 40, rdef = 0, curFat = 0, maxFat = 100;
        local turnDone = false, ap = 9, turnsUntil = 99;
        local stunned = false, fleeing = false;
        try {
            local p = _foe.getCurrentProperties();
            msk = p.getMeleeSkill();
            mdef = p.getMeleeDefense();
            rsk = p.getRangedSkill();
            rdef = p.getRangedDefense();
            stunned = p.IsStunned;
        } catch (e) {}
        try {
            curFat = _foe.getFatigue();
            maxFat = _foe.getFatigueMax();
        } catch (e) {}
        try {
            turnDone = _foe.isTurnDone();
            ap = _foe.getActionPoints();
            fleeing = (_foe.getMoraleState() == ::Const.MoraleState.Fleeing);
            if (!turnDone)
                turnsUntil = ::Tactical.TurnSequenceBar.getTurnsUntilActive(_foe.getID());
        } catch (e) {}
        local remFat = ::Math.max(0, maxFat - curFat);
        local fatPct = maxFat > 0 ? (curFat.tofloat() / maxFat.tofloat()) : 0.0;
        // Requiring curFat >= 25 cleanly excludes zero-fatigue undead (Ancient Dead / Zombies) who never stam out.
        local isExhausted = (maxFat >= 50 && curFat >= 25 && (remFat <= 18 || fatPct >= 0.85));
        local canActThisRound = (!turnDone && ap >= 4 && !stunned && !fleeing);
        return {
            MSk = msk,
            MDef = mdef,
            RSk = rsk,
            RDef = rdef,
            CurFat = curFat,
            MaxFat = maxFat,
            RemFat = remFat,
            FatPct = fatPct,
            IsExhausted = isExhausted,
            TurnDone = turnDone,
            AP = ap,
            TurnsUntil = turnsUntil,
            CanActThisRound = canActThisRound
        };
    },

    // Compute relative effective hit chance (5-95%) of _foe hitting _defender, factoring live skill-vs-defense delta,
    // real-time surround bonus (checking Underdog / Backstabber), and elevation difference.
    function enemyEffectiveHitOn( _foe, _defender, _atTile = null )
    {
        if (_foe == null || _defender == null || ::MSU.isNull(_foe) || ::MSU.isNull(_defender))
            return 50;
        local ft = _foe.getTile();
        local dt = _atTile != null ? _atTile : _defender.getTile();
        local fp = _foe.getCurrentProperties();
        local dp = _defender.getCurrentProperties();
        local hBonus = (ft != null && dt != null) ? (ft.Level - dt.Level) * 10 : 0;
        if (_foe.isArmedWithRangedWeapon())
        {
            local w = _foe.getMainhandItem();
            if (w == null || !w.isItemType(::Const.Items.ItemType.Ammo))
                return ::Math.max(5, ::Math.min(95, fp.getRangedSkill() - dp.getRangedDefense() + hBonus));
        }
        local surround = 0;
        if (dt != null && !_defender.getSkills().hasSkill("perk.underdog"))
        {
            local adjHostiles = 0;
            local foeAlreadyAdj = false;
            for (local d = 0; d < 6; ++d)
            {
                if (!dt.hasNextTile(d)) continue;
                local nt = dt.getNextTile(d);
                if (!nt.IsOccupiedByActor || ::Math.abs(nt.Level - dt.Level) > 1) continue;
                local occ = nt.getEntity();
                if (occ != null && !::MSU.isNull(occ) && occ.isAlive() && !occ.isDying() && !occ.isAlliedWith(_defender)
                    && occ.getMoraleState() != ::Const.MoraleState.Fleeing && !occ.getCurrentProperties().IsStunned)
                {
                    ++adjHostiles;
                    if (occ.getID() == _foe.getID()) foeAlreadyAdj = true;
                }
            }
            if (!foeAlreadyAdj) ++adjHostiles;
            local perSurr = _foe.getSkills().hasSkill("perk.backstabber") ? 10 : 5;
            surround = ::Math.max(0, adjHostiles - 1) * perSurr;
        }
        return ::Math.max(5, ::Math.min(95, fp.getMeleeSkill() - dp.getMeleeDefense() + surround + hBonus));
    },

    // Evaluate an enemy's relative threat against the player squad it is ACTUALLY threatening (plus company average melee skill).
    function enemySquadThreat( _foe, _info = null )
    {
        local bros = (_info != null && "Brothers" in _info) ? _info.Brothers : ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
        local ft = _foe.getTile();
        local isRangedFoe = _foe.isArmedWithRangedWeapon();
        local maxReach = isRangedFoe ? 8 : ::Math.max(2, _foe.getIdealRange() + 1);
        local maxHit = 0;
        local nearestBro = null;
        local nearestDist = 99;
        local mskSum = 0;
        local mskCnt = 0;
        foreach (bro in bros)
        {
            if (bro == null || ::MSU.isNull(bro) || !bro.isAlive() || bro.isDying() || !bro.isPlacedOnMap()) continue;
            if (!this.isCasterRole(bro) && !this.isRangedRole(bro))
            {
                try { mskSum += bro.getCurrentProperties().getMeleeSkill(); ++mskCnt; } catch (e) {}
            }
            local d = ft.getDistanceTo(bro.getTile());
            if (d < nearestDist) { nearestDist = d; nearestBro = bro; }
            if (d <= maxReach)
            {
                local h = this.enemyEffectiveHitOn(_foe, bro);
                if (this.isCasterRole(bro) || this.isRangedRole(bro) || bro.getHitpointsPct() <= 0.50)
                    h = ::Math.min(95, h + 10);
                if (h > maxHit) maxHit = h;
            }
        }
        if (maxHit == 0 && nearestBro != null)
            maxHit = this.enemyEffectiveHitOn(_foe, nearestBro);
        local avgAllyMSk = mskCnt > 0 ? (mskSum / mskCnt) : 72;
        return { MaxHit = maxHit, AvgAllyMSk = avgAllyMSk };
    },

    // Check how many dangerous melee/reach enemies can actually attack _actor BEFORE _actor's next turn starts
    // (either still able to act this round, OR faster Initiative next round with non-trivial hit chance).
    function hasThreatBeforeNextTurn( _actor, _enemies )
    {
        local myTile = _actor.getTile();
        local myFatRec = 15;
        try { myFatRec = _actor.getCurrentProperties().getFatigueRecoveryRate(); } catch (e) { myFatRec = 15; }
        local myNextIni = _actor.getInitiative() + ::Math.min(_actor.getFatigue(), myFatRec);
        local count = 0;
        local maxHit = 0;
        local urgentThisRound = 0;
        foreach (foe in _enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe)) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            local canReach = (d == 1 && ::Math.abs(myTile.Level - ft.Level) <= 1)
                || (d == 2 && foe.getIdealRange() >= 2 && ::Math.abs(myTile.Level - ft.Level) <= 1);
            if (!canReach) continue;
            local st = this.enemyLiveStats(foe);
            local actsBeforeNext = st.CanActThisRound;
            if (!actsBeforeNext)
            {
                local eFatRec = 15;
                try { eFatRec = foe.getCurrentProperties().getFatigueRecoveryRate(); } catch (e) { eFatRec = 15; }
                local eNextIni = foe.getInitiative() + ::Math.min(foe.getFatigue(), eFatRec);
                if (eNextIni >= myNextIni - 2 || foe.getSkills().hasSkill("effects.adrenaline"))
                    actsBeforeNext = true;
            }
            if (!actsBeforeNext) continue;
            local effHit = this.enemyEffectiveHitOn(foe, _actor);
            if (effHit >= 18 || this.isHeavyMeleeThreat(foe, _actor))
            {
                ++count;
                if (st.CanActThisRound) ++urgentThisRound;
                if (effHit > maxHit) maxHit = effHit;
            }
        }
        return { Count = count, MaxHit = maxHit, UrgentThisRound = urgentThisRound };
    },

    // Identify brothers whose equipped weapon excels at stripping heavy armor (Hammers, 2H Maces, Heavy Crossbows, Throwing Axes).
    function isArmorShredder( _actor )
    {
        if (_actor == null || ::MSU.isNull(_actor))
            return false;
        local w = _actor.getMainhandItem();
        if (w == null)
            return false;
        try {
            if (w.isWeaponType(::Const.Items.WeaponType.Hammer))
                return true;
            if (w.isWeaponType(::Const.Items.WeaponType.Mace) && w.isItemType(::Const.Items.ItemType.TwoHanded))
                return true;
            if (w.isWeaponType(::Const.Items.WeaponType.Axe) && (w.isItemType(::Const.Items.ItemType.TwoHanded) || w.isWeaponType(::Const.Items.WeaponType.Throwing)))
                return true;
            if (w.isWeaponType(::Const.Items.WeaponType.Crossbow) || w.isWeaponType(::Const.Items.WeaponType.Firearm))
                return true;
        } catch (e) {}
        local sk = _actor.getSkills();
        return sk.hasSkill("actives.smite") || sk.hasSkill("actives.shatter") || sk.hasSkill("actives.destroy_armor") || sk.hasSkill("actives.crush_armor");
    },

    // Identify melee brothers whose damage scales massively AFTER armor is stripped (Cleavers, Swords, Spears, Daggers, Polearms).
    function isFleshBurstWeapon( _actor )
    {
        if (_actor == null || ::MSU.isNull(_actor) || this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return false;
        if (this.isArmorShredder(_actor))
            return false;
        local w = _actor.getMainhandItem();
        if (w == null)
            return false;
        try {
            return w.isWeaponType(::Const.Items.WeaponType.Cleaver)
                || w.isWeaponType(::Const.Items.WeaponType.Sword)
                || w.isWeaponType(::Const.Items.WeaponType.Spear)
                || w.isWeaponType(::Const.Items.WeaponType.Dagger)
                || w.isWeaponType(::Const.Items.WeaponType.Polearm);
        } catch (e) {}
        return false;
    },

    // Detect whether stepping onto _destTile puts a melee brother at elevation disadvantage below an uphill melee/polearm enemy
    // (or inside an unengaged uphill 2-tile polearm's reach), which locks enemies ON their high ground instead of luring them down.
    function isUphillMeleeTrap( _destTile, _actor, _info )
    {
        local emptyRes = { IsTrap = false, PolearmTrap = false, UphillCount = 0 };
        if (_destTile == null || _actor == null || _info == null)
            return emptyRes;
        if (this.isRangedRole(_actor) || this.isCasterRole(_actor))
            return emptyRes;
        // Anti-stall & endgame overrides: push hills if enemies camped for >=2 rounds, stall broke, or cleaning up <=3 holdouts.
        if (_info.HillCampStall || _info.StallBroken || ::Time.getRound() >= 10
            || _info.ActiveEnemies <= 3 || ::Tactical.Entities.isEnemyRetreating())
            return emptyRes;

        local chiefTile = null;
        foreach (bro in _info.Brothers)
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }

        local uphillCount = 0;
        local polearmTrap = false;
        for (local d = 0; d < 6; ++d)
        {
            if (!_destTile.hasNextTile(d)) continue;
            local adj = _destTile.getNextTile(d);
            if (!adj.IsOccupiedByActor || adj.Level <= _destTile.Level || ::Math.abs(adj.Level - _destTile.Level) > 1)
                continue;
            local occ = adj.getEntity();
            if (occ == null || ::MSU.isNull(occ) || !occ.isAlive() || occ.isDying() || occ.isAlliedWith(_actor))
                continue;
            if (occ.getMoraleState() == ::Const.MoraleState.Fleeing || occ.getCurrentProperties().IsStunned)
                continue;
            // Pinning pure ranged units or hostile casters on high ground is desirable; only avoid locking MELEE/POLEARM enemies onto high ground!
            if (occ.isArmedWithRangedWeapon()) continue;
            local os = occ.getSkills();
            if (os.hasSkill("actives.raise_undead") || os.hasSkill("actives.horror") || os.hasSkill("actives.miasma")
                || os.hasSkill("actives.hex") || os.hasSkill("actives.root") || os.hasSkill("actives.sleep"))
                continue;
            if (!this.isDangerousMeleeEnemy(occ)) continue;
            // Always allow peeling an uphill enemy breaching our Mentor, or finishing a critically dying foe.
            if (chiefTile != null && adj.getDistanceTo(chiefTile) <= 2)
                continue;
            if (occ.getHitpoints() <= 24)
                continue;
            ++uphillCount;
        }

        // Also detect stepping within 2 tiles below an unengaged uphill polearm/reach-2 enemy (should stay 3 tiles away!).
        foreach (foe in _info.Enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe) || foe.isArmedWithRangedWeapon() || foe.getIdealRange() < 2)
                continue;
            local ft = foe.getTile();
            if (ft.Level <= _destTile.Level || ::Math.abs(ft.Level - _destTile.Level) > 1)
                continue;
            if (ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) > 0)
                continue;
            if (_destTile.getDistanceTo(ft) <= 2)
            {
                polearmTrap = true;
                break;
            }
        }

        return {
            IsTrap = uphillCount > 0,
            PolearmTrap = polearmTrap,
            UphillCount = uphillCount
        };
    },

    // Inspect live TurnSequenceBar.m.CurrentEntities (with safe fallback) to see which enemies and allies still act in Phase 1
    // BEFORE any Waiting unit resumes in Phase 2.
    function inspectTurnBar( _actor, _info )
    {
        local myTile = _actor.getTile();
        local myID = _actor.getID();
        local phase1Enemies = [];
        local phase1Allies = [];
        local phase1Set = {};
        local usedBar = false;

        try {
            local bar = ::Tactical.TurnSequenceBar;
            if (bar != null && ("m" in bar) && ("CurrentEntities" in bar.m) && bar.m.CurrentEntities != null)
            {
                local list = bar.m.CurrentEntities;
                local foundMe = false;
                foreach (e in list)
                {
                    if (e == null || ::MSU.isNull(e) || !e.isAlive() || e.isDying() || !e.isPlacedOnMap())
                        continue;
                    if (e.getID() == myID)
                    {
                        foundMe = true;
                        continue;
                    }
                    if (!foundMe) continue;
                    // Phase-1 units are those that have NOT spent their Wait action and are not done.
                    if (e.isTurnDone() || e.isWaitActionSpent())
                        continue;
                    if (e.getMoraleState() == ::Const.MoraleState.Fleeing || e.getCurrentProperties().IsStunned)
                        continue;
                    if (e.isAlliedWith(_actor))
                        phase1Allies.push(e);
                    else if (!e.isHiddenToPlayer() && e.getTile().IsVisibleForPlayer)
                        phase1Enemies.push(e);
                    phase1Set[e.getID()] <- true;
                }
                usedBar = foundMe;
            }
        } catch (e) { usedBar = false; }

        if (!usedBar)
        {
            foreach (foe in _info.Enemies)
            {
                if (foe.isTurnDone() || foe.isWaitActionSpent()) continue;
                if (foe.getMoraleState() == ::Const.MoraleState.Fleeing || foe.getCurrentProperties().IsStunned) continue;
                phase1Enemies.push(foe);
                phase1Set[foe.getID()] <- true;
            }
            foreach (bro in _info.Brothers)
            {
                if (bro.getID() == myID || bro.isTurnDone() || bro.isWaitActionSpent()) continue;
                if (bro.getMoraleState() == ::Const.MoraleState.Fleeing || bro.getCurrentProperties().IsStunned) continue;
                phase1Allies.push(bro);
                phase1Set[bro.getID()] <- true;
            }
        }

        local phase1Shooters = 0;
        local phase1MeleeNear = 0;
        local phase1MeleeUphill = 0;
        local phase1MeleeAdj = 0;
        foreach (foe in phase1Enemies)
        {
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (foe.isArmedWithRangedWeapon())
            {
                local w = foe.getMainhandItem();
                if (w != null && this.hasUsableRangedAmmo(foe, w))
                    ++phase1Shooters;
            }
            if (this.isDangerousMeleeEnemy(foe))
            {
                if (d == 1 && ::Math.abs(myTile.Level - ft.Level) <= 1)
                    ++phase1MeleeAdj;
                else if (d == 2 && foe.getIdealRange() >= 2 && ::Math.abs(myTile.Level - ft.Level) <= 1)
                    ++phase1MeleeAdj;
                if (d >= 2 && d <= 4 && ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0)
                    ++phase1MeleeNear;
                if (d >= 2 && d <= 5 && ft.Level > myTile.Level && ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0)
                    ++phase1MeleeUphill;
            }
        }

        local phase1ShieldAllies = 0;
        local rnd = ::Time.getRound();
        foreach (ally in phase1Allies)
        {
            if (ally.getActionPoints() < 4 || ally.getCurrentProperties().IsRooted) continue;
            local dist = ally.getTile().getDistanceTo(myTile);
            if (dist > 6) continue;
            if (::BGP.hasShield(ally) && ally.getTile().getZoneOfControlCountOtherThan(ally.getAlliedFactions()) == 0)
            {
                ++phase1ShieldAllies;
            }
            else if (rnd == 1 && this.isCasterRole(ally))
            {
                local sk = ally.getSkills();
                foreach (sid in ["actives.unleash_companion", "actives.pale_summon_skeleton", "actives.pale_summon_zombie"])
                {
                    local s = sk.getSkillByID(sid);
                    if (s != null && !s.isHidden() && s.isUsable() && s.isAffordable())
                    {
                        ++phase1ShieldAllies;
                        break;
                    }
                }
            }
        }

        return {
            Phase1Enemies = phase1Enemies,
            Phase1Allies = phase1Allies,
            Phase1Set = phase1Set,
            Phase1Shooters = phase1Shooters,
            Phase1MeleeNear = phase1MeleeNear,
            Phase1MeleeUphill = phase1MeleeUphill,
            Phase1MeleeAdj = phase1MeleeAdj,
            Phase1ShieldAllies = phase1ShieldAllies,
            HasAnyoneLeftInPhase1 = (phase1Enemies.len() + phase1Allies.len()) > 0
        };
    },

    // Check whether _actor can execute a likely lethal kill right now (never delay an immediate kill!).
    function canKillActiveTargetNow( _actor, _info )
    {
        local myTile = _actor.getTile();
        if (this.isRangedRole(_actor))
        {
            local bestRng = null;
            foreach (s in _actor.getSkills().m.Skills)
            {
                if (!s.isAttack() || !s.isRanged() || s.isHidden() || !s.isUsable() || !s.isAffordable()) continue;
                foreach (foe in _info.Enemies)
                {
                    if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    local ft = foe.getTile();
                    local d = myTile.getDistanceTo(ft);
                    if (d < s.getMinRange() || d > s.getMaxRange() || !s.isUsableOn(ft, myTile)) continue;
                    try {
                        local hit = s.getHitchance(foe);
                        local dmg = s.getExpectedDamage(foe);
                        if (hit >= 45 && dmg.HitpointDamage + dmg.DirectDamage >= foe.getHitpoints())
                            return true;
                    } catch (e) {}
                }
            }
            return false;
        }
        local atk = this.cheapestMeleeSkill(_actor);
        if (atk == null) return false;
        local minR = atk.getMinRange();
        local maxR = atk.getMaxRange();
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < minR || d > maxR || !atk.isUsableOn(ft, myTile)) continue;
            try {
                local hit = atk.getHitchance(foe);
                local dmg = atk.getExpectedDamage(foe);
                if (hit >= 45 && dmg.HitpointDamage + dmg.DirectDamage >= foe.getHitpoints())
                    return true;
            } catch (e) {}
        }
        return false;
    },

    // Find a safe uphill-bait stand-off tile: stay dist >= 2 from uphill 1-tile melee enemies and dist >= 3 from uphill 2-tile polearms,
    // retaining Shieldwall AP/Fatigue on Shieldbearers so uphill enemies descend off high ground instead of getting pinned with +10% elevation bonus!
    function findUphillBaitTile( _behavior, _actor, _info )
    {
        if (_info == null || _info.HillCampStall || _info.StallBroken || ::Time.getRound() >= 10
            || _info.ActiveEnemies <= 3 || ::Tactical.Entities.isEnemyRetreating())
            return null;
        if (this.isRangedRole(_actor) || this.isCasterRole(_actor) || _actor.getCurrentProperties().IsRooted)
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        if (this.hasBacklineBreach(_info))
            return null;

        local isShield = ::BGP.hasShield(_actor);
        // Gather nearby unengaged uphill melee/polearm enemies (within 6 tiles and higher than our elevation).
        local uphillFoes = [];
        local hasFlatReachableTarget = false;
        foreach (foe in _info.Enemies)
        {
            if (!this.isDangerousMeleeEnemy(foe) || foe.isArmedWithRangedWeapon()) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (ft.Level <= myTile.Level && d <= 3)
            {
                hasFlatReachableTarget = true;
            }
            if (ft.Level > myTile.Level && d <= 6 && ft.getZoneOfControlCountOtherThan(foe.getAlliedFactions()) == 0)
            {
                uphillFoes.push(foe);
            }
        }
        // If there is already a reachable equal/lower-elevation melee target, engage that target normally instead of baiting!
        if (uphillFoes.len() == 0 || hasFlatReachableTarget)
            return null;

        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local reserveAP = 0;
        local reserveFat = 0;
        if (isShield)
        {
            local sw = _actor.getSkills().getSkillByID("actives.shieldwall");
            if (sw != null && !sw.isHidden() && sw.isUsable())
            {
                reserveAP = sw.getActionPointCost();
                reserveFat = sw.getFatigueCost();
            }
        }
        local moveAPBudget = isShield ? (ap - reserveAP) : ::Math.min(ap, 4);

        // Helper check: is tile _t safely on or outside the uphill stand-off perimeter (dist >= 2 vs 1-tile, dist >= 3 vs polearm)?
        local function checkPerimeter( _t ) {
            local onExactRing = false;
            local nearestUphill = 99;
            foreach (foe in uphillFoes)
            {
                local ft = foe.getTile();
                if (ft.Level <= _t.Level) continue; // Matched or exceeded enemy's hill — even better!
                local reqDist = foe.getIdealRange() >= 2 ? 3 : 2;
                local d = _t.getDistanceTo(ft);
                if (d < reqDist)
                    return { Safe = false, Exact = false, Nearest = d };
                if (d == reqDist)
                    onExactRing = true;
                if (d < nearestUphill)
                    nearestUphill = d;
            }
            return { Safe = true, Exact = onExactRing, Nearest = nearestUphill };
        };

        local curCheck = checkPerimeter(myTile);
        local chiefTile = null;
        foreach (bro in _info.Brothers)
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }

        // If we are ALREADY standing safely on the exact dist-2 / dist-3 bait perimeter (not in bad terrain/hazard), hold right here!
        if (curCheck.Safe && curCheck.Exact && !myTile.IsBadTerrain && !_behavior.hasNegativeTileEffect(myTile, _actor))
        {
            return {
                Tile = myTile,
                HoldHere = true,
                NeedsShieldwall = isShield && (_info.EnemyProjectileRanged >= 2.0 || curCheck.Nearest <= 3)
            };
        }

        if (moveAPBudget < 2)
        {
            if (curCheck.Safe && curCheck.Nearest <= 4)
                return { Tile = myTile, HoldHere = true, NeedsShieldwall = isShield && _info.EnemyProjectileRanged >= 2.0 };
            return null;
        }

        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local candidates = this.tilesInRange(myTile, 1, 2);
        local bestTile = null;
        local bestScore = -999.0;

        foreach (dest in candidates)
        {
            if (!dest.IsEmpty || dest.ID == myTile.ID) continue;
            if (_behavior.hasNegativeTileEffect(dest, _actor)) continue;
            if (dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0) continue;

            local chk = checkPerimeter(dest);
            if (!chk.Safe) continue;
            // Must either step onto the exact bait ring, climb to match hill elevation, or get closer to the ring.
            local climbs = dest.Level > myTile.Level;
            if (!chk.Exact && !climbs && chk.Nearest >= curCheck.Nearest)
                continue;

            if (!navigator.findPath(myTile, dest, settings, 0)) continue;
            local cost = navigator.getCostForPath(_actor, settings, moveAPBudget, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.Tiles > 2 || cost.ActionPointsRequired > moveAPBudget)
                continue;
            if (isShield && reserveFat > 0 && (availFat - cost.FatigueRequired) < reserveFat)
                continue;

            local exp = this.evaluateTileExposure(_actor, dest, _info);
            if (!isShield && exp.AdjAllies == 0 && exp.NearAllies2 < 2)
                continue;

            local distGain = chk.Nearest < 99 ? (curCheck.Nearest - chk.Nearest) : 2;
            local sc = (chk.Exact ? 26.0 : 12.0)
                + distGain * 8.0
                + (dest.Level - myTile.Level) * 14.0
                + ::Math.min(2, exp.AdjAllies) * 9.0
                + ::Math.min(2, exp.AdjShieldAllies) * (isShield ? 7.0 : 10.0)
                + ::Math.min(3, exp.NearAllies2) * 3.0
                + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, isShield ? "tank" : "dps") * 0.65
                - cost.ActionPointsRequired * 0.6;
            if (!isShield && this.hasRangedCoverAt(dest, _actor, _info.Enemies, 8))
                sc += 10.0;
            if (isShield && chiefTile != null && dest.getDistanceTo(chiefTile) <= 4)
                sc += 5.0;
            if (sc > bestScore) { bestScore = sc; bestTile = dest; }
        }

        if (bestTile != null)
            return { Tile = bestTile, HoldHere = false, NeedsShieldwall = isShield && (_info.EnemyProjectileRanged >= 2.0 || curCheck.Nearest <= 4) };
        if (curCheck.Safe && curCheck.Nearest <= 4)
            return { Tile = myTile, HoldHere = true, NeedsShieldwall = isShield && _info.EnemyProjectileRanged >= 2.0 };
        return null;
    },

    // Unified Initiative & Turn-Order Tactical Wait evaluator (Phase 1 -> Phase 2 coordination):
    //   1) wait_tank_opener: R1-R3 unshielded melee yields Phase 1 to unacted Shieldbearers / R1 Mentor summoner.
    //   2) wait_uphill_or_firststrike: Shieldbearers (after enemy shooters acted) and non-striking melee wait for slower/uphill enemies to descend & burn AP first.
    //   3) wait_surround_focus / wait_combo_inzoc: fast DPS waits for slower tanks/summons to build surround OR armor-shredders (Hammer/2H Mace/Xbow) to strip armor first, then piles on in Phase 2!
    //   4) wait_buff_expire: wait out an unacted enemy's expiring Shieldwall / Riposte / Spearwall before striking.
    //   5) wait_ranged_range: fast ranged bro with no enemy currently in weapon range waits for slower Phase-1 enemies to step into range.
    function evaluateTacticalWait( _actor, _info, _agent )
    {
        if (_actor == null || _info == null || _info.Enemies.len() == 0)
            return null;
        if (!::Autopilot.isUnderAIControl(_actor) || !::Autopilot.conf("bgpSmartFrontline"))
            return null;
        if (this.isCasterRole(_actor))
            return null;
        if (!::Tactical.TurnSequenceBar.canEntityWait(_actor))
            return null;
        if (_actor.getActionPoints() < 4 || _actor.getCurrentProperties().IsStunned
            || _actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            return null;
        // Never delay endgame cleanup, routing chases, or urgent backline rescues/wounded retreats.
        if (::Tactical.Entities.isEnemyRetreating() || _info.ActiveEnemies <= 2 || ::Time.getRound() >= 12)
            return null;
        if (this.hasBacklineBreach(_info) || this.shouldWoundedRetreat(_actor, _info))
            return null;
        // Never wait when already holding Shieldwall/Spearwall/Indomitable active!
        if (_actor.getSkills().hasSkill("effects.shieldwall") || _actor.getSkills().hasSkill("effects.spearwall")
            || _actor.getSkills().hasSkill("effects.indomitable"))
            return null;

        local tb = this.inspectTurnBar(_actor, _info);
        if (!tb.HasAnyoneLeftInPhase1)
            return null;
        // Never pass up a likely immediate lethal kill!
        if (this.canKillActiveTargetNow(_actor, _info))
            return null;

        local myTile = _actor.getTile();
        local inZoC = myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0;
        local isShield = ::BGP.hasShield(_actor);
        local isRanged = this.isRangedRole(_actor);
        local rnd = ::Time.getRound();

        // --- Mode 5: Fast Ranged waiting when NO active enemy is inside weapon firing range yet ---
        if (isRanged)
        {
            if (inZoC || tb.Phase1Enemies.len() == 0)
                return null;
            // Never delay kiting away from close threats.
            if (this.nearestLiveBacklineThreatDist(_actor, _info.Enemies) <= 3)
                return null;
            local hasAnyTargetInRange = false;
            foreach (s in _actor.getSkills().m.Skills)
            {
                if (!s.isAttack() || !s.isRanged() || s.isHidden() || !s.isUsable() || !s.isAffordable()) continue;
                local maxR = s.getMaxRange();
                local minR = s.getMinRange();
                foreach (foe in _info.Enemies)
                {
                    if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    local ft = foe.getTile();
                    local d = myTile.getDistanceTo(ft);
                    if (d >= minR && d <= maxR && s.isUsableOn(ft, myTile))
                    {
                        hasAnyTargetInRange = true;
                        break;
                    }
                }
                if (hasAnyTargetInRange) break;
            }
            if (!hasAnyTargetInRange)
                return { Reason = "wait_ranged_range", Score = 460.0, SuppressMove = true, SuppressAttack = false };
            return null;
        }

        // --- Mode 1: Unshielded melee yields opening Phase 1 to unacted Shieldbearers / R1 Mentor summoner ---
        if (!isShield && !inZoC && rnd <= 3 && tb.Phase1ShieldAllies > 0
            && (_info.EngagedBrothers == 0 || rnd == 1))
        {
            local enemyDist2 = false;
            foreach (foe in _info.Enemies)
                if (myTile.getDistanceTo(foe.getTile()) <= 2) { enemyDist2 = true; break; }
            if (!enemyDist2)
                return { Reason = "wait_tank_opener", Score = 510.0, SuppressMove = true, SuppressAttack = false };
        }

        // --- Mode 2: Initiative & Uphill Bait Wait (let slower/uphill enemy melee move first -> Phase 2 counter-strike + next-round double turn!) ---
        if (!inZoC && !_info.HillCampStall && !_info.StallBroken)
        {
            // 2A: Shieldbearer smart wait — ONLY when all enemy archers already shot in Phase 1 (0 extra arrow risk!)
            // and slower enemy melee (especially on high ground!) haven't committed yet.
            if (isShield && tb.Phase1Shooters == 0 && (tb.Phase1MeleeUphill > 0 || (tb.Phase1MeleeNear > 0 && _info.EnemyMiasmaPriests == 0)))
            {
                // Skip if an enemy is already adjacent or we want to raise early Spearwall against >=2 close melee.
                local strikeNow = this.findSameTurnStrikePlan(_actor, _info.Enemies);
                local hasPinnedStrike = false;
                if (strikeNow != null && strikeNow.Enemy != null && strikeNow.Enemy.getTile().getZoneOfControlCountOtherThan(strikeNow.Enemy.getAlliedFactions()) > 0)
                    hasPinnedStrike = true;
                if (!hasPinnedStrike && !_info.LightMeleeVolleyRush)
                    return { Reason = "wait_shield_read", Score = 520.0, SuppressMove = true, SuppressAttack = false };
            }

            // 2B: Unshielded melee cannot strike anyone this turn, while slower unacted enemy melee (dist 2-4 or uphill 2-5) haven't moved yet.
            if (!isShield && (tb.Phase1MeleeUphill > 0 || (tb.Phase1MeleeNear > 0 && _info.EnemyMiasmaPriests == 0)))
            {
                local exposedToVolley = _info.LightMeleeVolleyRush && !this.hasRangedCoverAt(myTile, _actor, _info.Enemies, 8);
                if (!exposedToVolley && this.findSameTurnStrikePlan(_actor, _info.Enemies) == null)
                    return { Reason = "wait_firststrike_bait", Score = 515.0, SuppressMove = true, SuppressAttack = false };
            }
        }

        // --- Mode 4: Wait out an unacted enemy's expiring Shieldwall / Riposte / Spearwall (when safe from being hit first) ---
        local atk = this.cheapestMeleeSkill(_actor);
        if (!isShield && atk != null && (!_info.LightMeleeVolleyRush || inZoC))
        {
            local isReach2 = atk.getMaxRange() >= 2;
            local safeToWaitBuff = !inZoC || (tb.Phase1MeleeAdj == 0);
            if (safeToWaitBuff)
            {
                local reachable = 0;
                local allExpiringBuff = true;
                foreach (foe in _info.Enemies)
                {
                    if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    local ft = foe.getTile();
                    local d = myTile.getDistanceTo(ft);
                    if (d < atk.getMinRange() || d > (inZoC ? atk.getMaxRange() : atk.getMaxRange() + 1)) continue;
                    if (inZoC && !atk.isUsableOn(ft, myTile)) continue;
                    ++reachable;
                    local fs = foe.getSkills();
                    local hasDefBuff = fs.hasSkill("effects.shieldwall") || fs.hasSkill("effects.riposte") || fs.hasSkill("effects.spearwall");
                    local actsInP1 = (foe.getID() in tb.Phase1Set);
                    if (!hasDefBuff || !actsInP1)
                    {
                        allExpiringBuff = false;
                        break;
                    }
                }
                if (reachable > 0 && allExpiringBuff)
                    return { Reason = "wait_buff_expire", Score = inZoC ? 740.0 : 530.0, SuppressMove = true, SuppressAttack = inZoC };
            }
        }

        // --- Mode 3: Coordinated Surround & Armor-Strip Phase-2 Focus-Fire Wait ---
        // Wait for slower Phase-1 allies (Shieldbearers, Undead summons, 2H Hammer / 2H Mace armor-shredders) to step in,
        // surround the target (+10-20% hitchance), and strip armor FIRST, so our fast DPS deletes them together in Phase 2!
        if (!isShield && atk != null && tb.Phase1Allies.len() > 0 && _actor.getHitpointsPct() >= 0.45)
        {
            local self = this;
            // Helper: evaluate combo payoff from unacted Phase-1 allies on a specific target _foe.
            local function checkComboOnTarget( _foe ) {
                if (_foe == null || _foe.getMoraleState() == ::Const.MoraleState.Fleeing)
                    return { Worth = false };
                // Never wait on unacted high-burst Berserkers, hostile casters, or archers (kill/lock them immediately!).
                local fs = _foe.getSkills();
                if (_foe.ClassName == "orc_berserker" || fs.hasSkill("effects.berserker_rage")
                    || fs.hasSkill("actives.raise_undead") || fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma"))
                    return { Worth = false };
                local ft = _foe.getTile();
                local foeInP1 = (_foe.getID() in tb.Phase1Set);
                local foePinned = ft.getZoneOfControlCountOtherThan(_foe.getAlliedFactions()) > 0;
                // Never delay hitting enemy archers/ranged units; when already in ZoC require target already acted/stunned/netted/pinned;
                // when unengaged (!inZoC), waiting on a non-ranged melee target is safe and lets both allies surround AND unpinned foes step into our kill zone!
                if (_foe.isArmedWithRangedWeapon())
                    return { Worth = false };
                if (inZoC && foeInP1 && !_foe.getCurrentProperties().IsStunned && !fs.hasSkill("effects.net")
                    && (!foePinned || _foe.getIdealRange() >= 2))
                    return { Worth = false };

                local curAdjAllies = 0;
                for (local d = 0; d < 6; ++d)
                {
                    if (!ft.hasNextTile(d)) continue;
                    local nt = ft.getNextTile(d);
                    if (nt.IsOccupiedByActor && ::Math.abs(nt.Level - ft.Level) <= 1 && nt.getEntity().isAlliedWith(_actor))
                        ++curAdjAllies;
                }

                local p1MeleeApproachers = 0;
                local p1ArmorShredders = 0;
                local bodyArm = _foe.getArmor(::Const.BodyPart.Body);
                local iAmFleshBurst = self.isFleshBurstWeapon(_actor);

                foreach (ally in tb.Phase1Allies)
                {
                    if (ally.getActionPoints() < 4 || ally.getCurrentProperties().IsRooted) continue;
                    local at = ally.getTile();
                    local ad = at.getDistanceTo(ft);
                    local aIsRanged = self.isRangedRole(ally);
                    if (aIsRanged)
                    {
                        if (iAmFleshBurst && bodyArm >= 90 && self.isArmorShredder(ally) && ad <= 6)
                            ++p1ArmorShredders;
                        continue;
                    }
                    if (self.isCasterRole(ally))
                        continue;
                    local reachMax = ally.getIdealRange() >= 2 ? 4 : 3;
                    if (ad <= reachMax)
                    {
                        if (ad > 1 && ally.getIdealRange() <= 1 && at.getZoneOfControlCountOtherThan(ally.getAlliedFactions()) == 0)
                            ++p1MeleeApproachers;
                        else if (ad == 1 && !::BGP.hasShield(ally) && self.isArmorShredder(ally))
                            ++p1ArmorShredders;
                        if (iAmFleshBurst && bodyArm >= 90 && self.isArmorShredder(ally)
                            && (ad <= (ally.getIdealRange() >= 2 ? 3 : 2) || (ad == 1)))
                            ++p1ArmorShredders;
                    }
                }

                local hit = 65;
                try { hit = atk.getHitchance(_foe); } catch (e) {}
                local armorStripCombo = (iAmFleshBurst && bodyArm >= 90 && p1ArmorShredders >= 1);
                local surroundCombo = (p1MeleeApproachers >= 1 && (curAdjAllies <= 1 || hit < 65));
                return {
                    Worth = armorStripCombo || surroundCombo,
                    ArmorStrip = armorStripCombo,
                    Surround = surroundCombo
                };
            };

            if (inZoC)
            {
                // IRONCLAD IN-ZOC SAFETY: only wait in melee contact when ZERO adjacent dangerous enemies can swing before Phase 2!
                if (tb.Phase1MeleeAdj == 0)
                {
                    local adjTargets = 0;
                    local allWorth = true;
                    foreach (foe in _info.Enemies)
                    {
                        if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                        local ft = foe.getTile();
                        local d = myTile.getDistanceTo(ft);
                        if (d < atk.getMinRange() || d > atk.getMaxRange() || !atk.isUsableOn(ft, myTile)) continue;
                        ++adjTargets;
                        local res = checkComboOnTarget(foe);
                        if (!res.Worth) { allWorth = false; break; }
                    }
                    if (adjTargets > 0 && allWorth)
                        return { Reason = "wait_combo_inzoc", Score = 740.0, SuppressMove = true, SuppressAttack = true };
                }
            }
            else
            {
                // Unengaged DPS waiting to pile onto an already-safe target once slower tank/hammer/summons surround or strip it!
                local plan = this.findSameTurnStrikePlan(_actor, _info.Enemies);
                if (plan != null && plan.Enemy != null)
                {
                    local res = checkComboOnTarget(plan.Enemy);
                    if (res.Worth)
                        return { Reason = "wait_surround_focus", Score = 525.0, SuppressMove = true, SuppressAttack = false };
                }
            }
        }

        return null;
    },

    // Continuous enemy elite threat rating (scales across all game stages using relative skill-vs-defense deltas & turn order).
    function enemyEliteScore( _foe, _info = null )
    {
        if (!this.isDangerousMeleeEnemy(_foe))
            return 0.0;
        local score = 0.0;
        local skills = _foe.getSkills();
        local st = this.enemyLiveStats(_foe);
        local sq = this.enemySquadThreat(_foe, _info);
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
            || cn == "swordmaster" || cn == "blade_dancer" || cn == "desert_devil" || cn == "nomad_leader" || cn == "rf_fencer"
            || cn == "lindwurm" || cn == "unhold" || cn == "schrat")
            score += 1.25;
        // Relative offensive threat (foe.MSk - ally.MDef + surround) & relative evasiveness (our avg MSk - foe.MDef) + turn order.
        if (sq.MaxHit >= 65) score += 1.05;
        else if (sq.MaxHit >= 48) score += 0.55;
        else if (sq.MaxHit <= 22) score -= 0.35;
        if (sq.AvgAllyMSk - st.MDef <= 45) score += 0.45;
        if (st.CanActThisRound && st.TurnsUntil <= 3) score += 0.35;
        if (st.IsExhausted) score -= 0.45;
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
        return ::Math.maxf(0.0, score);
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
        if (_actor.getSkills().hasSkill("perk.battle_forged") && _actor.getArmor(::Const.BodyPart.Body) >= 100
            && (_actor.getFlags().has("undead") || (_actor.getHitpointsPct() > 0.22 && _actor.getMoraleState() > ::Const.MoraleState.Wavering)))
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
                // High-ground discipline: never pin an uphill melee/polearm enemy from below when we can engage equal-level targets or lure them down!
                if (!pinsChiefThreat)
                {
                    local uphill = this.isUphillMeleeTrap(dest, _actor, _info);
                    if (uphill.IsTrap || (uphill.PolearmTrap && !canSWAfter))
                        continue;
                }
                // Against melee-only enemies with NO ranged weapons, don't march a shieldbearer forward to feed Zombies first strike unless peeling Mentor or striking this turn!
                if (_info.NoEnemyRanged && !pinsChiefThreat)
                {
                    local shAtk = this.cheapestMeleeSkill(_actor, true);
                    local canStrikeDest = false;
                    if (shAtk != null && shAtk.isUsableOn(ft, dest))
                    {
                        local effSh = this.previewSkillCostsAfterMove(_actor, shAtk, cost);
                        if (ap - cost.ActionPointsRequired >= effSh.AP && availFat - cost.FatigueRequired >= effSh.Fat)
                            canStrikeDest = true;
                    }
                    if (!canStrikeDest)
                        continue;
                }

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
                if (!breachCh && (_info.EnemyProjectileRanged >= 3.0 || _info.NoEnemyRanged)) continue;
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
                // High-ground discipline: never dive adjacent below uphill melee enemies unless executing a lethal kill or peeling Mentor.
                local urgentMentorPeel = (foeBreachChief && _actor.getHitpointsPct() >= 0.45);
                if (!fleeing && !isLethalStrike && !urgentMentorPeel && this.isUphillMeleeTrap(dest, _actor, _info).IsTrap)
                    continue;
                // Fragile bros must not burn all AP walking into melee with zero attack left (except healthy Mentor breach peel).
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

    // Cohesive R1-R2 advance against hybrid heavy-ranged + strong-melee armies (e.g. Nomad mega-camps, Southern/Noble stacks):
    // Shieldbearers advance 1-2 tiles together keeping full Shieldwall AP/Fat; unshielded melee step 1-2 tiles right behind/beside them
    // with ranged cover instead of scattering 4 tiles ahead into Executioners/Desert Devils/Halberdiers!
    function findCohesiveAdvanceTile( _behavior, _actor, _info )
    {
        if (::Time.getRound() > 2 || !_info.HybridRangedHeavyMelee || _info.HoldLine)
            return null;
        if (this.isRangedRole(_actor) || this.isCasterRole(_actor) || _actor.getCurrentProperties().IsRooted)
            return null;
        local myTile = _actor.getTile();
        if (myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0)
            return null;
        local atk = this.cheapestMeleeSkill(_actor);
        if (atk != null && this.hasAdjacentTarget(_actor, atk, _info.Enemies))
            return null;
        // Never pass up a real same-turn step-and-attack (e.g. R2 2-tile polearms or counter-strikers).
        if (this.findSameTurnStrikePlan(_actor, _info.Enemies) != null)
            return null;

        local isShield = ::BGP.hasShield(_actor);
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local reserveAP = 0;
        local reserveFat = 0;
        if (isShield)
        {
            local sw = _actor.getSkills().getSkillByID("actives.shieldwall");
            if (sw != null && !sw.isHidden() && sw.isUsable())
            {
                reserveAP = sw.getActionPointCost();
                reserveFat = sw.getFatigueCost();
            }
        }
        local moveAPBudget = isShield ? (ap - reserveAP) : ::Math.min(ap, 4);
        if (moveAPBudget < 2)
            return null;

        local curEnemyDist = 99;
        local nearestFoeTile = null;
        foreach (foe in _info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < curEnemyDist) { curEnemyDist = d; nearestFoeTile = ft; }
        }
        if (nearestFoeTile == null || curEnemyDist <= 2)
            return null;

        local chiefTile = null;
        foreach (bro in _info.Brothers)
            if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }

        local navigator = ::Tactical.getNavigator();
        local settings = this.navSettings(_actor, navigator);
        local candidates = this.tilesInRange(myTile, 1, 2);
        local bestTile = null;
        local bestScore = 0.0;

        foreach (dest in candidates)
        {
            if (!dest.IsEmpty || dest.ID == myTile.ID) continue;
            if (_behavior.hasNegativeTileEffect(dest, _actor)) continue;
            local dZoc = dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions());
            if (!isShield && dZoc > 0) continue;
            if (isShield && dZoc > 1) continue;

            local newEnemyDist = 99;
            foreach (foe in _info.Enemies)
            {
                if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                local d = dest.getDistanceTo(foe.getTile());
                if (d < newEnemyDist) newEnemyDist = d;
            }
            local climbs = dest.Level > myTile.Level;
            if (newEnemyDist >= curEnemyDist && !(climbs && newEnemyDist == curEnemyDist))
                continue;
            // Unshielded melee never step within 2 tiles of unengaged dangerous melee killers on opening R1-R2 without striking!
            local newMeleeDist = this.nearestDangerousMeleeDistAt(dest, _info.Enemies);
            if (!isShield && newMeleeDist <= 2)
                continue;
            // High-ground discipline: never park cohesive advance below uphill melee or inside uphill polearm reach.
            local uphillAdv = this.isUphillMeleeTrap(dest, _actor, _info);
            if (uphillAdv.IsTrap || uphillAdv.PolearmTrap)
                continue;

            if (!navigator.findPath(myTile, dest, settings, 0)) continue;
            local cost = navigator.getCostForPath(_actor, settings, moveAPBudget, availFat);
            if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.Tiles > 2 || cost.ActionPointsRequired > moveAPBudget)
                continue;
            if (isShield && reserveFat > 0 && (availFat - cost.FatigueRequired) < reserveFat)
                continue;

            local exp = this.evaluateTileExposure(_actor, dest, _info);
            if (exp.AdjAllies == 0 && exp.NearAllies2 < 2)
                continue;

            local sc = (curEnemyDist - newEnemyDist) * 14.0
                + ::Math.min(2, exp.AdjAllies) * 10.0
                + ::Math.min(2, exp.AdjShieldAllies) * (isShield ? 8.0 : 12.0)
                + ::Math.min(3, exp.NearAllies2) * 3.5
                + this.scoreTerrainAdvantage(_actor, dest, myTile, _info.Enemies, isShield ? "tank" : "dps") * 0.75
                - cost.ActionPointsRequired * 0.5;
            if (isShield)
            {
                if (exp.AdjEnemies >= 2) sc -= 18.0;
                if (chiefTile != null && dest.getDistanceTo(chiefTile) <= 4 && dest.getDistanceTo(nearestFoeTile) < chiefTile.getDistanceTo(nearestFoeTile))
                    sc += 8.0;
            }
            else
            {
                if (this.hasRangedCoverAt(dest, _actor, _info.Enemies, 8))
                    sc += 10.0;
                if (exp.Polearms2 >= 1 && exp.AdjShieldAllies == 0)
                    sc -= 10.0;
            }
            if (sc > bestScore) { bestScore = sc; bestTile = dest; }
        }
        return bestTile;
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
            local st = this.enemyLiveStats(foe);
            local sq = this.enemySquadThreat(foe, _info);
            // Compute marginal hit-chance value of Net's -45% MDef based on our nearby attackers' actual MSk + surround vs foe MDef!
            local adjFriendlyAttackers = 0;
            local minNearbyHit = 95;
            for (local d0 = 0; d0 < 6; ++d0)
            {
                if (!ft.hasNextTile(d0)) continue;
                local nt0 = ft.getNextTile(d0);
                if (!nt0.IsOccupiedByActor) continue;
                local a0 = nt0.getEntity();
                if (a0.isAlive() && a0.isAlliedWith(_actor) && !this.isCasterRole(a0) && !this.isRangedRole(a0))
                    ++adjFriendlyAttackers;
            }
            local surrOnFoe = foe.getSkills().hasSkill("perk.underdog") ? 0 : ::Math.max(0, adjFriendlyAttackers - 1) * 5;
            foreach (bro in _info.Brothers)
            {
                if (this.isCasterRole(bro) || this.isRangedRole(bro)) continue;
                if (bro.getTile().getDistanceTo(ft) <= 2)
                {
                    local estHit = ::Math.max(5, ::Math.min(95, bro.getCurrentProperties().getMeleeSkill() - st.MDef + surrOnFoe));
                    if (estHit < minNearbyHit) minNearbyHit = estHit;
                }
            }
            if (minNearbyHit == 95)
                minNearbyHit = ::Math.max(5, ::Math.min(95, sq.AvgAllyMSk - st.MDef + surrOnFoe));

            local sc = 15.0 + elite * 24.0;
            if (nearChief) sc += 22.0;
            if (unengaged) sc += 14.0;
            // High marginal net value when our attackers' actual hit chance (including surround) is suppressed <= 55%.
            if (minNearbyHit <= 38) sc += 24.0;
            else if (minNearbyHit <= 55) sc += 14.0;
            // High relative offensive threat against our threatened brothers.
            if (sq.MaxHit >= 55) sc += 14.0;
            // Turn-order priority: net dangerous enemies BEFORE they move/act this round!
            if (st.CanActThisRound) sc += (st.TurnsUntil <= 3 ? 14.0 : 8.0);
            else if (!nearChief) sc -= 10.0;
            if (st.IsExhausted && !nearChief) sc -= 14.0;
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
                || foe.ClassName == "desert_devil" || foe.ClassName == "executioner"
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
        // After executing a cohesive R1-R2 formation step or uphill-bait stand-off step, do not let vanilla EngageMelee spend leftover AP scattering!
        local fl = _agent != null ? _agent.getBehavior(::Const.AI.Behavior.ID.BGP_Frontline) : null;
        if (fl != null && (("CohesiveMovedRound" in fl.m) && fl.m.CohesiveMovedRound == ::Time.getRound()
            || ("UphillBaitRound" in fl.m) && fl.m.UphillBaitRound == ::Time.getRound()))
            return true;
        local decision = this.shouldActorHold(_actor, _agent);
        if (decision.Hold)
            return true;
        // Suppress EngageMelee when Initiative/turn-order tactical Wait wants to hold Phase 1 for surround, first-strike, or uphill lure!
        local waitPlan = this.evaluateTacticalWait(_actor, decision.Info, _agent);
        if (waitPlan != null && waitPlan.SuppressMove)
            return true;
        if (!::BGP.hasShield(_actor) && !this.isRangedRole(_actor) && !this.isCasterRole(_actor)
            && ::Tactical.TurnSequenceBar.canEntityWait(_actor)
            && _actor.getTile().getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) == 0
            && this.hasUnactedShieldAlly(_actor, decision.Info))
            return true;
        return false;
    },

    function shouldSuppressEngageRanged( _actor, _agent, _targetTile, _skill = null )
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
        // Never allow Mentor (caster) to undo a same-turn kite, walk forward without enough AP to cast, or step closer into melee/sniper danger for pale_weaken!
        if (this.isCasterRole(_actor))
        {
            local liveCnt = 0;
            foreach (e in decision.Info.Enemies)
                if (e.getMoraleState() != ::Const.MoraleState.Fleeing) ++liveCnt;
            local isEndgame = (liveCnt <= 2) || (liveCnt <= 3 && ::Time.getRound() >= 14);
            if (_targetTile.ID != myTile.ID)
            {
                local fl = _agent.getBehavior(::Const.AI.Behavior.ID.BGP_Frontline);
                if (fl != null && fl.m.KitedRound == ::Time.getRound())
                    return true;
                if (_skill != null && !isEndgame)
                {
                    local minStepAP = myTile.getDistanceTo(_targetTile) * 2;
                    if (_actor.getActionPoints() - minStepAP < _skill.getActionPointCost())
                        return true;
                }
            }
            local curArch = this.nearestEnemyArcherDist(myTile, decision.Info.Enemies);
            local newArch = this.nearestEnemyArcherDist(_targetTile, decision.Info.Enemies);
            local isGoblinPoisoned = _actor.getSkills().hasSkill("effects.goblin_poison");
            local lowHpMentor = _actor.getHitpointsPct() < 0.55 || (isGoblinPoisoned && _actor.getHitpointsPct() < 0.78);
            local destHasCover = this.hasRangedCoverAt(_targetTile, _actor, decision.Info.Enemies, 8);
            local extremeVolley = decision.Info.EnemyProjectileRanged >= 10.0;
            if (decision.Info.EnemyProjectileRanged >= 3.0 && newArch <= 7 && newArch < curArch && (lowHpMentor || !destHasCover || extremeVolley))
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
            // In endgame cleanup (<= 2 active enemies, or <= 3 from round 14+, healthy Mentor staying >= 3 tiles away),
            // allow Mentor to walk into pale_weaken range (3-4 tiles) to finish armored/shielded holdouts!
            local endgameCleanup = (isEndgame && !lowHpMentor && newMelee >= 3);
            if (!endgameCleanup && _skill != null && _skill.getID() == "actives.pale_weaken" && _targetTile.ID != myTile.ID && newMelee <= 4 && newMelee < curMelee)
                return true;
            if (!endgameCleanup && newMelee <= 4 && newMelee < curMelee && nearestThreatTile != null)
            {
                local scr = this.countScreenBlockersBetween(_targetTile, _actor, nearestThreatTile);
                if (scr.Blockers == 0)
                    return true;
            }
            // Never walk Mentor onto an isolated tile with zero adjacent allies while live melee threats exist within 4 tiles (except safe >= 3 endgame cleanup).
            if (!endgameCleanup && newMelee <= 4)
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
        else if (this.isRangedRole(_actor) && _targetTile.ID != myTile.ID)
        {
            // Suppress premature forward stepping when ranged tactical Wait wants slower Phase-1 enemies to step into range first.
            local rWait = this.evaluateTacticalWait(_actor, decision.Info, _agent);
            if (rWait != null && rWait.SuppressMove)
                return true;
            // Prevent non-caster Bow/Crossbow/Throwing backliners from walking INTO dist <= 2 of a live melee threat
            // (which otherwise causes Engage.Ranged -> backline_kite ping-pong burning AP without firing!).
            local curMelee = 99;
            local newMelee = 99;
            foreach (foe in decision.Info.Enemies)
            {
                if (!this.isLiveBacklineThreat(foe)) continue;
                local ft = foe.getTile();
                local cd = myTile.getDistanceTo(ft);
                local nd = _targetTile.getDistanceTo(ft);
                if (cd < curMelee) curMelee = cd;
                if (nd < newMelee) newMelee = nd;
            }
            if (newMelee <= 2 && (curMelee > 2 || newMelee < curMelee))
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

        // 1. Strongly prioritize guaranteed / likely kills on active enemies (extra weight for Berserk chaining & denying unacted enemy turns!).
        local stLive = this.enemyLiveStats(_target);
        if (isLethal)
        {
            mult *= 1.60 + 0.40 * ::Math.minf(1.0, (hit - 35) / 45.0);
            if (_actor.getSkills().hasSkill("perk.berserk"))
                mult *= 1.15;
            if (stLive.CanActThisRound)
                mult *= (stLive.TurnsUntil <= 3 ? 1.28 : 1.16);
        }
        else if (!fleeing && hpPct <= 0.45)
            mult *= 1.0 + (0.50 - hpPct) * 1.15;

        // 1b. Relative threat to our threatened brothers (foe.MSk/RSk - ally.MDef/RDef + surround) & turn-order urgency.
        if (!fleeing && !isLethal)
        {
            local sqT = this.enemySquadThreat(_target, null);
            if (!stLive.IsExhausted)
            {
                if (sqT.MaxHit >= 55)
                    mult *= 1.24;
                else if (sqT.MaxHit <= 22 && _target.getTile().getZoneOfControlCountOtherThan(_target.getAlliedFactions()) > 0)
                    mult *= 0.85;
            }
            if (stLive.CanActThisRound && stLive.TurnsUntil <= 3)
                mult *= 1.12;
            if (stLive.IsExhausted)
                mult *= 0.88;
        }

        // 2. Focus armor-stripped enemies and heavily surrounded targets so Phase-2 waiting brothers chain-burst the SAME enemy down!
        if (!fleeing && _target.getArmorMax(::Const.BodyPart.Body) > 30 && bodyArmor <= 10)
            mult *= 1.20;
        if (!fleeing)
        {
            local tTile = _target.getTile();
            local adjAllies = 0;
            for (local d = 0; d < 6; ++d)
            {
                if (!tTile.hasNextTile(d)) continue;
                local nt = tTile.getNextTile(d);
                if (nt.IsOccupiedByActor && ::Math.abs(nt.Level - tTile.Level) <= 1 && nt.getEntity().isAlliedWith(_actor))
                    ++adjAllies;
            }
            if (adjAllies >= 3)
                mult *= 1.22;
            else if (adjAllies >= 2)
                mult *= 1.12;
            // In Phase 2 (after Waiting), reinforce coordinated focus-fire on surrounded, armor-stripped, or wounded targets to trigger morale cascades!
            local isPhase2 = false;
            try { isPhase2 = _actor.isWaitActionSpent(); } catch (e) {}
            if (isPhase2 && (adjAllies >= 2 || hpPct <= 0.65 || (_target.getArmorMax(::Const.BodyPart.Body) > 30 && bodyArmor <= 25)))
                mult *= 1.12;
        }

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
            else if (tSkills.hasSkill("actives.raise_undead"))
                mult *= _skill.isRanged() ? 2.75 : 2.15;
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
            else if (_target.ClassName == "executioner" || _target.ClassName == "desert_devil")
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
            // When a live melee threat is already within 2 tiles, discourage burning 7 AP on Aimed Shot if Quick Shot (4 AP) is available,
            // so the archer shoots FIRST at close range AND keeps enough AP left to kite safely afterwards!
            if (_skill.getID() == "actives.aimed_shot" && !this.isCasterRole(_actor))
            {
                local qs = _actor.getSkills().getSkillByID("actives.quick_shot");
                if (qs != null && !qs.isHidden() && qs.isUsable() && qs.isAffordable())
                {
                    local enemies = this.collectEnemies(_actor, null);
                    if (this.nearestLiveBacklineThreatDist(_actor, enemies) <= 2)
                    {
                        local stepAP = 2;
                        try { stepAP = ::Math.max(2, _actor.getActionPointCosts()[_actor.getTile().Type]); } catch (e) {}
                        if (_actor.getActionPoints() - _skill.getActionPointCost() < stepAP * 2)
                            mult *= 0.25;
                    }
                }
            }
            if (_target.getTile().getZoneOfControlCountOtherThan(_target.getAlliedFactions()) == 0)
                mult *= 1.24;
            local weapon = _actor.getMainhandItem();
            local isBow = weapon != null && weapon.isWeaponType(::Const.Items.WeaponType.Bow);
            if (tSkills.hasSkill("effects.shieldwall"))
                mult *= 0.48;
            // Relative hit-chance targeting (already incorporates our RSk - foe.RDef + height + shield + cover):
            // avoid dumping shots into <30% brick walls, reward clean >=65% high-hit shots!
            if (hit < 30)
                mult *= 0.55;
            else if (hit < 42 && _target.isArmedWithShield())
                mult *= 0.70;
            else if (hit >= 65 && !fleeing)
                mult *= 1.15;
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
            if (tSkills.hasSkill("effects.shieldwall") && _skill.getID() != "actives.split_shield" && hit < 60)
                mult *= 0.52;
            // Relative hit-chance targeting via engine getHitchance (already fuses our MSk - foe.MDef + real-time surround bonus + height):
            // low-hit brothers pivot away from turtle walls, while high-MSk/surrounding attackers smash right through!
            local sid = _skill.getID();
            local isArmorBreaker = sid == "actives.split_shield" || sid == "actives.destroy_armor" || sid == "actives.crush_armor"
                || sid == "actives.smite" || sid == "actives.shatter" || sid == "actives.rf_pummel";
            if (sid != "actives.split_shield" && sid != "actives.knock_out")
            {
                if (hit < 30)
                    mult *= 0.52;
                else if (hit < 45 && _target.isArmedWithShield() && !tSkills.hasSkill("effects.shieldwall"))
                    mult *= 0.68;
                else if (hit >= 70)
                    mult *= 1.15;
            }
            // Deprioritize ultra-heavy armored shield tanks for normal blades/spears, EXCEPT armor-shredding Hammers (smite/shatter/rf_pummel) which LOVE heavy armor!
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
            if (sid == "actives.knock_out" || sid == "actives.strike_down")
            {
                if (!fleeing && !_target.getCurrentProperties().IsImmuneToStun && !_target.getCurrentProperties().IsStunned)
                {
                    local w = _target.getMainhandItem();
                    local heavy = (w != null && w.isItemType(::Const.Items.ItemType.TwoHanded))
                        || _target.getHitpointsMax() >= 120 || tSkills.hasSkill("racial.champion")
                        || tSkills.hasSkill("effects.berserker_rage");
                    mult *= heavy ? 1.25 : 0.45;
                    // Turn-order stun discipline: stunning an unacted heavy enemy before they swing denies their entire turn!
                    if (!stLive.CanActThisRound)
                        mult *= 0.45;
                    else if (stLive.TurnsUntil <= 4)
                        mult *= 1.18;
                }
                else
                {
                    mult *= 0.25;
                }
            }
        }

        return _score * mult;
    },

    function isHeavyMeleeThreat( _foe, _defender = null )
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
        local st = this.enemyLiveStats(_foe);
        local relHit = _defender != null ? this.enemyEffectiveHitOn(_foe, _defender) : this.enemySquadThreat(_foe, null).MaxHit;
        if (relHit >= 58 && !st.IsExhausted)
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

        // Scan enemies in throwing range (2..4 + elevation) with clear Line of Sight, and long ranged range (5..7).
        local throwMaxRng = 4 + ::Math.max(0, myTile.Level);
        local vision = _actor.getCurrentProperties().getVision();
        local closeLive = 0;
        local closeNonSkel = 0;
        local closeArmoredOrSkel = 0;
        local closeSkel = 0;
        local longLive = 0;
        local anyLive = 0;
        foreach (foe in _info.Enemies)
        {
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < 2) continue;
            local active = foe.getMoraleState() != ::Const.MoraleState.Fleeing;
            if (active) ++anyLive;
            if (d <= throwMaxRng && (active || anyLive == 0))
            {
                if (!myTile.hasLineOfSightTo(ft, vision)) continue;
                ++closeLive;
                if (foe.getFlags().has("skeleton"))
                {
                    ++closeSkel;
                    ++closeArmoredOrSkel;
                }
                else
                {
                    ++closeNonSkel;
                    if (foe.getArmor(::Const.BodyPart.Body) >= 120)
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
            if (bestThrow == null)
                return null;
            local bestThrowIsAxe = false;
            try { bestThrowIsAxe = bestThrow.isWeaponType(::Const.Items.WeaponType.Axe); } catch (e) {}
            // Never swap to piercing Javelins when only Ancient Skeletons (heavy pierce resistance) are in range!
            local validThrowClose = bestThrowIsAxe ? closeLive : closeNonSkel;
            if (validThrowClose == 0)
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
        //   - No valid target in throwing range (e.g. only pierce-resistant Skeletons for Javelins) AND enemies exist at range, OR
        //   - Cannot afford another throw (ap == 3 < minThrowAP) AND bag holds a LOADED Crossbow ready to fire for 3 AP!
        if (bestLongRanged != null)
        {
            local curIsAxe = false;
            try { curIsAxe = curMain.isWeaponType(::Const.Items.WeaponType.Axe); } catch (e) {}
            local curValidClose = curIsAxe ? closeLive : closeNonSkel;
            if (curOff != null && bestLongRanged.getBlockedSlotType() == ::Const.ItemSlot.Offhand && this.emptyBagSlots(items) <= 0)
                return null;
            local swapList = (curOff != null && bestLongRanged.getBlockedSlotType() == ::Const.ItemSlot.Offhand) ? [curMain, curOff, bestLongRanged] : [curMain, bestLongRanged];
            if (items.isActionAffordable(swapList))
            {
                local swapAP = items.getActionCost(swapList);
                if (swapAP == 0)
                {
                    if (curValidClose == 0 && (longLive > 0 || closeSkel > 0) && ap >= 3)
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
        if (cn == "orc_berserker" || cn == "goblin_wolfrider" || cn == "desert_devil" || cn == "executioner"
            || cn == "ghost" || cn == "rf_banshee")
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

    // Find the lowest AP cost among currently usable & affordable ranged weapon attacks with at least one valid target in sight/range.
    function findCheapestUsableRangedAP( _actor, _info )
    {
        local myTile = _actor.getTile();
        local bestAP = null;
        foreach (s in _actor.getSkills().m.Skills)
        {
            if (s == null || !s.m.IsActive || !s.m.IsAttack || !s.m.IsTargeted || !s.m.IsRanged || !s.m.IsWeaponSkill)
                continue;
            if (s.isHidden() || !s.isUsable() || !s.isAffordable())
                continue;
            local cost = s.getActionPointCost();
            if (bestAP != null && cost >= bestAP)
                continue;
            local maxR = s.getMaxRange();
            local minR = s.getMinRange();
            local hasTarget = false;
            foreach (foe in _info.Enemies)
            {
                local ft = foe.getTile();
                local d = myTile.getDistanceTo(ft);
                if (d < minR || d > maxR) continue;
                local ok = false;
                try { ok = s.isUsableOn(ft, myTile); } catch (e) { ok = false; }
                if (ok) { hasTarget = true; break; }
            }
            if (hasTarget)
                bestAP = cost;
        }
        return bestAP;
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
        local isGoblinPoisoned = isCaster && _actor.getSkills().hasSkill("effects.goblin_poison");
        local lowHpMentor = isCaster && (_actor.getHitpointsPct() < 0.55 || (isGoblinPoisoned && _actor.getHitpointsPct() < 0.78));
        local sniperRange = _info.EnemyProjectileRanged >= 5.0 ? (lowHpMentor ? 9 : 8) : 7;
        local hasCoverNow = isCaster ? this.hasRangedCoverAt(myTile, _actor, _info.Enemies, sniperRange) : true;
        // Against extreme sniper swarms (5+ dedicated shooters like Goblin24, EnemyProjectileRanged >= 10),
        // +50% adjacent soft cover is saturated within 7 tiles; step back to dist >= 8 even while healthy.
        local coverSaturated = isCaster && _info.EnemyProjectileRanged >= 10.0 && curArcherDist <= 7;
        // Stay put and keep casting when frontline allies block enemy ranged line of fire, unless Mentor HP < 55% (or goblin-poisoned < 78%) or cover is saturated.
        local sniperDanger = isCaster && _info.EnemyProjectileRanged >= 2.0 && curArcherDist <= sniperRange && (!hasCoverNow || lowHpMentor || coverSaturated);

        if (!meleeDanger && !sniperDanger)
            return null;

        // Threat-tiered AP budget:
        // - Mentor (caster): safety first (urgent high -> 6 AP; unscreened dist 3 -> 4 AP; healthy sniper/coverSaturated/fodder -> 2 AP).
        // - Non-caster Ranged (Bow/Crossbow/Throwing): SHOOT FIRST at closer distance for higher hit chance (+ Throwing Mastery dist-2 dmg
        //   & kill/Berserk chance!) whenever remaining AP after shooting still covers terrain escape cost, THEN kite immediately afterwards!
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
            local stepAP = 2;
            try { stepAP = ::Math.max(2, _actor.getActionPointCosts()[myTile.Type]); } catch (e) {}
            local needEscapeAP = threat.UrgentHigh ? (stepAP * 2) : stepAP;
            local cheapRangedAP = this.findCheapestUsableRangedAP(_actor, _info);
            // Shoot FIRST at dist <= 2 if we have a usable ranged attack AND enough AP left afterwards to retreat safely!
            if (cheapRangedAP != null && ap - cheapRangedAP >= needEscapeAP)
                return null;
            // Also allow free-swap Crossbow -> Throwing at dist 2 when non-urgent and remaining AP still leaves a 1-tile step (e.g. 6 AP -> 4 AP Throw -> 2 AP kite).
            if (cheapRangedAP == null && !threat.UrgentHigh && ap >= 4 + needEscapeAP)
            {
                local hSwap = this.findHybridRangedSwap(_actor, _info);
                if (hSwap != null && !hSwap.EmptyBundle)
                    return null;
            }
            maxMoveAP = threat.UrgentHigh ? ::Math.min(ap, stepAP * 2) : ::Math.min(ap, stepAP);
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
                if (newArcherDist <= curArcherDist && (coverSaturated || !(newCover && !hasCoverNow))) continue;
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
        // No unshielded bro without Indomitable should walk into 3+ adjacent enemies unless high-MDef Underdog with attack AP left!
        if (exp.AdjEnemies >= 3 && (exp.AdjAllies == 0 || mdef < 35 || isFragile || !hasUnderdog || _apAfter < minAtkAP))
            return true;
        // Stop isolated solo flank leaps (zero allies even within 2 tiles, zero attack AP left) into enemy convergence
        // (allow BF frontliners to rush pure light-melee archer swarms like Goblin24, NOT Nomad Executioner/Desert Devil hybrids!).
        if (exp.AdjAllies == 0 && exp.NearAllies2 == 0 && _apAfter < minAtkAP
            && !(_info.LightMeleeVolleyRush && !isFragile && exp.AdjEnemies <= 1)
            && (exp.AdjEnemies >= 1 || exp.ThreatDist2 >= 2 || exp.Polearms2 >= 1))
            return true;
        // Stop unshielded melee brothers (e.g. 2H Hammer/Sword) from sprinting 3+ tiles ahead of the frontline on opening R1-R2
        // into isolated forward tiles (dAllies == 0, no shield/undead support, zero attack AP left) where enemies swarm them next turn!
        // Restrict to opening rounds (<= 2) so mid/late-battle flankers returning from killing backline Priests never freeze in Idle!
        local moveDist = _actor.getTile().getDistanceTo(_destTile);
        if (::Time.getRound() <= 2 && moveDist >= 3 && _apAfter < minAtkAP
            && !(_info.LightMeleeVolleyRush && !isFragile && exp.AdjEnemies <= 1))
        {
            if (_info.HybridRangedHeavyMelee && (exp.AdjAllies == 0 || (exp.AdjShieldAllies == 0 && this.nearestDangerousMeleeDistAt(_destTile, _info.Enemies) <= 4)))
                return true;
            if (exp.AdjAllies == 0 && exp.AdjShieldAllies == 0)
            {
                local nearEnemies3 = 0;
                foreach (foe in _info.Enemies)
                {
                    if (this.isDangerousMeleeEnemy(foe) && _destTile.getDistanceTo(foe.getTile()) <= 3)
                        ++nearEnemies3;
                }
                if (nearEnemies3 >= 2)
                    return true;
            }
        }
        // On opening R1-R2, prevent unshielded frontliners from stepping 2+ tiles into ZoC with insufficient post-move AP to strike
        // (using dynamic previewSkillCostsAfterMove AP, so Vigorous Assault / Vanquisher bros who CAN strike after moving 2 tiles are never blocked!)
        // right in front of enemy polearms / 3+ convergence traps without an adjacent Shieldbearer protecting them!
        if (::Time.getRound() <= 2 && moveDist >= 2 && _apAfter < minAtkAP
            && exp.AdjEnemies >= 1 && exp.AdjShieldAllies == 0 && (exp.Polearms2 >= 1 || exp.PotentialSurround >= 3)
            && !(_info.LightMeleeVolleyRush && !isFragile && exp.AdjEnemies <= 1))
            return true;
        // Never walk into a Halberdier/Ancient Polearm kill-box (2+ adjacent + reach-2 polearms) with zero shield support and zero attack AP left!
        if (exp.AdjEnemies >= 2 && (exp.Polearms2 >= 2 || (exp.Polearms2 >= 1 && mdef < 28)) && exp.AdjShieldAllies == 0 && _apAfter < minAtkAP && mdef < 35)
            return true;
        if (exp.AdjEnemies >= 2 && exp.AdjAllies == 0 && _apAfter < minAtkAP && (exp.Polearms2 >= 1 || exp.ThreatDist2 >= 2) && mdef < 30)
            return true;
        if (!hasDefPerk && !hasUnderdog && exp.AdjEnemies >= 3 && exp.AdjShieldAllies == 0)
            return true;
        if (isFragile && exp.AdjAllies == 0 && exp.AdjEnemies >= 2)
            return true;
        if (isFragile && exp.AdjAllies == 0 && exp.AdjEnemies >= 1 && exp.ThreatDist2 >= 2)
            return true;
        // Prevent fragile low-MDef or no-BF/no-Nimble 1H unshielded bros from burning AP walking into melee contact with zero AP left to strike
        // against non-ranged/non-caster melee waves (do NOT paralyze 2H 6-AP heavy frontliners who normally move 2 tiles!).
        if (isFragile && (mdef < 18 || !hasDefPerk) && minAtkAP <= 4 && _apAfter < minAtkAP)
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
    },

    // =========================================================================
    // Gen 35: Zero-Friendly-Fire AoE Geometry, Step-and-Reap, Precision Decapitate & Mace Stun Discipline
    // =========================================================================

    // Return the exact engine-verified list of tiles hit by melee AoE skills from _origin aiming at _targetTile.
    // Verified against live Battle Brothers tactical execution:
    //   - Dist-1 3-tile arcs (shatter, swing, rf_cleaving_swing, sweep, tail_slam, ghost_swing, censer_castigate, dist-1 reap):
    //       dir d0 = origin.getDirectionTo(target), hits d0, (d0+5)%6, (d0+4)%6 (counterclockwise).
    //   - Dist-2 reap:
    //       12-tile clockwise dist-2 ring where ring[2*d] = origin->d->d and ring[2*d+1] = origin->d->(d+1)%6;
    //       targeting ring[k] hits ring[k], ring[(k+11)%12], ring[(k+10)%12] (counterclockwise).
    //   - Line split (split, rf_cleaving_split, split_axe, ignite_firelance, excalibur_split):
    //       targetTile + (_lineLen - 1) sequential steps along dir = origin.getDirectionTo(target).
    //   - 360-degree swings (thresh, round_swing, tail_slam_big):
    //       all 6 adjacent tiles around _origin.
    function getAoEAffectedTiles( _origin, _targetTile, _skillID, _maxLevelDiff = 1, _lineLen = 2 )
    {
        local out = [];
        if (_origin == null || _targetTile == null)
            return out;

        if (_skillID == "actives.thresh" || _skillID == "actives.round_swing" || _skillID == "actives.tail_slam_big")
        {
            for (local d = 0; d < 6; ++d)
            {
                if (!_origin.hasNextTile(d)) continue;
                local t = _origin.getNextTile(d);
                if (::Math.abs(t.Level - _origin.Level) <= _maxLevelDiff)
                    out.push(t);
            }
            return out;
        }

        if (_skillID == "actives.split" || _skillID == "actives.rf_cleaving_split"
            || _skillID == "actives.split_axe" || _skillID == "actives.ignite_firelance"
            || _skillID == "actives.tail_slam_split" || _skillID == "actives.uproot"
            || _skillID == "actives.ghost_split" || _skillID == "actives.excalibur_split")
        {
            local dir = _origin.getDirectionTo(_targetTile);
            local cur = _targetTile;
            local steps = ::Math.max(2, _lineLen);
            for (local i = 0; i < steps; ++i)
            {
                if (cur == null) break;
                if (::Math.abs(cur.Level - _origin.Level) <= _maxLevelDiff)
                    out.push(cur);
                if (i + 1 < steps && cur.hasNextTile(dir))
                    cur = cur.getNextTile(dir);
                else
                    break;
            }
            return out;
        }

        local dist = _origin.getDistanceTo(_targetTile);
        if (_skillID == "actives.reap" && dist == 2)
        {
            local ring2 = array(12, null);
            local hitIdx = -1;
            for (local d = 0; d < 6; ++d)
            {
                if (!_origin.hasNextTile(d)) continue;
                local mid = _origin.getNextTile(d);
                if (mid.hasNextTile(d))
                {
                    local c = mid.getNextTile(d);
                    ring2[2 * d] = c;
                    if (c.ID == _targetTile.ID) hitIdx = 2 * d;
                }
                local dn = (d + 1) % 6;
                if (mid.hasNextTile(dn))
                {
                    local e = mid.getNextTile(dn);
                    ring2[2 * d + 1] = e;
                    if (e.ID == _targetTile.ID) hitIdx = 2 * d + 1;
                }
            }
            if (hitIdx >= 0)
            {
                foreach (off in [0, 11, 10])
                {
                    local t = ring2[(hitIdx + off) % 12];
                    if (t != null && ::Math.abs(t.Level - _origin.Level) <= _maxLevelDiff)
                        out.push(t);
                }
            }
            return out;
        }

        // Default: dist-1 3-tile counterclockwise arc (reap at dist 1, shatter, swing, rf_cleaving_swing, sweep, censer_castigate, etc.)
        if (dist == 1)
        {
            local d0 = _origin.getDirectionTo(_targetTile);
            foreach (off in [0, 5, 4])
            {
                local dir = (d0 + off) % 6;
                if (!_origin.hasNextTile(dir)) continue;
                local t = _origin.getNextTile(dir);
                if (::Math.abs(t.Level - _origin.Level) <= _maxLevelDiff)
                    out.push(t);
            }
        }
        return out;
    },

    // Enumerate all candidate aim tiles in range around _origin for an AoE skill (including empty tiles for clean friendly-fire shift aiming).
    function collectAoEAimTiles( _origin, _skill )
    {
        local out = [];
        if (_origin == null || _skill == null)
            return out;
        local minR = _skill.getMinRange();
        local maxR = _skill.getMaxRange();
        local seen = {};
        for (local d = 0; d < 6; ++d)
        {
            if (!_origin.hasNextTile(d)) continue;
            local t1 = _origin.getNextTile(d);
            if (minR <= 1 && maxR >= 1 && !(t1.ID in seen))
            {
                seen[t1.ID] <- true;
                out.push(t1);
            }
            if (maxR >= 2)
            {
                foreach (d2 in [d, (d + 1) % 6])
                {
                    if (!t1.hasNextTile(d2)) continue;
                    local t2 = t1.getNextTile(d2);
                    if (_origin.getDistanceTo(t2) == 2 && !(t2.ID in seen))
                    {
                        seen[t2.ID] <- true;
                        out.push(t2);
                    }
                }
            }
        }
        return out;
    },

    // Compute exact part-aware mathematical expected damage for _skill against _target from _originTile:
    //   - Uses live hit chance P(hit) (with elevation delta when evaluating stepped origins)
    //   - Uses live headshot probability p_head & headshot crit mult (respecting Steel Brow / IsImmuneToCriticals / IsHeadless)
    //   - Evaluates Body and Head hits separately against live Head Armor vs Body Armor (plus Battle Forged / Nimble)
    //   - Discounts armor chipping on a thick secondary armor bar (e.g. 300 helm when body armor is already broken)
    //   - Models Head vs Body Temporary Injury value on living targets (crossing live light 25% / heavy 50% injury thresholds,
    //     respecting Crippling Strikes & target injury resistance, weighting severe head trauma higher than body injuries!)
    //   - Models 2H Axe actives.split_man exact 100% primary-part + 50% secondary-part split damage!
    function computeSkillExpectedDamage( _actor, _skill, _target, _originTile = null )
    {
        local hit = 55;
        try {
            hit = _skill.getHitchance(_target);
            if (_originTile != null && _originTile.ID != _actor.getTile().ID)
            {
                local tt = _target.getTile();
                local curLvlDiff = _actor.getTile().Level - tt.Level;
                local newLvlDiff = _originTile.Level - tt.Level;
                hit = ::Math.max(5, ::Math.min(95, hit + (newLvlDiff - curLvlDiff) * 10));
            }
        } catch (e) {}
        local hitF = hit * 0.01;

        local hp = ::Math.maxf(1.0, _target.getHitpoints().tofloat());
        local maxHP = ::Math.maxf(hp, _target.getHitpointsMax().tofloat());
        local bodyArm = _target.getArmor(::Const.BodyPart.Body).tofloat();
        local headArm = _target.getArmor(::Const.BodyPart.Head).tofloat();

        local usedExact = false;
        local onHitRawHP = 0.0;
        local onHitHP = 0.0;
        local onHitArm = 0.0;
        local onHitVal = 0.0;
        local pKill = 0.0;

        try {
            local p = _actor.getSkills().buildPropertiesForUse(_skill, _target);
            local tp = _target.getCurrentProperties();
            local regDmg = (p.DamageRegularMin + p.DamageRegularMax) * 0.5 * p.DamageRegularMult * p.DamageTotalMult;
            if (regDmg > 0.01)
            {
                local armDmgRaw = regDmg * p.DamageArmorMult;
                local skillDir = 0.0;
                try { skillDir = _skill.m.DirectDamageMult; } catch (e2) {}
                local dirMult = ::Math.maxf(0.0, ::Math.minf(1.0, (skillDir + p.DamageDirectAdd) * p.DamageDirectMult));

                local canHeadshot = !tp.IsImmuneToHeadshots;
                try { if (_target.m.IsHeadless) canHeadshot = false; } catch (e2) {}
                local headP = canHeadshot ? ::Math.maxf(0.0, ::Math.minf(1.0, p.getHitchance(::Const.BodyPart.Head) * 0.01)) : 0.0;
                local bodyP = 1.0 - headP;
                local headMult = tp.IsImmuneToCriticals ? 1.0 : p.DamageAgainstMult[::Const.BodyPart.Head];
                local bodyMult = p.DamageAgainstMult[::Const.BodyPart.Body];

                local armRecv = tp.DamageReceivedArmorMult * tp.DamageReceivedTotalMult;
                local hpRecv = tp.DamageReceivedRegularMult * tp.DamageReceivedTotalMult;
                local dirRecv = tp.DamageReceivedDirectMult;
                local tSkills = _target.getSkills();
                if (tSkills.hasSkill("perk.battle_forged"))
                    armRecv *= ::Math.maxf(0.10, 1.0 - 0.0005 * (bodyArm + headArm));
                local nmb = tSkills.getSkillByID("perk.nimble");
                if (nmb != null)
                {
                    try { hpRecv *= nmb.getChance(); } catch (e2) { hpRecv *= 0.50; }
                }

                // Temporary injury thresholds (respecting Crippling Strikes & target injury resistance; undead are immune).
                local canInjure = false;
                local lightInjThr = maxHP * 0.25;
                local heavyInjThr = maxHP * 0.50;
                try {
                    canInjure = tp.IsAffectedByInjuries;
                    if (canInjure)
                    {
                        local injMult = p.ThresholdToInflictInjuryMult * tp.ThresholdToReceiveInjuryMult;
                        lightInjThr = ::Math.maxf(10.0, maxHP * 0.25 * injMult);
                        heavyInjThr = ::Math.maxf(20.0, maxHP * 0.50 * injMult);
                    }
                } catch (e2) { canInjure = false; }

                // Helper: evaluate hitting one body part with live armor _partArm vs opposite bar _otherArm.
                local function evalPart( _partArm, _otherArm, _partMult, _scale, _isHead ) {
                    local r = regDmg * _scale;
                    local aRaw = armDmgRaw * _scale * armRecv;
                    local armHit = ::Math.minf(_partArm, aRaw);
                    local armAfter = ::Math.maxf(0.0, _partArm - armHit);

                    local dirHP = ::Math.maxf(0.0, r * dirMult * dirRecv - 0.10 * armAfter);
                    local ovfHP = (_partArm <= 0.01) ? r : (armAfter <= 0.01 ? ::Math.maxf(0.0, r - armHit) : 0.0);
                    local rawHP = ::Math.maxf(dirHP, ovfHP) * _partMult * hpRecv;
                    local effHP = ::Math.minf(rawHP, hp * 1.05);

                    // Smart armor-strip weight: chipping an intact thick bar (e.g. 300 helm) while the opposite bar
                    // (e.g. 20 body) is already broken/much thinner contributes far less to killing the target!
                    local armW = 0.50;
                    if (armHit > 0.01)
                    {
                        if (_partArm >= _otherArm + 140.0 && armAfter > 60.0)
                            armW = 0.15;
                        else if (_partArm >= _otherArm + 75.0 && _otherArm <= 50.0 && armAfter > 30.0)
                            armW = 0.22;
                        else if (armAfter <= 0.01)
                            armW = 0.60;
                    }

                    // Head vs Body Temporary Injury bonus when target survives the hit:
                    // head trauma (Severe Concussion, Fractured Skull, Brain Damage, Cut Artery) inflicts far harsher combat debuffs
                    // than average body injuries, provided HP damage actually gets past Head Armor!
                    local injBonus = 0.0;
                    if (canInjure && rawHP < hp * 0.95)
                    {
                        if (rawHP >= heavyInjThr)
                            injBonus = _isHead ? 22.0 : 12.0;
                        else if (rawHP >= lightInjThr)
                            injBonus = _isHead ? 11.0 : 6.0;
                    }

                    // Per-part kill probability on hit (1.0 if guaranteed kill, partial ramp if close to lethal roll).
                    local partKillP = 0.0;
                    if (rawHP >= hp * 0.96) partKillP = 1.0;
                    else if (rawHP >= hp * 0.78) partKillP = 0.55;

                    return {
                        RawHP = rawHP,
                        EffHP = effHP,
                        ArmHit = armHit,
                        InjBonus = injBonus,
                        KillP = partKillP,
                        Val = effHP + armHit * armW + injBonus
                    };
                };

                local sid = _skill.getID();
                if (sid == "actives.split_man")
                {
                    // 2H Axe Split Man strikes primary part at 100% and opposite part at 50%!
                    local b1 = evalPart(bodyArm, headArm, bodyMult, 1.0, false);
                    local h2 = evalPart(headArm, bodyArm, headMult, 0.5, true);
                    local h1 = evalPart(headArm, bodyArm, headMult, 1.0, true);
                    local b2 = evalPart(bodyArm, headArm, bodyMult, 0.5, false);
                    local rawIfBody = b1.RawHP + h2.RawHP;
                    local rawIfHead = h1.RawHP + b2.RawHP;
                    local hpIfBody = ::Math.minf(rawIfBody, hp * 1.05);
                    local hpIfHead = ::Math.minf(rawIfHead, hp * 1.05);
                    local injIfBody = rawIfBody >= hp * 0.95 ? 0.0 : (b1.InjBonus + h2.InjBonus * 0.75);
                    local injIfHead = rawIfHead >= hp * 0.95 ? 0.0 : (h1.InjBonus + b2.InjBonus * 0.75);
                    local valIfBody = hpIfBody + (b1.Val - b1.EffHP - b1.InjBonus) + (h2.Val - h2.EffHP - h2.InjBonus) + injIfBody;
                    local valIfHead = hpIfHead + (h1.Val - h1.EffHP - h1.InjBonus) + (b2.Val - b2.EffHP - b2.InjBonus) + injIfHead;
                    local kBody = rawIfBody >= hp * 0.96 ? 1.0 : (rawIfBody >= hp * 0.78 ? 0.55 : 0.0);
                    local kHead = rawIfHead >= hp * 0.96 ? 1.0 : (rawIfHead >= hp * 0.78 ? 0.55 : 0.0);
                    onHitRawHP = bodyP * rawIfBody + headP * rawIfHead;
                    onHitHP = bodyP * hpIfBody + headP * hpIfHead;
                    onHitArm = bodyP * (b1.ArmHit + h2.ArmHit) + headP * (h1.ArmHit + b2.ArmHit);
                    onHitVal = bodyP * valIfBody + headP * valIfHead;
                    pKill = hitF * (bodyP * kBody + headP * kHead);
                }
                else
                {
                    local bRes = evalPart(bodyArm, headArm, bodyMult, 1.0, false);
                    local hRes = evalPart(headArm, bodyArm, headMult, 1.0, true);
                    onHitRawHP = bodyP * bRes.RawHP + headP * hRes.RawHP;
                    onHitHP = bodyP * bRes.EffHP + headP * hRes.EffHP;
                    onHitArm = bodyP * bRes.ArmHit + headP * hRes.ArmHit;
                    onHitVal = bodyP * bRes.Val + headP * hRes.Val;
                    pKill = hitF * (bodyP * bRes.KillP + headP * hRes.KillP);
                }
                usedExact = true;
            }
        } catch (e) { usedExact = false; }

        if (!usedExact)
        {
            local expHP = 25.0, expArm = 20.0;
            try {
                local dmg = _skill.getExpectedDamage(_target);
                expHP = dmg.HitpointDamage + dmg.DirectDamage;
                expArm = dmg.ArmorDamage;
            } catch (e) {}
            onHitRawHP = expHP;
            onHitHP = ::Math.minf(expHP, hp * 1.05);
            onHitArm = ::Math.minf(expArm, bodyArm + headArm);
            onHitVal = onHitHP + onHitArm * 0.50;
            pKill = hitF * (onHitRawHP >= hp * 0.96 ? 1.0 : (onHitRawHP >= hp * 0.78 ? 0.55 : 0.0));
        }

        return {
            Hit = hit,
            HitF = hitF,
            OnHitRawHP = onHitRawHP,
            OnHitHP = onHitHP,
            OnHitArm = onHitArm,
            OnHitVal = onHitVal,
            PKill = pKill,
            ExpHP = hitF * onHitHP,
            ExpArm = hitF * onHitArm,
            ExpVal = hitF * onHitVal
        };
    },

    // Equivalent tactical damage value of actually killing _foe this swing:
    // accounts for board/action removal, living-army Morale Cascade checks on nearby enemies,
    // unacted-turn denial, Berserk / Killing Frenzy tempo, and Mentor-breach / high-priority threat removal.
    function computeKillEquivalentValue( _actor, _foe, _info = null )
    {
        if (_foe == null || ::MSU.isNull(_foe) || _foe.getMoraleState() == ::Const.MoraleState.Fleeing)
            return 0.0;

        local val = 32.0; // Base board removal & action-economy gain.

        // Living-army Morale Cascade: killing a non-undead enemy triggers morale drops on nearby living enemies!
        if (!_foe.getFlags().has("undead"))
        {
            val += 14.0;
            if (_info != null && "Enemies" in _info)
            {
                local ft = _foe.getTile();
                local nearLiving = 0;
                foreach (e in _info.Enemies)
                {
                    if (e.getID() == _foe.getID() || e.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    if (!e.getFlags().has("undead") && ft.getDistanceTo(e.getTile()) <= 4)
                        ++nearLiving;
                }
                val += ::Math.min(3, nearLiving) * 4.0;
            }
        }

        // Turn-order action denial: killing an enemy BEFORE they act this round saves immediate incoming attacks.
        local st = this.enemyLiveStats(_foe);
        if (st.CanActThisRound)
            val += (st.TurnsUntil <= 3 ? 15.0 : 10.0);

        // Attacker on-kill tempo perks (Berserk +4 AP, Killing Frenzy +25% dmg).
        local aSk = _actor.getSkills();
        if (aSk.hasSkill("perk.berserk")) val += 16.0;
        if (aSk.hasSkill("perk.killing_frenzy") && !aSk.hasSkill("effects.killing_frenzy")) val += 8.0;

        // Threat & Mentor-breach multiplier.
        local fs = _foe.getSkills();
        local isHigh = fs.hasSkill("racial.champion") || fs.hasSkill("actives.raise_undead")
            || fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma")
            || fs.hasSkill("effects.berserker_rage") || _foe.ClassName == "orc_berserker";
        if (!isHigh && _info != null && "Brothers" in _info)
        {
            local ft = _foe.getTile();
            foreach (bro in _info.Brothers)
            {
                if (this.isCasterRole(bro) && ft.getDistanceTo(bro.getTile()) <= 2)
                {
                    isHigh = true;
                    break;
                }
            }
        }
        if (isHigh) val *= 1.45;
        return val;
    },

    // Evaluate one concrete AoE strike from _originTile aiming at _targetTile.
    // Strictly detects ANY allied unit on affected tiles so friendly fire is cleanly eliminated.
    function evaluateAoEStrike( _actor, _originTile, _targetTile, _skill, _info = null, _lineLen = 2 )
    {
        local maxLvl = 1;
        try { maxLvl = _skill.getMaxLevelDifference(); } catch (e) { maxLvl = 1; }
        local sid = _skill.getID();
        local tiles = this.getAoEAffectedTiles(_originTile, _targetTile, sid, maxLvl, _lineLen);

        local alliesHit = 0;
        local activeEnemies = 0;
        local fleeingEnemies = 0;
        local lethalKills = 0;
        local priorityKills = 0;
        local totalExpHP = 0.0;
        local totalExpArm = 0.0;
        local totalEffDmg = 0.0;
        local totalCompVal = 0.0;
        local totalExpKills = 0.0;
        local totalValue = 0.0;
        local hitSum = 0.0;
        local nonDefBuffEnemies = 0;
        local hitIDs = {};

        local chiefTile = null;
        if (_info != null && "Brothers" in _info)
        {
            foreach (bro in _info.Brothers)
                if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }
        }

        foreach (t in tiles)
        {
            if (t == null || !t.IsOccupiedByActor) continue;
            local occ = t.getEntity();
            if (occ == null || ::MSU.isNull(occ) || !occ.isAlive() || occ.isDying()) continue;
            if (occ.getID() == _actor.getID()) continue;
            if (occ.isAlliedWith(_actor))
            {
                ++alliesHit;
                continue;
            }
            if (!occ.isAttackable() || occ.isHiddenToPlayer() || !t.IsVisibleForPlayer)
                continue;

            local isFleeing = (occ.getMoraleState() == ::Const.MoraleState.Fleeing);
            if (isFleeing)
            {
                ++fleeingEnemies;
                continue;
            }
            ++activeEnemies;
            hitIDs[occ.getID()] <- true;

            // Exact headshot-rate, head/body-armor & head/body-injury weighted expected damage!
            local ed = this.computeSkillExpectedDamage(_actor, _skill, occ, _originTile);
            local killEq = ed.PKill > 0.0 ? this.computeKillEquivalentValue(_actor, occ, _info) : 0.0;
            hitSum += ed.Hit;
            totalExpHP += ed.ExpHP;
            totalExpArm += ed.ExpArm;
            totalEffDmg += ed.ExpVal;
            totalExpKills += ed.PKill;
            totalCompVal += ed.ExpVal + ed.PKill * killEq;

            local os = occ.getSkills();
            if (!os.hasSkill("effects.shieldwall") && !os.hasSkill("effects.riposte"))
                ++nonDefBuffEnemies;

            local kills = (ed.OnHitRawHP >= occ.getHitpoints() * 0.92 && ed.Hit >= 40);
            if (kills)
            {
                ++lethalKills;
                local isUrg = os.hasSkill("racial.champion") || os.hasSkill("actives.raise_undead")
                    || os.hasSkill("actives.horror") || os.hasSkill("actives.miasma")
                    || os.hasSkill("effects.berserker_rage") || occ.ClassName == "orc_berserker"
                    || (chiefTile != null && t.getDistanceTo(chiefTile) <= 2);
                if (isUrg) ++priorityKills;
            }

            // Compute tactical value per enemy hit using focus-target multipliers.
            local baseVal = ed.ExpVal + ed.PKill * killEq * 0.65;
            if (kills) baseVal *= 1.35;
            if (os.hasSkill("effects.riposte")) baseVal *= 0.45;
            else if (os.hasSkill("effects.shieldwall") && ed.Hit < 55) baseVal *= 0.55;
            if (os.hasSkill("racial.champion") || os.hasSkill("effects.berserker_rage")
                || os.hasSkill("actives.raise_undead") || os.hasSkill("actives.horror") || os.hasSkill("actives.miasma"))
                baseVal *= 1.35;
            if (chiefTile != null && t.getDistanceTo(chiefTile) <= 2)
                baseVal *= 1.45;
            if (sid == "actives.shatter" && !os.hasSkill("effects.staggered") && !occ.getCurrentProperties().IsImmuneToStun)
                baseVal += 10.0 * ed.HitF;
            totalValue += baseVal;
        }

        local avgHit = activeEnemies > 0 ? (hitSum / activeEnemies) : 0.0;

        return {
            AimTile = _targetTile,
            AlliesHit = alliesHit,
            ActiveEnemies = activeEnemies,
            FleeingEnemies = fleeingEnemies,
            LethalKills = lethalKills,
            PriorityKills = priorityKills,
            TotalExpHP = totalExpHP,
            TotalExpArm = totalExpArm,
            EffDmg = totalEffDmg,
            CompVal = totalCompVal,
            ExpKills = totalExpKills,
            AvgHit = avgHit,
            NonDefBuffEnemies = nonDefBuffEnemies,
            TotalValue = totalValue,
            HitIDs = hitIDs
        };
    },

    // Measure the highest AP-normalized mathematical expected damage AND kill+morale competitive value achievable
    // by ANY usable non-AoE primary weapon attack (Skill 1) from _originTile (e.g. overhead_strike, pound, split_man,
    // smite, strike, cleave), ensuring a high-hit Skill-1 finish on a wounded enemy properly competes against AoE!
    function bestSingleTargetMetric( _actor, _originTile, _info, _aoeSkill = null )
    {
        local aoeID = _aoeSkill != null ? _aoeSkill.getID() : null;
        local aoeAP = _aoeSkill != null ? _aoeSkill.getActionPointCost() : 6;

        local primSkills = [];
        foreach (s in _actor.getSkills().m.Skills)
        {
            if (s == null || !s.m.IsActive || !s.m.IsAttack || !s.m.IsTargeted || s.m.IsRanged || !s.m.IsWeaponSkill)
                continue;
            local sid = s.getID();
            if (s.m.IsAOE || sid == aoeID) continue;
            if (sid == "actives.knock_out" || sid == "actives.strike_down"
                || sid == "actives.split_shield" || sid == "actives.disarm"
                || sid == "actives.hook" || sid == "actives.repel" || sid == "actives.knock_back"
                || sid == "actives.rf_hook_shield" || sid == "actives.rf_deep_impact"
                || sid == "actives.decapitate" || sid == "actives.exesword_decapitate"
                || sid == "actives.golem_decapitate" || sid == "actives.lash")
                continue;
            if (s.isHidden() || !s.isUsable()) continue;
            primSkills.push(s);
        }
        if (primSkills.len() == 0)
            return { Skill = null, BestEffDmg = 0.0, BestCompVal = 0.0, BestPKill = 0.0, PrimAP = 6, PrimFat = 15, UrgentKillID = -1, AnyKillID = -1 };

        local chiefTile = null;
        if (_info != null && "Brothers" in _info)
        {
            foreach (bro in _info.Brothers)
                if (this.isCasterRole(bro)) { chiefTile = bro.getTile(); break; }
        }

        local bestSkill = null;
        local bestNormDmg = 0.0;
        local bestNormComp = 0.0;
        local bestPKill = 0.0;
        local bestPrimAP = 6;
        local bestPrimFat = 15;
        local urgentKillID = -1;
        local anyKillID = -1;
        local enemies = (_info != null && "Enemies" in _info) ? _info.Enemies : this.collectEnemies(_actor, null);

        foreach (prim in primSkills)
        {
            local minR = prim.getMinRange();
            local maxR = prim.getMaxRange();
            local pAP = ::Math.max(1, prim.getActionPointCost());
            local pFat = prim.getFatigueCost();
            local apScale = ::Math.maxf(1.0, aoeAP.tofloat() / pAP.tofloat());

            foreach (foe in enemies)
            {
                if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                local ft = foe.getTile();
                local d = _originTile.getDistanceTo(ft);
                if (d < minR || d > maxR) continue;
                local ok = false;
                try { ok = prim.isUsableOn(ft, _originTile); } catch (e) { ok = false; }
                if (!ok) continue;

                local ed = this.computeSkillExpectedDamage(_actor, prim, foe, _originTile);
                local killEq = ed.PKill > 0.0 ? this.computeKillEquivalentValue(_actor, foe, _info) : 0.0;
                local normEff = ed.ExpVal * apScale;
                local normComp = (ed.ExpVal + ed.PKill * killEq) * apScale;

                if (normEff > bestNormDmg) bestNormDmg = normEff;
                if (ed.PKill > bestPKill) bestPKill = ed.PKill;
                if (normComp > bestNormComp)
                {
                    bestNormComp = normComp;
                    bestSkill = prim;
                    bestPrimAP = pAP;
                    bestPrimFat = pFat;
                }

                if (ed.OnHitRawHP >= foe.getHitpoints() * 0.95 && ed.Hit >= 48)
                {
                    anyKillID = foe.getID();
                    local fs = foe.getSkills();
                    local st = this.enemyLiveStats(foe);
                    local isUrg = (chiefTile != null && ft.getDistanceTo(chiefTile) <= 2)
                        || fs.hasSkill("racial.champion") || fs.hasSkill("actives.raise_undead")
                        || fs.hasSkill("actives.horror") || fs.hasSkill("actives.miasma")
                        || fs.hasSkill("effects.berserker_rage") || foe.ClassName == "orc_berserker"
                        || (st.CanActThisRound && this.isHeavyMeleeThreat(foe, _actor));
                    if (isUrg) urgentKillID = foe.getID();
                }
            }
        }
        return {
            Skill = bestSkill,
            BestEffDmg = bestNormDmg,
            BestCompVal = bestNormComp,
            BestPKill = bestPKill,
            PrimAP = bestPrimAP,
            PrimFat = bestPrimFat,
            UrgentKillID = urgentKillID,
            AnyKillID = anyKillID
        };
    },

    // Compute the minimum expected-damage ratio (AoE E[Dmg] / AP-normalized Skill-1 E[Dmg]) required to justify
    // spending an AoE skill's higher Fatigue/AP cost over focused Skill-1 damage (covers Greatsword split/swing,
    // 2H Flail thresh, 2H Axe round_swing/split_axe, 2H Hammer shatter, Polearm reap, and Reforged AoE swings/splits).
    function computeAoERequiredMult( _actor, _aoeSkill, _single, _ev, _kind, _moveAP = 0 )
    {
        local aoeFat = _aoeSkill.getFatigueCost();
        local primFat = (_single != null && _single.PrimFat > 0) ? _single.PrimFat : 15;
        local fatDelta = ::Math.max(0, aoeFat - primFat);
        local fatPct = _actor.getFatigueMax() > 0 ? (_actor.getFatigue().tofloat() / _actor.getFatigueMax().tofloat()) : 0.0;

        // Require AoE expected damage to significantly beat focused Skill-1 expected damage:
        // base 1.35x + extra fatigue surcharge (+1.2% per extra Fat up to +0.25) + tiredness surcharge + step AP surcharge.
        // (Extra AP cost of AoE vs Skill 1 is already folded into _single.BestEffDmg via apScale = aoeAP / primAP.)
        local reqMult = 1.35 + ::Math.minf(0.25, fatDelta * 0.012);
        if (fatPct >= 0.40)
            reqMult += (fatPct - 0.40) * 0.55;
        if (_moveAP > 0)
            reqMult += _moveAP * 0.03;

        // High-risk 360-degree -15% hitchance AoEs (Thresh, Round Swing) require an even clearer edge (>= 1.60x).
        if (_kind == "thresh")
            reqMult = ::Math.maxf(reqMult, 1.60);

        // Modest relaxation when AoE delivers a multi-kill (>= 2) or secures a kill Skill 1 cannot get,
        // while still requiring a clear expected-damage advantage over Skill 1.
        if (_ev.LethalKills >= 2)
            reqMult = ::Math.maxf(1.20, reqMult - 0.22);
        else if (_ev.LethalKills >= 1 && (_single == null || _single.AnyKillID == -1))
            reqMult = ::Math.maxf(1.25, reqMult - 0.14);

        return reqMult;
    },

    // Unified Zero-Friendly-Fire optimizer & expected-damage gate for standing melee AoE behaviors:
    //   kind = "reap"   (ai_attack_reap: actives.reap, actives.censer_castigate)
    //   kind = "swing"  (ai_attack_swing: actives.shatter, actives.swing, actives.rf_cleaving_swing, actives.sweep, ...)
    //   kind = "split"  (ai_attack_split: actives.split, actives.rf_cleaving_split, actives.split_axe, ...)
    //   kind = "thresh" (ai_attack_thresh: actives.thresh, actives.round_swing, ...)
    function evaluateSmartMeleeAoE( _behavior, _actor, _origScore, _kind )
    {
        _behavior.m.TargetTile = null;
        _behavior.m.Skill = null;
        if (_actor.getActionPoints() < ::Const.Movement.AutoEndTurnBelowAP
            || _actor.getMoraleState() == ::Const.MoraleState.Fleeing
            || _actor.getCurrentProperties().IsStunned)
            return ::Const.AI.Behavior.Score.Zero;

        local info = this.assessBattle(_actor, _behavior.getAgent());
        if (info.Enemies.len() == 0)
            return ::Const.AI.Behavior.Score.Zero;

        // Respect ironclad Phase-1 tactical combo / buff-expire wait for Autopilot player brothers.
        if (::Autopilot.isUnderAIControl(_actor) && ::Tactical.TurnSequenceBar.canEntityWait(_actor))
        {
            local wPlan = this.evaluateTacticalWait(_actor, info, _behavior.getAgent());
            if (wPlan != null && wPlan.SuppressAttack)
                return ::Const.AI.Behavior.Score.Zero;
        }

        local skill = _behavior.selectSkill(_behavior.m.PossibleSkills);
        if (skill == null || skill.isHidden() || !skill.isUsable() || !skill.isAffordable())
            return ::Const.AI.Behavior.Score.Zero;

        local myTile = _actor.getTile();
        local lineLen = 2;
        if (_kind == "split")
        {
            try { if (_behavior.m.Length > 0) lineLen = _behavior.m.Length; } catch (e) { lineLen = 2; }
        }

        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local fatAfter = availFat - skill.getFatigueCost();
        local single = this.bestSingleTargetMetric(_actor, myTile, info, skill);

        local bestEval = null;
        local aimCandidates = (_kind == "thresh") ? [myTile.hasNextTile(0) ? myTile.getNextTile(0) : null] : this.collectAoEAimTiles(myTile, skill);

        foreach (aimTile in aimCandidates)
        {
            if (aimTile == null) continue;
            if (_kind != "thresh")
            {
                local usable = false;
                try { usable = skill.isUsableOn(aimTile, myTile); } catch (e) { usable = false; }
                if (!usable) continue;
            }
            else
            {
                // For 360-degree thresh/round_swing, find any valid target tile to execute the skill on.
                local validAim = null;
                for (local d = 0; d < 6; ++d)
                {
                    if (!myTile.hasNextTile(d)) continue;
                    local nt = myTile.getNextTile(d);
                    local ok = false;
                    try { ok = skill.isUsableOn(nt, myTile); } catch (e) { ok = false; }
                    if (ok) { validAim = nt; break; }
                }
                if (validAim == null) continue;
                aimTile = validAim;
            }

            local ev = this.evaluateAoEStrike(_actor, myTile, aimTile, skill, info, lineLen);
            // HARD ZERO FRIENDLY-FIRE RULE: never hit ANY ally (brothers, Mentor, Lich King, pets, undead allies)!
            if (ev.AlliesHit > 0)
                continue;
            // Require at least 2 active non-fleeing enemies hit (3+ for 360-degree thresh/round_swing unless multi-kill).
            if (_kind == "thresh")
            {
                if (ev.ActiveEnemies < 3 && !(ev.ActiveEnemies == 2 && ev.LethalKills >= 2 && fatAfter >= 14))
                    continue;
            }
            else
            {
                if (ev.ActiveEnemies < 2)
                    continue;
            }
            // Do not waste 2x fatigue grazing Shieldwall/Riposte turtles at poor hit chance with zero kills.
            if (ev.LethalKills == 0 && ev.NonDefBuffEnemies == 0 && ev.AvgHit < 52)
                continue;
            if (ev.ActiveEnemies == 2 && ev.LethalKills == 0 && ev.AvgHit < 38)
                continue;
            // Fatigue headroom gate for non-lethal 2-target AoEs.
            if (ev.ActiveEnemies == 2 && ev.LethalKills == 0 && fatAfter < 10)
                continue;

            // UNIVERSAL UNIFIED EXPECTED-VALUE COMPETITION GATE:
            // Compares AoE CompVal = Sum(part-aware ExpDmg + Head/Body Injury + P(kill)*KillMorale)
            // directly against Skill-1 AP-normalized BestCompVal * reqMult (scaled by extra Fatigue, tiredness, and 360 risk).
            // Smooth & continuous (never absolute): a reliable Skill-1 wounded finish beats marginal 2-man AoEs,
            // while a multi-kill AoE or overwhelming 3-man sweep still cleanly wins over a routine single finish!
            local reqMult = this.computeAoERequiredMult(_actor, skill, single, ev, _kind, 0);
            if (single.UrgentKillID != -1 && ev.LethalKills == 0)
                reqMult += 0.18;
            if (single.BestCompVal > 0.0 && ev.CompVal < single.BestCompVal * reqMult)
                continue;

            if (bestEval == null || ev.TotalValue > bestEval.TotalValue)
                bestEval = ev;
        }

        if (bestEval == null)
            return ::Const.AI.Behavior.Score.Zero;

        _behavior.m.Skill = skill;
        _behavior.m.TargetTile = bestEval.AimTile;

        local bMult = 1.0;
        try { bMult = _behavior.getProperties().BehaviorMult[_behavior.m.ID]; } catch (e) {}
        if (bMult <= 0.0) bMult = 1.0;

        // Calibrate score so clean 0-FF high-expected-damage sweeps reliably beat single-target Attack.Default (~180-550)
        // while staying cleanly below wounded_retreat (820) and emergency rescues / kiting / Shieldwall (850-1650).
        local targetScore = ::Const.AI.Behavior.Score.Attack * bMult
            * (bestEval.ActiveEnemies >= 3 ? 4.8 : (bestEval.LethalKills >= 1 ? 3.8 : 2.8))
            + bestEval.TotalValue * 2.2
            + bestEval.LethalKills * 140.0 + bestEval.PriorityKills * 110.0;
        if (_origScore > 0.0)
            targetScore = ::Math.maxf(targetScore, _origScore * (bestEval.ActiveEnemies >= 3 ? 1.35 : 1.10));
        local scoreCap = (bestEval.ActiveEnemies >= 3 || bestEval.LethalKills >= 1) ? 780.0 : 620.0;
        return ::Math.minf(scoreCap, targetScore);
    },

    // Find the best zero-friendly-fire actives.reap plan for a 2-tile polearm wielder (standing OR after a 1-2 tile safe non-ZoC step),
    // using live previewSkillCostsAfterMove() so Polearm Mastery (5 AP) & Vigorous Assault (-1 AP / 2 tiles) work seamlessly,
    // and enforcing the mathematical expected-damage margin over Skill-1 strike!
    function findBestReapPlan( _behavior, _actor, _info )
    {
        if (_actor == null || _info == null || _info.Enemies.len() < 2)
            return null;
        if (this.isRangedRole(_actor) || this.isCasterRole(_actor) || _actor.getCurrentProperties().IsStunned)
            return null;
        local reap = _actor.getSkills().getSkillByID("actives.reap");
        if (reap == null || reap.isHidden() || !reap.isUsable())
            return null;

        local myTile = _actor.getTile();
        local inZoC = myTile.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0;
        local ap = _actor.getActionPoints();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local reapAP = reap.getActionPointCost();
        local reapFat = reap.getFatigueCost();

        // Optimistic minimum AP after move-discount perks (Vigorous Assault / Vanquisher).
        local skills = _actor.getSkills();
        local hasMoveDiscount = skills.hasSkill("perk.rf_vigorous_assault") || skills.hasSkill("perk.rf_vanquisher");
        local optimisticAP = hasMoveDiscount ? ::Math.max(1, reapAP - 2) : reapAP;
        if (ap < optimisticAP)
            return null;

        // Check standing single-target baseline (and urgent kill check).
        local singleHere = this.bestSingleTargetMetric(_actor, myTile, _info, reap);
        local canStep = (!inZoC && !_actor.getCurrentProperties().IsRooted && !this.shouldWoundedRetreat(_actor, _info));

        local origins = [{ Tile = myTile, MoveAP = 0, MoveFat = 0, EffAP = reapAP, EffFat = reapFat }];
        if (canStep && (ap - optimisticAP) >= 2)
        {
            local maxStepTiles = (ap - optimisticAP) >= 4 ? 2 : 1;
            local navigator = ::Tactical.getNavigator();
            local settings = this.navSettings(_actor, navigator);
            local cands = this.tilesInRange(myTile, 1, maxStepTiles);
            foreach (dest in cands)
            {
                if (!dest.IsEmpty || dest.ID == myTile.ID) continue;
                if (dest.getZoneOfControlCountOtherThan(_actor.getAlliedFactions()) > 0) continue;
                if (_behavior != null && _behavior.hasNegativeTileEffect(dest, _actor)) continue;
                // Do not step into an uphill polearm/melee trap or isolated forward danger for a reap.
                local uphill = this.isUphillMeleeTrap(dest, _actor, _info);
                if (uphill.IsTrap || uphill.PolearmTrap) continue;
                if (!navigator.findPath(myTile, dest, settings, 0)) continue;
                local cost = navigator.getCostForPath(_actor, settings, ap, availFat);
                if (!cost.IsComplete || cost.End == null || cost.End.ID != dest.ID || cost.Tiles > maxStepTiles) continue;
                local eff = this.previewSkillCostsAfterMove(_actor, reap, cost);
                if (ap - cost.ActionPointsRequired < eff.AP || availFat - cost.FatigueRequired < eff.Fat)
                    continue;
                // Avoid stepping directly adjacent to an unengaged dangerous melee killer when current tile was safer.
                local curThreatD = this.nearestDangerousMeleeDist(_actor, _info.Enemies);
                local newThreatD = this.nearestDangerousMeleeDistAt(dest, _info.Enemies);
                if (curThreatD >= 3 && newThreatD <= 1) continue;
                origins.push({
                    Tile = dest,
                    MoveAP = cost.ActionPointsRequired,
                    MoveFat = cost.FatigueRequired,
                    EffAP = eff.AP,
                    EffFat = eff.Fat
                });
            }
        }

        local bestPlan = null;
        local bestRank = -9999.0;

        foreach (org in origins)
        {
            local oTile = org.Tile;
            if (ap - org.MoveAP < org.EffAP || availFat - org.MoveFat < org.EffFat)
                continue;
            local fatAfter = availFat - org.MoveFat - org.EffFat;
            local singleOrg = (oTile.ID == myTile.ID) ? singleHere : this.bestSingleTargetMetric(_actor, oTile, _info, reap);
            local refSingle = (singleOrg.BestCompVal >= singleHere.BestCompVal) ? singleOrg : singleHere;
            local aimTiles = this.collectAoEAimTiles(oTile, reap);

            foreach (aim in aimTiles)
            {
                local usable = false;
                try { usable = reap.isUsableOn(aim, oTile); } catch (e) { usable = false; }
                if (!usable) continue;

                local ev = this.evaluateAoEStrike(_actor, oTile, aim, reap, _info, 2);
                // STRICT ZERO FRIENDLY FIRE!
                if (ev.AlliesHit > 0 || ev.ActiveEnemies < 2)
                    continue;
                if (ev.LethalKills == 0 && ev.NonDefBuffEnemies == 0 && ev.AvgHit < 52)
                    continue;
                if (ev.ActiveEnemies == 2 && ev.LethalKills == 0)
                {
                    if (fatAfter < 10) continue;
                    if (ev.AvgHit < 40) continue;
                }
                // Unified mathematical expected-value margin over Skill-1 strike (damage + head/body injury + kill/morale competition + fatigue + step AP)!
                local reqMult = this.computeAoERequiredMult(_actor, reap, refSingle, ev, "reap", org.MoveAP);
                if (singleHere.UrgentKillID != -1 && ev.LethalKills == 0)
                    reqMult += 0.18;
                if (refSingle.BestCompVal > 0.0 && ev.CompVal < refSingle.BestCompVal * reqMult)
                    continue;

                // Rank candidate (origin, aim) plans: 3-man clean sweeps >> 2-man lethal sweeps > 2-man clean sweeps; prefer staying on high ground.
                local rank = ev.TotalValue
                    + (ev.ActiveEnemies >= 3 ? 85.0 : 0.0)
                    + ev.LethalKills * 55.0 + ev.PriorityKills * 45.0
                    + (oTile.Level - myTile.Level) * 14.0
                    - org.MoveAP * 2.5
                    - (oTile.IsBadTerrain ? 12.0 : 0.0);
                if (rank > bestRank)
                {
                    bestRank = rank;
                    local behScore = (ev.ActiveEnemies >= 3) ? 740.0 : (ev.LethalKills >= 1 ? 660.0 : 590.0);
                    bestPlan = {
                        OriginTile = oTile,
                        AimTile = aim,
                        Skill = reap,
                        Eval = ev,
                        Score = behScore,
                        NeedsMove = (oTile.ID != myTile.ID)
                    };
                }
            }
        }
        return bestPlan;
    },

    // Precision timing optimizer for actives.decapitate (Cleaver Duelists & Lich King):
    //   1. Execution: use when Decapitate secures a kill that primary Cleave cannot reliably confirm.
    //   2. Anti-Resurrection Behead: use to permanently behead Zombies / Wiedergangers / Fallen Heroes.
    //   3. Overkill Prevention: VETO when Cleave already kills a non-zombie cleanly (saves +67% fatigue!).
    //   4. 1-2 Combo & Wounded Burst: on full/high-HP targets, swing Cleave FIRST (2x bleed + drop HP + cheap fat),
    //      then follow up with Decapitate on swing 2 once HP is wounded and armor is low (or on bleed-immune wounded targets!).
    function evaluateSmartDecapitate( _behavior, _actor, _origScore )
    {
        _behavior.m.TargetTile = null;
        _behavior.m.Skill = null;
        if (_actor.getActionPoints() < ::Const.Movement.AutoEndTurnBelowAP
            || _actor.getMoraleState() == ::Const.MoraleState.Fleeing
            || _actor.getCurrentProperties().IsStunned)
            return ::Const.AI.Behavior.Score.Zero;

        local info = this.assessBattle(_actor, _behavior.getAgent());
        if (info.Enemies.len() == 0)
            return ::Const.AI.Behavior.Score.Zero;

        if (::Autopilot.isUnderAIControl(_actor) && ::Tactical.TurnSequenceBar.canEntityWait(_actor))
        {
            local wPlan = this.evaluateTacticalWait(_actor, info, _behavior.getAgent());
            if (wPlan != null && wPlan.SuppressAttack)
                return ::Const.AI.Behavior.Score.Zero;
        }

        local decap = _behavior.selectSkill(_behavior.m.PossibleSkills);
        if (decap == null || decap.isHidden() || !decap.isUsable() || !decap.isAffordable())
            return ::Const.AI.Behavior.Score.Zero;

        local cleave = _actor.getSkills().getSkillByID("actives.cleave");
        if (cleave != null && (cleave.isHidden() || !cleave.isUsable() || !cleave.isAffordable()))
            cleave = null;

        local myTile = _actor.getTile();
        local ap = _actor.getActionPoints();
        local decapAP = decap.getActionPointCost();
        local decapFat = decap.getFatigueCost();
        local availFat = _actor.getFatigueMax() - _actor.getFatigue();
        local fatPct = _actor.getFatigue().tofloat() / ::Math.maxf(1.0, _actor.getFatigueMax().tofloat());
        local canSwingTwice = (ap >= decapAP * 2);
        local isPlayerBro = (_actor.getFaction() == ::Const.Faction.Player);

        local enemyHasNecro = false;
        foreach (e in info.Enemies)
        {
            if (e.getMoraleState() != ::Const.MoraleState.Fleeing && e.getSkills().hasSkill("actives.raise_undead"))
            {
                enemyHasNecro = true;
                break;
            }
        }

        local bestTile = null;
        local bestScore = 0.0;

        foreach (foe in info.Enemies)
        {
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d < decap.getMinRange() || d > decap.getMaxRange()) continue;
            local usable = false;
            try { usable = decap.isUsableOn(ft, myTile); } catch (e) { usable = false; }
            if (!usable) continue;

            local hp = foe.getHitpoints();
            local hpPct = foe.getHitpointsPct();
            local bleedImmune = foe.getCurrentProperties().IsImmuneToBleeding;
            local cn = foe.ClassName;
            local isZombieRes = foe.getFlags().has("zombie_minion")
                || cn == "zombie" || cn == "zombie_yeoman" || cn == "zombie_knight"
                || cn == "rf_zombie_hero" || cn == "zombie_betrayer";

            local dEd = this.computeSkillExpectedDamage(_actor, decap, foe, myTile);
            local dHit = dEd.Hit;
            local dExpHP = dEd.OnHitHP;
            local dRawHP = dEd.OnHitRawHP;
            if (dHit < 32) continue;

            local cHit = dHit, cExpHP = 0.0, cRawHP = 0.0;
            if (cleave != null)
            {
                local cEd = this.computeSkillExpectedDamage(_actor, cleave, foe, myTile);
                cHit = cEd.Hit;
                cExpHP = cEd.OnHitHP;
                cRawHP = cEd.OnHitRawHP;
            }

            local decapKills = (dRawHP >= hp * 0.92 && dHit >= 38);
            local cleaveCleanKills = (cleave != null && cRawHP >= hp * 1.12 && cHit >= 45);

            local modeMult = 0.0;
            // Mode A: True Execution (Decapitate kills what Cleave cannot reliably kill!).
            if (decapKills && !cleaveCleanKills)
            {
                modeMult = 1.65;
            }
            // Mode B: Anti-Resurrection Zombie / Fallen Hero Behead!
            else if (isZombieRes && dExpHP >= hp * 0.85 && dHit >= 40
                && (availFat >= decapFat + 6 || enemyHasNecro || foe.getHitpointsMax() >= 115))
            {
                modeMult = (enemyHasNecro || foe.getHitpointsMax() >= 115) ? 1.60 : 1.40;
            }
            // Mode C: Overkill Prevention (never waste +67% fatigue overkilling non-resurrecting low-HP foes Cleave already kills!).
            else if (cleaveCleanKills)
            {
                continue;
            }
            // Mode D: Wounded HP Burst (strictly after target HP & armor are opened; swing Cleave first on full-HP targets!).
            else
            {
                local hpGate = bleedImmune ? 0.72 : (canSwingTwice ? 0.50 : 0.58);
                if (hpPct > hpGate) continue;
                if (dHit < 48) continue;
                local fatBuf = isPlayerBro ? 16 : 12;
                if (_actor.getFatigueMax() > 0 && (availFat < decapFat + fatBuf || (isPlayerBro && fatPct > 0.68))) continue;
                if (cleave != null)
                {
                    local minGain = bleedImmune ? 12.0 : 22.0;
                    local minRatio = bleedImmune ? 1.15 : 1.24;
                    if (dExpHP < cExpHP + minGain || dExpHP < cExpHP * minRatio)
                        continue;
                }
                modeMult = 1.32;
            }

            // Score using vanilla queryTargetValue (which already incorporates our scoreFocusTarget multipliers!).
            local tv = 1.0;
            try { tv = _behavior.queryTargetValue(_actor, foe, decap); } catch (e) { tv = 1.0; }
            local sc = ::Const.AI.Behavior.Score.Attack * tv * modeMult * (dHit * 0.01);
            if (decapKills) sc = ::Math.maxf(sc, 420.0 * modeMult);
            if (sc > bestScore)
            {
                bestScore = sc;
                bestTile = ft;
            }
        }

        if (bestTile == null)
            return ::Const.AI.Behavior.Score.Zero;

        _behavior.m.Skill = decap;
        _behavior.m.TargetTile = bestTile;
        return bestScore;
    },

    // Precision gate for 2H Mace actives.strike_down & 1H Mace actives.knock_out:
    // eliminates routine / overkill / low-value / surrounded-fodder / low-fatigue stun spam (preserving full-dmg Dazing Cudgel
    // + Reforged Concussive Strikes headshot stuns!), while firing cleanly on genuine clutch stuns (Champions, Berserkers,
    // Knights, Warlords, Executioners, Mentor-breachers, and active Riposte/Spearwall cancels).
    function evaluateSmartKnockOut( _behavior, _actor, _origScore )
    {
        if ((typeof _origScore != "integer" && typeof _origScore != "float") || _origScore <= 0.0 || _behavior.m.Skill == null)
            return _origScore;

        local info = this.assessBattle(_actor, _behavior.getAgent());
        if (::Tactical.TurnSequenceBar.canEntityWait(_actor))
        {
            local wPlan = this.evaluateTacticalWait(_actor, info, _behavior.getAgent());
            if (wPlan != null && wPlan.SuppressAttack)
            {
                _behavior.m.TargetTile = null;
                _behavior.m.Skill = null;
                _behavior.m.BestTarget = null;
                return ::Const.AI.Behavior.Score.Zero;
            }
        }

        local skill = _behavior.m.Skill;
        local sid = skill.getID();
        // Only govern Mace stun skills (leave Disarm, RF Hook Shield, and RF Deep Impact unaffected).
        if (sid != "actives.strike_down" && sid != "actives.knock_out")
            return _origScore;

        local foe = null;
        if (_behavior.m.TargetTile != null && _behavior.m.TargetTile.IsOccupiedByActor)
            foe = _behavior.m.TargetTile.getEntity();
        else if (_behavior.m.BestTarget != null)
        {
            if (typeof _behavior.m.BestTarget == "table" && ("Target" in _behavior.m.BestTarget))
                foe = _behavior.m.BestTarget.Target;
            else
                foe = _behavior.m.BestTarget;
        }

        local veto = false;
        if (foe == null || ::MSU.isNull(foe) || !foe.isAlive() || foe.isDying()
            || foe.getMoraleState() == ::Const.MoraleState.Fleeing
            || foe.getCurrentProperties().IsStunned
            || foe.getCurrentProperties().IsImmuneToStun)
        {
            veto = true;
        }

        local isEmergencyPeel = false;
        local isApexKiller = false;
        local isCancelStance = false;

        if (!veto)
        {
            local is2H = (sid == "actives.strike_down");
            local prim = _actor.getSkills().getSkillByID(is2H ? "actives.cudgel" : "actives.bash");
            if (prim == null || prim.isHidden() || !prim.isUsable() || !prim.isAffordable())
                prim = this.cheapestMeleeSkill(_actor);

            local ft = foe.getTile();
            local fs = foe.getSkills();
            local cn = foe.ClassName;
            local st = this.enemyLiveStats(foe);
            local elite = this.enemyEliteScore(foe, info);
            local availFat = _actor.getFatigueMax() - _actor.getFatigue();
            local fatPct = _actor.getFatigue().tofloat() / ::Math.maxf(1.0, _actor.getFatigueMax().tofloat());
            local skillFat = skill.getFatigueCost();

            // Check emergency peel: enemy breaching Mentor (dist <= 2) or adjacent to a ranged / wounded (<48% HP) unshielded brother.
            foreach (bro in info.Brothers)
            {
                local bt = bro.getTile();
                local bd = ft.getDistanceTo(bt);
                if (this.isCasterRole(bro) && bd <= 2)
                {
                    isEmergencyPeel = true;
                    break;
                }
                if (bd <= 1 && (this.isRangedRole(bro) || (!::BGP.hasShield(bro) && bro.getHitpointsPct() <= 0.48)))
                {
                    isEmergencyPeel = true;
                    break;
                }
            }

            isApexKiller = fs.hasSkill("racial.champion") || fs.hasSkill("effects.berserker_rage")
                || cn == "orc_berserker" || cn == "orc_warlord"
                || cn == "knight" || cn == "rf_knight_anointed"
                || cn == "executioner" || cn == "desert_devil"
                || cn == "barbarian_chosen" || cn == "barbarian_champion"
                || cn == "swordmaster" || cn == "blade_dancer"
                || cn == "rf_marshal" || cn == "nomad_leader" || cn == "hedge_knight";

            isCancelStance = (fs.hasSkill("effects.riposte") || fs.hasSkill("effects.spearwall") || fs.hasSkill("effects.shieldwall"))
                && elite >= 1.25 && foe.getHitpointsPct() >= 0.50;

            local stunHit = 50;
            try { stunHit = skill.getHitchance(foe); } catch (e) {}

            // 1. Kill > Stun: never spend 2x fatigue for 0.5x damage when primary Cudgel/Bash already kills or target is dying!
            if (prim != null && prim.getID() != sid)
            {
                local pEd = this.computeSkillExpectedDamage(_actor, prim, foe, _actor.getTile());
                if (pEd.OnHitRawHP >= foe.getHitpoints() * 0.90 && pEd.Hit >= 40)
                    veto = true;
            }
            if (!veto && !isEmergencyPeel && foe.getHitpointsPct() <= 0.42 && foe.getHitpoints() <= 60)
                veto = true;

            // 2. Hit chance & Fatigue discipline.
            if (!veto)
            {
                if (isEmergencyPeel)
                {
                    if (stunHit < 42 || availFat < skillFat + 6)
                        veto = true;
                }
                else
                {
                    if (stunHit < 52 || availFat < skillFat + 22 || fatPct > 0.58)
                        veto = true;
                }
            }

            // 3. Surround discipline: do not stun enemies already surrounded by 3+ allies (just smash them down!).
            local adjAllies = 0;
            if (!veto)
            {
                for (local d = 0; d < 6; ++d)
                {
                    if (!ft.hasNextTile(d)) continue;
                    local nt = ft.getNextTile(d);
                    if (nt.IsOccupiedByActor && ::Math.abs(nt.Level - ft.Level) <= 1 && nt.getEntity().isAlliedWith(_actor))
                        ++adjAllies;
                }
                if (adjAllies >= 3 && !isEmergencyPeel && (!isApexKiller || foe.getHitpointsPct() <= 0.60))
                    veto = true;
            }

            // 4. Target threat tier & Daze/Concussive-Strikes discipline:
            //    2H Cudgel already deals 2x damage + auto-Daze 2T + free headshot Stun (rf_concussive_strikes).
            //    Reserve Strike Down / Knock Out strictly for Apex Killers, Emergency Peels, Stance Cancels, or high-elite unacted undazed 2H threats!
            if (!veto)
            {
                local hasConcussive = _actor.getSkills().hasSkill("perk.rf_concussive_strikes");
                local highElite = this.isHeavyMeleeThreat(foe, _actor) && elite >= (hasConcussive ? 1.80 : 1.65)
                    && foe.getHitpointsPct() >= 0.58 && adjAllies <= 2
                    && st.CanActThisRound && (!hasConcussive || st.TurnsUntil <= 4)
                    && !fs.hasSkill("effects.dazed");
                if (!isEmergencyPeel && !isApexKiller && !isCancelStance && !highElite)
                    veto = true;
            }

            // 5. Turn-order & late-battle cleanup discipline.
            if (!veto && !st.CanActThisRound)
            {
                if (!is2H)
                {
                    if (!isEmergencyPeel && !isCancelStance)
                        veto = true;
                }
                else
                {
                    // Even for 2-turn Strike Down, only stun an already-acted enemy if it's a healthy Apex Killer or Emergency Peel with abundant stamina.
                    if (!((isEmergencyPeel || isApexKiller) && foe.getHitpointsPct() >= 0.58 && availFat >= skillFat + 26))
                        veto = true;
                }
            }
            if (!veto && info.ActiveEnemies <= 3 && !isEmergencyPeel && !isApexKiller)
                veto = true;
        }

        if (veto)
        {
            _behavior.m.TargetTile = null;
            _behavior.m.Skill = null;
            _behavior.m.BestTarget = null;
            return ::Const.AI.Behavior.Score.Zero;
        }

        if (isEmergencyPeel || isApexKiller || isCancelStance)
            return ::Math.maxf(_origScore, 340.0);
        return _origScore * 0.85;
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
            // Against melee-only enemies with NO ranged weapons (no bows/crossbows/javelins) and NO Miasma/Horror priests,
            // never walk into enemy melee strike range (dist 1, or dist 2 of an unengaged enemy) without AP left to strike first!
            if (!veto && F.isGivingMeleeFirstStrike(_entity, this.m.TargetTile, info, approxApAfter, effAtkAP))
            {
                veto = true;
            }
            // Prevent living brothers from walking straight into Miasma / Fire / negative tile hazards unless finishing a dying target or peeling Mentor!
            if (!veto && this.m.TargetTile.ID != myTile.ID && this.hasNegativeTileEffect(this.m.TargetTile, _entity))
            {
                local tgt = this.m.TargetActor;
                local lethalOrFleeing = tgt != null && !::MSU.isNull(tgt)
                    && (tgt.getMoraleState() == ::Const.MoraleState.Fleeing || tgt.getHitpoints() <= 28);
                local peelingChief = false;
                if (tgt != null && !::MSU.isNull(tgt))
                {
                    local tt = tgt.getTile();
                    foreach (bro in info.Brothers)
                    {
                        if (F.isCasterRole(bro) && tt.getDistanceTo(bro.getTile()) <= 2)
                        {
                            peelingChief = true;
                            break;
                        }
                    }
                }
                if (!lethalOrFleeing && !peelingChief)
                {
                    local reqAP = effAtkAP != null ? effAtkAP : 4;
                    if (!::BGP.hasShield(_entity) || _entity.getHitpointsPct() <= 0.65 || approxApAfter < reqAP)
                        veto = true;
                    else
                        this.m.Score *= 0.30;
                }
            }
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
            // Universal high-ground discipline (applies to BOTH Shieldbearers and unshielded melee, even when enemy has stronger ranged!):
            // Never walk below an uphill melee enemy (locking them on high ground with +10% elevation bonus) or into uphill polearm reach (dist <= 2),
            // unless peeling Mentor, chasing fleeing targets, securing a lethal finish, matching elevation, or HillCampStall lifted the hold!
            if (!veto && this.m.TargetTile.ID != myTile.ID && !F.isRangedRole(_entity) && !F.isCasterRole(_entity))
            {
                local tgt = this.m.TargetActor;
                local tgtFleeing = tgt != null && !::MSU.isNull(tgt) && tgt.getMoraleState() == ::Const.MoraleState.Fleeing;
                local tgtDying = tgt != null && !::MSU.isNull(tgt) && tgt.getHitpoints() <= 24;
                if (!tgtFleeing && !tgtDying)
                {
                    local uphill = F.isUphillMeleeTrap(this.m.TargetTile, _entity, info);
                    local reqAP = effAtkAP != null ? effAtkAP : 4;
                    if (uphill.IsTrap)
                    {
                        veto = true;
                    }
                    else if (uphill.PolearmTrap && (approxApAfter < reqAP || ::BGP.hasShield(_entity)))
                    {
                        veto = true;
                    }
                    else if (!::BGP.hasShield(_entity) && info.EnemyProjectileRanged < 3.0 && info.EnemyUrgentCasters == 0
                        && tgt != null && !::MSU.isNull(tgt))
                    {
                        local tgtLvl = tgt.getTile().Level;
                        local destLvl = this.m.TargetTile.Level;
                        local badJump = this.m.TargetTile.IsBadTerrain && !myTile.IsBadTerrain;
                        if ((destLvl < tgtLvl || destLvl < myTile.Level || badJump) && F.isFragileMelee(_entity))
                        {
                            if (approxApAfter < reqAP)
                                veto = true;
                            else
                                this.m.Score *= 0.45;
                        }
                    }
                }
            }
            // Also stop shieldbearers from being dragged by vanilla EngageMelee into 3+ surrounds, isolated solo dives,
            // or R1-R2 3+ tile scatter-sprints without Shieldwall AP against hybrid heavy-ranged + strong-melee armies!
            if (!veto && ::BGP.hasShield(_entity) && this.m.TargetTile.ID != myTile.ID)
            {
                local exp = F.evaluateTileExposure(_entity, this.m.TargetTile, info);
                local sw = _entity.getSkills().getSkillByID("actives.shieldwall");
                local swAP = (sw != null && !sw.isHidden() && sw.isUsable()) ? sw.getActionPointCost() : 4;
                if (exp.AdjEnemies >= 3 && (exp.AdjAllies == 0 || (approxApAfter < swAP && _entity.getCurrentProperties().getMeleeDefense() < 40)))
                    veto = true;
                else if (exp.AdjAllies == 0 && exp.NearAllies2 == 0 && approxApAfter < swAP && exp.AdjEnemies >= 2)
                    veto = true;
                else if (::Time.getRound() <= 2 && info.HybridRangedHeavyMelee && approxApAfter < swAP
                    && (myTile.getDistanceTo(this.m.TargetTile) >= 3 || (exp.AdjAllies == 0 && exp.NearAllies2 == 0)))
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

// Smart Adrenaline discipline for Autopilot-controlled player brothers:
// Never waste 20 Fatigue on Adrenaline when every nearby threatening enemy already has lower Initiative and the brother is healthy/uninjured!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_adrenaline", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        local score = __original(_entity);
        if (score <= 0 || !::Autopilot.isUnderAIControl(_entity) || !::Autopilot.conf("bgpSmartFrontline"))
            return score;
        local adr = _entity.getSkills().getSkillByID("actives.adrenaline");
        if (adr == null || adr.isHidden() || !adr.isUsable() || !adr.isAffordable() || _entity.getSkills().hasSkill("effects.adrenaline"))
            return ::Const.AI.Behavior.Score.Zero;

        local info = F.assessBattle(_entity, this.getAgent());
        if (info.Enemies.len() == 0)
            return ::Const.AI.Behavior.Score.Zero;

        local hasTempInjury = _entity.getSkills().hasSkillOfType(::Const.SkillType.TemporaryInjury);
        // Attack FIRST before considering Adrenaline unless actively suffering a temporary injury that Reforged Adrenaline suppresses immediately.
        if (!hasTempInjury)
        {
            local atk = F.cheapestMeleeSkill(_entity);
            if (atk != null && F.hasAdjacentTarget(_entity, atk, info.Enemies))
                return ::Const.AI.Behavior.Score.Zero;
        }
        // Keep enough fatigue headroom so Adrenaline never stamina-locks next turn's attack.
        local availFat = _entity.getFatigueMax() - _entity.getFatigue();
        if (availFat < adr.getFatigueCost() + 12)
            return ::Const.AI.Behavior.Score.Zero;

        local myTile = _entity.getTile();
        local inZoC = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) > 0;
        local myFatRec = 15;
        try { myFatRec = _entity.getCurrentProperties().getFatigueRecoveryRate(); } catch (e) { myFatRec = 15; }
        local myNextIni = _entity.getInitiative() + ::Math.min(_entity.getFatigue(), myFatRec);

        local meleeAdj = 0;
        local fasterAdj = 0;
        local heavyFasterAdj = 0;
        local fasterClose = 0;
        local nearestFastDist = 99;
        local hasHeavyKillOrEliteFaster = false;
        local scanMaxDist = inZoC ? 2 : 3;
        foreach (foe in info.Enemies)
        {
            if (!F.isDangerousMeleeEnemy(foe)) continue;
            // Never burn 20 Fatigue on Adrenaline to "outspeed" high-Initiative Geists/Banshees (low HP, huge MDef).
            if (foe.ClassName == "ghost" || foe.ClassName == "rf_banshee") continue;
            local ft = foe.getTile();
            local d = myTile.getDistanceTo(ft);
            if (d > scanMaxDist) continue;
            local isAdj = (d == 1 && ::Math.abs(myTile.Level - ft.Level) <= 1);
            if (isAdj)
                ++meleeAdj;
            local eFatRec = 15;
            try { eFatRec = foe.getCurrentProperties().getFatigueRecoveryRate(); } catch (e) { eFatRec = 15; }
            local eNextIni = foe.getInitiative() + ::Math.min(foe.getFatigue(), eFatRec);
            local foeFaster = (eNextIni >= myNextIni - 2) || foe.getSkills().hasSkill("effects.adrenaline");
            if (foeFaster)
            {
                local isHeavyOrElite = F.isHeavyMeleeThreat(foe) || F.enemyEliteScore(foe, info) >= 1.4;
                ++fasterClose;
                if (d < nearestFastDist) nearestFastDist = d;
                if ((isAdj || (d == 2 && foe.getIdealRange() >= 2 && ::Math.abs(myTile.Level - ft.Level) <= 1)))
                {
                    ++fasterAdj;
                    if (isHeavyOrElite) ++heavyFasterAdj;
                }
                if (d <= 2 && (isHeavyOrElite || (foe.getHitpointsPct() <= 0.50 && foe.getHitpointsMax() >= 85)))
                    hasHeavyKillOrEliteFaster = true;
            }
        }

        local hpPct = _entity.getHitpointsPct();
        local bodyArm = _entity.getArmor(::Const.BodyPart.Body);
        local inDanger = inZoC && (hpPct <= 0.55 || (bodyArm <= 45 && hpPct <= 0.75) || (meleeAdj >= 3 && (hpPct <= 0.78 || heavyFasterAdj >= 1)));

        // Core rule: if EVERY nearby threatening enemy is already slower than us (e.g. Zombies),
        // strictly block Adrenaline unless truly needed for Reforged survival / injury immunity!
        if (fasterAdj == 0 && fasterClose == 0)
        {
            if ((inDanger && hpPct <= 0.50) || (inZoC && hasTempInjury))
                return score;
            return ::Const.AI.Behavior.Score.Zero;
        }
        // Against faster enemies, only spend 20 Fatigue when truly in danger, injured, or leapfrogging an adjacent heavy/elite threat with spare fatigue
        // (never waste Adrenaline at 100% HP & full Battle Forged armor against weak fodder zombies!).
        if (fasterAdj > 0 && (inDanger || hasTempInjury || (heavyFasterAdj > 0 && (hpPct <= 0.80 || availFat >= adr.getFatigueCost() + 20))))
            return score;
        if (!inZoC && fasterClose > 0 && hasHeavyKillOrEliteFaster && nearestFastDist <= 2 && availFat >= adr.getFatigueCost() + 26)
            return score;
        return ::Const.AI.Behavior.Score.Zero;
    };
});

// Prevent unengaged brothers who just raised Spearwall from burning 20 extra fatigue stacking vanilla Shieldwall on the same turn,
// prevent shieldbearers peeling a melee enemy off Mentor from wasting attack AP on Shieldwall,
// and skip pointless Shieldwall when ZERO adjacent/reach enemies can attack before our next turn!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_defend_shieldwall", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline"))
        {
            local myTile = _entity.getTile();
            local inZoC = myTile.getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) > 0;
            if (_entity.getSkills().hasSkill("effects.spearwall") && !inZoC)
            {
                return ::Const.AI.Behavior.Score.Zero;
            }
            local info = F.assessBattle(_entity, this.getAgent());
            if (::BGP.hasShield(_entity) && F.isPeelingMentorMelee(_entity, info))
            {
                return ::Const.AI.Behavior.Score.Zero;
            }
            if (inZoC && !(info.EnemyProjectileRanged >= 4.0 && _entity.getHitpointsPct() <= 0.65))
            {
                local preThreat = F.hasThreatBeforeNextTurn(_entity, info.Enemies);
                if (preThreat.Count == 0)
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
            // Never switch back to a ranged weapon when completely out of all ranged ammo!
            if (!F.hasAnyRangedAmmoLeft(_entity))
                return ::Const.AI.Behavior.Score.Zero;
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
        if (this.m.Thread != null && this.m.Thread.getstatus() == "dead")
            this.m.Thread = null;
        local done;
        try { done = __original(_entity); }
        catch (e) {
            local threadDead = this.m.Thread != null && this.m.Thread.getstatus() == "dead";
            if (threadDead) {
                this.m.Thread = null;
                this.m.TargetTile = null;
                this.m.Score = 0;
            }
            if (threadDead && (e == "the index 'getID' does not exist"
                || e == "the index 'IsEmpty' does not exist"
                || e == "resuming dead generator"))
                return true;
            throw e;
        }
        if (done && this.m.Score > 0 && F.shouldSuppressEngageRanged(_entity, this.getAgent(), this.m.TargetTile, this.m.Skill))
        {
            this.m.TargetTile = null;
            this.m.Score = 0;
        }
        return done;
    };
});

// Let non-shield 2-tile bros yield Phase 1 for tactical Wait (tank opener, surround/armor-strip combo, buff expire),
// yield to clean zero-FF actives.reap opportunities (both standing Attack.Reap and BGP_Frontline step_reap),
// and fix snh_isTileInDanger so healthy Billhook/polearm bros don't get paralyzed by enemies already locked in our frontline's ZoC!
::BGP.HooksMod.hook("scripts/ai/autopilot_step_n_hit", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && _entity.getTile().getZoneOfControlCountOtherThan(_entity.getAlliedFactions()) == 0)
        {
            local decision = F.shouldActorHold(_entity, this.getAgent());
            if (!::BGP.hasShield(_entity) && ::Tactical.TurnSequenceBar.canEntityWait(_entity))
            {
                local wPlan = F.evaluateTacticalWait(_entity, decision.Info, this.getAgent());
                if ((wPlan != null && wPlan.SuppressMove) || F.hasUnactedShieldAlly(_entity, decision.Info))
                    return 0;
            }
            // Yield single-target step-and-strike whenever a clean zero-FF 2-3 enemy Reap sweep is available (standing or stepping)!
            if (_entity.getSkills().hasSkill("actives.reap"))
            {
                local reapPlan = F.findBestReapPlan(this, _entity, decision.Info);
                if (reapPlan != null)
                    return 0;
            }
        }
        return __original(_entity);
    };
    q.snh_isTileInDanger = @(__original) function( _entity, _tile ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline") && this.hasNegativeTileEffect(_tile, _entity))
            return true;
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

// Yield melee attacks ONLY when our ironclad safe Phase-1 tactical combo wait (wait_combo_inzoc / wait_buff_expire) triggers,
// so fast Cleaver/Sword/Polearm DPS waits for slower Hammer/2H Mace/Tank allies to strip armor & surround before bursting in Phase 2!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_default", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && ::Tactical.TurnSequenceBar.canEntityWait(_entity))
        {
            local info = F.assessBattle(_entity, this.getAgent());
            local wPlan = F.evaluateTacticalWait(_entity, info, this.getAgent());
            if (wPlan != null && wPlan.SuppressAttack)
                return ::Const.AI.Behavior.Score.Zero;
        }
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/autopilot_attack_alternate", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        if (::Autopilot.isUnderAIControl(_entity) && ::Autopilot.conf("bgpSmartFrontline")
            && ::Tactical.TurnSequenceBar.canEntityWait(_entity))
        {
            local info = F.assessBattle(_entity, this.getAgent());
            local wPlan = F.evaluateTacticalWait(_entity, info, this.getAgent());
            if (wPlan != null && wPlan.SuppressAttack)
                return ::Const.AI.Behavior.Score.Zero;
        }
        return __original(_entity);
    };
});

// Gen 35: Zero-friendly-fire & timing optimization for Polearm Reap, 2H Hammer Shatter / Swings, Line Splits, 360 Thresh/Round Swing,
// Cleaver Decapitate (both player brothers & Lich King / PlayerAnimals), and Mace Strike Down / Knock Out!
// Note: when empty-tile shift aiming is selected to avoid friendly fire, onExecute safely invokes skill.use(TargetTile) directly.
local function safeEmptyTileAoEExecute( _behavior, _entity )
{
    if (::Autopilot.conf("bgpSmartFrontline")
        && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals)
        && _behavior.m.TargetTile != null && !_behavior.m.TargetTile.IsOccupiedByActor
        && _behavior.m.Skill != null)
    {
        local sk = _behavior.m.Skill;
        local tt = _behavior.m.TargetTile;
        _behavior.m.TargetTile = null;
        _behavior.m.Skill = null;
        if (sk.isUsable() && sk.isAffordable() && sk.isUsableOn(tt, _entity.getTile()))
        {
            _behavior.getAgent().adjustCameraToTarget(tt);
            if (sk.use(tt))
            {
                if (!_entity.isHiddenToPlayer())
                    _behavior.getAgent().declareAction();
                if (sk.getDelay() != 0)
                    _behavior.getAgent().declareEvaluationDelay(sk.getDelay());
            }
        }
        return true;
    }
    return false;
}

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_reap", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.conf("bgpSmartFrontline")
            && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals))
        {
            try { this.m.Thread = null; } catch (e) {}
            this.m.Score = F.evaluateSmartMeleeAoE(this, _entity, 0.0, "reap");
            return true;
        }
        return __original(_entity);
    };
    q.onExecute = @(__original) function( _entity ) {
        if (safeEmptyTileAoEExecute(this, _entity))
            return true;
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_swing", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.conf("bgpSmartFrontline")
            && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals))
        {
            try { this.m.Thread = null; } catch (e) {}
            this.m.Score = F.evaluateSmartMeleeAoE(this, _entity, 0.0, "swing");
            return true;
        }
        return __original(_entity);
    };
    q.onExecute = @(__original) function( _entity ) {
        if (safeEmptyTileAoEExecute(this, _entity))
            return true;
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_split", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.conf("bgpSmartFrontline")
            && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals))
        {
            try { this.m.Thread = null; } catch (e) {}
            this.m.Score = F.evaluateSmartMeleeAoE(this, _entity, 0.0, "split");
            return true;
        }
        return __original(_entity);
    };
    q.onExecute = @(__original) function( _entity ) {
        if (safeEmptyTileAoEExecute(this, _entity))
            return true;
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_thresh", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.conf("bgpSmartFrontline")
            && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals))
        {
            try { this.m.Thread = null; } catch (e) {}
            this.m.Score = F.evaluateSmartMeleeAoE(this, _entity, 0.0, "thresh");
            return true;
        }
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_decapitate", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        if (::Autopilot.conf("bgpSmartFrontline")
            && (::Autopilot.isUnderAIControl(_entity) || _entity.getFaction() == ::Const.Faction.PlayerAnimals))
        {
            try { this.m.Thread = null; } catch (e) {}
            this.m.Score = F.evaluateSmartDecapitate(this, _entity, 0.0);
            return true;
        }
        return __original(_entity);
    };
});

::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_attack_knock_out", function(q) {
    q.evaluate = @(__original) function( _entity ) {
        local done = __original(_entity);
        if (done && ::Autopilot.conf("bgpSmartFrontline") && ::Autopilot.isUnderAIControl(_entity))
            this.m.Score = F.evaluateSmartKnockOut(this, _entity, this.m.Score);
        return done;
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

// Gate Reforged RF_CoverAlly (costs 4 AP, 20 Fatigue, and debuffs caster's own MSk/MDef!):
// never let player brothers burn 4 AP & self-debuff to "cover" disposable undead summons or healthy melee tanks;
// restrict strictly to rescuing Mentor, a ranged backliner, or a critically wounded unshielded brother (<= 40% HP)!
::BGP.HooksMod.hook("scripts/ai/tactical/behaviors/ai_rf_cover_ally", function(q) {
    q.onEvaluate = @(__original) function( _entity ) {
        local score = __original(_entity);
        if (score <= 0)
            return score;
        if (::Autopilot.conf("bgpSmartFrontline") && ::Autopilot.isUnderAIControl(_entity))
        {
            local ally = this.m.TargetAlly;
            if (ally == null || ::MSU.isNull(ally) || ally.getFaction() != ::Const.Faction.Player)
                return ::Const.AI.Behavior.Score.Zero;
            local isEmergencyAlly = F.isCasterRole(ally) || F.isRangedRole(ally)
                || (!::BGP.hasShield(ally) && ally.getHitpointsPct() <= 0.40);
            if (!isEmergencyAlly || _entity.getHitpointsPct() < 0.50)
                return ::Const.AI.Behavior.Score.Zero;
        }
        return score;
    };
});

// Track per-round Infusion casts so Mentor never casts Infusion twice on the same undead target in one turn.
::BGP.HooksMod.hook("scripts/skills/actives/bgp_necro_infusion_skill", function(q) {
    q.m.BGPAutoInfuseRound <- -1;
    q.m.BGPAutoInfuseTargets <- null;
    q.onCombatStarted = @(__original) function() {
        __original();
        this.m.BGPAutoInfuseRound = -1;
        this.m.BGPAutoInfuseTargets = null;
    };
    q.onUse = @(__original) function(user, tile) {
        local ent = tile != null && tile.IsOccupiedByActor ? tile.getEntity() : null;
        local id = ent != null ? ent.getID() : -1;
        local result = __original(user, tile);
        if (result && id != -1) {
            if (this.m.BGPAutoInfuseRound != ::Time.getRound()) {
                this.m.BGPAutoInfuseRound = ::Time.getRound();
                this.m.BGPAutoInfuseTargets = {};
            }
            this.m.BGPAutoInfuseTargets[id] <- true;
        }
        return result;
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
