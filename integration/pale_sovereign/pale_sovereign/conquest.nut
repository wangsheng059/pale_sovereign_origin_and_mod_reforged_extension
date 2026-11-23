local S = ::PaleSovereign;
local C = ::Conquest;

C.canTarget <- function( _town )
{
    if (_town == null || ::MSU.isNull(_town) || !_town.isAlive() || !_town.isActive())
        return false;
    local owner = _town.getOwner();
    return owner == null || ::MSU.isNull(owner) || owner.getType() != ::Const.FactionType.Player;
};

C.getNearbySettlement = function()
{
    local player = ::World.State.getPlayer();
    local nearest = null;
    local distance = 2;
    foreach (town in ::World.EntityManager.getSettlements())
    {
        if (!C.canTarget(town))
            continue;
        local d = town.getTile().getDistanceTo(player.getTile());
        if (d < distance)
        {
            distance = d;
            nearest = town;
        }
    }
    return nearest;
};

S.conquestMode = function( _town )
{
    if (!S.isActive() || _town == null || ::MSU.isNull(_town))
        return 0;
    local mode = _town.getFlags().getAsInt("PaleConquestMode");
    return mode > 0 && C.isOwnedByPlayer(_town) ? mode : 0;
};

S.conquestChoose <- function( _town, _mode )
{
    if (_town == null || !C.isOwnedByPlayer(_town) || _town.getFlags().get("PaleConquestPending") != true)
        return null;
    local flags = _town.getFlags();
    local contracts = clone _town.getContracts();
    flags.set("PaleConquestMode", _mode);
    flags.set("PaleConquestPending", false);
    if (_mode == 1)
        return "城中的钟照常敲响，集市照常开张，只是再没人敢抬头直视城门上的骷髅。恐惧税使税收 +25%，城镇每周失去 1 点繁荣度。防腐尸骸上限 +30。";

    foreach (contract in contracts)
        if (!contract.isActive())
            ::World.Contracts.removeContract(contract);
    this.changeReserve(20);
    local affected = {};
    foreach (neighbor in ::World.EntityManager.getSettlements())
    {
        if (neighbor == _town || !neighbor.isAlive() || !C.canTarget(neighbor) || C.isOwnedByPlayer(neighbor)
            || neighbor.getTile().getDistanceTo(_town.getTile()) > 10)
            continue;
        local faction = neighbor.getFactionOfType(::Const.FactionType.Settlement);
        if (faction == null)
            faction = C.getDefenderFaction(neighbor);
        if (faction == null || faction.getID() in affected)
            continue;
        affected[faction.getID()] <- true;
        faction.addPlayerRelation(-20.0, "相邻城镇成了亡者之城");
        neighbor.updatePlayerRelation();
    }
    _town.updateRoster(true);
    local label = _town.getLabel("name");
    if (label != null)
        label.Text = _town.getName();
    return "这一夜过后，城里再也听不到活人的声音。城镇成为亡者之城：收集 20 点防腐尸骸，尸骸上限 +30，周边定居点关系 −20。这里此后不再有活人招募、合同或税收。";
};

S.conquestChoices <- function( _screen, _town )
{
    foreach (mode in [1, 2])
    {
        local decision = mode;
        _screen.Options.push({
            Text = decision == 1 ? "统治 · 恐惧税 +25%，每周繁荣度 −1，尸骸上限 +30" : "屠城 · 建立亡者之城，收集 20 点尸骸，尸骸上限 +30",
            function getResult( _event )
            {
                local text = S.conquestChoose(_town, decision);
                if (text == null)
                    return 0;
                local art = decision == 1 ? "conquest_rule" : "conquest_raze";
                _event.m.PaleConquestResult <- "[img]gfx/ui/events/pale/" + art + ".jpg[/img]" + text;
                return "PaleConquestResult";
            }
        });
    }
};

S.conquestResultScreen <- function()
{
    return {
        ID = "PaleConquestResult",
        Text = "",
        Banner = "",
        Characters = [],
        Options = [{
            Text = "就这么办。",
            function getResult( _event )
            {
                return 0;
            }
        }],
        function start( _event )
        {
            this.Text = _event.m.PaleConquestResult;
            this.Banner = "ui/banners/" + ::World.Assets.getBanner() + "s.png";
        }
    };
};

