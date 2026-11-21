this.pale_tier_status <- ::inherit("scripts/skills/skill", {
    m = { Kind = "", Turns = 2 },

    function create()
    {
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.Order = ::Const.SkillOrder.Any;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function configure( _kind )
    {
        this.m.Kind = _kind;
        this.m.ID = "effects.pale_" + _kind + "_status";
        this.m.Icon = "skills/pale_" + _kind + "_effect.png";
        this.m.IconDisabled = this.m.Icon;
        switch (_kind)
        {
            case "grave_blade":
                this.m.Name = "墓之刃";
                this.m.Description = "受到的伤害 +10%。";
                break;
            case "bone_break":
                this.m.Name = "断骨";
                this.m.Description = "近战防御 −5。";
                break;
            case "dead_command":
                this.m.Name = "亡者号令";
                this.m.Description = "近战技能 +5，对敌人造成的伤害 +10%。";
                break;
            case "stench":
                this.m.Name = "腐臭";
                this.m.Description = "被尸山巨像的腐臭光环波及，决心 −5。";
                this.m.Turns = 1;
                break;
        }
    }

    function onUpdate( _properties )
    {
        switch (this.m.Kind)
        {
            case "grave_blade":
                _properties.DamageReceivedTotalMult *= 1.1;
                break;
            case "bone_break":
                _properties.MeleeDefense -= 5;
                break;
            case "dead_command":
                _properties.MeleeSkill += 5;
                break;
            case "stench":
                _properties.Bravery -= 5;
                break;
        }
    }

    function onAnySkillUsed( _skill, _target, _properties )
    {
        if (this.m.Kind == "dead_command" && _skill.isAttack()
            && (_target == null || !_target.isAlliedWith(this.getContainer().getActor())))
            _properties.DamageTotalMult *= 1.1;
    }

    function onRefresh()
    {
        this.m.Turns = this.m.Kind == "stench" ? 1 : 2;
    }

    function getTooltip()
    {
        local ret = this.skill.getTooltip();
        if (this.m.Kind != "dead_command")
            ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "剩余 " + this.m.Turns + " 回合。" });
        return ret;
    }

    function onTurnEnd()
    {
        if (this.m.Kind != "dead_command" && --this.m.Turns <= 0)
            this.removeSelf();
    }
});
