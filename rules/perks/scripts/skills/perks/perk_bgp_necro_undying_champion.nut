// 1.6.0 亡灵冠军 7 层：不灭冠军
//   战斗开始时饰品栏没有死灵宠物：在身旁召唤“墓穴王禁卫”；有死灵宠物：放出时晋升为永恒禁卫（全属性 +10%）。
//   解锁“不灭号令”：主人活着时让倒下的永恒禁卫原地以 50% 生命、50% 护甲复活。逻辑在 necro_champion.nut。
this.perk_bgp_necro_undying_champion <- ::inherit("scripts/skills/skill", {
	m = {
		IsSummonPending = false
	},
	function create()
	{
		this.m.ID = "perk.bgp_necro_undying_champion";
		this.m.Name = ::BGP.PerkNames.NecroUndyingChampion;
		this.m.Description = ::BGP.PerkDescriptions.NecroUndyingChampion;
		this.m.Icon = "ui/perks/perk_bgp_necro_undying_champion.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (!this.getContainer().hasSkill("actives.bgp_necro_eternal_command"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_eternal_command_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_eternal_command");
	}

	function onCombatStarted()
	{
		this.m.IsSummonPending = true;
		this.trySummon();
	}

	function onTurnStart()
	{
		this.trySummon();
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsSummonPending = false;
	}

	function trySummon()
	{
		if (!this.m.IsSummonPending)
			return;
		try
		{
			local actor = this.getContainer().getActor();
			if (!::BGP.isInBattle() || !actor.isAlive() || !actor.isPlacedOnMap())
				return;
			this.m.IsSummonPending = false;
			if (actor.getFaction() != ::Const.Faction.Player)
				return;
			if (::BGP.Champion.hasPetEquipped(actor))
				return;
			if (::BGP.Champion.findGuard(actor) != null)
				return;
			if (!::BGP.Champion.summon(actor))
				this.m.IsSummonPending = true;	// 身边没有空格，下回合开始时再试
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 召唤永恒禁卫失败: " + e);
		}
	}
});
