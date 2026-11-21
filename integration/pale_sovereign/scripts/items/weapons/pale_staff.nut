this.pale_staff <- ::inherit("scripts/items/weapons/weapon", {
    m = { PaleForm = "" },
    function create()
    {
        this.weapon.create();
        this.m.ID = "weapon.pale_staff";
        this.m.Name = "初生骷髅法杖";
        this.m.Description = "铁箍上的裂痕中透出一丝魂火。首席的法杖，与主人一同成长。";
        this.m.SlotType = ::Const.ItemSlot.Mainhand;
        this.m.BlockedSlotType = ::Const.ItemSlot.Offhand;
        this.m.WeaponType = ::Const.Items.WeaponType.Polearm;
        this.m.ItemType = ::Const.Items.ItemType.Weapon | ::Const.Items.ItemType.MeleeWeapon | ::Const.Items.ItemType.TwoHanded | ::Const.Items.ItemType.Quest;
        this.m.RangeMin = 1;
        this.m.RangeMax = 2;
        this.m.RangeIdeal = 2;
        this.m.Reach = 6;
        this.m.Condition = 52.0;
        this.m.ConditionMax = 52.0;
        this.m.StaminaModifier = -6;
        this.m.RegularDamage = 20;
        this.m.RegularDamageMax = 30;
        this.m.DirectDamageMult = 0.4;
        this.m.ArmorDamageMult = 0.6;
        this.m.ChanceToHitHead = 0;
        this.m.Value = 0;
        this.m.IsAllowedInBag = false;
        this.updatePaleIcons();
    }

    function updatePaleIcons()
    {
        local name = "pale_staff" + this.m.PaleForm;
        this.m.Icon = "pale/" + name + "_70.png";
        this.m.IconLarge = "pale/" + name + "_140.png";
        this.m.ArmamentIcon = name;
    }

    function getPaleResolve()
    {
        return this.m.PaleForm == "_scourge" ? 12 : 6;
    }

    function isSetForSale()
    {
        return false;
    }

    function getTooltip()
    {
        local ret = this.weapon.getTooltip();
        ret.push({ id = 17, type = "text", icon = "ui/icons/bravery.png", text = "决心 +" + this.getPaleResolve() + "。仅首席可装备。" });
        return ret;
    }

    function onUpdateProperties( _properties )
    {
        this.weapon.onUpdateProperties(_properties);
        _properties.Bravery += this.getPaleResolve();
    }

    function onEquip()
    {
        this.weapon.onEquip();
        local strike = ::new("scripts/skills/actives/pale_soul_strike");
        strike.m.DirectDamageMult = this.m.DirectDamageMult;
        strike.m.Champion = this.m.PaleForm == "_champion";
        if (strike.m.Champion)
        {
            strike.m.ActionPointCost = 5;
            strike.m.FatigueCost = 12;
        }
        this.addSkill(strike);
        local weaken = ::new("scripts/skills/actives/pale_weaken");
        weaken.m.Champion = strike.m.Champion;
        weaken.m.Scourge = this.m.PaleForm == "_scourge";
        weaken.m.MaxRange = weaken.m.Scourge ? 6 : 5;
        this.addSkill(weaken);
    }
});
