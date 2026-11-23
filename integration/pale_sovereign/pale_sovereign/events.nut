local S = ::PaleSovereign;

S.CurrentEvent <- "event.pale_sovereign_camp";
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
    this.deliverAmbitionItems();
    this.followerWorldTick();
    this.castleWorldTick();
    this.conquestWorldTick();
    if (this.CastlePage != null && ::World.State.m.LastEnteredTown == null && this.openEvent(this.CastlePage))
    {
        this.CastlePage = null;
        return;
    }

    if (this.get("IntroPending") != 0)
    {
        if (::World.Events.canFireEvent(true, true) && ::World.Events.fire("event.pale_sovereign_intro", false))
            this.set("IntroPending", 0);
        return;
    }
    if (this.get("PendingSoul") != 0 && !this.canUseSoul())
        this.set("PendingSoul", 0);
    if (this.canUseSoul() && this.openEvent("soul"))
        return;
    // 1.6.19 立誓后弹出誓约事件（关掉角色界面、回到大地图时）
    if (this.get("OathNotice") != 0 && this.oath() != this.Oath.None && this.openEvent("oath"))
    {
        this.set("OathNotice", 0);
        return;
    }
    if (this.get("RangerNotice") != 0)
    {
        if (this.locationAt(this.get("RangerLeadX"), this.get("RangerLeadY")) == null)
            this.set("RangerNotice", 0);
        else if (this.openEvent("ranger_lead"))
        {
            this.set("RangerNotice", 0);
            return;
        }
    }
    if (this.get("HarvestNotice") != 0 && this.openEvent("harvest"))
    {
        this.set("HarvestNotice", 0);
        return;
    }
    local ambition = ::World.Ambitions.getActiveAmbition();
    local glimpse = ambition != null && ambition.getID() == "ambition.ps_forbidden_glimpse";
    if (!glimpse && this.canAscend() && this.openEvent("ascend"))
        return;

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

S.canAscend <- function()
{
    local chief = this.chief();
    return chief != null && this.get("Ascended") == 0 && chief.getLevel() >= 11
        && this.get("Legend.Hunt") != 0 && this.get("Legend.Goblin") != 0 && this.get("Legend.Monolith") != 0;
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
        if (this.getUndeadBackground(bro) != null && bro.getBackground().m.PaleSkeleton)
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
            if (result.slice(0, 1) == "@")
                return result.slice(1);
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
        return "请先把导师身上的其他饰品放回仓库。";
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
    return _reserve.m.Name + " 随导师出战。";
};

S.HarvestOpenings <- [
    "盗墓贼们熟练地翻检着尚有余温的战场，挑出骨架完整的倒霉鬼撒上粗盐。",
    "你抬手止住了乌鸦的盘旋，命人将还能派上用场的躯壳一一装车。",
    "战火平息后，真正的收割才刚刚开始——马车里的盐袋又沉了几分。",
    "活人忙着清点金币，而你的目光只落在那些尚未残缺的尸骸上。",
    "夜风卷过寂静的战场，又一批沉默的储备被悄然封进了裹尸布。"
];

S.campPanel <- function( _event, _screen )
{
    local oath = this.oath();
    local pet = this.mainPet();
    local reserve = this.reservePet();
    local site = this.localSite(0, true);
    local limit = this.permanentUndeadLimit();
    local undeadCount = this.undead().len() + (limit == null ? "" : " / " + limit);
    local jade = this.countItems("misc.pale_jade");
    local opening = [
        "旧棺静静停在火光之外，盐袋与锁链各安其位。两条道路尚未落定，账簿上还留着大片空白。",
        "铜箍紧锁的旧棺里传来低沉的共鸣。你翻开染血的账簿，清点着为铸就不朽冠军而筹备的一切。",
        "营地边缘弥漫着粗盐与防腐药草的刺鼻气味。你翻开厚重的名册，清点着随时准备淹没战场的亡者储备。"
    ][oath];
    _screen.Text = opening + "\n\n誓约　" + this.OathNames[oath] + "\n防腐尸骸　" + this.get("Reserve") + " / " + this.reserveLimit()
        + "\n常驻亡灵　" + undeadCount
        + "　战团编制　" + ::World.getPlayerRoster().getSize() + " / " + ::World.Assets.getBrothersMax()
        + "\n缚魂锁链　" + this.countItems("misc.pale_chain") + "　古代魂玉　" + jade
        + (site == null ? "" : "\n附近登记地点　" + site.Name);
    if (oath == this.Oath.Champion)
    {
        _screen.Text += "\n出战　" + (pet == null ? "空棺" : pet.m.Name + "（吞魂 " + this.petGet(pet, "Devours") + " / " + this.devourCap(pet) + "）")
            + "\n候补　" + (reserve == null ? "无" : reserve.m.Name)
            + "\n荒坟守卫并肩胜仗　" + this.get("GuardWins") + " / 5";
    }

    if (this.castleHere() != null)
        this.option(_screen, "进入古堡工事", @() "@castle");
    local occupied = this.findPaleTown();
    if (occupied != null && this.conquestMode(occupied) == 2)
        this.option(_screen, "亡者之城征召", @() "@conquest_recruit");
    local story = this.campStory();
    if (story != "camp")
    {
        _screen.Options.push({
            Text = "处理营地事务",
            function getResult( _event )
            {
                return story;
            }
        });
    }

    if (oath == this.Oath.Champion)
    {
        if (reserve != null)
            this.option(_screen, "让候补换到导师身边", @() S.swapPets(reserve));
        else
        {
            foreach (item in ::World.Assets.getStash().getItems())
            {
                if (!this.isCoffin(item))
                    continue;
                local coffin = item;
                this.option(_screen, "登记候补 " + coffin.m.Name, function()
                {
                    S.set("ReservePetID", S.petID(coffin));
                    return coffin.m.Name + " 登记为候补。";
                });
            }
        }
        if (pet != null && pet.m.PaleID == this.get("StarterID") && this.get("GuardWins") >= 5 && this.petGet(pet, "Promoted") == 0 && jade >= 3)
            this.option(_screen, "用 3 枚古代魂玉将荒坟守卫晋升为尸妖王", function()
            {
                if (S.countItems("misc.pale_jade") < 3)
                    return null;
                for (local i = 0; i < 3; ++i)
                    S.removeMaterial("jade");
                S.promoteGuard(pet);
                return "导师将三枚魂玉依次推入守卫的胸腔。碧光沿着肋骨爬满全身，它稳稳立起长矛，向你致礼。\n\n（晋升为尸妖王：永久 +15 生命、+5 近战技能、+5 近战防御、+10 决心）";
            });
        if (pet != null && jade > 0)
            this.option(_screen, "魂玉淬骨 · 1 枚古代魂玉，" + pet.m.Name + " 随机 4 项属性各 +2", function()
            {
                if (!S.removeMaterial("jade"))
                    return null;
                local names = S.temperPet(pet);
                return "魂玉在你掌心碎成冰冷的碧粉，被一点点抹进冠军的骨缝。枯骨发出细密的爆响，比先前更沉、更硬。\n\n（" + names + "各 +2，累计淬骨 " + S.petGet(pet, "JadeTemper") + " 次）";
            });
        if (this.get("BannerReward") != 0 && pet != null && pet.m.PaleID == this.get("StarterID"))
            this.option(_screen, "授予荒坟守卫第三面残旗", function()
            {
                S.set("BannerReward", 0);
                S.petSet(pet, "Species.4", 1);
                S.setPetTitle(pet, "执旗者");
                return "卫士将残旗系在矛杆上，眼中的魂火骤然明亮了几分。\n\n（获得专属称号与【护驾遗志】：每战首次在导师身旁遭受敌方攻击时，生命与护甲伤害减半）";
            });
    }
    if (this.undead().len() > 0)
        this.option(_screen, "常驻亡灵升阶", function() { _event.m.TierPage = 0; return "@tier_roster"; });
    if (oath == this.Oath.Scourge && jade > 0 && this.jadeTargets().len() > 0)
        this.option(_screen, "魂玉点睛 · 用 1 枚古代魂玉强化一名常驻亡灵", @() "@jade");
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
            this.option(_screen, "征召常驻亡灵（" + this.recruitCost() + " 点防腐尸骸）", function() { S.RecruitSite = site; return "@recruit"; });
        else if (this.get(site.Key + "Recruited") != 0)
            _screen.Text += "\n\n" + site.Name + " 已经征召过常驻亡灵，每处登记地点只能征召一次。";
    }
    if (oath != this.Oath.None)
        _screen.Text += "\n\n" + (site == null ? "附近没有登记地点。" : "") + this.SiteRule;
};

