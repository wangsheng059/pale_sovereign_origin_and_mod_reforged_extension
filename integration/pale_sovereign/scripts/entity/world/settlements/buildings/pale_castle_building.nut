this.pale_castle_building <- ::inherit("scripts/entity/world/settlements/buildings/building", {
    m = { PalePage = "castle" },

    function setup( _key )
    {
        this.building.create();
        local definition = ::PaleSovereign.CastleBuildings[_key];
        this.m.ID = "building." + _key;
        this.m.Name = definition.Name;
        this.m.Description = definition.Description;
        this.m.UIImage = "ui/settlements/" + definition.Icon;
        this.m.UIImageNight = this.m.UIImage;
        this.m.Tooltip = "world-town-screen.main-dialog-module.Management";
        this.m.TooltipIcon = "ui/icons/ambition_tooltip.png";
        this.m.IsClosedAtNight = false;
        this.m.Sounds = [];
        this.m.SoundsAtNight = [];
        this.m.PalePage = definition.Page;
    }

    function onClicked( _townScreen )
    {
        ::PaleSovereign.CastlePage = this.m.PalePage;
        _townScreen.onModuleClosed();
    }
});
