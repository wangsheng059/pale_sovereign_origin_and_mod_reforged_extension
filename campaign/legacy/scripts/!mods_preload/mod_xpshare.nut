// XP Share on Dismiss & Veteran Keepsake Trinkets (refactored Legacy module).

::XPShare <- {
	ID = "mod_xpshare",
	Version = "2.0.0",
	Name = "解雇经验分享",
	Mod = null,
	Config = {
		IsEnabled = true,
		XPShareFraction = 0.5,
		MaxXPPerBrotherFraction = 0.1
	},
	TrinketIDs = [
		"misc.wooden_jaw",
		"misc.wisdom_stone",
		"misc.alp_figurine",
		"misc.chainmail_bracelet",
		"misc.curvy_maiden",
		"misc.goblin_figurine",
		"misc.hyena_figurine",
		"misc.iron_spoon",
		"misc.medal_from_the_flattened_coin",
		"misc.nachzehrer_figurine",
		"misc.orc_figurine",
		"misc.orc_shield_mirror",
		"misc.snake_figurine",
		"misc.strange_little_bag",
		"misc.strange_rosary",
		"misc.wolfs_fang_whistle",
		"misc.brass_knuckles_fork",
		"misc.collection_of_dried_mushrooms",
		"misc.ear_of_the_silent_one",
		"misc.emperors_skull_fragment",
		"misc.ghost_fang",
		"misc.glasses_from_bottles",
		"misc.kern_of_the_ancients",
		"misc.pipe_of_the_dead",
		"misc.scarf_from_the_squad_flag"
	]
};

::XPShare.isEnabled <- function()
{
	try
	{
		if (::XPShare.Mod != null)
		{
			local s = ::XPShare.Mod.ModSettings.getSetting("XPShare_Enable");
			if (s != null) return s.getValue();
		}
	}
	catch (e) {}
	return ::XPShare.Config.IsEnabled;
};

::XPShare.getShareFraction <- function()
{
	try
	{
		if (::XPShare.Mod != null)
		{
			local s = ::XPShare.Mod.ModSettings.getSetting("XPShare_Fraction");
			if (s != null) return s.getValue() / 100.0;
		}
	}
	catch (e) {}
	return ::XPShare.Config.XPShareFraction;
};

::XPShare.getMaxPerBrotherFraction <- function()
{
	try
	{
		if (::XPShare.Mod != null)
		{
			local s = ::XPShare.Mod.ModSettings.getSetting("XPShare_MaxPerBrother");
			if (s != null) return s.getValue() / 100.0;
		}
	}
	catch (e) {}
	return ::XPShare.Config.MaxXPPerBrotherFraction;
};

::XPShare.grantVeteranTrinket <- function( _bro )
{
	try
	{
		local stashObj = ::World.Assets.getStash();
		if (stashObj == null || !stashObj.hasEmptySlot()) return null;

		local owned = {};
		foreach (item in stashObj.getItems())
		{
			if (item != null) owned[item.getID()] <- true;
		}

		local available = [];
		foreach (id in ::XPShare.TrinketIDs)
		{
			if (!(id in owned)) available.push(id);
		}
		if (available.len() == 0) return null;

		local selectedID = available[::Math.rand(0, available.len() - 1)];
		local scriptName = selectedID.slice(5);
		local trinket = ::new("scripts/items/misc/" + scriptName + "_item");
		trinket.setVeteranName(_bro.getName());
		stashObj.add(trinket);
		return trinket;
	}
	catch (e)
	{
		::logWarning("XPShare: failed to grant veteran trinket: " + e);
		return null;
	}
};

::XPShare.MH <- ::Hooks.register(::XPShare.ID, ::XPShare.Version, ::XPShare.Name);
::XPShare.MH.require("mod_modern_hooks", "mod_msu", "mod_legacy");

::XPShare.MH.queue(">mod_legacy", ">mod_hardened", function()
{
	::XPShare.Mod = ::MSU.Class.Mod(::XPShare.ID, ::XPShare.Version, ::XPShare.Name);

	local page = ::XPShare.Mod.ModSettings.addPage("General", "常规");

	page.addBooleanSetting("XPShare_Enable", true,
		"启用经验分享",
		"支付遣散费解雇兄弟时，将他的部分经验分配给等级更低的兄弟（最高分到 11 级），11 级以上老兵退役还会留下纪念品。")
		.addBeforeChangeCallback(function( _newValue ) { ::XPShare.Config.IsEnabled = _newValue; });

	page.addRangeSetting("XPShare_Fraction", 50, 0, 100, 5,
		"分享比例（%）",
		"被解雇兄弟的总经验中，用于分配给队友的百分比。")
		.addBeforeChangeCallback(function( _newValue ) { ::XPShare.Config.XPShareFraction = _newValue / 100.0; });

	page.addRangeSetting("XPShare_MaxPerBrother", 10, 1, 50, 1,
		"每人上限（%）",
		"单个兄弟最多可从本次经验池中获得的比例。")
		.addBeforeChangeCallback(function( _newValue ) { ::XPShare.Config.MaxXPPerBrotherFraction = _newValue / 100.0; });

	page.addButtonSetting("XPShare_Reset",
		"重置",
		"恢复默认设置")
		.addBeforeChangeCallback(function() { ::XPShare.Mod.ModSettings.resetSettings(); });

	::XPShare.MH.hook("scripts/ui/screens/character/character_screen", function(q)
	{
		q.onDismissCharacter = @(__original) function( _data )
		{
			local broID = _data[0];
			local payCompensation = _data[1];

			// Notify CareerStats of the departure reason before roster removal runs.
			if ("CareerStats" in ::getroottable())
				::CareerStats.PendingDeparture <- payCompensation ? "Retired" : "Dismissed";

			if (!payCompensation || !::XPShare.isEnabled())
				return __original(_data);

			// Prefer world player roster lookup over Tactical.getEntityByID.
			local bro = null;
			local roster = ::World.getPlayerRoster().getAll();
			foreach (b in roster)
			{
				if (b != null && b.getID() == broID)
				{
					bro = b;
					break;
				}
			}
			if (bro == null)
			{
				try { bro = ::Tactical.getEntityByID(broID); } catch (e) {}
			}
			if (bro == null)
				return __original(_data);

			local broLevel = bro.getLevel();
			local xpToShare = bro.getXP() * ::XPShare.getShareFraction();
			if (xpToShare > 0)
			{
				local eligible = [];
				foreach (b in roster)
				{
					if (b != null && b.getID() != broID && b.getLevel() < broLevel && b.getLevel() < 11)
						eligible.push(b);
				}

				if (eligible.len() > 0)
				{
					local cap = xpToShare * ::XPShare.getMaxPerBrotherFraction();
					local perBro = ::Math.floor(::Math.min(cap, xpToShare / eligible.len()));
					if (perBro > 0)
					{
						local isVeteran = (broLevel >= 11);
						local mentorName = bro.getName();
						foreach (other in eligible)
						{
							other.addXP(perBro, false);
							other.updateLevel();
							try
							{
								if ("CareerStats_Stats" in other.m && other.m.CareerStats_Stats != null)
									other.m.CareerStats_Stats.addMentor(mentorName, isVeteran);
							}
							catch (e) {}
						}
					}
				}
			}

			// Retired level 11+ veterans leave behind a unique keepsake trinket.
			if (broLevel >= 11)
				::XPShare.grantVeteranTrinket(bro);

			return __original(_data);
		};
	});
});
