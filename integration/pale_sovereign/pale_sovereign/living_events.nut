local S = ::PaleSovereign;

// 1.7.0 活人与亡灵的大地图随机事件（《活人与亡灵随机事件》），以及并肩 8 场胜仗后的适应事件。
// 与原版随机事件同池，共用 classes/pale_undead_event.nut；多角色用 Pools / Roles。

S.livingBros <- function()
{
    return this.humans().filter(@(_, bro) S.isLivingBro(bro));
};

S.residents <- function( _filter = null )
{
    return this.undead().filter(@(_, bro) bro.isAlive() && (_filter == null || _filter(bro)));
};

S.isSkeletonUnit <- function( _bro )
{
    local background = this.getUndeadBackground(_bro);
    return background != null && background.m.PaleSkeleton;
};

S.giveLivingTrait <- function( _event, _bro, _key )
{
    local id = "trait.pale_" + _key;
    if (_bro.getSkills().hasSkill(id))
        return false;
    local trait = ::new("scripts/skills/traits/pale_undead_" + _key + "_trait");
    _bro.getSkills().add(trait);
    _bro.getSkills().update();
    _event.m.Effects.push({ id = 10, icon = trait.getIcon(), text = _bro.getName() + " 获得了【" + trait.getName() + "】" });
    return true;
};

S.moodBig <- function( _event, _bro, _reason )
{
    _bro.improveMood(3.0, _reason);
    _event.m.Effects.push({ id = 10, icon = ::Const.MoodStateIcon[_bro.getMoodState()], text = _bro.getName() + ::Const.MoodStateEvent[_bro.getMoodState()] });
};

S.CombatBackgrounds <- ["background.sellsword", "background.retired_soldier", "background.hedge_knight", "background.swordmaster",
    "background.militia", "background.gladiator", "background.squire", "background.deserter"];

