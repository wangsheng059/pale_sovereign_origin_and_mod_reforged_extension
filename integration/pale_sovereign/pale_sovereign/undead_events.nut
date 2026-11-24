local S = ::PaleSovereign;

// 1.6.33 常驻行尸 / 骷髅的大地图随机事件（与原版随机事件同池）。正文来自《资源重做与常驻亡灵事件设计案》第七节。

// ---------------- 共用判定 ----------------

S.uevtUnits <- function( _skeleton )
{
    return this.undead().filter(function( _, bro )
    {
        if (!bro.isAlive() || bro.getFlags().has("PaleSoulbound"))
            return false;
        local background = S.getUndeadBackground(bro);
        return background != null && background.m.PaleSkeleton == _skeleton;
    });
};

S.uevtCount <- function( _bro, _key )
{
    local flag = "PaleEvt." + _key;
    return _bro.getFlags().has(flag) ? _bro.getFlags().getAsInt(flag) : 0;
};

S.uevtMark <- function( _bro, _key )
{
    _bro.getFlags().set("PaleEvt." + _key, this.uevtCount(_bro, _key) + 1);
};

S.uevtHasAny <- function( _bro, _ids )
{
    foreach (id in _ids)
        if (_bro.getSkills().hasSkill(id))
            return true;
    return false;
};

// 候选人里任一带有指定特质时权重乘以 _mult
S.uevtWeight <- function( _event, _units, _base, _ids, _mult )
{
    _event.m.Candidates = _units;
    if (_units.len() == 0)
        return 0;
    if (_ids != null)
    {
        local weighted = _units.filter(@(_, bro) S.uevtHasAny(bro, _ids));
        if (weighted.len() > 0)
        {
            _event.m.Candidates = weighted;
            return _base * _mult;
        }
    }
    return _base;
};

S.uevtLiving <- function( _prefer = false )
{
    local living = this.humans().filter(@(_, bro) !S.isChief(bro));
    if (living.len() == 0)
        return null;
    if (_prefer)
    {
        local others = living.filter(@(_, bro) bro.getBackground().getID() != "background.graverobber");
        if (others.len() > 0)
            living = others;
    }
    return ::MSU.Array.rand(living);
};

S.uevtNight <- @() !::World.getTime().IsDaytime;
S.uevtSinceVictory <- @() this.get("LastVictoryHour") == 0 ? 99999 : this.worldHours() - this.get("LastVictoryHour");
S.uevtFood <- @() ::World.Assets.getFood();

// ---------------- 共用结果 ----------------

S.AttributeIcons <- { Hitpoints = "health", Stamina = "fatigue", Bravery = "bravery", Initiative = "initiative",
    MeleeSkill = "melee_skill", RangedSkill = "ranged_skill", MeleeDefense = "melee_defense", RangedDefense = "ranged_defense" };

S.uevtStat <- function( _event, _bro, _key, _value )
{
    _bro.getBaseProperties()[_key] += _value;
    _bro.getSkills().update();
    local color = _value >= 0 ? ::Const.UI.Color.PositiveEventValue : ::Const.UI.Color.NegativeEventValue;
    _event.m.Effects.push({ id = 16, icon = "ui/icons/" + this.AttributeIcons[_key] + ".png",
        text = _bro.getName() + " " + this.AttributeNames[_key] + " [color=" + color + "]" + (_value >= 0 ? "+" : "") + _value + "[/color]" });
};

S.uevtTraitScript <- @(_key) "scripts/skills/traits/pale_undead_" + _key + "_trait";

// 加一个亡灵专属特质；已有或与现有特质冲突时返回 false
S.uevtGiveTrait <- function( _event, _bro, _key )
{
    local trait = ::new(this.uevtTraitScript(_key));
    local skills = _bro.getSkills();
    if (skills.hasSkill(trait.getID()))
        return false;
    foreach (other in skills.query(::Const.SkillType.Trait))
        if (other.isExcluded(trait.getID()) || trait.isExcluded(other.getID()))
            return false;
    skills.add(trait);
    skills.update();
    _event.m.Effects.push({ id = 10, icon = trait.getIcon(), text = _bro.getName() + " 获得了【" + trait.getName() + "】" });
    return true;
};

// 从 _ids 里随机移除一个已有的特质，返回是否移除
S.uevtRemoveOne <- function( _event, _bro, _ids )
{
    local owned = _ids.filter(@(_, id) _bro.getSkills().hasSkill(id));
    if (owned.len() == 0)
        return false;
    local trait = _bro.getSkills().getSkillByID(::MSU.Array.rand(owned));
    _event.m.Effects.push({ id = 10, icon = trait.getIcon(), text = _bro.getName() + " 失去了【" + trait.getName() + "】" });
    _bro.getSkills().removeByID(trait.getID());
    _bro.getSkills().collectGarbage();
    _bro.getSkills().update();
    return true;
};

