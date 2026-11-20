// 神选者（北境扩张）：原本没有重铸蓝图，特技树完全随机。按重铸原版野蛮人的设置补上，专属组为“神选”
if (::Hooks.hasMod("mod_north_expansion"))
{
	::LocalNorthBackgrounds.hook("scripts/skills/backgrounds/barbarian_chosen_background", function(q)
	{
		q.createPerkTreeBlueprint = @(__original) function()
		{
			return ::new(::DynamicPerks.Class.PerkTree).init({
				DynamicMap = {
					"pgc.rf_exclusive_1": ["pg.bgp_chosen"],
					"pgc.rf_shared_1": [],
					"pgc.rf_weapon": [],
					"pgc.rf_armor": [],
					"pgc.rf_fighting_style": []
				}
			});
		}

		q.getPerkGroupCollectionMin = @(__original) function( _collection )
		{
			if (_collection.getID() == "pgc.rf_weapon")
				return _collection.getMin() + 2;
			return __original(_collection);
		}
	});
}

