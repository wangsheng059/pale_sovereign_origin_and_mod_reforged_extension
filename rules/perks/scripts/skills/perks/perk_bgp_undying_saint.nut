// 不灭圣徒：决心转伤害减免；免死在 hooks.nut 的 MV_onBeforeDeathConfirmed 里调用 tryCheatDeath
this.perk_bgp_undying_saint <- ::inherit("scripts/skills/skill", {
	m = {
		BraveryToReduction = 0.0015,   // 每点决心减免 0.15%
		MaxReduction = 0.8,
		IsSpent = false
	},
	function create()
	{
		this.m.ID = "perk.bgp_undying_saint";
		this.m.Name = ::BGP.PerkNames.UndyingSaint;
		this.m.Description = ::BGP.PerkDescriptions.UndyingSaint;
		this.m.Icon = "ui/perks/perk_bgp_undying_saint.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function getReduction()
	{
		local bravery = 0;
		try { bravery = this.getContainer().getActor().getCurrentProperties().getBravery(); } catch (e) { bravery = 0; }
		return ::Math.minf(this.m.MaxReduction, ::Math.maxf(0.0, bravery * this.m.BraveryToReduction));
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		_properties.DamageReceivedTotalMult *= 1.0 - this.getReduction();
	}

	function tryCheatDeath()
	{
		if (this.m.IsSpent)
			return false;
		local actor = this.getContainer().getActor();
		this.m.IsSpent = true;
		actor.setHitpoints(1);
		actor.getSkills().add(::new("scripts/skills/effects/bgp_undying_frenzy_effect"));
		::BGP.log(actor, "誓言未竟，拒绝倒下！");
		return true;
	}

	function onCombatStarted()
	{
		this.m.IsSpent = false;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.IsSpent = false;
	}
});
