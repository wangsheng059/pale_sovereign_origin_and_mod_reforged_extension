// 1.7.0 灵阶突破·玉髓重铸：每层伤害 +10%、行动点 +1（生命加成已写进冠军属性）
this.pale_breakthrough_effect <- ::inherit("scripts/skills/skill", {
    m = { Stacks = 0 },
    function create()
    {
        this.m.ID = "effects.pale_breakthrough";
        this.m.Name = "玉髓重铸";
        this.m.Icon = "skills/pale_breakthrough_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function getDescription()
    {
        return "熔进髓腔的魂玉让冠军跨过了生前的极限。玉髓重铸 " + this.m.Stacks + " 层：伤害 +" + (this.m.Stacks * 10) + "%，行动点 +" + this.m.Stacks + "（生命加成已计入属性）。";
    }

    function onUpdate( _properties )
    {
        _properties.DamageTotalMult *= 1.0 + 0.1 * this.m.Stacks;
        _properties.ActionPoints += this.m.Stacks;
    }
});