S.Mod.hook("scripts/events/events/conquest_assault_event", function(q)
{
    q.create = @(__original) function()
    {
        __original();
        foreach (screen in this.m.Screens)
        {
            if (screen.ID != "Victory")
                continue;
            local start = screen.start;
            screen.start = function( _event )
            {
                if (!S.isActive() || _event.m.Town == null || _event.m.Town.isNull())
                    return start.call(this, _event);
                local town = _event.m.Town.get();
                if (!C.isOwnedByPlayer(town))
                {
                    start.call(this, _event);
                    town.getFlags().set("PaleConquestPending", true);
                }
                this.Options = [];
                this.Text = "[img]gfx/ui/events/pale/conquest_choice.jpg[/img]城门的铁闩被枯骨从内侧抬起，沉重的门扇在一片死寂中缓缓敞开。守军的旗帜被踩进了泥水，残存的士兵早已扔下武器，和满城的居民一起伏在冰冷的街石上，连抽泣都压得极低。骷髅沿着主街排成两列，空洞的眼眶齐齐转向城中；行尸拖着脚步，把躲在屋檐下的伤者一个个拽出来，丢到广场中央。城墙上的守夜钟没人再敢去敲，只剩风从钟口灌进去，发出一阵阵低哑的呜咽。盗墓贼们已经在打量哪几户人家的地窖最深，哪座教堂底下的墓穴最值钱。导师缓步走过跪伏的人群，法杖顶端的魂火从一张张惨白的脸上掠过，没有人敢抬头。这座城往后是照常开市纳税，靠恐惧苟延残喘地过日子，还是就此归于寂静，让每一具尸骸都走进亡者的队列？活人们屏住呼吸，静候导师的裁决。";
                S.conquestChoices(this, town);
            };
        }
        this.m.Screens.push(S.conquestResultScreen());
    };
});

S.Mod.hookTree("scripts/entity/world/settlement", function(q)
{
    q.getUIInformation = @(__original) function()
    {
        local info = __original();
        if (!C.canTarget(this))
        {
            if ("ConquestOwned" in info) delete info.ConquestOwned;
            if ("ConquestLabel" in info) delete info.ConquestLabel;
        }
        return info;
    };

    q.updateRoster = @(__original) function( _force = false )
    {
        if (S.conquestMode(this) != 2)
            return __original(_force);
        local roster = ::World.getRoster(this.getID());
        if (roster != null)
            roster.clear();
    };

    q.getContracts = @(__original) function()
    {
        return S.conquestMode(this) == 2 ? [] : __original();
    };

    q.getName = @(__original) function()
    {
        local name = __original();
        return S.conquestMode(this) == 2 ? name + "（亡者之城）" : name;
    };
});

S.Mod.hook("scripts/ui/screens/world/modules/world_town_screen/town_main_dialog_module", function(q)
{
    q.onConquestButtonPressed = @(__original) function()
    {
        if (C.canTarget(::World.State.getCurrentTown()))
            __original();
    };
});

S.Mod.hook("scripts/factions/settlement_faction", function(q)
{
    q.isReadyForContract = @(__original) function()
    {
        return (this.m.Settlements.len() == 0 || S.conquestMode(this.m.Settlements[0]) != 2) && __original();
    };
});

local tax = C.getTax;
C.getTax = function( _town )
{
    local mode = S.conquestMode(_town);
    return mode == 2 ? 0 : mode == 1 ? ::Math.round(tax(_town) * 1.25) : tax(_town);
};

local upkeep = C.getGarrisonUpkeep;
C.getGarrisonUpkeep = function()
{
    local total = upkeep();
    if (S.isActive())
        foreach (town in C.getOwnedSettlements())
            if (S.conquestMode(town) > 0)
                total -= C.Garrison[C.getGarrisonLevel(town)].Upkeep;
    return total;
};

local getGarrison = C.getGarrisonLevel;
local maxGarrison = C.Garrison.len() - 1;
local championGarrison = clone C.Garrison[maxGarrison];
championGarrison.Name = "冠军统领的亡灵驻军";
championGarrison.En = championGarrison.Name;
championGarrison.Resources += C.Garrison[maxGarrison].Resources - C.Garrison[maxGarrison - 1].Resources;
championGarrison.HoldChance = ::Math.min(95, championGarrison.HoldChance + 15);
C.Garrison.push(championGarrison);
C.getGarrisonLevel = function( _town )
{
    local flags = _town.getFlags();
    local bonus = S.conquestMode(_town) > 0 && flags.get("PaleGovernor") == true
        && flags.get("PaleGarrisonHungry") != true ? 1 : 0;
    return ::Math.min(maxGarrison, getGarrison(_town)) + bonus;
};

