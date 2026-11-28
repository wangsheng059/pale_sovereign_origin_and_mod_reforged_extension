// Unified MSU ModSettings for standalone UI & helper tools in zz_local_interface.zip.
::LocalInterface <- {
	ID = "mod_local_interface",
	Version = "1.0.0",
	Name = "本地界面工具",
	Mod = null,
	Defaults = {
		UI_LairScout = true,
		UI_LairNamed = true,
		UI_AllRecipes = true,
		UI_SettlementPrices = true,
		UI_SituationDetails = true,
		UI_NamedItemStats = true,
		UI_BBForgeHotkey = true
	}
};

::LocalInterface.get <- function( _id, _fallback = true )
{
	try
	{
		if (::LocalInterface.Mod != null)
		{
			local s = ::LocalInterface.Mod.ModSettings.getSetting(_id);
			if (s != null)
				return s.getValue();
		}
	}
	catch (e) {}
	if (_id in ::LocalInterface.Defaults)
		return ::LocalInterface.Defaults[_id];
	return _fallback;
};

::LocalInterface.HooksMod <- ::Hooks.register(::LocalInterface.ID, ::LocalInterface.Version, ::LocalInterface.Name);
::LocalInterface.HooksMod.require("mod_msu");

::LocalInterface.HooksMod.queue(">mod_msu", function()
{
	::LocalInterface.Mod = ::MSU.Class.Mod(::LocalInterface.ID, ::LocalInterface.Version, ::LocalInterface.Name);
	local page = ::LocalInterface.Mod.ModSettings.addPage("General", "界面与工具");

	page.addBooleanSetting("UI_LairScout", true,
		"透视营地守军",
		"开启时，大地图悬停敌方营地可直接查看守军构成（不改写存档侦察标记，关闭后立即恢复原版未知守军规则）。");

	page.addBooleanSetting("UI_LairNamed", true,
		"显示营地红装信息",
		"开启时，在敌方营地悬浮窗显示生成红装概率，以及已生成红装的图标与名称。");

	page.addBooleanSetting("UI_AllRecipes", true,
		"揭示所有炼金配方",
		"开启时，铁匠铺与炼金师界面直接显示全部可制作配方，无需先获得对应材料；关闭后恢复原版解锁条件。");

	page.addBooleanSetting("UI_SettlementPrices", true,
		"显示城镇贸易价格对比",
		"开启时，在已造访城镇的大地图悬浮窗显示当前购买价/出售价百分比及全图最高最低区间。");

	page.addBooleanSetting("UI_SituationDetails", true,
		"显示城镇事件效果详情",
		"开启时，在城镇状态（如动乱、丰收、商队抵达等）悬浮窗列出具体物价、货物数量与新兵修正数值。");

	page.addBooleanSetting("UI_NamedItemStats", true,
		"显示著名装备属性范围",
		"开启时，在红装与神器悬浮窗底部显示同款物品的随机属性上下限范围。");

	page.addBooleanSetting("UI_BBForgeHotkey", true,
		"启用汉化修改器快捷键 (Shift+E)",
		"开启时，可在大地图按 Shift+E 呼出 BBForge 汉化修改器；关闭后屏蔽呼出快捷键，防止误触。");
});

// Gate mod_namedItemStats tooltip rows without duplicating its 15 item stat tables.
::LocalInterface.HooksMod.queue([">mod_msu", ">namedItemStats"], function()
{
	foreach (script in [
		"scripts/items/weapons/named/named_weapon",
		"scripts/items/armor/named/named_armor",
		"scripts/items/helmets/named/named_helmet",
		"scripts/items/shields/named/named_shield",
		"scripts/items/weapons/named/named_crossbow",
		"scripts/items/weapons/named/named_handgonne",
		"scripts/items/armor/named/lindwurm_armor",
		"scripts/items/helmets/named/lindwurm_helmet",
		"scripts/items/weapons/artifact/artifact_weapon",
		"scripts/items/armor/artifact/artifact_armor",
		"scripts/items/helmets/artifact/artifact_helmet",
		"scripts/items/shields/artifact/artifact_shield",
		"scripts/items/weapons/artifact/artifact_crossbow",
		"scripts/items/weapons/artifact/artifact_handgonne",
		"scripts/items/shields/artifact/artifact_schract_shield"
	])
	{
		::LocalInterface.HooksMod.hook(script, function(q)
		{
			q.getTooltip = @(__original) function()
			{
				local ret = __original();
				if (::LocalInterface.get("UI_NamedItemStats", true) || ret == null)
					return ret;
				for (local i = ret.len() - 1; i >= 0; --i)
				{
					local row = ret[i];
					if (row != null && ("id" in row) && row.id == 4 && ("text" in row) && typeof row.text == "string"
						&& (row.text.find("同款著名") == 0 || row.text.find("同款神器") == 0))
					{
						ret.remove(i);
					}
				}
				return ret;
			};
		});
	}
}, ::Hooks.QueueBucket.VeryLate);
