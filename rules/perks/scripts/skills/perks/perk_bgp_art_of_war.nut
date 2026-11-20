// 战争艺术：薪水 / 经验 / 扎营的全队效果在 hooks.nut 里（按名册里有没有人带此特技判断），这里只处理指挥技能的消耗
this.perk_bgp_art_of_war <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_art_of_war";
		this.m.Name = ::BGP.PerkNames.ArtOfWar;
		this.m.Description = ::BGP.PerkDescriptions.ArtOfWar;
		this.m.Icon = "ui/perks/perk_bgp_art_of_war.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAfterUpdate( _properties )
	{
		foreach (skill in this.getContainer().getAllSkillsOfType(::Const.SkillType.Active))
		{
			if (::BGP.CommandSkillIDs.find(skill.getID()) == null)
				continue;
			skill.m.ActionPointCost = ::Math.max(1, skill.m.ActionPointCost - 1);
			skill.m.FatigueCostMult *= 0.7;
		}
	}
});
