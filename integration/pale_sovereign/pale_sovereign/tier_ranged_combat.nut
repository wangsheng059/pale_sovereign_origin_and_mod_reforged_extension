local S = ::PaleSovereign;

S.rangedAttackWeapon <- function( _skill )
{
    if (!_skill.isAttack() || !_skill.isRanged() || !_skill.m.IsWeaponSkill)
        return null;
    local item = _skill.getItem();
    return ::MSU.isKindOf(item, "weapon") ? item : null;
};

S.Mod.hook("scripts/skills/skill", function(q)
{
    q.getMaxRange = @(__original) function()
    {
        local range = __original();
        local skills = this.getContainer();
        if (::MSU.isNull(skills) || !skills.hasSkill("effects.pale_bone_piercing_arrow")
            || this.getID() == "actives.pale_arrow_rain")
            return range;
        local weapon = S.rangedAttackWeapon(this);
        return weapon != null && weapon.isWeaponType(::Const.Items.WeaponType.Bow) ? range + 1 : range;
    };
});

// Consumption identifies a throw that actually occurred, even when attackEntity returns false on a miss.
local currentThrow = null;
local function refundFirstThrow( _weapon, _singleUse )
{
    if (currentThrow == null || currentThrow.SingleUse != _singleUse
        || !::MSU.isEqual(_weapon, currentThrow.Weapon) || currentThrow.Talent.m.UsedRound == ::Time.getRound())
        return false;
    currentThrow.Talent.m.UsedRound = ::Time.getRound();
    local actor = currentThrow.Actor;
    actor.setActionPoints(::Math.min(actor.getActionPointsMax(), actor.getActionPoints() + 2));
    actor.setDirty(true);
    return true;
}

S.Mod.hook("scripts/skills/skill", function(q)
{
    q.use = @(__original) function( _tile, _forFree = false )
    {
        local skills = this.getContainer();
        if (!::Tactical.isActive() || ::MSU.isNull(skills))
            return __original(_tile, _forFree);
        local talent = skills.getSkillByID("effects.pale_bone_spike_throw");
        if (talent == null || talent.m.UsedRound == ::Time.getRound())
            return __original(_tile, _forFree);
        local weapon = S.rangedAttackWeapon(this);
        if (weapon == null || !weapon.isWeaponType(::Const.Items.WeaponType.Throwing))
            return __original(_tile, _forFree);

        local former = currentThrow;
        currentThrow = { Weapon = weapon, Actor = skills.getActor(), Talent = talent, SingleUse = weapon.getAmmoMax() <= 0 };
        local result;
        try { result = __original(_tile, _forFree); }
        catch (e) { currentThrow = former; throw e; }
        currentThrow = former;
        return result;
    };
});

S.Mod.hook("scripts/items/weapons/weapon", function(q)
{
    q.consumeAmmo = @(__original) function()
    {
        if (!refundFirstThrow(this, false))
            return __original();
    };
});

S.Mod.hook("scripts/items/item_container", function(q)
{
    q.unequip = @(__original) function( _item )
    {
        if (!refundFirstThrow(_item, true))
            return __original(_item);
    };
});
