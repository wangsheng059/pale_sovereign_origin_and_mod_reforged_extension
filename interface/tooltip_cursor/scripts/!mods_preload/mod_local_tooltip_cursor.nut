local mod = ::Hooks.register("mod_local_tooltip_cursor", "1.0.0", "缺失光标坐标修复");
mod.queue(">mod_msu", function()
{
	mod.hook("scripts/ui/screens/tooltip/modules/tooltip", function(q)
	{
		foreach (method in ["mouseEnterTile", "mouseHoverTile"])
		{
			q[method] = @(__original) function(...)
			{
				// The world can update before the cursor has a position.
				if (vargv.len() >= 2 && (vargv[0] == null || vargv[1] == null))
					return;
				local args = [this];
				args.extend(vargv);
				return __original.acall(args);
			};
		}
	});
});
