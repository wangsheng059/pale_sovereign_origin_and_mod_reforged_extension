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
            _tooltip.push({ id = 3, type = "hint", icon = "ui/icons/icon_locked.png", text = "战役已立下亡灵天灾誓约。" });
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
            _tooltip.push({ id = 3, type = "hint", icon = "ui/icons/icon_locked.png", text = "战役已立下亡灵冠军誓约。" });
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

local oldEquip = ::BGP.NecroPet.canEquip;
::BGP.NecroPet.canEquip = function( _actor, _item )
{
    return (S.isChief(_actor) && ::BGP.NecroPet.isOwnItem(_item)) || oldEquip(_actor, _item);
};

local oldScale = ::BGP.NecroPet.applyScaling;
::BGP.NecroPet.applyScaling = function( _entity )
{
    oldScale(_entity);
    if (!S.isActive() || !S.isCoffin(_entity.m.Item))
        return;
    local item = _entity.m.Item;
    local chief = S.chief();
    if (chief == null || S.mainPet() != item)
        return;
    S.petID(item);
    if (S.isTameEliteScript(::BGP.NecroPet.TypeDefs[item.getType()].Pet))
        S.petSet(item, "Elite", 1);
    ::BGP.Champion.promotePet(_entity, chief);
    ::BGP.Necro.copySocket(chief, _entity);
    ::BGP.Necro.markMinion(chief, _entity);
    S.applyPetProgress(item, _entity);
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
        entity.getFlags().set("PaleRaised", true);
    return entity;
};

mod.hook("scripts/ui/global/data_helper", function(q)
{
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
            S.set("Oath", route);
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
            S.applyUndeadLook(this);
        }
    };

    q.onUpdateInjuryLayer = @(__original) function()
    {
        __original();
        if (!::BGP.NecroPet.IsLoading && S.isUndead(this))
            S.applyUndeadLook(this);
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
    try { player.getSprite("body").setBrush(this.PartyFigure); }
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
        try { __original(_state); }
        catch (e)
        {
            S.BlockWorldHealing = false;
            throw e;
        }
        S.BlockWorldHealing = false;
        if (this.m.LastDayPaid != dayBefore && S.oath() != S.Oath.None)
            S.repairUndead();

        if (this.m.LastDayPaid != dayBefore && S.get("StenchUntil") > S.worldHours())
            foreach (bro in S.humans())
                bro.worsenMood(0.35, "受不了缝合台的气味");

        local now = ::World.getTime().Days + ::World.getTime().Hours / 24.0;
        foreach (key in ["RitualUntil", "WhispersUntil"])
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
        local mult = ::World.getGlobalVisibilityMult();
        return mult > 0 && mult < 1.0 ? radius * ((1.0 + mult) * 0.5) / mult : radius;
    };
});

mod.hook("scripts/items/item_container", function(q)
{
    q.equip = @(__original) function( _item )
    {
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
            local item = ::World.Assets.getStash().getItemAtIndex(_data[0]);
            if (item != null && item.getID().find("weapon.pale_staff") == 0)
                return _data;
        }
        return __original(_data);
    };
});

mod.hook("scripts/states/world_state", function(q)
{
    q.onCamp = @(__original) function()
    {
        local already = ::World.Assets.isCamping();
        __original();
        if (S.isActive())
            S.CampRequested = !already && ::World.Assets.isCamping();
    };

    q.onUpdate = @(__original) function()
    {
        __original();
        if (S.isActive() && S.Battle == null && this.getPlayer() != null && !::MSU.isNull(this.getPlayer()))
            S.worldEvent();
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

    q.onDeserialize = @(__original) function( _in )
    {
        local ret = __original(_in);
        S.applyPartyLook();
        return ret;
    };

    q.loadCampaign = @(__original) function( _file )
    {
        S.CampRequested = false;
        S.Battle = null;
        S.NextWorldCheck = 0;
        return __original(_file);
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
        if (S.Battle != null && S.isAncientSite(this) && this.isAlive() && this.getTroops().len() == 0
            && ::World.Statistics.getFlags().getAsInt("LastCombatResult") == 1)
            S.registerSite(this.getTile(), 1, this.getName(), 4, true);
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
            Info = ::BGP.Necro.makeDeathInfo(this),
            Fatality = _fatality
        };
        try
        {
            local result = __original(_killer, _skill, _fatality, _silent);
            battle.Death = former;
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
    q.addCorpse = @(__original) function( _tile )
    {
        local result = __original(_tile);
        if (S.Battle != null && S.Battle.Death != null)
            S.recordCorpse(_tile.Properties.get("Corpse"));
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
        if (actor != null && S.Battle != null)
            actor.getFlags().set("PaleRaised", true);
        return actor;
    };
});

mod.hook("scripts/skills/skill_container", function(q)
{
    q.onCombatStarted = @(__original) function()
    {
        local actor = this.getActor();
        if (S.Battle != null && actor.isPlayerControlled())
        {
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
        if (S.Battle == null || S.Battle.Prey == null || _target == null || !_skill.isAttack()
            || !_target.getSkills().hasSkill("effects.pale_prey"))
            return properties;
        local actor = this.getActor();
        if (S.isChief(actor) || S.isChampionActor(actor))
        {
            properties.MeleeSkill += 10;
            properties.RangedSkill += 10;
            properties.DamageTotalMult *= 1.2;
        }
        return properties;
    };
});

mod.hook("scripts/skills/actives/bgp_necro_bind_skill", function(q)
{
    q.isUsable = @(__original) function()
    {
        if (S.isActive() && (!S.isChief(this.getContainer().getActor()) || S.oath() != S.Oath.Champion))
            return false;
        return __original();
    };

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
