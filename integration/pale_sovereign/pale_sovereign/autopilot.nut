local S = ::PaleSovereign, A = ::BGP.Autopilot;
local staffStrikeMult = 0.25;
local page = ::Autopilot.msu.ModSettings.getPage("背景与亡灵");
page.addElement(::MSU.Class.BooleanSetting("paleAutoChampion", true, "导师自动放出勇士", "第一回合召唤僵尸和骷髅，第二回合起放出饰品栏勇士并优先支配它。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoExtraSummon", false, "导师自动耗骸续召", "允许导师在每场免费召唤用完后消耗防腐尸骸续召僵尸和骷髅；关闭时每场默认各免费召唤 1 次。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoCorpseShot", true, "自动投掷防腐尸骸", "有尸骸储备时，可向敌群投掷尸弹。优先利用战场已有的尸体。"));
page.addRangeSetting("paleAutoCorpseShotLimit", 3, 0, 20, 1, "尸弹每场允许使用次数", "自动战斗中每场战斗最多允许投掷尸弹的次数（默认 3 次；0 表示自动战斗不投掷）。不影响手动操作。");
page.addElement(::MSU.Class.BooleanSetting("paleAutoChain", false, "自动使用缚魂锁链", "允许导师标记可吞魂的强敌，或用一条锁链复活可收编的亡灵强敌。"));

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
    // Prefer spawning summons/Lich on the front tile directly facing enemies so Mentor gets immediate ranged cover & melee screen.
    if (::Autopilot.conf("bgpSmartFrontline") && S.isChief(c.Actor) && distance < 99) {
        local originDist = A.nearest(c.Enemies, c.Origin);
        if (distance < originDist) coverBonus = 1.8;
    }
    return 4.7 - formationPenalty + coverBonus + (distance == 99 ? 0 : 1.4 / ::Math.maxf(1.0, distance))
        + 0.13 * (t.Level - c.Origin.Level) - (t.IsBadTerrain ? 0.32 : 0) - 0.45 * ::Math.max(0, zones - 1);
}
local function summon(c, s, t) {
    if (s.m.Used && !::Autopilot.conf("paleAutoExtraSummon")) return 0;
    local value = screen(c, s, t);
    if (value <= 0) return 0;
    if (S.isChief(c.Actor)) {
        if (::Autopilot.conf("bgpSmartFrontline")) {
            // Round 1: Lich King (3 AP) + Skeleton (4 AP); Round 2: Zombie (4 AP) so Mentor gets Lich Ward + cover immediately on Round 1.
            local bonus = s.getID() == "actives.pale_summon_skeleton" ? 18.0 : 17.0;
            if (::Time.getRound() <= 2) return value + bonus;
        } else if (::Time.getRound() <= 1) {
            return value + 18.0;
        }
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
        local pet = S.mainPet();
        if (S.isDeployed(pet, t.getEntity())) return 19.0;
        if (pet != null && ::Time.getRound() <= 2 && ::Autopilot.conf("paleAutoChampion") && !S.isDeployed(pet))
            return 0;
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
        // When no lethal snipe is available, prioritize marking dangerous high-HP bosses/elites as Prey (+10 hit / +20% dmg for all undead).
        if (enemy.getHitpointsMax() >= 130 || enemy.getSkills().hasSkill("racial.champion")
            || enemy.getArmor(::Const.BodyPart.Body) >= 180)
            value += 2.2;
    }
    // Guaranteed-hit direct-HP snipe bonus against ultra-high-MDef Geists/Banshees and Ancient Priests!
    if (enemy.ClassName == "ghost" || enemy.ClassName == "rf_banshee" || enemy.getSkills().hasSkill("actives.ghastly_touch"))
        value += 4.5;
    else if (enemy.getSkills().hasSkill("actives.miasma") || enemy.getSkills().hasSkill("actives.horror"))
        value += 3.0;
    return value + lethal;
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
        // Dedicated archers/crossbowmen, Mentor (who must summon/raise), engaged melee units, and heavily fatigued bros stick to their core roles.
        if (c.Actor.isArmedWithRangedWeapon() || S.isChief(c.Actor) || c.Engaged) return 0;
        if (c.Actor.getFatigue() > c.Actor.getFatigueMax() * 0.45) return 0;
        if (c.Origin.getDistanceTo(t) >= ::Const.Combat.DiversionMinDist && A.countNear(c.Allies, t) != 0) return 0;

        local corpses = c.Behavior.targets(c, "Corpses");
        foreach (corpse in corpses) if (corpse.getDistanceTo(t) <= 3) return 0;

        // Early corpse-seeding mode: when fewer than 2 corpses exist on the battlefield (especially vs kiting Goblins/Ancient Dead),
        // let a distant unengaged non-shield bro (e.g. Polearm or backline-adjacent bruiser >= 3 tiles away) seed 1-2 corpses
        // without stealing 2H melee strike turns (nearest <= 2) or Shieldbearer vanguard turns (nearest <= 4)!
        local enemiesNear = A.countNear(c.Enemies, t);
        local myNearest = A.nearest(c.Enemies, c.Origin);
        if (::BGP.hasShield(c.Actor) && myNearest <= 4) return 0;
        if (myNearest <= 2) return 0;
        if (corpses.len() < 2 && usedShots < ::Math.min(2, maxShots)) {
            if (::BGP.hasShield(c.Actor) && c.Actor.getFatigueMax() - c.Actor.getFatigue() < 36)
                return 0;
            local isRangedTarget = t.IsOccupiedByActor && t.getEntity().isArmedWithRangedWeapon();
            return 2.60 + 0.30 * A.weaponChance(s, t) + 0.25 * ::Math.min(3, enemiesNear) + (isRangedTarget ? 0.55 : 0.0);
        }

        return 0.70 + 0.15 * A.weaponChance(s, t) + 0.10 * ::Math.min(3, enemiesNear);
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
        local done;
        try { done = __original(actor); }
        catch (e) {
            // A target can disappear between native generator yields when a corpse changes sides.
            if (S.Battle == null || e != "the index 'getID' does not exist" || this.m.Thread == null
                || this.m.Thread.getstatus() != "dead") throw e;
            this.m.Thread = null;
            this.m.TargetTile = null;
            this.m.TargetActor = null;
            this.m.Score = 0;
            return true;
        }
        if (done && this.m.Score > 0 && S.isChief(actor) && ::Autopilot.isUnderAIControl(actor)
            && this.m.TargetTile != null && !::MSU.isNull(this.m.TargetActor) && this.m.TargetActor.isAlive() && this.m.TargetActor.isPlacedOnMap())
            this.m.Score *= advanceMult(actor, this.m.TargetTile, this.m.TargetActor);
        return done;
    };
});
