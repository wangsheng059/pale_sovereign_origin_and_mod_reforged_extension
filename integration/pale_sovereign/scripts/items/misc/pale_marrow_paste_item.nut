// 1.7.0 急救骨髓膏：亡灵营地里用 2 点防腐尸骸制作，放进背包后战斗中可对相邻的常驻亡灵或勇士使用
this.pale_marrow_paste_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_marrow_paste";
        this.m.Name = "急救骨髓膏";
        this.m.Description = "防腐尸骸熬出的骨髓与粗盐、松脂调成的黑膏，抹在亡灵的裂口上，能让断骨与烂肉重新咬合。";
        this.m.Icon = "consumables/pale_marrow_paste.png";
        this.m.SlotType = ::Const.ItemSlot.Bag;
        this.m.ItemType = ::Const.Items.ItemType.Misc;
        this.m.IsAllowedInBag = true;
        this.m.IsDroppedAsLoot = true;
        this.m.Value = 60;
    }

    function getTooltip()
    {
        local ret = [
            { id = 1, type = "title", text = this.getName() },
            { id = 2, type = "description", text = this.getDescription() },
            { id = 66, type = "text", text = this.getValueString() },
            { id = 3, type = "image", image = this.getIcon() },
            { id = 10, type = "text", icon = "ui/icons/health.png", text = "放进背包后，战斗中花 4 行动点对相邻的常驻亡灵或勇士使用：恢复 25% 最大生命，清除流血、酸液、燃烧" },
            { id = 11, type = "text", icon = "ui/icons/special.png", text = "盗墓贼、解剖师、死灵法师、亡灵法师导师使用时行动点 −1，治疗量 +25%" }
        ];
        return ret;
    }

    function onPutIntoBag()
    {
        this.item.onPutIntoBag();
        local skill = ::new("scripts/skills/actives/pale_marrow_paste_skill");
        skill.setItem(this);
        this.addSkill(skill);
    }

    function playInventorySound( _eventType )
    {
        ::Sound.play("sounds/combat/armor_leather_impact_03.wav", ::Const.Sound.Volume.Inventory);
    }
});
