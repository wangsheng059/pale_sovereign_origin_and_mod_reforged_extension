local S = ::PaleSovereign;

S.isAncientSite <- function( _location )
{
    local name = ::IO.scriptFilenameByHash(_location.ClassNameHash);
    return name != null && (name.find("ancient_") != null || name.find("undead_graveyard") != null
        || name.find("undead_crypt") != null || name.find("undead_ruin") != null || name.find("undead_tomb") != null);
};

S.siteKey <- function( _tile )
{
    return "Site." + _tile.SquareCoords.X + "." + _tile.SquareCoords.Y + ".";
};

S.registerSite <- function( _tile, _kind, _name, _supply, _cleared )
{
    local key = this.siteKey(_tile);
    if (this.get(key + "Kind") == 0)
    {
        this.set(key + "Kind", _kind);
        this.set(key + "Name", _name);
        this.set(key + "Supply", _supply);
    }
    if (_cleared)
        this.set(key + "Cleared", 1);
};

S.localSite <- function( _kind = 0, _cleared = false )
{
    local feet = ::World.State.getPlayer().getTile();
    local tiles = [feet];
    tiles.extend(this.area(feet).slice(1));
    for (local i = 1; i < tiles.len(); ++i)
    {
        // Include neighbouring tiles even when the cleared location was removed by the engine.
        local tile = tiles[i];
        if (feet.getDistanceTo(tile) != 1)
            break;
        foreach (near in this.area(tile))
        {
            if (feet.getDistanceTo(near) == 2 && tiles.find(near) == null)
                tiles.push(near);
        }
    }
    foreach (tile in tiles)
    {
        local key = this.siteKey(tile);
        local kind = this.get(key + "Kind");
        if (kind == 0 || (_kind != 0 && _kind != kind) || (_cleared && this.get(key + "Cleared") == 0))
            continue;
        return { Key = key, Kind = kind, Name = ::World.Flags.get("Pale." + key + "Name") };
    }
    return null;
};

S.revealAncient <- function()
{
    local feet = ::World.State.getPlayer().getTile();
    local nearest = null;
    local distance = 100000;
    foreach (loc in ::World.EntityManager.getLocations())
    {
        if (loc == null || !loc.isAlive() || !this.isAncientSite(loc))
            continue;
        local tile = loc.getTile();
        local d = feet.getDistanceTo(tile);
        if (d < distance && !loc.getFlags().has("PaleEliteLead") && this.get(this.siteKey(tile) + "Inspected") == 0)
        {
            nearest = loc;
            distance = d;
        }
    }
    if (nearest == null)
        return null;
    nearest.setDiscovered(true);
    this.registerSite(nearest.getTile(), 1, nearest.getName(), 4, false);
    if (this.oath() == this.Oath.Champion)
        nearest.getFlags().set("PaleEliteLead", true);
    return nearest.getName();
};

S.populateEliteLead <- function( _location )
{
    local flags = _location.getFlags();
    if (!flags.has("PaleEliteLead") || flags.has("PaleEliteSeen") || _location.getTroops().len() == 0)
        return;
    local hasElite = false;
    foreach (troop in _location.getTroops())
    {
        if (this.isTameEliteScript(troop.Script))
        {
            hasElite = true;
            break;
        }
    }
    if (!hasElite)
        ::Const.World.Common.addTroop(_location, { Type = ::Const.World.Spawn.Troops.RF_SkeletonMediumElite }, false);
    flags.set("PaleEliteSeen", true);
};

S.inspectAncient <- function( _site )
{
    if (this.get(_site.Key + "Inspected") != 0)
        return "营地已勘察过这处遗址。";
    local pet = this.mainPet();
    local starter = pet != null && pet.m.PaleID == this.get("StarterID");
    if (this.oath() == this.Oath.Champion && starter && this.get("BannerEvent") == 0)
        return null;

    if (this.oath() == this.Oath.Champion)
    {
        if (!this.addMaterials("jade", 1))
            return "仓库没有空位，魂玉仍留在遗址里。";
        this.set(_site.Key + "Inspected", 1);
        local lead = this.revealAncient();
        return "从石棺中找到 1 枚古代魂玉。" + (lead == null ? "" : "墓砖上的铭文指向 " + lead + "。");
    }

    if (this.oath() == this.Oath.Scourge)
    {
        local before = this.get("Reserve");
        local supply = this.get(_site.Key + "Supply");
        if (this.get(_site.Key + "Kind") == 2)
            supply = (supply / 2).tointeger();
        this.changeReserve(supply);
        this.set(_site.Key + "Inspected", 1);
        return "从遗址回收 " + (this.get("Reserve") - before) + " 点防腐尸骸。库存 " + before + " → " + this.get("Reserve") + "。";
    }
    return "立誓后可勘察这处遗址。";
};

S.canRecruitUndead <- function( _site )
{
    return _site != null && this.oath() == this.Oath.Scourge && this.get(_site.Key + "Recruited") == 0
        && this.get("Reserve") >= 3 && this.undead().len() < this.UndeadLimit
        && ::World.getPlayerRoster().getSize() < ::World.Assets.getBrothersMax();
};

S.recruitUndead <- function( _site, _skeleton )
{
    if (!this.canRecruitUndead(_site))
        return false;
    local name = _skeleton ? "pale_skeleton_background" : "pale_zombie_background";
    local equipment = _skeleton
        ? ["weapons/ancient/ancient_sword", "shields/wooden_shield"]
        : ["weapons/wooden_stick", "armor/tattered_sackcloth"];
    local bro = this.spawnBrother(name, equipment, -1, false);
    bro.getFlags().set("PalePermanentUndead", true);
    bro.getFlags().set("undead", true);
    bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
    bro.setTitle(_skeleton ? "盐封骷髅" : "缝合行尸");
    bro.m.MoraleState = ::Const.MoraleState.Ignore;
    this.applyUndeadLook(bro);
    this.changeReserve(-3);
    this.set(_site.Key + "Recruited", 1);
    ::World.Assets.updateFormation(true);
    return true;
};

S.nearTown <- function( _range, _smith = false )
{
    local feet = ::World.State.getPlayer().getTile();
    local nearest = null;
    local distance = _range + 1;
    foreach (town in ::World.EntityManager.getSettlements())
    {
        if (_smith && !town.hasBuilding("building.weaponsmith") && !town.hasBuilding("building.weaponsmith_oriental")
            && !town.hasBuilding("building.armorsmith") && !town.hasBuilding("building.armorsmith_oriental"))
            continue;
        local d = feet.getDistanceTo(town.getTile());
        if (d < distance)
        {
            nearest = town;
            distance = d;
        }
    }
    return nearest;
};

S.worldHours <- function()
{
    local time = ::World.getTime();
    return time.Days * 24 + time.Hours;
};

S.terrainForCrown <- function()
{
    local terrain = ::World.State.getPlayer().getTile().Type;
    return this.localSite(1) != null || terrain == ::Const.World.TerrainType.Mountains || terrain == ::Const.World.TerrainType.Desert;
};

S.startPatrolFight <- function()
{
    local props = ::World.State.getLocalCombatProperties(::World.State.getPlayer().getPos());
    props.CombatID = "PaleLantern";
    props.Entities = [];
    foreach (troop in [::Const.World.Spawn.Troops.Militia, ::Const.World.Spawn.Troops.Militia, ::Const.World.Spawn.Troops.MilitiaVeteran])
    {
        local enemy = clone troop;
        enemy.Faction <- ::Const.Faction.Enemy;
        props.Entities.push(enemy);
    }
    ::World.State.startScriptedCombat(props, false, false, true);
};
