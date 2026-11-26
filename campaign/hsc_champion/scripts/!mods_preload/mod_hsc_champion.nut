// HSC Champion Rules Extension
// 1. Captured champions recruited via Human Slave Capture receive trait.hsc_tarnished_champion
//    ("蒙尘冠军") instead of vanilla/Reforged racial.champion (racial.champion is left untouched
//    for enemies, Eightfold Trial rewards, and other mods).
// 2. Recognizes both Tarnished Champion and human racial.champion across HSC events (06/07/08,
//    Eightfold Trial eligibility, defeat penalty) and enables event.hsc_champion_duel to softly
//    limit the company to at most 1 living champion.

::HSC_ChampionRules <- {
	ID = "mod_hsc_champion",
	Version = "1.0.0",
	Name = "捕奴冠军规则扩展"
};

::HSC_ChampionRules.Mod <- ::Hooks.register(::HSC_ChampionRules.ID, ::HSC_ChampionRules.Version, ::HSC_ChampionRules.Name);
::HSC_ChampionRules.Mod.require("hsc_human_slave_capture");

::HSC_ChampionRules.replaceText <- function( _str, _old, _new )
{
	if (_str == null || _old == null || _old == "") return _str;
	local idx = _str.find(_old);
	if (idx == null) return _str;
	return _str.slice(0, idx) + _new + _str.slice(idx + _old.len());
};

