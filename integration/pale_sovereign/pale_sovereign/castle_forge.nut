local S = ::PaleSovereign;

// 1.7.0 古堡魂炉重做：魂玉配方全部为古堡独占，所有配方停留 4 小时完工
// 配方编号存进古堡旗标 PaleForge（编号 + 1），只能往后追加
S.ForgeHours <- 4;
S.CastleJobs <- [
    { Key = "wash", Name = "魂玉洗骨", Cost = "1 枚魂玉、2 点防腐尸骸", Items = [["misc.pale_jade", 1]], Reserve = 2, Pet = false, Unit = true, Route = 0,
      Desc = "从常驻亡灵所属种类的正面专属特质中随机注入 1 个。每名常驻亡灵限 2 次。" },
    { Key = "named", Name = "名器熔铸", Cost = "1 枚魂玉 + 1 件名器（或 1 枚魂玉 + 1 块金锭重铸承誓武器）", Items = [["misc.pale_jade", 1]], Reserve = 0, Pet = true, Unit = false, Route = 1,
      Desc = "冠军独占。把仓库里的一件名器武器、头盔或护甲熔进冠军对应的栏位（保留名器基础属性）；或消耗 1 枚魂玉与 1 块金锭，重随冠军承誓武器的两项属性（只升不降，每项至多 +5%）。" },
    { Key = "inherit", Name = "棺魂传承", Cost = "1 枚魂玉", Items = [["misc.pale_jade", 1]], Reserve = 0, Pet = true, Unit = false, Route = 1,
      Desc = "冠军独占。把冠军陵寝里一口候补棺椁的吞魂特质转给出战冠军（受吞魂上限约束，不含护驾遗志），那口棺椁随之销毁。" },
    { Key = "enchant", Name = "术法淬玉", Cost = "2 枚魂玉（切换 1 枚）", Items = [["misc.pale_jade", 2]], Reserve = 0, Pet = false, Unit = false, Route = 2,
      Desc = "天灾独占。为整个战团附上一种死灵术法（同时生效 1 种，飞升后 2 种）。" },
    { Key = "coin", Name = "古币灌注", Cost = "1 枚古代金币", Items = [["misc.ancient_gold_coins", 1]], Reserve = 0, Pet = false, Unit = true, Route = 0,
      Desc = "选定的常驻亡灵直接补满当前等级剩余的经验，升 1 级。" },
    { Key = "gild", Name = "镀金骨甲", Cost = "1 块金锭", Items = [["loot.pale_gold_ingot", 1]], Reserve = 0, Pet = true, Unit = true, Route = 0,
      Desc = "头盔与护甲最大耐久永久 +20（冠军棺椁自带的护甲也可以）。每名 1 次。" },
    { Key = "gem", Name = "宝石眼窝", Cost = "1 颗宝石", Items = [["misc.gemstones", 1]], Reserve = 0, Pet = true, Unit = true, Route = 0,
      Desc = "赋予永久特质【宝石眼窝】：主动性 +10、远程防御 +5、视野 +3。升阶保留，终生仅生效一次。" }
];
S.Enchants <- [
    { Key = "miasma", Name = "玉毒尸弹", Desc = "尸弹落地时在目标格及周围 1 格生成 2 回合苍白尸瘴：活人敌人进入或在其中结束回合时受到 10–15 点无视护甲伤害，近战防御 −5。" },
    { Key = "echo", Name = "千魂回响", Desc = "导师每场前 2 次复活或召唤的疲劳消耗 −50%；唤起的临时亡灵带 3 回合玉骨盾：头、身各 +30 临时护甲，伤害 +15%。" },
    { Key = "tide", Name = "亡潮蓄能", Desc = "每场我方每累计击杀 4 名敌人，导师恢复 15 点疲劳，下一次衰弱术与岁月诅咒不耗行动点与疲劳（每场最多 3 次）。" }
];
S.WashLimit <- 2;
S.enchantCap <- @() this.isAscended() ? 2 : 1;
S.hasEnchant <- @(_key) this.oath() == this.Oath.Scourge && this.get("Enchant." + _key) != 0;
S.activeEnchants <- function()
{
    return this.Enchants.filter(@(_, e) S.get("Enchant." + e.Key) != 0);
};

S.jobRouteOK <- function( _job )
{
    local route = this.CastleJobs[_job].Route;
    return route == 0 || (route == 1 && this.oath() == this.Oath.Champion) || (route == 2 && this.oath() == this.Oath.Scourge);
};

