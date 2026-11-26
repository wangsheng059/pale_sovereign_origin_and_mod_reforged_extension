// 墓穴挽歌：士气每低于稳定一级，造成的伤害 −10%，持续到目标的下一回合结束
this.pale_chant_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_chant";
        this.m.Name = "墓穴挽歌";
        this.m.Description = "低沉的挽歌在此人耳中回荡，越是害怕，手中的兵刃就越是无力。";
        this.m.Icon = "skills/pale_mark_dirge.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getMult()
    {
        local state = this.getContainer().getActor().getMoraleState();
        if (state == ::Const.MoraleState.Ignore)
            return 1.0;
        return ::Math.maxf(0.0, 1.0 - 0.1 * ::Math.max(0, ::Const.MoraleState.Steady - state));
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "士气每低于稳定一级，造成的伤害 " + ::MSU.Text.colorNegative("-10%") });
        ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.Turns + " 回合" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.DamageTotalMult *= this.getMult();
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
