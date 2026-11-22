this.pale_bound_soul_effect <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_bound_soul";
        this.m.Name = "缚魂锁链";
        this.m.Description = "黑铁锁链已锚定这个灵魂。它的头颅若能保全，导师可以在胜利后把魂魄注入冠军。";
        this.m.Icon = "skills/pale_mark_bound.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsStacking = false;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }
});
