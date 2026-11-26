// 1.7.0 震慑（玉骨威压）：2 回合内造成的伤害 −50%
this.pale_daunted_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_daunted";
        this.m.Name = "震慑";
        this.m.Description = "勇士骨缝里的魂玉压得此人喘不过气，挥出的兵器软弱无力。";
        this.m.Icon = "skills/pale_daunted_status.png";
        this.m.IconDisabled = "skills/pale_daunted_status_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/regular_damage.png", text = "造成的伤害 [color=" + ::Const.UI.Color.NegativeValue + "]-50%[/color]，剩余 " + this.m.Turns + " 回合" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.DamageTotalMult *= 0.5;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
