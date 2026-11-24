local S = ::PaleSovereign;

// 1.7.0 防腐尸骸的通用用途：耗骸续召、急救骨髓膏、战地急修、拆解重组、拆骨充备、加固尸车

// ---------------- 耗骸续召（战斗中） ----------------
S.ExtraSummonCost <- 3;
S.extraSummonCap <- @() this.isAscended() ? 2 : 1;

S.canExtraSummon <- function( _actor )
{
    return this.isActive() && this.Battle != null && _actor != null && this.isChief(_actor)
        && ("ExtraSummons" in this.Battle ? this.Battle.ExtraSummons : 0) < this.extraSummonCap()
        && this.get("Reserve") >= this.ExtraSummonCost;
};

S.payExtraSummon <- function( _actor )
{
    if (!this.canExtraSummon(_actor) || !this.changeReserve(-this.ExtraSummonCost))
        return false;
    this.Battle.ExtraSummons <- ("ExtraSummons" in this.Battle ? this.Battle.ExtraSummons : 0) + 1;
    ::Tactical.EventLog.log(::Const.UI.getColorizedEntityName(_actor) + " 扯开一捆防腐尸骸，追加召唤（防腐尸骸剩余 " + this.get("Reserve") + " 点）");
    return true;
};

// 头、身护甲耐久同时加 _amount（召唤物战后消散，等于临时护甲）
S.addSummonPlating <- function( _e, _amount )
{
    foreach (slot in [::Const.ItemSlot.Head, ::Const.ItemSlot.Body])
    {
        local item = _e.getItems().getItemAtSlot(slot);
        if (item == null)
            continue;
        item.m.ConditionMax += _amount;
        item.setCondition(item.getCondition() + _amount);
    }
};

// 召唤 / 复活出新的临时亡灵时（术法淬玉等在别处覆盖）
S.onPaleSummoned <- function( _user, _e ) {};

// 盗墓贼 / 解剖师 / 死灵法师（活人）：骨髓膏与尸弹 AP −1、治疗 +25%
S.NecroHandlerBackgrounds <- ["background.graverobber", "background.anatomist", "background.bgp_necromancer"];
S.isNecroHandler <- function( _actor )
{
    if (_actor == null || ::MSU.isNull(_actor) || this.isUndead(_actor))
        return false;
    local background = null;
    try { background = _actor.getBackground(); } catch (e) { background = null; }
    return background != null && this.NecroHandlerBackgrounds.find(background.getID()) != null;
};

S.Mod.hook("scripts/skills/actives/pale_corpse_shot", function(q)
{
    q.onAfterUpdate = @(__original) function( _properties )
    {
        __original(_properties);
        this.m.ActionPointCost = ::PaleSovereign.isNecroHandler(this.getContainer().getActor()) ? 3 : 4;
    };
});

// ---------------- 营地：尸骸工坊 ----------------
S.MendSingle <- { Cost = 2, Pct = 0.45 };
S.MendAll <- { Cost = 4, Pct = 0.35 };
S.CoffinMendCost <- 4;
S.StripCost <- 4;
S.StripLimit <- 2;
S.SalvageCost <- 3;
S.SalvageCooldownHours <- 72;
S.Salvage <- [
    { Name = "工具", Amount = 45, Apply = @(_n) ::World.Assets.addArmorParts(_n) },
    { Name = "弹药", Amount = 150, Apply = @(_n) ::World.Assets.addAmmo(_n) },
    { Name = "医药", Amount = 30, Apply = @(_n) ::World.Assets.addMedicine(_n) }
];
S.CartCost <- { Reserve = 6, Money = 500, Tools = 15, Slots = 15, Limit = 3 };
S.PasteCost <- 2;

S.stripCount <- function( _bro )
{
    return _bro.getFlags().has("PaleStripCount") ? _bro.getFlags().getAsInt("PaleStripCount") : 0;
};

S.strippableTraits <- function( _bro )
{
    return _bro.getSkills().query(::Const.SkillType.Trait).filter(@(_, trait) !trait.isHidden()
        && trait.getID() != "trait.pale_former_comrade" && trait.getID() != "trait.pale_soul_scar"
        && trait.getID() != "trait.pale_gem_eyes");
};

S.injuredUndead <- function()
{
    return this.undead().filter(@(_, bro) bro.getHitpoints() < bro.getHitpointsMax());
};

