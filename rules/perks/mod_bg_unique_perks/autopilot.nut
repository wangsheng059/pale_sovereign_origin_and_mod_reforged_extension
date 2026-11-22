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
local page = ::Autopilot.msu.ModSettings.addPage("背景与亡灵");
page.addElement(::MSU.Class.BooleanSetting("bgpAutoBind", false, "自动收服敌方亡灵", "有空位时用驱役亡灵收服合格的濒死敌人。我方仆从始终由你决定是否收回。"));

A.add("bgp_necro_raise", "Corpses", function(c, s, t) {
    local distance = A.nearest(c.Enemies, t);
    local pressure = A.zone(c.Actor, t);
    return (distance <= 2 ? 7.0 : distance <= 5 ? 5.9 : 3.2) + A.corpseValue(t)
        + (c.Engaged && c.Origin.getDistanceTo(t) <= 2 ? 0.9 : 0)
        - (pressure > 2 ? 0.65 : 0) - (c.Behavior.hasNegativeTileEffect(t, c.Actor) ? 1.1 : 0);
});
A.add("bgp_necro_eternal_command", "Corpses", @(c, s, t) 8.0);
A.add("bgp_corpse_explosion", "Corpses", function(c, s, t) {
    local blast = s.getBlast(::BGP.Necro.getCorpse(t), c.Actor);
    if (blast == null) return 0;
    local value = 0.0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1) continue;
        local enemy = tile.getEntity();
        value += 1.1 + ::Math.minf(1.8, (blast.Blunt + blast.Cutting * 0.45) / 35.0);
        if (enemy.getHitpoints() <= blast.Blunt * 0.65) value += 1.6;
    }
    return value;
});
A.add("bgp_necro_curse_of_ages", "Centers", function(c, s, t) {
    local value = 0.0;
    foreach (tile in c.Enemies) {
        if (tile.getDistanceTo(t) > 1 || tile.getEntity().getSkills().hasSkill("effects.bgp_curse_of_ages")) continue;
        value += 1.45 + ::Math.minf(0.9, tile.getEntity().getHitpointsMax() / 140.0);
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
        local skills = this.getSkills();
        local eligible = skills.getSkillsByFunction(@(s) s.getID() in A.Actions
            && (s.getID() != "actives.possess_undead" || s.ClassName == "bgp_necro_possess_skill")
            && s.getID() != "actives.unleash_companion");
        if (eligible.len() == 0) return;
        local agent = this.getAIAgent();
        agent.addBehavior(::new("scripts/ai/bgp_autopilot_tactics"));
        local possess = skills.getSkillByID("actives.possess_undead");
        if (possess != null && possess.ClassName == "bgp_necro_possess_skill")
            agent.removeBehavior(::Const.AI.Behavior.ID.PossessUndead);
        if (skills.hasSkill("actives.bgp_necro_raise")) {
            if (agent.getBehavior(::Const.AI.Behavior.ID.EngageRanged) == null)
                agent.addBehavior(::new("scripts/ai/tactical/behaviors/ai_engage_ranged"));
            agent.removeBehavior(::Const.AI.Behavior.ID.Protect);
            local weights = "autopilot_mults" in agent ? agent.autopilot_mults : agent.m.Properties.BehaviorMult;
            weights[::Const.AI.Behavior.ID.EngageMelee] = 0.18;
            weights[::Const.AI.Behavior.ID.Disengage] = 2.0;
        }
        agent.finalizeBehaviors();
    };
});
