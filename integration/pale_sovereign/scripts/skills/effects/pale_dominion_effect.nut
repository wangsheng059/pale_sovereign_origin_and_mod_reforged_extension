// 飞升仪式（天灾）：导师复活的单位 +20 生命、+10% 伤害
this.pale_dominion_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_dominion";
        this.m.Name = "苍白主宰的余威";
        this.m.Description = "苍白主宰的魂火在这具躯壳里燃烧。";
        this.m.Icon = "skills/pale_dominion.png";
        this.m.IconDisabled = "skills/pale_dominion_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/health.png", text = ::MSU.Text.colorPositive("+20") + " 生命" });
        ret.push({ id = 11, type = "text", icon = "ui/icons/regular_damage.png", text = ::MSU.Text.colorPositive("+10%") + " 伤害" });
        return ret;
    }

    function onAdded()
    {
        local actor = this.getContainer().getActor();
        this.getContainer().update();
        actor.setHitpoints(::Math.min(actor.getHitpointsMax(), actor.getHitpoints() + 20));
    }

    function onUpdate( _properties )
    {
        _properties.Hitpoints += 20;
        _properties.DamageTotalMult *= 1.1;
    }
});
