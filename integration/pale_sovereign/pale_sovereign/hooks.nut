local S = ::PaleSovereign;
local mod = S.Mod;

::BGP.hookExclusive(S.ChiefScript, ["pg.bgp_necro_champion", "pg.bgp_necro_scourge"]);

foreach (id in ::BGP.Necro.ChampionPerks)
{
    local perk = ::Const.Perks.findById(id);
    local original = perk.verifyPrerequisites;
    perk.verifyPrerequisites = function( _bro, _tooltip )
    {
        if (::PaleSovereign.isChief(_bro) && ::PaleSovereign.oath() == ::PaleSovereign.Oath.Scourge)
        {
            _tooltip.push({ id = 3, type = "hint", icon = "ui/icons/icon_locked.png", text = "誓约已定：本战役已立下亡灵天灾誓约。" });
            return false;
        }
        return original(_bro, _tooltip);
    };
}
foreach (id in ::BGP.Necro.ScourgePerks)
{
    local perk = ::Const.Perks.findById(id);
    local original = perk.verifyPrerequisites;
    perk.verifyPrerequisites = function( _bro, _tooltip )
    {
        if (::PaleSovereign.isChief(_bro) && ::PaleSovereign.oath() == ::PaleSovereign.Oath.Champion)
        {
            _tooltip.push({ id = 3, type = "hint", icon = "ui/icons/icon_locked.png", text = "誓约已定：本战役已立下亡灵勇士誓约。" });
            return false;
        }
        return original(_bro, _tooltip);
    };
}

local oldCanRaiseAll = ::BGP.Necro.canRaiseAll;
::BGP.Necro.canRaiseAll = function( _actor )
{
    return S.isChief(_actor) || oldCanRaiseAll(_actor);
};

// Enable temporary combat injuries for permanent undead using Reforged's undead exclusion lists.
S.ensureUndeadInjurySupport <- function( _actor )
{
    if (_actor == null || ::MSU.isNull(_actor))
        return;
    local bg = null;
    try { bg = _actor.getBackground(); } catch (e) { bg = null; }
    if (!this.isUndead(_actor) && (bg == null || !::isKindOf(bg, "pale_undead_background")))
        return;
    try
    {
        local b = _actor.getBaseProperties();
        b.IsAffectedByInjuries = true;
        b.IsAffectedByFreshInjuries = true;
        local skills = _actor.getSkills();
        local receiver = skills.getSkillByID("special.rf_undead_injury_receiver");
        if (receiver == null)
        {
            receiver = ::new("scripts/skills/special/rf_undead_injury_receiver");
            skills.add(receiver);
        }
        receiver.m.ThresholdToReceiveInjuryMult = 1.0;

        if ("ExcludedInjuries" in ::Const.Injury && "RF_Undead" in ::Const.Injury.ExcludedInjuries)
        {
            local isSkel = _actor.getFlags().has("skeleton");
            if (!isSkel && bg != null)
            {
                try { isSkel = bg.m.PaleSkeleton == true; } catch (e) {}
            }
            local listId = isSkel ? ::Const.Injury.ExcludedInjuries.RF_Skeleton : ::Const.Injury.ExcludedInjuries.RF_Undead;
            foreach (inj in ::Const.Injury.ExcludedInjuries.get(listId))
            {
                if (_actor.m.ExcludedInjuries.find(inj) == null)
                    _actor.m.ExcludedInjuries.push(inj);
            }
        }
    }
    catch (e)
    {
        ::logError("[PaleSovereign] ensureUndeadInjurySupport: " + e);
    }
};

local oldEquip = ::BGP.NecroPet.canEquip;
::BGP.NecroPet.canEquip = function( _actor, _item )
{
    return oldEquip(_actor, _item);
};


