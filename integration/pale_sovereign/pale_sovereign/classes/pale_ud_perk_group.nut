// Shared base class for permanent undead exclusive perk groups in DynamicPerks.
this.pale_ud_perk_group <- ::inherit(::DynamicPerks.Class.PerkGroup, {
    m = { PaleUndeadGroupKind = "" },

    function create()
    {
        local def = ::PaleSovereign.UndeadPerkGroups[this.m.PaleUndeadGroupKind];
        this.m.ID = def.ID;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Icon = def.Icon;
        local rows = [];
        foreach (row in def.Tree)
        {
            local valid = [];
            foreach (id in row)
            {
                if (::Const.Perks.findById(id) != null)
                    valid.push(id);
                else
                    ::logWarning("Pale Sovereign: undead perk " + id + " not found");
            }
            rows.push(valid);
        }
        this.m.Tree = rows;
    }

    function getSelfMultiplier( _perkTree )
    {
        return 0;
    }
});
