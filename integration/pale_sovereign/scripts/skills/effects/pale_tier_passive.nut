this.pale_tier_passive <- ::inherit("scripts/skills/skill", {
    m = { PaleTierSkill = true, TierTalent = "" },

    function create()
    {
        if (this.m.DamageType == null)
            this.m.DamageType = ::MSU.Class.DamageType();
        this.m.Type = ::Const.SkillType.StatusEffect;
        this.m.Order = ::Const.SkillOrder.Any;
        this.m.IsSerialized = false;
        this.m.IsRemovedAfterBattle = false;
        this.m.IsStacking = false;
    }

    function configure( _key )
    {
        local definition = ::PaleSovereign.TierTalents[_key];
        this.m.TierTalent = _key;
        this.m.ID = ::PaleSovereign.tierTalentID(_key);
        this.m.Name = definition.Name;
        this.m.Description = definition.Flavor + "\n" + definition.Description;
        this.m.Icon = "skills/pale_" + _key + ".png";
        this.m.IconDisabled = "skills/pale_" + _key + "_sw.png";
    }
});
