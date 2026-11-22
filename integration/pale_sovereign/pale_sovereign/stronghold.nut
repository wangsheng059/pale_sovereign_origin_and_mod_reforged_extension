local S = ::PaleSovereign;

S.CastleBuildings <- {
    pale_soul_furnace = { Name = "魂炉", Cost = 1500, Icon = "desert_building_14", Page = "castle_forge",
        Flavor = "炉膛里烧的不是木炭，而是碾碎的骨粉和魂玉残渣，火苗是冷的。", Effect = "用魂玉、古代金币、金锭和宝石强化亡灵。每次必须在古堡停留一天。" },
    pale_salt_cellar = { Name = "盐窖", Cost = 850, Icon = "building_02", Page = "castle",
        Flavor = "盐桶一直堆到拱顶，腌好的尸骸在这里能放上许多年。", Effect = "尸骸库存上限 +20。在古堡停留时，每天免费修补全体常驻亡灵。" },
    pale_soul_anvil = { Name = "缚魂铁砧", Cost = 1200, Icon = "building_01", Page = "castle",
        Flavor = "这块黑铁砧取自古帝国的刑场，打在上面的每一环铁链都缠着死者的哀嚎。", Effect = "每 10 天可用 200 克朗、10 工具和 1 块铜锭打一条缚魂锁链。" },
    pale_mausoleum = { Name = "冠军陵寝", Cost = 1300, Icon = "building_03", Page = "castle_tombs",
        Flavor = "三座墓室的棺盖上刻着冠军的名字，它们在长眠中也不会停止变强。", Effect = "可寄存 3 口候补棺椁。每口棺椁每日恢复 10% 最大生命并获得 10 经验。" },
    pale_dead_barracks = { Name = "亡者兵营", Cost = 1200, Icon = "building_04", Page = "castle_barracks",
        Flavor = "这里没有床铺，也没有伙房，只有一排排等着被唤起的尸体。", Effect = "消耗 3 点防腐尸骸征召常驻亡灵。升级需要 1000 克朗，之后新兵起始等级 +2。" },
    pale_sacrifice_pit = { Name = "献祭坑", Cost = 700, Icon = "building_13", Page = "castle_sacrifice",
        Flavor = "坑底的泥土从来没有干过。", Effect = "每名俘虏可换取 2 点防腐尸骸，或为导师提供 200 经验。" }
};

foreach (definition in S.CastleBuildings)
    definition.Description <- definition.Flavor + definition.Effect;

S.CastleIntro <- "古堡的石门在雾中敞开，铰链发出一声干涩的长鸣。守门的骷髅仍穿着生前那副锈透的鳞甲，听见脚步声便垂下长戟，让出通道。庭院里铺满了从旧墓里撬来的墓碑，碑文一律朝下，被往来的脚步磨得发亮。大厅的长桌旁没有一把椅子，这里的住客从来不需要坐下。墙上挂着从讨伐者手里缴来的旗帜，有几面还沾着没洗掉的血，烛台上燃着掺了骨油的蜡，火光幽绿，照不出任何人的影子。地窖深处隐约传来铁砧的敲击声和盐袋落地的闷响，那是亡灵们在替战团日夜干着永远干不完的活计。盗墓贼们一进门就钻进了厨房，那是整座古堡里唯一还烧着寻常炉火的地方，也是唯一闻不到腐味的地方。导师踏上台阶，满堂的魂火都朝着导师的方向低伏下去，像是在迎接它们归来的主人。";

S.isCastle <- function( _town )
{
    return _town != null && !::MSU.isNull(_town) && S.scriptBase(::IO.scriptFilenameByHash(_town.ClassNameHash)) == "stronghold_player_base";
};

S.castleHas <- function( _town, _key )
{
    return this.isCastle(_town) && _town.hasBuilding("building." + _key);
};

S.castleBuildingAllowed <- function( _key )
{
    if (!this.isActive())
        return false;
    if (_key == "pale_mausoleum")
        return this.oath() == this.Oath.Champion;
    if (_key == "pale_dead_barracks")
        return this.oath() == this.Oath.Scourge;
    if (_key == "pale_sacrifice_pit")
        return "HumanSlaveCapture" in ::getroottable();
    return true;
};

S.castles <- function()
{
    return ::World.EntityManager.getSettlements().filter(@(_, town) S.isCastle(town) && town.isAlive());
};

S.castleHere <- function( _range = 1 )
{
    local player = ::World.State.getPlayer();
    if (player == null || ::MSU.isNull(player))
        return null;
    foreach (town in this.castles())
        if (town.isActive() && !town.isUpgrading() && town.getTile().getDistanceTo(player.getTile()) <= _range)
            return town;
    return null;
};

S.castleReserveBonus = function()
{
    local bonus = 0;
    foreach (town in this.castles())
        if (this.castleHas(town, "pale_salt_cellar"))
            bonus += 20;
    return bonus;
};

S.CastleForbidden <- ["building.crowd", "building.hiring", "building.tavern", "building.temple"];
S.CastleForbiddenKeys <- ["Hire", "Hireable", "Hireables", "Hireling", "Hiring", "Crowd", "Tavern", "Temple"];

