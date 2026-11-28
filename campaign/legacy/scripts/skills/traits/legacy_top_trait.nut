// Dynamic Top-3 brother badge trait (Rank I / II / III -> +5 / +3 / +2 Resolve).
// Pure Simplified Chinese; removed unused perk_big*.png and 60ms JS polling loop.

this.legacy_top_trait <- ::inherit("scripts/skills/skill", {
	m = {
		LegacyTopRank = 1
	},

	RankIcons = [
		"ui/perks/perk_590.png",
		"ui/perks/perk_591.png",
		"ui/perks/perk_592.png"
	],

	RankResolve = [5, 3, 2],

	function _rank()
	{
		local r = this.m.LegacyTopRank;
		try
		{
			local a = this.getContainer().getActor();
			if (a != null && a.getFlags().has(::CareerStats.TOP_TRAIT_RANK_FLAG))
				r = a.getFlags().getAsInt(::CareerStats.TOP_TRAIT_RANK_FLAG);
		}
		catch (e) {}
		if (r < 1) r = 1;
		if (r > 3) r = 3;
		return r;
	}

	function _wearerName()
	{
		try
		{
			local a = this.getContainer().getActor();
			if (a != null) return a.getNameOnly();
		}
		catch (e) {}
		return null;
	}

	function setRank( _r )
	{
		if (_r < 1) _r = 1;
		if (_r > 3) _r = 3;
		this.m.LegacyTopRank = _r;
		this.m.Icon = this.RankIcons[_r - 1];
		this.m.Name = this.getName();
	}

	function create()
	{
		this.m.ID         = "trait.legacy_top";
		this.m.Type       = ::Const.SkillType.Trait;
		this.m.Order      = ::Const.SkillOrder.Trait;
		this.m.IsActive   = false;
		this.m.IsStacking = false;
		this.m.IsHidden   = false;
		this.setRank(1);
	}

	function isHidden()
	{
		return ("Legacy" in ::getroottable()) && !::Legacy.getSetting("Legacy_TopRankBadge", true);
	}

	function getName()
	{
		local r = this._rank();
		return r == 1 ? "全团公认第一"
			: r == 2 ? "战团第二把刀"
			: "私下排名第三";
	}

	function getIcon()
	{
		return this.RankIcons[this._rank() - 1];
	}

	function getDescription()
	{
		local r = this._rank();
		local self = this._wearerName();
		local top1 = null;
		try
		{
			if (r == 2 && ("topBroName" in ::CareerStats))
				top1 = ::CareerStats.topBroName(1);
		}
		catch (e) {}
		if (top1 != null && self != null && top1 == self) top1 = null;

		local intro = "这些臂章是兄弟们自己做的。你从没过问他们为什么需要这个。\n\n";
		local who = self != null ? self : "他";
		if (r == 1)
			return intro + "你的手下普遍认为，团里没人比得上" + who + "；大家私下嘀咕，要是有谁能把所有人从困境里拉出来，那一定是他。";
		if (r == 2)
		{
			local first = top1 != null ? top1 : "头号人物";
			return intro + "团里很少有人会觉得这是种屈辱。时不时有人把" + who + "和" + first + "相提并论；只要两人都不在场，这种争论就时常冒出来。";
		}
		return intro + "这是个光荣的位置——在" + who + "身后，还有足足十几个人连想都不敢想。";
	}

	function syncLook()
	{
		local r = this._rank();
		if (this.m.LegacyTopRank == r && this.m.Icon == this.RankIcons[r - 1]) return;
		this.m.LegacyTopRank = r;
		this.m.Icon = this.RankIcons[r - 1];
		this.m.Name = this.getName();
	}

	function onAdded()
	{
		this.syncLook();
	}

	function onUpdate( _properties )
	{
		this.syncLook();
		if (("Legacy" in ::getroottable()) && !::Legacy.getSetting("Legacy_TopRankBadge", true))
			return;
		_properties.Bravery += this.RankResolve[this._rank() - 1];
	}

	function getTooltip()
	{
		local res = this.RankResolve[this._rank() - 1];
		return [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 3, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/bravery.png", text = "[color=" + ::Const.UI.Color.PositiveValue + "]+" + res + "[/color] 决心" }
		];
	}
});
