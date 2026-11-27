local S = ::PaleSovereign, A = ::BGP.Autopilot;
local staffStrikeMult = 0.25;
local page = ::Autopilot.msu.ModSettings.getPage("背景与亡灵");
page.addElement(::MSU.Class.BooleanSetting("paleAutoChampion", true, "导师自动放出勇士", "第一回合召唤僵尸和骷髅，第二回合起放出饰品栏勇士并优先支配它。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoExtraSummon", false, "导师自动耗骸续召", "允许导师在每场免费召唤用完后消耗防腐尸骸续召僵尸和骷髅；关闭时每场默认各免费召唤 1 次。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoCorpseShot", true, "自动投掷防腐尸骸", "有尸骸储备时，可向敌群投掷尸弹。优先利用战场已有的尸体。"));
page.addRangeSetting("paleAutoCorpseShotLimit", 3, 0, 20, 1, "尸弹每场允许使用次数", "自动战斗中每场战斗最多允许投掷尸弹的次数（默认 3 次；0 表示自动战斗不投掷）。不影响手动操作。");
page.addElement(::MSU.Class.BooleanSetting("paleAutoChain", false, "自动使用缚魂锁链", "允许导师标记可吞魂的强敌，或用一条锁链复活可收编的亡灵强敌。"));

// Count Mentor's total remaining free summon charges across Skeleton & Zombie summons.
local function totalFreeSummonsLeft( _actor ) {
    local total = 0;
    foreach (sid in ["actives.pale_summon_skeleton", "actives.pale_summon_zombie"]) {
        local sk = _actor.getSkills().getSkillByID(sid);
        if (sk != null && !sk.isHidden()) {
            try { total += ::Math.max(0, sk.getFreeUses() - sk.m.FreeUsed); } catch (e) {}
        }
    }
    return total;
}

// Inspect whether Mentor faces a melee breach (<=3 tiles / ZoC) or exposed ranged fire (needs an immediate summon blocker).
local function mentorSummonCrisis( c ) {
    if ("MentorCrisis" in c.Cache)
        return c.Cache.MentorCrisis;
    local origin = c.Origin;
    local F = A.Frontline;
    local meleeThreatTile = null;
    local meleeThreatDist = 99;
    local shooterTile = null;
    local shooterDist = 99;
    local enemies = [];
    foreach (et in c.Enemies) {
        local foe = et.getEntity();
        if (foe == null || ::MSU.isNull(foe) || !foe.isAlive() || foe.isDying() || foe.getMoraleState() == ::Const.MoraleState.Fleeing)
            continue;
        enemies.push(foe);
        local d = origin.getDistanceTo(et);
        if (F.isLiveBacklineThreat(foe) && d < meleeThreatDist) {
            meleeThreatDist = d;
            meleeThreatTile = et;
        }
        if (foe.isArmedWithRangedWeapon()) {
            local w = foe.getMainhandItem();
            if (w == null || !w.isItemType(::Const.Items.ItemType.Ammo)) {
                if (d < shooterDist) { shooterDist = d; shooterTile = et; }
            }
        }
    }
    local inZoC = A.zone(c.Actor, origin) > 0;
    local meleeCrisis = inZoC || (meleeThreatDist <= 2) || (meleeThreatDist == 3 && meleeThreatTile != null && F.countScreenBlockersBetween(origin, c.Actor, meleeThreatTile).Blockers == 0);
    local rangedNeedCover = (shooterTile != null && shooterDist <= 8 && !F.hasRangedCoverAt(origin, c.Actor, enemies, 8));
    local aliveUndead = 0;
    foreach (u in ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.PlayerAnimals)) {
        if (u != null && !::MSU.isNull(u) && u.isAlive() && !u.isDying() && u.isPlacedOnMap() && u.getFlags().has("undead"))
            ++aliveUndead;
    }
    // Also release the pocket summon if Mentor is hurt (< 65% HP) or goblin-poisoned while enemies press within 4 tiles or shooters are in range, or if undead frontline collapses (<= 3).
    local isGoblinPoisoned = c.Actor.getSkills().hasSkill("effects.goblin_poison");
    local hurtUnderPressure = (c.Actor.getHitpointsPct() < 0.65 || isGoblinPoisoned) && (meleeThreatDist <= 4 || (shooterTile != null && shooterDist <= 8));
    local lineCollapse = (::Time.getRound() >= 4 && aliveUndead <= 3);
    local res = {
        MeleeCrisis = meleeCrisis,
        MeleeTile = meleeThreatTile,
        MeleeDist = meleeThreatDist,
        RangedNeedCover = rangedNeedCover,
        ShooterTile = shooterTile,
        ShooterDist = shooterDist,
        LineCollapse = lineCollapse,
        AnyCrisis = meleeCrisis || rangedNeedCover || hurtUnderPressure || lineCollapse
    };
    c.Cache.MentorCrisis <- res;
    return res;
}

