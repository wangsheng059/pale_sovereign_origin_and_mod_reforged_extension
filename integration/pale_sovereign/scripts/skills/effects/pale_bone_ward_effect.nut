// 1.7.0 玉骨盾（千魂回响）：3 回合内伤害 +15%（头、身各 +30 护甲在唤起时已加上，召唤物战后消散）
this.pale_bone_ward_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 3 },
    function create()
    {
        this.m.ID = "effects.pale_bone_ward";
        this.m.Name = "玉骨盾";
        this.m.Description = "千魂法杖的回响在新唤起的骨肉外凝成一层碧色的骨盾。伤害 +15%，头、身各多 30 点护甲。";
        this.m.Icon = "skills/pale_guard_shield.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function onUpdate( _properties )
    {
        _properties.DamageTotalMult *= 1.15;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
