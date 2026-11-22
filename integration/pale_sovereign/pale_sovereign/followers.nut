local S = ::PaleSovereign;

S.FollowerData <- {
    embalmer = {
        Name = "防腐师", Archetype = "Steward", Image = "ui/campfire/pale_embalmer",
        Description = "他身上的盐味和松脂味怎么也洗不掉。再破烂的尸体到了他手里，也能腌得整整齐齐，在车厢里码得严丝合缝。",
        Effects = ["每 3 具合格遗骸封存 2 点尸骸", "工具容量 +50、弹药容量 +100、医疗用品容量 +100，修理效率 +50%，常驻亡灵每日修补量提高至 50%", "常驻亡灵升阶后从 3 级起步（7 级升阶为 3 级），升阶消耗的防腐尸骸 −2"]
    },
    gravekeeper = {
        Name = "掘墓人首领", Archetype = "Ranger", Image = "ui/campfire/pale_gravekeeper",
        Description = "他能从野草的颜色和地面的塌陷看出帝国旧墓的位置，也知道哪道墓门还没被人撬开过。",
        Effects = ["每 5 天标出一处未勘察的古代遗址；白天大地图移动速度 +15%，夜间 +50%", "勘察时魂玉概率和锁链概率各 +20 个百分点", "清剿古代遗址额外获得古代武器或古代金币"]
    },
    wight_captain = {
        Name = "尸妖王侍卫长", Archetype = "Officer", Image = "ui/campfire/pale_wight_captain",
        Description = "一名从古帝国站岗至今的沉默军官。它早已不记得自己的名字，却还记得怎样操练一名冠军。",
        Effects = ["冠军经验 +50%", "缚魂锁链生命门槛 +5 个百分点；亡者之城和古堡兵营的待选亡灵从 8 名增加到 16 名；战团所有人（活人和亡灵）与所有宠物（驯服的野兽、死灵宠物、冠军）获得的经验 +20%","冠军在前 5 回合获得 +20 近战技能；战团每击杀一名敌方冠军获得 200 克朗"]
    },
    banshee = {
        Name = "女妖", Archetype = "Agent", Image = "ui/campfire/pale_banshee",
        Description = "只有守夜的人听见过她的歌声。第二天早上，他们谁也不肯复述那首歌。",
        Effects = ["战斗中所有非亡灵敌人决心 −5（夜战时 −10）", "夜间大地图视野 +50%；在森林与沼泽中不会被伏击", "首回合随机一名敌人做一次 −50 的士气检定；贵族、南方城邦和民兵队伍在大地图上发现战团的距离缩短 30%"]
    },
    blood_steward = {
        Name = "血宴管家", Archetype = "Healer", Image = "ui/campfire/pale_blood_steward",
        Description = "一个举止得体的吸血鬼，深谙如何让活人的血保持新鲜。战团接受了这个有些滑稽的安排，只是没人愿意和他单独吃饭。",
        Effects = ["活人生命恢复速度 +50%；活人被击倒时必定幸存，且不会留下永久伤势", "大地图移动速度 +20%；战斗胜利后，所有未满血的常驻亡灵恢复 20% 最大生命", "每战导师首次击杀恢复 20 生命和 10 疲劳；击败活人部队后额外掠夺 30% 金币，并有 30% 几率多得一件珠宝或古董；在酒馆付钱打听消息时，必定多给一条古代遗址的精确线索"]
    }
};

S.followerRank = function( _key )
{
    if (!this.isActive() || !("Retinue" in ::World) || ::World.Retinue == null)
        return 0;
    local index = ::PandorasHobby.Follower.Archetype[this.FollowerData[_key].Archetype];
    local follower = ::World.Retinue.PH_getFollowerAtIndex(index);
    return follower != null && follower.getID() == "follower.pale_" + _key ? follower.getPaleRank() : 0;
};

