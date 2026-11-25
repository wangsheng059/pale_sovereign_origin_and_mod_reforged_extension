// Statistics Manager hooks for Career Stats (Hall of Fame, Fallen/Legacy persistence,
// and the 65535-entry tag_collection blob compactor for long campaigns).
// Must be included BEFORE strength_tracker.nut and top_traits.nut so this hook sits
// innermost around vanilla onSerialize/onDeserialize.

::CareerStats.MH.hook("scripts/statistics/statistics_manager", function(q)
{
	q.m.Legacy <- [];
	q.m.CareerStats_RankSnapshot <- {};
	q.m.CareerStats_ArrowPrevSnapshot <- {};

	q.create = @(__original) function()
	{
		__original();
		this.m.Legacy = [];
		this.m.CareerStats_RankSnapshot = {};
		this.m.CareerStats_ArrowPrevSnapshot = {};
	};

	q.addLegacy <- function( _entry )
	{
		this.m.Legacy.insert(0, _entry);
	};

	q.addFallen = @(__original) function( _fallen )
	{
		local ret = __original(_fallen);
		if (this.m.Fallen.len() > 0)
			::CareerStats.LastFallen = this.m.Fallen[0];
		return ret;
	};

	q.CareerStats_buildHallOfFame <- function()
	{
		local entries = [];
		local tooltips = [];

		local accFields = function( _statsObj )
		{
			local r = { hit = 0.0, hitN = -1, hitProven = false, dodge = 0.0, dodgeN = -1, dodgeProven = false };
			try
			{
				if (_statsObj == null) return r;
				local st = _statsObj.m.Stats;
				local full = ("STRENGTH2_RAMP_FULL" in ::CareerStats) ? ::CareerStats.STRENGTH2_RAMP_FULL : 50;
				local hasSmooth = ("smoothedRate" in ::CareerStats);
				local hN = st.NumAccuracyHits + st.NumAccuracyMisses;
				local dN = st.NumAccuracyDodges + st.NumAccuracyHitsReceived;
				r.hitN = hN;
				r.dodgeN = dN;
				r.hitProven = hN >= full;
				r.dodgeProven = dN >= full;
				r.hit = hasSmooth ? ::CareerStats.smoothedRate(st.NumAccuracyHits, hN) : (hN > 0 ? st.NumAccuracyHits.tofloat() / hN : 0.0);
				r.dodge = hasSmooth ? ::CareerStats.smoothedRate(st.NumAccuracyDodges, dN) : (dN > 0 ? st.NumAccuracyDodges.tofloat() / dN : 0.0);
			}
			catch (e) {}
			return r;
		};

		local livingNames = {};
		local bros = ::World.getPlayerRoster().getAll();
		foreach (bro in bros)
		{
			if (bro == null) continue;
			try { if ("isNull" in bro && bro.isNull()) continue; } catch (e) {}
			try { livingNames[bro.getName()] <- true; } catch (e) {}
		}

		// 1) Fallen brothers (skip Nine Lives survivors still in active roster).
		for (local i = 0; i < this.m.Fallen.len(); i++)
		{
			local f = this.m.Fallen[i];
			if (f.Name in livingNames) continue;

			local damageDealt = 0;
			local smoothedRating = 0.0;
			local dpsHp = 0;
			local dpsArmor = 0;
			local hitChance = 0.0;
			local dodgeChance = 0.0;
			local dodgeMetric = 0.0;
			local acc = accFields(null);
			local hasStats = ("CareerStats_Stats" in f && f.CareerStats_Stats != null);
			if (hasStats)
			{
				local st = f.CareerStats_Stats;
				damageDealt = st.getDamageDealt();
				smoothedRating = st.getSmoothedRating();
				dodgeMetric = st.getSmoothedDodge();
				dpsHp = st.getDamageDealtAvgHitpoints();
				dpsArmor = st.getDamageDealtAvgArmor();
				hitChance = st.getAvgHitChance();
				dodgeChance = st.getAvgDodgeChance();
				acc = accFields(st);
			}

			entries.push({
				Name = f.Name,
				NameOnly = ("NameOnly" in f) ? f.NameOnly : f.Name,
				Level = ("Level" in f) ? f.Level : 0,
				TimeWithCompany = f.TimeWithCompany,
				Battles = f.Battles,
				Kills = f.Kills,
				DamageDealt = damageDealt,
				SmoothedRating = smoothedRating,
				DPSHp = dpsHp,
				DPSArmor = dpsArmor,
				HitChance = hitChance,
				DodgeChance = dodgeChance,
				HitSmoothed = acc.hit,
				HitAttempts = acc.hitN,
				HitProven = acc.hitProven,
				DodgeSmoothed = acc.dodge,
				DodgeAttempts = acc.dodgeN,
				DodgeProven = acc.dodgeProven,
				Status = f.KilledBy,
				StatusType = "fallen",
				Source = "fallen",
				SourceIdx = i,
				ImagePath = ("CachedPortrait" in f) ? f.CachedPortrait : "",
				ImageOffsetX = ("CachedPortraitX" in f) ? f.CachedPortraitX : 0,
				ImageOffsetY = ("CachedPortraitY" in f) ? f.CachedPortraitY : 0,
				Appearance = ("Appearance" in f) ? f.Appearance : null,
				BackgroundIcon = ("BackgroundIcon" in f) ? f.BackgroundIcon : "",
				LevelHistory = (hasStats && ("LevelHistory" in f.CareerStats_Stats.m)) ? f.CareerStats_Stats.m.LevelHistory : [],
				DodgeMetric = dodgeMetric
			});
		}

		// 2) Departed brothers (Legacy array).
		for (local i = 0; i < this.m.Legacy.len(); i++)
		{
			local l = this.m.Legacy[i];
			local smoothedRating = 0.0;
			local dpsHp = 0;
			local dpsArmor = 0;
			local hitChance = 0.0;
			local dodgeChance = 0.0;
			local dodgeMetric = 0.0;
			local acc = accFields(null);
			local hasStats = ("CareerStats_Stats" in l && l.CareerStats_Stats != null);
			if (hasStats)
			{
				local st = l.CareerStats_Stats;
				smoothedRating = st.getSmoothedRating();
				dodgeMetric = st.getSmoothedDodge();
				dpsHp = st.getDamageDealtAvgHitpoints();
				dpsArmor = st.getDamageDealtAvgArmor();
				hitChance = st.getAvgHitChance();
				dodgeChance = st.getAvgDodgeChance();
				acc = accFields(st);
			}

			entries.push({
				Name = l.Name,
				NameOnly = ("NameOnly" in l) ? l.NameOnly : l.Name,
				Level = ("Level" in l) ? l.Level : 0,
				TimeWithCompany = ("TimeWithCompany" in l) ? l.TimeWithCompany : 0,
				Battles = ("Battles" in l) ? l.Battles : 0,
				Kills = ("Kills" in l) ? l.Kills : 0,
				DamageDealt = ("DamageDealt" in l) ? l.DamageDealt : 0,
				SmoothedRating = smoothedRating,
				DPSHp = dpsHp,
				DPSArmor = dpsArmor,
				HitChance = hitChance,
				DodgeChance = dodgeChance,
				HitSmoothed = acc.hit,
				HitAttempts = acc.hitN,
				HitProven = acc.hitProven,
				DodgeSmoothed = acc.dodge,
				DodgeAttempts = acc.dodgeN,
				DodgeProven = acc.dodgeProven,
				Status = ("DepartureReason" in l) ? l.DepartureReason : "离队",
				StatusType = ("StatusType" in l) ? l.StatusType : "left",
				Source = "legacy",
				SourceIdx = i,
				ImagePath = ("CachedPortrait" in l) ? l.CachedPortrait : "",
				ImageOffsetX = ("CachedPortraitX" in l) ? l.CachedPortraitX : 0,
				ImageOffsetY = ("CachedPortraitY" in l) ? l.CachedPortraitY : 0,
				Appearance = ("Appearance" in l) ? l.Appearance : null,
				BackgroundIcon = ("BackgroundIcon" in l) ? l.BackgroundIcon : "",
				LevelHistory = (hasStats && ("LevelHistory" in l.CareerStats_Stats.m)) ? l.CareerStats_Stats.m.LevelHistory : [],
				DodgeMetric = dodgeMetric
			});
		}

		// 3) Living brothers.
		local livingByID = {};
		foreach (bro in bros)
		{
			if (bro == null) continue;
			try { if ("isNull" in bro && bro.isNull()) continue; } catch (e) {}
			livingByID[bro.getID()] <- bro;

			local damageDealt = 0;
			local battles = 0;
			local kills = 0;
			local smoothedRating = 0.0;
			local dpsHp = 0;
			local dpsArmor = 0;
			local hitChance = 0.0;
			local dodgeChance = 0.0;
			local dodgeMetric = 0.0;
			local acc = accFields(null);
			local hasStats = ("CareerStats_Stats" in bro.m && bro.m.CareerStats_Stats != null);
			if (hasStats)
			{
				local st = bro.m.CareerStats_Stats;
				damageDealt = st.getDamageDealt();
				battles = st.m.Stats.Battles;
				kills = st.m.Stats.Kills;
				smoothedRating = st.getSmoothedRating();
				dodgeMetric = st.getSmoothedDodge();
				dpsHp = st.getDamageDealtAvgHitpoints();
				dpsArmor = st.getDamageDealtAvgArmor();
				hitChance = st.getAvgHitChance();
				dodgeChance = st.getAvgDodgeChance();
				acc = accFields(st);
			}

			local liveBgIcon = "";
			try
			{
				local ic = bro.getBackground().getIcon();
				if (ic != null) liveBgIcon = ic;
			}
			catch (e) {}

			entries.push({
				Name = bro.getName(),
				NameOnly = bro.getNameOnly(),
				Level = bro.getLevel(),
				TimeWithCompany = bro.getDaysWithCompany(),
				Battles = battles,
				Kills = kills,
				DamageDealt = damageDealt,
				SmoothedRating = smoothedRating,
				DPSHp = dpsHp,
				DPSArmor = dpsArmor,
				HitChance = hitChance,
				DodgeChance = dodgeChance,
				HitSmoothed = acc.hit,
				HitAttempts = acc.hitN,
				HitProven = acc.hitProven,
				DodgeSmoothed = acc.dodge,
				DodgeAttempts = acc.dodgeN,
				DodgeProven = acc.dodgeProven,
				Status = "在役",
				StatusType = "alive",
				Source = "living",
				SourceIdx = bro.getID(),
				ImagePath = ("CareerStats_CachedPortrait" in bro.m) ? bro.m.CareerStats_CachedPortrait : bro.getImagePath(),
				ImageOffsetX = ("CareerStats_CachedPortraitX" in bro.m) ? bro.m.CareerStats_CachedPortraitX : bro.getImageOffsetX(),
				ImageOffsetY = ("CareerStats_CachedPortraitY" in bro.m) ? bro.m.CareerStats_CachedPortraitY : bro.getImageOffsetY(),
				Appearance = ::CareerStats.captureAppearance(bro),
				BackgroundIcon = liveBgIcon,
				LevelHistory = (hasStats && ("LevelHistory" in bro.m.CareerStats_Stats.m)) ? bro.m.CareerStats_Stats.m.LevelHistory : [],
				DodgeMetric = dodgeMetric
			});
		}

		local filtered = [];
		foreach (e in entries)
		{
			if (e.Level > 1) filtered.push(e);
		}

		// Rank points: damage axis + dodge axis.
		local RANKMAX = ("RANK_POINTS_MAX" in ::CareerStats) ? ::CareerStats.RANK_POINTS_MAX : 100;

		local byDmg = clone filtered;
		byDmg.sort(function( a, b ) {
			if (b.SmoothedRating != a.SmoothedRating) return b.SmoothedRating > a.SmoothedRating ? 1 : -1;
			if (b.Battles != a.Battles) return b.Battles <=> a.Battles;
			return b.Kills <=> a.Kills;
		});
		for (local i = 0; i < byDmg.len(); i++)
		{
			local p = RANKMAX - (i + 1);
			byDmg[i].DmgPoints <- (p > 0 ? p : 0);
		}

		local byDodge = clone filtered;
		byDodge.sort(function( a, b ) {
			if (b.DodgeMetric != a.DodgeMetric) return b.DodgeMetric > a.DodgeMetric ? 1 : -1;
			if (b.Battles != a.Battles) return b.Battles <=> a.Battles;
			return b.Kills <=> a.Kills;
		});
		for (local i = 0; i < byDodge.len(); i++)
		{
			local p = RANKMAX - (i + 1);
			byDodge[i].DodgePoints <- (p > 0 ? p : 0);
		}

		foreach (e in filtered)
			e.CombinedScore <- e.DmgPoints + e.DodgePoints;

		filtered.sort(function( a, b ) {
			if (b.CombinedScore != a.CombinedScore) return b.CombinedScore <=> a.CombinedScore;
			if (b.SmoothedRating != a.SmoothedRating) return b.SmoothedRating > a.SmoothedRating ? 1 : -1;
			if (b.Battles != a.Battles) return b.Battles <=> a.Battles;
			return b.Kills <=> a.Kills;
		});

		local lastRank = 0;
		local lastScore = -2147483647;
		for (local i = 0; i < filtered.len(); i++)
		{
			local sc = filtered[i].CombinedScore;
			if (sc != lastScore)
			{
				lastRank = i + 1;
				lastScore = sc;
			}
			filtered[i].Rank <- lastRank;
		}

		// Rank change arrow snapshots (living brothers only).
		local currentRanks = {};
		foreach (e in filtered)
		{
			if (e.StatusType == "alive") currentRanks[e.Name] <- e.Rank;
		}

		local hasChange = false;
		if (typeof this.m.CareerStats_RankSnapshot == "table" && this.m.CareerStats_RankSnapshot.len() > 0)
		{
			foreach (name, currRank in currentRanks)
			{
				local oldRank = (name in this.m.CareerStats_RankSnapshot) ? this.m.CareerStats_RankSnapshot[name] : -1;
				if (oldRank != currRank) { hasChange = true; break; }
			}
		}
		else
		{
			hasChange = true;
		}

		local arrowPrevSnapshot;
		if (hasChange)
		{
			arrowPrevSnapshot = (this.m.CareerStats_RankSnapshot != null && typeof this.m.CareerStats_RankSnapshot == "table")
				? clone this.m.CareerStats_RankSnapshot
				: {};
			this.m.CareerStats_ArrowPrevSnapshot = arrowPrevSnapshot;
			this.m.CareerStats_RankSnapshot = currentRanks;
		}
		else
		{
			arrowPrevSnapshot = this.m.CareerStats_ArrowPrevSnapshot;
		}

		foreach (e in filtered)
		{
			local tooltip = [{ id = 1, type = "title", text = e.Name }];
			if (e.Source == "fallen")
			{
				local f = this.m.Fallen[e.SourceIdx];
				if ("CareerStats_Stats" in f && f.CareerStats_Stats != null)
				{
					f.CareerStats_Stats.m.Ranks.DamageDealtAvg <- e.Rank;
					f.CareerStats_Stats.extendTooltip(tooltip, 2);
				}
				else
					tooltip.push({ id = 2, type = "text", text = "这名战士的统计数据未被保存。" });
			}
			else if (e.Source == "legacy")
			{
				local l = this.m.Legacy[e.SourceIdx];
				if ("CareerStats_Stats" in l && l.CareerStats_Stats != null)
				{
					l.CareerStats_Stats.m.Ranks.DamageDealtAvg <- e.Rank;
					l.CareerStats_Stats.extendTooltip(tooltip, 2);
				}
				else
					tooltip.push({ id = 2, type = "text", text = "这名战士的统计数据未被保存。" });
			}
			else if (e.Source == "living" && (e.SourceIdx in livingByID))
			{
				local bro = livingByID[e.SourceIdx];
				if ("CareerStats_Stats" in bro.m && bro.m.CareerStats_Stats != null)
				{
					bro.m.CareerStats_Stats.m.Ranks.DamageDealtAvg <- e.Rank;
					bro.m.CareerStats_Stats.extendTooltip(tooltip, 2);
				}
			}
			tooltips.push(tooltip);

			if (e.StatusType == "alive")
				e.PrevRank <- (e.Name in arrowPrevSnapshot) ? arrowPrevSnapshot[e.Name] : -1;
			else
				e.PrevRank <- -1;
		}

		::CareerStats.HallOfFameTooltips = tooltips;
		return filtered;
	};

	q.CareerStats_getTooltipForFallen <- function( _idx )
	{
		local tooltip = [{ id = 1, type = "title", text = this.m.Fallen[_idx].Name }];
		if ("CareerStats_Stats" in this.m.Fallen[_idx] && this.m.Fallen[_idx].CareerStats_Stats != null)
			this.m.Fallen[_idx].CareerStats_Stats.extendTooltip(tooltip, 2);
		else
			tooltip.push({ id = 2, type = "text", text = "这名角色阵亡时生涯统计尚未加载，其数据已永久丢失。" });
		return tooltip;
	};

	q.onSerialize = @(__original) function( _out )
	{
		local fallenWithCareerStats = [];
		local fallenLevels = [];
		local fallenAppearances = [];
		local fallenPortraits = [];
		local fallenBackgrounds = [];
		local fallenNames = [];

		for (local i = 0; i < this.m.Fallen.len(); ++i)
		{
			local f = this.m.Fallen[i];
			if ("CareerStats_Stats" in f && f.CareerStats_Stats != null)
			{
				fallenWithCareerStats.push(i);
				f.CareerStats_Stats.onSerialize(::CareerStats.Mod.Serialization.getSerializationEmulator("StatsFor" + i, this.m.Flags));
			}
			fallenLevels.push(("Level" in f) ? f.Level : 0);
			if ("Appearance" in f && f.Appearance != null)
			{
				local compact = ::CareerStats._compactAppearance(f.Appearance);
				if (compact != null) fallenAppearances.push({ idx = i, app = compact });
			}
			if ("CachedPortrait" in f && f.CachedPortrait != "")
			{
				fallenPortraits.push({
					idx = i,
					path = f.CachedPortrait,
					x = ("CachedPortraitX" in f) ? f.CachedPortraitX : 0,
					y = ("CachedPortraitY" in f) ? f.CachedPortraitY : 0
				});
			}
			if ("BackgroundIcon" in f && f.BackgroundIcon != "")
				fallenBackgrounds.push({ idx = i, icon = f.BackgroundIcon });
			fallenNames.push(("NameOnly" in f) ? f.NameOnly : f.Name);
		}

		::CareerStats.Mod.Serialization.flagSerialize("FallenWithStats", fallenWithCareerStats, this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("FallenLevels", fallenLevels, this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("FallenAppearances", fallenAppearances, this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("FallenPortraits", fallenPortraits, this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("FallenBackgrounds", fallenBackgrounds, this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("FallenNameOnly", fallenNames, this.m.Flags);

		local legacyData = [];
		for (local i = 0; i < this.m.Legacy.len(); i++)
		{
			local l = this.m.Legacy[i];
			local hasStats = ("CareerStats_Stats" in l && l.CareerStats_Stats != null);
			local appCompact = ::CareerStats._compactAppearance(("Appearance" in l) ? l.Appearance : null);

			legacyData.push({
				Name = l.Name,
				NameOnly = ("NameOnly" in l) ? l.NameOnly : l.Name,
				Level = ("Level" in l) ? l.Level : 0,
				TimeWithCompany = ("TimeWithCompany" in l) ? l.TimeWithCompany : 0,
				Battles = ("Battles" in l) ? l.Battles : 0,
				Kills = ("Kills" in l) ? l.Kills : 0,
				DamageDealt = ("DamageDealt" in l) ? l.DamageDealt : 0,
				DepartureReason = ("DepartureReason" in l) ? l.DepartureReason : "离队",
				StatusType = ("StatusType" in l) ? l.StatusType : "left",
				HasStats = hasStats,
				Appearance = appCompact,
				CachedPortrait = ("CachedPortrait" in l) ? l.CachedPortrait : "",
				CachedPortraitX = ("CachedPortraitX" in l) ? l.CachedPortraitX : 0,
				CachedPortraitY = ("CachedPortraitY" in l) ? l.CachedPortraitY : 0,
				BackgroundIcon = ("BackgroundIcon" in l) ? l.BackgroundIcon : ""
			});

			if (hasStats)
				l.CareerStats_Stats.onSerialize(::CareerStats.Mod.Serialization.getSerializationEmulator("LegacyStats" + i, this.m.Flags));
		}
		::CareerStats.Mod.Serialization.flagSerialize("LegacyArray", legacyData, this.m.Flags);

		// Keep only living brothers in rank snapshots.
		local livingNames = {};
		try
		{
			foreach (bro in ::World.getPlayerRoster().getAll())
			{
				if (bro == null) continue;
				try { if ("isNull" in bro && bro.isNull()) continue; } catch (eN) {}
				try { livingNames[bro.getName()] <- true; } catch (eN2) {}
			}
		}
		catch (e) {}

		local function aliveOnly( _snap )
		{
			if (_snap == null || typeof _snap != "table") return {};
			if (livingNames.len() == 0) return _snap;
			local out = {};
			foreach (k, v in _snap)
				if (k in livingNames) out[k] <- v;
			return out;
		}

		::CareerStats.Mod.Serialization.flagSerialize("RankSnapshot",      aliveOnly(this.m.CareerStats_RankSnapshot),      this.m.Flags);
		::CareerStats.Mod.Serialization.flagSerialize("ArrowPrevSnapshot", aliveOnly(this.m.CareerStats_ArrowPrevSnapshot), this.m.Flags);

		// Finance history (compacted per day).
		try
		{
			local hist = [];
			if (::World != null && ("Assets" in ::World) && ::World.Assets != null
				&& ("CareerStats_FinanceHistory" in ::World.Assets.m))
			{
				hist = ::World.Assets.m.CareerStats_FinanceHistory;
			}
			local compacted = ::CareerStats.compactFinanceHistory(hist, 1);
			if (::World != null && ("Assets" in ::World) && ::World.Assets != null)
				::World.Assets.m.CareerStats_FinanceHistory = compacted;
			::CareerStats.Mod.Serialization.flagSerialize("CareerStats_FinanceHistory", compacted, this.m.Flags);
		}
		catch (e) {}

		// Collapse MSU.* flag entries into <=60KB chunks to prevent vanilla's 65535 U16 tag_collection overflow.
		try
		{
			local CHUNK = 60000;
			local flags = this.m.Flags;
			local toCollapse = [];
			local stale = [];
			foreach (k, _v in flags.m)
			{
				if (typeof k != "string") continue;
				if (k == "~CSblobN~" || (k.len() >= 5 && k.slice(0, 5) == "~CSb~")) { stale.push(k); continue; }
				if (k.len() >= 4 && k.slice(0, 4) == "MSU.") toCollapse.push(k);
			}
			foreach (k in stale) flags.remove(k);

			local parts = [];
			foreach (k in toCollapse)
			{
				local v = flags.get(k);
				local t = typeof v;
				local tc, vs;
				if (t == "integer") { tc = "i"; vs = v.tostring(); }
				else if (t == "float") { tc = "f"; vs = v.tostring(); }
				else if (t == "bool") { tc = "b"; vs = v ? "1" : "0"; }
				else if (t == "string") { tc = "s"; vs = v; }
				else continue;
				parts.push("" + k.len() + ":" + k + tc + "" + vs.len() + ":" + vs);
				flags.remove(k);
			}
			while (parts.len() > 1)
			{
				local merged = [];
				for (local i = 0; i < parts.len(); i += 2)
					merged.push(i + 1 < parts.len() ? parts[i] + parts[i + 1] : parts[i]);
				parts = merged;
			}
			local blob = parts.len() > 0 ? parts[0] : "";

			local nChunks = 0;
			if (blob.len() > 0)
			{
				nChunks = (blob.len() + CHUNK - 1) / CHUNK;
				for (local j = 0; j < nChunks; j++)
				{
					local a = j * CHUNK;
					local b = (a + CHUNK < blob.len()) ? (a + CHUNK) : blob.len();
					flags.set("~CSb~" + j, blob.slice(a, b));
				}
			}
			flags.set("~CSblobN~", nChunks);
		}
		catch (e)
		{
			::logWarning("CareerStats: flag-collapse serialize failed: " + e);
		}

		return __original(_out);
	};

	q.onDeserialize = @(__original) function( _in )
	{
		local ret = __original(_in);

		// Re-expand collapsed MSU.* blob before any CareerStats reader touches this.m.Flags.
		try
		{
			local flags = this.m.Flags;
			if (flags.has("~CSblobN~"))
			{
				local nChunks = flags.get("~CSblobN~");
				if (typeof nChunks == "integer" && nChunks > 0)
				{
					local blob = "";
					for (local j = 0; j < nChunks; j++)
					{
						local ck = "~CSb~" + j;
						if (flags.has(ck)) { blob += flags.get(ck); flags.remove(ck); }
					}
					local pos = 0;
					local L = blob.len();
					while (pos < L)
					{
						local c1 = blob.find(":", pos);
						if (c1 == null) break;
						local klen = blob.slice(pos, c1).tointeger();
						local kstart = c1 + 1;
						local key = blob.slice(kstart, kstart + klen);
						pos = kstart + klen;
						if (pos >= L) break;
						local tc = blob.slice(pos, pos + 1);
						pos += 1;
						local c2 = blob.find(":", pos);
						if (c2 == null) break;
						local vlen = blob.slice(pos, c2).tointeger();
						local vstart = c2 + 1;
						local vs = blob.slice(vstart, vstart + vlen);
						pos = vstart + vlen;
						local val;
						if (tc == "i") val = vs.tointeger();
						else if (tc == "f") val = vs.tofloat();
						else if (tc == "b") val = (vs == "1");
						else val = vs;
						flags.set(key, val);
					}
				}
				flags.remove("~CSblobN~");
			}
		}
		catch (e)
		{
			::logWarning("CareerStats: flag-expand deserialize failed: " + e);
		}

		// Fallen stats & metadata.
		if (::CareerStats.Mod.Serialization.isSavedVersionAtLeast("0.2.0", _in.getMetaData()))
		{
			local isNewFmt = ::CareerStats.Mod.Serialization.isSavedVersionAtLeast("1.0.0-rc.1", _in.getMetaData());
			local fallenWithCareerStats = isNewFmt
				? ::CareerStats.Mod.Serialization.flagDeserialize("FallenWithStats", [], null, this.m.Flags)
				: ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_FallenWithStats", [], null, this.m.Flags);

			foreach (i in fallenWithCareerStats)
			{
				if (i >= 0 && i < this.m.Fallen.len())
				{
					this.m.Fallen[i].CareerStats_Stats <- ::new("scripts/mods/career_stats/career_stats");
					this.m.Fallen[i].CareerStats_Stats.onDeserialize(
						::CareerStats.Mod.Serialization.getDeserializationEmulator(
							isNewFmt ? ("StatsFor" + i) : ("CareerStats_Fallen" + i),
							this.m.Flags
						)
					);
				}
			}
		}

		try
		{
			local fallenLevels = ::CareerStats.Mod.Serialization.flagDeserialize("FallenLevels", [], null, this.m.Flags);
			if (typeof fallenLevels == "array")
				for (local i = 0; i < fallenLevels.len() && i < this.m.Fallen.len(); i++)
					this.m.Fallen[i].Level <- fallenLevels[i];
		}
		catch (e) {}

		try
		{
			local fallenAppearances = ::CareerStats.Mod.Serialization.flagDeserialize("FallenAppearances", [], null, this.m.Flags);
			if (typeof fallenAppearances == "array")
				foreach (fa in fallenAppearances)
					if (("idx" in fa) && ("app" in fa) && fa.idx >= 0 && fa.idx < this.m.Fallen.len())
						this.m.Fallen[fa.idx].Appearance <- fa.app;
		}
		catch (e) {}

		try
		{
			local fallenPortraits = ::CareerStats.Mod.Serialization.flagDeserialize("FallenPortraits", [], null, this.m.Flags);
			if (typeof fallenPortraits == "array")
				foreach (fp in fallenPortraits)
					if (("idx" in fp) && ("path" in fp) && fp.idx >= 0 && fp.idx < this.m.Fallen.len())
					{
						this.m.Fallen[fp.idx].CachedPortrait <- fp.path;
						this.m.Fallen[fp.idx].CachedPortraitX <- ("x" in fp) ? fp.x : 0;
						this.m.Fallen[fp.idx].CachedPortraitY <- ("y" in fp) ? fp.y : 0;
					}
		}
		catch (e) {}

		try
		{
			local fallenBackgrounds = ::CareerStats.Mod.Serialization.flagDeserialize("FallenBackgrounds", [], null, this.m.Flags);
			if (typeof fallenBackgrounds == "array")
				foreach (fb in fallenBackgrounds)
					if (("idx" in fb) && ("icon" in fb) && fb.idx >= 0 && fb.idx < this.m.Fallen.len())
						this.m.Fallen[fb.idx].BackgroundIcon <- fb.icon;
		}
		catch (e) {}

		try
		{
			local fallenNames = ::CareerStats.Mod.Serialization.flagDeserialize("FallenNameOnly", [], null, this.m.Flags);
			if (typeof fallenNames == "array")
				for (local i = 0; i < fallenNames.len() && i < this.m.Fallen.len(); i++)
					this.m.Fallen[i].NameOnly <- fallenNames[i];
		}
		catch (e) {}

		// Legacy departed array.
		this.m.Legacy = [];
		try
		{
			local legacyData = ::CareerStats.Mod.Serialization.flagDeserialize("LegacyArray", [], null, this.m.Flags);
			if (typeof legacyData == "array")
			{
				for (local i = 0; i < legacyData.len(); i++)
				{
					local ld = legacyData[i];
					local entry = {
						Name = ld.Name,
						NameOnly = ("NameOnly" in ld) ? ld.NameOnly : ld.Name,
						Level = ("Level" in ld) ? ld.Level : 0,
						TimeWithCompany = ("TimeWithCompany" in ld) ? ld.TimeWithCompany : 0,
						Battles = ("Battles" in ld) ? ld.Battles : 0,
						Kills = ("Kills" in ld) ? ld.Kills : 0,
						DamageDealt = ("DamageDealt" in ld) ? ld.DamageDealt : 0,
						DepartureReason = ("DepartureReason" in ld) ? ld.DepartureReason : "离队",
						StatusType = ("StatusType" in ld) ? ld.StatusType : "left"
					};
					if ("Appearance" in ld && ld.Appearance != null) entry.Appearance <- ld.Appearance;
					if ("BackgroundIcon" in ld && ld.BackgroundIcon != null && ld.BackgroundIcon != "") entry.BackgroundIcon <- ld.BackgroundIcon;
					if ("CachedPortrait" in ld && ld.CachedPortrait != "")
					{
						entry.CachedPortrait <- ld.CachedPortrait;
						entry.CachedPortraitX <- ("CachedPortraitX" in ld) ? ld.CachedPortraitX : 0;
						entry.CachedPortraitY <- ("CachedPortraitY" in ld) ? ld.CachedPortraitY : 0;
					}
					if ("HasStats" in ld && ld.HasStats)
					{
						entry.CareerStats_Stats <- ::new("scripts/mods/career_stats/career_stats");
						entry.CareerStats_Stats.onDeserialize(::CareerStats.Mod.Serialization.getDeserializationEmulator("LegacyStats" + i, this.m.Flags));
					}
					this.m.Legacy.push(entry);
				}
			}
		}
		catch (e) { this.m.Legacy = []; }

		try
		{
			local snap = ::CareerStats.Mod.Serialization.flagDeserialize("RankSnapshot", {}, null, this.m.Flags);
			this.m.CareerStats_RankSnapshot = (snap != null && typeof snap == "table") ? snap : {};
		}
		catch (e) { this.m.CareerStats_RankSnapshot = {}; }

		try
		{
			local arrowSnap = ::CareerStats.Mod.Serialization.flagDeserialize("ArrowPrevSnapshot", {}, null, this.m.Flags);
			this.m.CareerStats_ArrowPrevSnapshot = (arrowSnap != null && typeof arrowSnap == "table") ? arrowSnap : {};
		}
		catch (e) { this.m.CareerStats_ArrowPrevSnapshot = {}; }

		try
		{
			local hist = ::CareerStats.Mod.Serialization.flagDeserialize("CareerStats_FinanceHistory", [], null, this.m.Flags);
			if (hist == null || typeof hist != "array") hist = [];
			if (hist.len() > 1000)
			{
				try { hist = ::CareerStats.compactFinanceHistory(hist, 1); } catch (e2) {}
			}
			if (::World != null && ("Assets" in ::World) && ::World.Assets != null)
				::World.Assets.m.CareerStats_FinanceHistory = hist;
			else
				::CareerStats._PendingFinanceHistory <- hist;
		}
		catch (e) { ::CareerStats._PendingFinanceHistory <- []; }

		return ret;
	};
});
