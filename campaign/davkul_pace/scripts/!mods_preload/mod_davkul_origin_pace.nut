// Davkul cultist & Pale Sovereign origin event pacing & configurable global event frequency multiplier.
::DavkulPace <- {
	ID = "mod_davkul_origin_pace",
	Version = "1.2.1",
	Name = "达库尔起源加速",
	Mod = null,
	MH = null,
	ConversionEvents = [
		"cultist_origin_vs_old_gods_event",
		"cultist_origin_vs_uneducated_event"
	],
	OtherEvents = [
		"cultist_origin_sacrifice_event",
		"cultist_origin_flock_event"
	],
	BaseMinDelay = null,
	BaseChancePerSecond = null
};

::DavkulPace.getValue <- function( _id, _default )
{
	try
	{
		if (::DavkulPace.Mod == null) return _default;
		return ::DavkulPace.Mod.ModSettings.getSetting(_id).getValue();
	}
	catch (e)
	{
		return _default;
	}
};

::DavkulPace.getOriginID <- function()
{
	try
	{
		if (!("World" in ::getroottable()) || ::World == null || !("Assets" in ::World) || ::World.Assets == null)
			return "";
		local origin = ::World.Assets.getOrigin();
		return origin != null ? origin.getID() : "";
	}
	catch (e) {}
	return "";
};

::DavkulPace.shouldApplyGlobalBoost <- function( _onlyScoped = null, _paleBoost = null )
{
	local onlyScoped = _onlyScoped != null ? _onlyScoped : ::DavkulPace.getValue("DavkulPace_GlobalOnlyCultists", true);
	if (!onlyScoped)
		return true;
	local oid = ::DavkulPace.getOriginID();
	if (oid == "scenario.cultists")
		return true;
	local paleBoost = _paleBoost != null ? _paleBoost : ::DavkulPace.getValue("DavkulPace_PaleGlobalBoost", true);
	if (paleBoost && oid == "scenario.pale_sovereign")
		return true;
	return false;
};

::DavkulPace.applyCooldown <- function( _event, _isConversion )
{
	if (!("DavkulPaceBaseCooldown" in _event.m))
		_event.m.DavkulPaceBaseCooldown <- _event.m.Cooldown;

	if (_isConversion)
	{
		try
		{
			_event.m.Cooldown = ::DavkulPace.getValue("DavkulPace_ConvertDays", 2) * ::World.getTime().SecondsPerDay;
			return;
		}
		catch (e) {}
	}
	_event.m.Cooldown = _event.m.DavkulPaceBaseCooldown * ::DavkulPace.getValue("DavkulPace_CooldownPct", 35) / 100.0;
};

::DavkulPace.hookEvent <- function( _path, _isConversion )
{
	local multID = _isConversion ? "DavkulPace_ConvertScoreMult" : "DavkulPace_ScoreMult";
	local multDefault = _isConversion ? 50 : 10;

	::DavkulPace.MH.hook(_path, function( q )
	{
		q.create = @(__original) function()
		{
			__original();
			::DavkulPace.applyCooldown(this, _isConversion);
		};

		q.onUpdateScore = @(__original) function()
		{
			::DavkulPace.applyCooldown(this, _isConversion);
			__original();
			if (this.m.Score > 0)
				this.m.Score = this.m.Score * ::DavkulPace.getValue(multID, multDefault);
		};
	});
};

::DavkulPace.applyGlobalFrequency <- function( _mult = null, _onlyScoped = null, _paleBoost = null )
{
	if (!("Events" in ::Const)) return;
	if (::DavkulPace.BaseMinDelay == null)
	{
		::DavkulPace.BaseMinDelay = ::Const.Events.GlobalMinDelay;
		::DavkulPace.BaseChancePerSecond = ::Const.Events.GlobalChancePerSecond;
	}
	local mult = _mult != null ? _mult : ::DavkulPace.getValue("DavkulPace_GlobalEventMult", 3);
	if (!::DavkulPace.shouldApplyGlobalBoost(_onlyScoped, _paleBoost))
		mult = 1;
	if (mult < 1) mult = 1;
	::Const.Events.GlobalMinDelay = ::DavkulPace.BaseMinDelay / mult.tofloat();
	::Const.Events.GlobalChancePerSecond = ::DavkulPace.BaseChancePerSecond * mult;
};

