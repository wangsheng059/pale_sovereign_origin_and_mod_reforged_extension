// 心灵交融：复活的单位复制你的部分被动防御 / 属性特技；你自己每回合开始时回复 5 生命
this.perk_bgp_necro_mind_meld <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_mind_meld";
		this.m.Name = ::BGP.PerkNames.NecroMindMeld;
		this.m.Description = ::BGP.PerkDescriptions.NecroMindMeld;
		this.m.Icon = "ui/perks/perk_bgp_necro_mind_meld.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onTurnStart()
	{
		local actor = this.getContainer().getActor();
		local heal = ::Math.min(5, actor.getHitpointsMax() - actor.getHitpoints());
		if (heal > 0)
			::BGP.heal(actor, heal);
	}
});
