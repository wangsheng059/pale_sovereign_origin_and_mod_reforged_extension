// 挂在每个战团成员身上：统帅组的全队 / 光环效果
//   化瑕为瑜（场上有人带该特技即生效）、深渊共鸣（4 格内有人带该特技）、千面归一（按统帅战斗开始时统计的兵器种类）、
//   中军印对相邻友军的减伤。都不满足时隐藏。
this.bgp_command_link_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Lines = [],
		Flaws = false,
		ResCmd = null,
		Count = 0,
		WaitRound = -1,
		KillApUsed = false,
		SwapSpent = false,
		PainDone = false,
		ShareUsed = false
	},
	function create()
	{
		this.m.ID = "effects.bgp_command_link";
		this.m.Name = "统帅号令";
		this.m.Icon = "ui/perks/perk_bgp_abyssal_resonance.png";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
		this.m.Lines = [];
	}

	function getDescription()
	{
		return "统帅知人善任，人人各得其所。";
	}

	function isHidden()
	{
		return this.m.Lines.len() == 0;
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		foreach (i, l in this.m.Lines)
			ret.push({ id = 10 + i, type = "text", icon = "ui/icons/special.png", text = l });
		return ret;
	}

	// ---------- 工具 ----------
	function hasAny( _ids )
	{
		local skills = this.getContainer();
		foreach (id in _ids)
		{
			if (skills.hasSkill(id))
				return true;
		}
		return false;
	}

	function getResonanceCommander()
	{
		local actor = this.getContainer().getActor();
		local best = null;
		local bestBravery = -1;
		foreach (c in ::BGP.getBrosWithSkill("perk.bgp_abyssal_resonance"))
		{
			if (::BGP.distance(c, actor) > 4)
				continue;
			local b = 0;
			try { b = c.getCurrentProperties().getBravery(); } catch (e) { b = 0; }
			if (b > bestBravery)
			{
				bestBravery = b;
				best = c;
			}
		}
		return best;
	}

	function getOneFleshCount()
	{
		local n = 0;
		foreach (c in ::BGP.getBrosWithSkill("perk.bgp_one_flesh"))
		{
			try { n = ::Math.max(n, c.getSkills().getSkillByID("perk.bgp_one_flesh").getCount()); } catch (e) {}
		}
		return n;
	}

	function isLowerThan( _cmd )
	{
		local actor = this.getContainer().getActor();
		local ct = ::BGP.getCultistTier(_cmd);
		if (ct >= 0)
			return ::BGP.getCultistTier(actor) < ct;
		try { return actor.getLevel() < _cmd.getLevel(); } catch (e) { return false; }
		return false;
	}

	// ---------- 属性 ----------
	function onUpdate( _properties )
	{
		this.m.Lines = [];
		local actor = this.getContainer().getActor();

		// 化瑕为瑜
		this.m.Flaws = false;
		try { this.m.Flaws = ::BGP.getBrosWithSkill("perk.bgp_flaws_to_fangs").len() > 0; } catch (e) { this.m.Flaws = false; }
		if (this.m.Flaws)
		{
			if (this.hasAny(::BGP.FlawsMental))
			{
				try
				{
					foreach (st in [::Const.MoraleState.Fleeing, ::Const.MoraleState.Breaking])
					{
						if (_properties.MV_ForbiddenMoraleStates.find(st) == null)
							_properties.MV_ForbiddenMoraleStates.push(st);
					}
				}
				catch (e)
				{
				}
				_properties.MoraleCheckBravery[::Const.MoraleCheckType.MentalAttack] += 20;
				this.m.Lines.push("愚昧即虔诚：士气不会降到崩溃或溃逃；精神攻击的决心检定 " + ::MSU.Text.colorPositive("+20") + "；近战攻击无视目标盾牌的近战防御");
			}

			local n = 0;
			try { n = ::Math.min(3, this.getContainer().getAllSkillsOfType(::Const.SkillType.PermanentInjury).len()); } catch (e) { n = 0; }
			if (n > 0)
			{
				_properties.Bravery += 4 * n;
				this.m.Lines.push("圣痕共鸣（" + n + " 处永久伤）：近战伤害 " + ::MSU.Text.colorPositive("+" + (8 * n) + "%") + "，决心 " + ::MSU.Text.colorPositive("+" + (4 * n)));
			}

			if (this.hasAny(::BGP.FlawsCoward))
			{
				if (this.m.WaitRound == ::BGP.getRound())
					this.m.Lines.push("困兽之斗：下一次攻击命中 " + ::MSU.Text.colorPositive("+15") + "，命中头部几率 " + ::MSU.Text.colorPositive("+15%"));
				else
					this.m.Lines.push("困兽之斗：本回合用过“等待”后，下一次攻击命中 +15、命中头部几率 +15%");
			}

			if (this.hasAny(::BGP.FlawsAsthma))
			{
				_properties.FatigueRecoveryRate += 3;
				this.m.Lines.push("调息：每回合疲劳恢复 " + ::MSU.Text.colorPositive("+3"));
			}

			if (this.hasAny(::BGP.FlawsSight))
				this.m.Lines.push("抵近射击：对 3 格内目标的远程伤害 " + ::MSU.Text.colorPositive("+20%"));

			if (this.hasAny(::BGP.FlawsGreed))
				this.m.Lines.push("重赏之下：每回合第一次击杀回复 " + ::MSU.Text.colorPositive("2") + " 行动点" + (this.m.KillApUsed ? "（本回合已用）" : ""));
		}

		// 深渊共鸣：天赋放大
		this.m.ResCmd = null;
		local c = null;
		try { c = this.getResonanceCommander(); } catch (e) { c = null; }
		if (c != null)
		{
			this.m.ResCmd = c;
			local top = ::BGP.getTopTalent(actor);
			if (top != null && top.Stars > 0)
			{
				local stars = ::Math.min(3, top.Stars);
				local info = ::BGP.AttrInfo[top.Attr];
				_properties[info.Mult] *= 1.0 + 0.03 * stars;
				this.m.Lines.push("深渊共鸣：" + info.Name + "（" + stars + " 星）" + ::MSU.Text.colorPositive("+" + (3 * stars) + "%"));
			}
		}

		// 千面归一
		this.m.Count = 0;
		try { this.m.Count = this.getOneFleshCount(); } catch (e) { this.m.Count = 0; }
		if (this.m.Count >= 3)
			this.m.Lines.push("千面归一（" + this.m.Count + " 种兵器）：每回合第一次换武器不消耗行动点" + (this.m.SwapSpent ? "（本回合已用）" : ""));
		if (this.m.Count >= 5)
			this.m.Lines.push("苦痛转嫁：低阶成员生命跌破 25% 或阵亡时，高阶成员获得狂热");
		if (this.m.Count >= 7)
			this.m.Lines.push("深渊同体：回合开始时疲劳超过 80% 的部分转给 4 格内疲劳最低的队友；每场一次，受到致命伤时由相邻生命过半的队友分担一半伤害" + (this.m.ShareUsed ? "（已用）" : ""));
	}

	// 深渊共鸣：决心、近战防御保底（放在 onAfterUpdate，按其他加成算完后的数值比较）
	function onAfterUpdate( _properties )
	{
		local c = this.m.ResCmd;
		this.m.ResCmd = null;
		if (c == null)
			return;
		local actor = this.getContainer().getActor();
		try
		{
			if (c.getID() == actor.getID())
				return;
			local cp = c.getCurrentProperties();
			local pct = this.isLowerThan(c) ? 0.7 : 0.6;

			local floorB = ::Math.floor(cp.getBravery() * pct);
			local curB = _properties.getBravery();
			if (curB < floorB)
			{
				_properties.Bravery += ::Math.ceil((floorB - curB) / (_properties.BraveryMult > 0.1 ? _properties.BraveryMult : 0.1));
				this.m.Lines.push("深渊共鸣：决心至少为统帅的 " + ::Math.round(pct * 100) + "%（" + floorB + "）");
			}

			local floorD = ::Math.floor(cp.getMeleeDefense() * 0.5);
			local curD = _properties.getMeleeDefense();
			if (curD < floorD)
			{
				_properties.MeleeDefense += ::Math.ceil((floorD - curD) / (_properties.MeleeDefenseMult > 0.1 ? _properties.MeleeDefenseMult : 0.1));
				this.m.Lines.push("深渊共鸣：近战防御至少为统帅的 50%（" + floorD + "）");
			}
		}
		catch (e)
		{
		}
	}

	// ---------- 攻击 ----------
	function onAnySkillUsed( _skill, _targetEntity, _properties )
	{
		if (_skill == null || !_skill.isAttack() || !this.m.Flaws)
			return;

		local ranged = _skill.isRanged();
		if (!ranged && _targetEntity != null && this.hasAny(::BGP.FlawsMental))
			_properties.MeleeSkill += ::BGP.getShieldCompensation(_targetEntity);

		if (!ranged)
		{
			local n = 0;
			try { n = ::Math.min(3, this.getContainer().getAllSkillsOfType(::Const.SkillType.PermanentInjury).len()); } catch (e) { n = 0; }
			if (n > 0)
				_properties.DamageTotalMult *= 1.0 + 0.08 * n;
		}

		if (this.m.WaitRound == ::BGP.getRound() && this.hasAny(::BGP.FlawsCoward))
		{
			_properties.MeleeSkill += 15;
			_properties.RangedSkill += 15;
			_properties.HitChance[::Const.BodyPart.Head] += 15;
		}

		if (ranged && _targetEntity != null && this.hasAny(::BGP.FlawsSight) && ::BGP.distance(this.getContainer().getActor(), _targetEntity) <= 3)
			_properties.DamageTotalMult *= 1.2;
	}

	function consumeWaitBonus( _skill )
	{
		if (this.m.WaitRound < 0 || _skill == null || !_skill.isAttack())
			return;
		if (!::BGP.isActiveEntity(this.getContainer().getActor()))
			return;
		this.m.WaitRound = -1;
	}

	function onTargetHit( _skill, _targetEntity, _bodyPart, _damageInflictedHitpoints, _damageInflictedArmor )
	{
		this.consumeWaitBonus(_skill);
	}

	function onTargetMissed( _skill, _targetEntity )
	{
		this.consumeWaitBonus(_skill);
	}

	function onWaitTurn()
	{
		if (this.m.Flaws && this.hasAny(::BGP.FlawsCoward))
			this.m.WaitRound = ::BGP.getRound();
	}

	function onTargetKilled( _targetEntity, _skill )
	{
		if (!this.m.Flaws || this.m.KillApUsed || !this.hasAny(::BGP.FlawsGreed))
			return;
		local actor = this.getContainer().getActor();
		if (!::BGP.isActiveEntity(actor))
			return;
		this.m.KillApUsed = true;
		::BGP.restoreAP(actor, 2);
		::BGP.log(actor, "重赏之下，回复 2 行动点");
	}

	// ---------- 回合 ----------
	function onTurnStart()
	{
		this.m.KillApUsed = false;
		this.m.SwapSpent = false;
		if (this.m.Count >= 7)
			this.shareFatigue();
	}

	function shareFatigue()
	{
		local actor = this.getContainer().getActor();
		try
		{
			local maxF = actor.getFatigueMax();
			local f = actor.getFatigue();
			local limit = ::Math.floor(maxF * 0.8);
			if (f <= limit)
				return;
			local best = null;
			local bestRatio = 2.0;
			foreach (a in ::BGP.getCompany())
			{
				if (a.getID() == actor.getID() || ::BGP.distance(a, actor) > 4)
					continue;
				local mx = a.getFatigueMax();
				if (mx <= 0 || a.getFatigue() >= mx)
					continue;
				local r = a.getFatigue() * 1.0 / mx;
				if (r < bestRatio)
				{
					bestRatio = r;
					best = a;
				}
			}
			if (best == null)
				return;
			local amount = ::Math.min(f - limit, best.getFatigueMax() - best.getFatigue());
			if (amount <= 0)
				return;
			actor.setFatigue(f - amount);
			best.setFatigue(best.getFatigue() + amount);
			actor.setDirty(true);
			best.setDirty(true);
			::BGP.log(actor, "把 " + amount + " 点疲劳转给了" + ::Const.UI.getColorizedEntityName(best));
		}
		catch (e)
		{
		}
	}

	// ---------- 换武器 ----------
	function getItemActionCost( _items )
	{
		if (this.m.Count >= 3 && !this.m.SwapSpent)
			return 0;
		return null;
	}

	function onPayForItemAction( _skill, _items )
	{
		try
		{
			if (_skill != null && _skill.getID() == this.getID())
			{
				this.m.SwapSpent = true;
				this.getContainer().getActor().setDirty(true);
			}
		}
		catch (e)
		{
		}
	}

	// ---------- 受伤 ----------
	function onBeforeDamageReceived( _attacker, _skill, _hitInfo, _properties )
	{
		// 中军印：相邻有持中军印的友军时，受到伤害 -20%
		if (this.getContainer().hasSkill("effects.bgp_seal_center"))
			return;
		local actor = this.getContainer().getActor();
		foreach (e in ::BGP.countAdjacent(actor).List)
		{
			try
			{
				if (e.isAlliedWith(actor) && e.getSkills().hasSkill("effects.bgp_seal_center"))
				{
					_properties.DamageReceivedTotalMult *= 0.8;
					return;
				}
			}
			catch (err)
			{
			}
		}
	}

	function onDamageReceived( _attacker, _damageHitpoints, _damageArmor )
	{
		if (this.m.Count < 5 || this.m.PainDone)
			return;
		local actor = this.getContainer().getActor();
		try
		{
			if (actor.getHitpoints() > 0 && actor.getHitpoints() < actor.getHitpointsMax() * 0.25)
				this.triggerPain();
		}
		catch (e)
		{
		}
	}

	// 致命伤确认（hooks.nut 的 MV_onBeforeDeathConfirmed 调用）
	function onLethal()
	{
		if (this.m.Count >= 5 && !this.m.PainDone)
			this.triggerPain();
	}

	// 苦痛转嫁：有 4–6 阶信徒在场时给他们（受伤者自己是 0–3 阶或非信徒）；否则给等级最高的 3 人（受伤者不在其中）
	function triggerPain()
	{
		this.m.PainDone = true;
		local actor = this.getContainer().getActor();
		local others = [];
		local high = [];
		foreach (a in ::BGP.getCompany())
		{
			if (a.getID() == actor.getID())
				continue;
			others.push(a);
			if (::BGP.getCultistTier(a) >= 4)
				high.push(a);
		}

		local recipients = [];
		if (high.len() > 0)
		{
			if (::BGP.getCultistTier(actor) >= 4)
				return;
			recipients = high;
		}
		else
		{
			local all = clone others;
			all.push(actor);
			all.sort(function( _a, _b ) { return _b.getLevel() <=> _a.getLevel(); });
			for (local i = 0; i < all.len() && i < 3; i++)
			{
				if (all[i].getID() == actor.getID())
					return;
				recipients.push(all[i]);
			}
		}

		foreach (r in recipients)
		{
			try
			{
				local fx = r.getSkills().getSkillByID("effects.bgp_frenzy");
				if (fx == null)
				{
					fx = ::new("scripts/skills/effects/bgp_frenzy_effect");
					r.getSkills().add(fx);
				}
				fx.addStack();
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 苦痛转嫁失败: " + e);
			}
		}
		if (recipients.len() > 0)
			::BGP.log(actor, "的苦痛点燃了同伴的狂热");
	}

	// 深渊同体：每场一次，由相邻生命过半的队友分担一半伤害，自己保留 1 生命（hooks.nut 调用）
	function tryShareDeath( _hitInfo )
	{
		if (this.m.Count < 7 || this.m.ShareUsed)
			return false;
		local actor = this.getContainer().getActor();
		local best = null;
		local bestRatio = 0.5;
		foreach (e in ::BGP.countAdjacent(actor).List)
		{
			try
			{
				if (e.getFaction() != ::Const.Faction.Player)
					continue;
				local r = e.getHitpoints() * 1.0 / e.getHitpointsMax();
				if (r > bestRatio)
				{
					bestRatio = r;
					best = e;
				}
			}
			catch (err)
			{
			}
		}
		if (best == null)
			return false;

		local dmg = 20;
		try { dmg = ::Math.max(1, _hitInfo.DamageInflictedHitpoints); } catch (e) { dmg = 20; }
		local share = ::Math.ceil(dmg * 0.5);
		this.m.ShareUsed = true;
		best.setHitpoints(::Math.max(1, best.getHitpoints() - share));
		best.setDirty(true);
		actor.setHitpoints(1);
		::BGP.log(actor, "濒死之际，" + ::Const.UI.getColorizedEntityName(best) + "替他承受了 " + share + " 点伤害");
		return true;
	}

	function onCombatFinished()
	{
		this.skill.onCombatFinished();
		this.m.ResCmd = null;
	}
});
