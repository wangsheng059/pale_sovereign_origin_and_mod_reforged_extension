// 死灵法师：本 mod 新背景（1.4.0），只能靠捕奴 mod 俘获敌方死灵法师获得（不进城镇招募池）。
// 属性、排除特性、外观参考 mod_necro 0.4.0；自带“复活死者”（数值照 Nectomancy），盟友死亡不触发士气检查。
// 特技树：1.6.0 起两个专属组“亡灵冠军”“亡灵天灾”都在树里（两组独有特技互斥，死灵精通共用），必出匕首组；其余倾向沿用 mod_necro 给重铸写的倍率。
// 1.6.0 起“死灵法术”并入背景：能复活野兽、亡灵、兽人、地精。旧角色的特技树随存档保存，仍是 1.4.0–1.5.x 的“死灵法师”组。
// 复活的单位击杀敌人时，经验（击杀者那一份）和击杀数算给死灵法师。
this.bgp_necromancer_background <- this.inherit("scripts/skills/backgrounds/character_background", {
	m = {},
	function create()
	{
		this.character_background.create();
		this.m.ID = "background.bgp_necromancer";
		this.m.Name = "亡灵法师";
		this.m.Icon = "ui/backgrounds/background_39.png";
		this.m.BackgroundDescription = "亡灵法师擅长唤起死者为己所用，他们对生死的看法与常人截然不同。";
		this.m.GoodEnding = "%name% 离开战团后消失在北方的沼泽里。有人说他找到了一处古代墓穴，从此再也没人见过他——至少，没人见过活着的他。";
		this.m.BadEnding = "%name% 最终被猎巫人围在一座废弃的教堂里。据说那天晚上，墓地里的死人比来时的猎巫人还多。";
		this.m.HiringCost = 1500;
		this.m.DailyCost = 25;
		this.m.ExcludedTalents = [
			::Const.Attributes.Initiative,
			::Const.Attributes.RangedSkill
		];
		this.m.Excluded = [
			"trait.impatient",
			"trait.iron_jaw",
			"trait.clubfooted",
			"trait.dumb",
			"trait.insecure",
			"trait.loyal",
			"trait.fainthearted",
			"trait.brute",
			"trait.superstitious"
		];
		this.m.Titles = [
			"亡灵法师",
			"黑巫师",
			"掘墓者",
			"亡者之主"
		];
		this.m.Faces = ::Const.Faces.SmartMale;
		this.m.Hairs = ::Const.Hair.Necromancer;
		this.m.HairColors = ::Const.HairColors.Old;
		this.m.Beards = ::Const.Beards.All;
		this.m.Bodies = ::Const.Bodies.Skinny;
	}

	function getTooltip()
	{
		local ret = this.character_background.getTooltip();
		ret.push({ id = 10, type = "text", icon = "ui/icons/morale.png", text = "盟友死亡时不会触发士气检查" });
		ret.push({ id = 11, type = "text", icon = "ui/icons/special.png", text = "自带“复活死者”，能复活人类，以及野兽、亡灵、兽人、地精的尸体；复活的单位击杀敌人时，经验和击杀数算给他" });
		ret.push({ id = 12, type = "text", icon = "ui/icons/special.png", text = "亡灵天灾的不死再生、钢铁之躯、腐毒蝇群，以及亡灵冠军的心灵交融，对他放出的死灵宠物同样生效" });
		return ret;
	}

	function onBuildDescription()
	{
		return "{%name% 裹着一件颜色古怪的长袍，看上去更像是黑暗的使者，而不是一个有血有肉的人。 | %name% 总是佝偻着背，仿佛被某种不属于这个世界的知识压弯了腰。 | %name% 的脸藏在兜帽的阴影里，只露出一弯黄牙。 | 关于 %name% 的事没人说得清，只知道巫术和黑暗法术的传闻一直跟着他。} {他从哪里来，没人知道。 | 有人说他曾深入北方的山麓，带回了不可言说的知识。 | 据说他在被俘之前，曾在战场上唤起过成片的死者。} {你问了 %name% 很多问题，可等他比划完，你发现自己已经忘了他的回答。 | %name% 从袖子里放出一只白鸽，它在空中转了个身，飞回来时变成了一只乌鸦。 | %name% 预报天气准得出奇。 | %name% 想看看你的手相，你拒绝了。}";
	}

	function onChangeAttributes()
	{
		return {
			Hitpoints = [0, 0],
			Bravery = [10, 20],
			Stamina = [-5, 10],
			MeleeSkill = [0, 0],
			RangedSkill = [0, 0],
			MeleeDefense = [0, 3],
			RangedDefense = [-3, 3],
			Initiative = [-10, 0]
		};
	}

	function onAdded()
	{
		this.character_background.onAdded();
		try
		{
			if (!this.getContainer().hasSkill("actives.bgp_necro_raise"))
				this.getContainer().add(::new("scripts/skills/actives/bgp_necro_raise_skill"));
		}
		catch (e)
		{
			::logError("mod_bg_unique_perks: 添加复活死者失败: " + e);
		}
	}

	function onUpdate( _properties )
	{
		this.character_background.onUpdate(_properties);
		_properties.IsAffectedByDyingAllies = false;
	}

	function onOtherActorDeath( _killer, _victim, _skill, _deathTile, _corpseTile, _fatalityType )
	{
		::BGP.Necro.onMinionKill(this.getContainer().getActor(), _killer, _victim);
	}

	function createPerkTreeBlueprint()
	{
		return ::new(::DynamicPerks.Class.PerkTree).init({
			DynamicMap = {
				"pgc.rf_exclusive_1": ["pg.bgp_necro_champion", "pg.bgp_necro_scourge"],
				"pgc.rf_shared_1": [],
				"pgc.rf_weapon": ["pg.rf_dagger"],
				"pgc.rf_armor": [],
				"pgc.rf_fighting_style": []
			}
		});
	}

	function getPerkGroupMultiplier( _groupID, _perkTree )
	{
		switch (_groupID)
		{
			case "pg.rf_polearm":
				return 2;
			case "pg.special.rf_student":
				return 2;
			case "pg.rf_cleaver":
			case "pg.rf_fast":
			case "pg.special.rf_leadership":
				return 1.5;
			case "pg.rf_crossbow":
				return 1.2;
			case "pg.rf_tough":
				return 0.5;
			case "pg.rf_hammer":
			case "pg.rf_spear":
				return 0.3;
			case "pg.rf_axe":
			case "pg.rf_heavy_armor":
				return 0;
		}
	}
});