local oldScale = ::BGP.NecroPet.applyScaling;
::BGP.NecroPet.applyScaling = function( _entity )
{
    local item = _entity.m.Item;
    if (typeof item == "instance" && !::MSU.isNull(item))
        item = item.get();
    // 旧存档的尸妖王先补属性，再由原逻辑写进实体
    if (S.isActive() && S.isCoffin(item))
        S.upgradeLich(item);
    oldScale(_entity);
    if (!S.isActive() || !S.isCoffin(item))
        return;
    local chief = S.chief();
    if (chief == null || !::MSU.isEqual(S.mainPet(), item))
        return;
    S.petID(item);
    if (S.isTameEliteScript(::BGP.NecroPet.TypeDefs[item.getType()].Pet))
        S.petSet(item, "Elite", 1);
    ::BGP.Champion.promotePet(_entity, chief);
    ::BGP.Necro.copySocket(chief, _entity);
    ::BGP.Necro.markMinion(chief, _entity);
    S.applyPetProgress(item, _entity);
    if (S.petGet(item, "Gilded") != 0 && "gildArmor" in S)
        S.gildArmor(_entity);
    S.addBattleBoons(_entity);
    if (S.followerRank("wight_captain") >= 3 && ::Time.getRound() <= 5
        && !_entity.getSkills().hasSkill("effects.pale_wight_order"))
        _entity.getSkills().add(::new(S.SkillDir + "effects/pale_wight_order_effect"));
    if (S.ambitionDone("immortal_guard") && !_entity.getSkills().hasSkill("effects.pale_guard_shield"))
        _entity.getSkills().add(::new(S.SkillDir + "effects/pale_guard_shield"));
    if (S.isLich(item))
        S.applyLichSkills(_entity, chief);
};

local oldFly = ::BGP.Necro.isFlySwarmMinion;
::BGP.Necro.isFlySwarmMinion = function( _actor )
{
    if (S.Battle != null && S.isUndead(_actor))
    {
        local chief = S.chief();
        return chief != null && chief.isAlive() && chief.getSkills().hasSkill(::BGP.Necro.FlySwarmPerk);
    }
    return oldFly(_actor);
};

local oldRaise = ::BGP.Necro.raise;
::BGP.Necro.raise = function( _actor, _tile )
{
    local entity = oldRaise(_actor, _tile);
    if (entity != null && S.Battle != null)
    {
        entity.getFlags().set("PaleRaised", true);
        if (_actor != null && _actor.isPlayerControlled())
            S.addBattleBoons(entity);
        if (S.isAscended() && S.oath() == S.Oath.Scourge && _actor != null && _actor.isPlayerControlled()
            && !entity.getSkills().hasSkill("effects.pale_dominion"))
            entity.getSkills().add(::new(S.SkillDir + "effects/pale_dominion_effect"));
    }
    return entity;
};

mod.hook("scripts/ui/global/data_helper", function(q)
{
    q.convertAssetsInformationToUIData = @(__original) function()
    {
        local data = __original();
        if (data != null)
            data.PaleCampVisible <- S.isActive();
        return data;
    };

    q.convertEntityToUIData = @(__original) function( _entity, _activeEntity )
    {
        local data = __original(_entity, _activeEntity);
        if (data != null && S.isChief(_entity) && S.isActive())
            data.PaleOath <- S.oath();
        return data;
    };
});

mod.hook("scripts/ui/screens/character/character_screen", function(q)
{
    q.onDismissCharacter = @(__original) function( _data )
    {
        local bro = ::Tactical.getEntityByID(_data[0]);
        if (S.isActive() && S.isChief(bro))
            return null;
        return __original(_data);
    };
});

