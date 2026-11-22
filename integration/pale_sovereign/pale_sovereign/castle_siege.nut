local S = ::PaleSovereign;

S.castleSiege <- function()
{
    if (!this.isActive() || !("Contracts" in ::World) || ::World.Contracts == null)
        return null;
    local contract = ::World.Contracts.m.Active;
    return contract != null && ::isKindOf(contract, "stronghold_defeat_assailant_contract")
        && contract.m.Flags.get("PaleCastle") == true ? contract : null;
};

S.castleAssailant <- function( _town )
{
    local result = null;
    local best = 99999;
    local isolated = _town.getTile();
    foreach (faction in ::World.FactionManager.getFactions())
    {
        if (faction == null)
            continue;
        local type = faction.getType();
        local human = type == ::Const.FactionType.NobleHouse || type == ::Const.FactionType.OrientalCityState;
        if (!human && type != ::Const.FactionType.Bandits && type != ::Const.FactionType.OrientalBandits)
            continue;
        foreach (loc in faction.getSettlements())
        {
            if (loc == null || !loc.isAlive() || loc.getID() == _town.getID() || _town.isIsolatedFromLocation(loc))
                continue;
            local distance = isolated.getDistanceTo(loc.getTile());
            local score = distance + (!human && distance <= 18 ? 20 : distance > 18 ? 1000 : 0);
            if (score >= best)
                continue;
            best = score;
            result = { Site = loc, Faction = faction, Human = human };
        }
    }
    return result;
};

S.holyTroop <- function( _script, _fallback )
{
    local troop = clone ::Const.World.Spawn.Troops[_fallback];
    troop.Script = _script;
    return troop;
};

S.spawnCastleAttackers <- function( _contract )
{
    local town = _contract.m.Home;
    local homeTile = town.getTile();
    local source = this.castleAssailant(town);
    local faction = ::Stronghold.getHostileFaction();
    local human = source == null || source.Human;
    local southern = source != null && source.Faction.getType() == ::Const.FactionType.OrientalCityState;
    local origin = source == null ? homeTile : source.Site.getTile();
    local template = southern ? ::Const.World.Spawn.Southern : human ? ::Const.World.Spawn.Noble : ::Const.World.Spawn.BanditRaiders;
    if (source != null)
        faction.copyLooks(source.Faction);
    local wave = 4 - _contract.m.AttacksRemaining;
    local resources = (110 + (_contract.m.TargetLevel - 1) * 65 + (wave - 1) * 20) * _contract.getScaledDifficultyMult();
    local party = faction.spawnEntity(origin, human ? "古堡讨伐军" : "强盗攻城队", false, template, resources);
    if (human)
    {
        ::Const.World.Common.addTroop(party, { Type = this.holyTroop("scripts/entity/tactical/humans/pale_witch_hunter", "MilitiaVeteran") }, false);
        ::Const.World.Common.addTroop(party, { Type = this.holyTroop("scripts/entity/tactical/humans/pale_siege_monk", "StandardBearer") }, false);
    }
    party.setDescription(human ? "猎巫人与随军僧侣带领的讨伐军。" : "企图夺取古堡的强盗。");
    party.setMovementSpeed(70.0);
    party.setAttackableByAI(false);
    party.setVisibleInFogOfWar(true);
    party.setImportant(true);
    party.setDiscovered(true);
    party.getSprite("selection").Visible = true;
    if (source != null)
        party.getSprite("banner").setBrush(source.Site.getBanner());

    _contract.m.Destination = ::WeakTableRef(town);
    _contract.m.Target = ::WeakTableRef(party);
    _contract.m.HasSpawnedUnit = true;
    --_contract.m.AttacksRemaining;
    local controller = party.getController();
    controller.getBehavior(::Const.World.AI.Behavior.ID.Flee).setEnabled(false);
    controller.getBehavior(::Const.World.AI.Behavior.ID.Attack).setEnabled(false);
    local destroy = ::new("scripts/ai/world/orders/stronghold_destroy_order");
    destroy.setTargetTile(homeTile);
    destroy.setTargetID(town.getID());
    destroy.setTime(120.0);
    controller.addOrder(destroy);
    controller.addOrder(::new("scripts/ai/world/orders/despawn_order"));
};

