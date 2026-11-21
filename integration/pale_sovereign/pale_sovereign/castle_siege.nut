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
                        this.Text = "[img]gfx/ui/events/pale/mortuary.jpg[/img]古堡开始施工。两天后将有第一波敌军抵达，往后每隔一天一波，共三波。守住古堡后，讨伐者的遗骸都归战团。";
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
                    this.Text = "来敌毁坏了未完工的工事。施工进度退回一半，已完工建筑仍在。明日继续抵御围攻。";
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