S.uevtXP <- function( _event, _bro, _amount )
{
    _bro.addXP(_amount, false);
    _bro.updateLevel();
    _event.m.Effects.push({ id = 16, icon = "ui/icons/xp_received.png",
        text = _bro.getName() + " 获得 [color=" + ::Const.UI.Color.PositiveEventValue + "]" + _amount + "[/color] 经验" });
};

S.uevtHurt <- function( _event, _bro, _pct )
{
    local loss = ::Math.max(1, ::Math.floor(_bro.getHitpoints() * _pct));
    _bro.setHitpoints(::Math.max(1, _bro.getHitpoints() - loss));
    _event.m.Effects.push({ id = 16, icon = "ui/icons/days_wounded.png",
        text = _bro.getName() + " 损失 [color=" + ::Const.UI.Color.NegativeEventValue + "]" + loss + "[/color] 点生命" });
};

S.uevtMood <- function( _event, _bro, _good, _reason )
{
    if (_bro == null || ::MSU.isNull(_bro) || this.isUndead(_bro) || this.isChief(_bro))
        return;
    if (_good)
        _bro.improveMood(1.0, _reason);
    else if (!this.undeadMood(_bro, 1.0, _reason))
        return;
    _event.m.Effects.push({ id = 10, icon = ::Const.MoodStateIcon[_bro.getMoodState()],
        text = _bro.getName() + ::Const.MoodStateEvent[_bro.getMoodState()] });
};

S.uevtMoodAll <- function( _event, _good, _reason )
{
    foreach (bro in this.humans())
        this.uevtMood(_event, bro, _good, _reason);
};

S.uevtAsset <- function( _event, _kind, _amount )
{
    local assets = ::World.Assets;
    local icon = "", label = "";
    switch (_kind)
    {
        case "money": assets.addMoney(_amount); icon = "asset_money"; label = "克朗"; break;
        case "tools": assets.addArmorParts(_amount); icon = "asset_supplies"; label = "工具"; break;
        case "ammo": assets.addAmmo(_amount); icon = "asset_ammo"; label = "弹药"; break;
        case "reserve":
            local before = this.get("Reserve");
            this.changeReserve(_amount);
            _amount = this.get("Reserve") - before;
            icon = "pale_camp"; label = "防腐尸骸";
            break;
    }
    if (_amount == 0)
        return;
    local color = _amount > 0 ? ::Const.UI.Color.PositiveEventValue : ::Const.UI.Color.NegativeEventValue;
    _event.m.Effects.push({ id = 10, icon = "ui/icons/" + icon + ".png",
        text = (_amount > 0 ? "获得 " : "失去 ") + "[color=" + color + "]" + ::Math.abs(_amount) + "[/color] " + label });
};

S.uevtTakeFood <- function( _event, _amount )
{
    local left = _amount;
    local stash = ::World.Assets.getStash();
    foreach (item in clone stash.getItems())
    {
        if (left <= 0)
            break;
        if (item == null || !item.isItemType(::Const.Items.ItemType.Food))
            continue;
        local amount = item.getAmount();
        local take = ::Math.min(amount, left);
        left -= take;
        if (take >= amount)
            stash.remove(item);
        else
            item.setAmount(amount - take);
    }
    try { ::World.Assets.updateFood(); } catch (e) {}
    _event.m.Effects.push({ id = 10, icon = "ui/icons/asset_food.png",
        text = "失去 [color=" + ::Const.UI.Color.NegativeEventValue + "]" + (_amount - left) + "[/color] 食物" });
};

S.uevtItem <- function( _event, _script )
{
    local item = ::new("scripts/items/" + _script);
    ::World.Assets.getStash().add(item);
    _event.m.Effects.push({ id = 10, icon = "ui/items/" + item.getIcon(), text = "获得 " + item.getName() });
};

S.uevtRelation <- function( _event, _town, _change, _reason )
{
    if (_town == null)
        return;
    try
    {
        ::World.FactionManager.getFaction(_town.getFaction()).addPlayerRelation(_change, _reason);
        _event.m.Effects.push({ id = 10, icon = "ui/icons/relations.png",
            text = _town.getName() + " 的关系 " + (_change >= 0 ? "改善" : "恶化") });
    }
    catch (e)
    {
    }
};

S.isArcher <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    return background != null && background.m.PaleRanged;
};

// ---------------- 八个事件 ----------------

S.UndeadEvents <- {};

