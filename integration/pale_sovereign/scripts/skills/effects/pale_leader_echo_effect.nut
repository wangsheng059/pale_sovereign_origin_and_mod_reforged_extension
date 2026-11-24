// 1.7.0 执念共鸣：共享不到统领的特质时，伤害 +8%
this.pale_leader_echo_effect <- ::inherit("scripts/skills/skill", {
    m = { PaleShared = true },
    function create()
    {
        this.m.ID = "effects.pale_leader_echo";
        this.m.Name = "执念共鸣";
        this.m.Description = "身旁统领的魂火引着它一起燃烧。造成的伤害 +8%。";
        this.m.Icon = "skills/pale_leader_echo_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function onUpdate( _properties )
    {
        _properties.DamageTotalMult *= 1.08;
    }
});
