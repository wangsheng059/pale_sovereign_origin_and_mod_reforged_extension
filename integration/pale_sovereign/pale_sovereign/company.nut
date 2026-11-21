local S = ::PaleSovereign;

S.isActive <- function()
{
    if (!("Assets" in ::World) || ::World.Assets == null)
        return false;
    local origin = ::World.Assets.getOrigin();
    // MSU probes world serialization with a placeholder origin during startup.
    local kind = typeof origin;
    return (kind == "table" || kind == "instance") && origin.getID() == this.ID;
};

// 名册 18 人、部署 12 人；立下亡灵天灾誓约后名册 20 人、部署 14 人
S.applyRosterLimits <- function()
{
    if (!("Assets" in ::World) || ::World.Assets == null)
        return;
    local scourge = false;
    try { scourge = this.oath() == this.Oath.Scourge; } catch (e) { scourge = false; }
    ::World.Assets.m.BrothersMax = scourge ? this.ScourgeRosterLimit : this.RosterLimit;
    ::World.Assets.m.BrothersMaxInCombat = scourge ? (this.ambitionDone("forbidden_glimpse") ? 16 : this.ScourgeCombatLimit) : this.CombatLimit;
};

S.get <- function( _key )
{
    return ::World.Flags.getAsInt("Pale." + _key);
};

S.set <- function( _key, _value )
{
    ::World.Flags.set("Pale." + _key, _value);
};

S.oath <- function()
{
    return this.get("Oath");
};

S.isChief <- function( _actor )
{
    return _actor != null && _actor.getFlags().has("PaleChief");
};

S.nameChief <- function( _chief )
{
    _chief.setName(this.ChiefName);
    _chief.setTitle("");
};

S.chief <- function()
{
    foreach (bro in ::World.getPlayerRoster().getAll())
        if (this.isChief(bro))
            return bro;
    return null;
};

S.perkRoute <- function( _id )
{
    if (::BGP.Necro.ChampionPerks.find(_id) != null)
        return this.Oath.Champion;
    if (::BGP.Necro.ScourgePerks.find(_id) != null)
        return this.Oath.Scourge;
    return this.Oath.None;
};

S.isUndead <- function( _bro )
{
    return _bro.getFlags().has("PalePermanentUndead");
};

S.humans <- function()
{
    return ::World.getPlayerRoster().getAll().filter(@(_, bro) !bro.getFlags().has("undead"));
};

S.undead <- function()
{
    return ::World.getPlayerRoster().getAll().filter(@(_, bro) ::PaleSovereign.isUndead(bro));
};

S.permanentUndeadLimit <- function()
{
    local oath = this.oath();
    if (oath == this.Oath.Champion)
        return this.ChampionUndeadLimit;
    return oath == this.Oath.Scourge ? null : 0;
};

S.reserveLimit <- function()
{
    return this.ReserveLimit + (this.get("Ascended") == 1 && this.oath() == this.Oath.Scourge ? 20 : 0)
        + (this.ambitionDone("laden_cart") ? 10 : 0) + this.castleReserveBonus();
};

S.changeReserve <- function( _delta )
{
    local before = this.get("Reserve");
    if (before + _delta < 0)
        return false;
    this.set("Reserve", ::Math.min(this.reserveLimit(), before + _delta));
    return true;
};

S.followerRank <- @(_key) 0;
S.castleReserveBonus <- @() 0;
S.castleWorldTick <- @() null;
S.castleHere <- @() null;
S.findPaleTown <- @() null;
S.conquestMode <- @(_town) 0;
S.conquestDay <- @() null;
S.conquestWorldTick <- @() null;
S.castleDefenseLoot <- @(_properties, _count) false;
S.CastlePage <- null;
S.castleDaily <- function()
{
    if (this.oath() != this.Oath.None)
        this.repairUndead();
};
S.followerVictory <- @() null;
S.followerWorldTick <- @() null;
S.followerOnKill <- @(_killer) null;

S.repairUndead <- function( _free = false )
{
    local injured = this.undead().filter(@(_, bro) bro.getHitpoints() < bro.getHitpointsMax());
    if (injured.len() == 0 || (!_free && !this.changeReserve(-1)))
        return;
    local ratio = this.ambitionDone("ranks_of_dead") ? 0.35 : (this.followerRank("embalmer") >= 2 ? 0.30 : 0.20);
    foreach (bro in injured)
        bro.setHitpoints(::Math.minf(bro.getHitpointsMax(), bro.getHitpoints() + bro.getHitpointsMax() * ratio));
};