local undeadHireCosts = [5, 10, 15];
local hireGarrison = C.hireGarrison;
C.hireGarrison = function( _town )
{
    local level = getGarrison(_town);
    if (level >= maxGarrison)
        return;
    if (S.conquestMode(_town) == 0)
        return hireGarrison(_town);
    if (!S.changeReserve(-undeadHireCosts[level]))
        return false;

    local flags = _town.getFlags();
    flags.set("ConquestGarrison", level + 1);
    flags.set("ConquestLastResult", "已消耗 " + undeadHireCosts[level] + " 点尸骸，亡灵驻军升至 " + (level + 1) + " 级。");
    return true;
};

local taxes = C.updateTaxes;
C.updateTaxes = function()
{
    local flags = ::World.Statistics.getFlags();
    local before = flags.get("ConquestLastTaxDay");
    taxes();
    if (!S.isActive() || before == false || before == flags.get("ConquestLastTaxDay"))
        return;
    foreach (town in C.getOwnedSettlements())
    {
        local mode = S.conquestMode(town);
        if (mode == 0)
            continue;
        local localFlags = town.getFlags();
        if (mode == 1)
            localFlags.set("ConquestProsperity", ::Math.max(0, C.getProsperity(town) - 1));
        local level = getGarrison(town);
        if (level > 0 || localFlags.get("PaleGovernor") == true)
        {
            local paid = S.changeReserve(-3);
            localFlags.set("PaleGarrisonHungry", !paid && level == 0);
            if (!paid)
            {
                localFlags.set("ConquestGarrison", ::Math.max(0, level - 1));
                localFlags.set("ConquestLastResult", "本周防腐尸骸不足，一部分驻军烂得再也站不起来。亡灵驻军降级。");
            }
        }
    }
};

S.CemeteryDef <- {
    Key = "pale_cemetery", Name = "墓园", En = "墓园", Days = 2, Cost = 500,
    Terrain = [::Const.World.TerrainType.Plains, ::Const.World.TerrainType.Steppe, ::Const.World.TerrainType.Hills,
        ::Const.World.TerrainType.Forest, ::Const.World.TerrainType.AutumnForest, ::Const.World.TerrainType.Farmland,
        ::Const.World.TerrainType.Snow, ::Const.World.TerrainType.Badlands, ::Const.World.TerrainType.Desert],
    Near = [], Distance = 2
};
C.Buildings.push(S.CemeteryDef);

local buildable = C.getBuildable;
C.getBuildable = function( _town )
{
    local result = buildable(_town);
    return S.conquestMode(_town) > 0 ? result : result.filter(@(_, def) def.Key != "pale_cemetery");
};

S.conquestDay = function()
{
    foreach (town in C.getOwnedSettlements())
        if (S.conquestMode(town) > 0)
            foreach (attached in town.getActiveAttachedLocations())
                if (attached.getTypeID() == "attached_location.pale_cemetery")
                    S.changeReserve(3);
};

// 1.6.12：每座统治或屠城的城镇防腐尸骸上限 +30
S.conquestReserveBonus = function()
{
    local bonus = 0;
    local castle = S.ambitionDone("castle_taken");
    foreach (town in ::World.EntityManager.getSettlements())
        if (town != null && town.isAlive() && S.conquestMode(town) > 0)
            bonus += castle && town.isMilitary() ? 50 : 30;
    return bonus;
};

// 野心「城堡易主」：记录亡灵主宰攻下的城堡数
local capture = C.capture;
C.capture = function( _s )
{
    local castle = S.isActive() && !C.isOwnedByPlayer(_s) && _s.isMilitary();
    capture(_s);
    if (castle && C.isOwnedByPlayer(_s))
        S.set("CastleConquests", S.get("CastleConquests") + 1);
};

S.findPaleTown = function()
{
    local town = C.getNearbySettlement();
    return town != null && S.conquestMode(town) > 0 ? town : null;
};

