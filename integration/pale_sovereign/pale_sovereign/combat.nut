local S = ::PaleSovereign;

S.beginBattle <- function( _night )
{
    this.Battle = { CompanyContact = false, Mark = null, Prey = null, QueuedShots = {}, Uncollected = 0, Decayed = {}, Night = _night, SiegeFight = false, Death = null, Champions = 0, UndeadDeployed = 0, AncientCleared = false, Won = false, BloodFeast = false, FollowerOpening = false, BoneRound = -1, Governor = null, DefenseDead = 0, Soulbound = [], SoulUsed = false, HumanKills = 0, UndeadCampLooted = false, RaisedHarvest = 0 };
};

S.area <- function( _center )
{
    local tiles = [_center];
    for (local d = 0; d < 6; ++d)
        if (_center.hasNextTile(d))
            tiles.push(_center.getNextTile(d));
    return tiles;
};

S.isEnemy <- function( _user, _tile )
{
    if (!_tile.IsOccupiedByActor)
        return false;
    local actor = _tile.getEntity();
    return actor != null && actor.isAlive() && !actor.isDying() && !actor.isAlliedWith(_user);
};

S.directDamage <- function( _user, _skill, _target, _amount )
{
    local hit = clone ::Const.Tactical.HitInfo;
    hit.DamageRegular = ::Math.floor(_amount);
    if (hit.DamageRegular <= 0)
        return;
    hit.DamageArmor = 0;
    hit.DamageDirect = 1.0;
    hit.DamageFatigue = 0;
    hit.BodyPart = ::Const.BodyPart.Body;
    hit.BodyDamageMult = 1.0;
    hit.Injuries = null;
    hit.InjuryThresholdMult = 0.0;
    hit.FatalityChanceMult = 0.0;
    hit.Tile = _target.getTile();
    _target.onDamageReceived(_user, _skill, hit);
};

S.markPrey <- function( _target )
{
    if (this.Battle == null)
        return;
    local former = this.Battle.Prey;
    if (former != null && !::MSU.isNull(former) && former.isAlive() && former.getID() != _target.getID())
        former.getSkills().removeByID("effects.pale_prey");
    local effect = _target.getSkills().getSkillByID("effects.pale_prey");
    if (effect == null)
    {
        effect = ::new(this.SkillDir + "effects/pale_prey_effect");
        _target.getSkills().add(effect);
    }
    effect.m.Turns = 2;
    this.Battle.Prey = ::MSU.asWeakTableRef(_target);
};

S.isChampionActor <- function( _actor )
{
    local chief = this.chief();
    if (chief == null)
        return false;
    local master = ::BGP.Necro.getMaster(_actor);
    if (master == null || master.getID() != chief.getID())
        return false;
    if (this.isDeployed(this.mainPet(), _actor))
        return true;
    return ::BGP.Champion.isGuard(_actor);
};

S.placeShot <- function( _tile )
{
    if (this.Battle == null)
        return;
    if (_tile.IsCorpseSpawned)
    {
        local key = _tile.ID;
        this.Battle.QueuedShots[key] <- key in this.Battle.QueuedShots ? this.Battle.QueuedShots[key] + 1 : 1;
        return;
    }

    local corpse = clone ::Const.Corpse;
    corpse.Type = "scripts/entity/tactical/enemies/zombie";
    corpse.Name = "防腐行尸";
    corpse.CorpseName = "防腐尸骸";
    corpse.Tile = _tile;
    corpse.Faction = ::Const.Faction.PlayerAnimals;
    corpse.Hitpoints = 1.0;
    corpse.IsResurrectable = true;
    corpse.Items = ::new("scripts/items/item_container");
    corpse.PaleShot <- true;
    corpse.BGP_Necro <- { Script = corpse.Type, IsHuman = true, MaxHP = ::Const.Tactical.Actor.Zombie.Hitpoints, Armor = 0 };
    local decal = _tile.spawnDetail("pale_shroud_dead", ::Const.Tactical.DetailFlag.Corpse, false, false, ::Const.Combat.HumanCorpseOffset);
    decal.Scale = 0.9;
    _tile.Properties.set("Corpse", corpse);
    ::Tactical.Entities.addCorpse(_tile);
};