mod.hook("scripts/entity/tactical/player", function(q)
{
    q.unlockPerk = @(__original) function( _id )
    {
        if (!S.isActive() || !S.isChief(this))
            return __original(_id);
        local route = S.perkRoute(_id);
        if (route == S.Oath.None)
            return __original(_id);
        if (S.oath() != S.Oath.None && S.oath() != route)
            return false;
        if (this.hasPerk(_id))
            return true;
        if (this.getPerkPoints() == 0 || !this.isPerkUnlockable(_id))
            return false;
        local ok = __original(_id);
        if (ok && S.oath() == S.Oath.None)
        {
            S.set("Oath", route);
            S.applyRosterLimits();
            S.set("OathNotice", 1);
        }
        return ok;
    };

    q.isReallyKilled = @(__original) function( _fatality )
    {
        return S.isChief(this) || __original(_fatality);
    };

    q.getDailyCost = @(__original) function()
    {
        return S.isUndead(this) ? 0 : __original();
    };

    q.getDailyFood = @(__original) function()
    {
        return S.isUndead(this) ? 0 : __original();
    };

    q.setHitpoints = @(__original) function( _hp )
    {
        if (S.BlockWorldHealing && S.isUndead(this) && _hp > this.getHitpoints())
            return;
        __original(_hp);
    };

    q.recoverMood = @(__original) function()
    {
        if (!S.isUndead(this))
            return __original();
    };

    q.improveMood = @(__original) function( _value = 1.0, _reason = "" )
    {
        if (!S.isUndead(this))
            return __original(_value, _reason);
    };

    q.worsenMood = @(__original) function( _value = 1.0, _reason = "" )
    {
        if (!S.isUndead(this))
            return __original(_value, _reason);
    };

    q.setMoraleState = @(__original) function( _state )
    {
        if (!S.isUndead(this))
            return __original(_state);
        this.m.MoraleState = ::Const.MoraleState.Ignore;
    };

    q.onDeserialize = @(__original) function( ... )
    {
        local args = [this];
        args.extend(vargv);
        __original.acall(args);
        if (S.isChief(this) && this.getTitle() == "亡者之主")
            S.nameChief(this);
        if (S.isUndead(this))
        {
            this.m.MoraleState = ::Const.MoraleState.Ignore;
            S.restoreTierSkills(this);
            S.applyUndeadLook(this);
            S.ensureUndeadInjurySupport(this);
        }
    };

    q.onUpdateInjuryLayer = @(__original) function()
    {
        if (!::BGP.NecroPet.IsLoading && S.isUndead(this))
            S.applyUndeadLook(this);
        else
            __original();
    };
});

S.PartyFigure <- "figure_necromancer_01";
S.applyPartyLook <- function()
{
    if (!this.isActive() || !("State" in ::World) || ::World.State == null)
        return;
    local player = ::World.State.getPlayer();
    if (player == null || ::MSU.isNull(player))
        return;
    try
    {
        local body = player.getSprite("body");
        body.setBrush(this.PartyFigure);
        body.setHorizontalFlipping(true);
    }
    catch (e) { ::logWarning("[PaleSovereign] party look: " + e); }
};

S.BlockWorldHealing <- false;
mod.hook("scripts/states/world/asset_manager", function(q)
{
    q.updateLook = @(__original) function( ... )
    {
        local args = [this];
        args.extend(vargv);
        local ret = __original.acall(args);
        S.applyPartyLook();
        return ret;
    };

    q.update = @(__original) function( _state )
    {
        if (!S.isActive())
            return __original(_state);
        local dayBefore = this.m.LastDayPaid;
        S.BlockWorldHealing = true;
        local recovery = this.m.HitpointsPerHourMult;
        if (S.followerRank("blood_steward") > 0)
            this.m.HitpointsPerHourMult *= 1.50;
        try { __original(_state); }
        catch (e)
        {
            this.m.HitpointsPerHourMult = recovery;
            S.BlockWorldHealing = false;
            throw e;
        }
        this.m.HitpointsPerHourMult = recovery;
        S.BlockWorldHealing = false;
        if (this.m.LastDayPaid != dayBefore)
        {
            S.castleDaily();
            S.conquestDay();
            foreach (hook in S.DailyHooks)
            {
                try { hook.call(S); } catch (e) { ::logError("[PaleSovereign] daily hook: " + e); }
            }
        }

        if (this.m.LastDayPaid != dayBefore && S.get("StenchUntil") > S.worldHours())
            foreach (bro in S.humans())
                S.undeadMood(bro, 0.35, "受不了缝合台的气味");

        local now = ::World.getTime().Days + ::World.getTime().Hours / 24.0;
        foreach (key in ["RitualUntil", "WhispersUntil", "RefineWeakUntil"])
        {
            local ends = ::World.Flags.getAsFloat("Pale." + key);
            if (ends > 0 && now >= ends)
            {
                S.set(key, 0);
                local chief = S.chief();
                if (chief != null)
                    chief.getSkills().update();
            }
        }
    };
});

mod.hook("scripts/entity/world/player_party", function(q)
{
    q.getVisionRadius = @(__original) function()
    {
        local radius = __original();
        if (!S.isActive() || ::World.getTime().IsDaytime)
            return radius;
        radius *= S.followerRank("banshee") >= 2 ? 1.5 : 1.0;
        local mult = ::World.getGlobalVisibilityMult();
        return mult > 0 && mult < 1.0 ? radius * ((1.0 + mult) * 0.5) / mult : radius;
    };
});