S.UndeadEvents.living_borrow_lantern <- {
    Title = "借一盏灯", Image = "living_borrow_lantern", Cooldown = 15, RoleOrder = ["rookie", "skeleton"], MainRole = "skeleton",
    Text = "下半夜的寒雾顺着林缘漫进营地，火堆只剩几块噼啪轻响的暗红余炭。轮到%rookie%值夜，他入团没多久，抱着武器缩在车辕边，但凡林子里传来一声枯枝折断的脆响，他的肩膀便狠狠一抖，手里的油灯也跟着晃得影子乱蹿。\n\n正当他咬牙强撑眼皮时，身后暗影里忽然响起一阵极轻的骨节摩擦声。%rookie%险些喊出声，猛地回头举灯，却见%skeleton%正提着兵器无声走近。它既未发难，也不理会对方发白的脸色，只稳稳停在火光边缘的阴影里，眼眶中两点苍白魂火静静跳动，面朝漆黑荒野笔直立定，顺势替他挡住了最渗人的那片林地死角。\n\n你在帐帘缝隙后将这一切尽收眼底。一活一死相隔半步，一个捧着昏黄油灯，一个顶着冷白骨盔，竟就这么安安静静地并肩盯起了夜色。直到黎明换岗，%rookie%紧攥兵器的指节才一点点松开。",
    Score = function( _event )
    {
        if (!S.uevtNight())
            return 0;
        local rookies = S.livingBros().filter(@(_, bro) bro.getLevel() <= 4 && !S.isAcclimated(bro));
        local skeletons = S.residents(@(bro) S.isSkeletonUnit(bro));
        if (rookies.len() == 0 || skeletons.len() == 0)
            return 0;
        _event.m.Pools = { rookie = rookies, skeleton = skeletons };
        local t = ::World.State.getPlayer().getTile().Type, T = ::Const.World.TerrainType;
        return [T.Swamp, T.Forest, T.LeaveForest, T.AutumnForest, T.SnowyForest].find(t) != null ? 13.5 : 9;
    },
    Options = [
        {
            Text = "天亮后顺势替他破除心障，将其编入亡灵近侧。",
            Apply = function( _event )
            {
                local rookie = _event.role("rookie");
                S.giveLivingTrait(_event, rookie, "acclimated");
                S.uevtStat(_event, rookie, "Bravery", 3);
                S.uevtMood(_event, rookie, true, "不再害怕亡灵同袍");
                S.uevtXP(_event, _event.role("skeleton"), 300);
                return "次日拔营时，%rookie%再看那些白森森的战友已少了大半畏惧。他小声嘀咕着，比起满嘴谎话的活人佣兵，这具不声不响替自己盯了半宿梢的骷髅反倒更靠得住。";
            }
        },
        {
            Text = "命二人今后搭班列阵，磨合战中站位。",
            Apply = function( _event )
            {
                local rookie = _event.role("rookie");
                local skeleton = _event.role("skeleton");
                S.uevtStat(_event, rookie, "MeleeDefense", 2);
                S.uevtStat(_event, rookie, "Bravery", 1);
                local archer = S.isArcher(skeleton);
                S.uevtStat(_event, skeleton, archer ? "RangedDefense" : "MeleeDefense", archer ? 3 : 2);
                if (::Math.rand(1, 100) <= 45 && (archer || !S.uevtGiveTrait(_event, skeleton, "legion_discipline")))
                    S.uevtStat(_event, skeleton, "Stamina", 3);
                return "你在战阵图上把这两个名字划到了一处。活人提防冷箭、死人硬扛劈砍，往后的厮杀里，一活一死互相补位的架势竟意外地稳固。";
            }
        },
        {
            Text = "多发半袋灯油，嘱咐他夜里不必独自硬撑。（25 克朗）",
            Usable = @(_event) ::World.Assets.getMoney() >= 25,
            Apply = function( _event )
            {
                S.uevtAsset(_event, "money", -25);
                S.uevtXP(_event, _event.role("rookie"), 200);
                foreach (bro in S.livingBros())
                    S.uevtMood(_event, bro, true, "守夜时多了灯油");
                local lantern = false;
                foreach (bro in ::World.getPlayerRoster().getAll())
                    foreach (item in bro.getItems().getAllItems())
                        if (item != null && item.getID() == "tool.pale_bone_lantern")
                            lantern = true;
                if (lantern)
                    S.uevtXP(_event, S.chief(), 100);
                return "你添了些好油和引火绳分给值夜的弟兄。营地里紧绷了几天的气氛随之松弛下来，%rookie%也不再把守夜当成送命的苦差事。";
            }
        }
    ]
};

