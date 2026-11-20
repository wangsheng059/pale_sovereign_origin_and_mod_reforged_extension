// 深渊共鸣：4 格光环（含自己），具体效果在每个战团成员的 effects.bgp_command_link 里
this.perk_bgp_abyssal_resonance <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.bgp_abyssal_resonance";
		this.m.Name = ::BGP.PerkNames.AbyssalResonance;
		this.m.Description = ::BGP.PerkDescriptions.AbyssalResonance;
		this.m.Icon = "ui/perks/perk_bgp_abyssal_resonance.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onCombatStarted()
	{
		::BGP.ensureCommandLinks();
	}

	function onNewRound()
	{
		::BGP.ensureCommandLinks();
	}

	function onTurnStart()
	{
		::BGP.ensureCommandLinks();
	}

	// 统帅移动后光环范围变了，让场上战团成员重新计算
	function onMovementFinished( _tile )
	{
		foreach (a in ::BGP.getCompany())
		{
			try { a.setDirty(true); } catch (e) {}
		}
	}
});
