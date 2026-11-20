// 冠军特质基类。具体种类见同目录 ac_ph_champion_*.nut，数据在 mod_ac_ph_compat/champions.nut。
// 宠物放出时，配件兄弟按特质列表逐个添加技能，本特质在 onAdded 里把冠军加成加到这次放出的实体上。
this.ac_ph_champion <- this.inherit("scripts/skills/skill", {
	m = {
		ChampionKey = "",
		IsApplied = false
	},
	function create()
	{
		this.m.ID = "quirk.ac_ph_champion";
		this.m.Name = "冠军";
		this.m.Description = "它曾是野兽中的冠军，被驯服后仍保留着冠军的力量。";
		this.m.Icon = "ui/traits/trait_icon_14.png";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.Order = this.Const.SkillOrder.VeryLast;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = true;
		this.m.IsSerialized = false;
	}

	function setChampion( _key )
	{
		this.m.ChampionKey = _key;
		this.m.ID = ::AC_PH_Compat.getChampionQuirkID(_key);

		if (_key in ::AC_PH_Compat.Champions)
			this.m.Name = "冠军" + ::AC_PH_Compat.Champions[_key].Label;
	}

	function getName()
	{
		return this.m.Name;
	}

	function getTooltip()
	{
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
			}
		];
	}

	function onAdded()
	{
		if (this.m.IsApplied)
			return;

		this.m.IsApplied = true;

		try
		{
			::AC_PH_Compat.applyChampion(this.getContainer().getActor(), this.m.ChampionKey);
		}
		catch (e)
		{
			::logError("mod_ac_ph_compat: 冠军加成 " + this.m.ChampionKey + " 应用失败: " + e);
		}
	}
});
