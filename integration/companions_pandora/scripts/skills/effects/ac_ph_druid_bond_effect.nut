// 德鲁伊召唤兽的成长说明（只显示，属性已直接加到基础属性上）。
// 11 级以上按配件兄弟“好孩子”特质的公式加伤害（召唤兽没有宠物物品，不能直接用那个特质）。
this.ac_ph_druid_bond_effect <- this.inherit("scripts/skills/skill", {
	m = {
		Level = 1,
		Gains = [0, 0, 0, 0, 0, 0, 0, 0],
		QuirkNames = []
	},
	function create()
	{
		this.m.ID = "effects.ac_ph_druid_bond";
		this.m.Name = "德鲁伊之契";
		this.m.Description = "这只野兽回应了德鲁伊的召唤，随召唤者一同成长。";
		this.m.Icon = "skills/status_effect_06.png";
		this.m.IconMini = "";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.Order = this.Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
		this.m.IsSerialized = false;
	}

	function setData( _level, _gains, _quirkNames )
	{
		this.m.Level = _level;
		this.m.Gains = clone _gains;
		this.m.QuirkNames = clone _quirkNames;
	}

	function getDamageBonus()
	{
		return ::Math.max(0, this.m.Level - 10);
	}

	function getTooltip()
	{
		local ret = [
			{ id = 1, type = "title", text = this.getName() },
			{ id = 2, type = "description", text = this.getDescription() },
			{ id = 10, type = "text", icon = "ui/icons/special.png", text = "随德鲁伊成长至 [color=" + this.Const.UI.Color.PositiveValue + "]" + this.m.Level + "[/color] 级" }
		];

		local labels = ["生命", "胆识", "体力", "主动性", "近战技能", "远程技能", "近战防御", "远程防御"];
		local icons = ["health", "bravery", "fatigue", "initiative", "melee_skill", "ranged_skill", "melee_defense", "ranged_defense"];
		foreach (i, gain in this.m.Gains)
		{
			if (gain == 0)
				continue;

			ret.push({ id = 11 + i, type = "text", icon = "ui/icons/" + icons[i] + ".png", text = "[color=" + this.Const.UI.Color.PositiveValue + "]+" + gain + "[/color] " + labels[i] });
		}

		local bonus = this.getDamageBonus();
		if (bonus > 0)
		{
			ret.push({ id = 20, type = "text", icon = "ui/icons/regular_damage.png", text = "伤害 [color=" + this.Const.UI.Color.PositiveValue + "]+" + ::Math.floor(0.5 * bonus) + "~" + bonus + "[/color]" });
		}

		if (this.m.QuirkNames.len() != 0)
		{
			local s = "";
			foreach (i, n in this.m.QuirkNames)
				s += (i == 0 ? "" : "、") + n;
			ret.push({ id = 21, type = "text", icon = "ui/icons/special.png", text = "获得特质：" + s });
		}

		return ret;
	}

	function onUpdate( _properties )
	{
		local bonus = this.getDamageBonus();
		if (bonus > 0)
		{
			_properties.DamageRegularMin += ::Math.floor(0.5 * bonus);
			_properties.DamageRegularMax += ::Math.floor(1.0 * bonus);
		}
	}
});
