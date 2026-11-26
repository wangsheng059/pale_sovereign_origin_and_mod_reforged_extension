this.pale_prey_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_prey";
        this.m.Name = "勇士猎物";
        this.m.Description = "此人已被法杖的魂火锁定，成为了亡者共同的猎物。";
        this.m.Icon = "skills/pale_prey_status.png";
        this.m.IconDisabled = "skills/pale_prey_status_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "所有友方亡灵（勇士、常驻亡灵、复活与召唤的亡灵）优先攻击此目标" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/regular_damage.png", text = "导师与所有友方亡灵攻击此目标时命中 " + ::MSU.Text.colorNegative("+10") + "、伤害 " + ::MSU.Text.colorNegative("+20%") });
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.Turns + " 回合" });
        return ret;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
