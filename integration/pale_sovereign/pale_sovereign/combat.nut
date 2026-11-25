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

S.markPrey <- function( _target, _turns = 2 )
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
    effect.m.Turns = _turns;
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

// 不能封存的原因（只剩 "Shot"），能封存返回 null
// 1.6.15：不再排除“看起来会自己爬起来”的尸体。那个判断只看 IsResurrectable / IsConsumable 两个标记，
// 原版有的人类（如野蛮人）尸体本来就是这样标的，结果整场的遗骸都被排除；战斗结束后也不会再有尸体爬起
S.harvestReject <- function( _corpse )
{
    // 1.6.31：战场上所有死亡单位都计入（含我方与友军、野兽、兽人等），只排除被尸弹打烂的
    if ("PaleShot" in _corpse)
        return "Shot";
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
    // 1.7.0 击杀敌方冠军（带冠军标记）：每击杀一名 80% 得 1 枚魂玉，两条路线通用
    local jadeDrops = 0;
    if (this.oath() != this.Oath.None)
        for (local i = 0; i < this.Battle.Champions; ++i)
            if (::Math.rand(1, 100) <= 80 && this.addMaterials("jade", 1))
                ++jadeDrops;
    if (jadeDrops > 0)
        ::Tactical.EventLog.log("冠军的遗骸里滚出 " + jadeDrops + " 枚冰冷的古代魂玉。");

    // 1.6.15：逐格扫描整张地图（不再依赖 Tactical.Entities.m.Corpses 和击杀瞬间的记录），
    // 合格与否按尸体自身的阵营和生前种类在结算时判断
    local corpses = {};
    local soulFound = false;
    local mark = this.Battle.Mark;
    local stats = { Seen = 0, Faction = 0, Kind = 0, Shot = 0 };
    // 1.6.33 常驻亡灵事件用：上一场胜仗的时间，以及敌方里有没有人类、兽人或亡灵
    this.set("LastVictoryHour", this.worldHours());
    local humanoid = this.Battle.HumanKills > 0;
    local eliteUndead = false;
    foreach (tile in this.battleCorpseTiles())
    {
        local corpse = ::BGP.Necro.getCorpse(tile);
        if (corpse == null || typeof corpse != "table" || ::BGP.Necro.isGuardCorpse(corpse))
            continue;
        ++stats.Seen;
        if (!humanoid && ("PaleNative" in corpse && corpse.PaleNative || ("Type" in corpse && typeof corpse.Type == "string" && corpse.Type.find("orc") != null)))
            humanoid = true;
        local reason = this.harvestReject(corpse);
        if (reason == null)
        {
            corpses[tile.ID] <- true;
            if (!eliteUndead && this.isEliteUndeadCorpse(corpse))
                eliteUndead = true;
        }
        else
            ++stats[reason];
        if (mark != null && "PaleSoul" in corpse && corpse.PaleSoul == mark.Target && corpse.IsHeadAttached)
            soulFound = true;
    }
    this.set("LastVictoryHumanoid", humanoid ? 1 : 0);
    if (!this.castleDefenseLoot(strategic, this.Battle.DefenseDead) && this.oath() != this.Oath.None)
    {
        // 复活技能拉起来的遗骸照样算一具（复活时记下，见 hooks.nut）
        local total = corpses.len() + this.Battle.RaisedHarvest;
        local before = this.get("Reserve");
        // 1.7.0 天灾路线每 2 具 1 点（防腐师每 3 具 2 点）；冠军路线每 5 具 2 点（防腐师每 2 具 1 点）；向下取整
        local rate = this.harvestRate();
        local harvestYield = (total * rate[0] / rate[1]).tointeger();
        if (harvestYield > 0 || total > 0)
            harvestYield += this.graverobberHarvestBonus();
        this.changeReserve(harvestYield);
        local gathered = this.get("Reserve") - before;
        local used = ::Math.ceil(::Math.min(gathered, (total * rate[0] / rate[1]).tointeger()) * rate[1].tofloat() / rate[0]);
        this.Battle.Uncollected = ::Math.max(0, corpses.len() - used);
        // 1.7.0 天灾路线：采集到精锐亡灵的尸体时 50% 得 1 枚魂玉（每场最多 1 枚）
        if (eliteUndead && this.oath() == this.Oath.Scourge && ::Math.rand(1, 100) <= 50 && this.addMaterials("jade", 1))
            ::Tactical.EventLog.log("精锐亡灵的骸骨里藏着一枚古代魂玉。");
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
    foreach (hook in this.VictoryHooks)
    {
        try { hook.call(this); } catch (e) { ::logError("[PaleSovereign] victory hook: " + e); }
    }
};

// 1.7.0 其他模块在胜利结算末尾追加的处理
S.VictoryHooks <- [];

S.harvestRate <- function()
{
    local embalmer = this.followerRank("embalmer") > 0;
    if (this.oath() == this.Oath.Scourge)
        return embalmer ? [2, 3] : [1, 2];
    return embalmer ? [1, 2] : [2, 5];
};

// 后勤：盗墓贼 / 掘墓人每名 +1 点，最多 +2（见 living_bond.nut）
S.graverobberHarvestBonus <- @() 0;

S.isEliteUndeadCorpse <- function( _corpse )
{
    local info = ::BGP.Necro.getInfo(_corpse);
    if (info == null || !("Script" in info) || info.Script == null)
        return false;
    return this.isTameEliteScript(info.Script) || this.soulClassOfScript(info.Script) != null;
};

local undeadSpriteVariants = [
    { Layer = "head", Flag = "PaleHeadVariant", Count = 12 },
    { Layer = "body", Flag = "PaleBodyVariant", Count = 6 }
];

S.setSpriteBrushIfChanged <- function( _sprite, _brush )
{
    if (_sprite == null || _brush == null || _brush == "")
        return false;
    if (_sprite.HasBrush && _sprite.getBrush().Name == _brush)
        return false;
    _sprite.setBrush(_brush);
    return true;
};

S.resolveUndeadVariantBrush <- function( _flags, _model, _layer, _fallback = null )
{
    local variant = _layer == "head" ? undeadSpriteVariants[0] : undeadSpriteVariants[1];
    local index = this.getOrRollUndeadIndex(_flags, variant.Flag, variant.Count);
    local name = format("%s_%s_%02d", _model, _layer, index + 1);
    if (_layer == "body")
    {
        local detail = this.getOrRollUndeadIndex(_flags, "PaleDetailVariant", 6);
        local dressed = format("%s_detail_%02d", name, detail + 1);
        if (::doesBrushExist(dressed))
            name = dressed;
    }
    if (::doesBrushExist(name))
        return name;
    return _fallback;
};

S.applyUndeadVariants <- function( _actor, _model )
{
    local flags = _actor.getFlags();
    local changed = false;
    foreach (variant in undeadSpriteVariants)
    {
        local target = this.resolveUndeadVariantBrush(flags, _model, variant.Layer, null);
        if (target != null && this.setSpriteBrushIfChanged(_actor.getSprite(variant.Layer), target))
            changed = true;
    }
    local appearance = _actor.getItems().getAppearance();
    appearance.HideHair = true;
    appearance.HideBeard = true;
    return changed;
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
    local flags = _bro.getFlags();
    local appearance = _bro.getItems().getAppearance();
    if (skeleton)
        appearance.Corpse = "bust_skeleton_body_01_dead";

    // Compute final brushes once before calling setBrush to avoid unloading and re-decoding large atlases.
    local bodyBrush = skeleton ? "bust_skeleton_body_01" : null;
    local headBrush = skeleton ? "bust_skeleton_head" : "bgpu_bust_head_01";
    if (background.m.PaleRanged)
    {
        bodyBrush = this.resolveUndeadVariantBrush(flags, "pale_skeleton_archer", "body", "pale_skeleton_archer_body");
        headBrush = this.resolveUndeadVariantBrush(flags, "pale_skeleton_archer", "head", "pale_skeleton_archer_head");
        appearance.HideHair = true;
        appearance.HideBeard = true;
    }
    else if (branch != null)
    {
        local stem = "pale_" + (key in this.TierBrushStems ? this.TierBrushStems[key] : key);
        if (look != null)
            stem = "pale_sb_" + background.m.PaleSoulClass;
        bodyBrush = stem + "_body";
        headBrush = stem + "_head";
    }
    else if (background.getID() == "background.pale_skeleton" || background.getID() == "background.pale_zombie")
    {
        local model = skeleton ? "pale_summon_skeleton_0" : "pale_summon_zombie_0";
        bodyBrush = this.resolveUndeadVariantBrush(flags, model, "body", bodyBrush);
        headBrush = this.resolveUndeadVariantBrush(flags, model, "head", headBrush);
        appearance.HideHair = true;
        appearance.HideBeard = true;
    }

    local dirty = false;
    if (this.setSpriteBrushIfChanged(body, bodyBrush))
        dirty = true;
    if (this.setSpriteBrushIfChanged(head, headBrush))
        dirty = true;

    body.Color = ::createColor(branch != null || skeleton ? "#ffffff" : "#b4c4a5");
    head.Color = body.Color;
    if (branch != null && branch.Scale != 1.0)
    {
        foreach (layer in ["body", "head", "armor", "helmet", "armor_upgrade", "body_blood", "head_blood"])
            if (_bro.hasSprite(layer))
            {
                local sp = _bro.getSprite(layer);
                if (sp.Scale != branch.Scale)
                {
                    sp.Scale = branch.Scale;
                    dirty = true;
                }
            }
    }
    if (background.m.PaleBranch == "skeleton_king" && _bro.hasSprite("helmet")
        && _bro.getItems().getItemAtSlot(::Const.ItemSlot.Head) == null)
    {
        local crown = _bro.getSprite("helmet");
        if (this.setSpriteBrushIfChanged(crown, "pale_skeleton_king_crown"))
            dirty = true;
        if (!crown.Visible)
        {
            crown.Visible = true;
            dirty = true;
        }
    }
    foreach (layer in ["hair", "beard", "beard_top", "tattoo_body", "tattoo_head", "injury", "injury_body"])
    {
        if (_bro.hasSprite(layer))
        {
            local sp = _bro.getSprite(layer);
            if (sp.Visible)
            {
                sp.Visible = false;
                dirty = true;
            }
        }
    }
    if (skeleton)
    {
        foreach (layer in ["body_blood", "head_blood"])
            if (_bro.hasSprite(layer))
            {
                local sp = _bro.getSprite(layer);
                if (sp.Visible)
                {
                    sp.Visible = false;
                    dirty = true;
                }
            }
    }
    if (dirty)
        _bro.setDirty(true);
};

S.applySummonedLook <- function( _actor, _stem )
{
    local flags = _actor.getFlags();
    local bodyBrush = this.resolveUndeadVariantBrush(flags, _stem, "body", _stem + "_body");
    local headBrush = this.resolveUndeadVariantBrush(flags, _stem, "head", _stem + "_head");
    this.setSpriteBrushIfChanged(_actor.getSprite("body"), bodyBrush);
    this.setSpriteBrushIfChanged(_actor.getSprite("head"), headBrush);
    local appearance = _actor.getItems().getAppearance();
    appearance.HideHair = true;
    appearance.HideBeard = true;
    foreach (layer in ["body", "head"])
        _actor.getSprite(layer).Color = ::createColor("#ffffff");
    foreach (layer in ["hair", "beard", "beard_top", "injury", "injury_body", "body_blood_always"])
        if (_actor.hasSprite(layer))
            _actor.getSprite(layer).Visible = false;
    _actor.setDirty(true);
};