S.UndeadEvents.zombie_rain_bloat <- {
    Title = "雨季的发胀", Image = "undead_rain_bloat", Cooldown = 5,
    Text = "连续几日的阴湿水汽像针一样扎进了骨缝里。行军停歇时，一股甜腻得令人反胃的酸腐味顺着风飘进营地，几名活人弟兄捂着口鼻骂骂咧咧地退到了上风口。你拎着骨杖走过去，只见%zombie%正僵立在泥泞里，原本靠粗盐和松脂绷紧的皮囊如今吸饱了湿气，肿得像一头在河底泡了半个月的死猪。\n\n它皮下的暗绿汁液正顺着旧缝线往外渗，肩窝和肘弯鼓起一个个透亮的水泡，随着僵硬的动作微微发颤。一群绿头苍蝇绕着它的下巴打转，一只肥硕的蛆虫甚至从它眼角慢吞吞地爬了出来。%zombie%对此毫无察觉，听见你的脚步声，便咔哒一声转过头，浑浊的眼珠直勾勾地等着号令。\n\n几名活人已经开始在树丛边干呕。再放任这身腐肉泡下去，不等上战场，它的胳膊怕是自己就得烂断在泥潭里。你掂了掂手里的工具袋，盘算着该拿这具发胀的尸体怎么办。",
    Score = function( _event )
    {
        local t = ::World.State.getPlayer().getTile().Type, T = ::Const.World.TerrainType;
        if ([T.Swamp, T.Forest, T.LeaveForest, T.AutumnForest, T.SnowyForest].find(t) == null)
            return 0;
        local units = S.uevtUnits(false).filter(@(_, bro) S.uevtCount(bro, "rain_bloat") < 2);
        return S.uevtWeight(_event, units, 8, ["trait.pale_putrid", "trait.pale_maggot_ridden"], 2.5);
    },
    Options = [
        {
            Text = "刮去腐肉，重新敷盐填料。（2 点防腐尸骸、100 克朗）",
            Usable = @(_event) S.get("Reserve") >= 2 && ::World.Assets.getMoney() >= 100,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "rain_bloat");
                S.uevtAsset(_event, "reserve", -2);
                S.uevtAsset(_event, "money", -100);
                if (!S.uevtRemoveOne(_event, bro, ["trait.pale_putrid", "trait.pale_maggot_ridden"]))
                {
                    S.uevtStat(_event, bro, "Hitpoints", 5);
                    if (::Math.rand(1, 100) <= 60)
                    {
                        local keys = ["salted", "embalmed"];
                        if (::Math.rand(0, 1) == 1) keys.reverse();
                        if (!S.uevtGiveTrait(_event, bro, keys[0]))
                            S.uevtGiveTrait(_event, bro, keys[1]);
                    }
                }
                return "你割开泡烂的皮肉，挤出黑水，用新备的尸骸碎片与粗盐重新填实缝合。天亮时恶臭散了大半，%zombie%的躯壳比发胀前更加紧实。";
            }
        },
        {
            Text = "戳破水泡，让毒汁浸透表皮。",
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "rain_bloat");
                S.uevtHurt(_event, bro, 0.25);
                S.uevtMoodAll(_event, false, "受不了行尸的尸毒恶臭");
                if (!S.uevtGiveTrait(_event, bro, "toxic_flesh"))
                {
                    S.uevtStat(_event, bro, "MeleeDefense", 2);
                    S.uevtStat(_event, bro, "Hitpoints", 2);
                }
                return "你拿短刀逐一划破水泡，暗绿色的尸毒瞬间糊满了它的双臂与胸口。营地里骂声一片，可但凡活人敢靠近它半步，光闻那股毒气就得腿软。";
            }
        },
        {
            Text = "拴在尸车尾通风晾着。",
            Apply = function( _event )
            {
                S.uevtMark(_event.m.Target, "rain_bloat");
                S.uevtXP(_event, _event.m.Target, 200);
                return "你懒得大费周章，命人把%zombie%牵去队尾吹风。活人总算不用再边走边吐，它自己晃荡着走了一整天，皮囊也慢慢瘪了回去。";
            }
        }
    ]
};

