this.pale_jade_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_jade";
        this.m.Name = "古代魂玉";
        this.m.Description = "一块封存着古老战魂的阴冷碧石，触手如冰。冠军路线可在亡灵营地用 3 枚将荒坟守卫晋升为尸妖王，或用 1 枚为冠军淬骨（随机 4 项属性各 +2，不限次数）；天灾路线可为一名常驻亡灵点睛（8 项属性各 +2、生命再 +10），也可在营地炼化 6 级以上的常驻亡灵换取魂玉；也能交予懂行的铁匠换取两条缚魂锁链。";
        this.m.Icon = "pale/jade.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc | ::Const.Items.ItemType.Quest;
        this.m.Value = 0;
    }
});