S.conquestRecruitPanel <- function( _screen )
{
    local town = this.findPaleTown();
    _screen.Text = "街道上再无人声。集市的摊位还支着褪色的篷布，上面积了一层灰，酒馆的招牌在风里吱呀摇晃，却再没有人推门进去。城中每一扇窗户都黑着，只有墓园那边终夜亮着幽绿的魂火。几条野狗起初还在巷子里游荡，没过几天也夹着尾巴逃出了城，连乌鸦都不肯落在屋顶上。从前的居民如今在广场上排成整齐的队列，有的还系着围裙，有的手里攥着生前没来得及放下的锄头。导师的随从在空置的房屋间穿行，把新编入列的死者逐一登记造册：骨架完整的送去磨利兵器，皮肉尚存的就地缝补，实在拼不起来的便腌进盐桶，留作日后的材料。城门口的旧告示还没被撕掉，上面写着这座城的名字和赋税的章程，如今读来倒像一篇墓志铭。这里再也不需要税吏和征兵官，死者自会应召。";
    if (town == null || this.conquestMode(town) != 2)
    {
        _screen.Text = "需要在一座亡者之城旁边。";
        return;
    }
    this.recruitPoolPanel(_screen, town, this.recruitCost(), 0);
};

local startSiege = C.startSiege;
C.startSiege = function( _town, _faction )
{
    local flags = _town.getFlags();
    local holy = S.conquestMode(_town) > 0 && flags.getAsInt("ConquestFormerOwner") == _faction.getID() && ::Math.rand(1, 100) <= 50;
    flags.set("PaleHolySiege", holy);
    startSiege(_town, _faction);
    if (holy)
        flags.set("ConquestLastResult", "城外燃起了圣火。猎巫人与执誓者率圣火讨伐军前来收复失地，兵力 +25%。");
};

local strength = C.getSiegeStrength;
C.getSiegeStrength = function( _town )
{
    return strength(_town) * (_town.getFlags().get("PaleHolySiege") == true ? 1.25 : 1.0);
};

local repelled = C.onSiegeRepelled;
C.onSiegeRepelled = function( _town, _player )
{
    if (S.isActive() && _town.getFlags().get("PaleHolySiege") == true)
        S.pendingItem("misc/pale_chain_item");
    _town.getFlags().set("PaleHolySiege", false);
    return repelled(_town, _player);
};

local siegeLost = C.onSiegeLost;
C.onSiegeLost = function( _town )
{
    local flags = _town.getFlags();
    local result = siegeLost(_town);
    if (S.isActive() && !C.isOwnedByPlayer(_town))
    {
        flags.set("PaleConquestMode", 0);
        flags.set("PaleConquestPending", false);
        flags.set("PaleHolySiege", false);
        S.returnGovernor(_town);
        S.clearRecruitPool(_town);
        local label = _town.getLabel("name");
        if (label != null)
            label.Text = _town.getName();
    }
    return result;
};

S.ConquestDefense <- null;
local startDefense = C.startSiegeBattle;
C.startSiegeBattle = function( _town )
{
    if (S.conquestMode(_town) == 0)
        return startDefense(_town);
    S.ConquestDefense = _town;
    try
    {
        local result = startDefense(_town);
        S.ConquestDefense = null;
        return result;
    }
    catch(e)
    {
        S.ConquestDefense = null;
        throw e;
    }
};

S.Mod.hook("scripts/states/world_state", function(q)
{
    q.startScriptedCombat = @(__original) function( _properties = null, _isPlayerInitiated = true, _isCombatantsVisible = true, _allowFormationPicking = true )
    {
        if (_properties != null && _properties.CombatID == "ConquestSiege" && S.ConquestDefense != null)
        {
            local town = S.ConquestDefense;
            local enemies = _properties.Entities.filter(@(_, entity) entity.Faction == ::Const.Faction.Enemy);
            if (town.getFlags().get("PaleHolySiege") == true && enemies.len() > 1)
            {
                enemies[0].Script = "scripts/entity/tactical/humans/pale_witch_hunter";
                enemies[1].Script = "scripts/entity/tactical/humans/oathbringer";
            }
            local resources = C.Garrison[C.getGarrisonLevel(town)].Resources;
            if (resources > 0)
            {
                local count = ::Math.max(2, (resources / 14).tointeger());
                for (local i = 0; i < count; ++i)
                {
                    local soldier = clone ::Const.World.Spawn.Troops[i % 2 == 0 ? "SkeletonLight" : "Zombie"];
                    soldier.Faction <- ::Const.Faction.PlayerAnimals;
                    enemies.push(soldier);
                }
            }
            _properties.Entities = enemies;
            if (town.getFlags().get("PaleGovernor") == true)
                S.addGovernorToCombat(_properties, town);
        }
        return __original(_properties, _isPlayerInitiated, _isCombatantsVisible, _allowFormationPicking);
    };
});

