this.pale_staff_scourge <- ::inherit("scripts/items/weapons/pale_staff", {
    m = {},
    function create()
    {
        this.pale_staff.create();
        this.m.ID = "weapon.pale_staff_scourge";
        this.m.Name = "千魂法杖";
        this.m.Description = "缠绕杖身的符环已快盛不住其中翻涌的亡魂低语。衰弱术、岁月诅咒与尸爆的施法距离增加 1 格，衰弱术将波及目标周围的所有敌人。";
        this.m.PaleForm = "_scourge";
        this.updatePaleIcons();
    }
});