S.jobAffordable <- function( _job, _altGold = false )
{
    local job = this.CastleJobs[_job];
    foreach (pair in job.Items)
        if (this.countItems(pair[0]) < pair[1])
            return false;
    if (_altGold && this.countItems("loot.pale_gold_ingot") < 1)
        return false;
    return this.get("Reserve") >= job.Reserve;
};

S.namedStashItems <- function()
{
    return ::World.Assets.getStash().getItems().filter(@(_, item) item != null && item.isItemType(::Const.Items.ItemType.Named)
        && (item.isItemType(::Const.Items.ItemType.Weapon) || item.isItemType(::Const.Items.ItemType.Helmet) || item.isItemType(::Const.Items.ItemType.Armor)));
};

S.castleCanForge <- function( _job, _target, _isPet )
{
    if (!this.jobRouteOK(_job))
        return false;
    local key = this.CastleJobs[_job].Key;
    if (_isPet)
    {
        if (!this.isCoffin(_target) || !this.CastleJobs[_job].Pet)
            return false;
        if (key == "gild")
            return this.petGet(_target, "Gilded") == 0;
        if (key == "gem")
            return this.petGet(_target, "GemEyes") == 0;
        return ::MSU.isEqual(_target, this.mainPet());
    }
    if (key == "enchant")
        return true;
    if (_target == null || !this.isUndead(_target) || !this.CastleJobs[_job].Unit)
        return false;
    local flags = _target.getFlags();
    switch (key)
    {
        case "wash": return (flags.has("PaleWash") ? flags.getAsInt("PaleWash") : 0) < this.WashLimit && this.graftCandidates(_target).len() > 0;
        case "coin": return _target.getXPForNextLevel() > _target.getXP();
        case "gild": return !flags.has("PaleGilded");
        case "gem": return !flags.has("PaleGemEyes") && !_target.getSkills().hasSkill("trait.pale_gem_eyes");
    }
    return false;
};

S.queueCastleForge <- function( _town, _job, _target, _isPet, _extra = "" )
{
    local flags = _town.getFlags();
    local recipe = this.CastleJobs[_job];
    if (flags.getAsInt("PaleForge") != 0 || !this.castleCanForge(_job, _target, _isPet) || !this.jobAffordable(_job, _extra == "gold"))
        return "魂炉无法接下这项工作。";
    if (_target != null && !_isPet && !_target.getFlags().has("PaleUnitID"))
    {
        local id = this.get("NextCastleUnit") + 1;
        _target.getFlags().set("PaleUnitID", id);
        this.set("NextCastleUnit", id);
    }
    flags.set("PaleForge", _job + 1);
    flags.set("PaleForgeEnd", this.worldHours() + this.ForgeHours);
    flags.set("PaleForgeIsCoffin", _isPet);
    flags.set("PaleForgeTarget", _target == null ? 0 : _isPet ? this.petID(_target) : _target.getFlags().getAsInt("PaleUnitID"));
    flags.set("PaleForgeTier", _target == null || _isPet ? 0 : this.getUndeadTier(_target));
    flags.set("PaleForgeExtra", _extra);
    flags.set("PaleForgeNotice", "");
    return "冷火在魂炉深处悄然升起，已开始" + (_target == null ? "" : "为 " + this.forgeTargetName(_target, _isPet) + " ") + "筹备【" + recipe.Name
        + "】。请在古堡地格停留或扎营 " + this.ForgeHours + " 小时，待冷火熄灭完工后扣除材料；中途离开地格需重新计时。";
};

S.forgeConsume <- function( _job, _extra )
{
    local job = this.CastleJobs[_job];
    foreach (pair in job.Items)
        if (!this.takeItems(pair[0], pair[1]))
            return false;
    if (_extra == "gold" && !this.takeItems("loot.pale_gold_ingot", 1))
        return false;
    if (job.Reserve > 0 && !this.changeReserve(-job.Reserve))
        return false;
    return true;
};

S.findStashItemByInstance <- function( _id )
{
    if (_id == null)
        return null;
    local needle = _id + "";
    if (needle.len() == 0)
        return null;
    foreach (item in ::World.Assets.getStash().getItems())
        if (item != null && (item.getInstanceID() + "") == needle)
            return item;
    return null;
};