S.Mod.hook("scripts/events/events/conquest_manage_event", function(q)
{
    q.create = @(__original) function()
    {
        __original();
        foreach (screen in this.m.Screens)
        {
            if (screen.ID != "A")
                continue;
            local start = screen.start;
            screen.start = function( _event )
            {
                start.call(this, _event);
                local town = _event.m.Town.get();
                local mode = S.conquestMode(town);
                if (mode == 0 && (!S.isActive() || town.getFlags().get("PaleConquestPending") != true))
                {
                    if (getGarrison(town) >= maxGarrison)
                        this.Options = this.Options.filter(@(_, option) option.Text.find(C.T("opt_garrison")) != 0);
                    return;
                }
                if (mode == 0)
                {
                    this.Options.insert(0, { Text = "决定城镇的命运", function getResult( _event ) {
                        C.PendingEvent = "event.pale_conquest_choice"; C.Target = ::WeakTableRef(town); return 0;
                    } });
                    return;
                }
                local status = this.Text.find("\n" + C.T("manage_garrison"));
                if (status != null)
                {
                    local nextLine = this.Text.find("\n", status + 1);
                    local suffix = nextLine == null ? "" : this.Text.slice(nextLine);
                    this.Text = this.Text.slice(0, status) + "\n亡灵驻军 " + C.getGarrisonLevel(town) + " 级，每周消耗 3 点防腐尸骸。" + suffix;
                }
                this.Text += mode == 1 ? "\n\n统治 · 恐惧税 +25%，繁荣度每周 −1，防腐尸骸上限 +30。" : "\n\n亡者之城 · 可从待选名单征召常驻亡灵，无活人招募、合同或税收，防腐尸骸上限 +30。";
                this.Options = this.Options.filter(@(_, option) option.Text.find(C.T("opt_garrison")) != 0);
                this.Options.insert(this.Options.len() - 1, {
                    Text = "管理亡灵驻防",
                    function getResult( _event ) { return "PaleDefense"; }
                });
            };
        }

        this.m.Screens.push({
            ID = "PaleDefense",
            Text = "",
            Banner = "",
            Characters = [],
            Options = [],
            function start( _event )
            {
                local town = _event.m.Town.get();
                local mode = S.conquestMode(town);
                local level = getGarrison(town);
                this.Banner = "ui/banners/" + ::World.Assets.getBanner() + "s.png";
                local strength = C.getGarrisonLevel(town);
                local art = "fort_barracks";
                foreach (site in town.getActiveAttachedLocations())
                    if (site.getTypeID() == "attached_location.pale_cemetery")
                    {
                        art = "town_cemetery";
                        break;
                    }
                this.Text = "[img]gfx/ui/events/pale/" + art + ".jpg[/img]基础亡灵驻军 " + level + " 级";
                if (strength > level)
                    this.Text += "，计入冠军坐镇为 " + strength + " 级";
                this.Text += "。防腐尸骸储备 " + S.get("Reserve") + " 点。驻军每周消耗 3 点防腐尸骸。";
                this.Options = [];
                if (mode > 0 && level < maxGarrison)
                {
                    local price = undeadHireCosts[level];
                    local text = "增编至 " + (level + 1) + " 级（" + price + " 点尸骸）";
                    if (S.get("Reserve") >= price)
                    {
                        this.Options.push({
                            Text = text,
                            function getResult( _event )
                            {
                                C.hireGarrison(town);
                                return "PaleDefense";
                            }
                        });
                    }
                    else
                        this.Text += "\n" + text + "，当前储备不足。";
                }
                if (mode == 2)
                {
                    this.Options.push({
                        Text = "征召常驻亡灵",
                        function getResult( _event )
                        {
                            S.CastlePage = "conquest_recruit";
                            return 0;
                        }
                    });
                }
                if (mode > 0 && S.oath() == S.Oath.Champion)
                {
                    this.Options.push({
                        Text = "冠军坐镇",
                        function getResult( _event )
                        {
                            S.CastlePage = "conquest_governor";
                            return 0;
                        }
                    });
                }
                this.Options.push({
                    Text = "返回城镇管理",
                    function getResult( _event ) { return "A"; }
                });
            }
        });
    };
});
