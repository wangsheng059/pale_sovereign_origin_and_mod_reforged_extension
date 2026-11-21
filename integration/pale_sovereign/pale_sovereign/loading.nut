local S = ::PaleSovereign;
local originKey = "Pale.Origin";
local covers = [
    {
        Image = "pale_sovereign_loading.jpg",
        Opening = "葬钟已经停了。你提灯踏入地宫，两道誓约正等着你。"
    },
    {
        Image = "pale_sovereign_champion_loading.jpg",
        Opening = "石棺中的魂玉尚有微光。古代战士握起战戟，静候一声号令。"
    },
    {
        Image = "pale_sovereign_scourge_loading.jpg",
        Opening = "晨雾还未散去。倒下的人已在路边列队，等你领他们上路。"
    },
    {
        Image = "pale_sovereign_camp_loading.jpg",
        Opening = "盐、锁链和一本账簿。天亮前，你还得为战团补齐名册。"
    }
];
local lastCover = null;
local tips = [
    "立誓会锁定道路。两条路线都能学习死灵精通。",
    "在清剿过的遗址附近扎营，立誓后可从营地账簿勘察。",
    "亡灵天灾每征召一名常驻亡灵，需消耗三点防腐尸骸。",
    "亡灵天灾战胜后，每两具合格遗骸可封存一点防腐尸骸。",
    "夜战中，亡灵法师导师额外获得二十点决心。",
    "常驻亡灵免食免薪。每日可消耗一点防腐尸骸修补伤员。",
    "亡灵法师导师若战死，这支战团的故事也就结束了。"
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
        local filename = this.m.CampaignToLoadFileName;
        return !this.m.ExitGame && filename != null && isPaleSave(filename)
            ? loadingData(false) : __original();
    };

    q.onBeforeSerialize = @(__original) function( _out )
    {
        __original(_out);
        if (S.isActive())
            _out.getMetaData().setString(originKey, S.ID);
    };
});
