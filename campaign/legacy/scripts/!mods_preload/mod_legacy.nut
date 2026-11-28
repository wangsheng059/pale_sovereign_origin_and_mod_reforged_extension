// Core namespace for the refactored Legacy mod (Career Stats, XP Share, Item History).
// Graves, Permanent Injury Hook, and Blind Enemies have been removed completely.

::Legacy <- {
	ID = "mod_legacy",
	Version = "3.1.0",
	Name = "遗产",
	Lang = "zh",
	Mod = null,
	Defaults = {
		Legacy_TrustedWeaponBonus = true,
		Legacy_TopRankBadge = true
	}
};

// Back-compat shim for any external script probing ::Legacy.isRu().
::Legacy.isRu <- function()
{
	return false;
};

::Legacy.getSetting <- function( _id, _fallback = true )
{
	try
	{
		if (::Legacy.Mod != null)
		{
			local s = ::Legacy.Mod.ModSettings.getSetting(_id);
			if (s != null)
				return s.getValue();
		}
	}
	catch (e) {}
	if (_id in ::Legacy.Defaults)
		return ::Legacy.Defaults[_id];
	return _fallback;
};

::Legacy.refreshRoster <- function()
{
	try
	{
		if (!("World" in ::getroottable()) || ::World == null || ::World.getPlayerRoster() == null)
			return;
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null || ::MSU.isNull(bro))
				continue;
			try { bro.getSkills().update(); } catch (e) {}
		}
	}
	catch (e) {}
};

::Legacy.MH <- ::Hooks.register(::Legacy.ID, ::Legacy.Version, ::Legacy.Name);
::Legacy.MH.require("mod_modern_hooks", "mod_msu");

::Legacy.MH.queue(">mod_msu", function()
{
	::include("scripts/items/misc/veteran_trinket_item");
	::Legacy.Mod = ::MSU.Class.Mod(::Legacy.ID, ::Legacy.Version, ::Legacy.Name);
	local page = ::Legacy.Mod.ModSettings.addPage("General", "物品与臂章");

	page.addBooleanSetting("Legacy_TrustedWeaponBonus", true,
		"启用信赖之刃武器加成",
		"开启时，非红装武器由同一名兄弟累计击杀满 100 人后成为「信赖之刃」，在其主手装备时提供专属伤害加成；关闭后不再触发新转化且不提供伤害加成（物品履历与存档读写保持启用）。")
		.addAfterChangeCallback(function( _oldValue ) { ::Legacy.refreshRoster(); });

	page.addBooleanSetting("Legacy_TopRankBadge", true,
		"显示生涯排名臂章",
		"开启时，第 50 天后在战团综合排名前三保持满 10 场的兄弟获得排名臂章特质与决心加成（+5/+3/+2）；关闭后隐藏臂章并取消其决心加成（底层统计与存档读写保持启用）。")
		.addAfterChangeCallback(function( _oldValue )
		{
			try
			{
				if ("CareerStats" in ::getroottable() && "updateTopTraits" in ::CareerStats)
					::CareerStats.updateTopTraits(false);
			}
			catch (e) {}
			::Legacy.refreshRoster();
		});

	::logInfo("Legacy v" + ::Legacy.Version + ": core initialized (Career Stats + XP Share + Item History)");
});
