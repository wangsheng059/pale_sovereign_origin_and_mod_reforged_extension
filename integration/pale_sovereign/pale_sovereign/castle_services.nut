local S = ::PaleSovereign;

S.CastleJobs <- [
    { Name = "魂玉淬骨", ID = "misc.pale_jade", Amount = 1 },
    { Name = "古币灌注", ID = "misc.ancient_gold_coins", Amount = 3 },
    { Name = "镀金骨甲", ID = "loot.pale_gold_ingot", Amount = 1 },
    { Name = "宝石眼窝", ID = "misc.gemstones", Amount = 1 }
];

S.takeItems <- function( _id, _count )
{
    local stash = ::World.Assets.getStash();
    local items = stash.getItems().filter(@(_, item) item != null && item.getID() == _id);
    if (items.len() < _count)
        return false;
    for (local i = 0; i < _count; ++i)
        stash.remove(items[i]);
    return true;
};

S.castleTombs <- function( _town )
{
    local key = this.siteKey(_town.getTile());
    return _town.m.Stash.getItems().filter(@(_, item) S.isCoffin(item)
        && ::World.Flags.get("Pale." + S.petKey(item.m.PaleID, "Tomb")) == key);
};

S.storeCastleCoffin <- function( _town, _item, _put )
{
    if (!this.castleHas(_town, "pale_mausoleum"))
        return "这座古堡还没有冠军陵寝。";
    local carry = ::World.Assets.getStash();
    local tomb = _town.m.Stash;
    local from = _put ? carry : tomb;
    local to = _put ? tomb : carry;
    if (_put && this.castleTombs(_town).len() >= 3)
        return "陵寝的三座墓室都满了。";
    if (!to.hasEmptySlot() || from.getItems().find(_item) == null)
        return "没有足够的空位，棺椁留在原处。";
    from.remove(_item);
    if (!to.add(_item))
    {
        from.add(_item);
        return "棺椁留在原处。";
    }
    this.petSet(_item, "Tomb", _put ? this.siteKey(_town.getTile()) : "");
    return _put ? "棺椁已停入陵寝。" : "棺椁已送回战团物品栏。";
};

S.castleTrain <- function( _bro, _levels = 1 )
{
    for (local i = 0; i < _levels; ++i)
    {
        local xp = _bro.getXPForNextLevel() - _bro.getXP();
        if (xp <= 0)
            break;
        _bro.addXP(xp, false);
        _bro.updateLevel();
    }
};

S.castleCanForge <- function( _job, _target, _isPet )
{
    if (_isPet)
    {
        if (!this.isCoffin(_target) || this.oath() != this.Oath.Champion || _job == 1)
            return false;
        if (_job == 0)
            return true;
        return this.petGet(_target, _job == 2 ? "Gilded" : "GemEyes") == 0;
    }
    if (_target == null || !this.isUndead(_target))
        return false;
    local flags = _target.getFlags();
    return _job == 0 ? !flags.has("PaleJade")
        : _job == 1 ? _target.getXPForNextLevel() > _target.getXP()
        : !flags.has(_job == 2 ? "PaleGilded" : "PaleGemEyes");
};

S.forgeTargetName <- function( _target, _pet )
{
    return _pet ? _target.m.Name : _target.getName();
};

S.queueCastleForge <- function( _town, _job, _target, _isPet )
{
    local flags = _town.getFlags();
    local recipe = this.CastleJobs[_job];
    if (flags.getAsInt("PaleForge") != 0 || !this.castleCanForge(_job, _target, _isPet)
        || this.countItems(recipe.ID) < recipe.Amount)
        return "魂炉无法接下这项工作。";
    if (!_isPet && !_target.getFlags().has("PaleUnitID"))
    {
        local id = this.get("NextCastleUnit") + 1;
        _target.getFlags().set("PaleUnitID", id);
        this.set("NextCastleUnit", id);
    }
    flags.set("PaleForge", _job + 1);
    flags.set("PaleForgeEnd", this.worldHours() + 24);
    flags.set("PaleForgeIsCoffin", _isPet);
    flags.set("PaleForgeTarget", _isPet ? this.petID(_target) : _target.getFlags().getAsInt("PaleUnitID"));
    flags.set("PaleForgeTier", _isPet ? 0 : this.getUndeadTier(_target));
    flags.set("PaleForgeNotice", "");
    return "开始为 " + this.forgeTargetName(_target, _isPet) + " 准备" + recipe.Name
        + "。在古堡地格扎营或停留一天，完工后扣除材料。离开地格会重新计时。";
};

