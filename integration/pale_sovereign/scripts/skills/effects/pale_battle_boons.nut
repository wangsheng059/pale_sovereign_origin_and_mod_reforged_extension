this.pale_battle_boons <- ::inherit("scripts/skills/skill", {
    function create()
    {
        this.m.ID = "effects.pale_battle_boons";
        this.m.Name = "亡者的号令";
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.IsHidden = true;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = true;
    }

    function onRoundStart()
    {
        this.getContainer().update();
    }

    function onUpdate( _properties )
    {
        local actor = this.getContainer().getActor();
        ::PaleSovereign.battleBoon(actor, _properties);
    }
});