S.followerVictory = function()
{
    if (this.followerRank("blood_steward") >= 2)
        foreach (bro in this.undead())
            if (bro.getHitpoints() < bro.getHitpointsMax())
                bro.setHitpoints(::Math.minf(bro.getHitpointsMax(), bro.getHitpoints() + bro.getHitpointsMax() * 0.20));
    foreach (key, data in this.FollowerData)
    {
        if (this.followerRank(key) > 0)
            ::World.Retinue.PH_getFollowerAtIndex(::PandorasHobby.Follower.Archetype[data.Archetype]).earnVictoryXP();
    }
};

S.followerWorldTick = function()
{
    local age = this.worldHours();
    if (this.followerRank("gravekeeper") > 0 && age >= this.get("NextRangerLead"))
    {
        this.revealAncient(false, true);
        this.set("NextRangerLead", age + 5 * 24);
    }
};

// 尸妖王侍卫长 3 级：战团击杀敌方冠军得 200 克朗
S.followerChampionKill = function( _killer )
{
    local chief = this.chief();
    if (this.followerRank("wight_captain") < 3 || _killer == null || ::MSU.isNull(_killer) || chief == null || !_killer.isAlliedWith(chief))
        return;
    ::World.Assets.addMoney(200);
    ::Tactical.EventLog.log("尸妖王侍卫长清点了冠军的遗物，战团获得 200 克朗。");
};

// 随从对大地图资产的加成（随从系统重算资产时调用）
S.followerAssets = function( _key, _rank )
{
    if (_key == "embalmer" && _rank >= 2)
    {
        ::World.Assets.m.ArmorPartsMaxAdditional += 50;
        ::World.Assets.m.AmmoMaxAdditional += 100;
        ::World.Assets.m.MedicineMaxAdditional += 100;
        ::World.Assets.m.RepairSpeedMult *= 1.5;
    }
};

// 掘墓人首领 1 级：白天大地图移动速度 +15%，夜间 +50%
S.followerMovementMult = function( _key )
{
    if (!this.isActive())
        return 1.0;
    if (_key == "gravekeeper")
        return ::World.getTime().IsDaytime ? 1.15 : 1.5;
    if (_key == "blood_steward" && this.followerRank("blood_steward") >= 2)
        return 1.2;
    return 1.0;
};

// 血宴管家 3 级：击败活人部队后额外掠夺 30% 金币，30% 几率多一件珠宝或古董
S.ValuableLoot <- ["loot/gemstones_item", "loot/golden_chalice_item", "loot/jeweled_crown_item", "loot/ancient_gold_coins_item",
    "loot/signet_ring_item", "loot/silver_bowl_item", "loot/silverware_item", "loot/ornate_tome_item"];
S.followerLoot = function( _loot )
{
    if (this.followerRank("blood_steward") < 3 || this.Battle == null || this.Battle.HumanKills == 0)
        return;
    local coins = 0;
    try
    {
        foreach (item in _loot.getItems())
            if (item != null && item.getID() == "supplies.money")
                coins += item.getAmount();
    }
    catch (e)
    {
        ::logError("[PaleSovereign] 血宴管家清点金币: " + e);
    }
    local bonus = ::Math.floor(coins * 0.30);
    if (bonus > 0)
    {
        ::World.Assets.addMoney(bonus);
        ::Tactical.EventLog.log("血宴管家从死者的钱袋里又刮出了 " + bonus + " 克朗。");
    }
    if (::Math.rand(1, 100) > 30)
        return;
    local pool = clone this.ValuableLoot;
    while (pool.len() > 0)
    {
        local path = pool.remove(::Math.rand(0, pool.len() - 1));
        local item = null;
        try { item = ::new("scripts/items/" + path); } catch (e) { item = null; }
        if (item == null)
            continue;
        local added = false;
        try { _loot.add(item); added = true; } catch (e) { added = false; }
        if (!added)
            ::World.Assets.getStash().add(item);
        ::Tactical.EventLog.log("血宴管家在尸体的贴身衣袋里翻出了一件" + item.getName() + "。");
        return;
    }
};

