// 1.7.0 玉骨盾（千魂回响）：3 回合内伤害 +15%（头、身各 +30 护甲在唤起时已加上，召唤物战后消散）
this.pale_bone_ward_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 3 },
    function create()
    {
        this.m.ID = "effects.pale_bone_ward";
        this.m.Name = "玉骨盾";
        this.m.Description = "【千魂回响】在新唤起的骨肉外凝成一层碧色的骨盾。";
        this.m.Icon = "skills/pale_bone_ward_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "伤害 " + ::MSU.Text.colorPositive("+15%") + "（还剩 " + this.m.Turns + " 个回合）" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/armor_body.png", text = "唤起时穿戴的头甲、身甲已各获得 " + ::MSU.Text.colorPositive("+30") + " 点额外护甲（战后消散）" });
        return ret;
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
