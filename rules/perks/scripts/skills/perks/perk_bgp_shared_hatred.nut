// 同仇敌忾：你或你的宠物击杀敌人 → 你和你的宠物各叠 1 层（最多 3 层，每层伤害 +8%）；
// 宠物在你旁边时，你和宠物受到的伤害 -20%（宠物那一半在 effects.bgp_beast_link 里）
this.perk_bgp_shared_hatred <- ::inherit("scripts/skills/skill", {
	m = {
		DamageReceivedMult = 0.8
	},
	function create()
	{
		this.m.ID = "perk.bgp_shared_hatred";
		this.m.Name = ::BGP.PerkNames.SharedHatred;
		this.m.Description = ::BGP.PerkDescriptions.SharedHatred;
		this.m.Icon = "ui/perks/perk_bgp_shared_hatred.png";
		this.m.Type = ::Const.SkillType.Perk;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function onCombatStarted()
	{
		::BGP.ensureBeastLinks();
	}

	function onNewRound()
	{
		::BGP.ensureBeastLinks();
	}

	function onTurnStart()
	{
		::BGP.ensureBeastLinks();
	}

	function onAnySkillExecuted( _skill, _targetTile, _targetEntity, _forFree )
	{
		::BGP.ensureBeastLinks();
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		local actor = this.getContainer().getActor();
		if (_targetEntity == null || _targetEntity.isAlliedWith(actor))
			return;
		::BGP.triggerSharedHatred(actor);
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		if (::BGP.hasOwnPetAdjacent(this.getContainer().getActor()))
			_properties.DamageReceivedTotalMult *= this.m.DamageReceivedMult;
	}
});
