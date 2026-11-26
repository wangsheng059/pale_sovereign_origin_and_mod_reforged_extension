// Hunger passive granted to non-permanent friendly undead (undead pets & raised/summoned undead)
// when any ally has Tier 7 perk.bgp_necro_grandmaster.
// Heals 10% max HP at turn start if adjacent (distance 1) to an enemy, plus 10% max HP on attack hit.
this.bgp_necro_hunger_effect <- ::inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "effects.bgp_necro_hunger";
		this.m.Name = "饥渴";
		this.m.Description = "它不知饱足，只要贴近活物便本能地撕咬进食，借鲜血修补残躯。";
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
		ret.push({ id = 10, type = "text", icon = "ui/icons/health.png", text = "与敌人贴身（距离 1 格）时，每回合开始恢复最大生命的 " + ::MSU.Text.colorPositive("10%") });
		ret.push({ id = 11, type = "text", icon = "ui/icons/health.png", text = "攻击命中敌人时，额外恢复最大生命的 " + ::MSU.Text.colorPositive("10%") });
		return ret;
	}

	function hasAdjacentEnemy( _actor )
	{
		try
		{
			if (!_actor.isPlacedOnMap())
				return false;
			local tile = _actor.getTile();
			for (local d = 0; d < 6; ++d)
			{
				if (!tile.hasNextTile(d))
					continue;
				local next = tile.getNextTile(d);
				if (!next.IsOccupiedByActor)
					continue;
				local other = next.getEntity();
				if (other != null && other.isAlive() && !other.isDying() && !other.isAlliedWith(_actor))
					return true;
			}
		}
		catch (e)
		{
		}
		return false;
	}

	function healTenPct( _actor, _reason )
	{
		local maxHP = _actor.getHitpointsMax();
		local missing = maxHP - _actor.getHitpoints();
		if (missing <= 0 || maxHP <= 0)
			return;
		local amt = ::Math.max(1, ::Math.floor(maxHP * 0.10));
		local heal = ::Math.min(missing, amt);
		if (heal > 0)
		{
			::BGP.heal(_actor, heal);
			::BGP.log(_actor, _reason + "，因饥渴回复了 " + heal + " 点生命");
		}
	}

	function onTurnStart()
	{
		local c = this.getContainer();
		if (c == null || ::MSU.isNull(c))
			return;
		local actor = c.getActor();
		if (!::BGP.isValid(actor))
			return;
		if (this.hasAdjacentEnemy(actor))
			this.healTenPct(actor, "贴身接敌");
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		local c = this.getContainer();
		if (c == null || ::MSU.isNull(c))
			return;
		local actor = c.getActor();
		if (!::BGP.isValid(actor))
			return;
		if (_skill == null || !_skill.isAttack())
			return;
		if (_targetEntity == null || ::MSU.isNull(_targetEntity))
			return;
		local allied = false;
		try { allied = _targetEntity.isAlliedWith(actor); } catch (e) { allied = false; }
		if (allied)
			return;
		this.healTenPct(actor, "命中敌人");
	}
});