S.UndeadEvents.zombie_endless_hunger <- {
    Title = "无底的空腹", Image = "undead_endless_hunger", Cooldown = 10, Living = true, LivingPrefer = false,
    Text = "后半夜的营火刚塌成一堆暗红的炭灰，值夜的%living%便提着火把冲进帐篷，脸色白得像刚咽气。他压低声音说粮车那边有动静，既不像耗子，也不像偷粮的野狗。你抓起骨杖跟着过去，刚绕过驴车，便听见一阵令人牙酸的湿滑咀嚼声。\n\n火光一晃，%zombie%正跪在掀翻的麻袋堆里，双手死死抓着半条风干肉和发硬的黑面包，不管不顾地往嘴里猛塞。它早就没了胃袋，嚼得稀烂的肉渣和面团顺着咽喉滑进胸腔，又从腹部一道没缝严实的旧裂口扑簌簌掉回泥地里。可它浑然不觉，低下头又用发青的手指把沾泥的碎块捏起来，继续往嘴里填。\n\n死灵术能攥住尸体的筋骨，却未必抹得净临死前的执念——它生前多半是活活饿毙在路沟里的。%living%握紧腰间的短剑，低声问要不要给它来上一记狠的，免得明早大家只能啃泥巴。",
    Score = function( _event )
    {
        if (!S.uevtNight() || S.uevtFood() < 20 || S.uevtLiving() == null)
            return 0;
        local weight = S.uevtWeight(_event, S.uevtUnits(false), 7, null, 1);
        return S.uevtFood() >= 50 ? weight * 1.5 : weight;
    },
    Options = [
        {
            Text = "顺着这股凶性，喂它一袋生肉。（15 食物、1 点防腐尸骸）",
            Usable = @(_event) S.uevtFood() >= 15 && S.get("Reserve") >= 1,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtTakeFood(_event, 15);
                S.uevtAsset(_event, "reserve", -1);
                S.uevtStat(_event, bro, "MeleeSkill", 2);
                if (::Math.rand(1, 100) <= 65 && !S.uevtGiveTrait(_event, bro, "gnawing") && bro.getSkills().hasSkill("trait.pale_gnawing"))
                    S.uevtStat(_event, bro, "Hitpoints", 5);
                return "你顺手丢过去一袋生肉，并以死灵黑气灌注它的颌骨。%zombie%喉间爆出一声低沉的嘶吼，咬合的凶性被彻底引了出来，以后对阵活人时它的牙口怕是比钝剑还利。";
            }
        },
        {
            Text = "用铁钩和麻绳缝死它的嘴与腹腔。（4 工具）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 4,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtAsset(_event, "tools", -4);
                S.uevtMoodAll(_event, true, "再也听不见夜里的吞咽声");
                if (!S.uevtGiveTrait(_event, bro, "thick_hide"))
                    S.uevtStat(_event, bro, "MeleeDefense", 3);
                return "你按下它僵硬的脑袋，用浸过油的麻绳把腹裂与下颌一道道勒紧锁死。营地里再不会响起那渗人的吞咽声，密实的缝线也替它护住了躯干要害。";
            }
        },
        {
            Text = "施法强行压制这缕残存执念。",
            Apply = function( _event )
            {
                S.uevtXP(_event, S.chief(), 500);
                S.uevtXP(_event, _event.m.Target, 500);
                return "骨杖上的魂火骤然大亮，死灵契约瞬间压垮了那点可怜的本能。%zombie%松开手里的半块面包，呆滞地起身退回队列，连同你对死灵的掌控也精进了几分。";
            }
        }
    ]
};

S.UndeadEvents.zombie_familiar_face <- {
    Title = "泥垢下的熟面孔", Image = "undead_familiar_face", Cooldown = 10, Living = true, LivingPrefer = true,
    Text = "队伍顺着泥路绕过%townname%外的驿站时，阵雨恰好停了。水珠顺着头盔檐往下滴，把%zombie%左脸上糊了半个月的灰泥冲掉了一大片，露出一道豁开的断眉，以及左手无名指上死死卡进肿肉里的一枚旧铜戒。\n\n走在队列中段的%living%突然像踩了捕兽夹一样定在原地，手里的长矛差点滑脱。他盯着那具行尸的侧脸看了足足十息，喉结艰难地滚了两下，才挤出一声发颤的呼喊——那是几年前在边界巡逻时失踪的老同乡。%zombie%听见声音，机械地偏过僵硬的脖颈，浑浊的眼珠直愣愣地望过来，既无认出的欣喜，也无半点怨恨，只像一截听见风声的朽木。\n\n路边挑水的农夫正狐疑地朝这边张望，队列里的气氛骤然绷紧。%living%嘴唇发白，指节捏得咯吱作响，僵在原地挪不开步子。你冷冷扫过这具皮囊，决定趁麻烦闹大前先了断此事。",
    Score = function( _event )
    {
        if (!::World.State.getPlayer().getTile().HasRoad || S.nearTown(8) == null || S.uevtLiving() == null)
            return 0;
        local weight = S.uevtWeight(_event, S.uevtUnits(false), 6, null, 1);
        return ::World.Assets.getBusinessReputation() >= 300 ? weight * 1.3 : weight;
    },
    Options = [
        {
            Text = "褪下铜戒并递上封口费，打发路人。（40 克朗）",
            Usable = @(_event) ::World.Assets.getMoney() >= 40,
            Apply = function( _event )
            {
                S.uevtAsset(_event, "money", -40);
                S.uevtHurt(_event, _event.m.Target, 0.10);
                S.uevtRelation(_event, S.nearTown(8), 3, "你的人替路人解了围");
                return "你干脆利落地折下那截肿胀的手指，连同铜戒塞进%living%掌心，又丢了几枚银币打发走探头探脑的农夫。队伍很快消失在官道尽头，没人再提那个生前的名字。";
            }
        },
        {
            Text = "顺手搜刮它衣领夹层里的旧遗物。",
            Apply = function( _event )
            {
                S.uevtAsset(_event, "money", ::Math.rand(90, 140));
                if (::Math.rand(1, 100) <= 50)
                    S.uevtItem(_event, "loot/signet_ring_item");
                S.uevtRelation(_event, S.nearTown(8), -2, "有人看见你的人搜刮死人");
                S.uevtMoodAll(_event, false, "看着导师搜刮同乡的遗骸");
                return "死人留着钱财毫无用处。你割开%zombie%早已被血水浸透的贴身内袋，抖出了一小把沾泥的硬币。活人弟兄们纷纷别过脸去，连路边的农夫也吓得丢下水桶跑远了。";
            }
        },
        {
            Text = "默许%living%替故人整好甲带再上路。",
            Apply = function( _event )
            {
                local living = _event.m.Living;
                S.uevtMood(_event, living, false, "认出了变成行尸的同乡");
                S.uevtStat(_event, living, "Bravery", 2);
                S.uevtStat(_event, _event.m.Target, "MeleeDefense", 2);
                if (::Math.rand(1, 100) <= 50)
                    S.uevtGiveTrait(_event, _event.m.Target, "deathgrip");
                return "%living%咬着牙走上前，替那具浑身发臭的躯壳扣紧了松开的护肩皮带，低声说了句体面的告别。从此他再不畏惧死亡，而%zombie%在往后的厮杀中，似乎总下意识地挡在队列最前。";
            }
        }
    ]
};

