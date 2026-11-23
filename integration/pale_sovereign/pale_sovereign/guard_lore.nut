local S = ::PaleSovereign;
local mod = S.Mod;

// 1.6.22 开局荒坟守卫的来历：完整版在开局介绍事件的第二页（pale_sovereign_intro_event 的 B 页），
// 棺椁提示里放短版（提示框已经很高，放不下完整版），晋升尸妖王后换成晋升后的短版。
S.GuardLoreFull <- "这具残破的荒坟守卫，是你逃入无名荒冢时从一口石棺里掘出来的。它身上的铁甲早已锈穿，枯骨上布满刀斧劈砍的陈年缺口，眼窝里那点魂火也暗得像快燃尽的油灯，走起路来关节嘎吱作响，仿佛随时会散成一地白骨。盗墓贼起初只当它是具不值钱的破烂，唯独你留意到，它身周散落着几截早已锈断的沉重铁链，胸甲上满是刀剑攒刺的深痕。能让人如此大费周章地锁进深冢，它生前绝非寻常卒伍。即便沉睡了不知多少年，它抬手举盾的架势依然稳得吓人。只要多见几次血，再寻来合适的古代魂玉，这副残躯迟早会挣脱腐朽，重新找回它生前在沙场上厮杀的力气。";
S.GuardLoreShort <- "你逃入无名荒冢时，从一口石棺里掘出了它。它身周散落着几截锈断的沉重铁链，胸甲上满是刀剑攒刺的深痕，生前绝非寻常卒伍。魂火虽暗，它举盾的架势依然稳得吓人；多见几次血、寻来古代魂玉，它迟早会挣脱腐朽。";
S.GuardLorePromoted <- "你逃入无名荒冢时，从一口石棺里掘出了它，身周散落着几截锈断的沉重铁链。三枚古代魂玉让这副残躯挣脱了腐朽，锈穿的铁甲下重新燃起炽烈的魂火，它终于找回了生前在沙场上厮杀的力气。";

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
