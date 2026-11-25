this.pale_bone_lantern <- ::inherit("scripts/items/item", {
    function create()
    {
        this.item.create();
        this.m.ID = "tool.pale_bone_lantern";
        this.m.Name = "守夜人的骨灯";
        this.m.Description = "骨制提灯。无视夜战的视野与远程命中惩罚，夜战中决心 +6，命中头部概率 +10 个百分点。占用箭袋位。";
        this.m.Icon = "pale/bone_lantern.png";
        this.m.IconLarge = this.m.Icon;
        this.m.SlotType = ::Const.ItemSlot.Ammo;
        this.m.ItemType = ::Const.Items.ItemType.Tool;
        this.m.Value = 500;
    }

    // Keep item inheritance for save compatibility while exposing safe ammo stubs for callers inspecting ItemSlot.Ammo.
    function getAmmo()
    {
        return 0;
    }

    function getAmmoMax()
    {
        return 0;
    }

    function getAmmoCost()
    {
        return 0;
    }

    function getAmmoType()
    {
        return -1;
    }

    function setAmmo( _a )
    {
    }

    function consumeAmmo()
    {
    }

    function isAmmoFull()
    {
        return true;
    }

    function onEquip()
    {
        this.item.onEquip();
        this.addSkill(::new("scripts/skills/effects/pale_lantern_effect"));
    }
});
