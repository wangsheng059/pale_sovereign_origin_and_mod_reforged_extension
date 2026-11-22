local S = ::PaleSovereign, A = ::BGP.Autopilot;
local page = ::Autopilot.msu.ModSettings.getPage("背景与亡灵");
page.addElement(::MSU.Class.BooleanSetting("paleAutoChampion", true, "导师自动放出冠军", "第一回合召唤僵尸和骷髅，第二回合起放出饰品栏冠军并优先支配它。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoCorpseShot", true, "自动投掷防腐尸骸", "有尸骸储备时，可向敌群投掷尸弹。优先利用战场已有的尸体。"));
page.addElement(::MSU.Class.BooleanSetting("paleAutoChain", false, "自动使用缚魂锁链", "允许导师标记可吞魂的强敌，或用一条锁链复活可收编的亡灵强敌。"));

local function screen(c, s, t) {
    if (c.Behavior.hasNegativeTileEffect(t, c.Actor)) return 0;
    local distance = A.nearest(c.Enemies, t);
    if (distance == 99 && ::Time.getRound() > 2 && !S.isChief(c.Actor)) return 0;
    local zones = A.zone(c.Actor, t);
    return 4.7 + (distance == 99 ? 0 : 1.4 / ::Math.maxf(1.0, distance))
        + 0.13 * (t.Level - c.Origin.Level) - (t.IsBadTerrain ? 0.32 : 0) - 0.45 * ::Math.max(0, zones - 1);
}
local function summon(c, s, t) {
    local value = screen(c, s, t);
    return value > 0 && S.isChief(c.Actor) && ::Time.getRound() <= 1 ? value + 18.0 : value;
}
A.add("pale_summon_zombie", "Adjacent", summon);
A.add("pale_summon_skeleton", "Adjacent", summon);
A.add("unleash_companion", "Adjacent", function(c, s, t) {
    if (!S.isChief(c.Actor) || !::Autopilot.conf("paleAutoChampion") || ::Time.getRound() < 2 || S.mainPet() == null) return 0;
    local value = screen(c, s, t);
    return value > 0 ? value + 18.0 : 0;
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
    return value * hit;
});
A.add("pale_weaken", "Enemies", function(c, s, t) {
    local enemy = t.getEntity();
    local value = 2.2 + (enemy.getSkills().hasSkill("effects.pale_weaken") ? 0 : 0.8);
    if (enemy.getHitpoints() <= 20) value += 1.8;
    else if (enemy.getMoraleState() == ::Const.MoraleState.Fleeing) value *= 0.6;
    if (s.m.Scourge) value += 0.85 * (A.countNear(c.Enemies, t) - 1);
    return value + 0.22 * ::Math.min(3, A.countNear(c.Allies, t, 2));
});
A.add("pale_soul_chain", "Enemies", @(c, s, t) ::Autopilot.conf("paleAutoChain") ? 8.5 + (t.getEntity().getSkills().hasSkill("racial.champion") ? 1 : 0) : 0);
A.add("pale_soul_bind", "Corpses", @(c, s, t) ::Autopilot.conf("paleAutoChain") ? 8.0 + A.corpseValue(t) : 0);
A.add("pale_corpse_shot", "Enemies", function(c, s, t) {
    if (!::Autopilot.conf("paleAutoCorpseShot") || ::BGP.Necro.getCorpse(t) != null || A.countNear(c.Enemies, t) < 2) return 0;
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
