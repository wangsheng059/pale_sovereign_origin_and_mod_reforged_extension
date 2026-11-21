local S = ::PaleSovereign;

S.CurrentEvent <- "event.pale_sovereign_camp";
S.CampRequested <- false;
S.NextWorldCheck <- 0;

S.openEvent <- function( _page )
{
    if (!::World.Events.canFireEvent(true, true))
        return false;
    local event = ::World.Events.getEvent(this.CurrentEvent);
    if (event == null)
        return false;
    event.m.Page = _page;
    return ::World.Events.fire(this.CurrentEvent, false);
};

S.worldEvent <- function()
{
    local chief = this.chief();
    if (chief == null)
        return;
    local clock = ::Time.getRealTimeF();
    if (this.NextWorldCheck > clock)
        return;
    this.NextWorldCheck = clock + 0.4;

    if (this.get("PendingSoul") != 0 && !this.canUseSoul())
        this.set("PendingSoul", 0);
    if (this.canUseSoul() && this.openEvent("soul"))
        return;
    if (this.get("HarvestNotice") != 0 && this.openEvent("harvest"))
    {
        this.set("HarvestNotice", 0);
        return;
    }

    local camp = ::World.Assets.isCamping();
    local flags = ::World.Flags;
    if (camp && this.get("MortuaryFinish") != 0 && this.worldHours() >= this.get("MortuaryFinish"))
    {
        local site = this.localSite(2, true);
        if (site != null && site.Key == flags.get("Pale.MortuarySite"))
        {
            this.changeReserve(4);
            this.set("MortuaryFinish", 0);
        }
    }
    if (this.CampRequested && camp)
    {
        local page = this.campStory();
        if (this.openEvent(page))
            this.CampRequested = false;
        return;
    }

    if (::World.State.isPaused() || camp)
        return;
    local day = ::World.getTime().IsDaytime;
    if (this.oath() == this.Oath.Champion && this.canSmith() && this.nearTown(1, true) != null)
        this.openEvent("smith");
    else if (!day && this.oath() == this.Oath.Champion && this.canCrown() && this.get("CrownDeferred") == 0)
        this.openEvent("crown");
    else if (!day && this.oath() == this.Oath.Champion && this.canWhisper(this.mainPet()))
        this.openEvent("whispers");
    else if (!day && this.canLantern())
        this.openEvent("lantern");
};

S.canWhisper <- function( _pet )
{
    return _pet != null && this.petGet(_pet, "Devours") >= 2
        && this.petGet(_pet, "WhispersDone") == 0 && this.worldHours() >= this.get("WhispersAfter");
};

S.canSmith <- function()
{
    return this.countItems("misc.pale_chain") <= 1 && this.worldHours() >= this.get("SmithAfter") && this.nearTown(2, true) != null;
};

S.canCrown <- function()
{
    local pet = this.mainPet();
    return pet != null && this.get("Crown") == 0 && this.terrainForCrown()
        && (pet.m.PaleID == this.get("StarterID")
            ? this.get("GuardWins") >= 5 && this.petGet(pet, "Promoted") != 0
            : this.petGet(pet, "Elite") != 0);
};

S.canLantern <- function()
{
    local feet = ::World.State.getPlayer().getTile();
    return this.get("Lantern") == 0 && ::World.getTime().Days >= 8 && (feet.HasRoad || this.nearTown(3) != null);
};

S.campStory <- function()
{
    local oath = this.oath();
    local pet = this.mainPet();
    local chief = this.chief();
    if (this.get("Victories") > 0 && this.get("Shovels") == 0)
        return "shovels";
    if (this.canEvolve())
        return "evolve";

    local site = this.localSite(0, true);
    if (oath == this.Oath.Champion)
    {
        if (this.get("LostChampion") != 0 && this.get("EmptyCoffin") == 0 && pet == null && this.reservePet() == null)
            return "empty";
        if (this.canCrown() && (this.get("CrownDeferred") == 0 || this.localSite(1, true) != null))
            return "crown";
        if (this.canSmith())
            return "smith";
        if (!::World.getTime().IsDaytime && this.canWhisper(pet))
            return "whispers";
    }
    if (oath == this.Oath.Scourge)
    {
        local battle = this.localSite(2, true);
        if (battle != null && this.get("Reserve") <= 8 && this.get(battle.Key + "Mortuary") == 0 && this.get("MortuaryFinish") == 0)
            return "mortuary";
        if (this.get("Parts") == 0 && this.get("Reserve") >= 15 && this.undead().len() >= 2)
            return "parts";
        if (this.get("Porter") == 0 && this.get("Reserve") >= 8 && this.porters().len() >= 2)
            return "porter";
    }
    if (this.get("Dice") == 0 && this.get("Victories") >= 2 && this.diceBrother() != null
        && ((pet != null && pet.m.PaleID == this.get("StarterID")) || this.hasSkeleton()))
    {
        return "dice";
    }
    if (this.get("Apprentice") == 0 && ::World.getTime().Days >= 35 && chief.getHitpointsPct() < 0.95)
        return "apprentice";
    return "camp";
};

