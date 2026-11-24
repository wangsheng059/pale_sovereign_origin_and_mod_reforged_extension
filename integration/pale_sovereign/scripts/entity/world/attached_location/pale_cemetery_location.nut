this.pale_cemetery_location <- ::inherit("scripts/entity/world/attached_location/stone_watchtower_location", {
    m = {},

    function create()
    {
        this.stone_watchtower_location.create();
        this.m.ID = "attached_location.pale_cemetery";
        this.m.Name = "墓园";
        this.m.Sprite = "pale_world_cemetery";
        this.m.SpriteDestroyed = "pale_world_cemetery_ruins";
        this.m.Description = "城郊的墓园日夜不闭，新死的人从这里归入导师的队列。每日为战团送来 3 点防腐尸骸；亡灵天灾路线下，每天还有 15% 的概率从新坟里掘出 1 枚古代魂玉。";
    }
});
