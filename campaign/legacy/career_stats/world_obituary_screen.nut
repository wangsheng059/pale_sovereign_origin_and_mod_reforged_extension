// Hall of Fame / Obituary screen integration for Career Stats.
// Caches any missing/changed naked portraits atomically (and immediately restores
// all weapons & armor layers) instead of leaving brothers unequipped until onClose.

::CareerStats.MH.hook("scripts/ui/screens/world/world_obituary_screen", function(q)
{
	q.convertFallenToUIData = @(__original) function()
	{
		try { ::CareerStats.cacheNakedPortraits(false); } catch (e) {}

		local hallOfFame = ::World.Statistics.CareerStats_buildHallOfFame();
		for (local i = 0; i < hallOfFame.len(); i++)
		{
			hallOfFame[i].HallOfFameIdx <- i;
			if (!("ImagePath" in hallOfFame[i]))
			{
				hallOfFame[i].ImagePath <- "";
				hallOfFame[i].ImageOffsetX <- 0;
				hallOfFame[i].ImageOffsetY <- 0;
			}
		}

		local totalAlive = 0;
		local totalFallen = 0;
		local totalDeparted = 0;
		foreach (e in hallOfFame)
		{
			if (e.StatusType == "alive") totalAlive++;
			else if (e.StatusType == "fallen") totalFallen++;
			else totalDeparted++;
		}

		local financeHistory = [];
		try
		{
			if ("CareerStats_FinanceHistory" in ::World.Assets.m)
				financeHistory = ::World.Assets.m.CareerStats_FinanceHistory;
		}
		catch (e) {}

		try { ::CareerStats.updateStrengthSnapshots(); } catch (e) {}

		local strengthHistory = [];
		local deathMarkers = [];
		local injuryMarkers = [];
		local ringMarkers = [];
		try
		{
			if ("CareerStats_StrengthHistory_V2" in ::World.Statistics.m)
				strengthHistory = ::World.Statistics.m.CareerStats_StrengthHistory_V2;
			if ("CareerStats_DeathMarkers" in ::World.Statistics.m)
				deathMarkers = ::World.Statistics.m.CareerStats_DeathMarkers;
			if ("CareerStats_InjuryMarkers" in ::World.Statistics.m)
				injuryMarkers = ::World.Statistics.m.CareerStats_InjuryMarkers;
			if ("CareerStats_RingMarkers" in ::World.Statistics.m && ::CareerStats.hasJewelryMod())
				ringMarkers = ::World.Statistics.m.CareerStats_RingMarkers;
		}
		catch (e) {}

		local hardenedScaling = false;
		try { hardenedScaling = ::CareerStats.hasHardenedScaling(); } catch (e) {}

		local strengthOut = [];
		try
		{
			foreach (p in strengthHistory)
			{
				local day = ("day" in p) ? p.day : 0;
				local raw = ("strength" in p) ? p.strength : 0.0;
				local factor = ::CareerStats.difficultyFactorForDay(day);
				local diffPct = ::CareerStats.worldDifficultyForDay(day) * 100.0;
				local adj = raw * factor;
				if (adj < 0.0) adj = 0.0;
				if (adj > 100.0) adj = 100.0;
				strengthOut.push({
					day      = day,
					strength = adj,
					raw      = raw,
					factor   = factor * 100.0,
					diff     = diffPct,
					bf       = ("bf" in p) ? p.bf : false,
					hit      = ("hit" in p) ? p.hit : 0.0,
					dodge    = ("dodge" in p) ? p.dodge : 0.0
				});
			}
		}
		catch (e) { strengthOut = strengthHistory; }

		local curDiffPct = hardenedScaling ? ::CareerStats.currentWorldDifficultyPct() : null;
		local maxDiffPct = hardenedScaling ? ::CareerStats.maxWorldDifficultyPct() : null;

		return {
			Entries = hallOfFame,
			TotalCount = hallOfFame.len(),
			AliveCount = totalAlive,
			FallenCount = totalFallen,
			DepartedCount = totalDeparted,
			CompanyName = ::World.Assets.getName(),
			Lang = "en",
			FinanceHistory = financeHistory,
			StrengthHistory = strengthOut,
			StrengthHardened = hardenedScaling,
			StrengthCurDiffPct = curDiffPct,
			StrengthMaxDiffPct = maxDiffPct,
			DeathMarkers = deathMarkers,
			InjuryMarkers = injuryMarkers,
			RingMarkers = ringMarkers
		};
	};
});
