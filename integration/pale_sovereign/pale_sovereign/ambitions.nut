local S = ::PaleSovereign;

S.ambitionDone <- function( _key )
{
    return this.get("Ambition." + _key) != 0;
};

S.ambitionScore <- function( _key )
{
    if (!this.isActive() || this.ambitionDone(_key))
        return 0;
    local day = ::World.getTime().Days;
    local oath = this.oath();
    switch (_key)
    {
        case "night_walker":
            return day < 15 ? 15 : 10;
        case "pale_banner":
            local renown = ::World.Assets.getBusinessReputation();
            return renown < 400 ? 0 : (renown < 700 ? 15 : 30);
        case "first_soul_theft":
            return oath == this.Oath.Champion ? 20 : 0;
        case "immortal_guard":
            local pet = this.mainPet();
            if (oath != this.Oath.Champion || !this.ambitionDone("first_soul_theft") || pet == null)
                return 0;
            return this.petGet(pet, "Devours") > 0 ? 15 : 8;
        case "laden_cart":
            return oath == this.Oath.Scourge ? 20 : 0;
        case "ranks_of_dead":
            if (oath != this.Oath.Scourge || !this.ambitionDone("laden_cart"))
                return 0;
            return this.undead().len() >= 2 ? 18 : 10;
        case "forbidden_glimpse":
            local chief = this.chief();
            if (chief == null || day < 60 || this.get("Ascended") != 0 || !this.hasEvolvedStaff())
                return 0;
            return day >= 100 || chief.getLevel() >= 10 ? 25 : 12;
        case "castle_taken":
            if (!("Conquest" in ::getroottable()) || day < 30 || this.targetCastle() == null)
                return 0;
            return ::World.Assets.getBusinessReputation() >= 1000 || ::Conquest.getOwnedSettlements().len() > 0 ? 20 : 10;
    }
    return 0;
};

// 攻城 mod 能攻打的城堡（军事定居点；村庄、城镇、南方城邦都不是）
S.targetCastle <- function()
{
    foreach (town in ::World.EntityManager.getSettlements())
        if (town != null && town.isAlive() && town.isMilitary() && ::Conquest.canTarget(town))
            return town;
    return null;
};

S.hasEvolvedStaff <- function()
{
    local chief = this.chief();
    local staff = chief == null ? null : this.equippedStaff(chief);
    if (staff != null && staff.getID() != "weapon.pale_staff")
        return true;
    foreach (item in ::World.Assets.getStash().getItems())
        if (item != null && ["weapon.pale_staff_champion", "weapon.pale_staff_scourge"].find(item.getID()) != null)
            return true;
    return false;
};

S.companyCoffins <- function()
{
    local coffins = ::World.Assets.getStash().getItems().filter(@(_, item) S.isCoffin(item));
    local equipped = this.mainPet();
    if (equipped != null)
        coffins.push(equipped);
    return coffins;
};

S.ambitionComplete <- function( _key )
{
    if (!this.isActive())
        return false;
    switch (_key)
    {
        case "night_walker":
            return this.get("NightWins") > this.get("NightGoalStart");
        case "pale_banner":
            return ::World.Assets.getBusinessReputation() >= 1000 || this.get("AncientRuinWins") > 0;
        case "first_soul_theft":
            if (this.get("SoulInfusions") > 0)
                return true;
            foreach (pet in this.companyCoffins())
                if (this.petGet(pet, "Devours") > 0 || this.petGet(pet, "ChampionRacial") > 0
                    || this.petGet(pet, "Inherited") > 0 || ::World.Flags.has("Pale." + this.petKey(pet.m.PaleID, "Weapon")))
                    return true;
            return false;
        case "immortal_guard":
            foreach (pet in this.companyCoffins())
                if (this.petGet(pet, "Devours") >= 2 || this.petGet(pet, "Inherited") > 0
                    || this.petGet(pet, "ChampionRacial") > 0 || ::World.Flags.has("Pale." + this.petKey(pet.m.PaleID, "Weapon")))
                    return true;
            return false;
        case "laden_cart":
            return this.get("Reserve") >= 25 && this.get("CorpseTossCount") >= 5;
        case "ranks_of_dead":
            return this.undead().len() >= 4 && this.get("UndeadSquadWins") >= 3;
        case "forbidden_glimpse":
            return this.get("Legend.Hunt") != 0 || this.get("Legend.Goblin") != 0 || this.get("Legend.Monolith") != 0;
        case "castle_taken":
            return this.get("CastleConquests") > this.get("CastleGoalStart");
    }
    return false;
};

