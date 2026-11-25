// Tier 7 necromancy grandmaster perk (shared by Champion & Scourge routes).
// Unlocks undead taming & bind (Resolve-scaled), grants non-permanent friendly undead
// the Hunger passive, extends necromancy spell buff/debuff durations by +1 turn,
// and pulses +8 HP / +5 Melee & Ranged Skill within 4 tiles once per round on spell cast.
this.perk_bgp_necro_grandmaster <- ::inherit("scripts/skills/skill", {
	m = {
		LastPulseRound = -1
	},
	function create()
	{
		this.m.ID = "perk.bgp_necro_grandmaster";
		this.m.Name = ::BGP.PerkNames.NecroGrandmaster;
		this.m.Description = ::BGP.PerkDescriptions.NecroGrandmaster;
		this.m.Icon = "ui/perks/perk_bgp_necro_grandmaster.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onAdded()
	{
		if (::BGP.HasAC && !this.getContainer().hasSkill("actives.bgp_necro_bind"))
			this.getContainer().add(::new("scripts/skills/actives/bgp_necro_bind_skill"));
	}

	function onRemoved()
	{
		this.getContainer().removeByID("actives.bgp_necro_bind");
	}

	function onCombatStarted()
	{
		this.m.LastPulseRound = -1;
		::BGP.Necro.ensureHunger();
	}

	function onCombatFinished()
	{
		this.m.LastPulseRound = -1;
	}

	function onNewRound()
	{
		::BGP.Necro.ensureHunger();
	}

	function onAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		if (_skill == null || !(_skill.getID() in ::BGP.Necro.SpellIDs))
			return;
		local round = ::BGP.getRound();
		if (this.m.LastPulseRound == round)
			return;
		this.m.LastPulseRound = round;
		::BGP.Necro.triggerGrandmasterPulse(this.getContainer().getActor());
	}
});
