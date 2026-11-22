this.pale_signet <- ::inherit("scripts/items/accessory/accessory", {
    m = {},

    function create()
    {
        this.accessory.create();
        this.m.ID = "accessory.pale_signet";
        this.m.Name = "苍白印戒";
        this.m.Description = "导师将古老的符文篆刻在印戒的内侧。决心 +10，每回合额外恢复 2 疲劳，免疫魅惑和亡灵支配。";
        this.m.Icon = "pale/signet.png";
        this.m.IconLarge = this.m.Icon;
        this.m.Value = 1250;
    }

    function onUpdateProperties( _properties )
    {
        this.accessory.onUpdateProperties(_properties);
        _properties.Bravery += 10;
        _properties.FatigueRecoveryRate += 2;
    }
});
