// 1.6.1 亡灵天灾 5 层：腐毒蝇群（代替嗜血者）
// 在开战、每轮开始、自己回合开始时，给场上所有活体敌人挂上“腐毒蝇群”效果（没有相邻召唤亡灵时隐藏、不生效）
this.perk_bgp_necro_fly_swarm <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_necro_fly_swarm";
		this.m.Name = ::BGP.PerkNames.NecroFlySwarm;
		this.m.Description = ::BGP.PerkDescriptions.NecroFlySwarm;
		this.m.Icon = "ui/perks/perk_bgp_necro_fly_swarm.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function spread()
	{
		try
		{
			if (::BGP.isInBattle())
				::BGP.Necro.spreadFlySwarm(this.getContainer().getActor());
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 腐毒蝇群施加失败: " + e);
		}
	}

	function onCombatStarted()
	{
		this.spread();
	}

	function onNewRound()
	{
		this.spread();
	}

	function onTurnStart()
	{
		this.spread();
	}
});
