// 捕奴背景扩展：俘虏用的“驯兽师”占位背景。
// 只在俘虏记录、估价、试炼敌人等临时场合使用；招募成兄弟时会换回驯犬师背景再由配件兄弟改造（见 mod_hsc_bg_ext.nut）。
this.hsc_ac_beastmaster_background <- this.inherit("scripts/skills/backgrounds/houndmaster_background", {
	m = {},
	function create()
	{
		this.houndmaster_background.create();
		try
		{
			this.applyBeastmasterModification();
		}
		catch (e)
		{
		}
	}
});
