local S = ::PaleSovereign;

local attackBattles = ["SecretPassage", "AssaultTheGate", "BurnTheCastle", "AssaultTheCourtyard", "DefendersSallyForth", "ConquestAssault"];
local defenseBattles = ["Stronghold", "ConquestSiege", "DefendHolySite"];

local enemyScenes = [
    { Scene = "Barbarian", Scripts = ["barbarian_"] },
    { Scene = "Orc", Scripts = ["orc_"] },
    { Scene = "Goblin", Scripts = ["goblin_"] },
    { Scene = "Ancient", Scripts = ["skeleton", "ancient_", "mummy"] },
    { Scene = "Revenant", Scripts = ["undead", "zombie", "necromancer", "draugr", "ghost"] },
    { Scene = "Beast", Scripts = ["wolf", "hyena", "serpent", "lindwurm", "spider", "unhold", "schrat", "ghoul", "alp", "hexen", "kraken"] }
];

local scenes = {
    Barbarian = [
        ["barbarian_in", "风雪遮住了山口，野蛮人的圆盾已在对面排开。让前排站稳，给导师留出退路。"],
        ["barbarian_out", "北风重新吹过山口。把冻硬的盾带解开，趁天黑前将棺木拖回营地。"]
    ],
    Orc = [
        ["orc_in", "兽人的黑旗出现在采石场上方。接敌前，让勇士与导师保持照应。"],
        ["orc_out", "采石场里只剩风声。先清点队员，再把战后留下的合格遗骸装车。"]
    ],
    Goblin = [
        ["goblin_in", "树上的地精带着淬毒的箭。常驻亡灵免疫中毒，可以先守住阵线。"],
        ["goblin_out", "树台上的火光熄了。战团在溪边重新集结，将受损的亡灵带回营地修补。"]
    ],
    Ancient = [
        ["ancient_in", "古代军团从石门后排成盾阵。给导师留出施法的位置，别让两支骨军混在一起。"],
        ["ancient_out", "墓室重归寂静。清剿遗址后，在附近打开亡者的营地账簿即可勘察。"]
    ],
    Revenant = [
        ["tomb", "墓门后响起拖拽声。给导师留出施法的位置，也留神重新站起来的尸体。"],
        ["salvage", "确认倒下的亡者已经安静，再清点可以封存的合格遗骸。"]
    ],
    Beast = [
        ["beast_in", "林间响起爪子踩断枯枝的声音。让常驻亡灵守在外围，给导师留出回撤的路。"],
        ["beast_out", "溪水冲淡了兽径上的痕迹。回营后清点防腐尸骸，受损的亡灵每日可用它修补。"]
    ],
    Assault = [
        ["siege", "攻城的号角尚未响起。在城门外整好队形，给导师和勇士留出照应的位置。"],
        ["smoke", "城门下的烟还未散尽。若已取胜，留在战场的合格遗骸可以封存。"]
    ],
    Defense = [
        ["defend_in", "城垛上的守卫已经看见敌旗。让常驻亡灵守住缺口，给导师留出施法的位置。"],
        ["defend_out", "城内换上了新的守夜人。休整时翻开营地账簿，检查该修补的队员和剩下的尸骸。"]
    ],
    Snow = [
        ["moon", "月光照亮雪地里的盾阵。若在夜间开战，导师额外获得 20 点决心。"],
        ["snowbound", "脚印正被新雪填平。把伤员和棺木带回营地，再清点名册。"]
    ],
    Desert = [
        ["dunes", "盐风沿着断柱刮过。整队时给活人队员和导师留下可以互相照应的位置。"],
        ["desert_out", "盐地的余温还在上升。天黑前推过这段干河床，营火就在石柱背后。"]
    ]
};

