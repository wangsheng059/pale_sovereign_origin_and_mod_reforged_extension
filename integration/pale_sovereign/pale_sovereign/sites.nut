local S = ::PaleSovereign;

S.isAncientSite <- function( _location )
{
    local name = ::IO.scriptFilenameByHash(_location.ClassNameHash);
    return name != null && (name.find("ancient_") != null || name.find("undead_graveyard") != null
        || name.find("undead_crypt") != null || name.find("undead_ruin") != null || name.find("undead_tomb") != null);
};

// 飞升仪式要求通关的传奇地点（按地点脚本名；狩猎场另外认击杀伊吉罗克）
S.LegendSites <- {
    tundra_elk_location = "Hunt",
    goblin_city_location = "Goblin",
    unique_goblin_city_location = "Goblin",
    black_monolith_location = "Monolith",
    undead_monolith_location = "Monolith"
};

S.recordLegend <- function( _location )
{
    local fileName = this.scriptBase(::IO.scriptFilenameByHash(_location.ClassNameHash));
    if (fileName in this.LegendSites)
        this.set("Legend." + this.LegendSites[fileName], 1);
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
        // 魂玉 15%、锁链 35%、其余是陪葬的古钱
        local roll = ::Math.rand(1, 100);
        local found = null;
        if (roll <= 50)
        {
            local jade = roll <= 15;
            if (!this.addMaterials(jade ? "jade" : "chain", 1))
                return "仓库没有空位，石棺里的东西仍留在遗址里。";
            found = jade ? "撬开石棺，从中取出一枚冰冷的古代魂玉。" : "撬开石棺，从枯骨的腕间解下一条尚能使用的缚魂锁链。";
        }
        else
        {
            local coins = ::Math.rand(60, 120);
            ::World.Assets.addMoney(coins);
            found = "撬开石棺，里面只剩一些陪葬的古钱，折合 " + coins + " 克朗。";
        }
        this.set(_site.Key + "Inspected", 1);
        local lead = this.revealAncient();
        return found + (lead == null ? "" : "墓砖上的残缺铭文指向了 " + lead + "。");
    }

    if (this.oath() == this.Oath.Scourge)
    {
        local before = this.get("Reserve");
        local supply = this.get(_site.Key + "Supply");
        if (this.get(_site.Key + "Kind") == 2)
            supply = (supply / 2).tointeger();
        this.changeReserve(supply);
        this.set(_site.Key + "Inspected", 1);
        local text = "清点地宫角落后，从遗址中回收了 " + (this.get("Reserve") - before) + " 点防腐尸骸。库存 " + before + " → " + this.get("Reserve") + "。";
        if (this.get(_site.Key + "Kind") == 1 && ::Math.rand(1, 100) <= 10 && this.addMaterials("jade", 1))
            text += "盗墓贼还在一具裹尸布里摸到了一枚古代魂玉。";
        return text;
    }
    return "立誓后可勘察这处遗址。";
};

S.SkeletonTitles <- ["盐封骷髅", "铜索枯骨", "墓穴哨兵", "锈刃骸骨", "无名骨卒", "荒冢白骨"];
S.ZombieTitles <- ["缝合行尸", "盐渍尸卒", "腐土力士", "裹尸重步", "僵步死士", "墓泥行尸"];

S.canRecruitUndead <- function( _site )
{
    local limit = this.permanentUndeadLimit();
    return _site != null && this.get(_site.Key + "Recruited") == 0
        && this.get("Reserve") >= 3 && (limit == null || this.undead().len() < limit)
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
    local titles = _skeleton ? this.SkeletonTitles : this.ZombieTitles;
    bro.setTitle(titles[::Math.rand(0, titles.len() - 1)]);
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