// 登记地点的说明（营地账簿、征召页和读档提示共用）
S.SiteRule <- "登记地点：打赢一仗的战场会自动登记（就是交战的那一格，地图上没有标记）；清剿过的古代遗址、亡灵墓地，以及随从、野心和事件给出的遗址线索也会登记。站在登记地点 2 格以内打开账簿，才能勘察和征召常驻亡灵，每处只能征召一次。";

S.jadeTargets <- function()
{
    return this.undead().filter(@(_, bro) !bro.getFlags().has("PaleJade"));
};

S.jadePanel <- function( _screen )
{
    _screen.Text = "魂玉在火光下泛着阴冷的碧光。把它碾碎、抹进哪一具躯壳，它就会比同伴多记起一分生前的力量。\n\n（选定的常驻亡灵 8 项属性各 +2、生命再 +10，每名限 1 次）";
    local targets = this.jadeTargets();
    targets.sort(@(_a, _b) _b.getLevel() <=> _a.getLevel());
    foreach (i, bro in targets)
    {
        if (i >= 6)
            break;
        local target = bro;
        this.option(_screen, target.getName() + "（" + target.getLevel() + " 级）", function()
        {
            if (target.getFlags().has("PaleJade") || !S.removeMaterial("jade"))
                return null;
            local b = target.getBaseProperties();
            b.Hitpoints += 12;
            b.Stamina += 2;
            b.Bravery += 2;
            b.Initiative += 2;
            b.MeleeSkill += 2;
            b.RangedSkill += 2;
            b.MeleeDefense += 2;
            b.RangedDefense += 2;
            target.getFlags().add("PaleJade");
            target.getSkills().update();
            return target.getName() + " 空洞的眼窝里亮起一点碧光。\n\n（8 项属性各 +2，生命再 +10）";
        });
    }
    this.option(_screen, "收起魂玉", @() "@camp");
};

