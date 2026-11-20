// 狩猎狂热：触发检测在野兽身上的 effects.bgp_beast_link 里，叠层效果是 effects.bgp_hunting_fever
this.perk_bgp_hunting_fever <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_hunting_fever";
		this.m.Name = ::BGP.PerkNames.HuntingFever;
		this.m.Description = ::BGP.PerkDescriptions.HuntingFever;
		this.m.Icon = "ui/perks/perk_bgp_hunting_fever.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onCombatStarted()
	{
		::BGP.ensureBeastLinks();
	}

	function onNewRound()
	{
		::BGP.ensureBeastLinks();
	}

	function onTurnStart()
	{
		::BGP.ensureBeastLinks();
	}

	function onAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		::BGP.ensureBeastLinks();
	}
});
