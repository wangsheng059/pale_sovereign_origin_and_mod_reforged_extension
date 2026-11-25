::PaleSovereign <- {
    ID = "scenario.pale_sovereign",
    Chief = "background.pale_necromancer",
    ChiefScript = "scripts/skills/backgrounds/pale_necromancer_background",
    ChiefName = "亡灵法师导师",
    RosterLimit = 24,
    CombatLimit = 9,
    ScourgeRosterLimit = 24,
    ScourgeCombatLimit = 13,
    ChampionUndeadLimit = null,
    ReserveLimit = 40,
    Oath = { None = 0, Champion = 1, Scourge = 2 },
    OathNames = ["尚未立誓", "亡灵冠军", "亡灵天灾"],
    Battle = null,
    Endings = {
        Champion = "当这支令诸邦闻风丧胆的战团最终散去，%name% 并没有像人们期盼的那样重归隐匿，而是带着那尊由无数古老战魂浇筑而成的不朽冠军，独自踏入了北方终年不散的苍茫迷雾。数月之间，世间再无他的音讯，直到那个大雪纷飞的寒夜——当年联手围剿他的几座领主城堡与圣殿，相继在一夜之间化作了死寂无声的空城。寥寥几位逃出火海的幸存者在酒馆里发疯般地尖叫，说他们看见漫天幽蓝魂火映亮了漆黑的夜空，一道披着残破古甲、周身缠绕黑铁锁链的枯骨身影只身踏碎了包铁城门，所过之处铁骑尽碎；而那位早已“死去”的亡灵法师导师，就静静站在尸山血海之后，拄着骸骨权杖冷冷地注视着一切。自那以后，再没有哪位领主敢轻言圣火足以净化尘世，人们只在私下里颤抖着相传：苍白之主从未真正离去，他的冠军仍在暗影中静候下一次清算。",
        Scourge = "战团的旗帜缓缓落下之时，尘世真正的噩梦才刚刚拉开帷幕。%name% 将多年征战积攒下来的防腐尸骸尽数启封，在荒野深处挥动千魂法杖，带着绵延数里的亡者大军重返当年将他逼入绝境的旧地。这一次，没有仓皇的逃亡，也没有半分怜悯。曾经高举圣火围剿他的领主、牧师与披甲执锐的重装骑士，在无穷无尽的尸潮、蔓延不绝的诅咒与震耳欲聋的尸爆面前，显得如此脆弱而可笑。坚固的高墙在漫天飞舞的残肢与腐毒雾霭中轰然倒塌，昔日的焦土彻底沦为死者的国度。数十年过去，那片领地再也没有升起过一缕炊烟；偶有迷路的旅人误入终年笼罩在灰雾中的荒原，仍能听见风中传来成千上万具枯骨行军的咔哒声。而 %name% 的名讳，从此成为诸邦典籍中严令抹去、却无人敢忘的永恒禁忌。",
        Bad = "圣火、长矛与不知疲倦的猎巫人，终究还是追上了这具从荒冢深处爬出的残躯。在一座荒废已久、屋顶坍塌的乡间教堂外，%name% 耗尽了体内最后一丝幽蓝魂火，亲眼看着身旁的枯骨守卫在熊熊烈焰与圣水之中寸寸崩碎。他曾以为自己早已战胜了死亡，可当冰冷的箭矢贯透胸膛时，凡人血肉的脆弱依然无情地拽住了他的脚步。这一次，没有无人问津的荒冢供他喘息，也没有新的古老契约能将他从深渊拉回尘世。烈火很快吞没了他破旧的巫师袍，连同那柄相伴已久的骷髅法杖一起化作漫天飞灰。不久之后，教堂的钟声重新敲响，各地的领主举杯欢庆旧日噩梦的彻底终结；只是每逢寒冬深夜，荒野的冷风掠过那片焦黑的废墟时，路过的守夜人仍总觉得耳边回荡着一声沙哑而不甘的低语。",
        Ascend = "那场在荒野深夜举行的登神仪式没有任何活人得以近观，诸邦的史官们只记得，那一夜天地骤暗，寒风如泣，从北方终年积雪的冻土到南方炽热的荒漠，世间所有墓园与古冢里的枯骨都曾挣脱泥土，齐齐向着同一个方向俯首跪拜。%name% 在滔天的幽蓝魂火中彻底燃尽了那具曾被圣火灼伤、在泥泞里挣扎求生的凡人躯壳，以纯粹而永恒的苍白神火重塑了不朽之躯。昔日领主的围剿、圣职的追杀、仇恨与尘世王朝的兴衰更迭，在如今的他眼中早已渺小得如同脚下微尘。自那以后，酒馆与教堂里再无所谓“亡灵法师”的传闻——有的只是一位高居死寂王座之上、俯瞰众生的苍白之神。每当生者闭上双眼、灵魂坠入永恒黑暗的那一刻，耳边听见的最后一阵低语，都是他冷酷而威严的名讳。"
    },
    ItemDir = "scripts/items/",
    SkillDir = "scripts/skills/"
};