S.UndeadEvents.living_payday_grumble <- {
    Title = "发薪日的嘲笑", Image = "living_payday_grumble", Cooldown = 3, RoleOrder = ["complainer", "zombie", "prodeath"], MainRole = "zombie",
    Text = "晌午发完军饷，营地里的气氛却没像往常那样松快下来。你刚合上账簿，就听见火堆旁传来几声阴阳怪气的嗤笑。%complainer%把刚领到的几枚克朗在掌心抛得叮当作响，眼睛却死死斜着不远处正在擦甲的%zombie%，嘴里故意拔高了嗓门，嚷嚷着活人拼死拼活就值这几个铜子，倒是一具连饭都不吃的臭尸体，身上套着的铁甲比大伙儿的还要厚实崭新。\n\n周围几个活人弟兄跟着起哄发笑，笑声里透着掩不住的酸气与怨怼。有人小声接茬，说活人挨了刀还得自己喝酒扛疼，死了说不定还要被填进尸车；反观那具行尸，压根听不懂嘲讽，只顾着低头笨拙地扣紧护肩皮带，发青的脸皮在日头下显得格外刺眼。\n\n抱怨声渐渐聚成一股暗流，连几个平日沉默的老兵也停下了手里的活计，齐刷刷地望向你的帐篷。这股火气若不趁早按下去，下次接战前怕是就要有人掉链子。",
    Score = function( _event )
    {
        if (S.uevtNight())
            return 0;
        local living = S.livingBros();
        local complainers = living.filter(@(_, bro) !S.isProDeath(bro) && (!S.isAcclimated(bro) || bro.getMoodState() < ::Const.MoodState.Euphoric));
        local zombies = S.residents(@(bro) !S.isSkeletonUnit(bro) && bro.getItems().getItemAtSlot(::Const.ItemSlot.Body) != null);
        if (living.len() < 2 || complainers.len() == 0 || zombies.len() == 0)
            return 0;
        zombies.sort(@(a, b) b.getItems().getItemAtSlot(::Const.ItemSlot.Body).getCondition() <=> a.getItems().getItemAtSlot(::Const.ItemSlot.Body).getCondition());
        _event.m.Pools = { complainer = complainers, zombie = [zombies[0]], prodeath = living.filter(@(_, bro) S.isProDeath(bro)) };
        return ::World.Assets.getMoney() < 1000 ? 11.2 : 8;
    },
    Options = [
        {
            Text = "加发一轮酒肉赏钱，安抚活人弟兄。（150 克朗）",
            Usable = @(_event) ::World.Assets.getMoney() >= 150,
            Apply = function( _event )
            {
                S.uevtAsset(_event, "money", -150);
                foreach (bro in S.livingBros())
                    S.uevtMood(_event, bro, true, "得了酒肉赏钱");
                S.uevtStat(_event, _event.role("complainer"), "Bravery", 1);
                return "你掀帘丢出一袋银币，命人去就近买酒添肉，顺带点明只要活人打得好，赏格绝不会亏待。火堆旁的酸话很快变成了碰杯的喧闹，风波就此平息。";
            }
        },
        {
            Text = "提杖走出帐篷，冷声立下战团规矩。",
            Apply = function( _event )
            {
                S.uevtStat(_event, S.chief(), "Bravery", 1);
                foreach (bro in S.livingBros())
                    if (!S.isProDeath(bro))
                        S.uevtMood(_event, bro, false, "被导师训斥");
                S.uevtXP(_event, _event.role("zombie"), 100);
                return "你提着骨杖站到人群正中，冷冷提醒他们，每回冲进敌阵硬吃头一轮重斧与箭雨的都是这些不会喊疼的死人——给肉盾穿好甲，省的是他们自己的命。火堆旁顿时鸦雀无声，众人只得闷头散去。";
            }
        },
        {
            Text = "让%prodeath%出面替这群活人算笔明白账。",
            Usable = @(_event) _event.role("prodeath") != null,
            Apply = function( _event )
            {
                foreach (bro in S.livingBros())
                    S.uevtMood(_event, bro, true, "听了一笔明白账");
                S.uevtStat(_event, _event.role("prodeath"), "Bravery", 2);
                local complainer = _event.role("complainer");
                S.uevtStat(_event, complainer, "Bravery", 1);
                if (::Math.rand(1, 100) <= 50)
                    S.giveLivingTrait(_event, complainer, "acclimated");
                return "%prodeath%咧嘴一笑，掰着指头替大伙儿算起了账：死人既不抢酒桶、也不分战利品，还替活人顶在最要命的缺口上挨刀，天底下哪找这么划算的买卖？%complainer%听得哑口无言，抓了抓后脑勺，也跟着自嘲地笑出了声。";
            }
        }
    ]
};