local fieldScreens = [
    {
        Covers = ["moon", "bridge", "tomb"],
        Tips = [
            "部署时给亡灵法师导师留出退路。导师阵亡，战役就此结束。",
            "夜战中，亡灵法师导师额外获得 20 点决心。",
            "常驻亡灵不会因盟友阵亡而动摇，可以让它们守住阵线。",
            "用缚魂锁链标记精锐后，保全遗骸才能在胜利后注魂。",
            "亡灵天灾可消耗防腐尸骸投掷尸弹，落点会留下可复活或引爆的尸体。"
        ]
    },
    {
        Covers = ["salvage", "embers", "repair"],
        Tips = [
            "胜利后，留在战场上的合格遗骸可以封存为防腐尸骸。",
            "常驻亡灵若受损，每日可消耗防腐尸骸修补。",
            "清剿遗址后，在附近打开亡者的营地账簿即可勘察。",
            "常驻亡灵达到 7 级后，可在营地查看可用的升阶分支。",
            "为勇士选择注魂方式时，才会扣除一条缚魂锁链。"
        ]
    }
];

local function enemyScene( _script )
{
    foreach (enemy in enemyScenes)
        foreach (name in enemy.Scripts)
            if (_script.find(name) != null)
                return enemy.Scene;
    return "Field";
}

local function selectScene( _combatID, _tile, _enemies, _parties )
{
    if (attackBattles.find(_combatID) != null)
        return "Assault";
    if (defenseBattles.find(_combatID) != null)
        return "Defense";

    local contract = ::World.Contracts.getActiveContract();
    if (contract != null && contract.getType() == "contract.nem_defend_settlement_nobles")
        foreach (party in _parties)
            if (contract.m.UnitsSpawned.find(party.getID()) != null)
                return "Defense";

    local counts = {};
    local best = "Field";
    local most = 0;
    foreach (enemy in _enemies)
    {
        local scene = enemyScene(enemy.Script);
        local count = scene in counts ? counts[scene] + 1 : 1;
        counts.rawset(scene, count);
        if (count > most)
        {
            best = scene;
            most = count;
        }
    }
    if (best != "Field" || _tile == null)
        return best;

    local terrain = ::Const.World.TerrainType;
    if (_tile.Type == terrain.Snow)
        return "Snow";
    if (_tile.Type == terrain.Desert || _tile.Type == terrain.Badlands)
        return "Desert";
    return "Field";
}

S.battleLoadingScene <- function( _properties, _pos = null )
{
    if (_properties != null)
    {
        local opponents = _properties.Entities.filter(@(_, troop) troop.Script != ""
            && (!("Faction" in troop) || !::World.FactionManager.isAlliedWithPlayer(troop.Faction)));
        return selectScene(_properties.CombatID, _properties.Tile, opponents, _properties.Parties);
    }

    local tile = ::World.getTile(::World.worldToTile(_pos));
    local radius = ::Const.World.CombatSettings.CombatPlayerDistance;
    // Read the encounter without calling getLocalCombatProperties, which starts the world combat.
    local hostile = @(_, party) party.isAlive() && !party.isPlayerControlled()
        && party.isAttackable() && party.getFaction() != 0 && party.getVisibilityMult() != 0 && !party.isAlliedWithPlayer();
    local parties = ::World.getAllEntitiesAtPos(_pos, radius).filter(hostile);
    if (parties.filter(@(_, party) party.isInCombat()).len() != 0)
        parties = ::World.getAllEntitiesAtPos(_pos, radius * 2.0).filter(hostile);

    local unique = parties.filter(@(_, party) party.isLocation() && party.isLocationType(::Const.World.LocationType.Unique));
    if (unique.len() != 0)
        parties = unique;
    local opponents = [];
    foreach (party in parties)
        opponents.extend(party.getTroops().filter(@(_, troop) troop.Script != ""));
    return selectScene("", tile, opponents, parties);
};

S.battleLoadingData <- function( _entering, _scene )
{
    local direction = _entering ? 0 : 1;
    local cover;
    local tip;
    if (_scene in scenes)
    {
        local entry = scenes[_scene][direction];
        cover = entry[0];
        tip = entry[1];
    }
    else
    {
        local screen = fieldScreens[direction];
        cover = screen.Covers[::Math.rand(0, screen.Covers.len() - 1)];
        tip = screen.Tips[::Math.rand(0, screen.Tips.len() - 1)];
    }
    return {
        imagePath = "ui/screens/pale_sovereign_battle_" + cover + ".jpg",
        text = tip,
        PaleSovereignTitle = _entering ? "战前军令" : "战后手记"
    };
};
