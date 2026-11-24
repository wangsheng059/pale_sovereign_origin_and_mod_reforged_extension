this.pale_sovereign_scenario <- ::inherit("scripts/scenarios/world/starting_scenario", {
    m = {},
    function create()
    {
        this.m.ID = ::PaleSovereign.ID;
        this.m.Name = "亡灵主宰";
        this.m.Description = "[p=c][img]gfx/ui/events/pale_sovereign.png[/img][/p][p]你是一名遭围剿后从荒冢里爬回来的亡灵法师。世人以为你的名讳早已随那场围剿化作灰烬，却不知你在荒冢深处唤醒了更古老的死灵之力。如今你身边只剩一具封在旧棺里的荒坟守卫和两名盗墓贼，要靠死人重新拉起一支战团，一步步成为让大陆颤抖的亡灵主宰。\n\n[color=#bcad8c]开局：[/color] 亡灵法师导师、一名残破的荒坟守卫、两名盗墓贼，外加两条缚魂锁链。只有导师能装备初生骷髅法杖，法杖会随誓约蜕变。\n[color=#bcad8c]两条路线，一次抉择：[/color] 导师学会第一个路线独有特技时永久立誓，另一条路线从此关上；死灵精通两条路线共用。冠军路线收集强者的灵魂，打造一尊不朽的亡灵冠军；天灾路线搜罗尸骸，统领一支杀不完、补不尽的亡者大军。\n[color=#bcad8c]亡灵冠军：[/color] 用缚魂锁链标记濒死的强敌（亡灵精锐、兽人督军、林德蠕龙、剑术大师等，敌阵里出现时会挂上「可缚之魂」提示），战胜后把它的灵魂注入棺中的冠军，强化躯体、吞噬特质或继承具名武器。骸骨权杖标记的猎物会吸引冠军攻击，导师遇险或猎物难以接近时，它会择机应战。\n[color=#bcad8c]亡灵天灾：[/color] 全队都能消耗防腐尸骸向敌人投掷尸弹，落地的尸体可以复活或引爆。导师的尸爆会触发岁月诅咒的削甲。\n[color=#bcad8c]独一无二的亡灵兄弟：[/color] 常驻亡灵不领薪水，不吃粮食，不受士气影响，伤口也不会自行愈合。每一个都有随机的外貌、头衔和生前身世，还能一路进阶成骷髅王、尸山巨像等十几种形态。两条路线都不限制数量，只受名册上限约束。\n[color=#bcad8c]防腐尸骸：[/color] 立誓后，每场胜利天灾路线每 2 具遗骸封存 1 点、冠军路线每 5 具封存 2 点（向下取整），最多储存 40 点。每日消耗 1 点，为所有受伤的常驻亡灵修补 40% 生命。\n[color=#bcad8c]亡者的营地：[/color] 点击大地图顶栏名册按钮左侧的“亡灵营地”即可翻开账簿，清点尸骸、锁链与魂玉，勘察附近清剿过的遗址，并在那里花 3 点防腐尸骸征召常驻骷髅或行尸。旅途中还会遇到棺中低语、深夜提灯人这样的事件，活人兄弟与亡灵之间也有自己的故事。\n[color=#bcad8c]飞升与结局：[/color] 导师一路成长，最终迎来飞升仪式：登神而去，还是留在尘世做苍白主宰？不同的选择和路线会走向不同的结局。\n[color=#bcad8c]死者王国：[/color] 在荒野里建起亡灵古堡，顶住讨伐军一波波围攻；攻下城池后，可以让活人缴恐惧税，也可以屠空全城，让死者在街上列队。\n[color=#bcad8c]人少而精：[/color] 名册上限 24 人。未立誓和亡灵冠军路线每场最多部署 9 人；亡灵天灾路线 13 人，完成「禁忌的初窥」后 14 人，飞升后 16 人。饰品宠物与临时复活的亡灵不受数量限制。\n[color=#bcad8c]世人的戒心：[/color] 贵族、誓约者、圣职者、猎巫人、骑士、剑术大师和其他亡灵法师不愿加入你的战团。\n[color=#bcad8c]夜行者：[/color] 夜间战斗时，导师额外获得 20 点决心；大地图上的夜间视野惩罚减半。\n[color=#bcad8c]化身：[/color] 亡灵法师导师无法解雇。如果导师死亡，战役就结束了。[/p]";
        this.m.Difficulty = 2;
        this.m.Order = 108;
        this.m.IsFixedLook = false;
        this.m.RF_RebuildPerkTreeAfterSpawn <- false;
    }

    function isValid()
    {
        return ::BGP.HasAC;
    }

    function onInit()
    {
        ::PaleSovereign.applyRosterLimits();
    }

    function onSpawnAssets()
    {
        local s = ::PaleSovereign;
        local chief = s.spawnBrother("pale_necromancer_background", ["armor/wizard_robe", "weapons/pale_staff"], 13);
        chief.getSkills().add(::new("scripts/skills/traits/player_character_trait"));
        chief.getFlags().set("IsPlayerCharacter", true);
        chief.getFlags().set("PaleChief", true);
        s.nameChief(chief);
        chief.getItems().equip(s.makeGuard(true));
        chief.getSkills().update();
        local robbers = [
            s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/militia_spear", "shields/wooden_shield"], 4),
            s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/knife", "tools/throwing_net"], 5)
        ];
        local stories = [
            "%name% 曾是墓园里的老手，为了一袋来路不明的金币，亲手替导师撬开了那座无名荒冢的石门。亲眼见过旧棺掀开的那一幕后，他明白跟着活人领主卖命，远不如替死人干活稳妥。",
            "%name% 因盗掘贵族陵墓被全境通缉，走投无路时撞见了重返人间的导师。他不在乎雇主还有没有心跳，只要工钱按时到手、车厢里的大家伙别半夜爬出来咬他就行。"
        ];
        foreach (i, bro in robbers)
        {
            local background = bro.getBackground();
            background.m.RawDescription = stories[i];
            background.buildDescription(true);
        }
        ::World.Flags.set("Pale.IntroPending", 1);
        s.addMaterials("chain", 2);
        local stash = ::World.Assets.getStash();
        stash.add(::new("scripts/items/supplies/bread_item"));
        stash.add(::new("scripts/items/supplies/ground_grains_item"));
        ::World.Assets.m.BusinessReputation = 0;
    }

    function onSpawnPlayer()
    {
        local start = null;
        foreach (town in ::World.EntityManager.getSettlements())
        {
            if (town.isMilitary() || town.isIsolatedFromRoads())
                continue;
            local tile = town.getTile();
            for (local d = 0; d < 6; ++d)
            {
                if (!tile.hasNextTile(d))
                    continue;
                local next = tile.getNextTile(d);
                if (!next.IsOccupied && next.HasRoad)
                {
                    start = next;
                    break;
                }
            }
            if (start != null)
                break;
        }
        if (start == null)
            start = ::World.EntityManager.getSettlements()[0].getTile();
        ::World.State.m.Player = ::World.spawnEntity("scripts/entity/world/player_party", start.Coords.X, start.Coords.Y);
        ::World.Assets.updateLook(1);
        ::World.getCamera().setPos(::World.State.m.Player.getPos());
    }

    function onUpdateHiringRoster( _roster )
    {
        foreach (bro in clone _roster.getAll())
            if (::PaleSovereign.isRejected(bro.getBackground().getID()))
                _roster.remove(bro);
    }

    function onBattleWon( _combatLoot )
    {
        ::PaleSovereign.onVictory(_combatLoot);
    }

    function onCombatFinished()
    {
        return ::PaleSovereign.chief() != null;
    }
});
