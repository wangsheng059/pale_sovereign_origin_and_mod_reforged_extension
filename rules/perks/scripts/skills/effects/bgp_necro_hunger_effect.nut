// Hex-Eater (嗜咒) passive granted to non-permanent friendly undead (undead pets, Lich King,
// Eternal Guard, summoned zombies/skeletons, and raised undead) when any ally has Tier 7 perk.bgp_necro_grandmaster.
// Against targets afflicted by necromantic debuffs (Weaken, Curse of Ages, Corpse Explosion Stagger,
// Corpse Poison, or Prey): +10 percentage points armor penetration (DamageDirectAdd +0.10) and +6 fatigue on hit.
this.bgp_necro_hunger_effect <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "effects.bgp_necro_hunger";
		this.m.Name = "嗜咒";
		this.m.Description = "死灵诅咒在敌人身上撕开破绽，使这具亡灵的攻势更具穿透与耗竭之力。";
		this.m.Icon = "skills/bgp_necro_hunger.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.push({
			id = 10,
			type = "text",
			icon = "ui/icons/direct_damage.png",
			text = "攻击处于死灵减益（衰弱术、岁月诅咒、尸爆踉跄、尸毒、猎物）的敌人时，护甲穿透 " + ::MSU.Text.colorPositive("+10 个百分点")
		});
		ret.push({
			id = 11,
			type = "text",
			icon = "ui/icons/fatigue.png",
			text = "命中上述目标后，额外使其疲劳 " + ::MSU.Text.colorNegative("+6")
		});
		return ret;
	}

	function hasNecroDebuff( _actor, _target )
	{
		if (_actor == null || ::MSU.isNull(_actor) || _target == null || ::MSU.isNull(_target))
			return false;
		try
		{
			if (!_target.isAlive() || _target.isDying() || _target.isAlliedWith(_actor))
				return false;
			local skills = _target.getSkills();
			if (skills == null)
				return false;
			if (skills.hasSkill("effects.pale_weaken")
				|| skills.hasSkill("effects.bgp_curse_of_ages")
				|| skills.hasSkill("effects.pale_corpse_poison")
				|| skills.hasSkill("effects.bgp_undead_poison")
				|| skills.hasSkill("effects.pale_prey"))
				return true;
			local stagger = skills.getSkillByID("effects.staggered");
			if (stagger != null && ("BGP_FromCorpseExplosion" in stagger.m) && stagger.m.BGP_FromCorpseExplosion)
				return true;
		}
		catch (e)
		{
		}
		return false;
	}

	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill == null || !_skill.isAttack() || _targetEntity == null)
			return;
		local c = this.getContainer();
		if (c == null || ::MSU.isNull(c))
			return;
		local actor = c.getActor();
		if (!::BGP.isValid(actor))
			return;
		if (this.hasNecroDebuff(actor, _targetEntity))
			_properties.DamageDirectAdd += 0.10;
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		if (_skill == null || !_skill.isAttack() || _targetEntity == null)
			return;
		local c = this.getContainer();
		if (c == null || ::MSU.isNull(c))
			return;
		local actor = c.getActor();
		if (!::BGP.isValid(actor))
			return;
		if (!this.hasNecroDebuff(actor, _targetEntity))
			return;
		try
		{
			local cur = _targetEntity.getFatigue();
			local maxF = _targetEntity.getFatigueMax();
			local next = ::Math.min(maxF, cur + 6);
			if (next > cur)
				_targetEntity.setFatigue(next);
		}
		catch (e)
		{
		}
	}
});
