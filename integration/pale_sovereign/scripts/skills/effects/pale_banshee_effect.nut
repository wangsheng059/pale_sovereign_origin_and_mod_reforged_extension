this.pale_banshee_effect <- ::inherit("scripts/skills/skill", {
    m = { Penalty = 5 },
    function create()
    {
        this.m.ID = "effects.pale_banshee";
        this.m.Name = "夜半哀号";
        this.m.Description = "女妖的哀号从远处传来，钻进了这名战士的骨缝。整场战斗决心降低，夜里更甚。";
        this.m.Icon = "skills/pale_mark_wail.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/bravery.png", text = ::MSU.Text.colorNegative("-" + this.m.Penalty) + " 决心" });
        return ret;
    }

    function onUpdate( _properties )
    {
        _properties.Bravery -= this.m.Penalty;
    }
});