S.pendingItem <- function( _path, _count = 1 )
{
    local key = "Reward." + _path;
    this.set(key, this.get(key) + _count);
    this.deliverAmbitionItems();
};

S.RewardItems <- [
    "tools/pale_bone_lantern", "tools/pale_battle_standard", "accessory/pale_signet",
    "misc/pale_jade_item", "misc/pale_chain_item", "loot/ancient_gold_coins_item", "weapons/ancient/ancient_sword",
    "misc/pale_bound_undead_item"
];

// 1.6.29：城堡易主随机发放的名器（红装），按路径存待领取数
S.NamedRewardPools <- ["NamedWeapons", "NamedHelmets", "NamedArmors"];

S.rewardPaths <- function()
{
    local paths = clone this.RewardItems;
    foreach (pool in this.NamedRewardPools)
        if (pool in ::Const.Items)
            foreach (path in ::Const.Items[pool])
                if (paths.find(path) == null)
                    paths.push(path);
    return paths;
};

S.namedTwoHanded <- function()
{
    local result = [];
    foreach (path in ::Const.Items.NamedWeapons)
    {
        local item = ::new(this.ItemDir + path);
        if (item.isItemType(::Const.Items.ItemType.TwoHanded) && !item.isItemType(::Const.Items.ItemType.RangedWeapon))
            result.push(path);
    }
    return result;
};

// 有空位时直接入库并返回名字（名器多在入库时才起名）；没空位返回 null
S.giveNamedNow <- function( _path )
{
    local stash = ::World.Assets.getStash();
    if (!stash.hasEmptySlot())
        return null;
    local item = ::new(this.ItemDir + _path);
    stash.add(item);
    if (stash.getItems().find(item) == null)
        return null;
    if (item.getName() == "")
    {
        try { item.setName(item.createRandomName()); } catch (e) {}
    }
    return item.getName();
};

S.randomNamed <- function( _list )
{
    return _list.len() == 0 ? null : _list[::Math.rand(0, _list.len() - 1)];
};

S.deliverAmbitionItems <- function()
{
    local stash = ::World.Assets.getStash();
    foreach (path in this.rewardPaths())
    {
        local key = "Reward." + path;
        local count = this.get(key);
        while (count > 0 && stash.hasEmptySlot())
        {
            local item = ::new(this.ItemDir + path);
            stash.add(item);
            if (stash.getItems().find(item) == null)
                break;
            this.set(key, --count);
        }
    }
};

S.amReward <- function( _ambition, _text )
{
    _ambition.m.SuccessList.push({
        id = _ambition.m.SuccessList.len() + 10,
        type = "text",
        icon = "ui/icons/special.png",
        text = _text
    });
};

