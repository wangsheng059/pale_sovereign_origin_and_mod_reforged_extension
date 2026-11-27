// Curse of Ages status effect: -1 AP, -20 Initiative, -10 MAtk/RAtk, -25% Melee/Ranged damage, 3 turns (decremented on target turn end);
// each attack hit (including Corpse Explosion, deduplicated once per explosion) decays ONLY the hit body part's armor by -(10 + W/4).
this.bgp_curse_of_ages_effect <- ::inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 3,
		Decay = 10,
		IsPendingDecay = false,
		PendingDecaySlot = null,
		PendingBlastCastID = -1,
		LastBlastCastID = -1
	},
	function create()
	{
		this.m.ID = "effects.bgp_curse_of_ages";
		this.m.Name = "岁月诅咒";
		this.m.Description = "转眼老去几十年：手脚迟缓，刀剑无力，甲胄一碰就往下掉渣。";
		this.m.Icon = "skills/bgp_necro_curse_of_ages_skill.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		ret.extend([
			{ id = 9, type = "text", icon = "ui/icons/action_points.png", text = ::MSU.Text.colorNegative("-1") + " 行动点" },
			{ id = 10, type = "text", icon = "ui/icons/initiative.png", text = ::MSU.Text.colorNegative("-20") + " 主动值" },
			{ id = 11, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorNegative("-10") + " 近战技能、远程技能" },
			{ id = 12, type = "text", icon = "ui/icons/regular_damage.png", text = "近战 / 远程伤害 " + ::MSU.Text.colorNegative("-25%") },
			{ id = 13, type = "text", icon = "ui/icons/armor_body.png", text = "每受到一次攻击伤害（含尸爆），命中部位护甲耐久额外 " + ::MSU.Text.colorNegative("-" + this.m.Decay) },
			{ id = 14, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 回合" }
		]);
		return ret;
	}

	function refresh( _decay = null, _turns = 3 )
	{
		this.m.TurnsLeft = _turns;
		if (_decay != null)
			this.m.Decay = _decay;
	}

	function onUpdate( _properties )
	{
		_properties.ActionPoints -= 1;
		_properties.Initiative -= 20;
		_properties.MeleeSkill -= 10;
		_properties.RangedSkill -= 10;
		_properties.MeleeDamageMult *= 0.75;
		_properties.RangedDamageMult *= 0.75;
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		this.m.IsPendingDecay = false;
		this.m.PendingDecaySlot = null;
		this.m.PendingBlastCastID = -1;
		try
		{
			if (_skill != null && _skill.isAttack())
			{
				local blastCastID = -1;
				if (_skill.getID() == "actives.bgp_corpse_explosion")
				{
					try { blastCastID = _skill.m.BlastCastID; } catch (e2) { blastCastID = -1; }
					if (blastCastID >= 0 && blastCastID == this.m.LastBlastCastID)
						return;
				}
				this.m.IsPendingDecay = true;
				this.m.PendingBlastCastID = blastCastID;
				this.m.PendingDecaySlot = (_hitInfo != null && _hitInfo.BodyPart == ::Const.BodyPart.Head)
					? ::Const.ItemSlot.Head
					: ::Const.ItemSlot.Body;
			}
		}
		catch (e)
		{
			this.m.IsPendingDecay = false;
			this.m.PendingDecaySlot = null;
			this.m.PendingBlastCastID = -1;
		}
	}

	function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
	{
		if (!this.m.IsPendingDecay)
			return;
		local slot = this.m.PendingDecaySlot != null ? this.m.PendingDecaySlot : ::Const.ItemSlot.Body;
		local blastCastID = this.m.PendingBlastCastID;
		this.m.IsPendingDecay = false;
		this.m.PendingDecaySlot = null;
		this.m.PendingBlastCastID = -1;
		if (blastCastID >= 0)
			this.m.LastBlastCastID = blastCastID;

		local actor = this.getContainer().getActor();
		local total = 0;
		try
		{
			local piece = actor.getItems().getItemAtSlot(slot);
			if (piece != null && typeof piece != "integer")
			{
				local before = piece.getArmor();
				if (before > 0)
				{
					piece.setArmor(::Math.max(0, before - this.m.Decay));
					total = before - piece.getArmor();
				}
			}
		}
		catch (e)
		{
		}
		if (total > 0)
		{
			try { actor.getSkills().update(); } catch (e) {}
			try { actor.setDirty(true); } catch (e) {}
			::BGP.log(actor, "的护甲朽坏脱落了 " + total + " 点（岁月诅咒）");
		}
	}

	function onTurnEnd()
	{
		this.m.TurnsLeft -= 1;
		if (this.m.TurnsLeft <= 0)
			this.removeSelf();
	}
});