mod.hook("scripts/items/item_container", function(q)
{
    q.equip = @(__original) function( _item )
    {
        local tame = S.TameStash;
        if (tame != null && _item != null && tame.Item == null && this.m.Actor != null && !::MSU.isNull(this.m.Actor)
            && this.m.Actor.getID() == tame.Actor.getID() && ("getType" in _item) && ("setType" in _item)
            && this.getItemAtSlot(::Const.ItemSlot.Accessory) != null && ::World.Assets.getStash().hasEmptySlot())
        {
            ::World.Assets.getStash().add(_item);
            tame.Item = _item;
            return true;
        }
        if (!::BGP.NecroPet.IsLoading && _item != null && _item.getID().find("weapon.pale_staff") == 0)
        {
            local actor = this.m.Actor;
            if (actor != null && !::MSU.isNull(actor))
            {
                local background = actor.getSkills().getSkillByID(S.Chief);
                if (background == null)
                    return false;
            }
        }
        return __original(_item);
    };
});

mod.hook("scripts/ui/screens/world/modules/world_town_screen/town_shop_dialog_module", function(q)
{
    q.onSwapItem = @(__original) function( _data )
    {
        if (_data[1] == "world-town-screen-shop-dialog-module.stash" && _data[3] != null && _data[3] != _data[1])
        {
            local entry = ::World.Assets.getStash().getItemAtIndex(_data[0]);
            local item = entry != null && typeof entry == "table" && "item" in entry ? entry.item : entry;
            if (item != null && item.getID().find("weapon.pale_staff") == 0)
                return { Result = 1 };
        }
        return __original(_data);
    };
});

mod.hook("scripts/ui/screens/world/modules/topbar/world_screen_topbar_options_module", function(q)
{
    q.onPaleCampButtonPressed <- function()
    {
        if (!S.isActive() || S.chief() == null)
            return false;
        S.clearStaleBattle();
        if (S.Battle != null)
            return false;
        if (S.openEvent("camp", true))
        {
            S.PendingCampUntil = 0;
            return true;
        }
        if (S.canQueueManualCamp())
        {
            S.PendingCampUntil = ::Time.getRealTimeF() + 1.5;
            return true;
        }
        return false;
    };
});

mod.hook("scripts/states/world_state", function(q)
{
    q.onUpdate = @(__original) function()
    {
        __original();
        if (S.isActive() && this.getPlayer() != null && !::MSU.isNull(this.getPlayer()))
        {
            S.clearStaleBattle();
            if (S.Battle == null)
            {
                S.tryOpenPendingCamp();
                S.worldEvent();
            }
        }
    };

    q.getLocalCombatProperties = @(__original) function( _pos, _ignoreNoEnemies = false )
    {
        local properties = __original(_pos, _ignoreNoEnemies);
        if (properties != null && S.isActive())
            properties.PaleNight <- !::World.getTime().IsDaytime;
        return properties;
    };

    q.onCombatFinished = @(__original) function()
    {
        local result = __original();
        if (S.isActive())
        {
            if (S.get("FightingPet") != 0 && S.mainPet() == null)
                S.set("LostChampion", 1);
            S.set("FightingPet", 0);
            S.Battle = null;
        }
        return result;
    };

    q.onDeserialize = @(__original) function( ... )
    {
        local args = [this];
        args.extend(vargv);
        local ret = __original.acall(args);
        S.applyPartyLook();
        if (S.isActive())
        {
            S.applyRosterLimits();
            S.refreshUndeadLore();
            if ("repairSoulboundRoster" in S)
                S.repairSoulboundRoster();
            if ("ensureUndeadPerkGroups" in S)
                S.ensureUndeadPerkGroups();
        }
        return ret;
    };

    q.loadCampaign = @(__original) function( _file )
    {
        S.Battle = null;
        S.NextWorldCheck = 0;
        S.PendingCampUntil = 0;
        S.CastlePage = null;
        local result = __original(_file);
        if (this.m.WorldScreen != null)
            this.m.WorldScreen.updateAssetsInformation();
        return result;
    };
});

mod.hook("scripts/states/tactical_state", function(q)
{
    q.setStrategicProperties = @(__original) function( _properties )
    {
        local ret = __original(_properties);
        if (S.isActive() && _properties != null)
        {
            S.beginBattle("PaleNight" in _properties ? _properties.PaleNight : !::World.getTime().IsDaytime);
            S.Battle.SiegeFight = ["Stronghold", "ConquestSiege", "ConquestAssault"].find(_properties.CombatID) != null;
            local pet = S.mainPet();
            S.set("FightingPet", pet == null ? 0 : S.petID(pet));
        }
        return ret;
    };
});

