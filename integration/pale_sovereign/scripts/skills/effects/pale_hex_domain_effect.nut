// 禁咒领域：近战技能、远程技能、决心 −10，持续到目标的下一回合结束
this.pale_hex_domain_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_hex_domain";
        this.m.Name = "禁咒领域";
        this.m.Description = "古老的禁咒在此人耳边低语，手脚和胆气都不再听使唤。";
        this.m.Icon = "skills/pale_mark_domain.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorNegative("-10") + " 近战技能" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/ranged_skill.png", text = ::MSU.Text.colorNegative("-10") + " 远程技能" });
        ret.push({ id = 12, type = "text", icon = "ui/icons/bravery.png", text = ::MSU.Text.colorNegative("-10") + " 决心" });
        ret.push({ id = 13, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.Turns + " 回合" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeSkill -= 10;
        _properties.RangedSkill -= 10;
        _properties.Bravery -= 10;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