// 名器熔铸：武器写进承誓武器记录；头盔 / 护甲写进冠军的装备记录（放出时按记录生成）
S.forgeNamed <- function( _pet, _item )
{
    if (_item.isItemType(::Const.Items.ItemType.Weapon))
    {
        local script = ::IO.scriptFilenameByHash(_item.ClassNameHash);
        this.petSet(_pet, "Weapon", script);
        this.petSet(_pet, "WeaponName", _item.getName());
        foreach (key in this.WeaponFields)
        {
            local value = null;
            try { value = _item.m[key]; } catch (e) { value = null; }
            this.petSet(_pet, "WeaponSet." + key, value == null ? 0 : 1);
            if (value != null)
                this.petSet(_pet, "Weapon." + key, value);
        }
        return;
    }
    local slot = _item.isItemType(::Const.Items.ItemType.Helmet) ? "Helmet" : "Armor";
    this.petSet(_pet, "Named" + slot, ::IO.scriptFilenameByHash(_item.ClassNameHash));
    this.petSet(_pet, "Named" + slot + "Name", _item.getName());
    foreach (key in ["ConditionMax", "StaminaModifier"])
    {
        local value = null;
        try { value = _item.m[key]; } catch (e) { value = null; }
        if (value != null)
            this.petSet(_pet, "Named" + slot + "." + key, value);
    }
};

// 可从候补棺椁转给主冠军的吞魂特质列表（排除 4 号护驾遗志与已拥有的，且不超过剩余吞魂空位）
S.inheritableSouls <- function( _source, _target )
{
    local ret = [];
    if (_source == null || _target == null)
        return ret;
    local room = ::Math.max(0, this.devourCap(_target) - this.petGet(_target, "Devours"));
    if (room == 0)
        return ret;
    foreach (species in this.petSouls(_source))
    {
        if (species == 4 || this.petGet(_target, "Species." + species) != 0)
            continue;
        ret.push(species);
        if (ret.len() >= room)
            break;
    }
    return ret;
};

S.forgeReroll <- function( _pet )
{
    local keys = ["RegularDamage", "RegularDamageMax", "DirectDamageMult", "ArmorDamageMult", "ChanceToHitHead", "AdditionalAccuracy"]
        .filter(@(_, key) S.petGet(_pet, "WeaponSet." + key) != 0);
    local picked = [];
    while (picked.len() < 2 && keys.len() > 0)
        picked.push(keys.remove(::Math.rand(0, keys.len() - 1)));
    local names = [];
    foreach (key in picked)
    {
        local flag = "Pale." + this.petKey(_pet.m.PaleID, "Weapon." + key);
        local mult = 1.0 + ::Math.rand(1, 5) / 100.0;
        if (key == "DirectDamageMult" || key == "ArmorDamageMult")
            ::World.Flags.set(flag, ::World.Flags.getAsFloat(flag) * mult);
        else
        {
            local old = ::World.Flags.getAsInt(flag);
            ::World.Flags.set(flag, ::Math.max(old + 1, ::Math.floor(old * mult)));
        }
        names.push(key);
    }
    local minFlag = "Pale." + this.petKey(_pet.m.PaleID, "Weapon.RegularDamage");
    local maxFlag = "Pale." + this.petKey(_pet.m.PaleID, "Weapon.RegularDamageMax");
    if (this.petGet(_pet, "WeaponSet.RegularDamage") != 0 && this.petGet(_pet, "WeaponSet.RegularDamageMax") != 0)
    {
        local lo = ::World.Flags.getAsInt(minFlag);
        local hi = ::World.Flags.getAsInt(maxFlag);
        if (lo > hi)
            ::World.Flags.set(maxFlag, lo);
    }
    return names.len();
};