S.forgeApply <- function( _job, _target, _isPet )
{
    if (_isPet)
    {
        if (_job == 0)
        {
            this.raiseRandomAttributes(_target.m.Attributes, 4, 2);
            this.petSet(_target, "JadeTemper", this.petGet(_target, "JadeTemper") + 1);
        }
        else if (_job == 2)
            this.petSet(_target, "Gilded", 1);
        else
        {
            _target.m.Attributes.Initiative += 10;
            _target.m.Attributes.RangedDefense += 5;
            this.petSet(_target, "GemEyes", 1);
        }
        _target.updateCompanion();
        return;
    }

    local stats = _target.getBaseProperties();
    if (_job == 0)
    {
        this.raiseRandomAttributes(stats, 4, 2);
        _target.getFlags().set("PaleJade", true);
    }
    else if (_job == 1)
        this.castleTrain(_target);
    else if (_job == 2)
    {
        _target.getFlags().set("PaleGilded", true);
        this.gildArmor(_target);
    }
    else
    {
        stats.Initiative += 10;
        stats.RangedDefense += 5;
        _target.getFlags().set("PaleGemEyes", true);
    }
    _target.getSkills().update();
};

S.castleForgeTick <- function( _town, _present, _now )
{
    local flags = _town.getFlags();
    local job = flags.getAsInt("PaleForge") - 1;
    if (job < 0)
        return;
    if (!_present)
    {
        flags.set("PaleForgeEnd", _now + 24);
        return;
    }
    if (_now < flags.getAsInt("PaleForgeEnd"))
        return;
    flags.set("PaleForge", 0);
    local id = flags.getAsInt("PaleForgeTarget");
    local pet = flags.get("PaleForgeIsCoffin") == true;
    local targets = pet ? this.companyCoffins() : this.undead();
    local recipe = this.CastleJobs[job];
    foreach (target in targets)
    {
        local targetID = pet ? target.m.PaleID : target.getFlags().getAsInt("PaleUnitID");
        if (id != targetID)
            continue;
        if ((!pet && this.getUndeadTier(target) != ::Math.max(1, flags.getAsInt("PaleForgeTier")))
            || !this.castleHas(_town, "pale_soul_furnace") || !this.castleCanForge(job, target, pet)
            || !this.takeItems(recipe.ID, recipe.Amount))
            break;
        this.forgeApply(job, target, pet);
        flags.set("PaleForgeNotice", this.forgeTargetName(target, pet) + " 完成了" + recipe.Name + "。");
        ::World.State.updateTopbarAssets();
        return;
    }
    flags.set("PaleForgeNotice", "强化取消。材料、目标或魂炉已不可用。");
};

S.castleDaily = function()
{
    local present = this.castleHere(0);
    if (this.castleHas(present, "pale_salt_cellar"))
        this.repairUndead(true);
    else if (this.oath() != this.Oath.None)
        this.repairUndead();

    foreach (town in this.castles())
    {
        if (!this.castleHas(town, "pale_mausoleum"))
            continue;
        foreach (pet in this.castleTombs(town))
        {
            pet.m.Wounds = ::Math.max(0, pet.m.Wounds - 10);
            pet.addXP(10);
        }
    }
    if (present == null || !::World.Assets.getStash().hasEmptySlot())
        return;
    local flags = present.getFlags();
    local day = ::World.getTime().Days;
    foreach (resource in [
        { Location = "attached_location.gold_mine", Key = "PaleGoldDay", Period = 7, Path = "loot/pale_gold_ingot_item" },
        { Location = "attached_location.ore_smelters", Key = "PaleMetalDay", Period = 3, Path = "trade/copper_ingots_item" }
    ])
    {
        local site = present.getLocation(resource.Location);
        if (site == null || !site.isActive() || day < flags.getAsInt(resource.Key) || !::World.Assets.getStash().hasEmptySlot())
            continue;
        ::World.Assets.getStash().add(::new(this.ItemDir + resource.Path));
        flags.set(resource.Key, day + resource.Period);
    }
};

S.castleWorldTick = function()
{
    local present = this.castleHere(0);
    local now = this.worldHours();
    foreach (town in this.castles())
        this.castleForgeTick(town, town == present, now);

};

S.castleAnvil <- function( _town )
{
    local flags = _town.getFlags();
    local assets = ::World.Assets;
    if (!this.castleHas(_town, "pale_soul_anvil") || this.worldHours() < flags.getAsInt("PaleAnvilAfter")
        || assets.getMoney() < 200 || assets.getArmorParts() < 10 || !this.takeItems("misc.copper_ingots", 1))
        return "材料不足或铁砧尚在冷却。";
    if (!this.addMaterials("chain", 1))
    {
        assets.getStash().add(::new(this.ItemDir + "trade/copper_ingots_item"));
        return "仓库没有空位。";
    }
    assets.addMoney(-200);
    assets.addArmorParts(-10);
    flags.set("PaleAnvilAfter", this.worldHours() + 240);
    return "消耗 200 克朗、10 工具和 1 块铜锭，打出一条缚魂锁链。";
};

