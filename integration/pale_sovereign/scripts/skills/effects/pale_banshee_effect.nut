this.pale_banshee_effect <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_banshee";
        this.m.Name = "夜半哀号";
        this.m.Description = "女妖的哀号动摇了这名战士。首回合决心 −5。";
        this.m.Icon = "skills/pale_weaken_effect.png";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function onUpdate( _properties )
    {
        _properties.Bravery -= 5;
    }

    function onRoundStart()
    {
        if (::Time.getRound() > 1)
            this.removeSelf();
    }
});