S.porters <- function()
{
    return this.humans().filter(@(_, bro) !::BGP.Necro.canRaiseAll(bro));
};

S.diceBrother <- function()
{
    foreach (bro in this.porters())
        if (["background.graverobber", "background.farmhand", "background.daytaler", "background.beggar"].find(bro.getBackground().getID()) != null)
            return bro;
    return null;
};

S.hasSkeleton <- function()
{
    foreach (bro in this.undead())
        if (bro.getBackground().getID() == "background.pale_skeleton")
            return true;
    return false;
};

S.option <- function( _screen, _text, _apply )
{
    _screen.Options.push({
        Text = _text,
        function getResult( _event )
        {
            local result = _apply();
            if (result == null)
                return 0;
            if (result == "@camp")
                return "camp";
            _event.m.Message = result;
            return "result";
        }
    });
};

S.setPetTitle <- function( _pet, _title )
{
    _pet.m.Name = _title + " · " + _pet.m.Name;
};

S.swapPets <- function( _reserve )
{
    local chief = this.chief();
    local items = chief.getItems();
    local stash = ::World.Assets.getStash();
    local old = items.getItemAtSlot(::Const.ItemSlot.Accessory);
    if (old != null && !this.isCoffin(old))
        return "请先把首席身上的其他饰品放回仓库。";
    stash.remove(_reserve);
    if (old != null)
        items.unequip(old);
    if (!items.equip(_reserve))
    {
        stash.add(_reserve);
        if (old != null)
            items.equip(old);
        return "棺椁尚未能换位。";
    }
    if (old != null)
        stash.add(old);
    this.set("ReservePetID", old == null ? 0 : this.petID(old));
    return _reserve.m.Name + " 随首席出战。";
};

S.campPanel <- function( _screen )
{
    local oath = this.oath();
    local pet = this.mainPet();
    local reserve = this.reservePet();
    local site = this.localSite(0, true);
    local limit = this.permanentUndeadLimit();
    local undeadCount = this.undead().len() + (limit == null ? "" : " / " + limit);
    _screen.Text = "誓约　" + this.OathNames[oath] + "\n防腐尸骸　" + this.get("Reserve") + " / " + this.ReserveLimit
        + "\n常驻亡灵　" + undeadCount
        + "　战团编制　" + ::World.getPlayerRoster().getSize() + " / " + ::World.Assets.getBrothersMax()
        + "\n缚魂锁链　" + this.countItems("misc.pale_chain") + "　古代魂玉　" + this.countItems("misc.pale_jade")
        + (site == null ? "" : "\n附近登记地点　" + site.Name);
    if (oath == this.Oath.Champion)
    {
        _screen.Text += "\n出战　" + (pet == null ? "空棺" : pet.m.Name + "（吞魂 " + this.petGet(pet, "Devours") + "/3）")
            + "\n候补　" + (reserve == null ? "无" : reserve.m.Name)
            + "\n开局护卫并肩胜仗　" + this.get("GuardWins") + " / 5";
        if (reserve != null)
            this.option(_screen, "让候补换到首席身边", @() S.swapPets(reserve));
        else
        {
            foreach (item in ::World.Assets.getStash().getItems())
            {
                if (!this.isCoffin(item))
                    continue;
                this.option(_screen, "登记候补 " + item.m.Name, function()
                {
                    S.set("ReservePetID", S.petID(item));
                    return item.m.Name + " 登记为候补。";
                });
            }
        }
        if (pet != null && pet.m.PaleID == this.get("StarterID") && this.get("GuardWins") >= 5 && this.petGet(pet, "Promoted") == 0 && this.countItems("misc.pale_jade") > 0)
            this.option(_screen, "用 1 枚魂玉晋升墓穴守卫", function()
            {
                if (!S.removeMaterial("jade"))
                    return null;
                S.petSet(pet, "Promoted", 1);
                pet.m.Name = "墓穴冠军";
                pet.updateCompanion();
                return "首席将魂玉推入守卫的胸腔。它稳稳立起长矛，向你致礼。";
            });
        if (this.get("BannerReward") != 0 && pet != null && pet.m.PaleID == this.get("StarterID"))
            this.option(_screen, "授予守卫第三面残旗", function()
            {
                S.set("BannerReward", 0);
                S.petSet(pet, "Species.4", 1);
                S.setPetTitle(pet, "执旗者");
                return "护卫将残旗系在矛上，每战首次在首席身边挨打时所受伤害减半。";
            });
    }
    if (site != null && oath != this.Oath.None)
    {
        if (this.get(site.Key + "Inspected") == 0 && (site.Kind == 1 || oath == this.Oath.Scourge))
            _screen.Options.push({
                Text = "勘察 " + site.Name,
                function getResult( _event )
                {
                    local result = S.inspectAncient(site);
                    if (result == null)
                        return "banner";
                    _event.m.Message = result;
                    return "result";
                }
            });
        if (this.canRecruitUndead(site))
        {
            this.option(_screen, "征召常驻骷髅（3 点防腐尸骸）", @() S.recruitUndead(site, true) ? "一名骷髅加入了战团。" : "无法征召。");
            this.option(_screen, "征召常驻行尸（3 点防腐尸骸）", @() S.recruitUndead(site, false) ? "一名行尸加入了战团。" : "无法征召。");
        }
    }
};

