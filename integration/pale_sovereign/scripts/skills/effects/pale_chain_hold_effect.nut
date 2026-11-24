// 1.7.0 锁链牵制：被缚魂锁链标记的强敌无法溃逃、近战防御 −10，对导师造成的伤害 −20%
this.pale_chain_hold_effect <- ::inherit("scripts/skills/skill", {
    m = {},
    function create()
    {
        this.m.ID = "effects.pale_chain_hold";
        this.m.Name = "锁链牵制";
        this.m.Description = "黑铁锁链缠住了此人的残魂。无法溃逃，近战防御 −10，对亡灵法师导师造成的伤害 −20%。";
        this.m.Icon = "skills/pale_mark_prey.png";
        this.m.IconDisabled = "skills/pale_mark_prey_sw.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeDefense -= 10;
    }

    function onAnySkillUsed( _skill, _targetEntity, _properties )
    {
        if (_targetEntity != null && !::MSU.isNull(_targetEntity) && ::PaleSovereign.isChief(_targetEntity))
            _properties.DamageTotalMult *= 0.8;
    }

    function onTurnStart()
    {
        local actor = this.getContainer().getActor();
        if (actor.getMoraleState() == ::Const.MoraleState.Fleeing)
            actor.setMoraleState(::Const.MoraleState.Breaking);
    }
});