S.forgeApply <- function( _job, _target, _isPet, _extra = "" )
{
    local key = this.CastleJobs[_job].Key;
    if (_isPet)
    {
        switch (key)
        {
            case "named":
                if (_extra == "gold")
                    this.forgeReroll(_target);
                else
                {
                    local item = this.findStashItemByInstance(_extra);
                    if (item == null)
                        return false;
                    this.forgeNamed(_target, item);
                    ::World.Assets.getStash().remove(item);
                }
                break;
            case "inherit":
                local source = null;
                foreach (pet in this.companyCoffins())
                    if (pet.m.PaleID + "" == _extra)
                        source = pet;
                if (source == null)
                    foreach (town in this.castles())
                        foreach (pet in this.castleTombs(town))
                            if (pet.m.PaleID + "" == _extra)
                                source = pet;
                if (source == null)
                    return false;
                local transferable = this.inheritableSouls(source, _target);
                if (transferable.len() == 0)
                    return false;
                foreach (species in transferable)
                {
                    this.petSet(_target, "Species." + species, 1);
                    this.petSet(_target, "Devours", this.petGet(_target, "Devours") + 1);
                }
                if (this.get("ReservePetID") == source.m.PaleID)
                    this.set("ReservePetID", 0);
                if (this.get("TwinID") == source.m.PaleID)
                {
                    this.set("TwinID", 0);
                    this.set("TwinMode", 0);
                }
                foreach (town in this.castles())
                    if (town.m.Stash.getItems().find(source) != null)
                        town.m.Stash.remove(source);
                if (::World.Assets.getStash().getItems().find(source) != null)
                    ::World.Assets.getStash().remove(source);
                break;
            case "gild":
                this.petSet(_target, "Gilded", 1);
                break;
            case "gem":
                _target.m.Attributes.Initiative += 10;
                _target.m.Attributes.RangedDefense += 5;
                this.petSet(_target, "GemEyes", 1);
                break;
        }
        _target.updateCompanion();
        return true;
    }
    if (key == "enchant")
    {
        local active = this.activeEnchants();
        if (active.len() >= this.enchantCap())
            this.set("Enchant." + active[0].Key, 0);
        this.set("Enchant." + _extra, 1);
        return true;
    }
    local stats = _target.getBaseProperties();
    local flags = _target.getFlags();
    switch (key)
    {
        case "wash":
            local picks = this.graftCandidates(_target);
            if (picks.len() == 0)
                return false;
            _target.getSkills().add(picks[::Math.rand(0, picks.len() - 1)]);
            flags.set("PaleWash", (flags.has("PaleWash") ? flags.getAsInt("PaleWash") : 0) + 1);
            break;
        case "coin":
            this.castleTrain(_target);
            break;
        case "gild":
            flags.set("PaleGilded", true);
            this.gildArmor(_target);
            break;
        case "gem":
            if (_target.getSkills().hasSkill("trait.pale_gem_eyes"))
                return false;
            _target.getSkills().add(::new("scripts/skills/traits/pale_undead_gem_eyes_trait"));
            flags.set("PaleGemEyes", true);
            break;
    }
    _target.getSkills().update();
    return true;
};

S.castleForgeTick <- function( _town, _present, _now )
{
    local flags = _town.getFlags();
    local job = flags.getAsInt("PaleForge") - 1;
    if (job < 0)
        return;
    if (!_present)
    {
        flags.set("PaleForgeEnd", _now + this.ForgeHours);
        return;
    }
    if (_now < flags.getAsInt("PaleForgeEnd"))
        return;
    flags.set("PaleForge", 0);
    local recipe = this.CastleJobs[job];
    local extra = flags.get("PaleForgeExtra");
    if (typeof extra != "string")
        extra = "";
    local id = flags.getAsInt("PaleForgeTarget");
    local pet = flags.get("PaleForgeIsCoffin") == true;
    local target = null;
    if (recipe.Key != "enchant")
        foreach (candidate in pet ? this.companyCoffins() : this.undead())
            if ((pet ? candidate.m.PaleID : candidate.getFlags().getAsInt("PaleUnitID")) == id)
                target = candidate;
    local ok = this.castleHas(_town, "pale_soul_furnace") && (recipe.Key == "enchant" || target != null)
        && (recipe.Key == "enchant" || this.castleCanForge(job, target, pet))
        && (pet || target == null || this.getUndeadTier(target) == ::Math.max(1, flags.getAsInt("PaleForgeTier")))
        && this.jobAffordable(job, extra == "gold");
    if (ok && recipe.Key == "named" && extra != "gold" && this.findStashItemByInstance(extra) == null)
        ok = false;
    if (!ok || !this.forgeConsume(job, extra) || !this.forgeApply(job, target, pet, extra))
    {
        flags.set("PaleForgeNotice", "炉火熄灭，强化被迫取消——材料、目标或魂炉已不再满足条件。");
        return;
    }
    flags.set("PaleForgeNotice", "炉膛冷火散尽，" + (target == null ? "战团" : this.forgeTargetName(target, pet)) + " 已完成【" + recipe.Name + "】。");
    ::World.State.updateTopbarAssets();
};