::HSC_ChampionRules.Mod.queue([">hsc_human_slave_capture", ">mod_hsc_bg_ext"], function()
{
	local H = ::HumanSlaveCapture;
	local mod = ::HSC_ChampionRules.Mod;

	H.TarnishedChampionID <- "trait.hsc_tarnished_champion";

	// Returns true for undead permanent roster entities (e.g. Pale Sovereign zombies/skeletons)
	// so human champion rivalry events never pull mindless undead into duels.
	H.isLivingUndead <- function( _bro )
	{
		if (_bro == null) return false;
		try
		{
			local flags = _bro.getFlags();
			if (flags.has("undead") || flags.has("PalePermanentUndead")) return true;
		}
		catch (e)
		{
		}
		try
		{
			if (_bro.getCurrentProperties().IsUndead) return true;
		}
		catch (e)
		{
		}
		return false;
	};

	// Returns true if _bro is an alive living brother with either Tarnished Champion or racial.champion.
	H.isChampionBro <- function( _bro )
	{
		if (_bro == null) return false;
		try
		{
			if (!_bro.isAlive()) return false;
		}
		catch (e)
		{
		}
		if (this.isLivingUndead(_bro)) return false;
		return this.safeHasSkill(_bro, this.TarnishedChampionID) || this.safeHasSkill(_bro, "racial.champion");
	};

	// Returns all alive living brothers counted toward the 1-champion soft limit.
	H.getChampionBrothers <- function()
	{
		local ret = [];
		foreach (bro in this.getAliveBrothers())
		{
			if (this.isChampionBro(bro)) ret.push(bro);
		}
		return ret;
	};

	// Wrap createBrother so captured champions receive trait.hsc_tarnished_champion
	// instead of racial.champion. Enemy champions and Eightfold Trial rewards are untouched.
	local origCreateBrother = H.createBrother;
	H.createBrother = function( _entry, _level, _extraPerkPoints )
	{
		local isChampion = false;
		try
		{
			isChampion = (_entry != null && "Champion" in _entry && _entry.Champion == true);
		}
		catch (e)
		{
		}

		if (!isChampion)
			return origCreateBrother.call(this, _entry, _level, _extraPerkPoints);

		local entry = clone _entry;
		entry.Champion = false;

		local bro = origCreateBrother.call(this, entry, _level, _extraPerkPoints);
		if (bro != null)
		{
			try
			{
				if (!this.safeHasSkill(bro, this.TarnishedChampionID))
				{
					bro.getSkills().add(::new("scripts/skills/traits/hsc_tarnished_champion_trait"));
					bro.getSkills().update();
					bro.m.Hitpoints = bro.getHitpointsMax();
					bro.m.ActionPoints = bro.getActionPointsMax();
					bro.setFatigue(0);
					this.log("Tarnished Champion trait granted.");
				}
			}
			catch (e)
			{
				this.logError("Could not add the tarnished champion trait: " + e);
			}
		}
		return bro;
	};

	// Prevent brothers who already have Tarnished Champion (or racial.champion) from entering
	// the Eightfold Trial and stacking two champion traits on one brother.
	H.getEligibleBrosForTrial = function()
	{
		local all = [];
		try
		{
			foreach (bro in ::World.getPlayerRoster().getAll())
			{
				if (bro == null) continue;
				local alive = true;
				try { alive = bro.isAlive(); } catch (e) { alive = true; }
				if (!alive) continue;
				if (this.isChampionBro(bro) || this.safeHasSkill(bro, "racial.champion")) continue;
				all.push(bro);
			}
		}
		catch (e)
		{
		}

		all.sort(@(a, b) b.getLevel() <=> a.getLevel());

		local ret = [];
		for (local i = 0; i < all.len() && i < this.Config.TrialMaxSelectable; i++)
		{
			ret.push(all[i]);
		}
		return ret;
	};

	// Keep event 07 Suppress (10% chance to strip champion trait) working for Tarnished Champion too.
	local origRemoveSkill = H.removeSkill;
	H.removeSkill = function( _bro, _id )
	{
		if (_id == "racial.champion" && _bro != null && !this.safeHasSkill(_bro, "racial.champion") && this.safeHasSkill(_bro, this.TarnishedChampionID))
		{
			local ok = origRemoveSkill.call(this, _bro, this.TarnishedChampionID);
			try
			{
				if (_bro.getHitpoints() > _bro.getHitpointsMax())
					_bro.setHitpoints(_bro.getHitpointsMax());
			}
			catch (e)
			{
			}
			return ok;
		}
		return origRemoveSkill.call(this, _bro, _id);
	};

	// Protect Tarnished Champion brothers from random defeat disappearance the same way as racial.champion.
	H.applyDefeatPenalty = function()
	{
		local result = {
			Money = 0,
			Brother = null
		};

		try
		{
			local money = this.getMoney();
			local cost = ::Math.round(money * 0.15) + 200;
			if (cost > money) cost = money;
			if (cost < 0) cost = 0;
			if (cost > 0)
			{
				this.payMoney(cost);
				result.Money = cost;
			}
		}
		catch (e)
		{
		}

		local victims = [];
		foreach (bro in this.getAliveBrothers())
		{
			if (this.isChampionBro(bro)) continue;
			victims.push(bro);
		}

		if (victims.len() > 0 && ::Math.rand(1, 100) <= 40)
		{
			local victim = victims[::Math.rand(0, victims.len() - 1)];
			try
			{
				::World.getPlayerRoster().remove(victim);
				result.Brother = victim;
				this.log("Defeat penalty: " + victim.getName() + " is gone.");
			}
			catch (e)
			{
				this.logError("Defeat penalty could not remove a brother: " + e);
			}
		}

		return result;
	};

	// Update captive item description to reflect Tarnished Champion on recruitment.
	mod.hook("scripts/items/misc/hsc_captive_item", function( q )
	{
		q.HSC_buildDescription = @(__original) function()
		{
			local desc = __original();
			desc = ::HSC_ChampionRules.replaceText(desc, "冠军：是（保留冠军特质）", "冠军：是（招募后获得「蒙尘冠军」特质）");
			desc = ::HSC_ChampionRules.replaceText(desc, "Champion: yes (keeps the Champion trait)", "Champion: yes (gains the Tarnished Champion trait)");
			return desc;
		};
	});

	// Event 06: Old Master's Revenge recognizes Tarnished Champion brothers.
	mod.hook("scripts/events/events/hsc_event_06_old_master_revenge", function( q )
	{
		q.prepare = @(__original) function()
		{
			this.m.Bro = null;
			this.m.ChampionCaptives = ::HumanSlaveCapture.getChampionCaptives().len();

			local champions = ::HumanSlaveCapture.getChampionBrothers();
			if (champions.len() > 0)
			{
				this.m.Bro = champions[::Math.rand(0, champions.len() - 1)];
			}
		};

		q.onUpdateScore = @(__original) function()
		{
			this.m.Score = 0;

			if (::HumanSlaveCapture == null) return;
			this.m.Title = ::HumanSlaveCapture.L("旧主的复仇", "The Old Master's Revenge");
			if (!::HumanSlaveCapture.canRunStoryEvents()) return;

			local hasChampionBro = ::HumanSlaveCapture.getChampionBrothers().len() > 0;
			local hasChampionCaptive = ::HumanSlaveCapture.getChampionCaptives().len() > 0;
			if (!hasChampionBro && !hasChampionCaptive) return;

			this.m.Score = 30;
		};
	});

	// Event 07: Call of the Eightfold Path recognizes Tarnished Champion brothers.
	mod.hook("scripts/events/events/hsc_event_07_call_of_eightfold", function( q )
	{
		q.prepare = @(__original) function()
		{
			this.m.Bro = null;

			foreach (bro in ::HumanSlaveCapture.getChampionBrothers())
			{
				if (::HumanSlaveCapture.safeHasSkill(bro, "trait.hsc_flesh_tearer")) continue;
				this.m.Bro = bro;
				break;
			}

			if (this.m.Bro == null)
			{
				local all = ::HumanSlaveCapture.getAliveBrothers();
				if (all.len() > 0) this.m.Bro = all[::Math.rand(0, all.len() - 1)];
			}
		};

		q.onUpdateScore = @(__original) function()
		{
			this.m.Score = 0;

			if (::HumanSlaveCapture == null) return;
			this.m.Title = ::HumanSlaveCapture.L("八重之道的召唤", "The Call of the Eightfold Path");
			if (!::HumanSlaveCapture.canRunStoryEvents()) return;

			foreach (bro in ::HumanSlaveCapture.getChampionBrothers())
			{
				if (::HumanSlaveCapture.safeHasSkill(bro, "trait.hsc_flesh_tearer")) continue;
				this.m.Score = 30;
				return;
			}
		};
	});

	// Event 08: The Torn Shackle recognizes Tarnished Champion brothers.
	mod.hook("scripts/events/events/hsc_event_08_torn_shackles", function( q )
	{
		q.prepare = @(__original) function()
		{
			this.m.Bro = null;
			this.m.Cleanser = null;
			this.m.CanCleanse = false;

			foreach (bro in ::HumanSlaveCapture.getBrothersWithSkill("trait.hsc_flesh_tearer"))
			{
				if (!::HumanSlaveCapture.isChampionBro(bro)) continue;
				this.m.Bro = bro;
				break;
			}

			local cleansers = ::HumanSlaveCapture.getBrothersWithBackground([
				"monk",
				"priest",
				"flagellant",
				"oath",
				"paladin",
				"cultist"
			]);

			if (cleansers.len() > 0)
			{
				this.m.CanCleanse = true;
				this.m.Cleanser = cleansers[::Math.rand(0, cleansers.len() - 1)];
			}

			if (this.m.Bro == null)
			{
				local all = ::HumanSlaveCapture.getAliveBrothers();
				if (all.len() > 0) this.m.Bro = all[::Math.rand(0, all.len() - 1)];
			}
		};

		q.onUpdateScore = @(__original) function()
		{
			this.m.Score = 0;

			if (::HumanSlaveCapture == null) return;
			this.m.Title = ::HumanSlaveCapture.L("撕裂的枷锁", "The Torn Shackle");
			if (!::HumanSlaveCapture.canRunStoryEvents()) return;

			foreach (bro in ::HumanSlaveCapture.getBrothersWithSkill("trait.hsc_flesh_tearer"))
			{
				if (!::HumanSlaveCapture.isChampionBro(bro)) continue;
				this.m.Score = 30;
				return;
			}
		};
	});

	::logInfo("[HSC] 捕奴冠军规则扩展 v" + ::HSC_ChampionRules.Version + " 已加载。");
});
