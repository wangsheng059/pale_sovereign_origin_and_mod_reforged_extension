// 1.7.0 锁魂者破限·玉魂不灭（判定在 jade_ops.nut 的 kill 钩子）
this.pale_jade_undying_effect <- ::inherit("scripts/skills/skill", {
    m = { Spent = false },
    function create()
    {
        this.m.ID = "effects.pale_jade_undying";
        this.m.Name = "玉魂不灭";
        this.m.Description = "每场战斗第一次被击倒时，只要导师仍在场，就以 35% 生命重新站起。身上的缚魂镣铐尚未生效时合并触发：50% 生命、恢复 25 疲劳，2 回合内受到的伤害 −50%。";
        this.m.Icon = "skills/pale_jade_undying_status.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function isHidden()
    {
        return this.m.Spent;
    }
});