S.UndeadEvents.living_early_indenture <- {
    Title = "提前签好的卖身契", Image = "living_early_indenture", Cooldown = 20, RoleOrder = ["veteran"], MainRole = "veteran",
    Text = "深夜的营帐里只点着半截油蜡，帐帘忽然被人轻轻掀开。来人是%veteran%，他缓步挪进昏黄火光，身上那处永难痊愈的旧伤在夜风里隐隐作痛。你原以为他是来讨遣散费回乡养老的，可他只是沉默地走到案前，把随身兵刃横放桌上，又摸出一张按过暗红指印的粗羊皮纸推到你手边。\n\n他嗓音沙哑如砂纸磨铁，说自己这副残躯就算揣着银币回村，也不过是在干草堆里等死。他早见惯了常驻亡灵扛着断骨厮杀的模样，心里再无忌讳。只要你点头，他眼下便自愿减半军饷；等哪天真在战场上咽了气，不必入土，请导师亲手替他灌入黑气、换副好骨头，继续跟着老弟兄们走完剩下的路。\n\n蜡火在他布满疤痕的脸上跳动，那双浑浊的眼里没有半分求饶，只有看透生死的狠劲。你按住那张尚带体温的死契，沉默片刻，拿起了案头的骨笔。",
    Score = function( _event )
    {
        if (!S.uevtNight() || S.oath() == S.Oath.None || S.residents().len() == 0)
            return 0;
        local veterans = S.livingBros().filter(@(_, bro) bro.getLevel() >= 8 && !bro.getSkills().hasSkill("trait.pale_death_indenture")
            && bro.getSkills().query(::Const.SkillType.PermanentInjury).len() > 0);
        if (veterans.len() == 0)
            return 0;
        local heavy = veterans.filter(@(_, bro) bro.getSkills().query(::Const.SkillType.PermanentInjury).len() >= 2 || S.isAcclimated(bro));
        _event.m.Pools = { veteran = heavy.len() > 0 ? heavy : veterans };
        return heavy.len() > 0 ? 18 : 10;
    },
    Options = [
        {
            Text = "签下死契，许诺战死后亲手替他重塑骨肉。",
            Apply = function( _event )
            {
                S.giveLivingTrait(_event, _event.role("veteran"), "death_indenture");
                return "你在羊皮纸末尾烙下一枚苍白印记。%veteran%长长吐出一口浊气，仿佛卸下了压在心头许久的包袱，抓起兵器朝你重重一捶胸甲，转身大步走回了夜色之中。";
            }
        },
        {
            Text = "何必苦熬残躯？今夜便替你了断痛楚，重入队列。（4 点防腐尸骸、1 枚古代魂玉）",
            Usable = @(_event) S.get("Reserve") >= 4 && S.countItems("misc.pale_jade") >= 1,
            Apply = function( _event )
            {
                local veteran = _event.role("veteran");
                S.uevtAsset(_event, "reserve", -4);
                S.removeMaterial("jade");
                local rec = S.snapshotBro(veteran);
                veteran.getItems().transferToStash(::World.Assets.getStash());
                ::World.getPlayerRoster().remove(veteran);
                local undead = S.convertToUndead(rec, false);
                _event.m.Effects.push({ id = 10, icon = "ui/icons/special.png", text = undead.getName() + " 转为常驻亡灵，" + undead.getLevel() + " 级，获得【旧日同袍】" });
                S.uevtXP(_event, S.chief(), 500);
                return "你没有拖泥带水。冰冷的魂玉与死灵黑气很快吞没了最后一声闷哼，黎明破晓时，一具不再知晓疲惫与痛楚的熟悉身影重新站进了队列里，稳稳接回了自己用惯的旧兵刃。";
            }
        },
        {
            Text = "把死契烧进蜡火，劝他留着活命打完剩下的仗。",
            Apply = function( _event )
            {
                local veteran = _event.role("veteran");
                S.moodBig(_event, veteran, "导师烧掉了他的死契");
                S.uevtStat(_event, veteran, "Bravery", 2);
                S.uevtStat(_event, veteran, "Hitpoints", 3);
                foreach (bro in S.livingBros())
                    if (bro != veteran)
                        S.uevtMood(_event, bro, true, "导师不肯提前收活人的命");
                return "你把那张羊皮纸凑到蜡焰上烧成了一撮黑灰，拍着他的肩头说战团还没穷到要提前收活人的命。%veteran%怔了半晌，低头咧开缺牙的嘴笑了笑，默默把兵器重新挂回腰间。";
            }
        }
    ]
};