local function screen(c, s, t) {
    if (c.Behavior.hasNegativeTileEffect(t, c.Actor)) return 0;
    local distance = A.nearest(c.Enemies, t);
    if (distance == 99 && ::Time.getRound() > 2 && !S.isChief(c.Actor)) return 0;
    local zones = A.zone(c.Actor, t), formationPenalty = 0.0;
    local coverBonus = 0.0;
    if (S.Battle != null && !S.Battle.CompanyContact) {
        if (!("OpeningGroup" in c.Cache)) {
            local group = S.formationGroup(S.fieldBrothers());
            c.Cache.OpeningGroup <- group;
            c.Cache.OpeningThreats <- group.Anchor == null ? [] : S.formationThreats(c.Behavior.getAgent(), group);
        }
        if (c.Cache.OpeningGroup.Anchor != null)
            formationPenalty = ::Math.minf(2.5, 0.75 * S.formationLead(t, c.Cache.OpeningThreats)
                + 0.18 * t.getDistanceTo(c.Cache.OpeningGroup.Anchor));
    }
    // Prefer spawning summons/Lich directly between Mentor and approaching threats for immediate melee screen & ranged cover.
    if (::Autopilot.conf("bgpSmartFrontline") && S.isChief(c.Actor) && distance < 99) {
        local originDist = A.nearest(c.Enemies, c.Origin);
        if (distance < originDist) coverBonus = 1.8;
        local crisis = mentorSummonCrisis(c);
        if (crisis.MeleeTile != null && crisis.MeleeDist <= 4 && t.getDistanceTo(crisis.MeleeTile) < crisis.MeleeDist)
            coverBonus += (crisis.MeleeCrisis ? 7.5 : 4.5);
        if (crisis.RangedNeedCover && crisis.ShooterTile != null && t.getDistanceTo(crisis.ShooterTile) < crisis.ShooterDist)
            coverBonus += 8.0;
    }
    return 4.7 - formationPenalty + coverBonus + (distance == 99 ? 0 : 1.4 / ::Math.maxf(1.0, distance))
        + 0.13 * (t.Level - c.Origin.Level) - (t.IsBadTerrain ? 0.32 : 0) - 0.45 * ::Math.max(0, zones - 1);
}
local function summon(c, s, t) {
    local freeLeft = "hasFreeUseLeft" in s ? s.hasFreeUseLeft() : !s.m.Used;
    if (!freeLeft && !::Autopilot.conf("paleAutoExtraSummon")) return 0;
    local value = screen(c, s, t);
    if (value <= 0) return 0;
    if (S.isChief(c.Actor)) {
        if (::Autopilot.conf("bgpSmartFrontline")) {
            local totalFree = totalFreeSummonsLeft(c.Actor);
            local crisis = mentorSummonCrisis(c);
            local rnd = ::Time.getRound();
            // Always reserve the LAST free summon charge for a Mentor crisis (melee breach, ranged exposure, or line collapse).
            if (freeLeft && totalFree <= 1) {
                if (crisis.AnyCrisis)
                    return value + 20.0;
                return 0;
            }
            // Round 2 pacing: after Mentor's first 4-AP summon leaves 5 AP, yield to 5-AP Curse of Ages (Scourge, up to 16.5)
            // OR 3-AP Lich Infusion (Champion, up to 13.0) so Round 2 hits our key spell power-spike cleanly!
            local bonus = s.getID() == "actives.pale_summon_skeleton" ? 18.0 : 17.0;
            if (freeLeft && rnd == 2 && c.Actor.getActionPoints() <= 5 && !crisis.AnyCrisis)
                return value + 5.0;
            if (rnd <= 3 && freeLeft) return value + bonus;
            if (freeLeft) return value + 10.0;
        } else {
            if (::Time.getRound() <= 1 || (freeLeft && ::Time.getRound() <= 3))
                return value + 18.0;
            if (freeLeft) return value + 10.0;
        }
    } else if (freeLeft && ::Time.getRound() <= 3) {
        return value + 14.0;
    } else if (freeLeft) {
        return value + 9.0;
    }
    return value;
}
A.add("pale_summon_zombie", "Adjacent", summon);
A.add("pale_summon_skeleton", "Adjacent", summon);
A.add("unleash_companion", "Adjacent", function(c, s, t) {
    if (!S.isChief(c.Actor) || !::Autopilot.conf("paleAutoChampion") || S.mainPet() == null) return 0;
    local smart = ::Autopilot.conf("bgpSmartFrontline");
    if (!smart && ::Time.getRound() < 2) return 0;
    local value = screen(c, s, t);
    return value > 0 ? value + (smart ? 24.0 : 18.0) : 0;
});
local possess = A.Actions["actives.possess_undead"].Score;
A.Actions["actives.possess_undead"].Score = function(c, s, t) {
    if (S.isChief(c.Actor) && s.ClassName == "bgp_necro_possess_skill") {
        // Never overwrite an active Possession (especially ripping Possess off Lich King onto a fodder zombie!).
        if (c.Actor.getSkills().hasSkill("effects.possessing_undead"))
            return 0;
        local pet = S.mainPet();
        local target = t.getEntity();
        local smart = ::Autopilot.conf("bgpSmartFrontline");
        if (S.isDeployed(pet, target))
            // 13.2 * 130 = 1716: beats Raise Dead & Infusion while staying strictly BELOW Goblin24 deepVolleyZone backline_kite (1750)!
            return smart ? 13.2 : 19.0;
        if (pet != null && ::Autopilot.conf("paleAutoChampion")) {
            // While Lich King is alive on the field (or about to be unleashed in R1-2), never waste Possess on disposable summons!
            if (::Time.getRound() <= 2 && !S.isDeployed(pet))
                return 0;
            if (smart) {
                foreach (at in c.Allies) {
                    if (S.isDeployed(pet, at.getEntity()))
                        return 0;
                }
            }
        }
    }
    return possess(c, s, t);
};
// The generic wardog behavior must not deploy the mentor's coffin ahead of the opening.
S.Mod.hook("scripts/ai/autopilot_unleash_dog", function(q) {
    q.onEvaluate = @(__original) function(actor) {
        if (S.isChief(actor) && S.mainPet() != null) return 0;
        return __original(actor);
    };
});
A.add("pale_soul_strike", "Enemies", function(c, s, t) {
    local target = t.getEntity(), hit = A.weaponChance(s, t);
    local value = 2.4 + (target.getHitpoints() <= 24 ? 1.2 : 0);
    if (!target.getSkills().hasSkill("effects.pale_prey")) value += 0.35 * ::Math.min(3, A.countNear(c.Allies, t, 2));
    if (!target.getSkills().hasSkill("effects.dazed") && !target.getCurrentProperties().IsImmuneToDaze) value += 0.65;
    return value * hit * (S.isChief(c.Actor) ? staffStrikeMult : 1.0);
});
// Stock attack behaviors and Autopilot's step-and-hit also evaluate the staff independently.
S.Mod.hook("scripts/ai/tactical/behavior", function(q) {
    q.queryTargetValue = @(__original) function(actor, target, skill = null) {
        local score = __original(actor, target, skill);
        if (score > 0 && skill != null && skill.getID() == "actives.pale_soul_strike" && S.isChief(actor) && ::Autopilot.isUnderAIControl(actor))
            return score * staffStrikeMult;
        return score;
    };
});
A.add("pale_weaken", "Enemies", function(c, s, t) {
    local enemy = t.getEntity();
    local hp = enemy.getHitpoints();
    local value = 2.2 + (enemy.getSkills().hasSkill("effects.pale_weaken") ? 0 : 0.8);
    if (enemy.getMoraleState() == ::Const.MoraleState.Fleeing) value *= 0.6;
    if (s.m.Scourge) value += 0.85 * (A.countNear(c.Enemies, t) - 1);
    value += 0.22 * ::Math.min(3, A.countNear(c.Allies, t, 2));

    // Lethal snipe evaluation: pale_weaken deals 12-20 guaranteed armor-ignoring direct HP damage.
    local lethal = 0.0;
    if (hp <= 12) lethal = 9.5;
    else if (hp <= 16) lethal = 6.5;
    else if (hp <= 20) lethal = 3.0;
    if (s.m.Scourge) {
        foreach (et in c.Enemies) {
            if (et.ID != t.ID && et.getDistanceTo(t) <= 1 && et.getEntity().getHitpoints() <= 6)
                lethal += 4.0;
        }
    }
    if (lethal > 0.0) {
        // Extra priority when we can immediately raise the freshly killed enemy this same turn!
        local raise = c.Actor.getSkills().getSkillByID("actives.bgp_necro_raise");
        if (raise != null && !raise.isHidden() && raise.isUsable() && !t.IsCorpseSpawned
            && !enemy.getFlags().has("PaleRaised") && c.Origin.getDistanceTo(t) <= raise.getMaxRange()) {
            local apLeft = c.Actor.getActionPoints() - s.getActionPointCost();
            local fatLeft = c.Actor.getFatigueMax() - c.Actor.getFatigue() - s.getFatigueCost();
            if (apLeft >= raise.getActionPointCost() && fatLeft >= raise.getFatigueCost())
                lethal += (hp <= 12 ? 5.0 : 3.0);
        }
    } else if (!enemy.getSkills().hasSkill("effects.pale_prey") && enemy.getMoraleState() != ::Const.MoraleState.Fleeing) {
        // When no lethal snipe is available, prioritize marking dangerous high-HP/high-MSk/high-MDef bosses/elites as Prey (+10 hit / +20% dmg for all undead).
        local st = A.Frontline.enemyLiveStats(enemy);
        if (enemy.getHitpointsMax() >= 130 || enemy.getSkills().hasSkill("racial.champion")
            || enemy.getArmor(::Const.BodyPart.Body) >= 180 || st.MSk >= 78 || st.MDef >= 35)
            value += 2.2;
        if (st.MDef >= 38 && !st.IsExhausted)
            value += 1.0;
    }
    // Guaranteed-hit direct-HP snipe bonus against ultra-high-MDef Geists/Banshees and Ancient Priests!
    local isPrioritySnipe = false;
    if (enemy.ClassName == "ghost" || enemy.ClassName == "rf_banshee" || enemy.getSkills().hasSkill("actives.ghastly_touch")) {
        value += 4.5;
        isPrioritySnipe = true;
    } else if (enemy.getSkills().hasSkill("actives.miasma") || enemy.getSkills().hasSkill("actives.horror")
        || enemy.getSkills().hasSkill("actives.raise_undead")) {
        value += 3.0;
        isPrioritySnipe = true;
    }
    local total = value + lethal;
    if (::Autopilot.conf("bgpSmartFrontline")) {
        // Stay strictly below Goblin24 deepVolleyZone backline_kite (1750 = 13.46 * 130).
        // On Champion route (!Scourge), keep routine pale_weaken below Lich Possess (13.2), Infusion (13.0), Reforge (13.0), and urgent Raise Dead
        // unless executing a guaranteed lethal snipe on a Geist/Banshee/Priest/Necromancer/Champion or Mentor-breacher!
        if (!s.m.Scourge) {
            local nearMentor = c.Origin.getDistanceTo(t) <= 2;
            local allowHigh = (lethal >= 9.0 && (isPrioritySnipe || nearMentor || enemy.getSkills().hasSkill("racial.champion")));
            local cap = allowHigh ? 13.35 : (lethal >= 9.0 ? 12.1 : 10.6);
            total = ::Math.minf(cap, total);
        } else {
            total = ::Math.minf(13.4, total);
        }
    }
    return total;
});
A.add("pale_soul_chain", "Enemies", @(c, s, t) ::Autopilot.conf("paleAutoChain") ? 8.5 + (t.getEntity().getSkills().hasSkill("racial.champion") ? 1 : 0) : 0);
A.add("pale_soul_bind", "Corpses", @(c, s, t) ::Autopilot.conf("paleAutoChain") ? 8.0 + A.corpseValue(t) : 0);
A.add("pale_corpse_shot", "Enemies", function(c, s, t) {
    if (!::Autopilot.conf("paleAutoCorpseShot") || ::BGP.Necro.getCorpse(t) != null || A.countNear(c.Enemies, t) < 2) return 0;
    local maxShots = 3;
    try { maxShots = ::Autopilot.conf("paleAutoCorpseShotLimit").tointeger(); } catch (e) {}
    local usedShots = (S.Battle != null && "CorpseShots" in S.Battle) ? S.Battle.CorpseShots : 0;
    if (maxShots <= 0 || usedShots >= maxShots) return 0;
    if (::Autopilot.conf("bgpSmartFrontline")) {
        // Dedicated archers/crossbowmen, Mentor (who must summon/cast Curse & CE), engaged melee units, and fatigued bros stick to their core roles.
        if (c.Actor.isArmedWithRangedWeapon() || S.isChief(c.Actor) || c.Engaged) return 0;
        local availFat = c.Actor.getFatigueMax() - c.Actor.getFatigue();
        if (c.Actor.getFatigue() > c.Actor.getFatigueMax() * 0.55 || availFat < s.getFatigueCost() + 14) return 0;
        if (c.Origin.getDistanceTo(t) >= ::Const.Combat.DiversionMinDist && A.countNear(c.Allies, t) != 0) return 0;

        // Inspect enemy cluster density & Curse of Ages status inside the 7-tile blast radius centered on t.
        local enemiesNear = 0;
        local cursedNear = 0;
        local moraleVulnNear = 0;
        foreach (et in c.Enemies) {
            if (et.getDistanceTo(t) > 1) continue;
            local foe = et.getEntity();
            if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
            ++enemiesNear;
            if (foe.getSkills().hasSkill("effects.bgp_curse_of_ages")) ++cursedNear;
            if (!foe.getFlags().has("undead")) ++moraleVulnNear;
        }
        if (enemiesNear < 2) return 0;

        // Check whether Mentor can follow up with Corpse Explosion (and/or Curse of Ages) on tile t.
        local chief = S.chief();
        local inMentorBlastRange = false;
        local mentorHasCurse = false;
        if (chief != null && !::MSU.isNull(chief) && chief.isAlive() && !chief.isDying() && chief.isPlacedOnMap()) {
            local ce = chief.getSkills().getSkillByID("actives.bgp_corpse_explosion");
            if (ce != null && !ce.isHidden() && ce.isUsable() && chief.getTile().getDistanceTo(t) <= ce.getMaxRange())
                inMentorBlastRange = true;
            local cu = chief.getSkills().getSkillByID("actives.bgp_necro_curse_of_ages");
            if (cu != null && !cu.isHidden() && cu.isUsable() && chief.getTile().getDistanceTo(t) <= cu.getMaxRange())
                mentorHasCurse = true;
        }

        // Avoid redundant corpse stacking: skip if an existing corpse is adjacent AND already covers this cluster equally well.
        local corpses = c.Behavior.targets(c, "Corpses");
        foreach (corpse in corpses) {
            if (corpse.getDistanceTo(t) <= 1) {
                local cEnemies = 0;
                local cCursed = 0;
                foreach (et in c.Enemies) {
                    if (et.getDistanceTo(corpse) > 1) continue;
                    local foe = et.getEntity();
                    if (foe.getMoraleState() == ::Const.MoraleState.Fleeing) continue;
                    ++cEnemies;
                    if (foe.getSkills().hasSkill("effects.bgp_curse_of_ages")) ++cCursed;
                }
                if (enemiesNear < cEnemies + 2 && cursedNear < cCursed + 2)
                    return 0;
            }
        }

        // Distance & role safety: keep unshielded 1-tile melee from throwing at dist <= 2 (where they should strike or avoid eating zombie first-strike);
        // shieldbearers (with AP left for Shieldwall) and 2-tile polearms can safely seed combos from dist >= 2.
        local myNearest = A.nearest(c.Enemies, c.Origin);
        local isShield = ::BGP.hasShield(c.Actor);
        local isPolearm = !isShield && c.Actor.getIdealRange() >= 2;
        if (isShield) {
            if (myNearest < 2) return 0;
            if (myNearest == 2 && (c.Actor.getActionPoints() < s.getActionPointCost() + 4 || availFat < s.getFatigueCost() + 20))
                return 0;
        } else if (isPolearm) {
            if (myNearest < 2) return 0;
        } else {
            if (myNearest <= 2) return 0;
        }

        local hit = A.weaponChance(s, t);
        // Strongly prioritize ultra-dense 5+ enemy clusters (5-7 enemies in the 7-tile blast zone) for Curse + Corpse Explosion combos!
        if (inMentorBlastRange && enemiesNear >= 5) {
            if (cursedNear >= 2)
                return 8.0 + 0.90 * ::Math.min(7, enemiesNear) + 0.65 * ::Math.min(5, cursedNear)
                    + (moraleVulnNear >= 2 ? 0.45 : 0.0) + 0.20 * hit;
            return 7.3 + 0.90 * ::Math.min(7, enemiesNear) + (mentorHasCurse ? 0.55 : 0.0)
                + (moraleVulnNear >= 2 ? 0.45 : 0.0) + 0.20 * hit;
        }
        // Secondary 4-enemy clusters: solid combo setup when no 5+ clump is reachable.
        if (inMentorBlastRange && enemiesNear == 4) {
            if (cursedNear >= 2)
                return 6.0 + 0.55 * ::Math.min(4, cursedNear) + (moraleVulnNear >= 2 ? 0.35 : 0.0) + 0.20 * hit;
            if (corpses.len() < 4)
                return 5.4 + (mentorHasCurse ? 0.45 : 0.0) + (moraleVulnNear >= 2 ? 0.35 : 0.0) + 0.20 * hit;
        }
        // Low-priority 3-enemy clusters (only when few corpses exist and no 4+ dense clump is in range).
        if (inMentorBlastRange && enemiesNear == 3 && corpses.len() < 3) {
            if (cursedNear >= 2)
                return 4.1 + 0.35 * cursedNear + 0.20 * hit;
            return 3.8 + (mentorHasCurse ? 0.25 : 0.0) + (moraleVulnNear >= 2 ? 0.20 : 0.0) + 0.20 * hit;
        }
        // Fallback early corpse-seeding on 2-enemy tiles only when very few corpses (< 2) exist and no dense cluster is reachable.
        if (corpses.len() < 2) {
            if (isShield && (::Time.getRound() > 3 && myNearest <= 4)) return 0;
            local isRangedTarget = t.IsOccupiedByActor && t.getEntity().isArmedWithRangedWeapon();
            return 3.0 + 0.25 * hit + 0.20 * ::Math.min(3, enemiesNear) + (isRangedTarget ? 0.40 : 0.0);
        }
        return 0;
    }
    foreach (corpse in c.Behavior.targets(c, "Corpses")) if (corpse.getDistanceTo(t) <= 1) return 0;
    if (c.Origin.getDistanceTo(t) >= ::Const.Combat.DiversionMinDist && A.countNear(c.Allies, t) != 0) return 0;
    return 1.7 + A.weaponChance(s, t) + 0.35 * ::Math.min(4, A.countNear(c.Enemies, t));
});
A.add("pale_heavy_stomp", "Enemies", function(c, s, t) {
    local canStun = !t.getEntity().getCurrentProperties().IsImmuneToStun && !t.getEntity().getCurrentProperties().IsStunned;
    return A.weaponChance(s, t) * (3.2 + (canStun ? 1.2 : 0) + (A.countNear(c.Enemies, t) > 1 ? 1.15 : 0));
});
A.add("pale_rending_pounce", "Enemies", function(c, s, t) {
    local landing = s.getLanding(c.Origin, t);
    if (landing == null || !S.isSafeChampionStep(c.Behavior, c.Actor, landing, c.Origin, ::Math.max(1, A.zone(c.Actor, c.Origin)))) return 0;
    local hits = ::Math.min(4, s.getAttackCount(c.Actor));
    return A.weaponChance(s, t) * (2.2 + hits + (c.Origin.getDistanceTo(t) == 2 ? 1.0 : 0));
});
A.add("pale_arrow_rain", "Centers", function(c, s, t) {
    local value = 0.0;
    local count = 0;
    foreach (enemy in c.Enemies) if (enemy.getDistanceTo(t) <= 1) {
        value += 1.1 + A.weaponChance(s, enemy);
        ++count;
    }
    return count >= 2 ? value : 0;
});

