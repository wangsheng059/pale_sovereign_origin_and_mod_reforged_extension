// 1.7.0 苍白尸瘴（玉毒尸弹）：近战防御 −5，持续到自己的下一个回合结束
this.pale_jade_miasma_effect <- ::inherit("scripts/skills/skill", {
    m = { Turns = 1 },
    function create()
    {
        this.m.ID = "effects.pale_jade_miasma";
        this.m.Name = "苍白尸瘴";
        this.m.Description = "吸进去的尸瘴让人头晕目眩，举盾都慢了半拍。近战防御 −5。";
        this.m.Icon = "skills/pale_corpse_shot.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
        this.m.IsStacking = false;
    }

    function onUpdate( _properties )
    {
        _properties.MeleeDefense -= 5;
    }

    function onTurnEnd()
    {
        if (--this.m.Turns < 0)
            this.removeSelf();
    }
});