S.UndeadEvents.living_broken_prayer <- {
    Title = "半截断祷", Image = "living_broken_prayer", Cooldown = 15, RoleOrder = ["pious", "zombie"], MainRole = "zombie",
    Text = "月色冷得发青，营地早已沉入死寂，角落里却飘来一阵压得极低的祷告声。你循声拨开灌木，只见%pious%正跪在草地上，手里攥着一枚磨得发亮的旧护符，对着面前的%zombie%飞快地念着安魂经文。他声音抖得厉害，额头渗满冷汗，指尖还捏着一小撮不知从哪弄来的粗盐，正犹豫着要不要往行尸脑门上撒。\n\n%zombie%像截朽木般杵在原地，浑浊的眼珠直愣愣地回望着他，任凭那些斥退邪祟的圣词砸在自己发青的脸上，既没退后半步，也没冒出半缕黑烟。经文念到一半，%pious%的声音忽然卡在了喉咙里——他头一回真切地意识到，自己信了半辈子的神明根本没听见这声祈求，而眼前这具死尸，昨日才刚替他挡下一记劈向脑门的战斧。\n\n他攥着护符的指节发白，神情在虔诚与荒谬之间剧烈摇摆。你提着骨杖缓步走近，知道今夜正是决定他去留的关口。",
    Score = function( _event )
    {
        if (!S.uevtNight())
            return 0;
        local pious = S.livingBros().filter(@(_, bro) S.isPious(bro) && !bro.getSkills().hasSkill("trait.pale_fallen_saint"));
        local zombies = S.residents(@(bro) !S.isSkeletonUnit(bro));
        if (pious.len() == 0 || zombies.len() == 0)
            return 0;
        _event.m.Pools = { pious = pious, zombie = zombies };
        return pious.filter(@(_, bro) bro.getMoodState() <= ::Const.MoodState.Neutral).len() > 0 ? 15 : 10;
    },
    Options = [
        {
            Text = "趁势折断他的旧信仰，以死灵真理重塑心智。",
            Apply = function( _event )
            {
                local pious = _event.role("pious");
                pious.worsenMood(1.0, "丢掉了旧信仰");
                _event.m.Effects.push({ id = 10, icon = ::Const.MoodStateIcon[pious.getMoodState()], text = pious.getName() + ::Const.MoodStateEvent[pious.getMoodState()] });
                S.giveLivingTrait(_event, pious, "fallen_saint");
                S.uevtXP(_event, S.chief(), 100);
                return "你冷笑着点破真相：替他挡刀的是脚下这具行尸，而非高坐云端的虚无神祇。%pious%沉默良久，缓缓松开手，任那枚旧护符坠入泥泞，抬起头时眼底只剩冰冷的清醒。";
            }
        },
        {
            Text = "不加干涉，任他念完这场徒劳的安魂祷词。",
            Apply = function( _event )
            {
                local pious = _event.role("pious");
                S.uevtMood(_event, pious, true, "念完了一场安魂祷词");
                S.uevtStat(_event, pious, "Bravery", 2);
                S.giveLivingTrait(_event, pious, "acclimated");
                S.uevtXP(_event, _event.role("zombie"), 80);
                return "你没有出声打断。%pious%颤抖着念完最后一句经文，仿佛终于卸下了某种沉重的罪责，起身拍净膝上的泥土，再看向那具行尸的眼神竟多了几分古怪的平静。";
            }
        },
        {
            Text = "顺手收走他掌心的粗盐，拿来替行尸补敷创口。",
            Apply = function( _event )
            {
                local zombie = _event.role("zombie");
                zombie.setHitpoints(::Math.min(zombie.getHitpointsMax(), zombie.getHitpoints() + ::Math.floor(zombie.getHitpointsMax() * 0.25)));
                _event.m.Effects.push({ id = 16, icon = "ui/icons/health.png", text = zombie.getName() + " 恢复 25% 最大生命" });
                if (::Math.rand(1, 100) <= 40 && !S.uevtGiveTrait(_event, zombie, "salted") && zombie.getSkills().hasSkill("trait.pale_salted"))
                    S.uevtStat(_event, zombie, "Hitpoints", 2);
                local pious = _event.role("pious");
                pious.worsenMood(0.5, "祷告被导师打断");
                S.uevtXP(_event, pious, 80);
                return "你走上前掰开他的手指，把那撮粗盐全抹在了行尸肩头的旧裂口上，顺口夸了一句“正好缺这味防腐料”。%pious%张口结舌地僵在原地，半晌说不出一个字来。";
            }
        }
    ]
};

