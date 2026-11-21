::PaleSovereign <- {
    ID = "scenario.pale_sovereign",
    Chief = "background.pale_necromancer",
    ChiefScript = "scripts/skills/backgrounds/pale_necromancer_background",
    ChiefName = "亡灵法师导师",
    RosterLimit = 12,
    ChampionUndeadLimit = 3,
    ReserveLimit = 40,
    Oath = { None = 0, Champion = 1, Scourge = 2 },
    OathNames = ["尚未立誓", "亡灵冠军", "亡灵天灾"],
    Battle = null,
    ItemDir = "scripts/items/",
    SkillDir = "scripts/skills/"
};

::PaleSovereign.Mod <- ::Hooks.register("mod_pale_sovereign", "1.0.3", "亡灵主宰");
::PaleSovereign.Mod.require("mod_local_rules >= 1.6.3");
::Hooks.registerJS("ui/mods/pale_sovereign.js");
::Hooks.registerCSS("ui/mods/pale_sovereign.css");
::PaleSovereign.Mod.queue([">mod_local_necromancy_companions", ">mod_dynamic_perks", ">mod_AC", ">mod_reforged"], function()
{
    if (!::BGP.HasAC)
        return;
    foreach (file in ["company", "combat", "souls", "sites", "events", "hooks", "loading"])
        ::include("pale_sovereign/" + file);
});

::PaleSovereign.Mod.queue(">bbfusion_framework", function()
{
    if (!("BBFusion" in ::getroottable()) || !("IsEligible" in ::BBFusion))
        return;
    local eligible = ::BBFusion.IsEligible;
    ::BBFusion.IsEligible = function( _item )
    {
        if (_item != null)
        {
            local id = _item.getID();
            if (typeof id == "string" && id.find("weapon.pale_staff") == 0)
                return false;
            if ("PaleReplica" in _item.m && _item.m.PaleReplica)
                return false;
        }
        return eligible(_item);
    };
});
