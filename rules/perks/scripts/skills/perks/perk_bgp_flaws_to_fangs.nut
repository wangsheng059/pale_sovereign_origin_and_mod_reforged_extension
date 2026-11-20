// 化瑕为瑜：全队生效（统帅在场即可），具体效果在每个战团成员的 effects.bgp_command_link 里
this.perk_bgp_flaws_to_fangs <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_flaws_to_fangs";
		this.m.Name = ::BGP.PerkNames.FlawsToFangs;
		this.m.Description = ::BGP.PerkDescriptions.FlawsToFangs;
		this.m.Icon = "ui/perks/perk_bgp_flaws_to_fangs.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onCombatStarted()
	{
		::BGP.ensureCommandLinks();
	}

	function onNewRound()
	{
		::BGP.ensureCommandLinks();
	}

	function onTurnStart()
	{
		::BGP.ensureCommandLinks();
	}
});
