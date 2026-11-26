// 1.7.0 苍白尸瘴（玉毒尸弹）：近战防御 −5，持续到自己的下一个回合结束
this.pale_jade_miasma_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_jade_miasma";
        this.m.Name = "苍白尸瘴";
        this.m.Description = "吸进去的尸瘴让人头晕目眩，举盾都慢了半拍。";
        this.m.Icon = "skills/pale_jade_miasma_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/melee_defense.png", text = ::MSU.Text.colorNegative("-5") + " 近战防御" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "还剩 " + (this.m.Turns + 1) + " 回合" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeDefense -= 5;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns < 0)
            this.removeSelf();
    }
});