S.castlePanel <- function( _screen )
{
    local town = this.castleHere();
    local page = _screen.ID.find("castle_forge") == 0 ? "castle_forge" : _screen.ID;
    _screen.Text = this.CastleIntro;
    if (page != "castle")
        foreach (data in this.CastleBuildings)
            if (data.Page == page)
                _screen.Text = data.Flavor;
    if (town == null)
    {
        _screen.Text = "这里没有已完工的古堡。";
        return;
    }
    local flags = town.getFlags();
    if (flags.get("PaleForgeNotice") != false && flags.get("PaleForgeNotice") != "")
        _screen.Text += "\n\n" + flags.get("PaleForgeNotice");

    switch (_screen.ID)
    {
        case "castle":
            foreach (key, data in this.CastleBuildings)
            {
                if (data.Page == "castle" || !this.castleHas(town, key))
                    continue;
                local page = data.Page;
                this.option(_screen, data.Name, @() "@" + page);
            }
            if (this.castleHas(town, "pale_soul_anvil"))
                this.option(_screen, "缚魂铁砧 · 200 金、10 工具、1 块铜锭", @() S.castleAnvil(town));
            if (this.castleHas(town, "pale_salt_cellar"))
                _screen.Text += "\n\n盐窖仓储 +20。留在古堡地格时，每日免费修补。";
            break;
        case "castle_forge":
            if (!this.castleHas(town, "pale_soul_furnace"))
                break;
            if (flags.getAsInt("PaleForge") != 0)
            {
                _screen.Text += "\n\n魂炉正在工作。停留至战役第 " + (flags.getAsInt("PaleForgeEnd") / 24).tointeger() + " 天。";
                this.option(_screen, "撤回委托", function() { flags.set("PaleForge", 0); return "委托撤回。"; });
                break;
            }
            local names = ["1 枚魂玉", "3 枚古代金币", "1 块金锭", "1 颗宝石"];
            foreach (i, recipe in this.CastleJobs)
            {
                if (this.countItems(recipe.ID) < recipe.Amount)
                    continue;
                local job = i;
                this.option(_screen, recipe.Name + " · " + names[job], @() "@castle_forge_" + job);
            }
            break;
        case "castle_tombs":
            if (!this.castleHas(town, "pale_mausoleum"))
                break;
            local coffins = this.castleTombs(town);
            _screen.Text += "\n\n陵寝已停放 " + coffins.len() + " / 3 口棺椁。";
            foreach (pet in coffins)
            {
                local coffin = pet;
                this.option(_screen, "领回 " + coffin.m.Name, @() S.storeCastleCoffin(town, coffin, false));
            }
            if (coffins.len() < 3)
            {
                foreach (pet in ::World.Assets.getStash().getItems())
                {
                    if (!this.isCoffin(pet))
                        continue;
                    local coffin = pet;
                    this.option(_screen, "寄存 " + coffin.m.Name, @() S.storeCastleCoffin(town, coffin, true));
                }
            }
            break;
        case "castle_barracks":
            if (!this.castleHas(town, "pale_dead_barracks"))
                break;
            local trained = flags.get("PaleBarracksUpgraded") == true;
            if (this.canRecruitUndead(null, 3))
            {
                foreach (skeleton in [true, false])
                {
                    local recruitSkeleton = skeleton;
                    this.option(_screen, "征召" + (recruitSkeleton ? "骷髅" : "行尸") + "（3 点尸骸）",
                        @() S.recruitUndead(null, recruitSkeleton, 3, trained ? 2 : 0) ? "新兵已加入战团。" : "无法征召。");
                }
            }
            if (!trained && ::World.Assets.getMoney() >= 1000)
                this.option(_screen, "升级亡者兵营（1000 克朗）", function()
                {
                    ::World.Assets.addMoney(-1000);
                    flags.set("PaleBarracksUpgraded", true);
                    return "此后新征召的亡灵起始等级提高 2 级。";
                });
            break;
        case "castle_sacrifice":
            if (this.castleHas(town, "pale_sacrifice_pit") && this.countItems("misc.hsc_captive") > 0)
            {
                this.option(_screen, "献祭一名俘虏，封存 2 点尸骸", function()
                {
                    if (S.get("Reserve") > S.reserveLimit() - 2 || !S.takeItems("misc.hsc_captive", 1))
                        return "尸骸已满，或没有可献祭的俘虏。";
                    S.changeReserve(2);
                    return "防腐尸骸 +2。";
                });
                this.option(_screen, "献祭一名俘虏，导师获得 200 经验", function()
                {
                    if (S.chief() == null || !S.takeItems("misc.hsc_captive", 1))
                        return "现在不能举行献祭。";
                    S.chief().addXP(200);
                    S.chief().updateLevel();
                    return "导师获得 200 经验。";
                });
            }
            break;
        default:
            if (_screen.ID.find("castle_forge_") != 0 || !this.castleHas(town, "pale_soul_furnace"))
                break;
            local job = _screen.ID.slice(13).tointeger();
            foreach (pet in this.companyCoffins())
            {
                if (!this.castleCanForge(job, pet, true))
                    continue;
                local target = pet;
                this.option(_screen, target.m.Name, @() S.queueCastleForge(town, job, target, true));
            }
            foreach (bro in this.undead())
            {
                if (!this.castleCanForge(job, bro, false))
                    continue;
                local target = bro;
                this.option(_screen, target.getName(), @() S.queueCastleForge(town, job, target, false));
            }
            break;
    }
    this.option(_screen, _screen.ID == "castle" ? "回到亡灵营地" : "回到亡灵古堡", @() _screen.ID == "castle" ? "@camp" : "@castle");
};
