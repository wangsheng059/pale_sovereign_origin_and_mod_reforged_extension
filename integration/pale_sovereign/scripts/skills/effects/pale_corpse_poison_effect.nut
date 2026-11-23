// 1.6.30 恶臭涂抹附加的尸毒：2 回合，行动点 -2、每回合疲劳恢复 -5
this.pale_corpse_poison_effect <- ::inherit("scripts/skills/skill", {
    m = { TurnsLeft = 2 },
    function create()
    {
        this.m.ID = "effects.pale_corpse_poison";
        this.m.Name = "尸毒";
        this.m.Description = "伤口里渗进了腌过多年的尸油，四肢沉重，呼吸里全是甜腥的腐味。";
        this.m.Icon = "skills/status_effect_54.png";
        this.m.IconMini = "status_effect_54_mini";
        this.m.Overlay = "status_effect_54";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsActive = false;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/action_points.png", text = "行动点 " + ::MSU.Text.colorNegative("-2") });
        ret.push({ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = "每回合疲劳恢复 " + ::MSU.Text.colorNegative("-5") });
        ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 回合" });
        return ret;
    }

    function resetTime()
    {
        this.m.TurnsLeft = 2;
    }

    function onAdded()
    {
        local actor = this.getContainer().getActor();
        if (actor.getFlags().has("undead"))
        {
            this.removeSelf();
            return;
        }
        if (!actor.isHiddenToPlayer())
            ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(actor) + " 中了尸毒");
    }

    function onUpdate( _properties )
    {
        _properties.ActionPoints -= 2;
        _properties.FatigueRecoveryRate -= 5;
    }

    function onTurnEnd()
    {
        if (--this.m.TurnsLeft <= 0)
            this.removeSelf();
    }
});
