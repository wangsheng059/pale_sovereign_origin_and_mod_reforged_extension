// 注册四个专属特技组，并放进重铸的“专属”集合（Min = 0，不会被随机抽到；特技组本身权重也是 0）
foreach (script in ::IO.enumerateFiles("scripts/mods/mod_bg_unique_perks/perk_groups"))
{
	try
	{
		local group = ::new(script);
		::DynamicPerks.PerkGroups.add(group);
		local collection = ::DynamicPerks.PerkGroupCategories.findById("pgc.rf_exclusive_1");
		if (collection != null)
			collection.addPerkGroup(group.getID());
	}
	catch (e)
	{
		::logError("mod_bg_unique_perks: 注册特技组失败 " + script + ": " + e);
	}
}