S.UndeadEvents.living_no_mercy_spar <- {
    Title = "不收力的陪练", Image = "living_no_mercy_spar", Cooldown = 5, RoleOrder = ["fighter", "skeleton"], MainRole = "skeleton",
    Text = "傍晚扎营不久，营地空地上便响起一阵密集刺耳的金铁交鸣。你以为有敌袭，抓起骨杖快步赶去，却见%fighter%正赤着胳膊挥汗如雨，与%skeleton%打得难解难分。围观的几名弟兄看得直咧嘴，连连往后退了两大步。\n\n寻常活人切磋总得收着三分力，免得失手卸了自家弟兄的胳膊，练久了反而畏手畏脚。可眼前这具骷髅既不知疼痛，也不怕磕崩骨头，招招都是古帝国军团里直奔咽喉与肋下的杀着。%fighter%显然打出了真火，每一剑都使出了十成狠劲，震得虎口发麻；%skeleton%的左肩虽已被劈出一道浅白豁口，反手挑刺的力道却丝毫不减。\n\n照这架势再硬碰硬地劈下去，活人迟早能在死斗里被古帝国战法逼出一身狠劲，可那具骷髅好不容易拼齐的骨头架子，怕是要先散成一地白碴。你抱着胳膊站在一旁，盘算着是赶紧喊停，还是顺水推舟。",
    Score = function( _event )
    {
        if (S.uevtNight())
            return 0;
        local fighters = S.livingBros().filter(@(_, bro) bro.getLevel() >= 3
            && bro.getBaseProperties().MeleeSkill >= bro.getBaseProperties().RangedSkill);
        local skeletons = S.residents(@(bro) S.isSkeletonUnit(bro) && !S.isArcher(bro));
        if (fighters.len() == 0 || skeletons.len() == 0)
            return 0;
        local favored = fighters.filter(@(_, bro) S.isAcclimated(bro) || S.CombatBackgrounds.find(S.backgroundID(bro)) != null);
        _event.m.Pools = { fighter = favored.len() > 0 ? favored : fighters, skeleton = skeletons };
        return favored.len() > 0 ? 12 : 8;
    },
    Options = [
        {
            Text = "备好骨胶与工具，准他们放手打完这一场。（1 点防腐尸骸、4 工具）",
            Usable = @(_event) S.get("Reserve") >= 1 && ::World.Assets.getArmorParts() >= 4,
            Apply = function( _event )
            {
                local fighter = _event.role("fighter");
                local skeleton = _event.role("skeleton");
                S.uevtAsset(_event, "reserve", -1);
                S.uevtAsset(_event, "tools", -4);
                S.uevtStat(_event, fighter, "MeleeSkill", 2);
                S.uevtStat(_event, fighter, "MeleeDefense", 1);
                S.uevtXP(_event, fighter, 300);
                S.uevtStat(_event, skeleton, "MeleeSkill", 2);
                S.uevtXP(_event, skeleton, 300);
                if (::Math.rand(1, 100) <= 35 && !S.uevtGiveTrait(_event, skeleton, "old_drill") && skeleton.getSkills().hasSkill("trait.pale_old_drill"))
                    S.uevtStat(_event, skeleton, "MeleeDefense", 1);
                return "你挥手拦住想劝架的人，只等两人力竭停手才上前替骷髅粘合裂骨、重铆铁钉。%fighter%甩着发红的手腕哈哈大笑，这一场不留情面的死磕，抵得上半个月的寻常操练。";
            }
        },
        {
            Text = "敲杖改规矩，令%skeleton%只守不攻拆招喂招。",
            Apply = function( _event )
            {
                local fighter = _event.role("fighter");
                S.uevtStat(_event, fighter, "MeleeDefense", 2);
                S.uevtStat(_event, fighter, "Stamina", 2);
                S.uevtMood(_event, fighter, true, "和骷髅练了一场");
                S.uevtXP(_event, _event.role("skeleton"), 500);
                return "你敲响骨杖令骷髅收起杀招，专司格挡卸力。%fighter%虽没能劈个痛快，却在反复试探中摸清了古帝国军团的守势破绽，进退步法沉稳了不少。";
            }
        },
        {
            Text = "立刻喝止胡闹，战团的尸骨不是给活人砍着玩的。",
            Apply = function( _event )
            {
                local fighter = _event.role("fighter");
                local skeleton = _event.role("skeleton");
                fighter.worsenMood(0.5, "被导师喝止切磋");
                _event.m.Effects.push({ id = 10, icon = ::Const.MoodStateIcon[fighter.getMoodState()], text = fighter.getName() + ::Const.MoodStateEvent[fighter.getMoodState()] });
                S.uevtXP(_event, fighter, 60);
                skeleton.setHitpoints(::Math.min(skeleton.getHitpointsMax(), skeleton.getHitpoints() + ::Math.floor(skeleton.getHitpointsMax() * 0.15)));
                S.uevtXP(_event, skeleton, 80);
                return "你沉着脸拦在二人中间，提醒%fighter%重铆一副古骨架要耗多少工具与精力。%fighter%悻悻地收刃擦汗，围观的弟兄也一哄而散。";
            }
        }
    ]
};

