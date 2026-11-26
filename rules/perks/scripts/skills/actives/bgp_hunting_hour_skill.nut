// 狩猎时刻：每场战斗 1 次，驯兽师本人和场上所有友方野兽解除控制、恢复疲劳、进入狂热
this.bgp_hunting_hour_skill <- ::inherit("scripts/skills/skill", {
	m = {
		IsSpent = false,
		RemovedEffects = [
			"effects.stunned",
			"effects.net",
			"effects.web",
			"effects.kraken_ensnare",
			"effects.dazed",
			"effects.staggered",
			"effects.distracted"
		]
	},
	function create()
	{
		this.m.ID = "actives.bgp_hunting_hour";
		this.m.Name = ::BGP.PerkNames.HuntingHour;
		this.m.Description = "吹响终极猎号，唤起兽群与自身的狂猎斗志。";
		this.m.Icon = "skills/bgp_hunting_hour_skill.png";
		this.m.IconDisabled = "skills/bgp_hunting_hour_skill_sw.png";
		this.m.Overlay = "rf_command_skill";
		this.m.SoundOnUse = [
			"sounds/combat/rage_01.wav",
			"sounds/combat/rage_02.wav"
		];
		this.m.Type = ::Const.SkillType.Active;
		this.m.Order = ::Const.SkillOrder.UtilityTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = false;
		this.m.IsStacking = false;
		this.m.IsAttack = false;
		this.m.IsIgnoredAsAOO = true;
		this.m.ActionPointCost = 4;
		this.m.FatigueCost = 25;
		this.m.MinRange = 0;
		this.m.MaxRange = 0;
	}

	function getTooltip()
	{
		local ret = this.skill.getDefaultUtilityTooltip();
		ret.extend([
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "你和场上所有友方野兽解除眩晕、网缚、蛛网、晕眩、踉跄、分神" },
			{ id = 11, type = "text", icon = "ui/icons/fatigue.png", text = "恢复 " + ::MSU.Text.colorPositive("50%") + " 疲劳值上限" },
			{ id = 12, type = "text", icon = "ui/icons/initiative.png", text = "持续 2 回合：主动值 " + ::MSU.Text.colorPositive("+50") + "，士气锁定为自信" }
		]);
		if (this.m.IsSpent)
			ret.push({ id = 20, type = "text", icon = "ui/tooltips/warning.png", text = ::MSU.Text.colorNegative("本场战斗已经用过了") });
		return ret;
	}

	function isUsable()
	{
		return !this.m.IsSpent && this.skill.isUsable();
	}

	function onUse( _user, _targetTile )
	{
		this.m.IsSpent = true;

		local targets = [_user];
		targets.extend(::BGP.getFriendlyBeasts());

		foreach (a in targets)
		{
			try
			{
				foreach (s in a.getSkills().getAllSkillsOfType(::Const.SkillType.StatusEffect))
				{
					if (this.m.RemovedEffects.find(s.getID()) != null)
						s.removeSelf();
				}
				::BGP.reduceFatigue(a, ::Math.floor(a.getFatigueMax() * 0.5));
				a.getSkills().add(::new("scripts/skills/effects/bgp_hunting_hour_effect"));
				a.setDirty(true);
			}
			catch (e)
			{
				::logError("mod_bg_unique_perks: 狩猎时刻作用失败: " + e);
			}
		}

		::BGP.log(_user, "吹响了终极猎号！");
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