mod.hookTree("scripts/entity/world/location", function(q)
{
    q.onBeforeCombatStarted = @(__original) function()
    {
        __original();
        if (S.isActive() && this.isAlive() && S.oath() == S.Oath.Champion)
            S.populateEliteLead(this);
    };

    q.onCombatLost = @(__original) function()
    {
        // 1.6.8 攻破亡灵营地：仓库里得到一具受缚亡灵
        if (S.Battle != null && !S.Battle.UndeadCampLooted && this.isAlive() && this.getTroops().len() == 0
            && ::World.Statistics.getFlags().getAsInt("LastCombatResult") == 1 && S.isUndeadCamp(this))
        {
            S.Battle.UndeadCampLooted = true;
            S.pendingItem("misc/pale_bound_undead_item");
        }
        if (S.Battle != null && S.isAncientSite(this) && this.isAlive() && this.getTroops().len() == 0
            && ::World.Statistics.getFlags().getAsInt("LastCombatResult") == 1)
        {
            S.registerSite(this.getTile(), 1, this.getName(), 4, true);
            if (!S.Battle.AncientCleared)
            {
                S.Battle.AncientCleared = true;
                S.set("AncientRuinWins", S.get("AncientRuinWins") + 1);
                if (S.followerRank("gravekeeper") >= 3)
                    S.pendingItem(::Math.rand(0, 1) == 0 ? "weapons/ancient/ancient_sword" : "loot/ancient_gold_coins_item");
            }
        }
        if (S.Battle != null && ::World.Statistics.getFlags().getAsInt("LastCombatResult") == 1)
            S.recordLegend(this);
        return __original();
    };
});

mod.hook("scripts/entity/world/locations/battlefield_location", function(q)
{
    q.onSpawned = @(__original) function()
    {
        __original();
        if (S.Battle != null && ::World.Statistics.getFlags().getAsInt("LastCombatResult") == 1)
            S.registerSite(this.getTile(), 2, this.getName(), S.Battle.Uncollected, true);
    };
});

mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.kill = @(__original) function( _killer = null, _skill = null, _fatality = ::Const.FatalityType.None, _silent = false )
    {
        local battle = S.Battle;
        if (battle == null || !this.isAlive() || this.isDying() || !this.isPlacedOnMap())
            return __original(_killer, _skill, _fatality, _silent);
        local former = battle.Death;
        local chief = S.chief();
        battle.Death = {
            Eligible = chief != null && !this.isAlliedWith(chief) && this.getFaction() != ::Const.Faction.PlayerAnimals
                && !this.getFlags().has("PaleRaised"),
            ID = this.getID(),
            FormationSummon = this.getFlags().has("PaleFormationSummon"),
            Info = ::BGP.Necro.makeDeathInfo(this),
            Fatality = _fatality
        };
        if (battle.Death.Eligible)
        {
            local fileName = S.scriptBase(battle.Death.Info.Script);
            battle.Death.Champion <- this.getSkills().hasSkill("racial.champion");
            battle.Death.Human <- battle.Death.Info.IsHuman;
            if (battle.Death.Champion)
                ++battle.Champions;
            if (fileName == "trickster_god")
                S.markLegend("Hunt");
        }
        try
        {
            local result = __original(_killer, _skill, _fatality, _silent);
            local governor = battle.Governor;
            if (governor != null && governor.EntityID == battle.Death.ID && !this.isAlive())
                governor.Died = true;
            local eligible = battle.Death.Eligible;
            local champion = "Champion" in battle.Death && battle.Death.Champion;
            local human = "Human" in battle.Death && battle.Death.Human;
            battle.Death = former;
            if (eligible && (!this.isAlive() || this.isDying()))
            {
                ++battle.DefenseDead;
                S.followerOnKill(_killer);
                if (champion)
                    S.followerChampionKill(_killer);
                if (human)
                    ++battle.HumanKills;
            }
            return result;
        }
        catch (e)
        {
            battle.Death = former;
            throw e;
        }
    };
});

