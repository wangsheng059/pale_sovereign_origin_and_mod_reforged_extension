// Save-compatibility cleanup stub for removed mod_legacy_graves.
// Deserializes any pre-existing grave entity from older saves without stream
// misalignment and silently removes it from the world map on first update.
// Never spawns new graves, loads no brushes or UI assets.

this.legacy_grave_location <- this.inherit("scripts/entity/world/location", {
	m = {
		ShouldCleanup = false
	},

	function create()
	{
		this.location.create();
		this.m.TypeID = "location.legacy_grave";
		this.m.LocationType = ("Passive" in this.Const.World.LocationType)
			? this.Const.World.LocationType.Passive
			: this.Const.World.LocationType.Unique;
		this.m.IsAttackable = false;
		this.m.IsDestructible = false;
		this.m.IsShowingDefenders = false;
		this.m.IsShowingBanner = false;
		this.m.IsSpawningDefenders = false;
		this.m.IsDroppingLoot = false;
		this.m.VisibilityMult = 0.0;
		this.m.Resources = 0;
	}

	function onInit()
	{
		this.location.onInit();
		try { this.getLabel("name").Visible = false; } catch (e) {}
	}

	function onUpdate()
	{
		this.location.onUpdate();
		if (this.m.ShouldCleanup && this.isAlive())
		{
			this.m.ShouldCleanup = false;
			try { this.die(); } catch (e) {}
		}
	}

	function _skipSheet( _in, _version )
	{
		if (!_in.readBool()) return;
		_in.readString(); // Background
		_in.readString(); // Name
		_in.readString(); // Title
		local nb = _in.readU8();
		for (local i = 0; i < nb; i++) _in.readU16();
		local nt = _in.readU8();
		for (local i = 0; i < nt; i++) _in.readU8();
		_in.readU16(); // Level
		_in.readU32(); // XP
		_in.readU8();  // PerkPoints
		_in.readU8();  // PerkPointsSpent
		_in.readU8();  // LevelUps
		local np = _in.readU16();
		for (local i = 0; i < np; i++) _in.readString();
		local ntr = _in.readU16();
		for (local i = 0; i < ntr; i++) _in.readString();
		local ni = _in.readU8();
		for (local i = 0; i < ni; i++) _in.readString();
		local na = _in.readU8();
		for (local i = 0; i < na; i++)
		{
			_in.readString();
			_in.readString();
		}
		if (_version >= 10)
		{
			_in.readU8(); // Body
			_in.readU8(); // Ethnicity
			_in.readU8(); // Gender
			_in.readU8(); // VoiceSet
			_in.readU8(); // Surcoat
			local ns = _in.readU8();
			for (local i = 0; i < ns; i++)
			{
				_in.readString();
				_in.readF32();
			}
		}
		if (_version >= 11)
		{
			local npg = _in.readU16();
			for (local i = 0; i < npg; i++) _in.readString();
		}
	}

	function onSerialize( _out )
	{
		this.location.onSerialize(_out);
		_out.writeU8(11);
		_out.writeString("");
		_out.writeU8(0);
		_out.writeU8(255);
		_out.writeU32(0);
		_out.writeBool(false);
		_out.writeString("");
		_out.writeU16(0);
	}

	function onDeserialize( _in )
	{
		this.location.onDeserialize(_in);
		local version = _in.readU8();
		_in.readString(); // Brush
		if (version >= 2) _in.readU8();  // TitleIndex
		if (version >= 4) _in.readU8();  // EpitaphIndex
		if (version >= 6) _in.readU32(); // CreatedDay
		if (version >= 7) _in.readBool(); // IsMirrored
		if (version >= 8) _in.readString(); // Inscription

		local n = _in.readU16();
		for (local i = 0; i < n; i++)
		{
			_in.readString(); // Name
			_in.readU32();    // Time
			_in.readU32();    // TimeWithCompany
			_in.readU32();    // Kills
			_in.readU32();    // Battles
			_in.readString(); // KilledBy
			if (version >= 5) _in.readString(); // Killer
			if (version >= 3)
			{
				local na = _in.readU8();
				for (local j = 0; j < na; j++)
				{
					_in.readString();
					_in.readString();
				}
			}
			if (version >= 9)
				this._skipSheet(_in, version);
		}

		this.m.ShouldCleanup = true;
	}
});
