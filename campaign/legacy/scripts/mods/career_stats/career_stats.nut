// Per-brother career statistics container (refactored Legacy v2.0.0).
// Preserves exact MSU emulator serialization layout for 100% save compatibility.

this.career_stats <- {
	m = {
		Stats = {
			DamageReceivedHitpoints = 0,
			DamageReceivedArmor = 0,
			DamageDealtHitpoints = 0,
			DamageDealtArmor = 0,
			MaxDamageHitpoints = 0,
			MaxDamageArmor = 0,
			MaxDamageAttackHitpoints = 0,
			MaxDamageAttackArmor = 0,
			NumHeadHits = 0,
			NumHits = 0,
			NumAccuracyHits = 0,
			NumAccuracyMisses = 0,
			NumAccuracyDodges = 0,
			NumAccuracyHitsReceived = 0,
			Num5PercentHits = 0,
			Num95PercentMisses = 0,
			Battles = 0,
			NineLivesUses = 0,
			NineLivesSaves = 0,
			MaxKillsInBattle = 0,
			Kills = 0
		},
		Ranks = {
			DamageDealt = 0,
			DamageDealtAvg = 0,
			DamageReceived = 0,
			DamageReceivedAvg = 0,
			MaxDamage = 0,
			AvgHitChance = 0,
			AvgHeadshotChance = 0,
			AvgDodgeChance = 0,
			Num5PercentHits = 0,
			Num95PercentMisses = 0
		},
		BrotherMentors = [],
		VeteranMentors = [],
		LevelHistory = [],
		IDCounter = 0,
		Player = null
	},

	// True only if this brother has any non-default career data worth persisting.
	// Prevents serializing ~180 flags onto every unhired town recruit.
	function hasData()
	{
		if (this.m.VeteranMentors.len() > 0) return true;
		if (this.m.BrotherMentors.len() > 0) return true;
		if (this.m.LevelHistory.len() > 0) return true;
		foreach (k, v in this.m.Stats)
		{
			if (v != 0) return true;
		}
		return false;
	}

	function recordLevelUp( _day, _level )
	{
		foreach (entry in this.m.LevelHistory)
		{
			if (entry.level == _level) return;
		}
		this.m.LevelHistory.push({ day = _day, level = _level });
	}

	function getLevelHistory() { return this.m.LevelHistory; }

	function onNineLivesUse()  { this.m.Stats.NineLivesUses++; }
	function onNineLivesSave() { this.m.Stats.NineLivesSaves++; }

	function getKills()               { return this.m.Stats.Kills; }
	function getBattles()             { return this.m.Stats.Battles; }
	function getNum5PercentHits()     { return this.m.Stats.Num5PercentHits; }
	function getNum95PercentMisses()  { return this.m.Stats.Num95PercentMisses; }
	function getNineLivesUses()       { return this.m.Stats.NineLivesUses; }
	function getNineLivesSaves()      { return this.m.Stats.NineLivesSaves; }
	function getMaxKillsInBattle()    { return this.m.Stats.MaxKillsInBattle; }

	function getDamageDealt()
	{
		return this.m.Stats.DamageDealtHitpoints + this.m.Stats.DamageDealtArmor;
	}

	function getDamageDealtAvg()
	{
		if (this.m.Stats.Battles <= 0) return this.getDamageDealt();
		return this.getDamageDealt() / this.m.Stats.Battles;
	}

	function getDamageDealtAvgHitpoints()
	{
		if (this.m.Stats.Battles <= 0) return this.m.Stats.DamageDealtHitpoints;
		return this.m.Stats.DamageDealtHitpoints / this.m.Stats.Battles;
	}

	function getDamageDealtAvgArmor()
	{
		if (this.m.Stats.Battles <= 0) return this.m.Stats.DamageDealtArmor;
		return this.m.Stats.DamageDealtArmor / this.m.Stats.Battles;
	}

	function getDamageReceived()
	{
		return this.m.Stats.DamageReceivedHitpoints + this.m.Stats.DamageReceivedArmor;
	}

	function getDamageReceivedAvg()
	{
		if (this.m.Stats.Battles <= 0) return this.getDamageReceived();
		return this.getDamageReceived() / this.m.Stats.Battles;
	}

	function getDamageReceivedAvgHitpoints()
	{
		if (this.m.Stats.Battles <= 0) return this.m.Stats.DamageReceivedHitpoints;
		return this.m.Stats.DamageReceivedHitpoints / this.m.Stats.Battles;
	}

	function getDamageReceivedAvgArmor()
	{
		if (this.m.Stats.Battles <= 0) return this.m.Stats.DamageReceivedArmor;
		return this.m.Stats.DamageReceivedArmor / this.m.Stats.Battles;
	}

	function getMaxDamage()
	{
		return this.m.Stats.MaxDamageAttackArmor + this.m.Stats.MaxDamageAttackHitpoints;
	}

	// Linear ramp over first 15 battles so rookies do not dominate averages.
	function getSmoothedRating()
	{
		local battles = this.m.Stats.Battles;
		if (battles <= 0) return 0.0;
		local avg = this.getDamageDealt().tofloat() / battles;
		local weight = battles.tofloat() / 15.0;
		if (weight > 1.0) weight = 1.0;
		return avg * weight;
	}

	function getSmoothedDodge()
	{
		local d = this.m.Stats.NumAccuracyDodges;
		local a = d + this.m.Stats.NumAccuracyHitsReceived;
		if ("CareerStats" in ::getroottable() && "smoothedRate" in ::CareerStats)
			return ::CareerStats.smoothedRate(d, a);
		return a > 0 ? d.tofloat() / a : 0.0;
	}

	function getAvgHitChance()
	{
		local total = this.m.Stats.NumAccuracyHits + this.m.Stats.NumAccuracyMisses;
		if (total == 0) return 0.0;
		return this.m.Stats.NumAccuracyHits.tofloat() / total;
	}

	function getAvgHeadshotChance()
	{
		if (this.m.Stats.NumHits == 0) return 0.0;
		return this.m.Stats.NumHeadHits.tofloat() / this.m.Stats.NumHits;
	}

	function getAvgDodgeChance()
	{
		local total = this.m.Stats.NumAccuracyDodges + this.m.Stats.NumAccuracyHitsReceived;
		if (total == 0) return 0.0;
		return this.m.Stats.NumAccuracyDodges.tofloat() / total;
	}

	function getKillsPerBattle()
	{
		if (this.m.Stats.Battles <= 0) return 0.0;
		return this.m.Stats.Kills.tofloat() / this.m.Stats.Battles;
	}

	function makeTooltipSegment( _icon, _rank, _text )
	{
		local rank = _rank == 0 ? "" : "战团排名第" + _rank + "名";
		return {
			id = this.m.IDCounter++,
			type = "hint",
			text = rank + _text,
			icon = _rank == 0 ? _icon : "ui/icons/special.png"
		};
	}

	function extendTooltip( _tooltip, _idCounter )
	{
		this.m.IDCounter = _idCounter;
		local function red( text )  { return ::MSU.Text.colorRed(text + ""); }
		local function blue( text ) { return ::MSU.Text.color("#002869", text + ""); }

		local segments = [
			this.m.Stats.Battles > 0 && this.m.Ranks.DamageDealtAvg > 0
				? this.makeTooltipSegment("ui/icons/special.png", this.m.Ranks.DamageDealtAvg, "")
				: null,
			this.m.Stats.Battles > 0
				? this.makeTooltipSegment("mods/career_stats/damage_dealt_percent.png", 0,
					format("场均伤害 %s[img]gfx/mods/career_stats/health_mini.png[/img]%s[img]gfx/mods/career_stats/armor_body_mini.png[/img]",
						blue(::Math.round(this.getDamageDealtAvgHitpoints()).tostring()),
						blue(::Math.round(this.getDamageDealtAvgArmor()).tostring())))
				: null,
			this.m.Stats.Kills > 0
				? this.makeTooltipSegment("ui/icons/kills.png", 0,
					format("场均击杀 %s", blue(format("%.2f", this.getKillsPerBattle()))))
				: null,
			(this.m.Stats.NumAccuracyHits + this.m.Stats.NumAccuracyMisses) > 0
				? this.makeTooltipSegment("ui/icons/hitchance.png", 0,
					format("总命中率 %s%%", blue(::Math.round(this.getAvgHitChance() * 100).tostring())))
				: null,
			(this.m.Stats.NumAccuracyDodges + this.m.Stats.NumAccuracyHitsReceived) > 0
				? this.makeTooltipSegment("ui/icons/melee_defense.png", 0,
					format("总闪避率 %s%%", blue(::Math.round(this.getAvgDodgeChance() * 100).tostring())))
				: null,
			this.m.Stats.MaxKillsInBattle >= 5
				? this.makeTooltipSegment("ui/icons/round_information/enemies_icon.png", 0,
					format("单场战斗击杀 %s 名敌人", red(this.m.Stats.MaxKillsInBattle)))
				: null
		];

		foreach (seg in segments)
		{
			if (seg != null) _tooltip.push(seg);
		}

		local nineLivesText = this.getNineLivesText();
		if (nineLivesText != "")
			_tooltip.push(this.makeTooltipSegment("ui/perks/perk_07.png", 0, nineLivesText));

		local brotherText = this.getBrotherMentorsText();
		if (brotherText != "")
			_tooltip.push({ id = this.m.IDCounter++, type = "hint", icon = "ui/icons/special.png", text = brotherText });

		local veteranText = this.getVeteranMentorsText();
		if (veteranText != "")
			_tooltip.push({ id = this.m.IDCounter++, type = "hint", icon = "ui/icons/special.png", text = veteranText });
	}

	function getNineLivesText()
	{
		local uses = this.m.Stats.NineLivesUses;
		local saves = this.m.Stats.NineLivesSaves;
		if (uses == 0 && saves == 0) return "";
		if (uses > saves)
		{
			local text = "触发“九命”：" + ::MSU.Text.color("#002869", uses + "");
			if (saves == 0) text += "，每次都阵亡了";
			else text += "，幸存：" + ::MSU.Text.color("#002869", saves + "");
			return text;
		}
		return "被“九命”救下：" + ::MSU.Text.color("#002869", saves + "");
	}

	function getVeteranMentorsText()
	{
		if (this.m.VeteranMentors.len() == 0) return "";
		local text = "";
		foreach (i, mentor in this.m.VeteranMentors)
		{
			if (i > 0) text += "、";
			text += mentor;
		}
		return "受老兵指导：" + ::MSU.Text.color("#002869", text);
	}

	function getBrotherMentorsText()
	{
		if (this.m.BrotherMentors.len() == 0) return "";
		local text = "";
		foreach (i, mentor in this.m.BrotherMentors)
		{
			if (i > 0) text += "、";
			text += mentor;
		}
		return "受兄弟指导：" + ::MSU.Text.color("#002869", text);
	}

	function setPlayer( _p )
	{
		this.m.Player = ::WeakTableRef(_p);
	}

	function addMentor( _mentorName, _isVeteran = false )
	{
		local list = _isVeteran ? this.m.VeteranMentors : this.m.BrotherMentors;
		if (list.find(_mentorName) == null)
			list.push(_mentorName);
	}

	function clearRanks()
	{
		foreach (rank, _val in this.m.Ranks)
			this.m.Ranks[rank] = 0;
	}

	function onSerialize( _out )
	{
		::MSU.Utils.serialize(this.m.Stats, _out);
		_out.writeU32(this.m.VeteranMentors.len());
		foreach (mentor in this.m.VeteranMentors) _out.writeString(mentor);
		_out.writeU32(this.m.BrotherMentors.len());
		foreach (mentor in this.m.BrotherMentors) _out.writeString(mentor);
		_out.writeU16(this.m.LevelHistory.len());
		foreach (entry in this.m.LevelHistory)
		{
			_out.writeU16(entry.day);
			_out.writeU8(entry.level);
		}
	}

	function _emuRemaining( _in )
	{
		try { return _in.getData().len() - (_in.Idx + 1); }
		catch (e)
		{
			try { return _in.SerializationData.len() - (_in.Idx + 1); }
			catch (e2) { return 0; }
		}
	}

	function onDeserialize( _in )
	{
		if (_in == null || this._emuRemaining(_in) <= 0) return;

		try
		{
			::MSU.Utils.deserializeInto(this.m.Stats, _in);
		}
		catch (e) { return; }

		if (!("NineLivesUses" in this.m.Stats))    this.m.Stats.NineLivesUses <- 0;
		if (!("NineLivesSaves" in this.m.Stats))   this.m.Stats.NineLivesSaves <- 0;
		if (!("MaxKillsInBattle" in this.m.Stats)) this.m.Stats.MaxKillsInBattle <- 0;
		if (!("Kills" in this.m.Stats))            this.m.Stats.Kills <- 0;

		this.m.BrotherMentors = [];
		this.m.VeteranMentors = [];

		if (this._emuRemaining(_in) > 0)
		{
			try
			{
				local len = _in.readU32();
				for (local i = 0; i < len; i++)
					this.m.VeteranMentors.push(_in.readString());

				local bLen = _in.readU32();
				for (local i = 0; i < bLen; i++)
					this.m.BrotherMentors.push(_in.readString());
			}
			catch (e)
			{
				this.m.VeteranMentors = [];
				this.m.BrotherMentors = [];
			}
		}

		this.m.LevelHistory = [];
		if (this._emuRemaining(_in) > 0)
		{
			try
			{
				local histLen = _in.readU16();
				if (histLen > 0 && histLen < 500)
				{
					for (local i = 0; i < histLen; i++)
					{
						local day = _in.readU16();
						local level = _in.readU8();
						this.m.LevelHistory.push({ day = day, level = level });
					}
				}
			}
			catch (e)
			{
				this.m.LevelHistory = [];
			}
		}
	}
};
