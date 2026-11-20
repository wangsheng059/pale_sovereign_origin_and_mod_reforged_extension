// 1.6.0 岁月诅咒：主动值 -20，近战技能 / 远程技能 -10，近战 / 远程伤害 ×0.8，持续 3 回合（目标自己的回合结束时减 1）；
// 期间每受到一次攻击伤害（哪怕只伤到护甲），头甲和身甲当前耐久各额外 -20（流血、中毒等不是攻击，不触发）
this.bgp_curse_of_ages_effect <- ::inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 3,
		Decay = 20,
		IsPendingDecay = false
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
			{ id = 10, type = "text", icon = "ui/icons/initiative.png", text = ::MSU.Text.colorNegative("-20") + " 主动值" },
			{ id = 11, type = "text", icon = "ui/icons/melee_skill.png", text = ::MSU.Text.colorNegative("-10") + " 近战技能、远程技能" },
			{ id = 12, type = "text", icon = "ui/icons/regular_damage.png", text = "近战 / 远程伤害 " + ::MSU.Text.colorNegative("-20%") },
			{ id = 13, type = "text", icon = "ui/icons/armor_body.png", text = "每受到一次攻击伤害，头甲和身甲耐久各额外 " + ::MSU.Text.colorNegative("-" + this.m.Decay) },
			{ id = 14, type = "text", icon = "ui/icons/special.png", text = "还剩 " + this.m.TurnsLeft + " 回合" }
		]);
		return ret;
	}

	function refresh()
	{
		this.m.TurnsLeft = 3;
	}

	function onUpdate( _properties )
	{
		_properties.Initiative -= 20;
		_properties.MeleeSkill -= 10;
		_properties.RangedSkill -= 10;
		_properties.MeleeDamageMult *= 0.8;
		_properties.RangedDamageMult *= 0.8;
	}

	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		this.m.IsPendingDecay = false;
		try { this.m.IsPendingDecay = _skill != null && _skill.isAttack(); } catch (e) { this.m.IsPendingDecay = false; }
	}

	function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
	{
		if (!this.m.IsPendingDecay)
			return;
		this.m.IsPendingDecay = false;
		local actor = this.getContainer().getActor();
		local total = 0;
		foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
		{
			try
			{
				local piece = actor.getItems().getItemAtSlot(slot);
				if (piece == null || typeof piece == "integer")
					continue;
				local before = piece.getArmor();
				if (before <= 0)
					continue;
				piece.setArmor(::Math.max(0, before - this.m.Decay));
				total += before - piece.getArmor();
			}
			catch (e)
			{
			}
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
