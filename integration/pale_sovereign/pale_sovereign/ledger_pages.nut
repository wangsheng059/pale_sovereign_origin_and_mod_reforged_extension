local S = ::PaleSovereign;

// 1.7.0 营地账簿的附加页面：S.addPage 登记页面 ID、标题、插画和绘制函数，
// 渲染后自动加上插画和“返回营地”。页面 ID 需在战役创建事件前登记（各模块加载时完成）。
S.ExtraPageIDs <- [];
S.ExtraPages <- {};
S.PickUnitID <- 0;
S.PickValue <- null;

S.addPage <- function( _id, _title, _art, _render, _back = "@camp" )
{
    if (!(_id in this.ExtraPages))
        this.ExtraPageIDs.push(_id);
    this.ExtraPages[_id] <- { Title = _title, Art = _art, Render = _render, Back = _back };
};

S.findBroByID <- function( _id )
{
    foreach (bro in ::World.getPlayerRoster().getAll())
        if (bro.getID() == _id)
            return bro;
    return null;
};

local renderBase = S.renderEvent;
S.renderEvent = function( _event, _screen )
{
    if (!(_screen.ID in this.ExtraPages))
        return renderBase.call(this, _event, _screen);
    local page = this.ExtraPages[_screen.ID];
    _screen.Text = "";
    local art = page.Render(_event, _screen);
    if (typeof art != "string")
        art = page.Art;
    _event.m.Title = page.Title;
    _event.m.PaleArt = art;
    _screen.Text = "[img]gfx/ui/events/pale/" + art + ".jpg[/img]" + _screen.Text;
    if (page.Back != null)
    {
        local back = page.Back;
        this.option(_screen, back == "@camp" ? "返回营地" : "返回上一页", @() back);
    }
};

// 资源一行摘要
S.resourceLine <- function()
{
    return "防腐尸骸 " + this.get("Reserve") + " / " + this.reserveLimit() + "　古代魂玉 " + this.countItems("misc.pale_jade")
        + "　缚魂锁链 " + this.countItems("misc.pale_chain");
};
