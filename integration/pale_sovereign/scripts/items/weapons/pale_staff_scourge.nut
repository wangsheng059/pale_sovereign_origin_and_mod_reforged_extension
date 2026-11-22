this.pale_staff_scourge <- ::inherit("scripts/items/weapons/pale_staff", {
    m = {},
    function create()
    {
        this.pale_staff.create();
        this.m.ID = "weapon.pale_staff_scourge";
        this.m.Name = "千魂法杖";
        this.m.Description = "缠绕杖身的符环已快盛不住其中翻涌的亡魂低语。衰弱术、岁月诅咒与尸爆的施法距离增加 1 格，衰弱术将波及目标周围的所有敌人。";
        this.m.PaleForm = "_scourge";
        // 1.6.15：蜕变后成为红装（著名武器），价值 3000，可获得装备融合随机属性
        this.m.ItemType = this.m.ItemType | ::Const.Items.ItemType.Named;
        this.m.Value = 3000;
        this.updatePaleIcons();
    }
});
