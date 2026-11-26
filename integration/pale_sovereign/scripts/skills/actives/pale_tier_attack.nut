this.pale_tier_attack <- ::inherit("scripts/skills/effects/pale_tier_passive", {
    m = { DamageLow = 0, DamageHigh = 0, ArmorEfficiency = 1.0 },

    function create()
    {
        this.pale_tier_passive.create();
        this.m.Type = ::Const.SkillType.Active;
        this.m.Order = ::Const.SkillOrder.OffensiveTargeted + 100;
        this.m.IsActive = true;
        this.m.IsTargeted = true;
        this.m.IsAttack = true;
        this.m.IsWeaponSkill = false;
        this.m.IsIgnoredAsAOO = true;
        this.m.IsShowingProjectile = false;
        this.m.MinRange = 1;
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (_skill != this)
            return;
        // Character properties already include contributions from the equipped weapon.
        local weapon = this.getContainer().getActor().getMainhandItem();
        if (::MSU.isKindOf(weapon, "weapon"))
        {
            _properties.DamageArmorMult = weapon.m.ArmorDamageMult > 0
                ? _properties.DamageArmorMult / weapon.m.ArmorDamageMult : 1.0;
            _properties.DamageDirectAdd -= weapon.m.DirectDamageAdd;
            _properties.HitChance[::Const.BodyPart.Head] -= weapon.m.ChanceToHitHead;
        }
        _properties.DamageRegularMin = this.m.DamageLow;
        _properties.DamageRegularMax = this.m.DamageHigh;
        _properties.DamageArmorMult *= this.m.ArmorEfficiency;
    }
});