// 血宴管家 3 级：在酒馆付钱打听消息时，必定多给一条古代遗址的精确线索
S.Mod.hook("scripts/entity/world/settlements/buildings/tavern_building", function(q)
{
    q.getRumor = @(__original) function( _isPaidFor = false )
    {
        local ret = __original(_isPaidFor);
        if (!_isPaidFor || !S.isActive() || S.followerRank("blood_steward") < 3 || ::World.State.getPlayer() == null)
            return ret;
        local lead = S.revealAncient(true, true);
        if (lead == null)
            lead = S.revealAncient(true);
        if (lead != null)
            ret = (ret == null ? "" : ret + "\n\n") + "血宴管家端着酒杯回到桌边，低声补了一句：“" + lead + "那边，有人还守着没被撬开的墓。”（已在地图上标出）";
        return ret;
    };
});

// 女妖 2 级：在森林与沼泽中不会被伏击
S.AmbushSafeTerrain <- [
    ::Const.World.TerrainType.Forest, ::Const.World.TerrainType.SnowyForest, ::Const.World.TerrainType.LeaveForest,
    ::Const.World.TerrainType.AutumnForest, ::Const.World.TerrainType.Swamp
];
S.isAmbushSafe = function()
{
    if (!this.isActive() || this.followerRank("banshee") < 2 || ::World.State.getPlayer() == null)
        return false;
    return this.AmbushSafeTerrain.find(::World.State.getPlayer().getTile().Type) != null;
};

// 女妖 3 级：这些人类势力的队伍发现战团的距离缩短 30%
S.WaryFactionTypes <- [::Const.FactionType.NobleHouse, ::Const.FactionType.OrientalCityState, ::Const.FactionType.Settlement];
S.isWaryHumanParty = function( _party )
{
    if (!this.isActive() || this.followerRank("banshee") < 3 || _party.getFaction() == 0)
        return false;
    local faction = ::World.FactionManager.getFaction(_party.getFaction());
    if (faction == null || this.WaryFactionTypes.find(faction.getType()) == null)
        return false;
    return !faction.isAlliedWithPlayer();
};

S.followerOnKill = function( _killer )
{
    if (_killer == null || ::MSU.isNull(_killer) || !this.isChief(_killer) || this.Battle.BloodFeast || this.followerRank("blood_steward") < 3)
        return;
    this.Battle.BloodFeast = true;
    _killer.setHitpoints(::Math.min(_killer.getHitpointsMax(), _killer.getHitpoints() + 20));
    _killer.setFatigue(::Math.max(0, _killer.getFatigue() - 10));
    ::Tactical.EventLog.log("血宴管家的秘法生效，导师从首个击杀中恢复了生命和疲劳。");
};

S.followerBattleOpening <- function( _actor )
{
    if (!this.Battle.FollowerOpening && _actor.isPlayerControlled() && _actor.isPlacedOnMap())
    {
        this.Battle.FollowerOpening = true;
        local enemies = [];
        foreach (faction in ::Tactical.Entities.getAllInstances())
            foreach (enemy in faction)
                if (enemy.isAlive() && !enemy.isDying() && enemy.isPlacedOnMap() && !enemy.isAlliedWith(_actor))
                    enemies.push(enemy);
        if (this.followerRank("banshee") >= 3 && enemies.len() > 0)
            enemies[::Math.rand(0, enemies.len() - 1)].checkMorale(-1, -50);
    }
};

S.Mod.hook("scripts/retinue/retinue_manager", function(q)
{
    q.getFollowersForUI = @(__original) function( _slot = 99 )
    {
        local result = __original(_slot);
        if (!S.isActive())
            return result;
        return result.filter(@(_, f) ["follower.ph_healer_00", "follower.ph_healer_11"].find(f.ID) == null);
    };

    q.PH_getTrainersForUI = @(__original) function( _slot = 99 )
    {
        local follower = this.PH_getFollowerAtIndex(_slot);
        return follower != null && follower.getID().find("follower.pale_") == 0 ? [] : __original(_slot);
    };
});

