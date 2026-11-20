// 千面归一：战斗开始时统计场上战团成员主手武器的不同类型数（空手算一类），整场战斗固定
// 3 种：每回合第一次换武器免费；5 种：苦痛转嫁；7 种：深渊同体（效果在 effects.bgp_command_link 里）
this.perk_bgp_one_flesh <- ::inherit("scripts/skills/skill", {
	m = {
		Count = 0,
		IsPending = false
	},
	function create()
	{
		this.m.ID = "perk.bgp_one_flesh";
		this.m.Name = ::BGP.PerkNames.OneFlesh;
		this.m.Description = ::BGP.PerkDescriptions.OneFlesh;
		this.m.Icon = "ui/perks/perk_bgp_one_flesh.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function getCount()
	{
		return this.m.Count;
	}

	function tally()
	{
		local actor = this.getContainer().getActor();
		if (!::BGP.isValid(actor))
			return false;
		this.m.Count = ::BGP.countWeaponTypes();
		::BGP.ensureCommandLinks();
		local tier = this.m.Count >= 7 ? "深渊同体" : this.m.Count >= 5 ? "苦痛转嫁" : this.m.Count >= 3 ? "换武器免费" : "未达门槛";
		::BGP.log(actor, "统计兵器：" + this.m.Count + " 种（" + tier + "）");
		foreach (a in ::BGP.getCompany())
		{
			try { a.setDirty(true); } catch (e) {}
		}
		return true;
	}

	function onCombatStarted()
	{
		this.m.Count = 0;
		this.m.IsPending = !this.tally();
	}

	function onNewRound()
	{
		if (this.m.IsPending)
			this.m.IsPending = !this.tally();
		::BGP.ensureCommandLinks();
	}

	function onTurnStart()
	{
		if (this.m.IsPending)
			this.m.IsPending = !this.tally();
		::BGP.ensureCommandLinks();
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.Count = 0;
		this.m.IsPending = false;
	}
});
