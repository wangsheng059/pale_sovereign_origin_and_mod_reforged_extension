// 古帝祭司之魂：被冠军命中后致盲，近战技能、远程技能 −15，持续到目标的下一回合结束
this.pale_blind_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_blind";
        this.m.Name = "致盲";
        this.m.Description = "古老禁咒的冷光灼过双目，此人眼前只剩摇晃的幽蓝残影，连刀刃与盾缘都难以辨清。";
        this.m.Icon = "skills/pale_mark_blind.png";
        this.m.IconDisabled = "skills/pale_mark_blind_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorNegative("-15") + " 近战技能" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/ranged_skill.png", text = ::MSU.Text.colorNegative("-15") + " 远程技能" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeSkill -= 15;
        _properties.RangedSkill -= 15;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