mod.hook("scripts/entity/tactical/tactical_entity_manager", function(q)
{
    q.spawn = @(__original) function( _properties )
    {
        local result = __original(_properties);
        if (S.Battle != null)
        {
            S.Battle.UndeadDeployed = this.getInstancesOfFaction(::Const.Faction.Player)
                .filter(@(_, actor) actor.isPlacedOnMap() && S.isUndead(actor)).len();
        }
        return result;
    };

    q.addCorpse = @(__original) function( _tile )
    {
        local result = __original(_tile);
        if (S.Battle != null && S.Battle.Death != null) {
            local corpse = _tile.Properties.get("Corpse");
            if (corpse != null && S.Battle.Death.FormationSummon) corpse.PaleFormationSummon <- true;
            S.recordCorpse(corpse);
        }
        return result;
    };

    q.removeCorpse = @(__original) function( _tile )
    {
        local ret = __original(_tile);
        if (S.Battle != null && _tile.ID in S.Battle.QueuedShots)
            ::Time.scheduleEvent(::TimeUnit.Virtual, 1, @(_target) S.flushShot(_target), _tile);
        return ret;
    };

    q.onResurrect = @(__original) function( _corpse, _force = false )
    {
        local actor = __original(_corpse, _force);
        if (actor != null && S.Battle != null) {
            actor.getFlags().set("PaleRaised", true);
            if (_corpse != null && "PaleFormationSummon" in _corpse && actor.getFaction() == ::Const.Faction.PlayerAnimals)
                actor.getFlags().set("PaleFormationSummon", true);
        }
        return actor;
    };
});

// 1.6.15：复活技能拉起来的敌方遗骸战后照样计入防腐尸骸（原尸体被复活消耗掉，地上已经没有）
if ("Necro" in ::BGP && "raise" in ::BGP.Necro)
{
    local raise = ::BGP.Necro.raise;
    ::BGP.Necro.raise = function( _user, _tile )
    {
        local counted = false, formationSummon = false;
        if (S.Battle != null && S.isActive())
        {
            try
            {
                local corpse = ::BGP.Necro.getCorpse(_tile);
                formationSummon = corpse != null && "PaleFormationSummon" in corpse;
                counted = corpse != null && typeof corpse == "table" && !::BGP.Necro.isGuardCorpse(corpse)
                    && S.harvestReject(corpse) == null;
            }
            catch (e) { counted = false; }
        }
        local unit = raise(_user, _tile);
        if (unit != null && formationSummon) unit.getFlags().set("PaleFormationSummon", true);
        if (unit != null && counted && S.Battle != null)
            ++S.Battle.RaisedHarvest;
        return unit;
    };
}

mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.Battle != null && actor.isPlayerControlled())
        {
            if (S.isChief(actor) || S.isUndead(actor))
                S.addBattleBoons(actor);
            if (S.oath() == S.Oath.Scourge && !this.hasSkill("actives.pale_corpse_shot"))
                this.add(::new(S.SkillDir + "actives/pale_corpse_shot"));
            if (S.isUndead(actor))
            {
                actor.m.MoraleState = ::Const.MoraleState.Ignore;
                S.applyUndeadLook(actor);
            }
        }
        __original();
    };

    q.buildPropertiesForUse = @(__original) function( _skill, _target )
    {
        local properties = __original(_skill, _target);
        if (S.Battle == null || _target == null || !_skill.isAttack()
            || !_target.getSkills().hasSkill("effects.pale_prey"))
            return properties;
        local actor = this.getActor();
        // 1.6.33 所有友方亡灵（冠军、常驻亡灵、复活与召唤的亡灵）和导师都吃猎物加成
        if (S.isChief(actor) || S.isChampionActor(actor) || S.isFriendlyUndead(actor))
        {
            properties.MeleeSkill += 10;
            properties.RangedSkill += 10;
            properties.DamageTotalMult *= 1.2;
        }
        return properties;
    };
});

// Ordinary necromancers receive both summon skills (hidden until Tier 7 perk.bgp_necro_grandmaster is learned).
local function ensureGrandmasterSummons( _skills )
{
    if (_skills == null)
        return;
    foreach (summon in ["zombie", "skeleton"])
        if (!_skills.hasSkill("actives.pale_summon_" + summon))
            _skills.add(::new("scripts/skills/actives/pale_summon_" + summon));
}