S.Mod.hook("scripts/skills/actives/pale_corpse_shot", function(q) {
    q.onUse = @(__original) function(_user, _tile) {
        local ret = __original(_user, _tile);
        if (ret && S.Battle != null)
            S.Battle.CorpseShots = ("CorpseShots" in S.Battle ? S.Battle.CorpseShots : 0) + 1;
        return ret;
    };
});

S.Mod.hook("scripts/ai/tactical/behaviors/ai_engage_ranged", function(q) {
    q.m.PossibleSkills.push("actives.pale_weaken");
});

// Keep staff attacks from pulling the mentor past the units screening him.
local function advanceMult(actor, destination, enemy) {
    local origin = actor.getTile(), target = enemy.getTile();
    local distance = destination.getDistanceTo(target);
    if (origin.ID == destination.ID || distance >= origin.getDistanceTo(target) || distance > 3) return 1.0;
    foreach (nearby in ::std.Tile.iterAdjacent(destination)) {
        if (!nearby.IsOccupiedByActor || nearby.ID == origin.ID || nearby.getDistanceTo(target) >= distance) continue;
        if (nearby.getEntity().isAlliedWith(actor)) return 1.0;
    }
    if (distance <= 2) {
        foreach (nearby in ::std.Tile.iterAdjacent(origin)) {
            if (nearby.IsOccupiedByActor && nearby.getEntity().isAlliedWith(actor)
                && nearby.getDistanceTo(target) < origin.getDistanceTo(target)) return 0.0;
        }
    }
    return actor.getHitpointsPct() <= 0.55 ? 0.12 : 0.32;
}
S.Mod.hook("scripts/ai/autopilot_step_n_hit", function(q) {
    q.snh_scorePlan = @(__original) function(actor, enemy, skill, cost, tile) {
        local score = __original(actor, enemy, skill, cost, tile);
        return score > 0 && S.isChief(actor) ? score * advanceMult(actor, tile, enemy) : score;
    };
});
S.Mod.hook("scripts/ai/tactical/behaviors/ai_engage_melee", function(q) {
    q.evaluate = @(__original) function(actor) {
        if (this.m.Thread != null && this.m.Thread.getstatus() == "dead")
            this.m.Thread = null;
        local done;
        try { done = __original(actor); }
        catch (e) {
            // A target can disappear between native generator yields (getID), or an unreachable fortified cliff/palisade path
            // can return a null path end (IsEmpty). Always clear dead coroutines so the engine never loops on "resuming dead generator"!
            local threadDead = this.m.Thread != null && this.m.Thread.getstatus() == "dead";
            if (threadDead) {
                this.m.Thread = null;
                this.m.TargetTile = null;
                this.m.TargetActor = null;
                this.m.Score = 0;
            }
            if (threadDead && (e == "the index 'getID' does not exist"
                || e == "the index 'IsEmpty' does not exist"
                || e == "resuming dead generator"))
                return true;
            throw e;
        }
        if (done && this.m.Score > 0 && S.isChief(actor) && ::Autopilot.isUnderAIControl(actor)
            && this.m.TargetTile != null && !::MSU.isNull(this.m.TargetActor) && this.m.TargetActor.isAlive() && this.m.TargetActor.isPlacedOnMap())
            this.m.Score *= advanceMult(actor, this.m.TargetTile, this.m.TargetActor);
        return done;
    };
});
