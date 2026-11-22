this.pale_arrow_rain <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = { Used = false },

    function create()
    {
        this.pale_tier_passive.create();
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.OffensiveTargeted;
        this.m.IsActive = true;
        this.m.IsAttack = true;
        this.m.IsRanged = true;
        this.m.IsTargeted = true;
        this.m.IsTargetingActor = false;
        this.m.IsWeaponSkill = true;
        this.m.IsAOE = true;
        this.m.IsIgnoredAsAOO = true;
        this.m.IsShowingProjectile = false;
        this.m.IsDoingForwardMove = false;
        this.m.MinRange = 2;
        this.m.MaxRange = 6;
        this.m.MaxRangeBonus = 0;
        this.m.MaxLevelDifference = 9;
        this.m.ActionPointCost = 6;
        this.m.FatigueCost = 25;
    }

    function onCombatStarted() { this.m.Used = false; }
    function onCombatFinished() { this.m.Used = false; }

    function getItem()
    {
        local container = this.getContainer();
        return ::MSU.isNull(container) ? null : container.getActor().getMainhandItem();
    }

    function getAttackProfile()
    {
        local weapon = this.getItem();
        local types = ::Const.Items.WeaponType;
        if (!::MSU.isKindOf(weapon, "weapon") || !weapon.isWeaponType(types.Bow | types.Throwing))
            return null;
        local attacks = this.getContainer().getSkillsByFunction(@(skill) skill.isTargetingActor()
            && ::MSU.isEqual(weapon, ::PaleSovereign.rangedAttackWeapon(skill)));
        foreach (attack in attacks)
            if (attack.getID() == "actives.quick_shot")
                return attack;
        return attacks.len() == 0 ? null : attacks[0];
    }

    function getVolleyAmmo()
    {
        local weapon = this.getItem();
        if (weapon.isWeaponType(::Const.Items.WeaponType.Throwing))
            return weapon;
        local ammo = this.getContainer().getActor().getItems().getItemAtSlot(::Const.ItemSlot.Ammo);
        return ::MSU.isKindOf(ammo, "ammo") && ammo.getAmmoType() == ::Const.Items.AmmoType.Arrows ? ammo : null;
    }

    function hasVolleyAmmo()
    {
        local profile = this.getAttackProfile();
        if (profile == null)
            return false;
        local ammo = this.getVolleyAmmo();
        return ammo != null && (ammo.getAmmo() > 0 || profile.getID() == "actives.throw_spear");
    }

    function isUsable()
    {
        if (this.m.Used || !this.skill.isUsable() || !this.hasVolleyAmmo())
            return false;
        local actor = this.getContainer().getActor();
        return !actor.isPlacedOnMap() || !actor.isEngagedInMelee();
    }

    function getTooltip()
    {
        local ret = this.getDefaultTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/ammo.png", text = "每次齐射消耗 1 份弹药。" });
        if (this.m.Used)
            ret.push({ id = 11, type = "text", icon = "ui/tooltips/warning.png", text = "本场已经施放。" });
        else if (!this.hasVolleyAmmo())
            ret.push({ id = 11, type = "text", icon = "ui/tooltips/warning.png", text = "需要装有弹药的弓或投掷武器。" });
        return ret;
    }

    function getAffectedTiles( _tile )
    {
        return ::PaleSovereign.area(_tile);
    }

    function onVerifyTarget( _origin, _tile )
    {
        local distance = _origin.getDistanceTo(_tile);
        if (distance < 2 || distance > 6 || !this.skill.onVerifyTarget(_origin, _tile))
            return false;
        local actor = this.getContainer().getActor();
        foreach (tile in this.getAffectedTiles(_tile))
            if (::PaleSovereign.isEnemy(actor, tile) && tile.getEntity().isAttackable())
                return true;
        return false;
    }

    function onAfterUpdate( _properties )
    {
        local shot = this.getAttackProfile();
        if (shot == null)
            return;
        this.m.DirectDamageMult = shot.getDirectDamage();
        this.m.DamageType = shot.m.DamageType;
        this.m.InjuriesOnBody = shot.m.InjuriesOnBody;
        this.m.InjuriesOnHead = shot.m.InjuriesOnHead;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (_skill != this)
            return;
        local shot = this.getAttackProfile();
        if (shot != null)
            shot.onAnySkillUsed(shot, _target, _properties);
        _properties.DamageTotalMult *= 0.8;
    }

    function onUse( _user, _tile )
    {
        if (this.m.Used || !this.onVerifyTarget(_user.getTile(), _tile) || !this.hasVolleyAmmo())
            return false;
        this.m.Used = true;
        local S = ::PaleSovereign;
        local weapon = this.getItem();
        local ammo = this.getVolleyAmmo();
        weapon.onUse(this);
        S.playBattleArt("arrow_rain", _tile, 40, 1.2);
        foreach (tile in this.getAffectedTiles(_tile))
            if (S.isEnemy(_user, tile) && tile.getEntity().isAttackable())
                this.attackEntity(_user, tile.getEntity(), false);
        if (ammo.getAmmoMax() > 0)
            ammo.consumeAmmo();
        else
            _user.getItems().unequip(weapon);
        return true;
    }
});
