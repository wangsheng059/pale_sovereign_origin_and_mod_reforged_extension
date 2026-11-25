// Item History & Trusted Weapon Tracker (refactored Legacy module v6.0.0).
// Preserves exact WK binary serialization format v6 (reads v0..v6) for 100% save compatibility.
// Preserves BP Augmenteds dual-wield offhand kill attribution and BP Smith WK_* fields.
// Removed dangerous global skill_container / actor onDeserialize exception-swallowing hooks.

local mod = ::Hooks.register("mod_weapon_kills", "6.0.0", "物品履历");
mod.require("mod_msu", "mod_legacy");

::WK_FORMAT_VERSION <- 6;
::WK_TRUSTED_MAX    <- 50;
::WK_OWNERS_KEEP    <- 30;
::WK_BONUS_PCT_MIN  <- 5;
::WK_BONUS_PCT_MAX  <- 20;

// Fallback base damage table used only if live m.RegularDamage/Max cannot be read.
::WK_DAMAGE_TABLE <- {
	// Daggers
	"weapon.knife"                 : { base_min = 15, base_max = 20 },
	"weapon.dagger"                : { base_min = 20, base_max = 30 },
	"weapon.goblin_notched_blade"  : { base_min = 20, base_max = 30 },
	"weapon.rondel_dagger"         : { base_min = 25, base_max = 35 },
	"weapon.qatal_dagger"          : { base_min = 30, base_max = 45 },
	"weapon.estoc"                 : { base_min = 35, base_max = 50 },
	// 1H Swords
	"weapon.broken_ancient_sword"  : { base_min = 30, base_max = 35 },
	"weapon.shortsword"            : { base_min = 30, base_max = 40 },
	"weapon.saif"                  : { base_min = 35, base_max = 40 },
	"weapon.falchion"              : { base_min = 35, base_max = 45 },
	"weapon.ancient_sword"         : { base_min = 38, base_max = 43 },
	"weapon.scimitar"              : { base_min = 40, base_max = 45 },
	"weapon.arming_sword"          : { base_min = 40, base_max = 45 },
	"weapon.shamshir"              : { base_min = 45, base_max = 50 },
	"weapon.noble_sword"           : { base_min = 45, base_max = 50 },
	"weapon.fencing_sword"         : { base_min = 35, base_max = 50 },
	// 2H Swords
	"weapon.rhomphaia"             : { base_min = 45, base_max = 65 },
	"weapon.warbrand"              : { base_min = 65, base_max = 75 },
	"weapon.longsword"             : { base_min = 45, base_max = 55 },
	"weapon.greatsword"            : { base_min = 85, base_max = 100 },
	"weapon.guts_sword"            : { base_min = 120, base_max = 150 },
	"weapon.exesword"              : { base_min = 95, base_max = 110 },
	// 1H Axes
	"weapon.hatchet"               : { base_min = 25, base_max = 35 },
	"weapon.hand_axe"              : { base_min = 30, base_max = 45 },
	"weapon.fighting_axe"          : { base_min = 40, base_max = 55 },
	"weapon.crude_axe"             : { base_min = 40, base_max = 55 },
	"weapon.orc_axe"               : { base_min = 35, base_max = 55 },
	"weapon.military_pick"         : { base_min = 30, base_max = 40 },
	// 2H Axes
	"weapon.woodcutters_axe"       : { base_min = 40, base_max = 65 },
	"weapon.bardiche"              : { base_min = 60, base_max = 85 },
	"weapon.greataxe"              : { base_min = 65, base_max = 90 },
	"weapon.longaxe"               : { base_min = 50, base_max = 80 },
	"weapon.heavy_rusty_axe"       : { base_min = 60, base_max = 80 },
	"weapon.orc_axe_2h"            : { base_min = 80, base_max = 110 },
	"weapon.peasantshovel"         : { base_min = 40, base_max = 65 },
	// Cleavers
	"weapon.scramasax"             : { base_min = 25, base_max = 35 },
	"weapon.military_cleaver"      : { base_min = 40, base_max = 60 },
	"weapon.khopesh"               : { base_min = 35, base_max = 55 },
	"weapon.orc_cleaver"           : { base_min = 40, base_max = 65 },
	"weapon.battle_whip"           : { base_min = 15, base_max = 25 },
	"weapon.crypt_cleaver"         : { base_min = 60, base_max = 80 },
	"weapon.rusty_warblade"        : { base_min = 90, base_max = 110 },
	"weapon.two_handed_scimitar"   : { base_min = 65, base_max = 95 },
	"weapon.butchers_cleaver"      : { base_min = 20, base_max = 35 },
	"weapon.blunt_cleaver"         : { base_min = 30, base_max = 40 },
	"weapon.antler_cleaver"        : { base_min = 20, base_max = 30 },
	"weapon.falx"                  : { base_min = 25, base_max = 35 },
	"weapon.axehammer"             : { base_min = 20, base_max = 30 },
	"weapon.hooked_blade"          : { base_min = 40, base_max = 70 },
	"weapon.two_handed_saif"       : { base_min = 50, base_max = 70 },
	// Flails
	"weapon.flail"                 : { base_min = 30, base_max = 50 },
	"weapon.three_headed_flail"    : { base_min = 25, base_max = 60 },
	"weapon.two_handed_flail"      : { base_min = 55, base_max = 90 },
	"weapon.orc_flail_2h"          : { base_min = 65, base_max = 100 },
	"weapon.wooden_flail"          : { base_min = 10, base_max = 25 },
	"weapon.reinforced_wooden_flail": { base_min = 20, base_max = 45 },
	// Hammers
	"weapon.pickaxe"               : { base_min = 20, base_max = 28 },
	"weapon.warhammer"             : { base_min = 30, base_max = 40 },
	"weapon.polehammer"            : { base_min = 45, base_max = 70 },
	"weapon.two_handed_hammer"     : { base_min = 55, base_max = 75 },
	"weapon.skull_hammer"          : { base_min = 45, base_max = 70 },
	"weapon.two_handed_wooden_hammer": { base_min = 40, base_max = 70 },
	// Maces
	"weapon.wooden_stick"          : { base_min = 15, base_max = 25 },
	"weapon.bludgeon"              : { base_min = 20, base_max = 35 },
	"weapon.claw_club"             : { base_min = 20, base_max = 30 },
	"weapon.nomad_mace"            : { base_min = 25, base_max = 35 },
	"weapon.goblin_staff"          : { base_min = 25, base_max = 35 },
	"weapon.orc_wooden_club"       : { base_min = 40, base_max = 60 },
	"weapon.morning_star"          : { base_min = 30, base_max = 45 },
	"weapon.light_southern_mace"   : { base_min = 30, base_max = 40 },
	"weapon.heavy_southern_mace"   : { base_min = 35, base_max = 50 },
	"weapon.winged_mace"           : { base_min = 35, base_max = 55 },
	"weapon.goedendag"             : { base_min = 45, base_max = 75 },
	"weapon.two_handed_spiked_mace": { base_min = 50, base_max = 70 },
	"weapon.two_handed_mace"       : { base_min = 50, base_max = 75 },
	"weapon.polemace"              : { base_min = 60, base_max = 75 },
	"weapon.two_handed_flanged_mace": { base_min = 75, base_max = 95 },
	// Spears & Polearms
	"weapon.militia_spear"         : { base_min = 25, base_max = 30 },
	"weapon.ancient_spear"         : { base_min = 30, base_max = 40 },
	"weapon.goblin_spear"          : { base_min = 25, base_max = 35 },
	"weapon.boar_spear"            : { base_min = 30, base_max = 35 },
	"weapon.firelance"             : { base_min = 30, base_max = 35 },
	"weapon.fighting_spear"        : { base_min = 35, base_max = 40 },
	"weapon.warfork"               : { base_min = 40, base_max = 60 },
	"weapon.spetum"                : { base_min = 55, base_max = 75 },
	"weapon.pitchfork"             : { base_min = 35, base_max = 55 },
	"weapon.billhook"              : { base_min = 45, base_max = 80 },
	"weapon.bladed_pike"           : { base_min = 50, base_max = 75 },
	"weapon.broken_bladed_pike"    : { base_min = 35, base_max = 55 },
	"weapon.pike"                  : { base_min = 50, base_max = 70 },
	"weapon.swordlance"            : { base_min = 50, base_max = 70 },
	"weapon.warscythe"             : { base_min = 50, base_max = 75 },
	"weapon.peasantscythe"         : { base_min = 40, base_max = 65 },
	"weapon.goblin_pike"           : { base_min = 35, base_max = 55 },
	"weapon.poleaxe"               : { base_min = 50, base_max = 75 },
	// Ranged & Throwing
	"weapon.wonky_bow"             : { base_min = 30, base_max = 50 },
	"weapon.short_bow"             : { base_min = 35, base_max = 50 },
	"weapon.hunting_bow"           : { base_min = 30, base_max = 45 },
	"weapon.goblin_bow"            : { base_min = 30, base_max = 45 },
	"weapon.goblin_heavy_bow"      : { base_min = 40, base_max = 55 },
	"weapon.composite_bow"         : { base_min = 40, base_max = 65 },
	"weapon.war_bow"               : { base_min = 50, base_max = 70 },
	"weapon.masterwork_bow"        : { base_min = 50, base_max = 75 },
	"weapon.light_crossbow"        : { base_min = 30, base_max = 45 },
	"weapon.crossbow"              : { base_min = 50, base_max = 70 },
	"weapon.goblin_crossbow"       : { base_min = 50, base_max = 70 },
	"weapon.heavy_crossbow"        : { base_min = 60, base_max = 80 },
	"weapon.handgonne"             : { base_min = 35, base_max = 65 },
	"weapon.javelin"               : { base_min = 35, base_max = 45 },
	"weapon.throwing_axe"          : { base_min = 35, base_max = 50 },
	"weapon.throwing_spear"        : { base_min = 35, base_max = 50 },
	"weapon.heavy_javelin"         : { base_min = 40, base_max = 50 },
	"weapon.heavy_throwing_axe"    : { base_min = 45, base_max = 60 },
	"weapon.orc_javelin"           : { base_min = 35, base_max = 45 },
	"weapon.nomad_sling"           : { base_min = 35, base_max = 50 },
	"weapon.staff_sling"           : { base_min = 35, base_max = 50 },
	"weapon.lute"                  : { base_min = 5,  base_max = 10 },
	// Reforged & Davkul fallback entries
	"weapon.rf_battle_axe"         : { base_min = 60, base_max = 80 },
	"weapon.rf_two_handed_falchion": { base_min = 50, base_max = 65 },
	"weapon.rf_estoc"              : { base_min = 55, base_max = 70 },
	"weapon.rf_swordstaff"         : { base_min = 55, base_max = 80 },
	"weapon.rf_poleflail"          : { base_min = 55, base_max = 85 },
	"weapon.rf_greatsword"         : { base_min = 65, base_max = 85 },
	"weapon.rf_halberd"            : { base_min = 60, base_max = 80 },
	"weapon.rf_kriegsmesser"       : { base_min = 60, base_max = 80 },
	"weapon.rf_voulge"             : { base_min = 60, base_max = 90 },
	"weapon.rf_poleaxe"            : { base_min = 75, base_max = 100 },
	"weapon.rf_great_khopesh"      : { base_min = 85, base_max = 100 },
	"weapon.rf_orc_mace_2h"        : { base_min = 85, base_max = 115 },
	"weapon.rf_reinforced_wooden_poleflail": { base_min = 40, base_max = 70 },
	"weapon.rf_draugr_axe"         : { base_min = 35, base_max = 50 },
	"weapon.rf_draugr_cleaver"     : { base_min = 45, base_max = 55 },
	"weapon.rf_draugr_sword"       : { base_min = 42, base_max = 47 },
	"weapon.rf_draugr_shaman_staff": { base_min = 40, base_max = 60 },
	"weapon.rf_draugr_battle_axe"  : { base_min = 60, base_max = 80 },
	"weapon.rf_draugr_voulge"      : { base_min = 60, base_max = 85 },
	"weapon.rf_draugr_greataxe"    : { base_min = 80, base_max = 100 },
	"weapon.cultist_crowbeak"      : { base_min = 60, base_max = 90 },
	"weapon.cultist_mancatcher"    : { base_min = 45, base_max = 75 },
	"weapon.cultist_scythe"        : { base_min = 70, base_max = 90 },
	"weapon.cultist_billhook"      : { base_min = 65, base_max = 95 },
	"weapon.heavy_staff_sling"     : { base_min = 25, base_max = 40 },
	"weapon.goblin_falchion"       : { base_min = 30, base_max = 35 },
	"weapon.goblin_spiked_balls"   : { base_min = 25, base_max = 40 },
	"weapon.orc_metal_club"        : { base_min = 45, base_max = 65 },
	"weapon.thorned_whip"          : { base_min = 20, base_max = 35 },
	"weapon.two_handed_wooden_flail": { base_min = 35, base_max = 70 }
};