S.castleDefenseLoot = function( _strategic, _count )
{
    local siege = this.castleSiege();
    if (siege == null || _strategic == null || _strategic.CombatID != "Stronghold")
        return false;
    local wave = 3 - siege.m.AttacksRemaining;
    siege.m.Flags.set("PaleWaveCorpses" + wave, _count);
    return true;
};

S.castleFinishSiege <- function( _contract )
{
    local home = _contract.m.Home;
    local flags = home.getFlags();
    if (flags.get("PaleJadeAwarded") != true)
    {
        flags.set("PaleJadeAwarded", true);
        this.pendingItem("misc/pale_jade_item");
    }
    local corpses = 0;
    for (local i = 1; i <= 3; ++i)
        corpses += _contract.m.Flags.getAsInt("PaleWaveCorpses" + i);
    this.changeReserve(corpses);
};

S.castleRetrySiege <- function( _contract )
{
    local home = _contract.m.Home;
    if (_contract.m.Target != null && !_contract.m.Target.isNull())
        _contract.m.Target.die();
    local held = _contract.m.Flags.getAsInt("PaleWavesHeld");
    held = (held / 2).tointeger();
    _contract.m.Flags.set("PaleWavesHeld", held);
    for (local i = held + 1; i <= 3; ++i)
        _contract.m.Flags.remove("PaleWaveCorpses" + i);
    _contract.m.AttacksRemaining = 3 - held;
    home.getFlags().remove("BuildInterrupted");
    home.getFlags().remove("UpgradeInterrupted");
    home.getFlags().remove("UnderAttackBy");
    _contract.m.HasSpawnedUnit = false;
    _contract.m.Target = null;
    _contract.m.TimeOfNextAttack = ::Time.getVirtualTimeF() + ::World.getTime().SecondsPerDay;
    _contract.setState("Running");
};

S.CastleSiegeText <- {
    Start = "第一块墓石刚被抬上地基，消息就已经顺着商道传开了。附近村落的钟声连敲了一整夜，教堂执事在布道台上点名诅咒这座尚未落成的古堡，猎巫人带着随军僧侣在各处集市募兵，连山里的强盗也闻风而动，盘算着趁墙垣还没合拢时抢先下手。骷髅们不知疲倦地搬运石料，行尸用双手把灰浆抹进石缝，盗墓贼则在工地四周挖出浅沟，插满削尖的木桩，又在木桩之间埋好了绊索。夜里工地上从不点火，可干活的声响一刻也没有停过，路过的商队宁可绕上半天的远路。导师站在半截城墙上，望着远处一缕缕升起的炊烟，神情平静，像是在估算一笔早已算清的账。活人总会来的，他们越是恐惧，送上门来的尸骸就越多。等到城墙合拢的那一天，每一个倒在墙下的讨伐者，都会变成这座古堡的第一批守军。\n\n（两天后第一波敌军抵达，此后每隔一天一波，共三波。守住古堡后，讨伐者的遗骸都归战团。）",
    Fail = "来敌趁着守军被拖在外围的空当冲进了工地。等战团赶回来时，脚手架已经烧成一地焦黑的木炭，刚砌好的墙垣被撞开了好几道缺口，堆在一旁的石料滚得满坡都是。几具负责搬运的骷髅被砸成了碎骨，混在瓦砾里，分不清哪块是石头、哪块是肋骨。缺口边还插着一面猎巫人的小旗，旗杆上钉着一张写满经文的羊皮纸，墨迹被烟熏得发黑。盗墓贼们骂骂咧咧地扑灭余火，清点着被抢走的工具和材料，嘴里把讨伐者的祖宗挨个问候了一遍。好在地基深埋在土里，已经完工的厅堂也还屹立不倒，敌人终究没能把它连根拔起。导师在废墟间走了一圈，用法杖拨开一块熏黑的墓碑，吩咐亡灵们天亮之前把缺口重新垒起来。讨伐者明天还会再来，到那时，城墙下只会多出更多的尸骸。\n\n（施工进度退回一半，已完工的建筑仍在。明日继续抵御围攻。）",
    Wave = "[img]gfx/ui/events/event_26.png[/img]最后一名讨伐者倒在墙根下时，天边已经泛起了灰白。城墙下横七竖八地躺满了尸体，碎裂的圣徽和折断的长矛散落在泥泞里，几面绣着圣火纹章的旗帜被踩进血水，再也辨不出原来的颜色。骷髅们沉默地回到缺口处站定，仿佛这场厮杀从未发生过；行尸拖着残缺的躯体，把敌人的尸首一具具拽进古堡的庭院，在墙角码成齐整的一排。盗墓贼们忙着剥下还算完好的锁甲，顺手把死人的钱袋塞进怀里，为一枚镶着假宝石的戒指争了半天。导师俯身察看几具保存完好的尸体，吩咐手下先用盐把它们腌起来，免得放坏了。缺口处的血迹还没干，新砌的石块就已经压了上去。远处的山脊上，又有新的火把一支接一支地亮起。活人还没有死心，下一波讨伐军已经在路上了，而古堡的城墙也还没有合拢。\n\n（守住全部三波后，各波讨伐者的遗骸一并归入防腐尸骸。下一波敌军将在一天后抵达。）",
    Win = "[img]gfx/ui/events/event_24.png[/img]第三波讨伐军溃散时，连随军僧侣都扔下了圣典，提着袍角逃进了雾里。城墙下堆积的尸体已经填平了壕沟，猎巫人的银十字架和强盗的破斧头混在同一摊血泥里，谁也分不清彼此，也没人想去分清。古堡终于合上了最后一道城门，沉重的门闩落下时，整座山头都跟着震了一震。骷髅们在城垛上一字排开，魂火在暮色中连成一线，远远望去，像是在山头上点起了一圈永不熄灭的鬼火。盗墓贼们在庭院里生起了第一堆篝火，难得地撬开了一桶麦酒，为自己还活着干了一杯，又往火里扔了一面缴来的圣火旗。导师独自登上最高的塔楼，俯视着脚下这片刚被鲜血浸透的土地。从今往后，这里就是亡者的据点。讨伐者的尸骸会被腌好入库，而他们留下的恐惧，会替古堡守住每一条通往这里的道路。\n\n（三波讨伐者的遗骸全部归入防腐尸骸。每座古堡第一次守住围攻时，另得 1 枚古代魂玉。）"
};