S.mendUndead <- function( _units, _pct )
{
    foreach (bro in _units)
        bro.setHitpoints(::Math.minf(bro.getHitpointsMax(), bro.getHitpoints() + bro.getHitpointsMax() * _pct));
};

S.reserveWorkshopPanel <- function( _event, _screen )
{
    local assets = ::World.Assets;
    local reserve = this.get("Reserve");
    _screen.Text = "盐袋、骨锯与熬骨髓的铁锅都摊在火堆旁。防腐尸骸不只是填补兵员的料子，也能拆成战团处处用得上的东西。\n\n" + this.resourceLine();
    local injured = this.injuredUndead();
    if (injured.len() > 0 && reserve >= this.MendSingle.Cost)
        this.option(_screen, "战地急修 · 单名 " + this.MendSingle.Cost + " 点，恢复 45% 生命", function() { S.EmbalmPage = 0; return "@x_mend"; });
    if (injured.len() > 0 && reserve >= this.MendAll.Cost)
        this.option(_screen, "战地急修 · 全队 " + this.MendAll.Cost + " 点，受伤的常驻亡灵各恢复 35% 生命", function()
        {
            if (!S.changeReserve(-S.MendAll.Cost))
                return null;
            local units = S.injuredUndead();
            S.mendUndead(units, S.MendAll.Pct);
            return "防腐师连夜把盐浆与筋线分给每一具受损的躯壳。\n\n（" + units.len() + " 名常驻亡灵各恢复 35% 最大生命，防腐尸骸剩余 " + S.get("Reserve") + " 点）";
        });
    local pet = this.mainPet();
    if (this.oath() == this.Oath.Champion && pet != null && pet.m.Wounds > 0 && reserve >= this.CoffinMendCost)
        this.option(_screen, "棺椁抢修 · " + this.CoffinMendCost + " 点，" + pet.m.Name + " 的伤势减少 50 点", function()
        {
            if (!S.changeReserve(-S.CoffinMendCost))
                return null;
            pet.m.Wounds = ::Math.max(0, pet.m.Wounds - 50);
            pet.updateCompanion();
            return "你撬开棺盖，把熬好的骨髓膏一层层抹进冠军的裂骨。\n\n（" + pet.m.Name + " 的伤势降到 " + pet.m.Wounds + "%）";
        });
    if (this.undead().filter(@(_, bro) S.stripCount(bro) < S.StripLimit && S.strippableTraits(bro).len() > 0).len() > 0 && reserve >= this.StripCost)
        this.option(_screen, "拆解重组 · " + this.StripCost + " 点，移除常驻亡灵的 1 个特质", function() { S.EmbalmPage = 0; return "@x_strip"; });
    if (reserve >= this.PasteCost && assets.getStash().hasEmptySlot())
        this.option(_screen, "熬制急救骨髓膏 · " + this.PasteCost + " 点（现有 " + this.countItems("misc.pale_marrow_paste") + "）", function()
        {
            if (!::World.Assets.getStash().hasEmptySlot() || !S.changeReserve(-S.PasteCost))
                return null;
            ::World.Assets.getStash().add(::new(S.ItemDir + "misc/pale_marrow_paste_item"));
            return "铁锅里的骨髓熬成了黑亮的膏子，盛进一只小陶罐，封上蜡。\n\n（获得 1 罐急救骨髓膏，放进背包即可在战斗中使用。防腐尸骸剩余 " + S.get("Reserve") + " 点）";
        });
    if (this.worldHours() >= this.get("SalvageAfter") && reserve >= this.SalvageCost)
    {
        foreach (entry in this.Salvage)
        {
            local salvage = entry;
            this.option(_screen, "拆骨充备 · " + this.SalvageCost + " 点换 " + salvage.Amount + " " + salvage.Name, function()
            {
                if (!S.changeReserve(-S.SalvageCost))
                    return null;
                salvage.Apply(salvage.Amount);
                S.set("SalvageAfter", S.worldHours() + S.SalvageCooldownHours);
                ::World.State.updateTopbarAssets();
                return "骨片磨成补甲的碎铁和骨镞，骨髓熬成药膏，连最后一点渣都派上了用场。\n\n（消耗 " + S.SalvageCost + " 点防腐尸骸，获得 " + salvage.Amount + " " + salvage.Name + "。3 天后可再次拆骨充备）";
            });
        }
    }
    else if (this.worldHours() < this.get("SalvageAfter"))
        _screen.Text += "\n\n拆骨充备冷却到战役第 " + (this.get("SalvageAfter") / 24 + 1) + " 天。";
    local cart = this.get("CartUpgrades");
    if (cart < this.CartCost.Limit && reserve >= this.CartCost.Reserve && assets.getMoney() >= this.CartCost.Money && assets.getArmorParts() >= this.CartCost.Tools)
        this.option(_screen, "加固尸车（" + cart + " / " + this.CartCost.Limit + "）· 6 点、500 克朗、15 工具，物品栏 +15", function()
        {
            if (!S.changeReserve(-S.CartCost.Reserve))
                return null;
            ::World.Assets.addMoney(-S.CartCost.Money);
            ::World.Assets.addArmorParts(-S.CartCost.Tools);
            local stash = ::World.Assets.getStash();
            stash.resize(stash.getCapacity() + S.CartCost.Slots);
            S.set("CartUpgrades", S.get("CartUpgrades") + 1);
            ::World.State.updateTopbarAssets();
            return "你用尸骸里拆出的长骨给尸车加了一层骨架，又钉上新的挡板。\n\n（物品栏 +15 格，已加固 " + S.get("CartUpgrades") + " / " + S.CartCost.Limit + " 次）";
        });
    else if (cart < this.CartCost.Limit)
        _screen.Text += "\n\n加固尸车需要 6 点防腐尸骸、500 克朗和 15 工具（已加固 " + cart + " / 3）。";
    local captives = this.slaughterableCaptives();
    if (captives.len() > 0 && reserve < this.reserveLimit())
        this.option(_screen, "宰杀俘虏 · 每名防腐尸骸 +" + this.SlaughterGain + "（仓库里有 " + captives.len() + " 名）", function() { S.EmbalmPage = 0; return "@x_slaughter"; });
    else if (captives.len() > 0)
        _screen.Text += "\n\n防腐尸骸已满，暂时不能宰杀俘虏。";
};