S.UndeadEvents.zombie_spear_brace <- {
    Title = "卡在肩胛里的断矛", Image = "undead_spear_brace", Cooldown = 10,
    Text = "趁着夜色还未合拢，你在营地里逐一清点上一仗的亡灵损耗，很快便在%zombie%身上停住了脚步。半截生锈的敌军矛头斜斜楔在它的左肩胛骨里，断口处还沾着几缕扯断的锁子甲环，看深度差点把整个肩窝撬散架。\n\n换作活人，这会儿早该疼得满地打滚、失血送命了。可%zombie%毫不在意，刚才收拾战利品时，它抡起左臂搬动重盾的架势反倒比往常更稳更沉。你凑近拨开翻卷的皮肉一瞧，才明白缘由：那截硬铁阴差阳错地顶住了松垮的筋腱，正好替它烂掉半截的骨节充当了支点，每次发力都借上了铁器的死劲。\n\n只是铁锈混着黑血，久了难免把周围的残肉彻底磨烂。旁边的活人弟兄直咂舌，说死人打起仗来连废铁都能当骨头使。你拿捏着镊子和铁锤，盘算着是顺势改造，还是老老实实清创。",
    Score = function( _event )
    {
        if (S.uevtSinceVictory() > 24)
            return 0;
        local units = S.uevtUnits(false).filter(@(_, bro) bro.getLevel() >= 3 && bro.getHitpointsPct() < 0.85 && S.uevtCount(bro, "spear_brace") == 0);
        return S.uevtWeight(_event, units, 10, ["trait.pale_broken_fingers", "trait.pale_stiff_corpse"], 2);
    },
    Options = [
        {
            Text = "干脆把铁片铆死在骨肉里做支架。（6 工具、1 点防腐尸骸）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 6 && S.get("Reserve") >= 1,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "spear_brace");
                S.uevtAsset(_event, "tools", -6);
                S.uevtAsset(_event, "reserve", -1);
                if (!S.uevtRemoveOne(_event, bro, ["trait.pale_broken_fingers", "trait.pale_stiff_corpse"]))
                {
                    S.uevtStat(_event, bro, "Hitpoints", 3);
                    S.uevtStat(_event, bro, "Stamina", 3);
                    S.uevtStat(_event, bro, "Initiative", -2);
                }
                return "你敲平尖锐的断口，用铁箍和防腐油布把这截矛头直接钉死在了肩骨上。虽然动作略显沉钝，但这一记铁骨支架让它的臂力与抗打能力凭空长了一截。";
            }
        },
        {
            Text = "仔细拔出断铁并填补创口。（2 点防腐尸骸）",
            Usable = @(_event) S.get("Reserve") >= 2,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "spear_brace");
                S.uevtAsset(_event, "reserve", -2);
                bro.setHitpoints(bro.getHitpointsMax());
                _event.m.Effects.push({ id = 16, icon = "ui/icons/health.png", text = bro.getName() + " 的生命恢复到满值" });
                S.uevtXP(_event, bro, 500);
                return "你用钳子一点点拧出锈铁，清掉烂肉后再用上等尸骸补齐肩窝。修补完备的%zombie%很快恢复如初，省去了连日慢养的工夫。";
            }
        },
        {
            Text = "把断铁撬出来扔进工具箱。",
            Apply = function( _event )
            {
                S.uevtMark(_event.m.Target, "spear_brace");
                S.uevtAsset(_event, "tools", 5);
                return "你一脚踩住它的肩膀，硬生生把矛头拽了出来。虽然创口敞着不太好看，但这块熟铁回炉敲打敲打，够修好几副破盾牌了。";
            }
        }
    ]
};

