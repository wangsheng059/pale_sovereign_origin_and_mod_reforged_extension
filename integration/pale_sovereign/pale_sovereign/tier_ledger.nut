local S = ::PaleSovereign;

S.tierLedgerTargets <- function()
{
    local units = this.undead().filter(@(_, bro) bro.isAlive() && bro.getLevel() >= S.TierCost.Level
        && S.getUndeadTier(bro) > 0 && S.getUndeadTier(bro) < 3);
    units.sort(@(a, b) b.getLevel() <=> a.getLevel());
    return units;
};

S.tierLedgerPanel <- function( _event, _screen )
{
    local units = this.tierLedgerTargets();
    local page = ::Math.min(_event.m.TierPage, ::Math.max(0, (units.len() - 1) / 4));
    _screen.Text = "常驻骷髅与行尸达到 7 级后，可以举行升阶仪式。每次需古代魂玉 1 枚、防腐尸骸 5 点、500 克朗。"
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
    local choices = this.TierChoices[background.m.PaleSkeleton ? 1 : 0][background.m.PaleTier - 1];
    local nextLevel = target.getLevel() - this.tierLevelsSpent();
    _screen.Text = target.getName() + " · " + background.getName() + "　" + target.getLevel() + " → " + nextLevel + " 级";
    if (_screen.ID == "tier_confirm" && choices.find(_event.m.TierBranch) != null)
    {
        local chosen = _event.m.TierBranch;
        local branch = this.TierBranches[chosen];
        _screen.Text += "\n\n" + this.tierBranchSummary(chosen)
            + "\n\n升阶将重置基础属性、已学特技和动态特技树，退回新等级对应的属性升级次数和特技点。保留天赋星、特质、装备和中阶专长，旧阶段的魂玉与魂炉强化清空，可再次进行。"
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
    local text = "【" + branch.Name + "】" + branch.Description + "\n生命 " + stats[0] + "　近战 " + stats[1]
        + "　近防 " + stats[2] + "　远防 " + stats[3] + "　先手 " + stats[4] + "　行动点 " + stats[5] + "　决心 120";
    foreach (key in branch.Skills)
    {
        local talent = this.TierTalents[key];
        text += "\n" + talent.Name + "　" + talent.Description;
    }
    return text;
};