::DavkulPace.MH = ::Hooks.register(::DavkulPace.ID, ::DavkulPace.Version, ::DavkulPace.Name);
::DavkulPace.MH.require("mod_msu", "mod_davkul_rising");

::DavkulPace.MH.queue([">mod_msu", ">mod_davkul_rising", ">mod_pandoras_hobby", ">mod_reforged"], function()
{
	::DavkulPace.Mod = ::MSU.Class.Mod(::DavkulPace.ID, ::DavkulPace.Version, ::DavkulPace.Name);
	local page = ::DavkulPace.Mod.ModSettings.addPage("General", "常规");

	page.addRangeSetting("DavkulPace_ConvertDays", 2, 1, 30, 1,
		"改宗事件冷却（天）",
		"把队里够条件的兄弟转为教徒的改宗事件，两次之间至少间隔的天数。");
	page.addRangeSetting("DavkulPace_ConvertScoreMult", 50, 1, 100, 1,
		"改宗事件触发权重（倍）",
		"冷却结束后，改宗事件在随机事件中被选中的权重倍数。设得比下面献祭/投奔的权重高，改宗就会比其他事件更常出现。1 = 原版。");
	page.addRangeSetting("DavkulPace_CooldownPct", 35, 10, 100, 5,
		"献祭/投奔事件冷却（%）",
		"献祭事件和教徒投奔事件的冷却时间，按原版的百分比计算。100 = 原版，35 = 约原版三分之一的天数。");
	page.addRangeSetting("DavkulPace_ScoreMult", 10, 1, 50, 1,
		"献祭/投奔事件触发权重（倍）",
		"冷却结束后，献祭和投奔事件被选中的权重倍数。1 = 原版。");
	page.addBooleanSetting("DavkulPace_GlobalOnlyCultists", true,
		"全局事件加速仅对指定起源生效",
		"开启时，下方的「全局随机事件频率」倍率仅在达库尔教徒起源（以及勾选下项时的亡灵主宰起源）生效，其他常规起源保持 1 倍原版节奏；关闭后对所有起源生效。")
		.addBeforeChangeCallback(function( _newValue ) { ::DavkulPace.applyGlobalFrequency(null, _newValue, null); });
	page.addBooleanSetting("DavkulPace_PaleGlobalBoost", true,
		"亡灵主宰起源启用全局事件加速",
		"开启时（默认开启），游玩「亡灵主宰」起源同样享受下方的全局随机事件高频加成（默认 3 倍）；关闭后亡灵主宰恢复 1 倍原版事件间隔。")
		.addBeforeChangeCallback(function( _newValue ) { ::DavkulPace.applyGlobalFrequency(null, null, _newValue); });
	page.addRangeSetting("DavkulPace_GlobalEventMult", 3, 1, 10, 1,
		"全局随机事件频率（倍）",
		"随机事件的整体触发频率。原版平均约 5 天一次随机事件；3 倍约 1.5～2 天一次，10 倍约半天一次。1 = 原版。")
		.addBeforeChangeCallback(function( _newValue ) { ::DavkulPace.applyGlobalFrequency(_newValue, null, null); });

	::DavkulPace.applyGlobalFrequency();

	::DavkulPace.MH.hook("scripts/events/event_manager", function( q )
	{
		q.update = @(__original) function( ... )
		{
			::DavkulPace.applyGlobalFrequency();
			vargv.insert(0, this);
			return __original.acall(vargv);
		};
	});

	foreach (ev in ::DavkulPace.ConversionEvents)
		::DavkulPace.hookEvent("scripts/events/events/dlc4/" + ev, true);
	foreach (ev in ::DavkulPace.OtherEvents)
		::DavkulPace.hookEvent("scripts/events/events/dlc4/" + ev, false);
});