// ---------------- 魂炉页面 ----------------
S.ForgeJob <- 0;

S.forgeMenuPanel <- function( _screen, _town )
{
    local flags = _town.getFlags();
    if (flags.getAsInt("PaleForge") != 0)
    {
        _screen.Text += "\n\n幽冷的碧火正在炉膛里翻涌，【" + this.CastleJobs[flags.getAsInt("PaleForge") - 1].Name + "】尚在淬炼中。请在古堡地格停留到战役第 "
            + (flags.getAsInt("PaleForgeEnd") / 24 + 1) + " 天 " + (flags.getAsInt("PaleForgeEnd") % 24) + " 时。";
        this.option(_screen, "熄火撤回委托", function() { flags.set("PaleForge", 0); return "你挥杖压熄炉火，未耗的材料仍留在仓库中。"; });
        return;
    }
    _screen.Text += "\n\n魂炉只认古堡地脉的寒气，所有配方需在古堡停留 " + this.ForgeHours + " 小时方能成器。" + this.resourceLine();
    if (this.oath() == this.Oath.Scourge && this.activeEnchants().len() > 0)
    {
        local names = "";
        foreach (i, e in this.activeEnchants())
            names += (i == 0 ? "" : "、") + e.Name;
        _screen.Text += "\n当前术法：" + names;
    }
    foreach (i, recipe in this.CastleJobs)
    {
        if (!this.jobRouteOK(i))
            continue;
        _screen.Text += "\n\n【" + recipe.Name + "】" + recipe.Cost + "：" + recipe.Desc;
        local job = i;
        local canOpen = this.jobAffordable(i)
            || (recipe.Key == "named" && this.countItems("misc.pale_jade") >= 1)
            || (recipe.Key == "enchant" && this.activeEnchants().len() >= this.enchantCap() && this.countItems("misc.pale_jade") >= 1);
        if (canOpen)
            this.option(_screen, recipe.Name + " · " + recipe.Cost, function() { S.ForgeJob = job; S.EmbalmPage = 0; return "@x_forge_job"; });
    }
};

