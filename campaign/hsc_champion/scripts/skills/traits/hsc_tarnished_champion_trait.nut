// Permanent trait: Tarnished Champion (granted only to captured champions recruited via HSC).
// Leaves vanilla/Reforged racial.champion untouched for enemy champions and Eightfold Trial rewards.
this.hsc_tarnished_champion_trait <- this.inherit("scripts/skills/traits/character_trait", {
	m = {},

	function create()
	{
		this.character_trait.create();
		this.m.ID = "trait.hsc_tarnished_champion";
		this.m.Name = "蒙尘冠军";
		this.m.Description = "曾经是最强的人里最坚强的人。如今枷锁磨平了他的傲骨，昔日的战意早已蒙尘，唯有那副千锤百炼的躯体，仍本能地记得如何杀敌。";
		this.m.Icon = "ui/traits/trait_icon_72.png";
		this.m.Excluded = [];
	},

	function isEN()
	{
		try
		{
			return ::HumanSlaveCapture != null && ::HumanSlaveCapture.isEnglish();
		}
		catch (e)
		{
		}
		return false;
	},

	function getName()
	{
		return this.isEN() ? "Tarnished Champion" : "蒙尘冠军";
	},

	function getDescription()
	{
		if (this.isEN())
		{
			return "Once the strongest among the strong. Shackles have worn down his pride and clouded the fighting spirit of old, yet that battle-hardened body still remembers by instinct how to kill.";
		}
		return "曾经是最强的人里最坚强的人。如今枷锁磨平了他的傲骨，昔日的战意早已蒙尘，唯有那副千锤百炼的躯体，仍本能地记得如何杀敌。";
	},

	function getTooltip()
	{
		local en = this.isEN();
		local pos = this.Const.UI.Color.PositiveValue;
		local neg = this.Const.UI.Color.NegativeValue;

		return [
			{
				id = 1,
				type = "title",
				text = this.getName()
			},
			{
				id = 2,
				type = "description",
				text = this.getDescription()
			},
			{
				id = 10,
				type = "text",
				icon = "ui/icons/health.png",
				text = en
					? ("[color=" + pos + "]+5%[/color] Hitpoints")
					: ("[color=" + pos + "]+5%[/color] 生命值上限")
			},
			{
				id = 11,
				type = "text",
				icon = "ui/icons/fatigue.png",
				text = en
					? ("[color=" + pos + "]+8%[/color] Max Fatigue")
					: ("[color=" + pos + "]+8%[/color] 最大疲劳值")
			},
			{
				id = 12,
				type = "text",
				icon = "ui/icons/melee_skill.png",
				text = en
					? ("[color=" + pos + "]+5%[/color] Melee Skill")
					: ("[color=" + pos + "]+5%[/color] 近战技能")
			},
			{
				id = 13,
				type = "text",
				icon = "ui/icons/ranged_skill.png",
				text = en
					? ("[color=" + pos + "]+5%[/color] Ranged Skill")
					: ("[color=" + pos + "]+5%[/color] 远程技能")
			},
			{
				id = 14,
				type = "text",
				icon = "ui/icons/melee_defense.png",
				text = en
					? ("[color=" + pos + "]+5%[/color] Melee Defense")
					: ("[color=" + pos + "]+5%[/color] 近战防御")
			},
			{
				id = 15,
				type = "text",
				icon = "ui/icons/ranged_defense.png",
				text = en
					? ("[color=" + pos + "]+10%[/color] Ranged Defense")
					: ("[color=" + pos + "]+10%[/color] 远程防御")
			},
			{
				id = 16,
				type = "text",
				icon = "ui/icons/fatigue.png",
				text = en
					? ("[color=" + pos + "]+3[/color] Fatigue Recovery per turn")
					: ("[color=" + pos + "]+3[/color] 每回合疲劳恢复")
			},
			{
				id = 17,
				type = "text",
				icon = "ui/icons/direct_damage.png",
				text = en
					? ("[color=" + pos + "]+5%[/color] Armor Penetration")
					: ("[color=" + pos + "]+5%[/color] 穿甲伤害比例")
			},
			{
				id = 18,
				type = "text",
				icon = "ui/icons/bravery.png",
				text = en
					? ("[color=" + neg + "]-50%[/color] Resolve")
					: ("[color=" + neg + "]-50%[/color] 决心")
			},
			{
				id = 19,
				type = "hint",
				icon = "ui/icons/warning.png",
				text = en
					? "Having two or more Champions in the company will lead to unexpected negative consequences."
					: "队伍冠军人数大于等于两人时，会有意想不到的负面结果。"
			}
		];
	},

	function onUpdate( _properties )
	{
		_properties.HitpointsMult *= 1.05;
		_properties.StaminaMult *= 1.08;
		_properties.MeleeSkillMult *= 1.05;
		_properties.RangedSkillMult *= 1.05;
		_properties.MeleeDefenseMult *= 1.05;
		_properties.RangedDefenseMult *= 1.10;
		_properties.FatigueRecoveryRate += 3;
		_properties.DamageDirectAdd += 0.05;
		_properties.BraveryMult *= 0.50;
	}
});
