local S = ::PaleSovereign;
local mod = S.Mod;

// 1.6.18 捕奴联动：本起源里俘虏（misc.hsc_captive）双击转化为常驻行尸，右键仍按捕奴 mod 招募为活人兄弟。
// 双击和右键在后端都走“使用物品”→ onUse；双击前 JS 先调 pale_markCaptiveConvert 记下物品编号（构建补丁 patches/hsc/）。
S.CaptiveConvertMark <- null;
S.CaptiveConvertKind <- "zombie";

S.takeCaptiveConvertMark <- function( _item )
{
    local mark = this.CaptiveConvertMark;
    this.CaptiveConvertMark = null;
    return mark != null && mark.ID == _item.getInstanceID() && ::Time.getRealTimeF() - mark.Time < 3.0;
};

S.convertCaptive <- function( _item )
{
    if (!this.isActive() || _item.m.HSC_Used || (::Tactical != null && ::Tactical.isActive()) || !this.hasUndeadSlot())
        return false;
    local bro = this.createUndead(this.CaptiveConvertKind);
    local level = _item.m.HSC_Level == null ? 1 : _item.m.HSC_Level;
    if (level > 1)
        this.castleTrain(bro, level - 1);
    if (_item.m.HSC_ExtraPerkPoints != null && _item.m.HSC_ExtraPerkPoints > 0)
        bro.m.PerkPoints += _item.m.HSC_ExtraPerkPoints;
    if (_item.m.HSC_Champion)
    {
        bro.getFlags().set("PaleCaptiveChampion", true);
        this.ensureCaptiveChampion(bro);
    }
    bro.getSkills().update();
    bro.setHitpointsPct(1.0);
    _item.m.HSC_Used = true;
    ::World.Assets.updateFormation(true);
    return true;
};

// 冠军词条就是原版 / 重铸的 racial.champion（和捕奴 mod 招募冠军俘虏时一样）；升阶不移除种族技能，这里再兜底补一次
S.ensureCaptiveChampion <- function( _bro )
{
    if (!_bro.getFlags().has("PaleCaptiveChampion") || _bro.getSkills().hasSkill("racial.champion"))
        return;
    try { _bro.getSkills().add(::new("scripts/skills/racial/champion_racial")); }
    catch (e) { ::logError("[PaleSovereign] 俘虏冠军词条: " + e); }
};

S.CaptiveUsageText <- "双击：转化为常驻行尸（不耗防腐尸骸，保留等级；冠军转化后仍是冠军）。右键：招募为活人兄弟。";

mod.hook("scripts/ui/screens/character/character_screen", function(q)
{
    q.pale_markCaptiveConvert <- function( _itemId )
    {
        S.CaptiveConvertMark = { ID = _itemId, Time = ::Time.getRealTimeF() };
    };
});

mod.hook("scripts/items/misc/hsc_captive_item", function(q)
{
    q.onUse = @(__original) function( _actor, _item = null )
    {
        if (S.takeCaptiveConvertMark(this) && S.isActive())
            return S.convertCaptive(this);
        return __original(_actor, _item);
    };

    q.HSC_buildDescription = @(__original) function()
    {
        local desc = __original();
        if (!S.isActive() || this.HSC_isEN())
            return desc;
        local cut = desc.find("双击（或右键使用）");
        return (cut != null ? desc.slice(0, cut) : desc + "\n\n") + S.CaptiveUsageText + "也可以在商店里当作奴隶卖掉。";
    };

    q.getTooltip = @(__original) function()
    {
        local ret = __original();
        if (!S.isActive() || this.HSC_isEN())
            return ret;
        foreach (row in ret)
            if ("id" in row && row.id == 65)
                row.text = "使用方式：" + S.CaptiveUsageText;
        if (!S.hasUndeadSlot())
            ret.push({ id = 67, type = "hint", icon = "ui/icons/warning.png", text = "常驻亡灵已达上限或战团已满，现在无法转化。" });
        return ret;
    };
});
