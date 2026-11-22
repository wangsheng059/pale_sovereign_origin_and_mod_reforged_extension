this.pale_gilded_skull <- ::inherit("scripts/items/helmets/hood", {
    m = {},

    function create()
    {
        this.hood.create();
        this.m.ID = "helmet.pale_gilded_skull";
        this.m.Name = "镀金颅骨";
        this.m.Description = "魂炉在颅骨表面浇铸的一层薄金，能挡下 20 点伤害。换上真正的头盔后，镀金会转到新头盔上，使其耐久 +20。";
        this.m.ConditionMax = 1;
        this.m.Condition = 1;
        this.m.IsDroppedAsLoot = false;
        this.updateVariant();
    }

    function updateVariant()
    {
        this.m.Icon = "pale/gilded_skull.png";
        this.m.IconLarge = "pale/gilded_skull_large.png";
        this.m.Sprite = "pale_gilded_skull";
        this.m.SpriteDamaged = "pale_gilded_skull_damaged";
        this.m.SpriteCorpse = "pale_gilded_skull_dead";
    }
});