S.forgeJobPanel <- function( _event, _screen )
{
    local town = this.castleHere();
    if (town == null || !this.castleHas(town, "pale_soul_furnace"))
    {
        _screen.Text = "这里没有魂炉。";
        return "fort_forge";
    }
    local job = this.ForgeJob;
    local recipe = this.CastleJobs[job];
    _screen.Text = "【" + recipe.Name + "】" + recipe.Desc + "\n\n" + this.resourceLine();
    local pet = this.mainPet();
    switch (recipe.Key)
    {
        case "named":
            if (pet == null)
            {
                _screen.Text += "\n\n先把冠军的棺椁装进导师的饰品栏。";
                break;
            }
            foreach (item in this.namedStashItems())
            {
                local named = item;
                this.option(_screen, "熔入 " + named.getName() + " · 1 枚魂玉", @() S.queueCastleForge(town, job, pet, true, named.getInstanceID() + ""));
            }
            local weaponFlag = ::World.Flags.get("Pale." + this.petKey(pet.m.PaleID, "Weapon"));
            if (typeof weaponFlag == "string" && weaponFlag.len() > 0 && this.countItems("loot.pale_gold_ingot") >= 1)
                this.option(_screen, "重铸承誓武器 · 1 枚魂玉 + 1 块金锭", @() S.queueCastleForge(town, job, pet, true, "gold"));
            break;
        case "inherit":
            if (pet == null)
            {
                _screen.Text += "\n\n先把主冠军的棺椁装进导师的饰品栏。";
                break;
            }
            if (this.petGet(pet, "Devours") >= this.devourCap(pet))
            {
                _screen.Text += "\n\n出战冠军的吞魂次数已满（" + this.petGet(pet, "Devours") + " / " + this.devourCap(pet) + "），无法再承接残魂。";
                break;
            }
            local shown = 0;
            foreach (source in this.castleTombs(town))
            {
                local picks = this.inheritableSouls(source, pet);
                if (picks.len() == 0)
                    continue;
                local coffin = source;
                local names = "";
                foreach (idx, sp in picks)
                    names += (idx == 0 ? "" : "、") + this.Souls[sp].Name;
                this.option(_screen, "传承 " + coffin.m.Name + "（可转入：" + names + "）", @() S.queueCastleForge(town, job, pet, true, coffin.m.PaleID + ""));
                ++shown;
            }
            if (shown == 0)
                _screen.Text += "\n\n陵寝里没有可传承新吞魂特质的候补棺椁。";
            break;
        case "enchant":
            local active = this.activeEnchants();
            local switching = active.len() >= this.enchantCap();
            foreach (e in this.Enchants)
            {
                local enchant = e;
                _screen.Text += "\n\n【" + e.Name + "】" + e.Desc;
                if (this.get("Enchant." + e.Key) != 0)
                    continue;
                if (switching && this.countItems("misc.pale_jade") >= 1)
                {
                    if (active.len() == 1)
                    {
                        local prev = active[0];
                        this.option(_screen, "改为【" + e.Name + "】· 1 枚魂玉", function()
                        {
                            if (!S.removeMaterial("jade"))
                                return null;
                            S.set("Enchant." + prev.Key, 0);
                            S.set("Enchant." + enchant.Key, 1);
                            return "魂炉里的碧火换了颜色，新的铭文沿着炉壁亮起。\n\n（术法改为【" + enchant.Name + "】）";
                        });
                    }
                    else
                    {
                        foreach (cur in active)
                        {
                            local prev = cur;
                            this.option(_screen, "用【" + e.Name + "】替换【" + prev.Name + "】· 1 枚魂玉", function()
                            {
                                if (S.get("Enchant." + prev.Key) == 0 || !S.removeMaterial("jade"))
                                    return null;
                                S.set("Enchant." + prev.Key, 0);
                                S.set("Enchant." + enchant.Key, 1);
                                return "魂炉里的碧火换了颜色，旧铭文隐去，新铭文随之亮起。\n\n（【" + prev.Name + "】已替换为【" + enchant.Name + "】）";
                            });
                        }
                    }
                }
                else if (!switching && this.countItems("misc.pale_jade") >= 2)
                    this.option(_screen, "淬炼【" + e.Name + "】· 2 枚魂玉", @() S.queueCastleForge(town, job, null, false, enchant.Key));
            }
            break;
        default:
            if (recipe.Pet)
                foreach (coffin in this.companyCoffins())
                {
                    if (!this.castleCanForge(job, coffin, true))
                        continue;
                    local target = coffin;
                    this.option(_screen, target.m.Name, @() S.queueCastleForge(town, job, target, true));
                }
            if (recipe.Unit)
                this.pagedUnits(_screen, this.undead().filter(@(_, bro) S.castleCanForge(job, bro, false)), this.EmbalmPage,
                    @(bro) bro.getName() + "（" + bro.getLevel() + " 级）", @(bro) S.queueCastleForge(town, job, bro, false));
            break;
    }
    return "fort_forge";
};

S.addPage("x_forge_job", "古堡魂炉", "fort_forge", @(_event, _screen) S.forgeJobPanel(_event, _screen), "@castle_forge");

local castlePanelForge = S.castlePanel;
S.castlePanel = function( _screen )
{
    if (_screen.ID != "castle_forge")
        return castlePanelForge.call(this, _screen);
    local town = this.castleHere();
    _screen.Text = this.CastleIntro;
    foreach (data in this.CastleBuildings)
        if (data.Page == "castle_forge")
            _screen.Text = data.Flavor;
    if (town == null || !this.castleHas(town, "pale_soul_furnace"))
    {
        _screen.Text = "这里没有魂炉。";
        this.option(_screen, "回到亡灵古堡", @() "@castle");
        return;
    }
    local flags = town.getFlags();
    if (flags.get("PaleForgeNotice") != false && flags.get("PaleForgeNotice") != "")
        _screen.Text += "\n\n" + flags.get("PaleForgeNotice");
    this.forgeMenuPanel(_screen, town);
    this.option(_screen, "回到亡灵古堡", @() "@castle");
};

