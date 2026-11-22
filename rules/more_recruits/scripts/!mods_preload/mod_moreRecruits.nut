// 城镇招募候选倍率（本地改写自“8倍招募新兵”）：模组设置里 2–10 倍可调，默认 5 倍。
// 新倍率在定居点下次刷新招募修正值时生效。
::MoreRecruits <- {
  ID = "mod_moreRecruits",
  Version = "2.0.0",
  Name = "更多招募新兵",
  Mod = null,
  Default = 5
};

::MoreRecruits.getMult <- function()
{
  try
  {
    if (::MoreRecruits.Mod != null)
      return ::MoreRecruits.Mod.ModSettings.getSetting("RecruitsMult").getValue().tofloat();
  }
  catch (e) {}
  return ::MoreRecruits.Default.tofloat();
};

::MoreRecruits.HooksMod <- ::Hooks.register(::MoreRecruits.ID, ::MoreRecruits.Version, ::MoreRecruits.Name);
::MoreRecruits.HooksMod.require(["mod_msu >= 1.7.0"]);
::MoreRecruits.HooksMod.queue(">mod_msu", function()
{
  ::MoreRecruits.Mod = ::MSU.Class.Mod(::MoreRecruits.ID, ::MoreRecruits.Version, ::MoreRecruits.Name);
  local page = ::MoreRecruits.Mod.ModSettings.addPage("General", "招募");
  page.addRangeSetting("RecruitsMult", ::MoreRecruits.Default, 2, 10, 1, "城镇招募候选倍率",
    "城镇酒馆可招募的新兵数量倍率。1 倍为原版，默认 5 倍。改动后在各定居点下次刷新时生效。");

  ::mods_hookNewObject("entity/world/settlement_modifiers", function(o) {
    o.RecruitsMult *= ::MoreRecruits.getMult();
    local reset = o.reset;
    o.reset = function()
    {
      reset();
      this.RecruitsMult *= ::MoreRecruits.getMult();
    }
  });
});
