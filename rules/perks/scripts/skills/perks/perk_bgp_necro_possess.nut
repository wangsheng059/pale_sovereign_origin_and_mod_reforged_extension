// 支配亡灵：解锁“支配亡灵”主动技能
this.perk_bgp_necro_possess <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_possess";
		this.m.Name = ::BGP.PerkNames.NecroPossess;
		this.m.Description = ::BGP.PerkDescriptions.NecroPossess;
		this.m.Icon = "ui/perks/perk_bgp_necro_possess.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.possess_undead"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_possess_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.possess_undead");
	}
});
