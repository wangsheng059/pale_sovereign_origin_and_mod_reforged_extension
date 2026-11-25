// Player roster wrapper for Career Stats.
// Fixes the exponential closure-stacking leak in original mod_Legacy by wrapping
// each playerRoster instance AT MOST ONCE via a per-instance guard slot.

local origGetPlayerRoster = ::World.getPlayerRoster;
::World.getPlayerRoster = function()
{
	local playerRoster = origGetPlayerRoster();
	if (playerRoster == null || ("_csRosterHooked" in playerRoster))
		return playerRoster;

	playerRoster._csRosterHooked <- true;

	local origRemove = playerRoster.remove;
	playerRoster.remove = function( ... )
	{
		vargv.insert(0, this);
		local bro = vargv.len() > 1 ? vargv[1] : null;
		local validBro = (bro != null && !("isNull" in bro && bro.isNull()));

		local appearance = null;
		local bgIcon = "";
		if (validBro)
		{
			appearance = ::CareerStats.captureAppearance(bro);
			try
			{
				local ic = bro.getBackground().getIcon();
				if (ic != null) bgIcon = ic;
			}
			catch (e) {}
		}

		if (::CareerStats.LastFallen == null && validBro)
		{
			local hasStats = ("CareerStats_Stats" in bro.m && bro.m.CareerStats_Stats != null);
			local level = 0;
			local daysWithCompany = 0;
			local battles = 0;
			local kills = 0;
			local damageDealt = 0;

			try { level = bro.getLevel(); } catch (e) {}
			try { daysWithCompany = bro.getDaysWithCompany(); } catch (e) {}

			if (hasStats)
			{
				battles = bro.m.CareerStats_Stats.m.Stats.Battles;
				kills = bro.m.CareerStats_Stats.m.Stats.Kills;
				damageDealt = bro.m.CareerStats_Stats.getDamageDealt();
			}

			if (level > 1)
			{
				local departureReason = "Left";
				local statusType = "left";

				local fatalCause = null;
				try
				{
					if ("CareerStats_FatalCause" in bro.m && bro.m.CareerStats_FatalCause != null)
						fatalCause = bro.m.CareerStats_FatalCause;
				}
				catch (e) {}

				if (fatalCause != null)
				{
					departureReason = fatalCause;
					statusType = "fallen";
				}
				else if (::CareerStats.PendingDeparture != null)
				{
					departureReason = ::CareerStats.PendingDeparture;
					if (departureReason == "Dismissed" || departureReason == "Retired")
						statusType = "dismissed";
					else if (departureReason == "Deserted")
						statusType = "deserted";
					else if (departureReason == "Banished")
						statusType = "banished";
					else
						statusType = "left";
				}

				local entry = {
					Name = bro.getName(),
					NameOnly = bro.getNameOnly(),
					Level = level,
					TimeWithCompany = daysWithCompany,
					Battles = battles,
					Kills = kills,
					DamageDealt = damageDealt,
					DepartureReason = departureReason,
					StatusType = statusType
				};

				if (hasStats)
				{
					bro.m.CareerStats_Stats.clearRanks();
					entry.CareerStats_Stats <- bro.m.CareerStats_Stats;
				}
				if (appearance != null) entry.Appearance <- appearance;
				if (bgIcon != "") entry.BackgroundIcon <- bgIcon;

				try
				{
					if ("CareerStats_CachedPortrait" in bro.m)
					{
						entry.CachedPortrait <- bro.m.CareerStats_CachedPortrait;
						entry.CachedPortraitX <- ("CareerStats_CachedPortraitX" in bro.m) ? bro.m.CareerStats_CachedPortraitX : 0;
						entry.CachedPortraitY <- ("CareerStats_CachedPortraitY" in bro.m) ? bro.m.CareerStats_CachedPortraitY : 0;
					}
					else
					{
						entry.CachedPortrait <- bro.getImagePath();
						entry.CachedPortraitX <- bro.getImageOffsetX();
						entry.CachedPortraitY <- bro.getImageOffsetY();
					}
				}
				catch (e) {}

				::World.Statistics.addLegacy(entry);
			}

			::CareerStats.PendingDeparture = null;
		}
		else if (::CareerStats.LastFallen != null && validBro)
		{
			local lf = ::CareerStats.LastFallen;
			if ("CareerStats_Stats" in bro.m)
				lf.CareerStats_Stats <- bro.m.CareerStats_Stats;

			try
			{
				if (!("Level" in lf)) lf.Level <- bro.getLevel();
				if (!("NameOnly" in lf)) lf.NameOnly <- bro.getNameOnly();
			}
			catch (e) {}

			if (appearance != null) lf.Appearance <- appearance;
			if (bgIcon != "") lf.BackgroundIcon <- bgIcon;

			try
			{
				if ("CareerStats_CachedPortrait" in bro.m)
				{
					lf.CachedPortrait <- bro.m.CareerStats_CachedPortrait;
					lf.CachedPortraitX <- ("CareerStats_CachedPortraitX" in bro.m) ? bro.m.CareerStats_CachedPortraitX : 0;
					lf.CachedPortraitY <- ("CareerStats_CachedPortraitY" in bro.m) ? bro.m.CareerStats_CachedPortraitY : 0;
				}
				else
				{
					lf.CachedPortrait <- bro.getImagePath();
					lf.CachedPortraitX <- bro.getImageOffsetX();
					lf.CachedPortraitY <- bro.getImageOffsetY();
				}
			}
			catch (e) {}

			::CareerStats.LastFallen = null;
			::CareerStats.PendingDeparture = null;
		}

		local ret = origRemove.acall(vargv);
		::CareerStats.evaluateRanks();
		return ret;
	};

	local origCreate = playerRoster.create;
	playerRoster.create = function( ... )
	{
		vargv.insert(0, this);
		local ret = origCreate.acall(vargv);
		::CareerStats.evaluateRanks();
		return ret;
	};

	local origClear = playerRoster.clear;
	playerRoster.clear = function( ... )
	{
		vargv.insert(0, this);
		local ret = origClear.acall(vargv);
		::CareerStats.evaluateRanks();
		return ret;
	};

	local origAdd = playerRoster.add;
	playerRoster.add = function( ... )
	{
		vargv.insert(0, this);
		local ret = origAdd.acall(vargv);
		::CareerStats.evaluateRanks();
		return ret;
	};

	return playerRoster;
};