S.flushShot <- function( _tile )
{
    if (this.Battle == null || _tile.IsCorpseSpawned || !(_tile.ID in this.Battle.QueuedShots))
        return;
    if (--this.Battle.QueuedShots[_tile.ID] == 0)
        delete this.Battle.QueuedShots[_tile.ID];
    this.placeShot(_tile);
};

S.recordCorpse <- function( _corpse )
{
    if (_corpse == null || "PaleShot" in _corpse || this.Battle == null || this.Battle.Death == null)
        return;
    local death = this.Battle.Death;
    if (!death.Eligible || death.Fatality == ::Const.FatalityType.Unconscious)
        return;
    local info = death.Info;
    ::BGP.Necro.annotate(_corpse, info);
    local script = info.Script;
    _corpse.PaleNative <- info.IsHuman || (script in ::BGP.Necro.RaiseMap && ::BGP.Necro.WrapperCategory[::BGP.Necro.RaiseMap[script]] == "undead");
    local mark = this.Battle.Mark;
    if (mark != null && mark.Target == death.ID && _corpse.IsHeadAttached
        && death.Fatality != ::Const.FatalityType.Decapitated)
        _corpse.PaleSoul <- mark.Target;
};

// 地图上所有有尸体的格子
S.battleCorpseTiles <- function()
{
    local ret = [];
    local size = null;
    try { size = ::Tactical.getMapSize(); } catch (e) { size = null; }
    if (size == null)
    {
        try { return clone ::Tactical.Entities.m.Corpses; } catch (e) { return ret; }
    }
    for (local x = 0; x < size.X; ++x)
        for (local y = 0; y < size.Y; ++y)
        {
            local tile = null;
            try { tile = ::Tactical.getTileSquare(x, y); } catch (e) { tile = null; }
            if (tile != null && tile.IsCorpseSpawned && tile.Properties.has("Corpse"))
                ret.push(tile);
        }
    return ret;
};

// 不能封存的原因（"Faction" / "Kind" / "Shot"），能封存返回 null
// 1.6.15：不再排除“看起来会自己爬起来”的尸体。那个判断只看 IsResurrectable / IsConsumable 两个标记，
// 原版有的人类（如野蛮人）尸体本来就是这样标的，结果整场的遗骸都被排除；战斗结束后也不会再有尸体爬起
S.harvestReject <- function( _corpse )
{
    if ("PaleShot" in _corpse)
        return "Shot";
    local chief = this.chief();
    local faction = "Faction" in _corpse ? _corpse.Faction : ::Const.Corpse.Faction;
    if (faction == ::Const.Faction.Player || faction == ::Const.Faction.PlayerAnimals
        || (chief != null && chief.getAlliedFactions().find(faction) != null))
        return "Faction";
    local info = ::BGP.Necro.getInfo(_corpse);
    local native = false;
    if ("PaleNative" in _corpse)
        native = _corpse.PaleNative;
    else if (info != null)
        native = info.IsHuman || (info.Script in ::BGP.Necro.RaiseMap
            && ::BGP.Necro.WrapperCategory[::BGP.Necro.RaiseMap[info.Script]] == "undead");
    else
    {
        // 没有生前记录：按原版人类尸体的规则（能复活、类型不是兽人）
        try { native = (_corpse.IsResurrectable || ::BGP.Necro.isPendingResurrection(_corpse)) && _corpse.Type != null && _corpse.Type.find("orc") == null; }
        catch (e) { native = false; }
    }
    if (!native)
        return "Kind";
    return null;
};