S.Mod.hook("scripts/contracts/contracts/stronghold_defeat_assailant_contract", function(q)
{
    q.start = @(__original) function()
    {
        local result = __original();
        if (S.isActive() && S.isCastle(this.m.Home))
        {
            this.m.Flags.set("PaleCastle", true);
            this.m.AttacksRemaining = 3;
            this.m.TimeOfNextAttack = ::Time.getVirtualTimeF() + 2 * ::World.getTime().SecondsPerDay;
            this.m.Name = "防守古堡";
        }
        return result;
    };

    q.spawnNewAttackers = @(__original) function()
    {
        if (this.m.Flags.get("PaleCastle") == true)
            S.spawnCastleAttackers(this);
        else
            __original();
    };

    q.createStates = @(__original) function()
    {
        __original();
        foreach (state in this.m.States)
        {
            if (state.ID != "Running")
                continue;
            local update = state.update;
            local won = state.onCombatVictory;
            state.update = function()
            {
                local contract = this.Contract;
                if (contract.m.Flags.get("PaleCastle") != true)
                    return update.call(this);
                if (contract.m.Flags.get("Introduced") != true)
                {
                    contract.setScreen("Under_Construction");
                    ::World.Contracts.m.LastShown = contract;
                    ::World.Contracts.m.IsEventVisible = true;
                    ::World.State.showEventScreen(contract, true, true);
                    return;
                }
                local flags = contract.m.Home.getFlags();
                if (flags.get("BuildInterrupted") == true || flags.get("UpgradeInterrupted") == true)
                {
                    contract.setScreen("FailureInterrupt");
                    ::World.Contracts.showActiveContract();
                    return;
                }
                if (contract.m.HasSpawnedUnit && (contract.m.Target == null || contract.m.Target.isNull()))
                {
                    if (contract.m.Flags.getAsInt("PaleWavesHeld") != 3 - contract.m.AttacksRemaining)
                    {
                        ++contract.m.AttacksRemaining;
                        contract.m.HasSpawnedUnit = false;
                        contract.m.TimeOfNextAttack = ::Time.getVirtualTimeF() + ::World.getTime().SecondsPerDay;
                        return;
                    }
                    contract.m.HasSpawnedUnit = false;
                    contract.setScreen(contract.m.AttacksRemaining == 0 ? "Victory_None_Left" : "Victory_More_Left");
                    ::World.Contracts.showActiveContract();
                    return;
                }
                if (!contract.m.HasSpawnedUnit && contract.m.AttacksRemaining > 0 && ::Time.getVirtualTimeF() >= contract.m.TimeOfNextAttack)
                {
                    contract.setScreen("Enemies_Incoming");
                    ::World.Contracts.showActiveContract();
                }
            };
            state.onCombatVictory = function( _id )
            {
                if (_id == "Stronghold" && this.Contract.m.Flags.get("PaleCastle") == true)
                    this.Contract.m.Flags.set("PaleWavesHeld", 3 - this.Contract.m.AttacksRemaining);
                return won.call(this, _id);
            };
        }
    };

    q.createScreens = @(__original) function()
    {
        __original();
        foreach (screen in this.m.Screens)
        {
            if (screen.ID == "Under_Construction")
            {
                local start = screen.start;
                screen.start = function()
                {
                    start.call(this);
                    if (this.Contract.m.Flags.get("PaleCastle") == true)
                        this.Text = "[img]gfx/ui/events/pale/mortuary.jpg[/img]" + S.CastleSiegeText.Start;
                };
            }
            if (screen.ID == "FailureInterrupt" || screen.ID == "FailureBuild")
            {
                local start = screen.start;
                local apply = screen.Options[0].getResult;
                screen.start = function()
                {
                    if (this.Contract.m.Flags.get("PaleCastle") != true)
                        return start.call(this);
                    this.Text = S.CastleSiegeText.Fail;
                };
                screen.Options[0].getResult = function()
                {
                    if (this.Contract.m.Flags.get("PaleCastle") != true)
                        return apply.call(this);
                    S.castleRetrySiege(this.Contract);
                    return 0;
                };
            }
            if (screen.ID == "Victory_More_Left" || screen.ID == "Victory_None_Left")
            {
                local last = screen.ID == "Victory_None_Left";
                local victoryStart = screen.start;
                screen.start = function()
                {
                    victoryStart.call(this);
                    if (this.Contract.m.Flags.get("PaleCastle") == true)
                        this.Text = last ? S.CastleSiegeText.Win : S.CastleSiegeText.Wave;
                };
                local apply = screen.Options[0].getResult;
                screen.Options[0].getResult = function()
                {
                    if (this.Contract.m.Flags.get("PaleCastle") != true)
                        return apply.call(this);
                    if (last)
                        S.castleFinishSiege(this.Contract);
                    local result = apply.call(this);
                    if (!last)
                        this.Contract.m.TimeOfNextAttack = ::Time.getVirtualTimeF() + ::World.getTime().SecondsPerDay;
                    return result;
                };
            }
        }
    };
});