S.spawnBrother <- function( _background, _gear, _position = -1, _traits = true )
{
    local bro = ::World.getPlayerRoster().create("scripts/entity/tactical/player");
    bro.setStartValuesEx([_background], _traits);
    if (bro.getTalents().len() == 0)
        bro.getTalents().resize(::Const.Attributes.COUNT, 0);
    bro.m.HireTime = ::Time.getVirtualTimeF();
    if (_position != -1)
        bro.setPlaceInFormation(_position);
    if (_gear != null)
    {
        local items = bro.getItems();
        foreach (item in items.getAllItems())
            items.unequip(item);
        foreach (path in _gear)
            items.equip(::new(this.ItemDir + path));
    }
    bro.getSkills().update();
    bro.setHitpointsPct(1.0);
    return bro;
};

S.countItems <- function( _id )
{
    return ::World.Assets.getStash().getItems().filter(@(_, item) item != null && item.getID() == _id).len();
};

S.addMaterials <- function( _name, _count )
{
    local stash = ::World.Assets.getStash();
    local empty = stash.getItems().filter(@(_, item) item == null).len();
    if (empty < _count)
        return false;
    for (local i = 0; i < _count; ++i)
        stash.add(::new(this.ItemDir + "misc/pale_" + _name + "_item"));
    return true;
};

S.removeMaterial <- function( _name )
{
    local stash = ::World.Assets.getStash();
    foreach (item in stash.getItems())
    {
        if (item == null || item.getID() != "misc.pale_" + _name)
            continue;
        stash.remove(item);
        return true;
    }
    return false;
};

S.equippedStaff <- function( _bro )
{
    local weapon = _bro.getItems().getItemAtSlot(::Const.ItemSlot.Mainhand);
    return weapon != null && weapon.getID().find("weapon.pale_staff") == 0 ? weapon : null;
};

S.findStaff <- function()
{
    local chief = this.chief();
    if (chief == null)
        return null;
    local staff = this.equippedStaff(chief);
    if (staff != null && staff.getID() == "weapon.pale_staff")
        return staff;
    foreach (item in ::World.Assets.getStash().getItems())
        if (item != null && item.getID() == "weapon.pale_staff")
            return item;
    return null;
};

S.canEvolve <- function()
{
    local chief = this.chief();
    if (chief == null || this.get("Evolved") != 0)
        return false;
    local ready = this.oath() == this.Oath.Champion
        ? chief.getSkills().hasSkill("perk.bgp_necro_infusion")
        : this.oath() == this.Oath.Scourge && chief.getSkills().hasSkill("perk.bgp_necro_curse_of_ages");
    return ready && this.findStaff() != null;
};

S.evolveStaff <- function()
{
    if (!this.canEvolve())
        return false;
    local staff = this.findStaff();
    local chief = this.chief();
    local items = chief.getItems();
    local upgraded = ::new(this.ItemDir + "weapons/pale_staff_" + (this.oath() == this.Oath.Champion ? "champion" : "scourge"));
    local conditionRatio = staff.getCondition() / staff.getConditionMax();
    if (this.equippedStaff(chief) == staff)
    {
        items.unequip(staff);
        if (!items.equip(upgraded))
        {
            items.equip(staff);
            return false;
        }
    }
    else
    {
        local stash = ::World.Assets.getStash();
        stash.remove(staff);
        stash.add(upgraded);
    }
    upgraded.setCondition(upgraded.getConditionMax() * conditionRatio);
    this.set("Evolved", 1);
    chief.getSkills().update();
    return true;
};

S.isRejected <- function( _id )
{
    return [
        "background.adventurous_noble", "background.disowned_noble", "background.bastard",
        "background.paladin", "background.oathtaker", "background.bgp_old_oathtaker",
        "background.monk", "background.priest", "background.witchhunter",
        "background.swordmaster", "background.rf_renowned_swordmaster",
        "background.hedge_knight", "background.bgp_commander", "background.bgp_necromancer",
        "background.pale_necromancer", "background.pale_skeleton", "background.pale_zombie"
    ].find(_id) != null;
};