S.UndeadEvents.skeleton_midnight_drill <- {
    Title = "午夜的空队列", Image = "undead_midnight_drill", Cooldown = 3,
    Text = "子夜无风，林子外头连猫头鹰都不叫一声，营地边缘却突然传出一阵整齐得令人头皮发麻的脚步声。你披衣走出帐篷，只见月色冷冷洒在草地上，以%skeleton%为首的几具常驻骷髅不知何时自行起了身，正扛着兵器排成一道笔直的半月阵。\n\n没人下令，也没人击鼓，可它们迈步、顿足、横盾、出刺的节拍却分毫不差，骨节敲击甲片的咔哒声像一架上了发条的旧钟表。那套步法沉稳古拙，绝非如今各路领主惯用的野路子，分明是早被黄土埋进史书里的古帝国军团操典。它们空洞的眼窝里幽火明灭，死死盯着黑漆漆的荒野，仿佛正面对着一支看不见的千军万马。\n\n几个起夜的活人弟兄吓得缩在车辕后头不敢出声，生怕这群白骨突然调转矛头。你靠在骨杖上细细打量这幕跨越百年的幽灵操演，思忖着该如何借题发挥。",
    Score = function( _event )
    {
        local units = S.uevtUnits(true);
        if (!S.uevtNight() || units.len() < 2)
            return 0;
        local weight = S.uevtWeight(_event, units, 8, null, 1);
        return units.len() >= 3 ? weight * 1.5 : weight;
    },
    Options = [
        {
            Text = "屏息旁观，顺着旧日军纪默许演练。",
            Apply = function( _event )
            {
                local units = S.uevtUnits(true);
                local drilled = [];
                while (drilled.len() < 3 && units.len() > 0)
                    drilled.push(units.remove(::Math.rand(0, units.len() - 1)));
                foreach (bro in drilled)
                    S.uevtXP(_event, bro, 250);
                local melee = drilled.filter(@(_, bro) !S.isArcher(bro));
                local gained = melee.len() > 0 && ::Math.rand(1, 100) <= 65 && S.uevtGiveTrait(_event, ::MSU.Array.rand(melee), "legion_discipline");
                if (!gained)
                {
                    S.uevtStat(_event, _event.m.Target, "MeleeDefense", 2);
                    S.uevtStat(_event, _event.m.Target, "RangedDefense", 2);
                }
                return "你没有打断这场跨越百年的夜训。直到天边泛白，它们才整齐划一地收刃归位，彼此结阵时的默契肉眼可见地深了几分。";
            }
        },
        {
            Text = "敲响骨杖，按现代战法强行纠偏。（3 工具）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 3,
            Apply = function( _event )
            {
                S.uevtAsset(_event, "tools", -3);
                local forgetful = S.uevtUnits(true).filter(@(_, bro) bro.getSkills().hasSkill("trait.pale_forgotten_drill"));
                if (forgetful.len() > 0)
                    S.uevtRemoveOne(_event, forgetful[0], ["trait.pale_forgotten_drill"]);
                else if (::Math.rand(1, 100) <= 55 && !S.uevtGiveTrait(_event, _event.m.Target, "old_drill")
                    && _event.m.Target.getSkills().hasSkill("trait.pale_old_drill"))
                    S.uevtStat(_event, _event.m.Target, S.isArcher(_event.m.Target) ? "RangedSkill" : "MeleeSkill", 3);
                return "你用骨杖敲出新的节拍，替它们拧紧磨松的扣带，强行把僵化的古步法掰向当下战场的节奏。%skeleton%的架势很快锋利起来，不再只是盲目重复旧梦。";
            }
        },
        {
            Text = "把缩在车后的活人弟兄也拎出来陪练。",
            Usable = @(_event) S.uevtLiving() != null,
            Apply = function( _event )
            {
                local living = S.humans().filter(@(_, bro) !S.isChief(bro));
                local count = ::Math.min(living.len(), ::Math.rand(1, 2));
                for (local i = 0; i < count; ++i)
                {
                    local bro = living.remove(::Math.rand(0, living.len() - 1));
                    S.uevtStat(_event, bro, "MeleeDefense", 2);
                    S.uevtMood(_event, bro, false, "被拉去和骷髅走了半宿方阵");
                }
                S.uevtXP(_event, _event.m.Target, 80);
                return "几个活人骂骂咧咧地被赶进了白骨队列。跟一群不知疲倦的死人走了半宿方阵，他们天亮时累得直翻白眼，可架盾换位的步法确实扎实了许多。";
            }
        }
    ]
};