S.spawnCastleSkeleton <- function( _actor )
{
    if (this.Battle == null || this.Battle.BoneRound == ::Time.getRound() || !_actor.isPlayerControlled() || !_actor.isPlacedOnMap())
        return;
    local strategic = ::Tactical.State.getStrategicProperties();
    local siege = this.castleSiege();
    if (siege == null || strategic == null || strategic.CombatID != "Stronghold" || !this.castleHasTower(siege.m.Home))
        return;
    local tile = ::BGP.Champion.findSpawnTile(_actor.getTile());
    if (tile == null)
        return;
    this.Battle.BoneRound = ::Time.getRound();
    local skeleton = ::Tactical.spawnEntity("scripts/entity/tactical/enemies/skeleton_light", tile.Coords.X, tile.Coords.Y);
    if (skeleton == null)
        return;
    skeleton.setFaction(::Const.Faction.PlayerAnimals);
    skeleton.getFlags().set("PaleRaised", true);
    this.addBattleBoons(skeleton);
    skeleton.riseFromGround();
};

S.Mod.hook("scripts/entity/tactical/actor", function(q)
{
    q.onTurnStart = @(__original) function()
    {
        __original();
        if (S.Battle != null && this.isPlayerControlled() && S.Battle.BoneRound != ::Time.getRound())
        {
            local combat = ::Tactical.State.getStrategicProperties();
            if (combat != null && combat.CombatID == "Stronghold")
                S.deferBattleSpawn(this, S.spawnCastleSkeleton);
        }
    };
});