S.registerCastleBuildings <- function()
{
    foreach (key, definition in this.CastleBuildings)
    {
        if (key in ::Stronghold.Buildings)
            continue;
        ::Stronghold.Buildings[key] <- {
            Name = definition.Name, Description = definition.Description, ID = "building." + key,
            Path = key + "_building", SouthPath = "", Requirements = [], Price = definition.Cost,
            ImagePath = "ui/settlements/" + definition.Icon + ".png"
        };
    }
};

S.Mod.hook("scripts/entity/world/settlements/stronghold_player_base", function(q)
{
    q.getSizeName = @(__original) function( _next = false )
    {
        return S.isActive() ? "古堡" : __original(_next);
    };

    q.updateLook = @(__original) function()
    {
        if (S.isActive())
            this.m.Spriteset = "Luft_Necro";
        return __original();
    };

    q.updateTown = @(__original) function()
    {
        local result = __original();
        if (S.isActive())
            foreach (building in clone this.m.Buildings)
                if (building != null && S.CastleForbidden.find(building.getID()) != null)
                    this.removeBuilding(building.getID());
        return result;
    };

    q.getUIInformation = @(__original) function()
    {
        local info = __original();
        if (S.isActive())
        {
            info.Background <- "ui/events/pale/mortuary.jpg";
            foreach (layer in ["BackgroundCenter", "BackgroundLeft", "BackgroundRight", "Ramp", "RampPathway"])
                info[layer] <- "";
        }
        return info;
    };

    q.updateRoster = @(__original) function( _force = false )
    {
        if (!S.isActive())
            return __original(_force);
        local roster = ::World.getRoster(this.getID());
        local seed = this.getFlags().get("RosterSeed");
        if (typeof seed == "integer" && seed != this.getID())
        {
            local locals = ::World.getRoster(seed);
            if (locals != null)
                locals.clear();
        }
        if (roster != null)
            roster.clear();
    };
});

S.Mod.hook("scripts/ui/screens/stronghold/modules/stronghold_screen_buildings_module", function(q)
{
    q.getUIData = @(__original) function( _result )
    {
        S.registerCastleBuildings();
        local result = __original(_result);
        foreach (key, building in ::Stronghold.Buildings)
        {
            if ((key in S.CastleBuildings && !S.castleBuildingAllowed(key))
                || (S.isActive() && (S.CastleForbiddenKeys.find(key) != null || S.CastleForbidden.find(building.ID) != null)))
                delete result[key];
        }
        return result;
    };

    q.addBuilding = @(__original) function( _key )
    {
        if (_key in S.CastleBuildings)
        {
            if (!S.castleBuildingAllowed(_key) || this.getTown().getActiveBuildings().len() >= this.getTown().getMaxBuildings()
                || S.castleHas(this.getTown(), _key)
                || ::World.Assets.getMoney() < S.CastleBuildings[_key].Cost * ::Stronghold.GeneralSettings.PriceMult)
                return;
        }
        else if (S.isActive() && (S.CastleForbiddenKeys.find(_key) != null || S.CastleForbidden.find(::Stronghold.Buildings[_key].ID) != null))
            return;
        return __original(_key);
    };

    q.removeBuilding = @(__original) function( _key )
    {
        if (S.isActive() && _key == "pale_mausoleum" && S.castleTombs(this.getTown()).len() > 0)
            return;
        local result = __original(_key);
        if (S.isActive() && _key == "pale_salt_cellar")
            S.changeReserve(0);
        return result;
    };
});

S.Mod.hook("scripts/ui/screens/stronghold/modules/stronghold_screen_locations_module", function(q)
{
    q.getUIData = @(__original) function( _result )
    {
        local data = __original(_result);
        if (S.isActive() && "Stone_Watchtower" in data)
        {
            data.Stone_Watchtower.Name = "骨塔";
            data.Stone_Watchtower.Description = "塔顶的骨灯整夜不熄，守望的骷髅能看清黑暗里的每一处动静。夜间在古堡势力范围内视野 +50%。围攻时每回合召来一具骷髅。";
        }
        return data;
    };
});

S.Mod.hook("scripts/entity/world/attached_location/stone_watchtower_location", function(q)
{
    q.getName = @(__original) function()
    {
        return S.isActive() && S.isCastle(this.m.Settlement) ? "骨塔" : __original();
    };
});

S.Mod.hook("scripts/entity/world/player_party", function(q)
{
    q.getVisionRadius = @(__original) function()
    {
        local result = __original();
        if (!S.isActive() || ::World.getTime().IsDaytime || !this.isAlive())
            return result;
        foreach (town in S.castles())
            if (S.castleHasTower(town) && town.getTile().getDistanceTo(this.getTile()) <= town.getEffectRadius())
                return result * 1.50;
        return result;
    };
});

S.castleHasTower <- function( _town )
{
    if (!this.isCastle(_town))
        return false;
    local tower = _town.getLocation("attached_location.stone_watchtower");
    return tower != null && tower.isActive();
};
