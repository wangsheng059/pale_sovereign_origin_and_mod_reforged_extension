local S = ::PaleSovereign;
::MSU.AI.addBehavior("PaleFormation", "Pale.Formation", ::Const.AI.Behavior.Order.EngageMelee, ::Const.AI.Behavior.Score.Attack);
// Run Champion Rotation BEFORE Shieldwall & Attacks so Lich King never cancels a freshly raised Shieldwall by rotating afterwards.
::MSU.AI.addBehavior("PaleChampionRotation", "Pale.ChampionRotation", 20, ::Const.AI.Behavior.Score.Attack);

S.isFormationUndead <- function(actor)
{
    return this.Battle != null && !::MSU.isNull(actor) && actor.getFaction() == ::Const.Faction.PlayerAnimals
        && actor.isAlive() && !actor.isDying() && actor.isPlacedOnMap() && !actor.isPlayerControlled()
        && (actor.getFlags().has("PaleFormationSummon") || this.isChampionAI(actor));
};

S.fieldBrothers <- function()
{
    return ::World.getPlayerRoster().getAll().filter(@(_, b) b.getFaction() == ::Const.Faction.Player
        && b.isAlive() && !b.isDying() && b.isPlacedOnMap());
};

S.markFormationContact <- function(tile)
{
    this.Battle.CompanyContact = true;
    this.Battle.ContactTile <- tile;
};

S.enemyBesideBrother <- function(bro, tile)
{
    foreach (nearby in this.area(tile)) {
        if (nearby.ID == tile.ID || !nearby.IsOccupiedByActor || ::Math.abs(nearby.Level - tile.Level) > 1) continue;
        local foe = nearby.getEntity();
        if (!foe.isAlliedWith(bro) && foe.isAlive() && !foe.isDying() && foe.isAttackable()) return nearby;
    }
    return null;
};

S.noteFormationContact <- function(actor, tile)
{
    if (this.Battle == null || this.Battle.CompanyContact || tile == null || !actor.isAlive() || actor.isDying()) return;
    local player = ::Const.Faction.Player;
    if (actor.getFaction() != player && actor.isAlliedWith(player)) return;
    local brothers = this.fieldBrothers();
    if (actor.getFaction() == player) {
        foreach (bro in brothers) if (bro.getID() == actor.getID()) {
            local contact = this.enemyBesideBrother(bro, tile);
            if (contact != null) this.markFormationContact(contact);
            return;
        }
    } else if (actor.isAttackable()) {
        foreach (bro in brothers) {
            local at = bro.getTile();
            if (tile.getDistanceTo(at) == 1 && ::Math.abs(at.Level - tile.Level) <= 1) {
                this.markFormationContact(tile);
                return;
            }
        }
    }
};

S.Mod.hook("scripts/entity/tactical/actor", function(q) {
    q.onMovementStep = @(__original) function(tile, levelDifference) {
        local ret = __original(tile, levelDifference);
        if (ret) S.noteFormationContact(this, tile);
        return ret;
    };
    q.onMovementFinish = @(__original) function(tile) {
        local ret = __original(tile);
        if (this.isPlacedOnMap()) S.noteFormationContact(this, this.getTile());
        return ret;
    };
});
S.Mod.hook("scripts/skills/skill", function(q) {
    q.MV_onAttackRolled = @(__original) function(info) {
        if (S.Battle != null && !S.Battle.CompanyContact && this.isAttack() && !this.isRanged()
            && info.User != null && info.Target != null && info.User.isPlacedOnMap() && info.Target.isPlacedOnMap()
            && !info.User.isAlliedWith(info.Target) && info.User.getTile().getDistanceTo(info.Target.getTile()) <= 2) {
            local player = info.User.getFaction() == ::Const.Faction.Player ? info.User : info.Target;
            if (player.getFaction() == ::Const.Faction.Player) {
                foreach (bro in S.fieldBrothers()) if (bro.getID() == player.getID()) { S.markFormationContact(info.Target.getTile()); break; }
            }
        }
        return __original(info);
    };
});

// The largest local group sets the line. A lone scout does not drag the escort out of formation.
S.formationGroup <- function(brothers)
{
    local anchor = null, bestCount = 0, bestTotal = 100000;
    foreach (bro in brothers) {
        local tile = bro.getTile(), count = 0, total = 0;
        foreach (other in brothers) {
            local d = tile.getDistanceTo(other.getTile());
            if (d <= 3) ++count;
            total += d;
        }
        if (count > bestCount || (count == bestCount && total < bestTotal)) {
            anchor = tile; bestCount = count; bestTotal = total;
        }
    }
    local tiles = [];
    foreach (bro in brothers) if (anchor.getDistanceTo(bro.getTile()) <= 3) tiles.push(bro.getTile());
    return { Anchor = anchor, Tiles = tiles };
};

S.formationThreats <- function(agent, group)
{
    local threats = [];
    foreach (entry in agent.getKnownOpponents()) {
        local foe = entry.Actor;
        if (::MSU.isNull(foe) || !foe.isAlive() || foe.isDying() || !foe.isPlacedOnMap() || !foe.isAttackable()
            || foe.isAlliedWith(agent.getActor()) || foe.isHiddenToPlayer() || !foe.getTile().IsVisibleForPlayer) continue;
        local at = foe.getTile(), front = 99;
        foreach (tile in group.Tiles) front = ::Math.min(front, tile.getDistanceTo(at));
        threats.push({ Tile = at, Front = front });
    }
    return threats;
};

