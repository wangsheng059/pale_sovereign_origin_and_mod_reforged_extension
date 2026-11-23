local S = ::PaleSovereign;

// 1.6.30 盐窖：用防腐尸骸为常驻亡灵施加临时秘仪（数据与效果在 embalm_craft.nut）
S.CastleBuildings.pale_salt_cellar.Page = "castle_salt";
S.CastleBuildings.pale_salt_cellar.Effect = "尸骸库存上限 +20。在古堡停留时，每天免费修补全体常驻亡灵。可消耗防腐尸骸为常驻亡灵施加持续 3 场战斗的防腐秘仪。";
S.CastleBuildings.pale_salt_cellar.Description = S.CastleBuildings.pale_salt_cellar.Flavor + S.CastleBuildings.pale_salt_cellar.Effect;

local castlePanelRites = S.castlePanel;
S.castlePanel = function( _screen )
{
    local id = _screen.ID;
    castlePanelRites.call(this, _screen);
    if (id != "castle_salt" && id.find("castle_rite_") != 0)
        return;
    local town = this.castleHere();
    // 去掉原面板补的返回按钮，换成本页的选项
    if (_screen.Options.len() > 0)
        _screen.Options.pop();
    if (town == null || !this.castleHas(town, "pale_salt_cellar"))
    {
        _screen.Text = "这座古堡还没有盐窖。";
        this.option(_screen, "回到亡灵古堡", @() "@castle");
        return;
    }
    if (id == "castle_salt")
    {
        _screen.Text = this.CastleBuildings.pale_salt_cellar.Flavor
            + "\n\n防腐师在盐桶之间支起了工作台。只要尸骸管够，他们可以在下一次出征前为常驻亡灵做些额外的处理。每种秘仪持续接下来参战的 3 场战斗（没上场的亡灵不扣次数），重复施加只会重新计数。"
            + "\n\n防腐尸骸　" + this.get("Reserve") + " / " + this.reserveLimit() + "　常驻亡灵　" + this.undead().len();
        local active = [];
        foreach (bro in this.undead())
        {
            local summary = this.riteSummary(bro);
            if (summary != "")
                active.push(bro.getName() + summary);
        }
        if (active.len() > 0)
            _screen.Text += "\n\n生效中：" + active.reduce(@(a, b) a + "；" + b);
        foreach (i, rite in this.Rites)
        {
            local index = i;
            this.option(_screen, rite.Name + " · 单名 " + rite.Single + " 点 / 全体 " + rite.All + " 点", function() { S.EmbalmPage = 0; return "@castle_rite_" + index; });
        }
        this.option(_screen, "回到亡灵古堡", @() "@castle");
        return;
    }

    local index = id.slice(12).tointeger();
    local rite = this.Rites[index];
    _screen.Text = this.RiteFlavor[index] + "\n\n【" + rite.Name + "】" + rite.Effect + "。持续接下来参战的 " + rite.Battles + " 场战斗。"
        + "\n\n指定 1 名：" + rite.Single + " 点防腐尸骸　全体常驻亡灵：" + rite.All + " 点（当前库存 " + this.get("Reserve") + " 点）";
    local units = this.undead();
    if (units.len() == 0)
        _screen.Text += "\n\n战团里没有常驻亡灵。";
    else
    {
        if (this.get("Reserve") >= rite.All)
            this.option(_screen, "为全体 " + units.len() + " 名常驻亡灵施加（" + rite.All + " 点）", @() S.applyRite(index, null));
        if (this.get("Reserve") >= rite.Single)
        {
            units.sort(@(a, b) b.getLevel() <=> a.getLevel());
            this.pagedUnits(_screen, units, this.EmbalmPage,
                function( bro )
                {
                    local left = S.riteCharges(bro, rite.Key);
                    return bro.getName() + "（" + bro.getLevel() + " 级" + (left > 0 ? "，还剩 " + left + " 场" : "") + "）";
                },
                @(bro) S.applyRite(index, bro));
        }
        else
            _screen.Text += "\n\n防腐尸骸不足。";
    }
    this.option(_screen, "回到盐窖", @() "@castle_salt");
};