S.onVictory <- function( _loot )
{
    if (this.Battle == null || this.Battle.Won || this.chief() == null)
        return;
    local strategic = ::Tactical.State.getStrategicProperties();
    if (strategic != null && strategic.IsArenaMode)
        return;
    this.Battle.Won = true;
    this.captureSoulbound();
    this.set("Victories", this.get("Victories") + 1);
    if (this.Battle.Night)
        this.set("NightWins", this.get("NightWins") + 1);
    if (this.Battle.UndeadDeployed >= 4)
        this.set("UndeadSquadWins", this.get("UndeadSquadWins") + 1);
    if (strategic != null && strategic.CombatID == "PaleLantern" && this.oath() == this.Oath.Champion && ::Math.rand(1, 100) <= 50)
    {
        ::World.Assets.addArmorParts(8);
        ::Tactical.EventLog.log("从巡逻队的遗物里搜刮出 8 点工具。");
    }
    if (this.Battle.Champions > 0 && this.oath() != this.Oath.None && ::Math.rand(1, 100) <= 50 && this.addMaterials("jade", 1))
        ::Tactical.EventLog.log("冠军的遗骸里滚出一枚冰冷的古代魂玉。");

    // 1.6.15：逐格扫描整张地图（不再依赖 Tactical.Entities.m.Corpses 和击杀瞬间的记录），
    // 合格与否按尸体自身的阵营和生前种类在结算时判断
    local corpses = {};
    local soulFound = false;
    local mark = this.Battle.Mark;
    local stats = { Seen = 0, Faction = 0, Kind = 0, Shot = 0 };
    foreach (tile in this.battleCorpseTiles())
    {
        local corpse = ::BGP.Necro.getCorpse(tile);
        if (corpse == null || typeof corpse != "table" || ::BGP.Necro.isGuardCorpse(corpse))
            continue;
        ++stats.Seen;
        local reason = this.harvestReject(corpse);
        if (reason == null)
            corpses[tile.ID] <- true;
        else
            ++stats[reason];
        if (mark != null && "PaleSoul" in corpse && corpse.PaleSoul == mark.Target && corpse.IsHeadAttached)
            soulFound = true;
    }
    if (!this.castleDefenseLoot(strategic, this.Battle.DefenseDead) && this.oath() != this.Oath.None)
    {
        // 复活技能拉起来的敌方遗骸照样算一具（复活时记下，见 hooks.nut）
        local total = corpses.len() + this.Battle.RaisedHarvest;
        local before = this.get("Reserve");
        local embalmer = this.followerRank("embalmer") > 0;
        this.changeReserve(embalmer ? (total * 2 / 3).tointeger() : (total / 2).tointeger());
        local gathered = this.get("Reserve") - before;
        this.Battle.Uncollected = ::Math.max(0, corpses.len() - (embalmer ? ::Math.ceil(gathered * 1.5) : gathered * 2));
        this.set("LastHarvest", gathered);
        this.set("LastCorpseCount", total);
        this.set("HarvestArtStep", (this.get("HarvestArtStep") + 1) % 4);
        this.set("HarvestNotice", 1);
        ::Tactical.EventLog.log("清点合格遗骸 " + total + " 具，封存防腐尸骸：" + before + " → " + this.get("Reserve") + "。");
        ::logInfo("[PaleSovereign] 遗骸采集：地上尸体 " + stats.Seen + "，合格 " + corpses.len() + "，复活计入 " + this.Battle.RaisedHarvest
            + "；排除 友方 " + stats.Faction + " / 种类 " + stats.Kind + " / 尸弹 " + stats.Shot);
    }
    local pet = this.mainPet();
    local chief = this.chief();
    local together = this.isDeployed(pet) && chief.isAlive() && chief.isPlacedOnMap();
    if (together && pet.m.PaleID == this.get("StarterID"))
    {
        this.set("GuardWins", this.get("GuardWins") + 1);
        if (this.get("BannerTrials") > 0)
            this.set("BannerSuccess", this.get("BannerSuccess") + 1);
    }
    if (this.get("BannerTrials") > 0)
    {
        this.set("BannerTrials", this.get("BannerTrials") - 1);
        if (this.get("BannerTrials") == 0 && this.get("BannerSuccess") >= 2)
            this.set("BannerReward", 1);
    }
    if (soulFound && pet != null && pet.m.PaleID == mark.PetID)
        this.saveSoul(mark);
    this.followerVictory();
    this.followerLoot(_loot);
};

local undeadSpriteVariants = [
    { Layer = "head", Flag = "PaleHeadVariant", Count = 12 },
    { Layer = "body", Flag = "PaleBodyVariant", Count = 6 }
];

