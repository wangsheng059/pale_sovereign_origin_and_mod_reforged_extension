::mods_registerMod("mod_moreRecruits", 8, "More recruits (5x)");
::mods_queue(null, null, function()
{
  ::mods_hookNewObject("entity/world/settlement_modifiers", function(o) {
    o.RecruitsMult *= 5;
    local reset = o.reset;
    o.reset = function()
    {
      reset();
      this.RecruitsMult *= 5;
    }
  });
});
