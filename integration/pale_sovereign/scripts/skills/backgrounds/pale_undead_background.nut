this.pale_undead_background <- ::inherit("scripts/skills/backgrounds/character_background", {
    m = { PaleSkeleton = false, PaleRanged = false, PaleTier = 1, PaleBranch = "" },
    function create()
    {
        this.character_background.create();
        // MSU's expanded description expects a container even on non-attacking backgrounds.
        if (this.m.DamageType == null)
            this.m.DamageType = ::MSU.Class.DamageType();
        this.m.HiringCost = 0;
        this.m.DailyCost = 0;
        this.m.Titles = [];
        this.m.GoodEnding = "当这支战团终于走到尽头、维系灵魂的契约随之松动时，%name% 并没有像其他亡灵那样轰然倒塌。它默默拖着陪伴自己多年的残破兵刃，沿着荒野的小路一步步走回了最初醒来的那片乱葬岗。在晨雾升起之前，它安静地将武器插在一座无名墓碑前，随后缓缓跪倒在潮湿的泥土里，再也没有起身。";
        this.m.BadEnding = "战团溃散之后，再也没有人用粗盐与黑线替 %name% 修补日渐腐朽的躯壳，也没有魂火继续为它指引方向。它曾在荒野的冷雨里漫无目的地游荡了数日，直到某个寒意刺骨的深夜，绑住关节的铜索终于彻底崩断。天亮之后，路过的旅人只看见泥地里散落着一地无人问津的枯骨，很快便被风沙彻底掩埋。";
        this.m.ExcludedTalents = [::Const.Attributes.Bravery];
    }

    function getStartingBraveryAdjustment()
    {
        local defaultBravery = this.m.BaseAttributes.Bravery;
        return [120 - defaultBravery[0], 120 - defaultBravery[1]];
    }

    function onBuildDescription()
    {
        return (this.m.PaleSkeleton ? "几根浸过死灵药水与黑盐的铜索，将这副瘦削而发黄的枯骨牢牢捆扎成了一名不知疲倦的战士。它的关节处早已没有半分血肉，行军时总会发出令人牙酸的咔哒轻响，空洞的眼窝里只跳动着一缕微弱的幽蓝魂火。它感受不到疼痛，也听不懂恐惧，唯有在导师抬起法杖的那一刻，才会机械而精准地举起手中锈蚀的兵刃。" : "厚重发硬的粗盐痂下，依然保留着这具躯壳生前结实的筋肉与骨骼。粗糙的黑线在它的胸腹间纵横交错，勉强缝合着当年致命的创口。它拖着僵硬沉重的步子，身上常年散发着防腐药草与腐土混合的刺鼻气味，但在惨烈的拉锯战中，它却比绝大多数贪生怕死的活人佣兵更能死死钉住阵线的缺口。") + "\n\n{%name% 是从一口洒满粗盐的旧木棺里缓缓坐起来的。它早已记不清自己生前的名姓、家乡，也忘了究竟是谁砍下了它的头颅，可当冰冷的兵刃被塞进僵硬的指骨时，沉睡在躯壳里的本能却立刻苏醒过来——它依然记得如何举盾、如何列阵，以及如何迎着刀锋一步不退。 | 干结的粗盐颗粒随着步伐从 %name% 的衣缝间簌簌滑落。营地里的活人总在抱怨它身上挥之不去的咸腥味，但你很清楚它的价值：它不需要面包与麦酒，不会在发薪日讨价还价，更不会在强敌压境时临阵脱逃，它唯一听从的，只有你指尖那缕幽蓝的魂火。 | %name% 曾经倒在某片无人收尸的泥泞荒野上，任由乌鸦与野狗分食，如今却在你的缝合台上重新睁开了浑浊的双眼。对这具被强行拉回尘世的残躯而言，死亡并没有带来安息，不过是换了一个更加冷酷、也更加慷慨的新雇主罢了。 | 每当夜幕降临，营地里的活人兄弟总会下意识地离 %name% 远远的，生怕它那双空洞无神的眼睛突然转向自己。可只要号角一响、战阵拉开，所有人都不得不承认，这具沉默寡言的死人，在战场上比任何拿钱办事的佣兵都更守规矩。}";
    }

    function getTooltip()
    {
        local ret = this.character_background.getTooltip();
        ret.push({ id = 10, type = "text", icon = "ui/icons/special.png", text = "常驻亡灵。零薪水、零粮耗，免疫常规士气变化。受伤时需要用防腐尸骸修复。" });
        if (this.m.PaleRanged)
            ret.push({ id = 12, type = "text", icon = "skills/pale_night_archer.png",
                text = "夜间视野 −1、远程技能 −15%，为通常惩罚的一半。装备守夜人的骨灯时免除此惩罚。" });
        return ret;
    }

    function onAdded()
    {
        this.character_background.onAdded();
        if (this.m.PaleSkeleton && !this.getContainer().hasSkill("racial.skeleton"))
            this.getContainer().add(::new("scripts/skills/racial/skeleton_racial"));
    }

    function onUpdate( _properties )
    {
        this.character_background.onUpdate(_properties);
        _properties.IsAffectedByDyingAllies = false;
        _properties.IsAffectedByFleeingAllies = false;
        _properties.IsAffectedByFreshInjuries = false;
        _properties.IsAffectedByInjuries = false;
        _properties.IsAffectedByLosingHitpoints = false;
        _properties.IsAffectedByNight = false;
        local battle = ::PaleSovereign.Battle;
        if (this.m.PaleRanged && battle != null && battle.Night && !this.getContainer().hasSkill("effects.pale_lantern"))
        {
            _properties.Vision -= 1;
            _properties.RangedSkillMult *= 0.85;
        }
        _properties.IsImmuneToBleeding = true;
        _properties.IsImmuneToPoison = true;
        // 飞升仪式（天灾）：常驻亡灵 +20 生命、+10% 伤害
        if (::PaleSovereign.isActive() && ::PaleSovereign.isAscended() && ::PaleSovereign.oath() == ::PaleSovereign.Oath.Scourge)
        {
            _properties.Hitpoints += 20;
            _properties.DamageTotalMult *= 1.1;
        }
    }
});
