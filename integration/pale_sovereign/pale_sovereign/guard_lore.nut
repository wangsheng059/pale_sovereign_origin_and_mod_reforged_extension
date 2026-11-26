local S = ::PaleSovereign;
local mod = S.Mod;

// 1.6.22 开局荒坟守卫的来历：完整版在开局介绍事件的第二页（pale_sovereign_intro_event 的 B 页），
// 棺椁提示里放短版（提示框已经很高，放不下完整版），晋升尸妖王后换成晋升后的短版。
S.GuardLoreFull <- "这具残破的荒坟守卫，是你逃入无名荒冢时从一口石棺里掘出来的。它身上的铁甲早已锈穿，枯骨上布满刀斧劈砍的陈年缺口，眼窝里那点魂火也暗得像快燃尽的油灯，走起路来关节嘎吱作响，仿佛随时会散成一地白骨。盗墓贼起初只当它是具不值钱的破烂，唯独你留意到，它身周散落着几截早已锈断的沉重铁链，胸甲上满是刀剑攒刺的深痕。能让人如此大费周章地锁进深冢，它生前绝非寻常卒伍。即便沉睡了不知多少年，它抬手举盾的架势依然稳得吓人。只要多见几次血，再寻来合适的古代魂玉，这副残躯迟早会挣脱腐朽，重新找回它生前在沙场上厮杀的力气。";
S.GuardLoreShort <- "你逃入无名荒冢时，从一口石棺里掘出了它。它身周散落着几截锈断的沉重铁链，胸甲上满是刀剑攒刺的深痕，生前绝非寻常卒伍。魂火虽暗，它举盾的架势依然稳得吓人；多见几次血、寻来古代魂玉，它迟早会挣脱腐朽。";
S.GuardLorePromoted <- "你逃入无名荒冢时，从一口石棺里掘出了它，身周散落着几截锈断的沉重铁链。三枚古代魂玉让这副残躯挣脱了腐朽，锈穿的铁甲下重新燃起炽烈的魂火，它终于找回了生前在沙场上厮杀的力气。\n放出后带有【号令亡魂】（4 格内友方亡灵近战 +5、伤害 +10%）、【冢王威压】（每回合开始 2 格内敌人士气检定，失败者成为猎物；触及 +1）和换位；它在场时导师每回合首次受击生命与护甲伤害各 −20，并免疫爆头额外伤害与击退、抓取。";

// 1.6.23 新战役介绍事件第二页的开局指引（接在守卫来历之后）
S.IntroGuide <- "[color=#bcad8c]导师手札[/color]\n· [color=#bcad8c]亡灵营地：[/color]大地图顶栏名册按钮左侧的按钮可随时打开账簿。清点尸骸、锁链与魂玉，勘察遗址、征召和升阶都在这里。\n· [color=#bcad8c]立誓：[/color]导师学会第一个路线独有特技时永久立誓（亡灵勇士 / 亡灵天灾），另一条路线随之封闭；亡灵法术精通与亡灵法术大师两条路线都能学。立誓前想清楚。\n· [color=#bcad8c]荒坟守卫：[/color]把它的棺椁装在导师的饰品栏，战斗中放出。勇士路线中与导师并肩打赢 10 场后，可用 3 枚古代魂玉晋升为尸妖王。\n· [color=#bcad8c]古代魂玉的来源：[/color]立誓后每击杀一名敌方冠军并取胜（80%）；首次通关传奇地点（2 枚）；勇士路线注魂时选吞魂或承誓（50%）、勘察清剿过的古代遗址（30%）；天灾路线采集到精锐亡灵的尸体（50%）、勘察古代遗址（10%）、统治城镇的墓园每天 15%、炼化一名 6 级以上的常驻亡灵（之后导师虚弱 2 天）；每座亡灵古堡每 7 天产出 1 枚。\n· [color=#bcad8c]古代魂玉的用途：[/color]勇士路线晋升尸妖王（3 枚）、常驻亡灵 7 级后升阶（每次 1 枚）；勇士路线的魂玉铭刻与灵阶突破；天灾路线的魂玉统领与锁魂者破限；古堡魂炉的七种魂玉配方。\n· [color=#bcad8c]缚魂锁链：[/color]勇士路线在战场上标记生命不高于 25% 的强敌，打赢后把它的灵魂注入勇士，也可请城镇铁匠打造；天灾路线可在战场上对强敌施放【锁魂】夺取魂玉；两条路线都能用它锻造镣铐，并在锁魂者阵亡后召返。勘察遗址常能找到锁链。\n· [color=#bcad8c]防腐尸骸：[/color]立誓后每场胜利清点战场上所有倒下的尸体（敌我都算，被尸弹打烂的除外），天灾路线每 2 具封存 1 点、勇士路线每 5 具封存 2 点。营地的尸骸工坊还能急修、拆解、熬骨髓膏、拆骨充备、加固尸车和宰杀俘虏。征召一名常驻亡灵 3 点，每天还会消耗 1 点，为受伤的常驻亡灵修补 40% 最大生命——它们的生命不会自己愈合。\n· [color=#bcad8c]登记地点：[/color]打赢一仗的战场和清剿过的遗址会登记下来。站在 2 格以内打开账簿，可以在那里征召一次常驻亡灵。\n· [color=#bcad8c]俘虏：[/color]捕获的俘虏在仓库里双击转化为常驻行尸，右键仍招募为活人兄弟；立誓后也可以在尸骸工坊宰杀，防腐尸骸 +1。队伍里等级最高的亡灵法师学会亡灵法术精通后，新唤起的常驻亡灵不再带负面特质。\n· [color=#bcad8c]导师：[/color]夜战时决心 +20；自带的召唤僵尸和召唤骷髅每场各能免费施放 1 次。导师一旦阵亡，战役便就此结束。";

S.guardLore <- function( _item )
{
    if (!this.isActive() || _item == null)
        return null;
    // PaleID 是饰品基类上加的字段，子类实例上用 in 判断会是 false，直接读
    local id = 0;
    try { id = _item.m.PaleID; } catch (e) { id = 0; }
    if (id == 0 || id != this.get("StarterID"))
        return null;
    return this.petGet(_item, "Promoted") != 0 ? this.GuardLorePromoted : this.GuardLoreShort;
};

// 配件兄弟在自己的钩子里给饰品重写了 getDescription，用 Modern Hooks 的 hook 会被盖掉；
// 跟 hooks.nut 里 PaleID 的做法一样用 rawHookTree，只包装真正定义了 getDescription 的那一层
mod.rawHookTree("scripts/items/accessory/accessory", function(p)
{
    if (!("getDescription" in p) || "PaleGuardLoreWrapped" in p)
        return;
    p.PaleGuardLoreWrapped <- true;
    local original = p.getDescription;
    p.getDescription <- function()
    {
        local desc = original.call(this);
        try
        {
            local lore = S.guardLore(this);
            // 只改装在棺里的状态（放出后原描述是“棺盖已启”）；已经加过的不再加
            if (lore != null && desc != null && desc.find("一具以铜箍封紧的木棺") == 0)
                return lore + "\n\n" + desc;
        }
        catch (e)
        {
        }
        return desc;
    };
});
