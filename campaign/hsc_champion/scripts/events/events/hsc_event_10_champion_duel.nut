// Event 10: Duel of Champions / 双冠死斗
// Soft-caps living champion brothers in the company to 1. Whenever 2 or more living
// champions (Tarnished Champion or human racial.champion) share the roster, this severe
// negative event rapidly triggers and only one of the two colliding champions can remain.
this.hsc_event_10_champion_duel <- this.inherit("scripts/events/event", {
	m = {
		ChampA = null,
		ChampB = null,
		Others = [],
		PickedWinner = null,
		PickedLoser = null
	},

	function create()
	{
		this.m.ID = "event.hsc_champion_duel";
		this.m.Title = "双冠死斗";
		this.m.Cooldown = 3.0 * this.World.getTime().SecondsPerDay;

		// Screen A: Confrontation
		this.m.Screens.push({
			ID = "A",
			Text = "",
			Image = "",
			List = [],
			Characters = [],
			Options = [],

			function start( _event )
			{
				if (_event.m.ChampA == null || _event.m.ChampB == null)
				{
					_event.prepare();
				}

				local L = ::HumanSlaveCapture.L;
				local a = _event.m.ChampA;
				local b = _event.m.ChampB;

				if (a == null || b == null)
				{
					this.Text = L("[img]gfx/ui/events/event_06.png[/img]{营地里剑拔弩张了一阵，但最后没有闹出人命。}",
						"[img]gfx/ui/events/event_06.png[/img]{Tension flared across the camp for a moment, but died down before steel was drawn.}");
					this.Options.push({
						Text = L("继续前进。", "Move on."),
						function getResult( _event )
						{
							return 0;
						}
					});
					return;
				}

				try { this.Characters.push(a.getImagePath()); } catch (e) {}
				try { this.Characters.push(b.getImagePath()); } catch (e) {}

				local nameA = a.getName();
				local nameB = b.getName();

				this.Text = L(
					"[img]gfx/ui/events/event_06.png[/img]{从" + nameA + "和" + nameB + "坐到同一堆篝火旁的那天起，营地里的空气就没再松弛过。两个曾经凌驾于尸山血海之上的怪物，彼此都只用看猎物与死敌的眼神打量对方。\n\n今晚，火星终于落进了干草堆。没人看清是谁先伸手按住剑柄，只听见一阵刺耳的铁器出鞘声，营火旁的弟兄们像躲瘟疫一样齐刷刷退开了一大圈。没有人敢说一句劝架的话。\n\n" + nameA + "缓缓压低重心，嘴角扯出冷笑；" + nameB + "一言不发，只把刃尖稳稳指着对方的咽喉。一营不容二冠——今晚之后，他们两个里只能有一个站着留下。}",
					"[img]gfx/ui/events/event_06.png[/img]{Ever since " + nameA + " and " + nameB + " began sharing the same campfire, the air in camp has stayed taut as a bowstring. Two apex killers forged atop mountains of corpses can only size one another up as prey or mortal rivals.\n\nTonight the spark finally hits dry tinder. No one sees whose hand touches steel first — only the rasp of blades leaving scabbards as the rest of the company scrambles back in dead silence. Nobody dares utter a word.\n\n" + nameA + " sinks into a low stance with a cold grin; " + nameB + " says nothing, leveling his point straight at the other's throat. One camp cannot hold two champions — by dawn, only one of them will remain.}");

				this.Options.push({
					Text = L("清出空地，让他们决出胜负。", "Clear a ring and let steel decide."),
					function getResult( _event )
					{
						return "Duel";
					}
				});

				if (_event.m.Others.len() >= 1)
				{
					this.Options.push({
						Text = L("带人冲上去强行拉开他们！", "Rush in with the men and drag them apart!"),
						function getResult( _event )
						{
							return "Intervene";
						}
					});
				}

				if (_event.m.Others.len() >= 2)
				{
					if (!_event.isPlayerAvatar(b))
					{
						this.Options.push({
							Text = L("带人围杀 " + nameB + "，留下 " + nameA + "。", "Gang up on " + nameB + " so " + nameA + " stays."),
							function getResult( _event )
							{
								_event.m.PickedWinner = _event.m.ChampA;
								_event.m.PickedLoser = _event.m.ChampB;
								return "Ambush";
							}
						});
					}

					if (!_event.isPlayerAvatar(a))
					{
						this.Options.push({
							Text = L("带人围杀 " + nameA + "，留下 " + nameB + "。", "Gang up on " + nameA + " so " + nameB + " stays."),
							function getResult( _event )
							{
								_event.m.PickedWinner = _event.m.ChampB;
								_event.m.PickedLoser = _event.m.ChampA;
								return "Ambush";
							}
						});
					}
				}
			}
		});

		// Screen Duel: Fair duel to the death, stat-weighted + random outcome
		this.m.Screens.push({
			ID = "Duel",
			Text = "",
			Image = "",
			List = [],
			Characters = [],
			Options = [
				{
					Text = "收拾残局。",
					function getResult( _event )
					{
						return 0;
					}
				}
			],

			function start( _event )
			{
				local L = ::HumanSlaveCapture.L;
				this.Options[0].Text = L("收拾残局。", "Clean up the mess.");

				local a = _event.m.ChampA;
				local b = _event.m.ChampB;

				if (a == null || b == null) return;

				local res = _event.resolveDuelWinner(a, b);
				local winner = res.Winner;
				local loser = res.Loser;
				local wName = winner.getName();
				local lName = loser.getName();

				try { this.Characters.push(winner.getImagePath()); } catch (e) {}

				this.Text = L(
					"[img]gfx/ui/events/event_06.png[/img]{你抬手示意众人退后。火光映在两张毫无怜悯的脸上，下一瞬，铁与铁狠狠撞在一处，火星溅得满地都是。\n\n这不是演武，也不是切磋。每一击都冲着咽喉、肋骨与膝弯去，甲片碎裂的脆响和骨肉撕开的闷声交替炸开，快得让人几乎看不清招式。几轮换命般的死拼后，" + lName + "的格挡慢了半拍——" + wName + "硬生生挨了一记狠斩，反手将利刃顺着锁骨一路送进胸腔。\n\n" + lName + "呛出一口血沫，直挺挺栽倒在泥地里，抽搐两下便没了声息。" + wName + "踉跄着拔出染血的兵器，浑身是口子，甲胄残破不堪，像头喘着粗气的伤狼一样冷冷环视了一圈营地。整夜再没有人敢靠近火堆半步。}",
					"[img]gfx/ui/events/event_06.png[/img]{You wave the men back. Firelight catches two pitiless faces, and a heartbeat later steel slams into steel in a shower of sparks.\n\nThis is no sparring match. Every cut aims for throat, ribs, and hamstring; plates shear apart and flesh tears open in a blur of brutal exchanges. After several lethal passes, " + lName + "'s guard slips half a beat — " + wName + " eats a vicious blow and drives his blade straight down past the collarbone.\n\n" + lName + " coughs dark blood, pitches into the mud, twitches twice, and lies still. " + wName + " wrenches his weapon free, bleeding from deep gashes in ruined armor, glaring across the silent camp like a cornered wolf. Nobody dares step near the fire for the rest of the night.}");

				// Kill loser, transfer battered gear to stash, record in Obituary
				local cause = L("在与" + wName + "的营地死斗中丧命", "Killed in a camp duel by " + wName);
				_event.killChampionInEvent(loser, cause, true);

				this.List.push({
					id = 10,
					icon = "ui/icons/kills.png",
					text = L("[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " 在死斗中阵亡[/color]（残破装备已收回仓库）",
						"[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " died in the duel[/color] (battered gear returned to stash)")
				});

				// Winner survives badly battered
				local wTemp = ::HumanSlaveCapture.addTempInjuries(winner, ::Math.rand(2, 3));
				_event.hurtBroHpPct(winner, 20, 45);
				local wDmgArmor = _event.damageEquipment(winner, 40, 65);

				if (wTemp > 0)
				{
					this.List.push({
						id = 11,
						icon = "ui/icons/health.png",
						text = L(wName + " 在死斗中受重创，获得 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] 处临时伤",
							wName + " is badly mauled and suffers [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] temporary injuries")
					});
				}

				if (::Math.rand(1, 100) <= 35)
				{
					local perm = _event.addRandomPermanentInjury(winner);
					if (perm != null)
					{
						this.List.push({
							id = 12,
							icon = "ui/icons/health.png",
							text = L(wName + " 留下永久伤：[color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]",
								wName + " suffers a permanent injury: [color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]")
						});
					}
				}

				if (wDmgArmor > 0)
				{
					this.List.push({
						id = 13,
						icon = "ui/icons/armor_body.png",
						text = L(wName + " 的护甲在死斗中严重损毁", wName + "'s armor is badly damaged in the duel")
					});
				}

				::HumanSlaveCapture.changeCompanyMood(-10, L("目睹了营地里的血腥死斗", "witnessed a bloody duel in camp"));

				this.List.push({
					id = 14,
					icon = "ui/icons/morale.png",
					text = L("全队心情大幅下降", "Company mood drops sharply")
				});
			}
		});

		// Screen Intervene: Trying to break them up backfires catastrophically; still only one remains
		this.m.Screens.push({
			ID = "Intervene",
			Text = "",
			Image = "",
			List = [],
			Characters = [],
			Options = [
				{
					Text = "舔舐伤口。",
					function getResult( _event )
					{
						return 0;
					}
				}
			],

			function start( _event )
			{
				local L = ::HumanSlaveCapture.L;
				this.Options[0].Text = L("舔舐伤口。", "Tend the wounded.");

				local a = _event.m.ChampA;
				local b = _event.m.ChampB;

				if (a == null || b == null) return;

				local res = _event.resolveDuelWinner(a, b);
				local winner = res.Winner;
				local loser = res.Loser;
				local wName = winner.getName();
				local lName = loser.getName();

				try { this.Characters.push(winner.getImagePath()); } catch (e) {}

				// Innocent bystanders get butchered trying to separate two apex killers
				local bystanders = _event.pickRandomBystanders(3);
				local permVictim = _event.pickPermanentVictim(bystanders);

				foreach (bro in bystanders)
				{
					local added = ::HumanSlaveCapture.addTempInjuries(bro, ::Math.rand(2, 3));
					_event.hurtBroHpPct(bro, 30, 60);

					if (added > 0)
					{
						this.List.push({
							id = 20,
							icon = "ui/icons/health.png",
							text = L(bro.getName() + " 冲上去拉架被砍伤，获得 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + added + "[/color] 处临时伤",
								bro.getName() + " is slashed trying to intervene and suffers [color=" + this.Const.UI.Color.NegativeEventValue + "]" + added + "[/color] temporary injuries")
						});
					}
				}

				if (permVictim != null)
				{
					local perm = _event.addRandomPermanentInjury(permVictim);
					if (perm != null)
					{
						this.List.push({
							id = 21,
							icon = "ui/icons/health.png",
							text = L(permVictim.getName() + " 在混战中致残：[color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]",
								permVictim.getName() + " is maimed in the brawl: [color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]")
						});
					}
				}

				// 60% bloodbath kills loser in the melee; 40% loser breaks free and deserts with all his gear + steals crowns
				local bloodbath = (::Math.rand(1, 100) <= 60);

				if (bloodbath)
				{
					this.Text = L(
						"[img]gfx/ui/events/event_06.png[/img]{你吼着让弟兄们一拥而上，想把这两个疯子按倒在地。这是你犯过最蠢的错。\n\n杀红了眼的冠军根本不管扑上来的是谁，挥刃横扫如同镰刀割麦。冲在最前面的几名弟兄惨叫着翻滚倒地，血瞬间泼湿了帐篷帆布。就在人群大乱的一瞬，" + wName + "借着混乱抢步近身，一剑贯穿了" + lName + "的心口。\n\n等你们好不容易把浑身是血的" + wName + "按住，地上已经横七竖八躺满了哀嚎的伤员，而" + lName + "早已断气。你不仅没能留住两人，还白白搭上了弟兄们的血肉。}",
						"[img]gfx/ui/events/event_06.png[/img]{You bark at the men to pile on and wrestle the two madmen down. It is the worst mistake you could have made.\n\nBlinded by bloodlust, neither champion cares who grabs his arms — their blades sweep through the crowd like scythes through wheat. Men go down screaming as blood sprays across the tent canvas. In the middle of the panic, " + wName + " lunges through the tangle and drives steel straight through " + lName + "'s chest.\n\nBy the time you pin a drenched " + wName + " to the dirt, the ground is littered with groaning men and " + lName + " is already cold. You saved neither peace nor numbers — only bought extra cripples in blood.}");

					local cause = L("在营地混战中被" + wName + "刺死", "Slain by " + wName + " during a camp brawl");
					_event.killChampionInEvent(loser, cause, true);

					this.List.push({
						id = 10,
						icon = "ui/icons/kills.png",
						text = L("[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " 在混战中丧命[/color]（残破装备已收回仓库）",
							"[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " was killed in the chaos[/color] (battered gear returned to stash)")
					});
				}
				else
				{
					local money = ::HumanSlaveCapture.getMoney();
					local stolen = ::Math.min(money, ::Math.rand(300, 800));
					if (stolen > 0) ::HumanSlaveCapture.payMoney(stolen);

					this.Text = L(
						"[img]gfx/ui/events/event_06.png[/img]{你带人扑上去强行扯开他们，结果两个杀神压根不收手，刀锋和肘击砸在劝架的弟兄身上，眨眼间营地里哭嚎四起、血流一地。\n\n你们好不容易才用长矛和盾牌把两人隔开。" + lName + "吐出一口带血的唾沫，阴沉地扫了你和" + wName + "一眼，转身退进夜色。天亮清点时，他已经带着身上的全部装备消失无踪，连营地钱箱都被撬开顺走了一大把克朗。\n\n没人提议去追。所有人都知道，就算追上，也只会多几具尸体。}",
						"[img]gfx/ui/events/event_06.png[/img]{You rush in with the men to wrench them apart, and neither killer holds back. Steel and gauntlets smash into anyone who steps close until the camp is awash in screams and blood.\n\nOnly with spears and shields do you finally force them apart. " + lName + " spits blood at your feet, fixes you and " + wName + " with a venomous stare, and backs into the dark. By dawn he is gone — along with every piece of gear on his back and a hefty fistful of crowns pried from the company chest.\n\nNo one offers to give chase. Everyone knows catching him would only mean more graves.}");

					_event.desertChampionWithGear(loser);

					this.List.push({
						id = 10,
						icon = "ui/icons/warning.png",
						text = L("[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " 连夜携全套随身装备逃离战团[/color]",
							"[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " deserted in the night with all his equipped gear[/color]")
					});

					if (stolen > 0)
					{
						this.List.push({
							id = 11,
							icon = "ui/icons/asset_money.png",
							text = L("被顺走了 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + stolen + "[/color] 克朗",
								"Lost [color=" + this.Const.UI.Color.NegativeEventValue + "]" + stolen + "[/color] crowns")
						});
					}
				}

				local wTemp = ::HumanSlaveCapture.addTempInjuries(winner, ::Math.rand(2, 3));
				_event.hurtBroHpPct(winner, 35, 65);
				_event.damageEquipment(winner, 50, 75);

				if (wTemp > 0)
				{
					this.List.push({
						id = 22,
						icon = "ui/icons/health.png",
						text = L(wName + " 在冲突中获得 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] 处临时伤",
							wName + " suffers [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] temporary injuries")
					});
				}

				::HumanSlaveCapture.changeCompanyMood(-15, L("强行拉开两名冠军导致营地血肉横飞", "caught in a bloody brawl trying to separate two champions"));

				this.List.push({
					id = 25,
					icon = "ui/icons/morale.png",
					text = L("全队士气崩盘", "Company morale plummets")
				});
			}
		});

		// Screen Ambush: Order the company to gang up on one champion to choose who survives
		this.m.Screens.push({
			ID = "Ambush",
			Text = "",
			Image = "",
			List = [],
			Characters = [],
			Options = [
				{
					Text = "埋掉尸体。",
					function getResult( _event )
					{
						return 0;
					}
				}
			],

			function start( _event )
			{
				local L = ::HumanSlaveCapture.L;
				this.Options[0].Text = L("埋掉尸体。", "Bury the body.");

				local winner = _event.m.PickedWinner;
				local loser = _event.m.PickedLoser;

				if (winner == null || loser == null) return;

				local wName = winner.getName();
				local lName = loser.getName();

				try { this.Characters.push(winner.getImagePath()); } catch (e) {}

				this.Text = L(
					"[img]gfx/ui/events/event_06.png[/img]{你冷声下令，让弟兄们拔出武器围住" + lName + "，替" + wName + "把事情一劳永逸地了结。\n\n" + lName + "看了一眼合围上来的刀枪，没有求饶，只发出一声野兽般的低笑。哪怕背靠绝境，这具千锤百炼的躯体依然可怕得令人发指——他像困兽一样扑进人群，劈翻了冲在最前的几名弟兄，甚至反手在" + wName + "身上撕开数道血口，直到七八把武器同时扎进他的脊背才轰然倒地。\n\n营地死寂一片。人人手上的血都还是热的，没人敢看彼此的眼睛。连活下来的" + wName + "也只是厌恶地啐了一口，背过身去。所有人都明白，今天倒在刀下的不是敌人，而是睡在隔壁帐篷里的同伴。}",
					"[img]gfx/ui/events/event_06.png[/img]{You give the cold order: surround " + lName + " and end this for good in " + wName + "'s favor.\n\n" + lName + " glances at the closing ring of spears, asks for no quarter, and lets out a low animal laugh. Even cornered, that war-forged body is terrifying — he hurls himself into the press, hacking down the foremost men and carving deep gashes into " + wName + " himself before half a dozen blades finally pin him to the earth.\n\nA sick silence settles over the camp. Blood is still warm on everyone's hands, and no one meets anyone else's gaze. Even " + wName + " spits in disgust and turns away. Every man knows it was not an enemy they butchered tonight, but a comrade from the next tent over.}");

				local cause = L("在营地冲突中被战团众人围杀", "Cut down by the company during a camp confrontation");
				_event.killChampionInEvent(loser, cause, true);

				this.List.push({
					id = 10,
					icon = "ui/icons/kills.png",
					text = L("[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " 被众人围杀身亡[/color]（残破装备已收回仓库）",
						"[color=" + this.Const.UI.Color.NegativeEventValue + "]" + lName + " was cut down by the company[/color] (battered gear returned to stash)")
				});

				local bystanders = _event.pickRandomBystanders(3);
				local permVictim = _event.pickPermanentVictim(bystanders);

				foreach (bro in bystanders)
				{
					local added = ::HumanSlaveCapture.addTempInjuries(bro, ::Math.rand(2, 3));
					_event.hurtBroHpPct(bro, 25, 55);

					if (added > 0)
					{
						this.List.push({
							id = 20,
							icon = "ui/icons/health.png",
							text = L(bro.getName() + " 在围杀中遭反扑，获得 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + added + "[/color] 处临时伤",
								bro.getName() + " takes [color=" + this.Const.UI.Color.NegativeEventValue + "]" + added + "[/color] temporary injuries in the ambush")
						});
					}
				}

				if (permVictim != null)
				{
					local perm = _event.addRandomPermanentInjury(permVictim);
					if (perm != null)
					{
						this.List.push({
							id = 21,
							icon = "ui/icons/health.png",
							text = L(permVictim.getName() + " 被临死反扑致残：[color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]",
								permVictim.getName() + " is permanently maimed: [color=" + this.Const.UI.Color.NegativeEventValue + "]" + perm.getName() + "[/color]")
						});
					}
				}

				local wTemp = ::HumanSlaveCapture.addTempInjuries(winner, 2);
				_event.hurtBroHpPct(winner, 40, 70);
				_event.damageEquipment(winner, 50, 75);

				if (wTemp > 0)
				{
					this.List.push({
						id = 22,
						icon = "ui/icons/health.png",
						text = L(wName + " 被临死反扑砍伤，获得 [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] 处临时伤",
							wName + " suffers [color=" + this.Const.UI.Color.NegativeEventValue + "]" + wTemp + "[/color] temporary injuries")
					});
				}

				// Whole company suffers guilt (5 days) and severe morale crash
				foreach (bro in ::HumanSlaveCapture.getAliveBrothers())
				{
					if (::HumanSlaveCapture.isLivingUndead(bro)) continue;
					::HumanSlaveCapture.addGuilt(bro, 5);
				}

				::HumanSlaveCapture.changeCompanyMood(-15, L("奉命围杀了自己的同伴", "ordered to gang up on and kill a comrade"));

				this.List.push({
					id = 24,
					icon = "ui/traits/trait_icon_87.png",
					text = L("全队活人成员获得「内疚」状态（持续 5 天，决心 -10）", "All living brothers suffer Guilt (5 days, -10 Resolve)")
				});

				this.List.push({
					id = 25,
					icon = "ui/icons/morale.png",
					text = L("全队士气严重崩盘", "Company morale collapses")
				});
			}
		});
	},

	function isBroInRoster( _bro )
	{
		if (_bro == null) return false;
		try
		{
			if ("MSU" in ::getroottable() && ::MSU.isNull(_bro)) return false;
			return ::World.getPlayerRoster().getAll().find(_bro) != null;
		}
		catch (e)
		{
		}
		return false;
	},

	function computeDuelPower( _bro )
	{
		local power = 0.0;
		try
		{
			local props = _bro.getCurrentProperties();
			power += _bro.getLevel() * 6.0;
			power += props.getMeleeSkill() * 1.2;
			power += props.getMeleeDefense() * 1.8;
			power += _bro.getHitpoints() * 0.6;

			if (::HumanSlaveCapture.safeHasSkill(_bro, "racial.champion"))
				power += 35.0;

			local tempInj = _bro.getSkills().getSkillsByFunction(@( s ) s.isType(::Const.SkillType.TemporaryInjury)).len();
			local permInj = _bro.getSkills().getSkillsByFunction(@( s ) s.isType(::Const.SkillType.PermanentInjury)).len();
			power -= tempInj * 12.0 + permInj * 10.0;
		}
		catch (e)
		{
		}
		return power;
	},

	function isPlayerAvatar( _bro )
	{
		if (_bro == null) return false;
		if (::HumanSlaveCapture.safeHasSkill(_bro, "trait.player")) return true;
		if (::HumanSlaveCapture.safeHasSkill(_bro, "trait.player_character")) return true;
		try
		{
			if (_bro.getFlags().has("IsPlayerCharacter")) return true;
		}
		catch (e)
		{
		}
		return false;
	},

	function resolveDuelWinner( _a, _b )
	{
		local aPlayer = this.isPlayerAvatar(_a);
		local bPlayer = this.isPlayerAvatar(_b);

		// Never silently delete a player avatar (e.g. Lone Wolf / Swordmaster) in a random event.
		if (aPlayer && !bPlayer) return { Winner = _a, Loser = _b };
		if (bPlayer && !aPlayer) return { Winner = _b, Loser = _a };

		local pA = this.computeDuelPower(_a);
		local pB = this.computeDuelPower(_b);
		local chanceA = ::Math.round(50.0 + (pA - pB) * 0.45);
		if (chanceA < 20) chanceA = 20;
		if (chanceA > 80) chanceA = 80;

		if (::Math.rand(1, 100) <= chanceA)
			return { Winner = _a, Loser = _b };
		return { Winner = _b, Loser = _a };
	},

	function hurtBroHpPct( _bro, _minPct, _maxPct )
	{
		if (_bro == null) return;
		try
		{
			local maxHp = _bro.getHitpointsMax();
			local target = ::Math.floor(maxHp * (::Math.rand(_minPct, _maxPct) / 100.0));
			if (target < 1) target = 1;
			if (_bro.getHitpoints() > target)
				_bro.setHitpoints(target);
		}
		catch (e)
		{
		}
	},

	function damageEquipment( _bro, _minPct, _maxPct )
	{
		if (_bro == null) return 0;
		local damaged = 0;
		try
		{
			local items = _bro.getItems();
			foreach (slot in [::Const.ItemSlot.Body, ::Const.ItemSlot.Head])
			{
				local item = items.getItemAtSlot(slot);
				if (item == null) continue;
				local cond = item.getCondition();
				local condMax = item.getConditionMax();
				if (condMax <= 0 || cond <= 1) continue;
				local nextCond = ::Math.max(1, ::Math.floor(cond * (::Math.rand(_minPct, _maxPct) / 100.0)));
				if (nextCond < cond)
				{
					item.setCondition(nextCond);
					damaged++;
				}
			}
		}
		catch (e)
		{
		}
		return damaged;
	},

	function addRandomPermanentInjury( _bro )
	{
		if (_bro == null) return null;
		try
		{
			local pool = [];
			foreach (entry in ::Const.Injury.Permanent)
			{
				if (entry == null || entry.ID == null || entry.Script == null) continue;
				if (::HumanSlaveCapture.safeHasSkill(_bro, entry.ID)) continue;
				pool.push(entry);
			}
			if (pool.len() == 0) return null;
			local pick = pool[::Math.rand(0, pool.len() - 1)];
			local threshold = 0.0;
			if ("Threshold" in pick && pick.Threshold != null) threshold = pick.Threshold;
			local inj = _bro.addInjury([
				{
					ID = pick.ID,
					Threshold = threshold,
					Script = pick.Script
				}
			]);
			try { _bro.getSkills().update(); } catch (e) {}
			return inj;
		}
		catch (e)
		{
			::HumanSlaveCapture.logError("champion duel permanent injury failed: " + e);
		}
		return null;
	},

	function pickRandomBystanders( _maxCount )
	{
		local pool = [];
		foreach (bro in this.m.Others)
		{
			if (this.isBroInRoster(bro)) pool.push(bro);
		}
		local picked = [];
		local target = ::Math.min(_maxCount, pool.len());
		while (picked.len() < target && pool.len() > 0)
		{
			local idx = ::Math.rand(0, pool.len() - 1);
			picked.push(pool[idx]);
			pool.remove(idx);
		}
		return picked;
	},

	function pickPermanentVictim( _bystanders )
	{
		if (_bystanders == null || _bystanders.len() == 0) return null;
		local nonPlayers = [];
		foreach (bro in _bystanders)
		{
			if (!this.isPlayerAvatar(bro))
				nonPlayers.push(bro);
		}
		if (nonPlayers.len() > 0)
			return nonPlayers[::Math.rand(0, nonPlayers.len() - 1)];
		return _bystanders[0];
	},

	function killChampionInEvent( _dead, _causeText, _keepGearInStash )
	{
		if (!this.isBroInRoster(_dead)) return false;

		if (_keepGearInStash)
		{
			this.damageEquipment(_dead, 35, 60);
			try
			{
				_dead.getItems().transferToStash(::World.Assets.getStash());
			}
			catch (e)
			{
				::HumanSlaveCapture.logError("champion duel transferToStash failed: " + e);
			}
		}

		try
		{
			local bgId = "";
			try { bgId = _dead.getBackground().getID(); } catch (e) {}

			local fallen = {
				Name = _dead.getName(),
				Time = ::World.getTime().Days,
				TimeWithCompany = ::Math.max(1, _dead.getDaysWithCompany()),
				Kills = _dead.getLifetimeStats().Kills,
				Battles = _dead.getLifetimeStats().Battles,
				KilledBy = _causeText,
				Expendable = bgId == "background.slave"
			};
			::World.Statistics.addFallen(fallen);
		}
		catch (e)
		{
			::HumanSlaveCapture.logError("champion duel addFallen failed: " + e);
		}

		try { _dead.getSkills().onDeath(::Const.FatalityType.None); } catch (e) {}

		try
		{
			::World.getPlayerRoster().remove(_dead);
			::World.Assets.updateFormation();
			return true;
		}
		catch (e)
		{
			::HumanSlaveCapture.logError("champion duel remove dead failed: " + e);
		}
		return false;
	},

	function desertChampionWithGear( _bro )
	{
		if (!this.isBroInRoster(_bro)) return false;
		try
		{
			::World.getPlayerRoster().remove(_bro);
			::World.Assets.updateFormation();
			return true;
		}
		catch (e)
		{
			::HumanSlaveCapture.logError("champion duel desert failed: " + e);
		}
		return false;
	},

	function prepare()
	{
		this.m.ChampA = null;
		this.m.ChampB = null;
		this.m.Others = [];
		this.m.PickedWinner = null;
		this.m.PickedLoser = null;

		local champs = ::HumanSlaveCapture.getChampionBrothers();
		if (champs.len() < 2) return;

		local idxA = ::Math.rand(0, champs.len() - 1);
		this.m.ChampA = champs[idxA];
		champs.remove(idxA);

		local idxB = ::Math.rand(0, champs.len() - 1);
		this.m.ChampB = champs[idxB];

		foreach (bro in ::HumanSlaveCapture.getAliveBrothers())
		{
			if (bro == this.m.ChampA || bro == this.m.ChampB) continue;
			if (::HumanSlaveCapture.isLivingUndead(bro)) continue;
			this.m.Others.push(bro);
		}
	},

	function onPrepare()
	{
		this.prepare();
	},

	function onUpdateScore()
	{
		this.m.Score = 0;

		if (::HumanSlaveCapture == null) return;
		this.m.Title = ::HumanSlaveCapture.L("双冠死斗", "Duel of Champions");

		if (::HumanSlaveCapture.Trial != null && ::HumanSlaveCapture.Trial.Active == true) return;
		if (::HumanSlaveCapture.EventCombat != null && ::HumanSlaveCapture.EventCombat.Armed == true) return;
		try
		{
			if (::Tactical != null && ::Tactical.isActive()) return;
		}
		catch (e)
		{
		}

		local champs = ::HumanSlaveCapture.getChampionBrothers();
		if (champs.len() < 2) return;

		// High escalating weight to softly enforce a 1-champion company limit.
		this.m.Score = 80 + (champs.len() - 2) * 80;
	},

	function onClear()
	{
		this.m.ChampA = null;
		this.m.ChampB = null;
		this.m.Others = [];
		this.m.PickedWinner = null;
		this.m.PickedLoser = null;
	}
});
