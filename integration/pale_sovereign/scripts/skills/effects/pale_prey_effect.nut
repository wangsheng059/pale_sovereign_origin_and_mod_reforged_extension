this.pale_prey_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_prey";
        this.m.Name = "冠军猎物";
        this.m.Description = "此人已被骸骨权杖的魂火锁定，成为了导师与冠军共同的猎物。导师与冠军攻击此目标时命中 +10，伤害 +20%。";
        this.m.Icon = "skills/pale_prey.png";
        this.m.IconDisabled = "skills/pale_prey_sw.png";
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