S.applyUndeadVariants <- function( _actor, _model )
{
    local flags = _actor.getFlags();
    foreach (variant in undeadSpriteVariants)
    {
        local index = this.getOrRollUndeadIndex(flags, variant.Flag, variant.Count);
        local name = format("%s_%s_%02d", _model, variant.Layer, index + 1);
        if (variant.Layer == "body")
        {
            local detail = this.getOrRollUndeadIndex(flags, "PaleDetailVariant", 6);
            local dressed = format("%s_detail_%02d", name, detail + 1);
            if (::doesBrushExist(dressed))
                name = dressed;
        }
        if (::doesBrushExist(name))
            _actor.getSprite(variant.Layer).setBrush(name);
    }
    local appearance = _actor.getItems().getAppearance();
    appearance.HideHair = true;
    appearance.HideBeard = true;
};

S.applyUndeadLook <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    if (background == null || !_bro.hasSprite("body") || !_bro.hasSprite("head"))
        return;
    local skeleton = background.m.PaleSkeleton;
    local key = background.m.PaleBranch;
    local look = null;
    try { look = background.m.PaleLook; } catch (e) { look = null; }
    if (typeof look == "string" && look in this.TierBranches)
        key = look;
    else
        look = null;
    local branch = look != null || background.m.PaleTier > 1 ? this.TierBranches[key] : null;
    local body = _bro.getSprite("body");
    local head = _bro.getSprite("head");
    if (skeleton)
    {
        body.setBrush("bust_skeleton_body_01");
        head.setBrush("bust_skeleton_head");
        _bro.getItems().getAppearance().Corpse = "bust_skeleton_body_01_dead";
    }
    else
    {
        head.setBrush("bgpu_bust_head_01");
    }
    if (background.m.PaleRanged)
    {
        body.setBrush("pale_skeleton_archer_body");
        head.setBrush("pale_skeleton_archer_head");
        this.applyUndeadVariants(_bro, "pale_skeleton_archer");
    }
    else if (branch != null)
    {
        local stem = "pale_" + (key in this.TierBrushStems ? this.TierBrushStems[key] : key);
        if (look != null)
            stem = "pale_sb_" + background.m.PaleSoulClass;
        body.setBrush(stem + "_body");
        head.setBrush(stem + "_head");
    }
    else if (background.getID() == "background.pale_skeleton" || background.getID() == "background.pale_zombie")
    {
        this.applyUndeadVariants(_bro, skeleton ? "pale_summon_skeleton_0" : "pale_summon_zombie_0");
    }
    body.Color = ::createColor(branch != null || skeleton ? "#ffffff" : "#b4c4a5");
    head.Color = body.Color;
    if (branch != null && branch.Scale != 1.0)
    {
        foreach (layer in ["body", "head", "armor", "helmet", "armor_upgrade", "body_blood", "head_blood"])
            if (_bro.hasSprite(layer))
                _bro.getSprite(layer).Scale = branch.Scale;
    }
    if (background.m.PaleBranch == "skeleton_king" && _bro.hasSprite("helmet")
        && _bro.getItems().getItemAtSlot(::Const.ItemSlot.Head) == null)
    {
        local crown = _bro.getSprite("helmet");
        crown.setBrush("pale_skeleton_king_crown");
        crown.Visible = true;
    }
    foreach (layer in ["hair", "beard", "beard_top", "tattoo_body", "tattoo_head", "injury", "injury_body"])
    {
        if (_bro.hasSprite(layer))
            _bro.getSprite(layer).Visible = false;
    }
    if (skeleton)
    {
        foreach (layer in ["body_blood", "head_blood"])
            if (_bro.hasSprite(layer))
                _bro.getSprite(layer).Visible = false;
    }
    _bro.setDirty(true);
};

S.applySummonedLook <- function( _actor, _stem )
{
    _actor.getSprite("body").setBrush(_stem + "_body");
    _actor.getSprite("head").setBrush(_stem + "_head");
    this.applyUndeadVariants(_actor, _stem);
    foreach (layer in ["body", "head"])
        _actor.getSprite(layer).Color = ::createColor("#ffffff");
    foreach (layer in ["hair", "beard", "beard_top", "injury", "injury_body", "body_blood_always"])
        if (_actor.hasSprite(layer))
            _actor.getSprite(layer).Visible = false;
    _actor.setDirty(true);
};