// 女妖 2 级：在森林与沼泽中遭遇敌人时，战前照常显示敌情、允许撤退和选阵型
S.Mod.hook("scripts/states/world_state", function(q)
{
    q.showCombatDialog = @(__original) function( _isPlayerInitiated = true, _isCombatantsVisible = true, _allowFormationPicking = true, _properties = null, _pos = null )
    {
        if (!_isPlayerInitiated && S.isAmbushSafe())
        {
            _isCombatantsVisible = true;
            _allowFormationPicking = true;
        }
        return __original(_isPlayerInitiated, _isCombatantsVisible, _allowFormationPicking, _properties, _pos);
    };
});

// 女妖 3 级：贵族、南方城邦和民兵的队伍视野 −30%，更晚发现战团
S.Mod.hook("scripts/entity/world/party", function(q)
{
    q.getVisionRadius = @(__original) function()
    {
        local radius = __original();
        return S.isWaryHumanParty(this) ? radius * 0.7 : radius;
    };
});

// 血宴管家 1 级：活人被击倒时必定幸存（不论致命方式），且不留下永久伤势
S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.isReallyKilled = @(__original) function( _fatalityType )
    {
        if (S.Battle == null || S.followerRank("blood_steward") < 1 || S.isUndead(this) || this.getFlags().has("undead")
            || ::Tactical.State.isScenarioMode())
            return __original(_fatalityType);
        local properties = this.m.CurrentProperties;
        local chance = properties.SurviveWithInjuryChanceMult;
        local before = {};
        foreach (injury in this.getSkills().query(::Const.SkillType.PermanentInjury))
            before[injury.getID()] <- true;
        properties.SurviveWithInjuryChanceMult = 1000.0;
        local result = true;
        try { result = __original(::Const.FatalityType.None); }
        catch (e)
        {
            properties.SurviveWithInjuryChanceMult = chance;
            throw e;
        }
        properties.SurviveWithInjuryChanceMult = chance;
        if (!result)
        {
            foreach (injury in this.getSkills().query(::Const.SkillType.PermanentInjury))
                if (!(injury.getID() in before))
                    this.getSkills().remove(injury);
            ::Tactical.EventLog.log("血宴管家的秘药吊住了 " + ::Const.UI.getColorizedEntityName(this) + " 的最后一口气。");
        }
        return result;
    };
});

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onRoundStart = @(__original) function()
    {
        __original();
        if (S.Battle == null)
            return;
        local chief = S.chief();
        if (S.followerRank("banshee") >= 1 && chief != null && this.isAlive() && !this.isAlliedWith(chief)
            && !this.getFlags().has("undead") && !this.getSkills().hasSkill("effects.pale_banshee"))
        {
            local wail = ::new(S.SkillDir + "effects/pale_banshee_effect");
            wail.m.Penalty = S.Battle.Night ? 10 : 5;
            this.getSkills().add(wail);
        }
        if (::Time.getRound() == 1)
            S.followerBattleOpening(this);
    };
});

S.Mod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
    if (!("addXP" in p))
        return;
    local original = p.addXP;
    p.addXP = function( _xp )
    {
        // 1 级：冠军 +50%；2 级：所有宠物（驯服的野兽、死灵宠物、冠军）再 +20%，与冠军加成相加（冠军共 +70%）
        local rank = S.isActive() ? S.followerRank("wight_captain") : 0;
        if (rank >= 1 && _xp > 0)
        {
            local mult = rank >= 2 ? 1.20 : 1.0;
            if (S.isCoffin(this) && (S.mainPet() == this || this.m.PaleID > 0))
                mult += 0.50;
            if (mult != 1.0)
                _xp = ::Math.round(_xp * mult);
        }
        return original.call(this, _xp);
    };
});

// 尸妖王侍卫长 2 级：战团所有人（活人和常驻亡灵）获得的经验 +20%，宠物在上面的饰品钩子里处理（只放大按常规倍率结算的经验，古币灌注、兵营训练这类直接补满的不算）
S.Mod.hook("scripts/entity/tactical/player", function(q)
{
    q.addXP = @(__original) function( _xp, _scale = true )
    {
        if (_scale && _xp > 0 && S.isActive() && S.followerRank("wight_captain") >= 2)
            _xp = _xp * 1.20;
        return __original(_xp, _scale);
    };
});
