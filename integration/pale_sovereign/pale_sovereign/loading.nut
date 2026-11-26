local S = ::PaleSovereign;
local originKey = "Pale.Origin";
local covers = [
    {
        Image = "pale_sovereign_loading.jpg",
        Opening = "荒冢的石门早已合拢。你握着枯骨法杖重返人间，两道誓约正在暗影中静候抉择。"
    },
    {
        Image = "pale_sovereign_champion_loading.jpg",
        Opening = "旧棺的缝隙里透出幽蓝魂火。残破的荒坟守卫握紧锈蚀的长矛与木盾，静候你的第一道号令。"
    },
    {
        Image = "pale_sovereign_scourge_loading.jpg",
        Opening = "晨雾尚未散去，焦土上的死寂已经苏醒。倒下的生者正在路边缓缓起身，等你领他们上路。"
    },
    {
        Image = "pale_sovereign_camp_loading.jpg",
        Opening = "粗盐、黑铁锁链与一本染血的账簿。天亮之前，你还得为这支亡者战团补齐名册。"
    }
];
local lastCover = null;
local tips = [
    "立誓会永久锁定另一条道路，但两条路线均可学习亡灵法术精通与亡灵法术大师。",
    "立誓后，在清剿过的古代遗址附近打开亡者的营地账簿即可勘察。",
    "打赢一仗的战场会自动登记为营地地点。站在 2 格以内打开账簿，就能在那里征召一次常驻亡灵。",
    "立誓后，每征召 1 名常驻亡灵默认消耗 3 点防腐尸骸；完成野心「死者的队列」后降为 2 点。",
    "战胜后，天灾路线每 2 具遗骸封存 1 点防腐尸骸，勇士路线每 5 具封存 2 点。初始上限 40 点，可通过野心、亡灵古堡、盐窖与占领城镇不断扩容。",
    "常驻亡灵免食免薪。若队中有受伤的常驻亡灵，每日会自动消耗 1 点防腐尸骸，为它们修补 40% 最大生命（可通过野心与随从提至 70%）；停留在建有盐窖的古堡时免消耗。",
    "夜战中，亡灵法师导师额外获得 +20 决心，大地图夜间视野惩罚减半。",
    "勇士路线中，使用缚魂锁链标记濒死的强敌，战胜并保全遗骸后即可为其注魂或承誓。",
    "天灾路线中，全团成员均可消耗 1 点防腐尸骸投掷尸弹，落地的尸体可复活或直接引爆。",
    "学会立誓路线的第 6 层特技后，下一次打开亡者的营地时初生骷髅法杖将随誓约发生蜕变。",
    "勇士路线中，荒坟守卫与导师并肩打赢 10 场后，3 枚古代魂玉可将它晋升为尸妖王。击杀敌方冠军有 80% 概率掉落魂玉。",
    "常驻亡灵达到 7 级后，可在营地账簿消耗古代魂玉、防腐尸骸与金币进行中阶与高阶升阶。",
    "营地的尸骸工坊能消耗防腐尸骸急修伤势、拆解负面特质、做肢体拼装与加固尸车扩充仓库；古堡盐窖可施加防腐秘仪。",
    "古代魂玉除用于升阶外，勇士路线可用来魂玉铭刻与灵阶突破，天灾路线可册封魂玉统领并为锁魂者破限。",
    "在亡灵古堡修建魂炉后，可用七种古堡独占配方洗骨、重铸承誓武器、传承棺魂或镶嵌宝石眼窝。",
    "活人兄弟贴着亡灵时远程防御 +5，高士气活人可鼓舞身旁亡灵；8 级以上活人战死后还能在账簿里转为中阶常驻亡灵。",
    "亡灵法师导师若战死，这支战团的复仇便到此为止。"
];

local function loadingData( _newCampaign )
{
    local options = covers.filter(@(_, cover) cover != lastCover);
    local cover = options[::Math.rand(0, options.len() - 1)];
    lastCover = cover;
    return {
        imagePath = "ui/screens/" + cover.Image,
        text = _newCampaign ? cover.Opening : tips[::Math.rand(0, tips.len() - 1)],
        PaleSovereignTitle = _newCampaign ? "亡灵主宰" : "亡者手记"
    };
}

local function isPaleSave( _filename )
{
    foreach (meta in ::PersistenceManager.queryStorages())
        if (meta.getFileName() == _filename)
            return meta.getString(originKey) == S.ID;
    return false;
}

S.Mod.hook("scripts/states/main_menu_state", function(q)
{
    q.loading_screen_onQueryData = @(__original) function()
    {
        local filename = this.m.SelectedCampaignFileName;
        if (filename != null)
            return isPaleSave(filename) ? loadingData(false) : __original();

        local settings = this.m.NewCampaignSettings;
        return settings != null && settings.StartingScenario.getID() == S.ID
            ? loadingData(true) : __original();
    };
});

S.Mod.hook("scripts/states/world_state", function(q)
{
    q.loading_screen_onQueryData = @(__original) function()
    {
        if (this.m.ExitGame)
            return __original();

        local filename = this.m.CampaignToLoadFileName;
        if (filename != null)
            return isPaleSave(filename) ? loadingData(false) : __original();

        if (!S.isActive() || (this.m.CombatProperties == null && this.m.EngageCombatPos == null))
            return __original();

        return S.battleLoadingData(true, S.battleLoadingScene(this.m.CombatProperties, this.m.EngageCombatPos));
    };

    q.onBeforeSerialize = @(__original) function( _out )
    {
        __original(_out);
        if (S.isActive())
            _out.getMetaData().setString(originKey, S.ID);
    };
});

S.Mod.hook("scripts/states/tactical_state", function(q)
{
    q.m.PaleBattleLoadingScene <- "Field";

    q.setStrategicProperties = @(__original) function( _properties )
    {
        local result = __original(_properties);
        if (S.isActive() && _properties != null)
            this.m.PaleBattleLoadingScene = S.battleLoadingScene(_properties);
        return result;
    };

    q.loading_screen_onQueryData = @(__original) function()
    {
        return !this.m.IsExitingToMenu && !this.isScenarioMode() && S.isActive()
            ? S.battleLoadingData(false, this.m.PaleBattleLoadingScene) : __original();
    };
});
