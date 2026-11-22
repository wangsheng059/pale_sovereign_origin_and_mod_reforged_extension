this.pale_gilded_bones <- ::inherit("scripts/items/armor/tattered_sackcloth", {
    m = {},

    function create()
    {
        this.tattered_sackcloth.create();
        this.m.ID = "armor.pale_gilded_bones";
        this.m.Name = "镀金骨骸";
        this.m.Description = "魂炉在裸露的骨架上浇铸的一层薄金，能挡下 20 点伤害。换上真正的身甲后，镀金会转到新身甲上，使其耐久 +20。";
        this.m.ConditionMax = 1;
        this.m.Condition = 1;
        this.m.IsDroppedAsLoot = false;
        this.updateVariant();
    }

    function updateVariant()
    {
        this.m.Icon = "pale/gilded_bones.png";
        this.m.IconLarge = "pale/gilded_bones_large.png";
        this.m.Sprite = "pale_gilded_bones";
        this.m.SpriteDamaged = "pale_gilded_bones_damaged";
        this.m.SpriteCorpse = "pale_gilded_bones_dead";
    }
});
