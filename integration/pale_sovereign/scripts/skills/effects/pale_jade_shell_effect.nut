// 1.7.0 灵阶突破·不朽玉壳：每场第一次致命伤改为锁定 20% 生命（判定在 jade_ops.nut 的 kill 钩子）
this.pale_jade_shell_effect <- ::inherit("scripts/skills/skill", {
    m = { Spent = false },
    function create()
    {
        this.m.ID = "effects.pale_jade_shell";
        this.m.Name = "不朽玉壳";
        this.m.Description = "骨架外结着一层冷玉般的薄壳。每场战斗第一次受到致命伤害时免于死亡，生命锁定为 20%，清除眩晕、定身与流血，并在 1 回合内受到的伤害 −50%。";
        this.m.Icon = "skills/pale_jade_shell_status.png";
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