::PaleSovereign.Mod <- ::Hooks.register("mod_pale_sovereign", "1.7.7", "亡灵主宰");
::PaleSovereign.Mod.require("mod_local_rules >= 1.6.9");
::Hooks.registerJS("ui/mods/pale_sovereign.js");
::Hooks.registerCSS("ui/mods/pale_sovereign.css");
::PaleSovereign.Mod.queue([">mod_local_necromancy_companions", ">mod_dynamic_perks", ">mod_AC", ">mod_reforged", ">mod_stronghold", ">mod_pandoras_hobby", ">mod_conquest"], function()
{
    if (!::BGP.HasAC)
        return;
    foreach (file in ["company", "combat", "souls", "sites", "undead_recruits", "undead_lore", "guard_lore", "tier_data", "tier_ranged_data", "tier_promotion", "tier_ledger", "events", "hooks", "champion_ai", "battle_loading", "loading", "ambition_data", "ambitions", "battle_rewards", "tier_combat", "tier_ranged_combat", "lich", "undead_events", "soulbound", "battle_art", "embalm_craft", "ledger_pages", "reserve_ops", "jade_ops", "chain_ops", "living_bond", "living_events"])
        ::include("pale_sovereign/" + file);
    ::include("pale_sovereign/formation_ai");
    if ("Stronghold" in ::getroottable())
        foreach (file in ["stronghold", "castle_services", "castle_armor", "castle_siege", "castle_rites", "castle_forge"])
            ::include("pale_sovereign/" + file);
    if ("Conquest" in ::getroottable())
        foreach (file in ["conquest", "conquest_governor"])
            ::include("pale_sovereign/" + file);
    if ("PandorasHobby" in ::getroottable())
        ::include("pale_sovereign/followers");
    if ("HumanSlaveCapture" in ::getroottable())
        ::include("pale_sovereign/captives");
});

// 1.6.33 棺椁说明里写明亡灵主宰战役中活人兄弟可用（宠物库在 AfterHooks 阶段才登记）
// Also register Soulbound DynamicPerks perk groups in AfterHooks after DynamicPerks VeryLate initializes PerkGroupIDs.
::PaleSovereign.Mod.queue([">mod_local_necromancy_companions", ">mod_AC", ">mod_reforged", ">mod_dynamic_perks"], function()
{
    if ("registerSoulboundPerkGroups" in ::PaleSovereign)
        ::PaleSovereign.registerSoulboundPerkGroups();
    if (!("BGP" in ::getroottable()) || !("NecroPet" in ::BGP) || !("Companions" in ::Const))
        return;
    local before = "只有亡灵法师能装备。";
    local after = "只有亡灵法师能装备；亡灵主宰战役中活人兄弟也能装备。";
    foreach (type, _ in ::BGP.NecroPet.OwnTypes)
    {
        local def = ::Const.Companions.Library[type];
        local at = def.Description.find(before);
        if (at != null)
            def.Description = def.Description.slice(0, at) + after + def.Description.slice(at + before.len());
    }
}, ::Hooks.QueueBucket.AfterHooks);

::PaleSovereign.Mod.queue([">mod_local_rules", ">mod_autopilot_new"], function()
{
    if (::BGP.HasAC && "Autopilot" in ::BGP)
        ::include("pale_sovereign/autopilot");
});

::PaleSovereign.Mod.queue(">bbfusion_framework", function()
{
    if (!("BBFusion" in ::getroottable()) || !("IsEligible" in ::BBFusion))
        return;
    local eligible = ::BBFusion.IsEligible;
    ::BBFusion.IsEligible = function( _item )
    {
        if (_item != null)
        {
            local id = _item.getID();
            // 1.6.15：只排除初生骷髅法杖；蜕变后的骸骨权杖 / 千魂法杖是红装，参与融合
            if (id == "weapon.pale_staff")
                return false;
            if ("PaleReplica" in _item.m && _item.m.PaleReplica)
                return false;
        }
        return eligible(_item);
    };
    if ("ApplyFusionArmorItem" in ::BBFusion)
    {
        local applyArmorStats = ::BBFusion.ApplyFusionArmorItem;
        ::BBFusion.ApplyFusionArmorItem = function( _item, _stats, _properties = null )
        {
            if (_item == null || _stats == null || !("PaleGildedBonus" in _item.m) || !::BBFusion.IsEligible(_item))
                return applyArmorStats(_item, _stats, _properties);
            // Fusion rebuilds durability from its own base. Keep the soul furnace bonus outside that base.
            local condition = _item.m.Condition;
            local maximum = _item.m.ConditionMax;
            local bonus = _item.m.PaleGildedBonus;
            _item.m.ConditionMax -= bonus;
            _item.m.Condition = ::Math.minf(condition, _item.m.ConditionMax);
            local result;
            try { result = applyArmorStats(_item, _stats, _properties); }
            catch (e)
            {
                _item.m.ConditionMax = maximum;
                _item.m.Condition = condition;
                throw e;
            }
            _item.m.ConditionMax += bonus;
            _item.m.Condition = ::Math.minf(condition, _item.m.ConditionMax);
            return result;
        };
    }
});