S.UndeadEvents.skeleton_loose_pins <- {
    Title = "松脱的骨钉", Image = "undead_loose_pins", Cooldown = 5,
    Text = "这一路行军，队列里总混着一阵刺耳的“咔哒”声，听起来比没上油的破驴车还要烦人。你勒住步子循声排查，最后把目光定格在%skeleton%身上。它每往前迈一步，左膝盖便不自然地向外撇开半寸，连带着下颌骨也一磕一磕地跟着打颤。\n\n你挥手令它站定，掀开它那件带着铜绿的旧护甲仔细端详，不由得皱起眉头。当年替它拼接骨节的细铁丝和木销早就锈蚀糟烂，肩胛与肘弯处的骨钉更是松脱了大半，全靠几缕稀薄的死灵黑气勉强吊着不散架。眼下只是走平路就晃成这样，若真在战场上硬吃一记战锤重击，怕是整条胳膊都得连着兵器一块儿甩飞出去。\n\n骷髅自己当然不会喊累，它只是安静地立在原地，空荡荡的眼眶倒映着灰蒙蒙的天色。你掂量着所剩不多的工具和尸车里的存货，盘算着怎么替它修补这副老骨头。",
    Score = function( _event )
    {
        if (::World.Assets.isCamping())
            return 0;
        local units = S.uevtUnits(true).filter(@(_, bro) S.uevtCount(bro, "loose_pins") == 0);
        return S.uevtWeight(_event, units, 8, ["trait.pale_rusted_pins", "trait.pale_brittle", "trait.pale_loose_skull"], 2.5);
    },
    Options = [
        {
            Text = "用工具和铜丝彻底重铆关节。（8 工具、100 克朗）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 8 && ::World.Assets.getMoney() >= 100,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "loose_pins");
                S.uevtAsset(_event, "tools", -8);
                S.uevtAsset(_event, "money", -100);
                if (!S.uevtRemoveOne(_event, bro, ["trait.pale_rusted_pins", "trait.pale_brittle", "trait.pale_loose_skull"]))
                {
                    S.uevtStat(_event, bro, "Stamina", 3);
                    S.uevtStat(_event, bro, "Initiative", 5);
                    if (::Math.rand(1, 100) <= 60)
                        S.uevtGiveTrait(_event, bro, "refined_joints");
                }
                return "你拆掉发黑的烂铁丝，按古帝国军械匠的手艺逐一打入新铜销。再起身时，%skeleton%关节咬合紧密无声，挥刃收势轻快得判若两具尸骨。";
            }
        },
        {
            Text = "从尸车拆几块厚骨片绑上去加固。（2 点防腐尸骸）",
            Usable = @(_event) S.get("Reserve") >= 2,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtMark(bro, "loose_pins");
                S.uevtAsset(_event, "reserve", -2);
                if (!S.uevtGiveTrait(_event, bro, "dense_bone"))
                    S.uevtStat(_event, bro, "Hitpoints", 5);
                S.uevtStat(_event, bro, "Initiative", -2);
                return "你挑了几块格外厚实的胫骨片夹在关节外侧，死死捆紧并以死灵术粘合。这副骨架沉了不少，但以后再挨闷锤也绝不会轻易散架。";
            }
        },
        {
            Text = "扯块破布缠两圈先凑合上路。",
            Apply = function( _event )
            {
                S.uevtMark(_event.m.Target, "loose_pins");
                if (::Math.rand(1, 100) <= 30)
                    S.uevtHurt(_event, _event.m.Target, 0.10);
                return "战团眼下没工夫伺候一具死人的关节。你随便缠了两圈麻布消音，它倒也照旧迈开步子跟了上来，只是不知还能撑过几场硬仗。";
            }
        }
    ]
};

S.UndeadEvents.skeleton_ferryman_coin <- {
    Title = "舌下的冥河渡资", Image = "undead_ferryman_coin", Cooldown = 15,
    Text = "营地休整时，%skeleton%像往常一样蹲在火堆外围的暗影里，用一块磨石慢慢刮掉兵器刃口的血锈。它微微低头的刹那，发黄的下颌骨突然发出一声闷响，“当啷”一声，一枚发黑的圆片从它空荡荡的牙关里滑落出来，滚到了泥地里。\n\n你走近弯腰拾起，抹去上面结块的黑垢，指腹顿时触到了古帝国皇帝清晰的侧像——那是一枚货真价实的古代金币。按古俗，战死的兵卒下葬时总要在舌下含一枚渡资，好付给冥河边的摆渡人；这枚金币不知怎的一直卡在它颚骨深处，直到今日才松动跌落。%skeleton%停下了手里的磨石，缓缓俯身盯着你掌心的金币，眼眶里的苍白魂火罕见地剧烈摇曳起来，滋滋作响。\n\n它显然早已忘了生前的名姓，却还死死记着某种买路的规矩。看着这枚在古堡魂炉和打造镣铐时都能派上大用场的古币，你一时起了不同的心思。",
    Score = function( _event )
    {
        if (S.get("Victories") < 3 && S.localSite(0) == null)
            return 0;
        return S.uevtWeight(_event, S.uevtUnits(true), 7, null, 1);
    },
    Options = [
        {
            Text = "弯腰收进战团的宝箱。",
            Apply = function( _event )
            {
                S.uevtItem(_event, "loot/ancient_gold_coins_item");
                return "死人已经上了岸，哪还用得着渡船钱。你面不改色地把金币揣进钱囊，%skeleton%眼中的魂火随之黯淡了一瞬，随后便重新低下头，继续安静地打磨起手里的兵刃。";
            }
        },
        {
            Text = "把金币塞回它牙关，低念一句古安魂辞。",
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                if (::Math.rand(1, 100) <= 60)
                {
                    local keys = ["soulfire", "grudge"];
                    if (::Math.rand(0, 1) == 1) keys.reverse();
                    if (!S.uevtGiveTrait(_event, bro, keys[0]) && !S.uevtGiveTrait(_event, bro, keys[1])
                        && bro.getSkills().hasSkill("trait.pale_soulfire") && bro.getSkills().hasSkill("trait.pale_grudge"))
                        S.uevtStat(_event, bro, S.isArcher(bro) ? "RangedSkill" : "MeleeSkill", 5);
                }
                S.uevtStat(_event, S.chief(), "Bravery", 2);
                return "你替它把渡资重新卡回颌骨深处，顺口念出一段古帝国的出征祷词。%skeleton%缓缓直起脊背，向你行了一个标准得令人发冷的帝国军礼，眼中的魂火骤然烧得雪亮。";
            }
        },
        {
            Text = "将古币锤扁，嵌进它的眉骨当护符。（5 工具）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 5,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtAsset(_event, "tools", -5);
                if (!S.uevtGiveTrait(_event, bro, "hollow_skull"))
                {
                    S.uevtStat(_event, bro, "RangedDefense", 3);
                    S.uevtStat(_event, bro, "Hitpoints", 3);
                }
                return "既不愿离身，便让它派上实打实的用场。你把古币敲成弧片铆在它的眉心，残留的古帝国祈护铭文贴着苍白颅骨微微发烫，替它挡下了不少致命的劈砍。";
            }
        }
    ]
};

