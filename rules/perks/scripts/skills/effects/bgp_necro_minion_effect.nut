// 死灵仆从：死灵法师复活的单位身上挂的效果
// 复活时按主人的特技决定：不死再生（每回合 +10 生命）、钢铁之躯（复活时护甲 +30%，有不死再生时每回合再 +7%）、
// 嗜血者（获得吸血）、心灵交融（复制主人的部分被动特技）
this.bgp_necro_minion_effect <- ::inherit("scripts/skills/skill", {
	m = {
		Master = null,
		MasterName = "",
		HasRegen = false,
		HasArmorRegen = false,
		HasBloodSucking = false,
		MeldedPerks = []
	},
	function create()
	{
		this.m.ID = "effects.bgp_necro_minion";
		this.m.Name = "死灵仆从";
		this.m.Description = "这具躯体被死灵法术唤起，听从死灵法师的意志战斗。";
		this.m.Icon = "ui/perks/perk_bgp_necro_arts.png";
		this.m.IconMini = "";
		this.m.Type = ::Const.SkillType.StatusEffect;
		this.m.Order = ::Const.SkillOrder.Last;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
		this.m.IsSerialized = false;
		this.m.MeldedPerks = [];
	}

	function getMaster()
	{
		if (this.m.Master == null || ::MSU.isNull(this.m.Master))
			return null;
		return this.m.Master.get();
	}

	function setMaster( _master )
	{
		this.m.Master = ::MSU.asWeakTableRef(_master);
		try { this.m.MasterName = _master.getName(); } catch (e) { this.m.MasterName = ""; }

		local s = _master.getSkills();
		local actor = this.getContainer().getActor();
		this.m.HasRegen = s.hasSkill("perk.bgp_necro_regeneration");
		this.m.HasArmorRegen = this.m.HasRegen && s.hasSkill("perk.bgp_necro_flesh_of_iron");

		if (s.hasSkill("perk.bgp_necro_flesh_of_iron"))
			::BGP.Necro.restoreArmorPct(actor, 0.3);

		if (s.hasSkill("perk.bgp_necro_blood_sucking") && !actor.getSkills().hasSkill("racial.vampire"))
		{
			try
			{
				local v = ::new("scripts/skills/racial/vampire_racial");
				v.m.IsRemovedAfterBattle = true;
				actor.getSkills().add(v);
				this.m.HasBloodSucking = true;
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 嗜血者添加失败: " + e);
			}
		}

		if (s.hasSkill("perk.bgp_necro_mind_meld"))
		{
			foreach (id in ::BGP.Necro.MindMeldPerks)
			{
				try
				{
					local perk = s.getSkillByID(id);
					if (perk == null || actor.getSkills().hasSkill(id))
						continue;
					actor.getSkills().add(::new(::IO.scriptFilenameByHash(perk.ClassNameHash)));
					this.m.MeldedPerks.push(perk.getName());
				}
				catch (e)
				{
				}
			}
		}
		try { actor.getSkills().update(); } catch (e) {}
	}

	function getTooltip()
	{
		local ret = this.skill.getTooltip();
		if (this.m.MasterName != "")
			ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "听命于" + this.m.MasterName });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "不会出血、中毒，不受伤势和夜晚影响，没有士气" });
		if (this.m.HasRegen)
			ret.push({ id = 12, type = "text", icon = "ui/icons/health.png", text = "每回合开始时回复 " + ::MSU.Text.colorPositive("10") + " 点生命" });
		if (this.m.HasArmorRegen)
			ret.push({ id = 13, type = "text", icon = "ui/icons/armor_body.png", text = "每回合开始时头甲、身甲各回复上限的 " + ::MSU.Text.colorPositive("7%") });
		if (this.m.HasBloodSucking)
			ret.push({ id = 14, type = "text", icon = "ui/icons/special.png", text = "嗜血者：攻击造成生命伤害时吸血" });
		if (this.m.MeldedPerks.len() > 0)
		{
			local names = "";
			foreach (i, n in this.m.MeldedPerks)
				names += (i == 0 ? "" : "、") + n;
			ret.push({ id = 15, type = "text", icon = "ui/icons/special.png", text = "心灵交融：" + names });
		}
		return ret;
	}

	// 1.6.1 腐毒蝇群：召唤亡灵移动或倒下后，周围敌人的减益要重算
	function refreshSwarm()
	{
		try
		{
			local m = this.getMaster();
			if (m != null && m.getSkills().hasSkill(::BGP.Necro.FlySwarmPerk))
				::BGP.Necro.refreshFlySwarm();
		}
		catch (e)
		{
		}
	}

	function onMovementFinished( _tile )
	{
		this.refreshSwarm();
	}

	function onDeath( _fatalityType )
	{
		this.refreshSwarm();
	}

	function onTurnStart()
	{
		local actor = this.getContainer().getActor();
		if (::MSU.isKindOf(actor, "bgp_undead_ghoul") || ::MSU.isKindOf(actor, "bgp_undead_ghoul_medium") || ::MSU.isKindOf(actor, "bgp_undead_ghoul_high"))
			::BGP.Necro.applyBoundArt(actor);
		if (this.m.HasRegen)
		{
			local missing = actor.getHitpointsMax() - actor.getHitpoints();
			local heal = ::Math.min(missing, 10);
			if (heal > 0)
			{
				::BGP.heal(actor, heal);
				::BGP.log(actor, "回复了 " + heal + " 点生命（不死再生）");
			}
		}
		if (this.m.HasArmorRegen)
			::BGP.Necro.restoreArmorPct(actor, 0.07);
	}
});
