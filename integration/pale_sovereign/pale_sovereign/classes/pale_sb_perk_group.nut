// Shared base class for Soulbound exclusive perk groups in DynamicPerks.
this.pale_sb_perk_group <- ::inherit(::DynamicPerks.Class.PerkGroup, {
    m = { PaleSoulClass = "" },
    function create()
    {
        local def = ::PaleSovereign.SoulboundClasses[this.m.PaleSoulClass];
        this.m.ID = "pg.pale_sb_" + this.m.PaleSoulClass;
        this.m.Name = def.Name;
        this.m.Description = def.Description;
        this.m.Icon = "ui/backgrounds/pale_sb_" + this.m.PaleSoulClass + ".png";
        local rows = [];
        foreach (row in def.Tree)
        {
            local valid = [];
            foreach (id in row)
            {
                if (::Const.Perks.findById(id) != null)
                    valid.push(id);
                else
                    ::logWarning("Pale Sovereign: soulbound perk " + id + " not found");
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
