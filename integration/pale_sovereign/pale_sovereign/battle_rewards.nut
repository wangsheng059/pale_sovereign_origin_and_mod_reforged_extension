local S = ::PaleSovereign;

S.isPaleBannerBearer <- function( _actor )
{
    local held = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
    return held != null && held.getID() == "weapon.pale_battle_standard";
};

S.isPaleUndeadActor <- function( _actor )
{
    local flags = _actor.getFlags();
    return flags.has("undead") || flags.has("PaleRaised") || this.isUndead(_actor) || this.isChampionActor(_actor);
};

S.battleBoon <- function( _actor, _properties )
{
    if (this.Battle == null || !_actor.isPlacedOnMap())
        return;
    local tile = _actor.getTile();
    if (this.isChief(_actor) && this.ambitionDone("immortal_guard"))
    {
        local pet = this.mainPet();
        if (this.isDeployed(pet) && tile.getDistanceTo(pet.m.Entity.getTile()) <= 2)
        {
            _properties.MeleeDefense += 5;
            _properties.RangedDefense += 5;
        }
    }

    if (!this.ambitionDone("pale_banner") || !this.isPaleUndeadActor(_actor))
        return;
    foreach (bearer in ::World.getPlayerRoster().getAll())
    {
        if (bearer.isAlive() && !bearer.isDying() && bearer.isPlacedOnMap() && bearer.isAlliedWith(_actor)
            && tile.getDistanceTo(bearer.getTile()) <= 4 && this.isPaleBannerBearer(bearer))
        {
            _properties.MeleeSkill += 5;
            _properties.MeleeDefense += 5;
            break;
        }
    }
};

S.addBattleBoons <- function( _actor )
{
    local skills = _actor.getSkills();
    if (!skills.hasSkill("effects.pale_battle_boons"))
        skills.add(::new(this.SkillDir + "effects/pale_battle_boons"));
};

S.refreshBattleBoons <- function()
{
    foreach (faction in ::Tactical.Entities.getAllInstances())
        foreach (actor in faction)
            if (actor.isAlive() && !actor.isDying() && actor.isPlacedOnMap()
                && actor.getSkills().hasSkill("effects.pale_battle_boons"))
                actor.getSkills().update();
};

S.deferBattleSpawn <- function( _actor, _spawn )
{
    // The turn bar assigns its active entity after actor.onTurnStart returns.
    ::Time.scheduleEvent(::TimeUnit.Real, 100, function( _request )
    {
        if (S.Battle != _request.Battle || ::MSU.isNull(_request.Actor) || !_request.Actor.isAlive()
            || ::Tactical.TurnSequenceBar.getActiveEntity() == null)
            return;
        _request.Spawn.call(S, _request.Actor);
    }, { Battle = this.Battle, Actor = ::MSU.asWeakTableRef(_actor), Spawn = _spawn });
};

S.Mod.hookTree("scripts/skills/skill", function(q)
{
    q.attackEntity = @(__original) function( ... )
    {
        if (S.Battle != null && S.Battle.SiegeFight && this.m.IsShowingProjectile && this.m.ProjectileType != 0)
        {
            // Some troop equipment selects a projectile without a sprite in this mod stack.
            try { local sprite = ::Const.ProjectileSprite[this.m.ProjectileType]; }
            catch (e) { this.m.IsShowingProjectile = false; }
        }
        local args = [this];
        args.extend(vargv);
        return __original.acall(args);
    };
});

S.bearsSignet <- function( _actor )
{
    local item = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Accessory);
    return item != null && item.getID() == "accessory.pale_signet";
};

S.Mod.hook("scripts/skills/special/night_effect", function(q)
{
    q.isHidden = @(__original) function()
    {
        local item = this.getContainer().getActor().getItems().getItemAtSlot(::Const.ItemSlot.Ammo);
        return (item != null && item.getID() == "tool.pale_bone_lantern") || __original();
    };

    q.onUpdate = @(__original) function( _properties )
    {
        local item = this.getContainer().getActor().getItems().getItemAtSlot(::Const.ItemSlot.Ammo);
        if (item == null || item.getID() != "tool.pale_bone_lantern")
            __original(_properties);
    };
});

foreach (path in ["charm_skill", "possess_undead_skill"])
{
    S.Mod.hook("scripts/skills/actives/" + path, function(q)
    {
        q.onVerifyTarget = @(__original) function( _origin, _target )
        {
            return __original(_origin, _target) && (!_target.IsOccupiedByActor || !S.bearsSignet(_target.getEntity()));
        };
    });
}

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onRoundStart = @(__original) function()
    {
        __original();
        if (S.Battle == null || !this.isPlacedOnMap())
            return;
        local chief = S.chief();
        if (chief != null && this.isAlliedWith(chief) && S.isPaleUndeadActor(this))
            S.addBattleBoons(this);
    };
});

S.Mod.hook("scripts/skills/skill_container", function(q)
{
    q.onMovementFinished = @(__original) function()
    {
        __original();
        if (S.Battle == null || (!S.ambitionDone("immortal_guard") && !S.ambitionDone("pale_banner")))
            return;
        local actor = this.getActor();
        if (S.isChief(actor) || S.isDeployed(S.mainPet(), actor) || S.isPaleBannerBearer(actor))
            S.refreshBattleBoons();
        else if (this.hasSkill("effects.pale_battle_boons"))
            this.update();
    };

    q.add = @(__original) function( _skill, _order = 0 )
    {
        if (S.Battle != null && _skill != null && ["effects.charmed", "effects.possessed_undead"].find(_skill.getID()) != null
            && S.bearsSignet(this.getActor()))
            return;
        return __original(_skill, _order);
    };
});

S.Mod.hook("scripts/states/world/asset_manager", function(q)
{
    q.update = @(__original) function( _state )
    {
        if (S.isActive() && S.ambitionDone("immortal_guard") && this.m.IsConsumingAssets
            && ::World.getTime().Hours != this.m.LastHourUpdated)
        {
            foreach (pet in S.companyCoffins())
                pet.m.Wounds = ::Math.max(0, pet.m.Wounds - 2);
        }
        return __original(_state);
    };
});