S.UndeadEvents.skeleton_picky_scavenger <- {
    Title = "挑剔的拾骨者", Image = "undead_picky_scavenger", Cooldown = 20,
    Text = "厮杀刚歇，战场上到处都是横七竖八的残尸与断刃。别的亡灵都听从号令守在尸车旁等候清点，唯有%skeleton%独自脱了队，正蹲在一堆敌尸中间挑挑拣拣，活像集市上挑剔猪腿的厨子。\n\n你走过去喝止，却见它正用力掰下一具强壮敌尸的小腿骨，抖落上面的碎肉和泥浆，然后小心翼翼地贴在自己布满细密裂纹的尺骨与肋骨旁反复比划。它左看看右瞧瞧，空洞的颅骨微微偏斜，竟流露出几分说不清道不明的嫌弃，似乎极度不满自己如今这副在地下埋了不知几百年的老旧骨架。随后它又顺手摸了摸旁边几块厚实的骨殖，迟迟不肯撒手。\n\n一旁帮忙收拾尸骸的弟兄看得直发愣，低声嘀咕说头一回见骷髅还嫌自己骨头不够结实的。你扫了眼那截成色极佳的硬骨，又看看%skeleton%跃跃欲试的架势，开口作出了决断。",
    Score = function( _event )
    {
        if (S.uevtSinceVictory() > 24 || S.get("LastVictoryHumanoid") == 0)
            return 0;
        return S.uevtWeight(_event, S.uevtUnits(true), 9, ["trait.pale_cracked_ribs", "trait.pale_frail_bone"], 2.5);
    },
    Options = [
        {
            Text = "顺手替它换骨，以死灵术重新粘合。（2 点防腐尸骸）",
            Usable = @(_event) S.get("Reserve") >= 2,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtAsset(_event, "reserve", -2);
                if (!S.uevtRemoveOne(_event, bro, ["trait.pale_cracked_ribs", "trait.pale_frail_bone"]))
                {
                    S.uevtStat(_event, bro, "Hitpoints", 3);
                    if (S.isArcher(bro))
                    {
                        S.uevtStat(_event, bro, "RangedSkill", 2);
                        S.uevtStat(_event, bro, "Hitpoints", 2);
                    }
                    else if (::Math.rand(1, 100) <= 55)
                        S.uevtGiveTrait(_event, bro, "tall_frame");
                }
                return "你顺了这具死人的意，替它拆掉发脆的旧骨，换上这几截粗壮的新骨并灌入黑气弥合。%skeleton%活动了一下变宽的肩背，骨节发出令人满意的沉闷轻响。";
            }
        },
        {
            Text = "制止换骨，把硬骨磨成兵器配重或骨镞。（3 工具）",
            Usable = @(_event) ::World.Assets.getArmorParts() >= 3,
            Apply = function( _event )
            {
                local bro = _event.m.Target;
                S.uevtAsset(_event, "tools", -3);
                if (S.isArcher(bro))
                {
                    S.uevtStat(_event, bro, "RangedSkill", 2);
                    S.uevtAsset(_event, "ammo", 20);
                }
                else
                {
                    S.uevtStat(_event, bro, "MeleeSkill", 2);
                    S.uevtStat(_event, bro, "Stamina", 2);
                }
                return "好骨头用在杀敌上比装在自己身上更划算。你命人把这截硬骨削磨成型，添作兵器配重与尖锐骨镞，%skeleton%试了试手感，很快就安静地归了队。";
            }
        },
        {
            Text = "喝令它归队，合格骨殖一律入库。",
            Apply = function( _event )
            {
                S.uevtAsset(_event, "reserve", 2);
                return "规矩就是规矩，谁也不能私吞战利品。你拿骨杖敲了敲它的头盖骨，把几块上好的骸骨统统收进尸车，%skeleton%只好空着手闷头走回队列。";
            }
        }
    ]
};