// 宝石眼窝（冠军）：挂上宝石眼窝特质（仅补视野 +3，主动与远防已在棺椁属性中）；名器头盔 / 护甲按记录生成
local applyJadePetForge = S.applyJadePet;
S.applyJadePet = function( _pet, _entity )
{
    applyJadePetForge.call(this, _pet, _entity);
    if (this.petGet(_pet, "GemEyes") != 0 && !_entity.getSkills().hasSkill("trait.pale_gem_eyes"))
    {
        local gemTrait = ::new("scripts/skills/traits/pale_undead_gem_eyes_trait");
        gemTrait.m.PalePetMode = true;
        _entity.getSkills().add(gemTrait);
    }
    foreach (slot in ["Helmet", "Armor"])
    {
        local script = ::World.Flags.get("Pale." + this.petKey(_pet.m.PaleID, "Named" + slot));
        if (typeof script != "string" || script == "")
            continue;
        try
        {
            local item = ::new(script);
            item.m.Name = ::World.Flags.get("Pale." + this.petKey(_pet.m.PaleID, "Named" + slot + "Name"));
            foreach (key in ["ConditionMax", "StaminaModifier"])
            {
                local flag = "Pale." + this.petKey(_pet.m.PaleID, "Named" + slot + "." + key);
                if (::World.Flags.has(flag))
                    item.m[key] = key == "ConditionMax" ? ::World.Flags.getAsFloat(flag) : ::World.Flags.getAsInt(flag);
            }
            item.setCondition(item.getConditionMax());
            item.m.IsDroppedAsLoot = false;
            item.m.PaleReplica <- true;
            local items = _entity.getItems();
            local itemSlot = slot == "Helmet" ? ::Const.ItemSlot.Head : ::Const.ItemSlot.Body;
            local old = items.getItemAtSlot(itemSlot);
            if (old != null)
                items.unequip(old);
            items.equip(item);
        }
        catch (e)
        {
            ::logError("[PaleSovereign] named " + slot + ": " + e);
        }
    }
    _entity.getSkills().update();
};

// ---------------- 术法淬玉 ----------------
// 玉毒尸弹：尸弹落地生成苍白尸瘴
S.MiasmaTimeout <- 2;
S.onApplyJadeMiasma <- function( _tile, _entity )
{
    if (!::PaleSovereign.coldfireCanBurn(_entity))
        return;
    local hit = clone ::Const.Tactical.HitInfo;
    hit.DamageRegular = ::Math.rand(10, 15);
    hit.DamageArmor = 0;
    hit.DamageDirect = 1.0;
    hit.BodyPart = ::Const.BodyPart.Body;
    hit.BodyDamageMult = 1.0;
    hit.FatalityChanceMult = 0.0;
    hit.Injuries = null;
    hit.IsPlayingArmorSound = false;
    _entity.onDamageReceived(_entity, null, hit);
    if (_entity.isAlive() && !_entity.getSkills().hasSkill("effects.pale_jade_miasma"))
        _entity.getSkills().add(::new("scripts/skills/effects/pale_jade_miasma_effect"));
    if (!_entity.isHiddenToPlayer())
        ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_entity) + " 吸进了苍白尸瘴");
};

S.spawnJadeMiasma <- function( _tile )
{
    local effect = _tile.Properties.Effect;
    if (effect != null && effect.Type == "pale_jade_miasma")
    {
        effect.Timeout = ::Time.getRound() + this.MiasmaTimeout;
        return;
    }
    if (effect != null || _tile.Type == ::Const.Tactical.TerrainType.ShallowWater || _tile.Type == ::Const.Tactical.TerrainType.DeepWater)
        return;
    local miasma = {
        Type = "pale_jade_miasma",
        Tooltip = "苍白尸瘴贴着地面翻涌，只侵蚀活人的血肉",
        IsPositive = false,
        IsAppliedAtRoundStart = false,
        IsAppliedAtTurnEnd = true,
        IsAppliedOnMovement = false,
        IsAppliedOnEnter = true,
        IsByPlayer = true,
        Timeout = ::Time.getRound() + this.MiasmaTimeout,
        Callback = this.onApplyJadeMiasma,
        function Applicable( _a )
        {
            return ::PaleSovereign.coldfireCanBurn(_a);
        }
    };
    local source = "MiasmaParticles" in ::Const.Tactical ? ::Const.Tactical.MiasmaParticles : ::Const.Tactical.FireParticles;
    local particles = this.makeFieldParticles(_tile, "miasma_ground", source);
    ::Tactical.State.spawnEffectOnTile(_tile, "pale_jade_miasma", miasma, particles);
};

local placeShotForge = S.placeShot;
S.placeShot = function( _tile )
{
    placeShotForge.call(this, _tile);
    if (this.Battle == null || !this.hasEnchant("miasma"))
        return;
    foreach (tile in this.area(_tile))
    {
        try { this.spawnJadeMiasma(tile); } catch (e) { ::logError("[PaleSovereign] 苍白尸瘴: " + e); }
    }
};

