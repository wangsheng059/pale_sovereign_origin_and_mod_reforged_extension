// 尸爆：解锁“尸爆”主动技能
this.perk_bgp_corpse_explosion <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_corpse_explosion";
		this.m.Name = ::BGP.PerkNames.CorpseExplosion;
		this.m.Description = ::BGP.PerkDescriptions.CorpseExplosion;
		this.m.Icon = "ui/perks/perk_bgp_corpse_explosion.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_corpse_explosion"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_corpse_explosion_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_corpse_explosion");
	}
});