::WK_DAMAGE_DEFAULT <- { base_min = 20, base_max = 40 };

::WeaponKills <- {

	function isNamed( _item )
	{
		try { return _item.isItemType(::Const.Items.ItemType.Named); }
		catch (e) { return false; }
	}

	function getDamageRange( _item )
	{
		try
		{
			local bMin = null;
			local bMax = null;
			try { bMin = _item.m.RegularDamage; } catch (e) {}
			try { bMax = _item.m.RegularDamageMax; } catch (e) {}
			if (bMin != null && bMin > 0 && bMax != null && bMax > 0)
			{
				if (bMax < bMin) bMax = bMin;
				return { base_min = bMin, base_max = bMax };
			}
		}
		catch (e) {}
		try
		{
			local id = _item.getID();
			if (id in ::WK_DAMAGE_TABLE) return ::WK_DAMAGE_TABLE[id];
		}
		catch (e) {}
		return ::WK_DAMAGE_DEFAULT;
	}

	function rollDamageBonus( _item )
	{
		local r = this.getDamageRange(_item);
		local pctA = ::Math.rand(::WK_BONUS_PCT_MIN, ::WK_BONUS_PCT_MAX);
		local pctB = ::Math.rand(::WK_BONUS_PCT_MIN, ::WK_BONUS_PCT_MAX);
		local pctMin = (pctA <= pctB) ? pctA : pctB;
		local pctMax = (pctA <= pctB) ? pctB : pctA;

		local bonusMin = (r.base_min * pctMin + 50) / 100;
		local bonusMax = (r.base_max * pctMax + 50) / 100;
		if (bonusMin < 1) bonusMin = 1;
		if (bonusMax < bonusMin) bonusMax = bonusMin;
		if (bonusMin > 255) bonusMin = 255;
		if (bonusMax > 255) bonusMax = 255;

		return {
			bonusMin = bonusMin,
			bonusMax = bonusMax,
			rolledPctMin = pctMin,
			rolledPctMax = pctMax
		};
	}

	function deriveRolledPcts( _item, _bonusMin = null, _bonusMax = null )
	{
		try
		{
			local bMin = _bonusMin;
			local bMax = _bonusMax;
			if (bMin == null) { try { bMin = _item.m.WK_BonusMin; } catch (e1) { bMin = 0; } }
			if (bMax == null) { try { bMax = _item.m.WK_BonusMax; } catch (e2) { bMax = 0; } }
			if (bMin == null || bMin <= 0 || bMax == null || bMax <= 0) return null;

			local r = this.getDamageRange(_item);
			if (r.base_min <= 0 || r.base_max <= 0) return null;

			local pctMin = (bMin * 100 + r.base_min / 2) / r.base_min;
			local pctMax = (bMax * 100 + r.base_max / 2) / r.base_max;
			if (pctMin < 1) pctMin = 1;
			if (pctMax < 1) pctMax = 1;
			if (pctMin > 99) pctMin = 99;
			if (pctMax > 99) pctMax = 99;
			return { pctMin = pctMin, pctMax = pctMax };
		}
		catch (e) { return null; }
	}

	function _pruneOwners( _owners, _legendaryOwner, _maxCount = 30, _trusted = null )
	{
		if (_owners == null) return {};
		if (_owners.len() <= _maxCount) return _owners;

		local list = [];
		foreach (name, val in _owners)
			list.push({ name = name, val = val });

		list.sort(function( a, b ) {
			if (b.val != a.val) return b.val <=> a.val;
			return a.name <=> b.name;
		});

		local result = {};
		local kept = 0;
		for (local i = 0; i < list.len() && kept < _maxCount; i++)
		{
			result[list[i].name] <- list[i].val;
			kept++;
		}

		if (_legendaryOwner != null && _legendaryOwner != ""
			&& !(_legendaryOwner in result) && (_legendaryOwner in _owners))
		{
			result[_legendaryOwner] <- _owners[_legendaryOwner];
		}

		if (_trusted != null)
		{
			foreach (t in _trusted)
			{
				if (t.name != null && t.name != "" && !(t.name in result) && (t.name in _owners))
					result[t.name] <- _owners[t.name];
			}
		}
		return result;
	}

	// Safe raw initialization: never throws even on custom subclasses missing WK fields.
	function _safeInit( _item )
	{
		local m = _item.m;
		if (!m.rawin("WK_TotalStat")         || m.rawget("WK_TotalStat") == null)         m.rawset("WK_TotalStat", 0);
		if (!m.rawin("WK_IsNamedByPlayer")   || m.rawget("WK_IsNamedByPlayer") == null)   m.rawset("WK_IsNamedByPlayer", false);
		if (!m.rawin("WK_Owners")            || m.rawget("WK_Owners") == null)            m.rawset("WK_Owners", {});
		if (!m.rawin("WK_LegendaryOwner"))                                                m.rawset("WK_LegendaryOwner", null);
		if (!m.rawin("WK_LegendaryHireTime") || m.rawget("WK_LegendaryHireTime") == null) m.rawset("WK_LegendaryHireTime", -1.0);
		if (!m.rawin("WK_BonusMin")          || m.rawget("WK_BonusMin") == null)          m.rawset("WK_BonusMin", 0);
		if (!m.rawin("WK_BonusMax")          || m.rawget("WK_BonusMax") == null)          m.rawset("WK_BonusMax", 0);
		if (!m.rawin("WK_Trusted")           || m.rawget("WK_Trusted") == null)           m.rawset("WK_Trusted", []);
	}

	function _ownedBy()
	{
		return "，属于";
	}

	function _augmentedsInstalled()
	{
		return ("BP_Augmenteds_rf" in ::getroottable());
	}

	function getTrustedOwners( _item )
	{
		local ret = [];
		try
		{
			local m = _item.m;
			local hire = null, owner = null, bMin = 0, bMax = 0, extra = null;
			try { hire  = m.WK_LegendaryHireTime; } catch (e1) {}
			try { owner = m.WK_LegendaryOwner; }    catch (e2) {}
			try { bMin  = m.WK_BonusMin; }          catch (e3) {}
			try { bMax  = m.WK_BonusMax; }          catch (e4) {}
			try { extra = m.WK_Trusted; }           catch (e5) {}

			if (hire != null && hire >= 0.0 && owner != null)
			{
				ret.push({
					name = owner,
					hire = hire,
					min = bMin == null ? 0 : bMin,
					max = bMax == null ? 0 : bMax
				});
			}
			if (extra != null)
			{
				foreach (t in extra) ret.push(t);
			}
		}
		catch (e) {}
		return ret;
	}

	function getTrustedEntry( _item, _hireTime )
	{
		if (_hireTime == null) return null;
		foreach (t in this.getTrustedOwners(_item))
		{
			if (t.hire == _hireTime) return t;
		}
		return null;
	}

	function _resolveAttackingWeapon( _killer, _skill )
	{
		// Authoritative BP Augmenteds dual-wield offhand follow-up tag.
		if (this._augmentedsInstalled() && _killer != null && ("m" in _killer))
		{
			try
			{
				if ("bp_aug_wk_offhand" in _killer.m)
				{
					local tagged = _killer.m.bp_aug_wk_offhand;
					if (tagged != null
						&& !("isNull" in tagged && tagged.isNull())
						&& tagged.isItemType(::Const.Items.ItemType.Weapon)
						&& tagged.getCurrentSlotType() == ::Const.ItemSlot.Offhand)
					{
						return tagged;
					}
				}
			}
			catch (e) {}
		}

		local mainhand = null;
		local offhandWeapon = null;
		try
		{
			local items = _killer.getItems();
			if (items != null)
			{
				mainhand = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
				local oh = items.getItemAtSlot(::Const.ItemSlot.Offhand);
				if (oh != null
					&& !("isNull" in oh && oh.isNull())
					&& oh.isItemType(::Const.Items.ItemType.Weapon))
				{
					offhandWeapon = oh;
				}
			}
		}
		catch (e) {}

		if (_skill != null)
		{
			local skillItem = null;
			try { skillItem = _skill.getItem(); } catch (e) {}
			if (skillItem != null
				&& !("isNull" in skillItem && skillItem.isNull())
				&& skillItem.isItemType(::Const.Items.ItemType.Weapon))
			{
				if (skillItem == offhandWeapon) return offhandWeapon;
				if (skillItem == mainhand) return mainhand;
				return skillItem;
			}
		}

		return mainhand;
	}

	function onKill( _killer, _skill )
	{
		if (_killer == null || !_killer.isPlayerControlled()) return;

		local item = this._resolveAttackingWeapon(_killer, _skill);
		if (item == null) return;
		if (!item.isItemType(::Const.Items.ItemType.Weapon)) return;
		if ("isNull" in item && item.isNull()) return;

		this._safeInit(item);

		item.m.WK_TotalStat++;
		local broName = _killer.getNameOnly();
		if (!(broName in item.m.WK_Owners)) item.m.WK_Owners[broName] <- 0;
		item.m.WK_Owners[broName]++;

		if (this.isNamed(item)) return;
		if (item.m.WK_Owners[broName] < 100) return;

		local hire = _killer.m.HireTime;
		if (this.getTrustedEntry(item, hire) != null) return;

		local hasFirst = item.m.WK_LegendaryHireTime != null
			&& item.m.WK_LegendaryHireTime >= 0.0
			&& item.m.WK_LegendaryOwner != null;

		if (!hasFirst)
		{
			local bonus = this.rollDamageBonus(item);
			item.m.WK_BonusMin = bonus.bonusMin;
			item.m.WK_BonusMax = bonus.bonusMax;
			if (!item.m.WK_IsNamedByPlayer)
				item.m.Name = item.getName() + this._ownedBy() + broName;
			item.m.WK_LegendaryOwner = broName;
			item.m.WK_LegendaryHireTime = hire;
			item.m.WK_IsNamedByPlayer = true;
		}
		else
		{
			if (item.m.WK_Trusted.len() >= ::WK_TRUSTED_MAX) return;
			item.m.WK_Trusted.push({
				name = broName,
				hire = hire,
				min = item.m.WK_BonusMin,
				max = item.m.WK_BonusMax
			});
		}
	}

	function _recordAbsorbed( _item, _broName, _dmg, _threshold )
	{
		if (_dmg <= 0 || _item == null) return;
		if ("isNull" in _item && _item.isNull()) return;
		this._safeInit(_item);
		_item.m.WK_TotalStat += _dmg;
		if (!(_broName in _item.m.WK_Owners)) _item.m.WK_Owners[_broName] <- 0;
		_item.m.WK_Owners[_broName] += _dmg;
		if (_item.m.WK_Owners[_broName] >= _threshold && !_item.m.WK_IsNamedByPlayer)
		{
			_item.m.Name = _item.getName() + this._ownedBy() + _broName;
			_item.m.WK_IsNamedByPlayer = true;
		}
	}

	function onDamageReceived( _entity, _oldBodyArmor, _oldHeadArmor, _oldShieldCond )
	{
		if (_entity == null || !_entity.isPlayerControlled()) return;
		local broName = _entity.getNameOnly();
		local items = _entity.getItems();
		if (items == null) return;

		local dmgBody = _oldBodyArmor - _entity.getArmor(::Const.BodyPart.Body);
		if (dmgBody > 0)
			this._recordAbsorbed(items.getItemAtSlot(::Const.ItemSlot.Body), broName, dmgBody, 1200);

		local dmgHead = _oldHeadArmor - _entity.getArmor(::Const.BodyPart.Head);
		if (dmgHead > 0)
			this._recordAbsorbed(items.getItemAtSlot(::Const.ItemSlot.Head), broName, dmgHead, 600);

		local shield = items.getItemAtSlot(::Const.ItemSlot.Offhand);
		if (shield != null && shield.isItemType(::Const.Items.ItemType.Shield) && !("isNull" in shield && shield.isNull()))
		{
			local dmgShield = _oldShieldCond - shield.getCondition();
			if (dmgShield > 0)
				this._recordAbsorbed(shield, broName, dmgShield, 1000);
		}
	}
};

