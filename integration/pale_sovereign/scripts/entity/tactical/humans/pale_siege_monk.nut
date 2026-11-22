this.pale_siege_monk <- ::inherit("scripts/entity/tactical/humans/standard_bearer", {
    m = {},

    function create()
    {
        this.standard_bearer.create();
        this.m.Name = "随军僧侣";
    }

    function onInit()
    {
        this.standard_bearer.onInit();
        this.addSprite("pale_reliquary").setBrush("pale_reliquary_monk");
    }
});
