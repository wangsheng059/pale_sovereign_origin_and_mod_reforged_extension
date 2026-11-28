// MSU ModSettings for standalone gameplay rules in zz_local_rules.zip.
::BGP.Defaults <- {
	BGP_VisionMult = 2.0,
	BGP_LargeCompanyXP = true,
	BGP_ForceEnemyLoot = true,
	BGP_SaveBrokenNamed = true,
	BGP_BannerBuff = true,
	BGP_EagleEyesBuff = true
};

::BGP.getSetting <- function( _id, _fallback = null )
{
	try
	{
		if (::BGP.Mod != null)
		{
			local s = ::BGP.Mod.ModSettings.getSetting(_id);
			if (s != null)
				return s.getValue();
		}
	}
	catch (e) {}
	if (_id in ::BGP.Defaults)
		return ::BGP.Defaults[_id];
	return _fallback;
};

::BGP.applyVisionMult <- function( _mult = null )
{
	if (!("World" in ::Const) || !("TerrainTypeVisionRadiusMult" in ::Const.World))
		return;
	if (!("BGP_BaseTerrainVision" in ::Const.World) || ::Const.World.BGP_BaseTerrainVision == null)
		::Const.World.BGP_BaseTerrainVision <- clone ::Const.World.TerrainTypeVisionRadiusMult;

	local mult = _mult != null ? _mult.tofloat() : ::BGP.getSetting("BGP_VisionMult", 2.0).tofloat();
	if (mult < 1.0) mult = 1.0;
	if (mult > 5.0) mult = 5.0;

	local orig = ::Const.World.BGP_BaseTerrainVision;
	local target = ::Const.World.TerrainTypeVisionRadiusMult;
	local n = ::Math.min(orig.len(), target.len());
	for (local i = 0; i < n; i++)
		target[i] = orig[i] * mult;
};

::BGP.refreshRosterSkills <- function()
{
	try
	{
		if (!("World" in ::getroottable()) || ::World == null || ::World.getPlayerRoster() == null)
			return;
		foreach (bro in ::World.getPlayerRoster().getAll())
		{
			if (bro == null || ::MSU.isNull(bro))
				continue;
			try { bro.getSkills().update(); } catch (e) {}
		}
	}
	catch (e) {}
};

::BGP.refreshAllBanners <- function( _enabled = null )
{
	try
	{
		if (!("World" in ::getroottable()) || ::World == null)
			return;
		if (::World.getPlayerRoster() != null)
		{
			foreach (bro in ::World.getPlayerRoster().getAll())
			{
				if (bro == null || ::MSU.isNull(bro))
					continue;
				local items = bro.getItems();
				if (items == null)
					continue;
				local mh = items.getItemAtSlot(::Const.ItemSlot.Mainhand);
				if (mh != null && ("BGP_syncBannerBuff" in mh))
					mh.BGP_syncBannerBuff(_enabled);
				local bag = items.getAllItemsAtSlot(::Const.ItemSlot.Bag);
				if (bag != null)
				{
					foreach (it in bag)
					{
						if (it != null && ("BGP_syncBannerBuff" in it))
							it.BGP_syncBannerBuff(_enabled);
					}
				}
				try { bro.getSkills().update(); } catch (e) {}
			}
		}
		if (("Assets" in ::World) && ::World.Assets != null && ::World.Assets.getStash() != null)
		{
			foreach (it in ::World.Assets.getStash().getItems())
			{
				if (it != null && ("BGP_syncBannerBuff" in it))
					it.BGP_syncBannerBuff(_enabled);
			}
		}
	}
	catch (e) {}
};

::BGP.Mod = ::MSU.Class.Mod(::BGP.ID, ::BGP.Version, ::BGP.Name);
local page = ::BGP.Mod.ModSettings.addPage("General", "玩法规则");

page.addRangeSetting("BGP_VisionMult", 2.0, 1.0, 5.0, 0.5,
	"大地图视野倍率",
	"按原版各森山平地比例缩放战团大地图视野半径（1 = 原版视野，5 = 5 倍视野，修改后立即生效）。")
	.addAfterChangeCallback(function( _oldValue ) { ::BGP.applyVisionMult(); });

page.addBooleanSetting("BGP_LargeCompanyXP", true,
	"大规模战队经验补偿",
	"上场兄弟超过 12 人时，按「上场人数 ÷ 12」放大战斗经验，抵消大编队均摊导致的升级变慢（世界事件与固定经验不变）。");

page.addBooleanSetting("BGP_ForceEnemyLoot", true,
	"强制掉落敌人全部装备",
	"开启时，敌人携带的护甲与武器无视耐久门槛必定进入战利品结算；关闭后恢复原版与起源掉落规则。");

page.addBooleanSetting("BGP_SaveBrokenNamed", true,
	"具名与传奇武盾损毁保留",
	"开启时，战斗中被打碎的红装（具名）或传奇武器、盾牌掉落在地上而不会永久消失。");

page.addBooleanSetting("BGP_BannerBuff", true,
	"战旗增强",
	"开启时，战团战旗基础伤害由 50–70 提升至 70–90，并附带「收割」范围技能；关闭后恢复原版战旗。")
	.addAfterChangeCallback(function( _oldValue ) { ::BGP.refreshAllBanners(); });

page.addBooleanSetting("BGP_EagleEyesBuff", true,
	"鹰眼特性强化",
	"开启时，「鹰眼」特性额外提供 +5 远程技能、+20% 命中头部几率，并将视野加成提高至 +5；关闭后恢复原版 +1 视野。")
	.addAfterChangeCallback(function( _oldValue ) { ::BGP.refreshRosterSkills(); });

::BGP.applyVisionMult();
