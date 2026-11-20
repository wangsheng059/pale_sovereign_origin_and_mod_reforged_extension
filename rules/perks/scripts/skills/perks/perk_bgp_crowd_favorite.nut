this.perk_bgp_crowd_favorite <- ::inherit("scripts/skills/skill", {
	m = {
		Stacks = 0,
		MaxStacks = 5,
		BraveryPerStack = 5,
		FatigueRecoveryPerStack = 1,
		LastHitTargetID = null
	},
	function create()
	{
		this.m.ID = "perk.bgp_crowd_favorite";
		this.m.Name = ::BGP.PerkNames.CrowdFavorite;
		this.m.Description = ::BGP.PerkDescriptions.CrowdFavorite;
		this.m.Icon = "ui/perks/perk_bgp_crowd_favorite.png";
		this.m.Type = ::Const.SkillType.Perk | ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
	}

	function isHidden()
	{
		return this.m.Stacks == 0;
	}

	function getName()
	{
		return this.m.Stacks > 1 ? "喝彩 (x" + this.m.Stacks + ")" : "喝彩";
	}

	function getDescription()
	{
		return "观众为你欢呼！";
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/bravery.png", text = "决心 " + ::MSU.Text.colorPositive("+" + (this.m.Stacks * this.m.BraveryPerStack)) },
			{ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = "每回合疲劳恢复 " + ::MSU.Text.colorPositive("+" + (this.m.Stacks * this.m.FatigueRecoveryPerStack)) }
		]);
		return ret;
	}

	function addStack()
	{
		if (this.m.Stacks >= this.m.MaxStacks)
			return;
		this.m.Stacks++;
		this.getContainer().getActor().setDirty(true);
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_skill == null || !_skill.isAttack() || _targetEntity == null)
			return;
		if (_targetEntity.isAlliedWith(this.getContainer().getActor()))
			return;
		if (!_targetEntity.isAlive() || _targetEntity.isDying())
			return;   // 击杀算在 onTargetKilled，一次攻击只给一层
		this.addStack();
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		if (_targetEntity == null || _targetEntity.isAlliedWith(this.getContainer().getActor()))
			return;
		this.addStack();
	}

	function onUpdate( _properties )
	{
		_properties.Bravery += this.m.Stacks * this.m.BraveryPerStack;
		_properties.FatigueRecoveryRate += this.m.Stacks * this.m.FatigueRecoveryPerStack;
	}

	function onCombatStarted()
	{
		this.m.Stacks = 0;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.Stacks = 0;
	}
});