S.renderEvent <- function( _event, _screen )
{
    local pet = this.mainPet();
    local chief = this.chief();
    local assets = ::World.Assets;
    local flags = ::World.Flags;
    local title = "亡灵主宰";
    local art = _screen.ID;
    local closing = true;
    switch (_screen.ID)
    {
        case "camp":
            title = "亡者的营地";
            this.campPanel(_event, _screen);
            break;

        case "tier_roster":
            title = "亡灵升阶";
            art = "ascension_rite";
            this.tierLedgerPanel(_event, _screen);
            break;

        case "tier_branch":
        case "tier_confirm":
            title = "升阶仪式";
            art = "ascension_rite";
            this.tierBranchPanel(_event, _screen);
            closing = false;
            break;

        case "castle":
        case "castle_forge":
        case "castle_forge_0":
        case "castle_forge_1":
        case "castle_forge_2":
        case "castle_forge_3":
        case "castle_tombs":
        case "castle_barracks":
        case "castle_sacrifice":
            title = "古堡";
            if (_screen.ID.find("castle_forge") == 0)
                art = "fort_forge";
            else if (_screen.ID == "castle_barracks")
                art = "fort_barracks";
            else if (_screen.ID == "castle_tombs")
                art = "fort_tombs";
            else if (_screen.ID == "castle_sacrifice")
                art = "fort_pit";
            else
                art = "fort_court";
            this.castlePanel(_screen);
            break;

        case "refine":
            title = "炼化";
            art = "soul_refine";
            closing = false;
            this.refinePanel(_screen);
            break;

        case "recruit":
            title = "征召常驻亡灵";
            art = "fort_barracks";
            closing = false;
            this.recruitPanel(_screen);
            break;

        case "refine_confirm":
            title = "炼化";
            art = "soul_refine";
            closing = false;
            this.refineConfirmPanel(_screen);
            break;

        case "shackle":
            title = "缚魂镣铐";
            art = "soul_shackle";
            closing = false;
            this.shacklePanel(_screen);
            break;

        case "soulbound":
            title = "锁魂者";
            art = "soul_muster";
            closing = false;
            this.soulboundPanel(_screen);
            break;

        case "conquest_recruit":
            title = "亡者之城";
            art = "conquest_raze";
            this.conquestRecruitPanel(_screen);
            break;

        case "conquest_governor":
            title = "冠军坐镇";
            art = "conquest_governor";
            this.governorPanel(_screen);
            break;

        case "jade":
            title = "魂玉点睛";
            this.jadePanel(_screen);
            closing = false;
            break;

        case "result":
            art = _event.m.PaleArt;
            _screen.Text = _event.m.Message;
            this.option(_screen, "翻阅亡者账簿", @() "@camp");
            break;

        case "oath":
            closing = false;
            if (this.oath() == this.Oath.Champion)
            {
                title = "冠军之誓";
                art = "oath_champion";
                _screen.Text = "你在篝火旁坐到了后半夜。法杖横放在膝上，杖头的魂火一明一灭，像在等你开口。马车里那口旧棺比平日更安静，安静得近乎恭顺。\n\n你终于念出了那句誓词。不是向任何神祇，而是向棺中那具不肯腐朽的枯骨：从今往后，你不再驱使成群的死者，只锻造一尊冠军。你会用锁链去捕捉强者濒死时的残魂，把它们一缕缕抹进它的骨缝，直到它强得足以替你挡下世间所有的刀剑。誓言落定的一刻，另一条路在你心里无声地塌了下去，再也回不去了。"
                    + "\n\n（立下【亡灵冠军】誓约，另一条路线的独有特技永久封闭，死灵精通仍可学习。缚魂锁链可在战场标记濒死强敌，胜利后为冠军注魂、吞魂或承誓；冠军路线最多 3 名常驻亡灵；古代魂玉可为冠军淬骨、晋升荒坟守卫；学会第 6 阶路线特技后，初生骷髅法杖将蜕变为骸骨权杖。）";
                this.option(_screen, "“它会是我唯一的剑。”", @() null);
            }
            else
            {
                title = "天灾之誓";
                art = "oath_scourge";
                _screen.Text = "你把法杖插进营地边的冻土，对着荒野里看不见尽头的黑暗低声立誓。没有冠军，没有王座，也不需要谁来替你挡刀——你要的是数量，是潮水，是让每一片战场都在你身后重新站起来的死者。\n\n誓词出口时，四周的风忽然停了。盗墓贼放下铲子，不安地望向远处的坟岗；马车里的盐封裹尸布轻轻鼓动，像是底下有什么东西翻了个身。你知道，从这一夜起，你走过的每一处战场都会成为你的兵源，而另一条路已经永远关上了门。"
                    + "\n\n（立下【亡灵天灾】誓约，另一条路线的独有特技永久封闭，死灵精通仍可学习。名册上限 " + ::World.Assets.getBrothersMax() + " 人、每场部署 " + ::World.Assets.getBrothersMaxInCombat() + " 人；全队可投掷防腐尸骸作尸弹；常驻亡灵数量只受名册限制；古代魂玉可为常驻亡灵点睛，营地可炼化 6 级以上常驻亡灵换取魂玉；学会第 6 阶路线特技后，初生骷髅法杖将蜕变为千魂法杖。）";
                this.option(_screen, "“让死者涨潮。”", @() null);
            }
            break;

        case "ranger_lead":
            title = "掘墓人的线索";
            art = "ranger_lead";
            closing = false;
            local lead = this.locationAt(this.get("RangerLeadX"), this.get("RangerLeadY"));
            local leadName = lead == null ? "一处古墓" : lead.getName();
            if (lead != null)
                this.focusLocation(lead);
            _screen.Text = "掘墓人首领一大早就蹲在路边，用铲尖拨弄着一片颜色发暗的野草。他抓起一把土凑到鼻子底下闻了闻，又用指甲刮开草根下面的碎石，露出半块刻着古帝国纹样的墓砖。\n\n“错不了，”他把墓砖往你手里一塞，咧嘴露出一口黄牙，“下面是空的，而且还没被人撬开过。”他在地图边缘画了个歪歪扭扭的圈，又在圈里点了三下，那是他们这一行表示“值得一挖”的暗号。"
                + "\n\n（掘墓人首领标出了 " + leadName + "。已在大地图上标出，镜头已移到那里。每 5 天标出一处未勘察的古代遗址）";
            this.option(_screen, "“记下来，我们会去的。”", @() null);
            break;

        case "harvest":
            title = "遗骸采集";
            _screen.Text = this.HarvestOpenings[::Math.rand(0, this.HarvestOpenings.len() - 1)]
                + "\n\n战后清点出 " + this.get("LastCorpseCount") + " 具合格遗骸，封存 " + this.get("LastHarvest") + " 点。防腐尸骸库存 " + (this.get("Reserve") - this.get("LastHarvest")) + " → " + this.get("Reserve") + "。";
            break;

        case "soul":
            title = "锁链里的余魂";
            closing = false;
            local species = this.get("SoulSpecies");
            local soul = species > 0 && species < this.Souls.len() ? this.Souls[species] : null;
            _screen.Text = "硝烟尚未散尽，" + flags.get("Pale.SoulName") + " 残破的遗骸仍躺在血泊之中，缠绕其上的黑铁锁链正发出急促而尖锐的嗡鸣。马车里的旧棺随之剧烈震颤，" + pet.m.Name + " 仿佛闻到了某种令它渴望已久的古老气息。\n\n趁这缕残魂尚未彻底消散，你握紧法杖，决定如何将其彻底榨干并注入冠军体内。（选定注魂方式后消耗 1 条缚魂锁链）";
            local gain = this.isAscended() && this.oath() == this.Oath.Champion ? 2 : 1;
            this.option(_screen, "强化躯体 · 随机 4 项属性各 +" + gain, @() S.resolveSoul("body") ? "冠军的骸骨又紧实了几分。" : "这次注魂未完成。");
            if (soul != null && this.canDevour(pet))
                this.option(_screen, "吞魂 · 获得【" + soul.Name + "】：" + soul.Desc, @() S.resolveSoul("soul") ? "一缕残魂沉入冠军的躯体。（获得【" + soul.Name + "】）" : "这次注魂未完成。");
            else if (soul != null && this.petGet(pet, "Species." + species) != 0)
                _screen.Text += "\n\n该冠军已拥有【" + soul.Name + "】。";
            else
                _screen.Text += "\n\n该冠军的吞魂次数已满（" + this.petGet(pet, "Devours") + " / " + this.devourCap(pet) + "）。";
            this.option(_screen, "承誓 · 继承冠军加成及具名武器", @() S.resolveSoul("inherit") ? "冠军接过亡者的誓言与武艺。" : "这次注魂未完成。");
            this.option(_screen, "放走残魂，保留锁链", function() { S.set("PendingSoul", 0); return null; });
            break;

        case "shovels":
            title = "两把军铲";
            _screen.Text = "营火噼啪作响，刚经历过第一场血战的两名盗墓贼却没有急着分赃，而是各自拎着一把沾满泥土的军铲走到了你面前。\n\n矮个子那个指着马车里的旧棺，压低声音说他在棺底摸到了半块刻着家族纹章的铜片，顺着线索或许能找到那名卫士生前的埋骨地。另一个则踢了踢地上刚收拢来的战利品，搓着手提议趁遗骸还没发臭，不如用随车带着的粗盐先封存一批，留着日后派上用场。\n\n两人各自盯着你手中的法杖，等待你的决断。";
            this.option(_screen, "“先去看看它生前的墓碑。”", function()
            {
                S.set("Shovels", 1);
                if (pet != null && pet.m.PaleID == S.get("StarterID"))
                {
                    pet.m.Wounds = 0;
                    pet.updateCompanion();
                }
                local lead = S.revealAncient();
                return "盗墓贼收起盐袋，借着火光把铜片上的纹路抄在羊皮纸上，很快在地图边缘圈出了一处荒废的古墓，顺手还替卫士重新绑紧了松脱的甲片。\n\n（" + (lead == null ? "附近没有找到可标记的遗址" : "地图上标出了 " + lead) + "；荒坟守卫的伤势已处理）";
            });
            this.option(_screen, "“把盐拿来，先封好这批遗骸。”", function()
            {
                S.set("Shovels", 1);
                S.changeReserve(4);
                return "两人立刻麻利地干起了老本行。半夜过后，车厢角落里多了几捆裹得严严实实的盐封裹尸布，空气里弥漫着刺鼻的咸腥味。\n\n（获得 4 点防腐尸骸）";
            });
            break;

        case "evolve":
            title = "法杖蜕变";
            if (this.oath() == this.Oath.Champion)
            {
                art = "evolve_champion";
                _screen.Text = "夜深人静，你将初生骷髅法杖横架在渐渐转暗的篝火之上。跳动的橘红火焰并未灼伤枯骨，反而像是遇见了天敌般剧烈蜷缩，随即被杖头那缕愈发炽烈的幽蓝魂火尽数吞没。\n\n随着你低声重申亡灵冠军的誓约，车厢里那具钉满铜箍的旧棺猛然一震，卫士的兵刃在棺内发出低沉而狂热的金属共鸣。法杖表面原本纵横交错的裂纹在魂火中寸寸弥合，粗糙的铁箍融化成暗沉的镀铜，那颗苍白的颅骨缓缓睁开空洞的眼眶，一股令人窒息的君王威压顺着杖身涌入你的掌心。它不再是荒冢里拼凑出的简陋法器，而是足以加冕并号令不朽冠军的【骸骨权杖】。";
                this.option(_screen, "“以此权杖，加冕我的冠军。”", @() S.evolveStaff() ? "初生骷髅法杖蜕变为【骸骨权杖】。" : "法杖仍在原处。");
            }
            else
            {
                art = "evolve_scourge";
                _screen.Text = "你独自走到营地边缘，将初生骷髅法杖深深插进浸满腐土与盐水的泥地之中。随着你沙哑地念出亡灵天灾的誓词，四周温暖的篝火骤然熄灭，刺骨的寒意瞬间席卷了整座营地。\n\n无数肉眼难辨的苍白虚影从地底与黑暗中涌出，像饥饿的蝗虫般疯狂钻进杖身的裂隙。枯骨在成百上千道凄厉的哀嚎与低语中扭曲、延展，原本松动的铁箍被迫重铸成密密麻麻的符环，勉强锁住其中翻涌不息的亡魂浪潮。彻骨的阴冷顺着你的指尖蔓延至全身——从今往后，整片战场都将回荡着【千魂法杖】的无尽诅咒。";
                this.option(_screen, "“听吧，亡者的潮水正在呼唤。”", @() S.evolveStaff() ? "初生骷髅法杖蜕变为【千魂法杖】。" : "法杖仍在原处。");
            }
            break;

        case "banner":
            title = "第三面残旗";
            _screen.Text = "清理完地宫深处的瓦砾后，盗墓贼从一具倒塌的石像臂弯里扯出了一面早已褪色的残旗。布料虽然脆得一碰就碎，内侧却用金线密密麻麻地缝着一支古帝国仪仗队的番号与名录。\n\n你正要将其收入行囊，身后的卫士却突然停住了脚步。它空洞的眼窝死死盯着残旗上的徽记，喉骨间发出几声生锈齿轮般的轻响。下一刻，它竟无视了你的指令，自己弯腰拾起长矛，沉稳地横跨一步，挡在了你的身前。";
            local site = this.localSite(1, true);
            this.option(_screen, "“既然你还记得怎么护驾，就重新执起这面旗吧。”", function()
            {
                S.set("BannerEvent", 1);
                S.set("BannerTrials", 3);
                S.set("BannerSuccess", 0);
                S.set(site.Key + "Inspected", 1);
                return "你将残旗系在卫士的矛杆上，它眼中的魂火骤然明亮了几分。\n\n（接下来 3 场胜仗中，让荒坟守卫至少 2 场与导师一同出战并存活，完成后在营地授旗，解锁专属称号与【护驾遗志】）";
            });
            this.option(_screen, "“死人不需要旧日荣耀，把旗留在墓里。”", function()
            {
                if (!S.addMaterials("jade", 1))
                    return "仓库没有空位，魂玉仍留在原处。";
                S.set("BannerEvent", 1);
                S.set(site.Key + "Inspected", 1);
                return "你令卫士退下，将残旗盖回石棺，却在旗杆折断的底座里摸出了一块触手冰凉的碧石。\n\n（获得 1 枚古代魂玉）";
            });
            break;

        case "crown":
            title = "王座的余烬";
            _screen.Text = "深夜，守夜的兄弟轻手轻脚地叫醒了你。顺着他颤抖的手指望去，月光下的营地边缘，" + pet.m.Name + " 正独自站在一块空地上，手中握着兵刃，一遍又一遍地演练着一套早已被世人遗忘的皇家战技。\n\n它的动作起初僵硬生涩，随着每一次劈砍与转身，那具枯骨却仿佛重新找回了昔日驰骋沙场的韵律。你走近几步，清晰地感觉到一缕残存的王室武艺记忆正盘踞在它的颅骨深处，蠢蠢欲动。";
            if (assets.getMoney() >= 400)
                this.option(_screen, "“以我的魂火，为你重铸昔日的战意。”（400 金币，导师 2 天内全属性 −15%）", function()
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
                    return "你咬破指尖，将昂贵的死灵秘药与自身魂火一并灌入 " + pet.m.Name + " 的躯体。漫长的仪式几乎榨干了你的精力，但当它重新抬起头时，每一寸骨骼都散发着令人胆寒的锋芒。\n\n（冠军获得专属称号，永久 +4 近战技能、+4 近战防御，并获得主手武器专精；导师 2 天内全属性 −15%）";
                });
            this.option(_screen, "“把你的本能交给我，我比你更需要它。”（永久牺牲 " + pet.m.Name + "，" + pet.m.Level + " 级）", function()
            {
                local name = pet.m.Name;
                chief.getItems().unequip(pet);
                chief.getBaseProperties().Bravery += 8;
                chief.getSkills().update();
                S.set("Crown", 1);
                S.set("LostChampion", 1);
                return "你抬手按住它的天灵盖，强行抽干了那缕沉淀百年的战魂记忆。" + name + " 的身躯在你脚下寸寸崩解，化作一捧再无生机的尘土，而你的双眸中却燃起了前所未有的冰冷清明。\n\n（导师永久 +8 决心）";
            });
            this.option(_screen, "“先别打扰它，等它练完这套剑法。”", function()
            {
                S.set("CrownDeferred", 1);
                return "你示意守夜人退回篝火旁，静静看着它在月光下收招归位。\n\n（下次在古代遗址扎营时可再次触发）";
            });
            break;

        case "empty":
            title = "空棺回营";
            _screen.Text = "两名盗墓贼垂头丧气地把那具沉重的旧棺抬回了营地。棺盖大敞着，里面空空如也，只剩下几片碎裂的骨渣和一缕尚未散尽的青烟。\n\n曾经替你挡下无数刀锋的冠军已经彻底化作尘埃。矮个子盗墓贼抹了把脸上的灰，小心翼翼地问你：是花钱去黑市打听另一处藏着古代精锐的古墓，还是干脆就地唤醒一具普通的卫士，先填上身边的空缺。";
            if (assets.getMoney() >= 250)
                this.option(_screen, "“花 250 金，去买一处古墓精锐的线索。”", function()
                {
                    local name = S.revealAncient();
                    if (name == null)
                        return "盗墓贼在黑市转了一夜，这一带却无人知道可用的遗址。（未花费金币）";
                    assets.addMoney(-250);
                    S.set("EmptyCoffin", 1);
                    return "盗墓贼揣上钱袋钻进夜色，天亮前带回了一张画满红叉的旧地图，上面标着一处据说沉睡着古代悍将的遗址。\n\n（消耗 250 金币，地图上标出了 " + name + "）";
                });
            this.option(_screen, "“先唤醒一具普通的卫士顶上。”", function()
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
                    return "导师的饰品栏和仓库都没有空位。";
                S.set("EmptyCoffin", 1);
                return "你用残存的魂火拼凑出一具新的骨架，虽不如往日那般悍勇，但至少旧棺不再空荡荡的。\n\n（获得 1 名未训练的荒坟守卫）";
            });
            break;

        case "smith":
            title = "黑铁的私活";
            _screen.Text = "镇上的铁匠蹲在马车旁敲了敲旧棺上的铜箍，浑浊的眼睛里闪过一丝精明。他没有多问车厢里运的究竟是死人还是货物，只是吐了口唾沫，低声说这种老式封魂箍配的锁链如今市面上不好找，但他炉子里正好还有几块掺了墓土的生铁，愿意私下替你打几条。\n\n话音未落，他又瞥了眼你腰间隐约泛着碧光的布袋，显然是个识货的老手。";
            local price = this.ambitionDone("first_soul_theft") ? 250 : 350;
            if (assets.getMoney() >= price && assets.getArmorParts() >= 10)
                this.option(_screen, "“" + price + " 金再加 10 点工具，给我打一条结实的。”", function()
                {
                    if (!S.addMaterials("chain", 1))
                        return "仓库没有空位。";
                    assets.addMoney(-price);
                    assets.addArmorParts(-10);
                    S.set("SmithAfter", S.worldHours() + 240);
                    return "铁匠拉上铺门，叮叮当当忙活了半宿。天亮时，一条沉重冰冷的黑铁锁链被油布包着塞进了你的马车。\n\n（消耗 " + price + " 金币与 10 点工具，获得 1 条缚魂锁链；墓土生铁用完了，10 天内不会再有铁匠接这种活）";
                });
            if (this.countItems("misc.pale_jade") > 0)
                this.option(_screen, "“这块古代魂玉归你，给我打两条锁链。”", function()
                {
                    if (!S.addMaterials("chain", 2))
                        return "仓库需要两个空位。";
                    S.removeMaterial("jade");
                    S.set("SmithAfter", S.worldHours() + 240);
                    return "铁匠接过魂玉对着油灯照了照，嘴角咧开一个贪婪的弧度，二话不说便从炉底拖出了两条早已备好的上等锁链。\n\n（消耗 1 枚古代魂玉，获得 2 条缚魂锁链）";
                });
            this.option(_screen, "“太贵了，我还不缺这东西。”", function()
            {
                S.set("SmithAfter", S.worldHours() + 48);
                return "铁匠耸耸肩，转身回到了火炉边，权当什么也没看见。";
            });
            break;

        case "whispers":
            title = "棺中低语";
            _screen.Text = "半夜的营地安静得反常，连虫鸣都停了。唯独马车里的旧棺剧烈地晃动起来，铜箍发出不堪重负的吱嘎声。\n\n你掀开油布走近，听见两种截然不同的声音正从棺缝里争先恐后地挤出来——一声低沉威严，仿佛在沙场上厉声号令军阵；另一声却尖锐疯狂，夹杂着令人毛骨悚然的磨牙声。被你强行塞进同一具躯壳里的数道残魂，正在为争夺主导权互相撕咬。";
            this.option(_screen, "“都给我闭嘴！这具躯壳只听我一人的号令。”", function()
            {
                S.petSet(pet, "WhispersDone", 1);
                S.set("WhispersUntil", S.worldHours() / 24.0 + 2.0);
                chief.getBaseProperties().Bravery += 3;
                chief.getSkills().update();
                pet.m.Attributes.MeleeSkill += 1;
                pet.m.Attributes.Stamina += 1;
                pet.updateCompanion();
                return "你将法杖重重顿在棺盖上，倾泻而出的冰冷意志如重锤般砸进棺内。凄厉的嘶吼戛然而止，残魂在你的威压下彻底驯服，你的心神经此一役愈发坚不可摧，只是短期内难免有些力竭。\n\n（导师 2 天内全属性 −10%，导师永久 +3 决心；冠军永久 +1 近战技能、+1 疲劳）";
            });
            this.option(_screen, "“随它们去，让更强的那个吞掉弱者。”", function()
            {
                local names = { Hitpoints = "生命", Stamina = "疲劳", Bravery = "决心", Initiative = "主动值", MeleeSkill = "近战技能", RangedSkill = "远程技能", MeleeDefense = "近战防御", RangedDefense = "远程防御" };
                local stats = clone S.Attributes;
                local up = stats.remove(::Math.rand(0, stats.len() - 1));
                local down = stats[::Math.rand(0, stats.len() - 1)];
                pet.m.Attributes[up] += 10;
                pet.m.Attributes[down] -= 5;
                S.setPetTitle(pet, ::Math.rand(0, 1) != 0 ? "暴骨" : "冷魂");
                S.petSet(pet, "WhispersDone", 1);
                pet.updateCompanion();
                return "棺内的撞击声持续了整整半个时辰，最终只剩下一声充满暴戾气息的低吼。弱小的残魂已被彻底咀嚼殆尽，留下的意志变得前所未有地极端而凶悍。\n\n（冠军获得专属称号，" + names[up] + " +10，" + names[down] + " −5）";
            });
            if (assets.getArmorParts() >= 5)
                this.option(_screen, "“拿工具来，把铜箍再钉死几寸。”（5 点工具）", function()
                {
                    assets.addArmorParts(-5);
                    S.set("WhispersAfter", S.worldHours() + 72);
                    return "盗墓贼满头大汗地钉进几根铁楔，棺材终于重新安静了下来，只是里面的低语恐怕迟早还会再次响起。";
                });
            break;

        case "mortuary":
            title = "封死的停尸间";
            _screen.Text = "在古战场边缘扎营时，斥候在半塌的石砌地窖里发现了一间被木板封死的停尸间。门缝里飘出熟悉的粗盐与防腐药草味，里面整齐码放着一批尚未腐烂的遗骸。\n\n可就在你们准备撬门时，几个衣衫褴褛的乡民抱着发黄的名册找了过来。他们站在火光边缘不敢靠近，只哽咽着说里面躺着他们的父兄，恳求你们行行好，让他们把亲人带回去入土为安。";
            local site = this.localSite(2, true);
            if (assets.getArmorParts() >= 5)
                this.option(_screen, "“死人归我管，把门撬开。”（5 点工具，在此扎营半天）", function()
                {
                    assets.addArmorParts(-5);
                    S.set(site.Key + "Mortuary", 1);
                    S.set("MortuaryFinish", S.worldHours() + 12);
                    S.set("MortuarySite", site.Key);
                    return "乡民们在盗墓贼的呵斥下哭着退进了夜色。你们花了半天工夫和不少工具拆开封板，将里面保存完好的遗骸尽数装车。\n\n（在这里继续扎营半天后，获得 4 点防腐尸骸）";
                });
            this.option(_screen, "“把名册和门钥匙留给他们，我们走。”", function()
            {
                local town = S.nearTown(10000);
                if (town != null)
                    town.getFactionOfType(::Const.FactionType.Settlement).addPlayerRelation(3, "交还遗骸名册");
                S.set(site.Key + "Mortuary", 1);
                return "你拦住了蠢蠢欲动的盗墓贼。那些乡民千恩万谢地接过名册，临走前反复念叨着这支怪异的佣兵团倒还有几分良心。\n\n（附近定居点的关系改善）";
            });
            break;

        case "parts":
            title = "缝合台上的多余零件";
            _screen.Text = "连日征战下来，马车里囤积的防腐尸骸早已堆得快要顶破帆布。趁着今夜扎营，你在火堆旁支起两张厚重的木板当作缝合台，将精心挑选出来的粗壮股骨、完好肋排与浸过药水的柔韧筋腱一字排开。暗红的火光下，几名常驻亡灵像木桩般安静地排成一列，任由你拿着沾满黑油的弯针、铁钳与铜钉在它们身上反复比划。\n\n刺鼻的腐臭混合着浓烈的粗盐气味顺风飘散，铁钩刮过骨面的尖锐摩擦声更是让人头皮发麻。几个正在啃干粮的活人兄弟终于彻底忍受不住，黑着脸骂骂咧咧地拎起铺盖，默不作声地往逆风处又挪了好几丈远。";
            this.option(_screen, "“挑最好的料子，把它的躯干再加固一层。”（5 点防腐尸骸）", function()
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
                return "你耗费了不少库存，用双层骨板与浸盐筋腱彻底重塑了 " + bro.getName() + " 的胸膛，它如今站起来像堵移动的石墙。\n\n（" + bro.getName() + (hp ? " 永久 +15 生命）" : " 永久 +5 近战防御）");
            });
            this.option(_screen, "“用边角料把所有伤员都补一补。”", function()
            {
                foreach (bro in S.undead())
                    bro.setHitpointsPct(1.0);
                foreach (bro in S.humans())
                    bro.worsenMood(0.75, "受不了缝合台的气味");
                S.set("StenchUntil", S.worldHours() + 48);
                S.set("Parts", 1);
                return "你动作麻利地替所有受损的亡灵缝合了裂口，省下了珍贵的储备，代价是整座营地接下来两天都弥漫着令人作呕的酸臭味。\n\n（不消耗储备，常驻亡灵的生命全部补满；活人兄弟 2 天内心情下降）";
            });
            this.option(_screen, "“算了，把这些都封回去，留着上战场用。”", function()
            {
                S.set("Parts", 1);
                return "你收起针线，将多余的材料重新塞回盐袋。";
            });
            break;

        case "porter":
            title = "谁来扛这具胖子";
            _screen.Text = "天还没彻底黑透，营地中央就爆发出一阵激烈的争吵。原本贴在马车辕上的搬运轮班表，不知被谁用一把生锈的匕首狠狠钉回了旧棺的盖子上。篝火旁，两名负责替战团搬运防腐尸骸的活人兄弟正梗着脖子互相推搡，谁也不肯先伸手去碰地上那具又沉又胖、裹尸布还不断往外渗着浑浊盐水的尸弹。\n\n“上回就是老子背着它走了五里烂泥路，连裤裆都腌透了！”其中一人气急败坏地吼道，“今天轮也该轮到你扛着它上战场了！”另一个也不甘示弱，当场撸起袖子破口大骂。周围的兄弟们纷纷捂着鼻子看热闹，眼看两人就要抄起家伙动真格的。";
            this.option(_screen, "“蠢货，连尸体都不会搬。看好了。”（1 点防腐尸骸）", function()
            {
                if (!S.changeReserve(-1))
                    return null;
                local porters = S.porters();
                local lines = [];
                for (local i = 0; i < 2; ++i)
                {
                    local bro = porters[i];
                    bro.improveMood(1.0, "学会搬运防腐遗骸");
                    if (::Math.rand(0, 1) != 0)
                    {
                        bro.getBaseProperties().RangedSkill += 2;
                        lines.push(bro.getName() + " 永久 +2 远程技能");
                    }
                    else
                    {
                        bro.getBaseProperties().Stamina += 3;
                        lines.push(bro.getName() + " 永久 +3 疲劳上限");
                    }
                    bro.getSkills().update();
                }
                S.set("Porter", 1);
                return "你冷哼一声，亲自挑出一具尸骸，当场演示了如何借力扛肩、如何攥紧衣领抛出最远的弧线。两人看得目瞪口呆，吵架的火气顿时消了大半，顺便还学到了几分实打实的发力窍门。\n\n（" + lines[0] + "；" + lines[1] + "）";
            });
            if (assets.getMoney() >= 100)
                this.option(_screen, "“一人五十金，拿了钱就闭嘴干活。”（100 金币）", function()
                {
                    assets.addMoney(-100);
                    foreach (bro in S.humans())
                        bro.improveMood(0.75, "得到了搬运赏钱");
                    S.set("Porter", 1);
                    return "叮当作响的金币瞬间平息了这场风波。两人麻利地揣好赏钱，甚至开始互相客气起来。\n\n（全团活人兄弟心情提升）";
                });
            if (this.undead().len() > 0)
                this.option(_screen, "“既然活人娇气，就让骷髅来搬。”", function()
                {
                    S.set("Porter", 1);
                    return "你挥手唤来几名常驻亡灵接手苦力，活人兄弟们顿时松了口气，只是亡灵们在行军途中显得格外笨重。";
                });
            break;

        case "lantern":
            title = "黑夜里的提灯人";
            _screen.Text = "夜色浓稠如墨，车队刚拐过一处林间岔口，几杆雪亮的长枪便骤然从道旁的灌木丛里刺了出来，紧接着一盏耀眼的油灯高高举到了马车正前方。一队神色警惕的城镇巡逻兵死死拦住了去路，领头的老队长皱着眉头凑近车厢，用力吸了两口潮湿的夜风，原本还算客气的脸色瞬间阴沉得能滴出水来。\n\n“大半夜不点灯赶路，拉着一口钉满黑铁铜箍的旧棺材，车斗里还飘着死人堆里才有的粗盐与腐肉味……”他缓缓拔出半截长剑，冷冷地盯着你兜帽下的阴影，身后的长枪手也齐刷刷地压低了枪尖，“别装哑巴，掀开油布，让我们瞧瞧里面装的究竟是什么货色。”";
            this.option(_screen, "“熄灭营灯，趁夜色甩开他们。”", function()
            {
                local town = S.nearTown(10000);
                if (town != null)
                    town.getFactionOfType(::Const.FactionType.Settlement).addPlayerRelation(-2, "夜里绕过了巡逻队");
                S.set("Lantern", 1);
                return "你低喝一声，借着自己远胜常人的夜间视力，领着车队猛然拐进一条漆黑的林间小道。巡逻兵举着提灯在泥泞里徒劳地追了几十步，只能对着黑暗破口大骂。\n\n（无损脱身，与最近城镇的关系微降）";
            });
            if (assets.getMoney() >= 200)
                this.option(_screen, "“夜路难走，这点茶水钱请诸位行个方便。”（200 金币）", function()
                {
                    assets.addMoney(-200);
                    S.set("Lantern", 1);
                    return "沉甸甸的钱袋准确落进队长怀里。他掂了掂分量，眼神立刻柔和了下来，挥手示意手下收起长枪：“看来只是批腌坏了的咸鱼，赶紧滚出我的地界。”";
                });
            this.option(_screen, "“正好，马车里还缺几具新鲜货色。”（夜间遭遇战）", function() { S.set("Lantern", 1); S.startPatrolFight(); return null; });
            break;

        case "dice":
            title = "少了一枚指骨的骰子";
            _screen.Text = "深夜的营地角落里突然爆出一阵古怪而放肆的哄笑声，打破了往日的死寂。你披上黑袍循声走去，只见那名平日里最爱吹牛的盗墓贼喝得满脸通红、东倒西歪，正抱着半壶劣质麦酒，摇摇晃晃地蹲在一具站岗的亡灵面前，硬拉着这位不会说话的死人掷骰子消遣。\n\n原本只是醉汉的胡闹，可当盗墓贼把破木碗推到脚边时，令人意外的一幕发生了：那具沉默的亡灵竟然真的咔哒咔哒地弯下腰，用一只缺了半截指骨的枯手稳稳抓起木碗摇了两下，随即精准地将骰子推了回来，赫然掷出了个满点。盗墓贼拍着大腿哈哈大笑，连周围几个原本对亡灵避之不及的活人兄弟也忍不住凑过来啧啧称奇。";
            this.option(_screen, "“随他们去吧，习惯了死人，上战场才不会腿软。”", function()
            {
                local bro = S.diceBrother();
                bro.improveMood(0.75, "和亡灵一起掷骰子");
                bro.getBaseProperties().Bravery += 2;
                bro.getSkills().update();
                S.set("Dice", 1);
                return "你没有打断这场荒诞的赌局。那天晚上，" + bro.getName() + " 输光了兜里的铜板，胆子却比从前壮了不少。\n\n（" + bro.getName() + " 心情变好，永久 +2 决心）";
            });
            this.option(_screen, "“够了！战团不是酒馆，滚回去守夜。”", function()
            {
                foreach (bro in S.humans())
                    bro.worsenMood(0.25, "导师禁止和亡灵掷骰子");
                chief.getBaseProperties().Bravery += 1;
                chief.getSkills().update();
                S.set("Dice", 1);
                return "你冰冷的呵斥瞬间冻住了营地的笑声。盗墓贼讪讪地收起骰子溜回铺盖，所有人都重新记起了你究竟是什么人。\n\n（活人兄弟心情微降，导师永久 +1 决心）";
            });
            break;

        case "apprentice":
            title = "握灯的人";
            _screen.Text = "今夜寒风刺骨，你身上的旧伤隐隐作痛。就在营火快要燃尽时，一个提着幽绿油灯的瘦削身影穿过警戒线，安静地停在了火光边缘。\n\n来人穿着一件沾满泥浆的旧黑袍，眼神里既没有圣职的狂热，也没有常人的恐惧。他盯着你身旁的骷髅法杖看了许久，低声道出你早已失传的旧名，并表示自己慕名寻了很久——哪怕只替你打下手、看管盐袋与召唤杂兵，也愿追随你见识真正的死灵秘术。";
            if (assets.getMoney() >= 250 && ::World.getPlayerRoster().getSize() < assets.getBrothersMax())
                this.option(_screen, "“付你一笔安家费。拿好提灯，替我分担些杂活。”（250 金币）", function()
                {
                    local apprentice = S.spawnBrother("bgp_necromancer_background", ["armor/wizard_robe", "weapons/wooden_stick"]);
                    apprentice.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
                    assets.addMoney(-250);
                    assets.updateFormation(true);
                    S.set("Apprentice", 1);
                    return "流浪亡灵法师深深鞠了一躬，熄灭了旧灯，安静地站到了战团队列之中。多一双懂行的手，战场上的死人也能听话几分。\n\n（招募 1 名亡灵法师，占 1 个编制位）";
                });
            if (assets.getMoney() >= 75)
                this.option(_screen, "“我不需要学徒。拿上盘缠，把你知道的遗址消息留下。”（75 金币）", function()
                {
                    local lead = S.revealAncient();
                    if (lead == null)
                        return "他想了很久，却没能指出一处新的遗址。（未花费金币）";
                    assets.addMoney(-75);
                    S.set("Apprentice", 1);
                    return "他略显失落地收下金币，临行前在地图上为你标出了一处人迹罕至的古墓位置，随后重新消失在苍茫的夜色中。\n\n（地图上标出了 " + lead + "）";
                });
            break;

        case "ascend":
            title = "飞升仪式";
            closing = false;
            _screen.Text = "通过对传奇生物、人类、绿皮和亡灵的不断研究，你已经站在这个位面亡灵术的巅峰。\n\n狩猎场里那头古老神兽崩碎时溢出的狂野残魂，让你彻底洞悉了血肉演化与野性本源的终极奥秘；哥布林王城深处那些诡谲恶毒的萨满巫术，替你补全了诅咒、瘟疫与灵魂侵蚀的最后一块拼图；而踏平黑色巨石、击碎古帝国千年死寂的那一刻，无数沉睡在历史尘埃中的幽冥伟力尽数涌入你的识海，终于为你亲手推开了超越生死界限的最后一道大门。\n\n今夜，营地的篝火无风自灭，刺骨的寒霜沿着马车车轮悄然蔓延，天穹之上的群星在幽蓝的雾霭中黯然失色。营地里无论是活人还是亡灵，都本能地低下头颅，不敢直视法阵中央的身影。你独自站在以古帝国铭文、黑盐与传奇魔血绘就的巨大仪轨之中，手中的法杖发出震耳欲聋的共鸣。你无比清晰地感觉到，那具曾饱受围剿、流血与衰老折磨的凡人躯壳早已成了束缚灵魂的沉重枷锁——只要念出最后一句禁忌真名，你便能彻底褪去肉身凡胎，踏上凌驾于生死之上的不朽神座。";
            _screen.Options.push({
                Text = "“凡胎已尽，今夜我便踏上神座。”（战役胜利结束）",
                function getResult( _event )
                {
                    S.set("Ascended", 2);
                    local c = S.chief();
                    if (c != null)
                        c.getSkills().update();
                    ::World.State.getMenuStack().pop(true);
                    ::World.State.showGameFinishScreen(true);
                    return 0;
                }
            });
            this.option(_screen, "“尘世的清算尚未结束，我还不能离开。”", function()
            {
                S.set("Ascended", 1);
                chief.setTitle("苍白主宰");
                chief.getBaseProperties().Bravery += 10;
                chief.getSkills().update();
                local route = S.oath() == S.Oath.Champion
                    ? "冠军吞魂上限 +1，缚魂锁链可标记生命不高于 50% 的目标，“强化躯体”改为随机 4 项属性各 +2"
                    : S.oath() == S.Oath.Scourge
                        ? "所有常驻亡灵与复活单位 +20 生命、+10% 伤害，防腐尸骸上限提至 " + S.reserveLimit()
                        : "尚未立誓，路线加成在立誓后生效";
                return "你没有念出那句彻底割裂尘世的真名。相反，在法阵的光芒攀升至顶峰的刹那，你猛然收紧五指，将那股足以让寻常凡人瞬间化作飞灰的磅礴神性洪流，硬生生压回了这具残破却熟悉的躯壳之中。狂暴的幽蓝魂火顺着你的血脉疯狂奔涌，骨骼在令人牙酸的脆响中重铸，衰老与疲惫被彻底逐出体外，原本跳动的心脏在胸腔里归于死一般的沉寂，取而代之的是一团永不熄灭的苍白冷焰。法阵渐渐暗淡，群星重新浮现，而你依然稳稳立在这片沾满泥泞与血污的大地之上。你亲手推开了触手可及的神座，只因尘世的清算尚未结束，那些高傲的领主、伪善的圣职与隐匿在暗处的强敌，还配不上你仓促离场。自今夜起，你不再是凡人，而是行走于人间的【苍白主宰】。\n\n（导师获得称号【苍白主宰】，永久 +10 决心、每回合额外恢复 3 点疲劳；" + route + "）";
            });
            break;
    }
    _event.m.Title = title;
    _event.m.PaleArt = art;
    local illustration = art == "ascension_rite" ? "gfx/ui/events/pale_ascension_rite.png" : "gfx/ui/events/pale/" + art + ".jpg";
    _screen.Text = "[img]" + illustration + "[/img]" + _screen.Text;
    if (closing)
        this.option(_screen, _screen.ID == "camp" ? "合上账簿" : "返回营地",
            _screen.ID == "whispers" ? function() { S.set("WhispersAfter", S.worldHours() + 24); return null; } : @() null);
};
