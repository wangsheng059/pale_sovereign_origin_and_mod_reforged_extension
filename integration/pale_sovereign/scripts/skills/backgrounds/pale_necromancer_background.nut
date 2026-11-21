this.pale_necromancer_background <- ::inherit("scripts/skills/backgrounds/bgp_necromancer_background", {
    m = {},
    function create()
    {
        this.bgp_necromancer_background.create();
        this.m.ID = ::PaleSovereign.Chief;
        this.m.Name = "异端死灵法师";
        this.m.Icon = "ui/backgrounds/pale_necromancer.png";
        this.m.BackgroundDescription = "你是这支战团的首席。两道誓约都向你敞开，直到你择其一。";
        this.m.DailyCost = 0;
    }

    function onChangeAttributes()
    {
        local attrs = this.bgp_necromancer_background.onChangeAttributes();
        for (local i = 0; i < 2; ++i)
        {
            attrs.Bravery[i] += 10;
            attrs.Stamina[i] += 10;
        }
        return attrs;
    }

    function createPerkTreeBlueprint()
    {
        local tree = this.bgp_necromancer_background.createPerkTreeBlueprint();
        tree.m.DynamicMap["pgc.rf_weapon"] = ["pg.rf_polearm"];
        return tree;
    }

    function getPerkGroupMultiplier( _groupID, _tree )
    {
        if (_groupID == "pg.special.rf_leadership")
            return -1;
        return this.bgp_necromancer_background.getPerkGroupMultiplier(_groupID, _tree);
    }

    function onAdded()
    {
        this.bgp_necromancer_background.onAdded();
        local skills = this.getContainer();
        if (!skills.hasSkill("actives.pale_soul_chain"))
            skills.add(::new("scripts/skills/actives/pale_soul_chain"));
    }

    function onUpdate( _properties )
    {
        this.bgp_necromancer_background.onUpdate(_properties);
        local battle = ::PaleSovereign.Battle;
        if (battle != null && battle.Night)
            _properties.Bravery += 20;
        if (::PaleSovereign.isActive())
        {
            local now = ::World.getTime().Days + ::World.getTime().Hours / 24.0;
            if (::World.Flags.getAsFloat("Pale.RitualUntil") > now)
            {
                foreach (stat in ["HitpointsMult", "StaminaMult", "BraveryMult", "InitiativeMult", "MeleeSkillMult", "RangedSkillMult", "MeleeDefenseMult", "RangedDefenseMult"])
                    _properties[stat] *= 0.85;
            }
            if (::World.Flags.getAsFloat("Pale.WhispersUntil") > now)
                _properties.Stamina -= 10;
        }
    }
});
