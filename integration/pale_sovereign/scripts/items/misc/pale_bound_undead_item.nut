// 1.6.8 受缚亡灵：攻破亡灵营地后得到，在仓库里右键使用可收编为常驻亡灵，也可卖 100 克朗
this.pale_bound_undead_item <- ::inherit("scripts/items/item", {
    m = { PaleKind = "skeleton" },
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_bound_undead";
        this.m.Icon = "tools/bgp_necro_vessel_70x70.png";
        this.m.SlotType = ::Const.ItemSlot.None;
        this.m.ItemType = ::Const.Items.ItemType.Usable;
        this.m.IsUsable = true;
        this.m.IsAllowedInBag = false;
        this.m.IsDroppedAsLoot = false;
        this.m.Value = 100;
        local kinds = ["skeleton", "archer", "zombie"];
        this.m.PaleKind = kinds[::Math.rand(0, kinds.len() - 1)];
        this.refresh();
    }

    function getKindName()
    {
        local s = ::PaleSovereign;
        return ("UndeadKinds" in s) && this.m.PaleKind in s.UndeadKinds ? s.UndeadKinds[this.m.PaleKind].Name : "亡灵";
    }

    function refresh()
    {
        this.m.Name = "受缚的" + this.getKindName();
        this.m.Description = "从亡灵营地的废墟里拖出来的一具" + this.getKindName() + "，魂火被锁在一只封魂瓮里，还没认主。在仓库中右键使用可将其收编为常驻亡灵（属性、天赋与特质随机），也可以在商店卖掉。";
    }

    function getSellPrice()
    {
        return 100;
    }

    function getTooltip()
    {
        local ret = [
            { id = 1, type = "title", text = this.getName() },
            { id = 2, type = "description", text = this.getDescription() },
            { id = 66, type = "text", text = this.getValueString() },
            { id = 3, type = "image", image = this.getIcon() },
            { id = 65, type = "text", icon = "ui/icons/special.png", text = "右键使用：收编为常驻亡灵（需要名册空位；亡灵冠军最多 3 名常驻亡灵）" }
        ];
        return ret;
    }

    function onUse( _actor, _item = null )
    {
        return ::PaleSovereign.recruitBoundUndead(this);
    }

    function onSerialize( _out )
    {
        this.item.onSerialize(_out);
        _out.writeString(this.m.PaleKind);
    }

    function onDeserialize( _in )
    {
        this.item.onDeserialize(_in);
        this.m.PaleKind = _in.readString();
        this.refresh();
    }
});
