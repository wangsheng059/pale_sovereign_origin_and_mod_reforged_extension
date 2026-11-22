this.pale_staff_champion <- ::inherit("scripts/items/weapons/pale_staff", {
    m = {},
    function create()
    {
        this.pale_staff.create();
        this.m.ID = "weapon.pale_staff_champion";
        this.m.Name = "骸骨权杖";
        this.m.Description = "镀铜的颅骨已将冠军誓约深深烙进杖身，每一次挥动都带着君临沙场的威压。导师与冠军将合力追猎权杖标定的猎物。";
        this.m.PaleForm = "_champion";
        this.m.RegularDamage = 75;
        this.m.RegularDamageMax = 95;
        // 1.6.15：蜕变后成为红装（著名武器），价值 3000，可获得装备融合随机属性
        this.m.ItemType = this.m.ItemType | ::Const.Items.ItemType.Named;
        this.m.Value = 3000;
        this.updatePaleIcons();
    }
});
