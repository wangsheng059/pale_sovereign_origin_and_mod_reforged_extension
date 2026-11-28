// Reveal all crafting blueprints with live MSU toggle support.
::LocalInterface.HooksMod.queue([">mod_msu", ">mod_reforged"], function()
{
	::LocalInterface.HooksMod.hook("scripts/crafting/blueprint", function(q)
	{
		q.isQualified = @(__original) function()
		{
			if (::LocalInterface.get("UI_AllRecipes", true))
				return true;
			return __original();
		};
	});
});
