::LocalNecroAC <- ::Hooks.register("mod_local_necromancy_companions", "1.6.1", "死灵法师 × 配件兄弟");
::LocalNecroAC.require("mod_local_rules");
::LocalNecroAC.queue([">mod_local_rules", ">mod_AC"], function()
{
	if (!::Hooks.hasMod("mod_AC"))
		return;
	::BGP.HasAC = true;
	::include("mod_bg_unique_perks/necro_ac");
	::include("mod_bg_unique_perks/necro_pets");
	::include("mod_bg_unique_perks/necro_companions_hooks");
	::include("mod_bg_unique_perks/companions_background");
});
::LocalNecroAC.queue([">mod_local_rules", ">mod_AC", ">mod_ac_ph_compat"], function()
{
	if (::BGP.HasAC)
		::include("mod_bg_unique_perks/necro_ac_library");
}, ::Hooks.QueueBucket.AfterHooks);