// 1.7.5 宰杀俘虏（捕奴 mod 的 misc.hsc_captive）：任意地点，每名 +1 点防腐尸骸；古堡献祭坑仍是 2 点
S.SlaughterGain <- 1;

S.slaughterableCaptives <- function()
{
    return ::World.Assets.getStash().getItems().filter(function( _, item )
    {
        if (item == null || item.getID() != "misc.hsc_captive")
            return false;
        try { return !item.m.HSC_Used; } catch (e) { return true; }
    });
};

S.captiveLabel <- function( _item )
{
    // 捕奴 mod 的俘虏名字里已带等级，例如“被俘的奴隶（1级）”
    local name = _item.getName();
    local champion = false;
    try { champion = _item.m.HSC_Champion == true; } catch (e) {}
    return champion && name.find("冠军") == null ? name + "（冠军）" : name;
};

S.slaughterPanel <- function( _event, _screen )
{
    _screen.Text = "俘虏被拖到盐袋旁，绳子还没解开。盗墓贼已经磨好了刀，只等你点头。宰下的血肉会和战场上收来的遗骸一起封进盐里。\n\n（选一名俘虏，宰杀后防腐尸骸 +"
        + this.SlaughterGain + "。在古堡献祭坑献祭能得 2 点。双击仓库里的俘虏则是转化为常驻行尸。" + this.resourceLine() + "）";
    local captives = this.slaughterableCaptives();
    if (captives.len() == 0)
    {
        _screen.Text += "\n\n仓库里没有俘虏了。";
        return;
    }
    if (this.get("Reserve") >= this.reserveLimit())
    {
        _screen.Text += "\n\n防腐尸骸已满。";
        return;
    }
    this.pagedUnits(_screen, captives, this.EmbalmPage, @(item) S.captiveLabel(item), function( item )
    {
        local stash = ::World.Assets.getStash();
        if (stash.getItems().find(item) == null || S.get("Reserve") >= S.reserveLimit())
            return "这名俘虏已经不在仓库里，或者防腐尸骸已满。";
        local name = item.getName();
        stash.remove(item);
        S.changeReserve(S.SlaughterGain);
        ::World.State.updateTopbarAssets();
        return "刀起刀落，没有多余的声响。盗墓贼把尸身抬进盐桶，压上石板。\n\n（" + name + " 被宰杀，防腐尸骸 +" + S.SlaughterGain + "，现有 " + S.get("Reserve") + " / " + S.reserveLimit() + " 点）";
    });
};