mod.queue(">mod_legacy", function()
{
	foreach (itemScript in [
		"scripts/items/weapons/weapon",
		"scripts/items/armor/armor",
		"scripts/items/helmets/helmet",
		"scripts/items/shields/shield"
	])
	{
		mod.hook(itemScript, function(q)
		{
			q.m.WK_TotalStat         <- 0;
			q.m.WK_IsNamedByPlayer   <- false;
			q.m.WK_Owners            <- null;
			q.m.WK_LegendaryOwner    <- null;
			q.m.WK_LegendaryHireTime <- -1.0;
			q.m.WK_BonusMin          <- 0;
			q.m.WK_BonusMax          <- 0;
			q.m.WK_Trusted           <- null;

			q.create = @(__original) function()
			{
				__original();
				this.m.rawset("WK_TotalStat",         0);
				this.m.rawset("WK_IsNamedByPlayer",   false);
				this.m.rawset("WK_Owners",            {});
				this.m.rawset("WK_LegendaryOwner",    null);
				this.m.rawset("WK_LegendaryHireTime", -1.0);
				this.m.rawset("WK_BonusMin",          0);
				this.m.rawset("WK_BonusMax",          0);
				this.m.rawset("WK_Trusted",           []);
			};

			q.onSerialize = @(__original) function( _out )
			{
				__original(_out);
				::WeaponKills._safeInit(this);

				_out.writeU8(::WK_FORMAT_VERSION);
				_out.writeU32(this.m.WK_TotalStat);
				_out.writeBool(this.m.WK_IsNamedByPlayer);

				local owners = ::WeaponKills._pruneOwners(
					this.m.WK_Owners,
					this.m.WK_LegendaryOwner,
					::WK_OWNERS_KEEP,
					this.m.WK_Trusted
				);

				_out.writeU16(owners.len());
				foreach (name, val in owners)
				{
					_out.writeString(name);
					_out.writeU32(val);
				}

				local hasLegendary = this.m.WK_LegendaryHireTime != null
					&& this.m.WK_LegendaryHireTime >= 0.0
					&& this.m.WK_LegendaryOwner != null;
				_out.writeBool(hasLegendary);
				if (hasLegendary)
				{
					_out.writeString(this.m.WK_LegendaryOwner);
					_out.writeF32(this.m.WK_LegendaryHireTime);
					_out.writeU8(this.m.WK_BonusMin);
					_out.writeU8(this.m.WK_BonusMax);
				}

				local extra = hasLegendary ? this.m.WK_Trusted : [];
				local n = extra.len();
				if (n > ::WK_TRUSTED_MAX) n = ::WK_TRUSTED_MAX;
				_out.writeU8(n);
				for (local i = 0; i < n; i++)
				{
					_out.writeString(extra[i].name);
					_out.writeF32(extra[i].hire);
					_out.writeU8(extra[i].min);
					_out.writeU8(extra[i].max);
				}
			};

			q.onDeserialize = @(__original) function( _in )
			{
				__original(_in);

				this.m.rawset("WK_TotalStat",         0);
				this.m.rawset("WK_IsNamedByPlayer",   false);
				this.m.rawset("WK_Owners",            {});
				this.m.rawset("WK_LegendaryOwner",    null);
				this.m.rawset("WK_LegendaryHireTime", -1.0);
				this.m.rawset("WK_BonusMin",          0);
				this.m.rawset("WK_BonusMax",          0);
				this.m.rawset("WK_Trusted",           []);

				try
				{
					local marker = _in.readU8();

					if (marker >= 2 && marker <= ::WK_FORMAT_VERSION)
					{
						this.m.WK_TotalStat       = _in.readU32();
						this.m.WK_IsNamedByPlayer = _in.readBool();

						local numOwners = _in.readU16();
						if (numOwners > 500) throw "WK: numOwners=" + numOwners + " suspicious";
						local owners = {};
						for (local i = 0; i < numOwners; i++)
						{
							local name = _in.readString();
							local val  = _in.readU32();
							if (name != null && name.len() > 0 && name.len() <= 100)
								owners[name] <- val;
						}
						this.m.WK_Owners = owners;

						try
						{
							if (_in.readBool())
							{
								this.m.WK_LegendaryOwner    = _in.readString();
								this.m.WK_LegendaryHireTime = _in.readF32();
								if (marker >= 5)
								{
									this.m.WK_BonusMin = _in.readU8();
									this.m.WK_BonusMax = _in.readU8();
								}
							}
						}
						catch (eLeg) {}

						if (marker >= 6)
						{
							local n = _in.readU8();
							local extra = [];
							for (local i = 0; i < n; i++)
							{
								local tName = _in.readString();
								local tHire = _in.readF32();
								local tMin  = _in.readU8();
								local tMax  = _in.readU8();
								extra.push({ name = tName, hire = tHire, min = tMin, max = tMax });
							}
							this.m.WK_Trusted = extra;
						}
					}
					else if (marker == 1)
					{
						this.m.WK_TotalStat       = _in.readU32();
						this.m.WK_IsNamedByPlayer = _in.readBool();

						local numOwners = _in.readU16();
						if (numOwners > 500) throw "WK v1: numOwners=" + numOwners + " suspicious";
						local owners = {};
						for (local i = 0; i < numOwners; i++)
						{
							local name = _in.readString();
							local val  = _in.readU32();
							if (name != null && name.len() > 0 && name.len() <= 100)
								owners[name] <- val;
						}
						this.m.WK_Owners = owners;

						try
						{
							if (_in.readBool())
							{
								this.m.WK_LegendaryOwner    = _in.readString();
								this.m.WK_LegendaryHireTime = _in.readF32();
							}
						}
						catch (eLeg) {}
					}
					else if (marker == 0)
					{
						local b1 = _in.readU8();
						local b2 = _in.readU8();
						local b3 = _in.readU8();
						this.m.WK_TotalStat       = marker | (b1 << 8) | (b2 << 16) | (b3 << 24);
						this.m.WK_IsNamedByPlayer = _in.readBool();

						local numOwners = _in.readU16();
						if (numOwners > 500) throw "WK legacy: numOwners=" + numOwners + " suspicious";
						local owners = {};
						for (local i = 0; i < numOwners; i++)
						{
							local name = _in.readString();
							local val  = _in.readU32();
							if (name != null && name.len() > 0 && name.len() <= 100)
								owners[name] <- val;
						}
						this.m.WK_Owners = owners;

						try
						{
							if (_in.readBool())
							{
								this.m.WK_LegendaryOwner    = _in.readString();
								this.m.WK_LegendaryHireTime = _in.readF32();
							}
						}
						catch (eLeg) {}
					}
					else
					{
						throw "WK: unknown format version: " + marker;
					}
				}
				catch (e)
				{
					::logWarning("mod_weapon_kills: onDeserialize fallback [" + this.getName() + "]: " + e);
				}
			};

			q.getTooltip = @(__original) function()
			{
				local ret = __original();
				::WeaponKills._safeInit(this);

				if (this.m.WK_TotalStat <= 0) return ret;

				local isWeapon = this.isItemType(::Const.Items.ItemType.Weapon);
				local isShield = this.isItemType(::Const.Items.ItemType.Shield);
				local isHelmet = this.isItemType(::Const.Items.ItemType.Helmet);

				local statLabel = isWeapon ? "击杀敌人：" : "吸收伤害：";
				local statIcon  = isWeapon ? "ui/icons/kills.png"
					: (isShield ? "ui/icons/shield_hp.png" : "ui/icons/armor_body.png");
				ret.push({ id = 100, type = "text", icon = statIcon, text = statLabel + this.m.WK_TotalStat });

				if (isWeapon)
				{
					local trusted = ::WeaponKills.getTrustedOwners(this);
					if (trusted.len() > 0)
					{
						local wielderHire = null;
						try
						{
							local container = this.getContainer();
							if (container != null)
							{
								local actor = container.getActor();
								if (actor != null && !actor.isNull() && actor.isPlayerControlled())
									wielderHire = actor.m.HireTime;
							}
						}
						catch (e) {}

						foreach (t in trusted)
						{
							local pcts = ::WeaponKills.deriveRolledPcts(this, t.min, t.max);
							local pctStrMin = (pcts != null) ? (" (+" + pcts.pctMin + "%)") : "";
							local pctStrMax = (pcts != null) ? (" (+" + pcts.pctMax + "%)") : "";
							local bonusStr = "最小伤害 +" + t.min + pctStrMin + "，最大伤害 +" + t.max + pctStrMax;

							local isWielder = (wielderHire != null && wielderHire == t.hire);
							local legendText = isWielder
								? (t.name + "的信赖之刃：" + bonusStr)
								: (t.name + "的信赖之刃（" + bonusStr + "）——仅在其手中生效");
							ret.push({ id = 102, type = "text", icon = "ui/icons/damage.png", text = legendText });
						}
					}
				}

				local minVal = isWeapon ? 15 : (isShield ? 300 : (isHelmet ? 200 : 500));
				local validOwners = [];
				foreach (name, val in this.m.WK_Owners)
				{
					if (val >= minVal) validOwners.push(name);
				}
				if (validOwners.len() > 0)
				{
					local ownersStr = "";
					for (local i = 0; i < validOwners.len(); i++)
					{
						ownersStr += validOwners[i];
						if (i < validOwners.len() - 1) ownersStr += ", ";
					}
					ret.push({ id = 101, type = "text", icon = "ui/icons/special.png", text = "持有者：" + ownersStr });
				}

				return ret;
			};
		});
	}

	// Trusted weapon damage bonus (Mainhand only, so dual-wield offhand never leaks damage).
	mod.hook("scripts/items/weapons/weapon", function(q)
	{
		q.onUpdateProperties = @(__original) function( _properties )
		{
			__original(_properties);

			local legHire = -1.0;
			try { legHire = this.m.WK_LegendaryHireTime; } catch (e) { return; }
			if (legHire == null || legHire < 0.0) return;

			try
			{
				try { if (this.getCurrentSlotType() != ::Const.ItemSlot.Mainhand) return; } catch (eslot) {}

				local container = this.getContainer();
				if (container == null) return;
				local actor = container.getActor();
				if (actor == null || actor.isNull() || !actor.isPlayerControlled()) return;

				local t = ::WeaponKills.getTrustedEntry(this, actor.m.HireTime);
				if (t == null) return;

				_properties.DamageRegularMin += t.min;
				_properties.DamageRegularMax += t.max;
			}
			catch (e) {}
		};
	});
});
