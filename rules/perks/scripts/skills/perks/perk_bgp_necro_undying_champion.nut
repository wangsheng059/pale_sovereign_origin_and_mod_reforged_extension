// 1.6.0 亡灵勇士 6 层：不灭勇士
//   战斗开始时饰品栏没有死灵宠物：在身旁召唤“墓穴王禁卫”；有死灵宠物：放出时晋升为永恒禁卫（全属性 +10%）。
//   被动自动复活：主人在场上存活时，倒下的永恒禁卫在下一回合自动复活（被敌人踩住时挤开敌人），
//   生命和头甲、身甲恢复到 15% + W/5 %（最多 50%）。逻辑在 necro_champion.nut。
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
		// Clean up legacy active skill on existing characters.
		this.getContainer().removeByID("actives.bgp_necro_eternal_command");
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_eternal_command");
	}

	function onCombatStarted()
	{
		this.getContainer().removeByID("actives.bgp_necro_eternal_command");
		try { ::BGP.Champion.clearPending(this.getContainer().getActor().getID()); } catch (e) {}
		this.m.IsSummonPending = true;
		this.trySummon();
	}

	function onTurnStart()
	{
		this.trySummon();
		try { ::BGP.Champion.tryAutoRevive(this.getContainer().getActor()); } catch (e) { ::logError("mod_bg_unique_perks: 永恒禁卫回合自动复活异常: " + e); }
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsSummonPending = false;
		try { ::BGP.Champion.clearPending(this.getContainer().getActor().getID()); } catch (e) {}
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