S.formationLead <- function(tile, threats)
{
    local lead = 0;
    foreach (enemy in threats) lead = ::Math.max(lead, enemy.Front - tile.getDistanceTo(enemy.Tile));
    return lead;
};

S.Mod.hook("scripts/ai/tactical/agent", function(q) {
    q.onTurnStarted = @(__original) function() {
        local actor = this.getActor();
        local added = false;
        if (S.isFormationUndead(actor) && this.getBehavior(::Const.AI.Behavior.ID.PaleFormation) == null) {
            this.addBehavior(::new("scripts/ai/pale_formation_move"));
            added = true;
        }
        if (S.isChampionAI(actor) && actor.getSkills().hasSkill("actives.rotation")
            && this.getBehavior(::Const.AI.Behavior.ID.PaleChampionRotation) == null) {
            this.addBehavior(::new("scripts/ai/pale_champion_rotation"));
            added = true;
        }
        if (added) this.finalizeBehaviors();
        return __original();
    };
    q.sortBehaviors = @(__original) function() {
        local actor = this.getActor();
        if (S.isFormationUndead(actor) && !S.Battle.CompanyContact && actor.isPlacedOnMap()
            && actor.getMoraleState() != ::Const.MoraleState.Fleeing && !::Tactical.State.isAutoRetreat()) {
            foreach (bro in S.fieldBrothers()) {
                local contact = S.enemyBesideBrother(bro, bro.getTile());
                if (contact != null) { S.markFormationContact(contact); break; }
            }
            if (!S.Battle.CompanyContact && this.getBehavior(::Const.AI.Behavior.ID.PaleFormation) != null) {
                foreach (b in this.m.Behaviors) {
                    if (b.getScore() <= 0) continue;
                    switch (b.ClassName) {
                        case "pale_formation_move": case "pale_champion_rotation": case "ai_idle": case "ai_break_free": case "ai_recover":
                        case "ai_defend_shieldwall": case "ai_defend_spearwall": case "ai_defend_riposte":
                        case "ai_attack_bow": case "ai_attack_crossbow": case "ai_attack_handgonne": continue;
                        case "ai_attack_default":
                            if (b.m.Skill != null && b.m.TargetTile != null && (b.m.Skill.isRanged()
                                || actor.getTile().getDistanceTo(b.m.TargetTile) == 1)) continue;
                    }
                    b.m.Score = 0;
                }
            }
        }
        return __original();
    };
});

// Smart Shieldwall discipline for Lich King & summoned/raised shield skeletons:
// Healthy Lich King facing only 1 regular enemy swings TWICE instead of wasting 4 AP on Shieldwall;
// rooted undead with no melee adjacent break free FIRST instead of wasting 4 AP on Shieldwall.
S.Mod.hook("scripts/ai/tactical/behaviors/ai_defend_shieldwall", function(q) {
    q.onEvaluate = @(__original) function(_entity) {
        if (::Autopilot.conf("bgpSmartFrontline") && _entity.getFaction() == ::Const.Faction.PlayerAnimals
            && (S.isChampionAI(_entity) || S.isRaisedFighter(_entity) || S.isFormationUndead(_entity))) {
            local F = ::BGP.Autopilot.Frontline;
            local enemies = F.collectEnemies(_entity, this.getAgent());
            local meleeAdj = F.countDangerousMeleeAdjacent(_entity, enemies);
            if (_entity.getCurrentProperties().IsRooted && meleeAdj == 0)
                return ::Const.AI.Behavior.Score.Zero;
            local hpPct = _entity.getHitpointsPct();
            local isChamp = S.isChampionAI(_entity);
            local heavyAdj = F.hasHeavyMeleeAdjacent(_entity, enemies);
            if (meleeAdj == 0) {
                local within2 = F.countDangerousMeleeWithin(_entity, enemies, 2);
                if (within2 < 2) return ::Const.AI.Behavior.Score.Zero;
            } else if (meleeAdj == 1) {
                // Single melee enemy: only Shieldwall when wounded or facing a heavy 2H boss while hurt; otherwise swing twice!
                local need = isChamp ? (hpPct <= 0.55 || (heavyAdj && hpPct <= 0.75)) : (hpPct <= 0.45);
                if (!need) return ::Const.AI.Behavior.Score.Zero;
            }
        }
        return __original(_entity);
    };
});

// Suppress vanilla ai_defend_rotation on Lich King when smart AI is enabled so ONLY our Shieldwall-safe PaleChampionRotation controls Lich King's Rotation.
// Note: ai_defend_rotation.onEvaluate is a Squirrel generator (uses yield), so we MUST hook evaluate(), NOT onEvaluate().
S.Mod.hook("scripts/ai/tactical/behaviors/ai_defend_rotation", function(q) {
    q.evaluate = @(__original) function(_entity) {
        if (::Autopilot.conf("bgpSmartFrontline") && S.isChampionAI(_entity)) {
            this.m.Thread = null;
            this.m.TargetTile = null;
            this.m.Score = 0;
            return true;
        }
        return __original(_entity);
    };
});
