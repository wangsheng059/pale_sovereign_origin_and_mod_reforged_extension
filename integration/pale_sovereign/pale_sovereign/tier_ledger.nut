local S = ::PaleSovereign;

S.tierLedgerTargets <- function()
{
    if (!this.canUseTierSystem())
        return [];
    local units = this.undead().filter(@(_, bro) bro.isAlive() && bro.getLevel() >= S.TierCost.Level
        && !bro.getFlags().has("PaleSoulbound") && S.getUndeadTier(bro) > 0 && S.getUndeadTier(bro) < 3);
    units.sort(@(a, b) b.getLevel() <=> a.getLevel());
    return units;
};

S.tierLedgerPanel <- function( _event, _screen )
{
    if (!this.canUseTierSystem())
    {
        _screen.Text = "常驻亡灵升阶为【亡灵勇士】路线专属机制，当前路线无法为常驻亡灵升阶。";
        return;
    }
    local units = this.tierLedgerTargets();
    local page = ::Math.min(_event.m.TierPage, ::Math.max(0, (units.len() - 1) / 4));
    _screen.Text = "空地上以骨灰与粗盐画好重铸法阵。历经血战、达到 7 级的常驻骷髅与行尸可以踏入其中，拆去旧骨、重塑更凶悍的亡者形骸。\n\n"
        + "每次升阶需古代魂玉 " + this.TierCost.Jade + " 枚、防腐尸骸 " + this.tierReserveCost() + " 点、" + this.TierCost.Money + " 克朗，每次升阶均从 1 级重新开始。"
        + "\n\n古代魂玉　" + this.countItems("misc.pale_jade") + "　防腐尸骸　" + this.get("Reserve");
    if (units.len() == 0)
        _screen.Text += "\n\n目前没有达到 7 级、且尚未升至高阶的常驻亡灵。";
    for (local i = page * 4; i < ::Math.min(units.len(), (page + 1) * 4); ++i)
    {
        local target = units[i];
        this.option(_screen, target.getName() + " · " + target.getBackground().getName() + "（" + target.getLevel() + " 级）", function()
        {
            _event.m.TierUnit = target.getID();
            return "@tier_branch";
        });
    }
    if (page > 0)
        this.option(_screen, "上一页", function() { _event.m.TierPage = page - 1; return "@tier_roster"; });
    if ((page + 1) * 4 < units.len())
        this.option(_screen, "下一页", function() { _event.m.TierPage = page + 1; return "@tier_roster"; });
};

S.tierBranchPanel <- function( _event, _screen )
{
    local units = this.tierLedgerTargets().filter(@(_, bro) bro.getID() == _event.m.TierUnit);
    if (units.len() == 0)
    {
        _screen.Text = "该单位当前无法升阶。";
        this.option(_screen, "返回选择亡灵", @() "@tier_roster");
        return;
    }

    local target = units[0];
    local background = target.getBackground();
    local choices = this.tierChoicesFor(background);
    local nextLevel = this.tierNewLevel(target, background);
    _screen.Text = target.getName() + " · " + background.getName() + "　" + target.getLevel() + " → " + nextLevel + " 级";
    if (_screen.ID == "tier_confirm" && choices.find(_event.m.TierBranch) != null)
    {
        local chosen = _event.m.TierBranch;
        local branch = this.TierBranches[chosen];
        _screen.Text += "\n\n" + this.tierBranchSummary(chosen)
            + "\n\n升阶将重置基础属性、普通已学特技和动态特技树，退回新等级对应的属性升级次数和特技点。保留天赋星、特质（含宝石眼窝）、已学会的常驻亡灵专属特技组技能、装备和中阶专长；旧阶段的镀金骨甲清空，升阶后可再次进行。"
            + (background.m.PaleRanged ? "\n\n远程升阶从 1 级开始。已有合用武器会继续使用；若需换装，配发分支武器和适用的弹药，换下的装备送入仓库。" : "")
            + "\n\n消耗古代魂玉 " + this.TierCost.Jade + " 枚、防腐尸骸 " + this.tierReserveCost() + " 点、" + this.TierCost.Money + " 克朗。";
        if (this.tierCanPromote(target, chosen))
            this.option(_screen, "确认升阶为" + branch.Name, @() S.tierPromote(target, chosen));
        else
            _screen.Text += "\n\n材料不足。";
        this.option(_screen, "返回选择分支", @() "@tier_branch");
        return;
    }

    _screen.Text += "\n\n选择" + (background.m.PaleTier == 1 ? "中阶" : "高阶") + "分支。";
    foreach (key in choices)
    {
        local choice = key;
        _screen.Text += "\n\n" + this.tierBranchSummary(choice);
        this.option(_screen, "选择" + this.TierBranches[choice].Name, function()
        {
            _event.m.TierBranch = choice;
            return "@tier_confirm";
        });
    }
    this.option(_screen, "返回选择亡灵", @() "@tier_roster");
};

S.tierBranchSummary <- function( _key )
{
    local branch = this.TierBranches[_key];
    local stats = branch.Stats;
    local sp = this.TierStatSpread;
    local fmt = @(r) r[0] + "–" + r[1];
    local hp = this.statRange(stats[0], sp.Hitpoints, 10);
    local sta = this.TierStaminaRange;
    local ms = this.statRange(stats[1], sp.MeleeSkill, 1);
    local md = this.statRange(stats[2], sp.MeleeDefense, 0);
    local rd = this.statRange(stats[3], sp.RangedDefense, 0);
    local ini = this.statRange(stats[4], sp.Initiative, 1);
    local brv = this.statRange(100, sp.Bravery, 1);
    local text = "【" + branch.Name + "】" + branch.Description
        + "\n生命 " + fmt(hp) + "　疲劳 " + fmt(sta) + "　近战 " + fmt(ms)
        + ("RangedSkill" in branch ? "　远程 " + fmt(this.statRange(branch.RangedSkill, sp.RangedSkill, 1)) : "")
        + "　近防 " + fmt(md) + "　远防 " + fmt(rd) + "　主动值 " + fmt(ini)
        + "　决心 " + fmt(brv) + "　行动点 " + stats[5];
    foreach (key in branch.Skills)
    {
        local talent = this.TierTalents[key];
        text += "\n" + talent.Name + "　" + talent.Description;
    }
    return text;
};
