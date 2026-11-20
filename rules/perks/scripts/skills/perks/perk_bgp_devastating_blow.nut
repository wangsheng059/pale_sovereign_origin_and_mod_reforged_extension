// 毁灭一击：加两个主动技能（单体 / 扇形），两者共用这里记录的冷却
this.perk_bgp_devastating_blow <- ::inherit("scripts/skills/skill", {
	m = {
		LastUsedRound = -99,
		Cooldown = 2
	},
	function create()
	{
		this.m.ID = "perk.bgp_devastating_blow";
		this.m.Name = ::BGP.PerkNames.DevastatingBlow;
		this.m.Description = ::BGP.PerkDescriptions.DevastatingBlow;
		this.m.Icon = "ui/perks/perk_bgp_devastating_blow.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function isOnCooldown()
	{
		return ::BGP.getRound() <= this.m.LastUsedRound + this.m.Cooldown;
	}

	function getCooldownLeft()
	{
		return ::Math.max(0, this.m.LastUsedRound + this.m.Cooldown - ::BGP.getRound() + 1);
	}

	function setUsed()
	{
		this.m.LastUsedRound = ::BGP.getRound();
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_devastating_blow"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_devastating_blow_skill"));
		if (!this.getContainer().hasSkill("actives.bgp_devastating_sweep"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_devastating_sweep_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_devastating_blow");
		this.getContainer().removeByID("actives.bgp_devastating_sweep");
	}

	function onCombatStarted()
	{
		this.m.LastUsedRound = -99;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.LastUsedRound = -99;
	}
});