mod.hook("scripts/skills/backgrounds/bgp_necromancer_background", function(q)
{
    q.onAdded = @(__original) function()
    {
        __original();
        ensureGrandmasterSummons(this.getContainer());
    };
});

// Ensure existing saves & any brother learning perk.bgp_necro_grandmaster receive both Summon Zombie and Summon Skeleton.
mod.hook("scripts/skills/perks/perk_bgp_necro_grandmaster", function(q)
{
    q.onAdded = @(__original) function()
    {
        __original();
        ensureGrandmasterSummons(this.getContainer());
    };
    q.onCombatStarted = @(__original) function()
    {
        ensureGrandmasterSummons(this.getContainer());
        __original();
    };
});

mod.hook("scripts/skills/actives/bgp_necro_bind_skill", function(q)
{
    q.onUse = @(__original) function( _user, _tile )
    {
        local elite = S.Battle != null && _tile.IsOccupiedByActor && S.isElite(_tile.getEntity());
        if (!elite)
            return __original(_user, _tile);
        local previous = S.mainPet();
        local stash = ::World.Assets.getStash();
        local prior = clone stash.getItems();
        local ret = __original(_user, _tile);
        if (ret)
        {
            local pet = S.mainPet();
            if (pet != null && pet != previous)
                S.petSet(pet, "Elite", 1);
            else
                foreach (item in stash.getItems())
                    if (S.isCoffin(item) && prior.find(item) == null)
                        S.petSet(item, "Elite", 1);
        }
        return ret;
    };
});

// 导师的饰品栏已有死灵宠物时，驱役亡灵 / 驯服亡灵仍可使用，收服的亡灵放进仓库（普通亡灵法师不行）
S.TameStash <- null;
S.canStashPet <- function( _actor )
{
    if (!this.isActive() || !this.isChief(_actor))
        return false;
    local acc = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
    return acc != null && ::BGP.NecroPet.isOwnItem(acc) && ::World.Assets.getStash().hasEmptySlot();
};
S.StashRule <- "亡灵法师导师：饰品栏已有亡灵宠物时仍可使用，收服的宠物放进仓库";

mod.hook("scripts/skills/actives/bgp_necro_bind_skill", function(q)
{
    q.hasDestination = @(__original) function( _user )
    {
        return __original(_user) || S.canStashPet(_user);
    };

    q.getTooltip = @(__original) function()
    {
        local ret = __original();
        local actor = this.getContainer().getActor();
        if (S.isActive() && S.isChief(actor))
        {
            local acc = actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
            local stashFull = acc != null && ::BGP.NecroPet.isOwnItem(acc) && !::World.Assets.getStash().hasEmptySlot();
            foreach (row in ret)
            {
                if (!("id" in row))
                    continue;
                if (row.id == 11)
                    row.text = "饰品栏空着时收服并直接装备（本场不能再放出）；饰品栏已有亡灵宠物时可继续收服并放进仓库；属性、名字、伤势沿用这个单位";
                else if (row.id == 20 && stashFull)
                    row.text = ::MSU.Text.colorNegative("仓库已满，无法收进仓库");
            }
        }
        return ret;
    };
});