S.rewardAmbition <- function( _ambition, _key )
{
    if (this.ambitionDone(_key))
        return;
    this.set("Ambition." + _key, 1);
    local oath = this.oath();
    switch (_key)
    {
        case "night_walker":
            this.pendingItem("tools/pale_bone_lantern");
            this.amReward(_ambition, "获得守夜人的骨灯");
            if (oath == this.Oath.Champion)
            {
                this.pendingItem("misc/pale_jade_item");
                this.amReward(_ambition, "获得 1 枚古代魂玉");
            }
            else
            {
                this.changeReserve(oath == this.Oath.Scourge ? 10 : 2);
                this.amReward(_ambition, oath == this.Oath.Scourge ? "补充 10 点防腐尸骸" : "获得 400 克朗与 2 点防腐尸骸");
                if (oath == this.Oath.None)
                    ::World.Assets.addMoney(400);
            }
            break;
        case "pale_banner":
            this.pendingItem("tools/pale_battle_standard");
            this.amReward(_ambition, "获得苍白战旗");
            break;
        case "first_soul_theft":
            this.pendingItem("misc/pale_chain_item");
            local lead = this.revealAncient(true);
            this.amReward(_ambition, "返还 1 条缚魂锁链。黑铁的私活此后只收 250 克朗");
            if (lead != null)
                this.amReward(_ambition, "已在地图上标出古代遗址 " + lead);
            break;
        case "immortal_guard":
            this.pendingItem("misc/pale_jade_item");
            this.pendingItem("misc/pale_chain_item");
            this.amReward(_ambition, "获得魂玉与锁链各 1 件。出战冠军获得首次受击护盾，棺椁自然恢复翻倍，贴身护卫使导师近防、远防各 +5");
            break;
        case "laden_cart":
            this.changeReserve(6);
            local stash = ::World.Assets.getStash();
            stash.resize(stash.getCapacity() + 9);
            this.amReward(_ambition, "尸骸上限 +10，补充 6 点尸骸。仓库 +9 格，尸弹疲劳消耗 20 → 16");
            break;
        case "ranks_of_dead":
            this.changeReserve(4);
            ::World.Assets.addArmorParts(10);
            this.amReward(_ambition, "修补恢复量提高至 55%，征召消耗降为 2 点尸骸。补充 4 点尸骸、10 点工具");
            break;
        case "forbidden_glimpse":
            this.pendingItem("accessory/pale_signet");
            this.revealLegendarySites();
            this.amReward(_ambition, "获得苍白印戒，地图已标出尚未攻克的飞升仪式地点");
            if (oath == this.Oath.Champion)
            {
                this.pendingItem("misc/pale_chain_item", 2);
                this.pendingItem("misc/pale_jade_item");
                this.amReward(_ambition, "获得 2 条缚魂锁链与 1 枚古代魂玉");
            }
            else if (oath == this.Oath.Scourge)
            {
                this.changeReserve(8);
                this.applyRosterLimits();
                this.amReward(_ambition, "每场最多部署 14 人（飞升后 16 人），补充 8 点防腐尸骸");
            }
            break;
        case "castle_taken":
            ::World.Assets.addMoney(600);
            this.pendingItem("misc/pale_jade_item", 2);
            this.pendingItem("misc/pale_chain_item", 2);
            this.amReward(_ambition, "获得 600 克朗、2 枚古代魂玉和 2 条缚魂锁链。此后每座统治或屠城的城堡防腐尸骸上限再 +20");
            local labels = ["名器双手武器", "名器头盔", "名器护甲"];
            foreach (i, path in [this.randomNamed(this.namedTwoHanded()), this.randomNamed(::Const.Items.NamedHelmets), this.randomNamed(::Const.Items.NamedArmors)])
            {
                if (path == null)
                    continue;
                local name = this.giveNamedNow(path);
                if (name == null)
                {
                    this.pendingItem(path);
                    this.amReward(_ambition, "获得 1 件" + labels[i]);
                }
                else
                    this.amReward(_ambition, "获得" + labels[i] + "「" + name + "」");
            }
            break;
    }
    if (_key == "night_walker" || _key == "pale_banner" || _key == "castle_taken")
        foreach (bro in this.humans())
            bro.improveMood(1.0, _ambition.getUIText() + "，野心达成");
    if (!::World.Assets.getStash().hasEmptySlot())
        foreach (path in this.rewardPaths())
            if (this.get("Reward." + path) > 0)
            {
                this.amReward(_ambition, "仓库空间不足，腾出空位后余下物品会自动入库");
                break;
            }
};

S.Mod.hook("scripts/ambitions/ambitions/battle_standard_ambition", function(q)
{
    q.onUpdateScore = @(__original) function()
    {
        if (S.isActive())
            this.m.Score = 0;
        else
            __original();
    };
});

S.Mod.hook("scripts/ambitions/ambitions/wagon_ambition", function(q)
{
    q.onReward = @(__original) function()
    {
        local stash = ::World.Assets.getStash();
        local capacity = stash.getCapacity();
        __original();
        if (S.isActive() && S.ambitionDone("laden_cart") && stash.getCapacity() != capacity)
            stash.resize(stash.getCapacity() + 9);
    };
});

S.Mod.hook("scripts/events/events/special/ambition_failed_event", function(q)
{
    q.create = @(__original) function()
    {
        __original();
        foreach (screen in this.m.Screens)
        {
            if (!("start" in screen))
                continue;
            local start = screen.start;
            screen.start = function( _event )
            {
                start.call(this, _event);
                local ambition = ::World.Ambitions.getActiveAmbition();
                if (ambition != null && ambition.getID().find("ambition.ps_") == 0)
                    this.Text = ambition.getAbandonText();
            };
        }
    };
});
