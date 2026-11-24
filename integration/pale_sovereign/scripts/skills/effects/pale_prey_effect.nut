this.pale_prey_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_prey";
        this.m.Name = "冠军猎物";
        this.m.Description = "此人已被法杖的魂火锁定，成为了亡者共同的猎物。所有友方亡灵（冠军、常驻亡灵、复活与召唤的亡灵）会优先攻击此目标；它们和导师攻击它时命中 +10，伤害 +20%。";
        this.m.Icon = "skills/pale_mark_prey.png";
        this.m.IconDisabled = "skills/pale_mark_prey_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
