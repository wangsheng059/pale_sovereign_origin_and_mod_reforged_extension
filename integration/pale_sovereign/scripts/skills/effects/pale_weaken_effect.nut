this.pale_weaken_effect <- ::inherit("scripts/skills/skill", {
    m = { Penalty = 2, Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_weaken";
        this.m.Name = "衰弱";
        this.m.Description = "阴冷的魂火缠绕四肢，每一次呼吸与格挡都显得格外吃力。";
        this.m.Icon = "skills/pale_mark_weak.png";
        this.m.IconDisabled = "skills/pale_mark_weak_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/melee_skill.png", text = "近战技能、远程技能、近战防御各 −" + this.m.Penalty + "，剩余 " + this.m.Turns + " 回合。" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeSkill -= this.m.Penalty;
        _properties.RangedSkill -= this.m.Penalty;
        _properties.MeleeDefense -= this.m.Penalty;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
