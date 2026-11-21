local S = ::PaleSovereign;
local C = ::Conquest;

S.governorMetadata <- function()
{
    local meta = ::MSU.Class.MetaDataEmulator();
    meta.setString("mod_msuVersion", ::MSU.Mod.getVersionString());
    return meta;
};

S.storeGovernor <- function( _town, _coffin )
{
    local flags = _town.getFlags();
    local stream = ::MSU.Class.FlagSerializationEmulator(C.Mod, "PaleGovernor", flags, this.governorMetadata());
    _coffin.onSerialize(stream);
    stream.storeDataInFlagContainer();
    flags.set("PaleGovernorScript", ::IO.scriptFilenameByHash(_coffin.ClassNameHash));
    flags.set("PaleGovernorName", _coffin.m.Name);
    flags.set("PaleGovernor", true);
};

S.loadGovernor <- function( _town )
{
    local flags = _town.getFlags();
    if (flags.get("PaleGovernor") != true)
        return null;
    local temp = ::new("scripts/tools/tag_collection");
    local key = "MSU." + C.Mod.getID() + ".PaleGovernor";
    local count = flags.getAsInt(key);
    temp.set(key, count);
    for (local i = 0; i < count; ++i)
    {
        temp.set(key + ".data." + i, flags.get(key + ".data." + i));
        temp.set(key + ".type." + i, flags.get(key + ".type." + i));
    }
    local input = ::MSU.Class.FlagDeserializationEmulator(C.Mod, "PaleGovernor", temp, this.governorMetadata());
    if (!input.loadDataFromFlagContainer())
        return null;
    local coffin = ::new(flags.get("PaleGovernorScript"));
    coffin.onDeserialize(input);
    return coffin;
};

S.clearGovernor <- function( _town )
{
    local flags = _town.getFlags();
    local key = "MSU." + C.Mod.getID() + ".PaleGovernor";
    for (local i = 0; i < flags.getAsInt(key); ++i)
    {
        flags.remove(key + ".data." + i);
        flags.remove(key + ".type." + i);
    }
    flags.remove(key);
    foreach (field in ["PaleGovernor", "PaleGovernorName", "PaleGovernorScript", "PaleGovernorEvacuate"])
        flags.remove(field);
};

S.returnGovernor <- function( _town )
{
    local flags = _town.getFlags();
    if (flags.get("PaleGovernor") != true)
        return "这座城没有冠军坐镇。";
    local stash = ::World.Assets.getStash();
    if (!stash.hasEmptySlot())
    {
        if (!C.isOwnedByPlayer(_town))
            flags.set("PaleGovernorEvacuate", true);
        return "战团物品栏已满，棺椁暂时留在原处。";
    }
    local coffin = this.loadGovernor(_town);
    if (coffin == null || !stash.add(coffin))
        return "棺椁暂时无法取出。";
    this.clearGovernor(_town);
    return coffin.m.Name + " 已回到战团物品栏。";
};

S.assignGovernor <- function( _town, _coffin )
{
    if (this.oath() != this.Oath.Champion || this.conquestMode(_town) == 0 || _town.getFlags().get("PaleGovernor") == true)
        return "无法派遣冠军。";
    local stash = ::World.Assets.getStash();
    if (stash.getItems().find(_coffin) == null)
        return "这口棺椁已经不在战团物品栏。";
    this.petID(_coffin);
    this.storeGovernor(_town, _coffin);
    stash.remove(_coffin);
    return _coffin.m.Name + " 留守此城，驻军强度 +1 级。守城战中它会以宠物身份出战。";
};

S.governorPanel <- function( _screen )
{
    local town = this.findPaleTown();
    _screen.Text = "将一口候补棺椁留在城里，令冠军指挥亡灵驻军。";
    if (this.oath() != this.Oath.Champion || town == null)
        return;
    local flags = town.getFlags();
    if (flags.get("PaleGovernor") == true)
    {
        _screen.Text += "\n\n坐镇者　" + flags.get("PaleGovernorName");
        this.option(_screen, "召回驻军统领", @() S.returnGovernor(town));
        return;
    }
    foreach (coffin in ::World.Assets.getStash().getItems())
    {
        if (!this.isCoffin(coffin))
            continue;
        local candidate = coffin;
        this.option(_screen, "留下 " + candidate.m.Name, @() S.assignGovernor(town, candidate));
    }
};

S.conquestWorldTick = function()
{
    if (!::World.Assets.getStash().hasEmptySlot())
        return;
    foreach (town in ::World.EntityManager.getSettlements())
        if (town.getFlags().get("PaleGovernorEvacuate") == true)
            this.returnGovernor(town);
};

S.addGovernorToCombat <- function( _properties, _town )
{
    local coffin = this.loadGovernor(_town);
    if (coffin == null)
        return;

    local troop = clone ::Const.World.Spawn.Troops.SkeletonLight;
    troop.Script = coffin.getScript();
    troop.Faction <- ::Const.Faction.PlayerAnimals;
    troop.Callback <- function( _entity, _data )
    {
        _entity.setItem(coffin);
        _entity.setName(coffin.m.Name);
        _entity.setVariant(coffin.getVariant());
        coffin.setEntity(_entity);
        S.Battle.Governor = {
            Town = _town, Pet = coffin, Entity = _entity, EntityID = _entity.getID(),
            Died = false, Settled = false
        };
    };
    _properties.Entities.push(troop);
};

S.prepareGovernor <- function( _entity, _coffin )
{
    _entity.applyCompanionScaling();
    local chief = this.chief();
    if (chief != null)
    {
        ::BGP.Necro.copySocket(chief, _entity);
        ::BGP.Necro.markMinion(chief, _entity);
    }
    this.applyPetProgress(_coffin, _entity);
    if (this.petGet(_coffin, "Gilded") > 0 && "gildArmor" in this)
        this.gildArmor(_entity);
    this.addBattleBoons(_entity);
    _entity.setHitpointsPct(::Math.maxf(0.05, (100.0 - _coffin.m.Wounds) / 100.0));
};

S.Mod.hook("scripts/entity/tactical/tactical_entity_manager", function(q)
{
    q.spawn = @(__original) function( _properties )
    {
        local result = __original(_properties);
        if (S.Battle != null && S.Battle.Governor != null)
        {
            local governor = S.Battle.Governor;
            S.prepareGovernor(governor.Entity, governor.Pet);
        }
        return result;
    };
});

S.settleBattleGovernor <- function()
{
    local governor = this.Battle == null ? null : this.Battle.Governor;
    if (governor == null || governor.Settled)
        return;

    // An invalid entity reference during teardown does not imply a casualty.
    if (governor.Died)
        this.clearGovernor(governor.Town);
    else
    {
        local entity = governor.Entity;
        if (entity == null || ::MSU.isNull(entity) || !entity.isAlive())
            return;
        governor.Pet.m.Wounds = ::Math.max(0, ::Math.floor((1.0 - entity.getHitpointsPct()) * 100.0));
        this.storeGovernor(governor.Town, governor.Pet);
    }
    governor.Settled = true;
};

S.Mod.hook("scripts/states/tactical_state", function(q)
{
    q.onBattleEnded = @(__original) function( ... )
    {
        S.settleBattleGovernor();
        local args = [this];
        args.extend(vargv);
        return __original.acall(args);
    };
});

S.Mod.hook("scripts/states/world_state", function(q)
{
    q.onCombatFinished = @(__original) function()
    {
        S.settleBattleGovernor();
        return __original();
    };
});