S.UndeadEvents.living_ale_for_the_dead <- {
    Title = "倒在骨脚边的麦酒", Image = "living_ale_for_the_dead", Cooldown = 45, RoleOrder = ["living", "undead"], MainRole = "undead",
    Text = "恶战过后的头一夜总是格外难熬。大部分弟兄灌完劣酒便钻进帐篷蒙头大睡，唯有%living%拎着半壶麦酒，独自晃到营地边缘的暗影里，一屁股坐在了正在原地待命的%undead%脚边。\n\n他先仰头灌了一大口，接着又把壶口微微倾斜，将半杯泛着泡沫的麦酒缓缓倒在了那双沾满血泥的骨靴旁。借着酒劲，%living%絮絮叨叨地说了起来——先是咒骂白天差点劈碎自己头盔的敌人，随后嗓音渐渐低下去，开始说起早已记不清模样的旧家，以及夜里总也闭不上的眼睛。%undead%既不插嘴，也不嘲笑，只静静垂着头立在风里，空洞的目光落在那摊迅速渗入泥土的酒渍上。\n\n活人之间总有藏不住的猜忌与讥讽，反倒是一具绝不会泄密的死人，成了营地里最好的听众。你站在一旁暗处听了几句，思量着要不要走过去打破这片刻的安宁。",
    Score = function( _event )
    {
        if (!S.uevtNight() || S.uevtSinceVictory() > 48 || S.get("AleEvents") >= 2)
            return 0;
        local living = S.livingBros();
        local undead = S.residents();
        if (living.len() == 0 || undead.len() == 0)
            return 0;
        local sad = living.filter(@(_, bro) bro.getHitpoints() < bro.getHitpointsMax() || bro.getMoodState() <= ::Const.MoodState.Neutral);
        _event.m.Pools = { living = sad.len() > 0 ? sad : living, undead = undead };
        return sad.len() > 0 ? 12.8 : 8;
    },
    Options = [
        {
            Text = "悄悄退回暗影，把这一夜留给他们。",
            Apply = function( _event )
            {
                S.set("AleEvents", S.get("AleEvents") + 1);
                local living = _event.role("living");
                S.moodBig(_event, living, "在亡灵脚边倒了半夜苦水");
                S.uevtStat(_event, living, "Bravery", 2);
                S.giveLivingTrait(_event, living, "acclimated");
                S.uevtXP(_event, _event.role("undead"), 100);
                return "你轻手轻脚地退回帐篷，没有惊动那一活一死。次日天明时，%living%眼底的阴郁散得一干二净，整装列队时还顺手替%undead%扶正了歪斜的护肩。";
            }
        },
        {
            Text = "走过去添一壶好酒，敬生者也敬死者。（40 克朗）",
            Usable = @(_event) ::World.Assets.getMoney() >= 40,
            Apply = function( _event )
            {
                S.set("AleEvents", S.get("AleEvents") + 1);
                S.uevtAsset(_event, "money", -40);
                foreach (bro in S.livingBros())
                    S.uevtMood(_event, bro, true, "敬了生者也敬了死者");
                local living = _event.role("living");
                local undead = _event.role("undead");
                S.uevtStat(_event, living, "Bravery", 2);
                S.uevtStat(_event, living, "Hitpoints", 2);
                S.uevtStat(_event, undead, "Hitpoints", 3);
                if (::Math.rand(1, 100) <= 40 && !S.uevtGiveTrait(_event, undead, "grudge") && undead.getSkills().hasSkill("trait.pale_grudge"))
                    S.uevtStat(_event, undead, "MeleeDefense", 1);
                return "你从辎重车里拎出一壶烈酒放下，说了句简短的祝词。陆续被酒香引来的几名老兵也默契地各倒了一口敬在地上，营地里那股生与死的隔阂，仿佛在酒气里悄然化开了几分。";
            }
        },
        {
            Text = "上前拧上酒壶，训斥他别把酒水糟蹋在死人身上。",
            Apply = function( _event )
            {
                S.set("AleEvents", S.get("AleEvents") + 1);
                local living = _event.role("living");
                living.worsenMood(1.0, "被导师夺了酒壶");
                _event.m.Effects.push({ id = 10, icon = ::Const.MoodStateIcon[living.getMoodState()], text = living.getName() + ::Const.MoodStateEvent[living.getMoodState()] });
                S.uevtItem(_event, "supplies/ground_grains_item");
                S.uevtXP(_event, S.chief(), 60);
                return "你冷着脸夺过酒壶，提醒他死人不需要怜悯，活人更不该拿军粮买醉。%living%讪讪地抹了把嘴起身回营，临走前还是回头看了一眼站在风里的沉默身影。";
            }
        }
    ]
};

// 并肩 8 场胜仗后：凡人背景的活人适应亡灵同袍
S.UndeadEvents.living_acclimation <- {
    Title = "见怪不怪", Image = "living_acclimation", Cooldown = 1, RoleOrder = ["living"], MainRole = "living",
    Text = "收队时，%living%顺手替身边那具骷髅扶正了歪掉的头盔，又帮行尸把松开的护肩扣好，动作熟得像在整理自己的行李。他自己都没注意到，从什么时候起，夜里听见骨节咔哒作响，他已经不会再惊醒了。\n\n和死人并肩打完这么多仗，该怕的早就怕过了。",
    Score = function( _event )
    {
        local list = S.acclimationCandidates();
        if (list.len() == 0)
            return 0;
        _event.m.Pools = { living = list };
        return 40;
    },
    Options = [
        {
            Text = "“习惯就好。”",
            Apply = function( _event )
            {
                local living = _event.role("living");
                S.giveLivingTrait(_event, living, "acclimated");
                return "从今往后，%living%再不会被亡灵同袍吓得心神不宁。";
            }
        }
    ]
};