// 千魂回响：前 2 次复活 / 召唤疲劳 −50%，唤起的临时亡灵带玉骨盾
S.isRaiseSkill <- function( _skill )
{
    local id = _skill.getID();
    return id == "actives.pale_summon_zombie" || id == "actives.pale_summon_skeleton" || id == "actives.bgp_necro_raise" || id == "actives.pale_soul_bind";
};

S.Mod.hook("scripts/skills/skill", function(q)
{
    q.getFatigueCost = @(__original) function()
    {
        local cost = __original();
        local s = ::PaleSovereign;
        if (s.Battle == null || !s.hasEnchant("echo") || !s.isRaiseSkill(this))
            return cost;
        local actor = this.getContainer() == null ? null : this.getContainer().getActor();
        if (actor == null || !s.isChief(actor) || ("EchoUsed" in s.Battle && s.Battle.EchoUsed >= 2))
            return cost;
        return ::Math.floor(cost * 0.5);
    };
});

local onPaleSummonedForge = S.onPaleSummoned;
S.onPaleSummoned = function( _user, _e )
{
    onPaleSummonedForge.call(this, _user, _e);
    if (this.Battle == null || !this.hasEnchant("echo") || _user == null || !this.isChief(_user))
        return;
    this.Battle.EchoUsed <- ("EchoUsed" in this.Battle ? this.Battle.EchoUsed : 0) + 1;
    if (!_e.getSkills().hasSkill("effects.pale_bone_ward"))
    {
        this.addSummonPlating(_e, 30);
        _e.getSkills().add(::new(this.SkillDir + "effects/pale_bone_ward_effect"));
    }
};

local raiseForge = ::BGP.Necro.raise;
::BGP.Necro.raise = function( _actor, _tile )
{
    local entity = raiseForge(_actor, _tile);
    if (entity != null && S.Battle != null)
        S.onPaleSummoned(_actor, entity);
    return entity;
};

// 亡潮蓄能：我方每累计击杀 4 名敌人，导师恢复 15 疲劳，下一次衰弱术与岁月诅咒免费（每场最多 3 次）
S.KillHooks.push(function( _killer, _victim )
{
    local chief = this.chief();
    if (!this.hasEnchant("tide") || _killer == null || ::MSU.isNull(_killer) || chief == null || _victim.isAlliedWith(chief))
        return;
    local faction = _killer.getFaction();
    if (faction != ::Const.Faction.Player && faction != ::Const.Faction.PlayerAnimals)
        return;
    this.Battle.TideKills <- ("TideKills" in this.Battle ? this.Battle.TideKills : 0) + 1;
    local charges = "TideCharges" in this.Battle ? this.Battle.TideCharges : 0;
    if (this.Battle.TideKills % 4 != 0 || charges >= 3)
        return;
    this.Battle.TideCharges <- charges + 1;
    this.Battle.TideFree <- true;
    local chief = this.chief();
    if (chief != null && chief.isAlive() && chief.isPlacedOnMap())
    {
        chief.setFatigue(::Math.max(0, chief.getFatigue() - 15));
        chief.setDirty(true);
        ::Tactical.EventLog.log("亡者的潮水涌回导师体内：恢复 15 点疲劳，下一次衰弱术与岁月诅咒免费。");
    }
});

foreach (script in ["scripts/skills/actives/pale_weaken", "scripts/skills/actives/bgp_necro_curse_of_ages_skill"])
{
    S.Mod.hook(script, function(q)
    {
        q.getActionPointCost = @(__original) function()
        {
            local s = ::PaleSovereign;
            if (s.Battle != null && "TideFree" in s.Battle && s.Battle.TideFree && s.isChief(this.getContainer().getActor()))
                return 0;
            return __original();
        };
        q.getFatigueCost = @(__original) function()
        {
            local s = ::PaleSovereign;
            if (s.Battle != null && "TideFree" in s.Battle && s.Battle.TideFree && s.isChief(this.getContainer().getActor()))
                return 0;
            return __original();
        };
        q.onUse = @(__original) function( _user, _targetTile )
        {
            local s = ::PaleSovereign;
            local free = s.Battle != null && "TideFree" in s.Battle && s.Battle.TideFree && s.isChief(_user);
            local result = __original(_user, _targetTile);
            if (free && result)
                s.Battle.TideFree = false;
            return result;
        };
    });
}
