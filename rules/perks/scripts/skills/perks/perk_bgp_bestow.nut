// 授印封将：解锁先锋印、中军印、奇兵印三个主动技能（第 1 回合可用，0 行动点）
this.perk_bgp_bestow <- ::inherit("scripts/skills/skill", {
	m = {
		Skills = [
			["actives.bgp_seal_vanguard", "scripts/skills/actives/bgp_seal_vanguard_skill"],
			["actives.bgp_seal_center", "scripts/skills/actives/bgp_seal_center_skill"],
			["actives.bgp_seal_shadow", "scripts/skills/actives/bgp_seal_shadow_skill"]
		]
	},
	function create()
	{
		this.m.ID = "perk.bgp_bestow";
		this.m.Name = ::BGP.PerkNames.Bestow;
		this.m.Description = ::BGP.PerkDescriptions.Bestow;
		this.m.Icon = "ui/perks/perk_bgp_bestow.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		foreach (s in this.m.Skills)
		{
			if (!this.getContainer().hasSkill(s[0]))
				this.getContainer().add(::new(s[1]));
		}
	}

	function onRemoved()
	{
		foreach (s in this.m.Skills)
			this.getContainer().removeByID(s[0]);
	}
});
