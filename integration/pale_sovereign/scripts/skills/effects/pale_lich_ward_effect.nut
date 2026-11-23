// 1.6.32 尸妖王在场时，导师受到的所有伤害 −15%
this.pale_lich_ward_effect <- ::inherit("scripts/skills/skill", {
    m = { Lich = null },
    function create()
    {
        this.m.ID = "effects.pale_lich_ward";
        this.m.Name = "冢王护持";
        this.m.Description = "尸妖王仍立在战场上，替导师挡下了一部分死亡。只要它还在场，导师受到的所有伤害 −15%。";
        this.m.Icon = "skills/pale_guard_shield.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function setLich( _entity )
    {
        this.m.Lich = ::MSU.asWeakTableRef(_entity);
    }

    function isLichPresent()
    {
        local lich = this.m.Lich;
        return lich != null && !::MSU.isNull(lich) && lich.isAlive() && !lich.isDying() && lich.isPlacedOnMap();
    }

    function isHidden()
    {
        return !this.isLichPresent();
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "受到的所有伤害 [color=" + ::Const.UI.Color.PositiveValue + "]-15%[/color]" });
        return ret;
    }

    function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
    {
        if (this.isLichPresent())
            _properties.DamageReceivedTotalMult *= ::PaleSovereign.LichWardMult;
    }
});
