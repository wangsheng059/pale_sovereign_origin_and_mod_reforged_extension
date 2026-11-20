::LocalNorthBackgrounds <- ::Hooks.register("mod_local_northern_backgrounds", "1.6.1", "神选者 × 北境扩张");
::LocalNorthBackgrounds.require("mod_local_rules");
::LocalNorthBackgrounds.queue([">mod_local_rules", ">mod_north_expansion"], function()
{
	if (::Hooks.hasMod("mod_north_expansion"))
		::include("mod_bg_unique_perks/northern_background");
});
