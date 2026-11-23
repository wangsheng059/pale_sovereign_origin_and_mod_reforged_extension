this.pale_jade_item <- ::inherit("scripts/items/item", {
    m = {},
    function create()
    {
        this.item.create();
        this.m.ID = "misc.pale_jade";
        this.m.Name = "古代魂玉";
        this.m.Description = "一块封存着古老战魂的阴冷碧石，触手如冰。\n\n用法：魂玉放在仓库里即可，点大地图顶栏名册按钮左侧的“亡灵营地”打开账簿，在主页选对应选项。\n· 冠军淬骨（冠军路线）：先把冠军的棺椁装进导师的饰品栏，再选“魂玉淬骨”，1 枚换随机 4 项属性各 +2，不限次数。\n· 晋升尸妖王（冠军路线）：荒坟守卫装在导师饰品栏、并肩打赢 5 场后，用 3 枚晋升。\n· 魂玉点睛（天灾路线）：选“魂玉点睛”，为一名常驻亡灵 8 项属性各 +2、生命再 +10，每名限 1 次。\n· 常驻亡灵升阶：每次 1 枚，在“常驻亡灵升阶”里选。\n· 古堡魂炉：停留 24 小时后，可为冠军或常驻亡灵淬骨。\n· 铁匠（冠军路线）：在城镇附近打开账簿遇到“黑铁的私活”时，可用 1 枚换 2 条缚魂锁链。\n\n天灾路线可在营地炼化 6 级以上的常驻亡灵换取魂玉。";
        this.m.Icon = "pale/jade.png";
        this.m.ItemType = ::Const.Items.ItemType.Misc;
        this.m.Value = 400;
    }

    // 1.6.21 出售价固定 400
    function getSellPrice()
    {
        return 400;
    }
});