mod.hook("scripts/companions/player/companions_tame", function(q)
{
    q.isStashMode <- function()
    {
        local actor = this.getContainer().getActor();
        return actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) != null && actor.getSkills().hasSkill("perk.bgp_necro_grandmaster")
            && S.canStashPet(actor);
    };

    // Mentor can tame beasts normally and unlocks undead taming with Grandmaster; when holding an undead pet, tamed pets go to stash.
    q.isHidden = @(__original) function()
    {
        return __original() && !this.isStashMode();
    };

    q.getTooltip = @(__original) function()
    {
        local ret = __original();
        local actor = this.getContainer().getActor();
        if (S.isActive() && S.isChief(actor) && actor.getSkills().hasSkill("perk.bgp_necro_grandmaster"))
        {
            foreach (row in ret)
            {
                if ("id" in row && row.id == 2)
                {
                    row.text = "可驯服敌方野兽或亡灵。饰品栏空着时收服并直接装备；饰品栏已有亡灵宠物时可继续收服并放进仓库。";
                    break;
                }
            }
        }
        return ret;
    };

    q.onUse = @(__original) function( _user, _targetTile )
    {
        local actor = this.getContainer().getActor();
        local target = _targetTile.getEntity();
        local elite = S.Battle != null && target != null && S.isElite(target);
        if (!this.isStashMode())
        {
            local prev = S.mainPet();
            local ret = __original(_user, _targetTile);
            if (ret && elite && S.isChief(actor))
            {
                local pet = S.mainPet();
                if (pet != null && pet != prev)
                    S.petSet(pet, "Elite", 1);
            }
            return ret;
        }
        local unleash = actor.getSkills().getSkillByID("actives.unleash_companion");
        local used = unleash == null ? null : unleash.m.IsUsed;
        S.TameStash = { Actor = actor, Item = null };
        local ret = false;
        try { ret = __original(_user, _targetTile); }
        catch (e)
        {
            S.TameStash = null;
            throw e;
        }
        local item = S.TameStash.Item;
        S.TameStash = null;
        if (unleash != null)
        {
            unleash.m.IsUsed = used;
            unleash.m.IsHidden = unleash.isUsed();
        }
        if (item != null)
        {
            if (::BGP.NecroPet.isOwnItem(item))
            {
                try { ::BGP.NecroPet.fillFromEntity(item, target); } catch (e) { ::logError("[PaleSovereign] 驯服入库: " + e); }
                if (elite)
                    S.petSet(item, "Elite", 1);
                ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + "把" + item.m.Name + "封进棺椁，放进了仓库");
            }
            else
                ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + "驯服了" + item.m.Name + "，放进了仓库");
        }
        return ret;
    };
});

foreach (path in ["bgp_necro_curse_of_ages_skill", "bgp_corpse_explosion_skill"])
{
    mod.hook("scripts/skills/actives/" + path, function(q)
    {
        q.onAfterUpdate = @(__original) function( _properties )
        {
            __original(_properties);
            local wielder = this.getContainer().getActor();
            local weapon = S.isChief(wielder) ? S.equippedStaff(wielder) : null;
            this.m.MaxRange = weapon != null && weapon.getID() == "weapon.pale_staff_scourge" ? 7 : 6;
            if (this.getID() == "actives.bgp_corpse_explosion")
                this.m.IsAttack = S.isActive() && S.oath() == S.Oath.Scourge && S.isChief(wielder);
        };
    });
}

mod.hook("scripts/skills/actives/bgp_corpse_explosion_skill", function(q)
{
    q.onUse = @(__original) function( _user, _tile )
    {
        if (S.Battle != null)
            S.Battle.Decayed.clear();
        return __original(_user, _tile);
    };
});

mod.hook("scripts/skills/effects/bgp_curse_of_ages_effect", function(q)
{
    q.m.PaleExplosion <- false;

    q.onBeforeDamageReceived = @(__original) function( _attacker, _skill, _hit, _properties )
    {
        __original(_attacker, _skill, _hit, _properties);
        this.m.PaleExplosion = S.Battle != null && _skill != null && _skill.getID() == "actives.bgp_corpse_explosion";
    };

    q.onDamageReceived = @(__original) function( _attacker, _hp, _armor )
    {
        if (this.m.IsPendingDecay && this.m.PaleExplosion && S.Battle != null)
        {
            local id = this.getContainer().getActor().getID();
            if (id in S.Battle.Decayed)
                this.m.IsPendingDecay = false;
            else
                S.Battle.Decayed[id] <- true;
        }
        __original(_attacker, _hp, _armor);
    };
});

mod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
    if (!("serializeCompanionName" in p) || !("deserializeCompanionName" in p) || "PaleID" in p.m)
        return;
    p.m.PaleID <- 0;
    local serialize = p.serializeCompanionName;
    p.serializeCompanionName <- function()
    {
        if (this.m.PaleID == 0)
            return serialize.call(this);
        local name = this.m.Name;
        this.m.Name = name + S.PetTag + this.m.PaleID;
        try
        {
            local result = serialize.call(this);
            this.m.Name = name;
            return result;
        }
        catch (e)
        {
            this.m.Name = name;
            throw e;
        }
    };
    local deserialize = p.deserializeCompanionName;
    p.deserializeCompanionName <- function( _name )
    {
        deserialize.call(this, _name);
        local cut = this.m.Name.find(S.PetTag);
        if (cut != null)
        {
            this.m.PaleID = this.m.Name.slice(cut + S.PetTag.len()).tointeger();
            this.m.Name = this.m.Name.slice(0, cut);
        }
    };
});
