local S = ::PaleSovereign;

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

S.forgeTargetName <- function( _target, _pet )
{
    return _pet ? _target.m.Name : _target.getName();
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
        // 1.7.4 每座亡灵古堡每 7 天产出 1 枚古代魂玉（两条路线通用），仓库满时暂存，有空位再发
        local castleFlags = town.getFlags();
        local today = ::World.getTime().Days;
        if (castleFlags.getAsInt("PaleJadeDay") == 0)
            castleFlags.set("PaleJadeDay", today + 7);
        else if (today >= castleFlags.getAsInt("PaleJadeDay"))
        {
            castleFlags.set("PaleJadeDay", today + 7);
            this.pendingItem("misc/pale_jade_item");
        }
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
    flags.set("PaleAnvilAfter", this.worldHours() + this.smithCooldownHours());
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
                this.option(_screen, data.Name, function() { S.EmbalmPage = 0; return "@" + page; });
            }
            if (this.castleHas(town, "pale_soul_anvil"))
                this.option(_screen, "缚魂铁砧 · 200 金、10 工具、1 块铜锭", @() S.castleAnvil(town));
            _screen.Text += "\n\n每座古堡使防腐尸骸上限 +30（当前上限 " + this.reserveLimit() + "）。";
            local jadeDay = town.getFlags().getAsInt("PaleJadeDay");
            _screen.Text += "\n\n古堡地窖每 7 天凝出 1 枚古代魂玉" + (jadeDay > 0 ? "，下一枚在战役第 " + jadeDay + " 天。" : "。");
            if (this.castleHas(town, "pale_salt_cellar"))
                _screen.Text += "\n\n盐窖仓储 +20。留在古堡地格时，每日免费修补。";
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
            this.recruitPoolPanel(_screen, town, 3, trained ? 2 : 0);
            if (!trained && ::World.Assets.getMoney() >= 1000)
                this.option(_screen, "升级亡者兵营（1000 克朗）", function()
                {
                    ::World.Assets.addMoney(-1000);
                    flags.set("PaleBarracksUpgraded", true);
                    return "此后新征召的亡灵起始等级提高 2 级。";
                });
            break;
        case "castle_sacrifice":
            if (!this.castleHas(town, "pale_sacrifice_pit"))
                break;
            local captives = this.slaughterableCaptives();
            _screen.Text += "\n\n挑选一名仓库里的俘虏推入献祭坑：每名可封存 2 点防腐尸骸，或为导师换取 200 点经验。\n" + this.resourceLine();
            if (captives.len() == 0)
                _screen.Text += "\n\n仓库里没有可以献祭的俘虏。";
            else
                this.pagedUnits(_screen, captives, this.EmbalmPage, @(item) S.captiveLabel(item), function( item )
                {
                    S.SacrificeItemID = item.getInstanceID();
                    return "@x_castle_sacrifice_pick";
                });
            break;
    }
    this.option(_screen, _screen.ID == "castle" ? "回到亡灵营地" : "回到亡灵古堡", @() _screen.ID == "castle" ? "@camp" : "@castle");
};

S.SacrificeItemID <- 0;

S.castleSacrificePickPanel <- function( _event, _screen )
{
    local town = this.castleHere();
    if (town == null || !this.castleHas(town, "pale_sacrifice_pit"))
    {
        _screen.Text = "这里没有献祭坑。";
        return "fort_pit";
    }
    local target = null;
    foreach (item in this.slaughterableCaptives())
        if (item.getInstanceID() == this.SacrificeItemID)
        {
            target = item;
            break;
        }
    if (target == null)
    {
        _screen.Text = "这名俘虏已经不在仓库里了。";
        return "fort_pit";
    }
    local label = this.captiveLabel(target);
    _screen.Text = "献祭坑底的泥土泛着暗红。" + label + " 已被押到坑沿，你要怎么处置？\n\n" + this.resourceLine();
    if (this.get("Reserve") < this.reserveLimit())
    {
        this.option(_screen, "献祭 " + label + " · 封存 2 点防腐尸骸", function()
        {
            local stash = ::World.Assets.getStash();
            if (stash.getItems().find(target) == null || S.get("Reserve") >= S.reserveLimit())
                return "防腐尸骸已满，或这名俘虏已不在仓库里。";
            local before = S.get("Reserve");
            stash.remove(target);
            S.changeReserve(2);
            ::World.State.updateTopbarAssets();
            return "一声闷响落进坑底。盐袋很快合拢，" + label + " 化作了战团的储备。\n\n（防腐尸骸 +" + (S.get("Reserve") - before) + "，现有 " + S.get("Reserve") + " / " + S.reserveLimit() + " 点）";
        });
    }
    else
        _screen.Text += "\n\n防腐尸骸已满，暂时不能献祭换取尸骸。";
    if (this.chief() != null)
    {
        this.option(_screen, "献祭 " + label + " · 导师获得 200 经验", function()
        {
            local stash = ::World.Assets.getStash();
            local chief = S.chief();
            if (chief == null || stash.getItems().find(target) == null)
                return "现在不能举行献祭。";
            stash.remove(target);
            chief.addXP(200);
            chief.updateLevel();
            return "幽绿的魂火从坑底卷起，将 " + label + " 最后的生机尽数抽入法杖。\n\n（导师获得 200 经验）";
        });
    }
    return "fort_pit";
};

S.addPage("x_castle_sacrifice_pick", "献祭坑", "fort_pit", @(_event, _screen) S.castleSacrificePickPanel(_event, _screen), "@castle_sacrifice");
