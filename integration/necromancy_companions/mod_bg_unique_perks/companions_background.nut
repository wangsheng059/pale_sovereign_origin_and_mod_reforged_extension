// 驯兽师（配件兄弟把驯犬师背景改造成驯兽师，ID 变为 background.companions_beastmaster）
if (::BGP.HasAC)
{
	::LocalNecroAC.hook("scripts/skills/backgrounds/houndmaster_background", function(q)
	{
		q.createPerkTreeBlueprint = @(__original) function()
		{
			local tree = __original();
			if (this.m.ID == "background.companions_beastmaster")
				::BGP.setExclusive(tree, ["pg.bgp_beastmaster"]);
			return tree;
		}
	});
}