S.mendPanel <- function( _event, _screen )
{
    _screen.Text = "选一名受损的常驻亡灵，立刻替它填补伤口。\n\n（消耗 " + this.MendSingle.Cost + " 点防腐尸骸，恢复 45% 最大生命。" + this.resourceLine() + "）";
    this.pagedUnits(_screen, this.injuredUndead(), this.EmbalmPage,
        @(bro) bro.getName() + "（生命 " + bro.getHitpoints() + " / " + bro.getHitpointsMax() + "）",
        function( bro )
        {
            if (!S.changeReserve(-S.MendSingle.Cost))
                return null;
            S.mendUndead([bro], S.MendSingle.Pct);
            return bro.getName() + " 的裂口被新的骨肉填满。\n\n（生命 " + bro.getHitpoints() + " / " + bro.getHitpointsMax() + "，防腐尸骸剩余 " + S.get("Reserve") + " 点）";
        });
};

S.stripPanel <- function( _event, _screen )
{
    _screen.Text = "拆掉那些让你不满意的旧零件，腾出地方以后再拼新的。\n\n（选一名常驻亡灵，消耗 " + this.StripCost + " 点防腐尸骸移除 1 个特质，正面负面都可以。每名限 " + this.StripLimit + " 次）";
    local units = this.undead().filter(@(_, bro) S.stripCount(bro) < S.StripLimit && S.strippableTraits(bro).len() > 0);
    this.pagedUnits(_screen, units, this.EmbalmPage,
        @(bro) bro.getName() + "（已拆解 " + S.stripCount(bro) + " / " + S.StripLimit + "）",
        function( bro ) { S.PickUnitID = bro.getID(); return "@x_strip_pick"; });
};

S.stripPickPanel <- function( _event, _screen )
{
    local bro = this.findUndeadByID(this.PickUnitID);
    if (bro == null)
    {
        _screen.Text = "这名常驻亡灵已经不在了。";
        return;
    }
    _screen.Text = "要从 " + bro.getName() + " 身上拆掉哪一部分？\n\n（消耗 " + this.StripCost + " 点防腐尸骸，" + this.resourceLine() + "）";
    foreach (trait in this.strippableTraits(bro))
    {
        local id = trait.getID();
        local name = trait.getName();
        this.option(_screen, "拆掉【" + name + "】", function()
        {
            if (!bro.getSkills().hasSkill(id) || S.stripCount(bro) >= S.StripLimit || !S.changeReserve(-S.StripCost))
                return "防腐尸骸不足，或这个特质已经不在了。";
            bro.getSkills().removeByID(id);
            bro.getSkills().collectGarbage();
            bro.getFlags().set("PaleStripCount", S.stripCount(bro) + 1);
            local flags = bro.getFlags();
            if (flags.has("PaleTitleTrait") && flags.get("PaleTitleTrait") == id)
                S.assignUndeadTitle(bro);
            bro.getSkills().update();
            return "骨锯沿着旧缝线走了一圈，那部分躯壳被整块拆下，接口处重新封好。\n\n（" + bro.getName() + " 失去【" + name + "】，已拆解 " + S.stripCount(bro) + " / " + S.StripLimit + " 次）";
        });
    }
};

S.addPage("x_reserve", "尸骸工坊", "reserve_workshop", @(_event, _screen) S.reserveWorkshopPanel(_event, _screen));
S.addPage("x_mend", "战地急修", "reserve_workshop", @(_event, _screen) S.mendPanel(_event, _screen), "@x_reserve");
S.addPage("x_strip", "拆解重组", "reserve_workshop", @(_event, _screen) S.stripPanel(_event, _screen), "@x_reserve");
S.addPage("x_strip_pick", "拆解重组", "reserve_workshop", @(_event, _screen) S.stripPickPanel(_event, _screen), "@x_strip");
S.addPage("x_slaughter", "宰杀俘虏", "reserve_workshop", @(_event, _screen) S.slaughterPanel(_event, _screen), "@x_reserve");

local campPanelReserve = S.campPanel;
S.campPanel = function( _event, _screen )
{
    if (this.oath() != this.Oath.None)
        this.option(_screen, "尸骸工坊 · 急修、拆解、骨髓膏、拆骨充备、加固尸车、宰杀俘虏", @() "@x_reserve");
    return campPanelReserve.call(this, _event, _screen);
};
