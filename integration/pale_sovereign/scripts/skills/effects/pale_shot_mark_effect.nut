// 1.7.0 被尸弹砸中的标记（2 回合，死兆导引用）
this.pale_shot_mark_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 2 },
    function create()
    {
        this.m.ID = "effects.pale_shot_mark";
        this.m.Name = "尸弹砸中";
        this.m.Description = "刚被一具防腐尸骸砸中，身上还沾着盐浆。";
        this.m.Icon = "skills/pale_corpse_shot.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
        this.m.IsHidden = true;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns <= 0)
            this.removeSelf();
    }
});
