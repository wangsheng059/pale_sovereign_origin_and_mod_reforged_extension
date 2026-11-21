this.pale_staff_scourge <- ::inherit("scripts/items/weapons/pale_staff", {
    m = {},
    function create()
    {
        this.pale_staff.create();
        this.m.ID = "weapon.pale_staff_scourge";
        this.m.Name = "千魂法杖";
        this.m.Description = "符环已盛不下其中的低语。衰弱术、岁月诅咒和尸爆的施法距离增加 1 格。";
        this.m.PaleForm = "_scourge";
        this.updatePaleIcons();
    }
});
