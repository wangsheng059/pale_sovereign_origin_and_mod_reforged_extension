this.pale_sovereign_scenario <- ::inherit("scripts/scenarios/world/starting_scenario", {
    m = {},
    function create()
    {
        this.m.ID = ::PaleSovereign.ID;
        this.m.Name = "亡灵主宰";
        this.m.Description = "[p=c][img]gfx/ui/events/pale_sovereign.png[/img][/p][p]世人以为你的名讳早已随那场围剿化作灰烬，却不知你在荒冢深处唤醒了更古老的死灵之力。如今，两名盗墓贼护着一具封存古墓卫士的旧棺随你重返人间。是铸就一尊不朽的冠军，还是驱使无尽尸潮吞没大地？亡者的时代，正待你亲手落子。\n\n[color=#bcad8c]亡灵法师导师：[/color] 你以亡灵法师导师、一名残破的墓穴守卫和两名盗墓贼开局，并带有两条缚魂锁链。只有导师能装备初生骷髅法杖，法杖会随誓约蜕变。\n[color=#bcad8c]两条誓约：[/color] 导师学会第一个路线独有特技时永久立誓，死灵精通两条路线共用。\n[color=#bcad8c]亡灵冠军：[/color] 用缚魂锁链标记濒死的亡灵精锐，战胜后把它的灵魂注入棺中的冠军，强化躯体、吞噬特质或继承具名武器。\n[color=#bcad8c]亡灵天灾：[/color] 全队都能消耗防腐尸骸向敌人投掷尸弹，落地的尸体可以复活或引爆。导师的尸爆会触发岁月诅咒的削甲。\n[color=#bcad8c]防腐尸骸：[/color] 立誓后，每场胜利每两具合格遗骸可封存一点，最多储存 40 点。每日消耗一点，为所有受伤的常驻亡灵修补躯体。\n[color=#bcad8c]亡者的营地：[/color] 在大地图上扎营即可翻开营地账簿，清点尸骸、锁链与魂玉，勘察附近清剿过的遗址，并在那里花三点防腐尸骸征召常驻骷髅或行尸。\n[color=#bcad8c]常驻亡灵：[/color] 不领薪水，不吃粮食，不受士气影响，伤口也不会自行愈合。亡灵冠军最多拥有 3 名，亡灵天灾可以填满全部空余编制。\n[color=#bcad8c]人少而精：[/color] 你的名册不能超过 12 人，每场战斗最多部署 12 人。饰品宠物与临时复活的亡灵不受数量限制。\n[color=#bcad8c]世人的戒心：[/color] 贵族、誓约者、圣职者、猎巫人、骑士、剑术大师和其他亡灵法师不愿加入你的战团。\n[color=#bcad8c]夜行者：[/color] 夜间战斗时，导师额外获得 20 点决心；大地图上的夜间视野惩罚减半。\n[color=#bcad8c]化身：[/color] 亡灵法师导师无法解雇。如果导师死亡，战役就结束了。[/p]";
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
        ::World.Assets.m.BrothersMax = ::PaleSovereign.RosterLimit;
        ::World.Assets.m.BrothersMaxInCombat = ::PaleSovereign.RosterLimit;
    }

    function onSpawnAssets()
    {
        local s = ::PaleSovereign;
        local chief = s.spawnBrother("pale_necromancer_background", ["armor/wizard_robe", "weapons/pale_staff"], 13, false);
        // setStartValuesEx(..., false) skips talents together with traits; the chief keeps no traits but rolls talents.
        chief.fillTalentValues();
        chief.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
        chief.getSkills().add(::new("scripts/skills/traits/player_character_trait"));
        chief.getFlags().set("IsPlayerCharacter", true);
        chief.getFlags().set("PaleChief", true);
        s.nameChief(chief);
        chief.getItems().equip(s.makeGuard(true));
        chief.getSkills().update();
        s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/militia_spear", "shields/wooden_shield"], 4);
        s.spawnBrother("graverobber_background", ["armor/thick_tunic", "weapons/knife", "tools/throwing_net"], 5);
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
