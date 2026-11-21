this.pale_battle_standard <- ::inherit("scripts/items/tools/player_banner", {
    m = {},

    function create()
    {
        this.player_banner.create();
        this.m.ID = "weapon.pale_battle_standard";
        this.m.Name = "苍白战旗";
        this.m.Variant = 90;
        this.m.RegularDamage = 50;
        this.m.RegularDamageMax = 70;
        this.m.Description = "以古墓裹尸布缝成的战旗。保留战旗的决心光环，4 格内己方亡灵额外获得 +5 近战技能与 +5 近战防御。夜战时持有者决心 +5。";
        this.updateVariant();
    }

    function getName()
    {
        return "苍白战旗";
    }

    function updateVariant()
    {
        this.m.Icon = "weapons/banner/banner_90_70x70.png";
        this.m.IconLarge = "weapons/banner/banner_90.png";
    }

    function onUpdateProperties( _properties )
    {
        this.player_banner.onUpdateProperties(_properties);
        if (::PaleSovereign.Battle != null && ::PaleSovereign.Battle.Night)
            _properties.Bravery += 5;
    }
});