S.renderEvent <- function( _event, _screen )
{
    local pet = this.mainPet();
    local chief = this.chief();
    local assets = ::World.Assets;
    local flags = ::World.Flags;
    local after = null;
    local title = "亡灵主宰";
    local art = _screen.ID == "lantern" ? "event_43.png" : "event_33.png";
    switch (_screen.ID)
    {
        case "camp":
            title = "亡者的营地";
            this.campPanel(_screen);
            break;

        case "result":
            _screen.Text = _event.m.Message;
            this.option(_screen, "查看营地账簿", @() "@camp");
            break;

        case "harvest":
            title = "遗骸采集";
            _screen.Text = "战后清点出 " + this.get("LastCorpseCount") + " 具合格遗骸，封存 " + this.get("LastHarvest") + " 点。防腐尸骸库存 " + (this.get("Reserve") - this.get("LastHarvest")) + " → " + this.get("Reserve") + "。";
            break;

        case "soul":
            title = "锁链里的余魂";
            _screen.Text = flags.get("Pale.SoulName") + " 的遗骸还在，锁链正对着 " + pet.m.Name + " 鸣响。选定注魂方式后消耗 1 条锁链。";
            this.option(_screen, "强化躯体 · 随机三项属性各 +1", @() S.resolveSoul("body") ? "冠军的骸骨又紧实了几分。" : "这次注魂未完成。");
            if (this.petGet(pet, "Devours") < 3)
                this.option(_screen, "吞魂 · 继承该亡灵的特质", @() S.resolveSoul("soul") ? "一缕残魂沉入冠军的躯体。" : "这次注魂未完成。");
            else
                _screen.Text += "\n该冠军已吞魂 3 次。";
            this.option(_screen, "承誓 · 继承冠军加成及具名武器", @() S.resolveSoul("inherit") ? "冠军接过亡者的誓言与武艺。" : "这次注魂未完成。");
            this.option(_screen, "放走残魂，保留锁链", function() { S.set("PendingSoul", 0); return null; });
            break;

        case "shovels":
            title = "两把军铲";
            _screen.Text = "两名盗墓贼各拿出一把军铲。一人想找出守卫生前的墓碑，另一人想用盐试试这批遗骸。";
            this.option(_screen, "寻碑", function()
            {
                S.set("Shovels", 1);
                if (pet != null && pet.m.PaleID == S.get("StarterID"))
                {
                    pet.m.Wounds = 0;
                    pet.updateCompanion();
                }
                local lead = S.revealAncient();
                return lead == null ? "护卫的伤处已经处理。" : "护卫的伤处已经处理。地图上标出了 " + lead + "。";
            });
            this.option(_screen, "试封 · 取得 4 点防腐尸骸", function()
            {
                S.set("Shovels", 1);
                S.changeReserve(4);
                return "盗墓贼将盐封好的遗骸抬进马车。";
            });
            break;

        case "evolve":
            title = "法杖蜕变";
            _screen.Text = "你把骨杖横在火堆上。颅骨里的魂光回应你的誓言，法杖在火里重新成形。";
            this.option(_screen, "接过蜕变后的法杖", @() S.evolveStaff() ? "你接过了 " + (S.oath() == S.Oath.Champion ? "骸骨权杖。" : "千魂法杖。") : "法杖仍在原处。");
            break;

        case "banner":
            title = "第三面残旗";
            _screen.Text = "残旗内侧缝着仪仗队的名字。护卫看到旗后，拾起长矛，站到首席身前。";
            local site = this.localSite(1, true);
            this.option(_screen, "让它重新执旗", function()
            {
                S.set("BannerEvent", 1);
                S.set("BannerTrials", 3);
                S.set("BannerSuccess", 0);
                S.set(site.Key + "Inspected", 1);
                return "接下来三场胜仗中，护卫须至少两场与首席同场存活。达成后在营地授旗。";
            });
            this.option(_screen, "把旗留在墓里 · 取得 1 枚古代魂玉", function()
            {
                if (!S.addMaterials("jade", 1))
                    return "仓库没有空位，魂玉仍留在原处。";
                S.set("BannerEvent", 1);
                S.set(site.Key + "Inspected", 1);
                return "你从旗脚下的石盒里取出一枚古代魂玉。";
            });
            break;

        case "crown":
            title = "王座的余烬";
            _screen.Text = "深夜，" + pet.m.Name + " 在营地边缘一遍遍演练失传的皇家战技。你从它的动作里看见了沉睡的记忆。";
            if (assets.getMoney() >= 400)
                this.option(_screen, "以魂火重铸其战意（400 金，首席全属性 −15% 持续两天）", function()
                {
                    assets.addMoney(-400);
                    S.set("Crown", 1);
                    S.set("RitualUntil", S.worldHours() / 24.0 + 2.0);
                    S.setPetTitle(pet, "王座余烬");
                    pet.m.Attributes.MeleeSkill += 4;
                    pet.m.Attributes.MeleeDefense += 4;
                    S.petSet(pet, "Mastery", 1);
                    pet.updateCompanion();
                    chief.getSkills().update();
                    return "冠军永久获得 +4 近战技能、+4 近战防御，以及主手武器专精。";
                });
            this.option(_screen, "窃取 " + pet.m.Name + "（" + pet.m.Level + " 级）的战斗本能 · 永久牺牲", function()
            {
                chief.getItems().unequip(pet);
                chief.getBaseProperties().Bravery += 8;
                chief.getSkills().update();
                S.set("Crown", 1);
                S.set("LostChampion", 1);
                return "棺盖下再也没有声响。首席永久获得 +8 决心。";
            });
            this.option(_screen, "等它练完这套剑法", function() { S.set("CrownDeferred", 1); return null; });
            break;

        case "empty":
            title = "空棺回营";
            _screen.Text = "盗墓贼抬回了空棺。他们问你是去找一名精锐，还是重新唤醒一具熟悉的身躯。";
            if (assets.getMoney() >= 250)
                this.option(_screen, "花 250 金买线索", function()
                {
                    local name = S.revealAncient();
                    if (name == null)
                        return "这一带无人知道可用的遗址。";
                    assets.addMoney(-250);
                    S.set("EmptyCoffin", 1);
                    return "地图上标出了 " + name + "。";
                });
            this.option(_screen, "唤醒普通墓穴守卫", function()
            {
                local replacement = S.makeGuard(false);
                if (chief.getItems().getItemAtSlot(::Const.ItemSlot.Accessory) == null)
                    chief.getItems().equip(replacement);
                else if (assets.getStash().hasEmptySlot())
                {
                    assets.getStash().add(replacement);
                    S.set("ReservePetID", replacement.m.PaleID);
                }
                else
                    return "首席的饰品栏和仓库都没有空位。";
                S.set("EmptyCoffin", 1);
                return "一名未训练的墓穴守卫听从了你的召唤。";
            });
            break;

        case "smith":
            title = "黑铁的私活";
            _screen.Text = "铁匠认得棺上的铜箍，却没有问车里运的是什么。他愿意私下打几条锁链。";
            if (assets.getMoney() >= 350 && assets.getArmorParts() >= 10)
                this.option(_screen, "付 350 金和 10 工具，定制一条锁链", function()
                {
                    if (!S.addMaterials("chain", 1))
                        return "仓库没有空位。";
                    assets.addMoney(-350);
                    assets.addArmorParts(-10);
                    S.set("SmithAfter", S.worldHours() + 48);
                    return "铁匠交给你一条缚魂锁链。";
                });
            if (this.countItems("misc.pale_jade") > 0)
                this.option(_screen, "以一枚旧魂玉换两条锁链", function()
                {
                    if (!S.addMaterials("chain", 2))
                        return "仓库需要两个空位。";
                    S.removeMaterial("jade");
                    S.set("SmithAfter", S.worldHours() + 48);
                    return "铁匠交给你两条缚魂锁链。";
                });
            this.option(_screen, "婉拒", function() { S.set("SmithAfter", S.worldHours() + 48); return null; });
            break;

        case "whispers":
            title = "棺中低语";
            _screen.Text = "两种声音从铜箍下争先恐后地冒出，一声在发号施令，另一声在磨牙。";
            this.option(_screen, "以首席意志强行镇压", function()
            {
                S.petSet(pet, "WhispersDone", 1);
                if (::Math.rand(1, 100) <= ::Math.max(5, ::Math.min(95, ::BGP.Necro.getResolve(chief))))
                {
                    pet.m.Attributes.Bravery += 3;
                    pet.m.Attributes.MeleeSkill += 3;
                    pet.updateCompanion();
                    return "冠军平静下来，永久获得 +3 决心、+3 近战技能。";
                }
                S.set("WhispersUntil", S.worldHours() / 24.0 + 2.0);
                chief.getSkills().update();
                return "首席疲劳上限 −10，持续 2 天。";
            });
            this.option(_screen, "让强者吞噬弱者", function()
            {
                local stats = clone S.Attributes;
                local up = stats.remove(::Math.rand(0, stats.len() - 1));
                local down = stats[::Math.rand(0, stats.len() - 1)];
                pet.m.Attributes[up] += 4;
                pet.m.Attributes[down] -= 2;
                S.setPetTitle(pet, ::Math.rand(0, 1) != 0 ? "暴骨" : "冷魂");
                S.petSet(pet, "WhispersDone", 1);
                pet.updateCompanion();
                return "一种声音消失了。冠军随机一项属性 +4，另一项 −2。";
            });
            if (assets.getArmorParts() >= 5)
                this.option(_screen, "用 5 点工具加固铜箍", function()
                {
                    assets.addArmorParts(-5);
                    S.set("WhispersAfter", S.worldHours() + 72);
                    return "棺盖暂时安静了。";
                });
            break;

        case "mortuary":
            title = "封死的停尸间";
            _screen.Text = "门内还有一批盐封遗骸。门外站着抱名册的人，他们一直在等死者回家。";
            local site = this.localSite(2, true);
            if (assets.getArmorParts() >= 5)
                this.option(_screen, "开门取材（5 点工具，在这里扎营半天）", function()
                {
                    assets.addArmorParts(-5);
                    S.set(site.Key + "Mortuary", 1);
                    S.set("MortuaryFinish", S.worldHours() + 12);
                    S.set("MortuarySite", site.Key);
                    return "营地开始清理石门。让这里经过半天，库存会增加 4 点。";
                });
            this.option(_screen, "交还遗骸名册", function()
            {
                local town = S.nearTown(10000);
                if (town != null)
                    town.getFactionOfType(::Const.FactionType.Settlement).addPlayerRelation(3, "交还遗骸名册");
                S.set(site.Key + "Mortuary", 1);
                return "人们从名单上认出了自己的家人。";
            });
            break;

        case "parts":
            title = "缝合台上的多余零件";
            _screen.Text = "你把能用的骨片和筋腱摊在缝合台上。几名活人拎起铺盖，往远处挪了挪。";
            this.option(_screen, "精挑细选加固躯干（5 点防腐尸骸）", function()
            {
                if (!S.changeReserve(-5))
                    return null;
                local units = S.undead();
                local bro = units[::Math.rand(0, units.len() - 1)];
                local hp = ::Math.rand(0, 1) != 0;
                if (hp)
                    bro.getBaseProperties().Hitpoints += 15;
                else
                    bro.getBaseProperties().MeleeDefense += 5;
                bro.getSkills().update();
                S.set("Parts", 1);
                return bro.getName() + (hp ? " 永久 +15 生命。" : " 永久 +5 近战防御。");
            });
            this.option(_screen, "拆东墙补西墙", function()
            {
                foreach (bro in S.undead())
                    bro.setHitpointsPct(1.0);
                foreach (bro in S.humans())
                    bro.worsenMood(0.75, "受不了缝合台的气味");
                S.set("StenchUntil", S.worldHours() + 48);
                S.set("Parts", 1);
                return "常驻亡灵的生命全部补满。两天内，活人同伴的心情受缝合气味影响。";
            });
            this.option(_screen, "按原样封存", function() { S.set("Parts", 1); return null; });
            break;

        case "porter":
            title = "谁来扛这具胖子";
            _screen.Text = "轮班表又被人钉回了棺盖。两个抬尸的人谁也不肯先伸手。";
            this.option(_screen, "演示发力和防腐技巧（1 点防腐尸骸）", function()
            {
                if (!S.changeReserve(-1))
                    return null;
                local porters = S.porters();
                for (local i = 0; i < 2; ++i)
                {
                    porters[i].improveMood(1.0, "学会搬运防腐遗骸");
                    porters[i].getBaseProperties().RangedSkill += 2;
                    porters[i].getSkills().update();
                }
                S.set("Porter", 1);
                return "两名搬运者各永久 +2 远程技能。";
            });
            if (assets.getMoney() >= 100)
                this.option(_screen, "发 100 金封口费", function()
                {
                    assets.addMoney(-100);
                    foreach (bro in S.humans())
                        bro.improveMood(0.75, "得到了搬运赏钱");
                    S.set("Porter", 1);
                    return "抱怨声停了。";
                });
            break;

        case "lantern":
            title = "黑夜里的提灯人";
            _screen.Text = "几杆长枪挡住路口。一盏提灯伸过来，巡逻兵闻到了马车里的防腐气味。";
            this.option(_screen, "利用夜色甩开巡逻队", function()
            {
                local town = S.nearTown(10000);
                if (town != null)
                    town.getFactionOfType(::Const.FactionType.Settlement).addPlayerRelation(-2, "夜里绕过了巡逻队");
                S.set("Lantern", 1);
                return "马车趁夜色离开大路。";
            });
            if (assets.getMoney() >= 200)
                this.option(_screen, "花 200 金买路", function() { assets.addMoney(-200); S.set("Lantern", 1); return "巡逻队放行了。"; });
            this.option(_screen, "就地开战", function() { S.set("Lantern", 1); S.startPatrolFight(); return null; });
            break;

        case "dice":
            title = "少了一枚指骨的骰子";
            _screen.Text = "盗墓贼醉得站不稳。他把骰子推给不会说话的亡灵，没想到它抬手把骰子推了回来。";
            this.option(_screen, "随他们去", function()
            {
                local bro = S.diceBrother();
                bro.improveMood(0.75, "和亡灵一起掷骰子");
                bro.getBaseProperties().Bravery += 2;
                bro.getSkills().update();
                S.set("Dice", 1);
                return bro.getName() + " 永久 +2 决心。";
            });
            this.option(_screen, "严厉制止", function()
            {
                foreach (bro in S.humans())
                    bro.worsenMood(0.25, "首席禁止和亡灵掷骰子");
                chief.getBaseProperties().Bravery += 1;
                chief.getSkills().update();
                S.set("Dice", 1);
                return "首席永久 +1 决心。";
            });
            break;

        case "apprentice":
            title = "握灯的人";
            _screen.Text = "你负伤后，一名流浪亡灵法师带着提灯来到营地。他说自己可以从守夜学起。";
            if (assets.getMoney() >= 250 && ::World.getPlayerRoster().getSize() < assets.getBrothersMax())
                this.option(_screen, "付 250 金安家费收徒", function()
                {
                    local apprentice = S.spawnBrother("bgp_necromancer_background", ["armor/wizard_robe", "weapons/wooden_stick"]);
                    apprentice.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
                    assets.addMoney(-250);
                    assets.updateFormation(true);
                    S.set("Apprentice", 1);
                    return "流浪亡灵法师加入战团，占 1 个编制位。";
                });
            if (assets.getMoney() >= 75)
                this.option(_screen, "给 75 金旅费，交换遗址情报", function()
                {
                    local lead = S.revealAncient();
                    if (lead == null)
                        return "旅人没能指出一处新的遗址。";
                    assets.addMoney(-75);
                    S.set("Apprentice", 1);
                    return "旅人标出了 " + lead + "。";
                });
            break;
    }
    _event.m.Title = title;
    _screen.Text = "[img]gfx/ui/events/" + art + "[/img]" + _screen.Text;
    if (_screen.ID != "soul")
        this.option(_screen, _screen.ID == "camp" ? "收起账簿" : "回到营地",
            _screen.ID == "whispers" ? function() { S.set("WhispersAfter", S.worldHours() + 24); return null; } : @() null);
};
