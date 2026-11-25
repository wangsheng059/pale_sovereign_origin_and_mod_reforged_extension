// Language- and markup-independent combat attack log parser.
// Supports both Chinese full-width brackets "（几率：X，掷出：Y）" and ASCII "(Chance: X, Rolled: Y)".

local function stripMarkup( _s )
{
	local out = "";
	local i = 0;
	local n = _s.len();
	while (i < n)
	{
		if (_s[i] == '[')
		{
			local j = i + 1;
			while (j < n && _s[j] != ']') j++;
			i = (j < n) ? j + 1 : n;
		}
		else
		{
			out += _s.slice(i, i + 1);
			i++;
		}
	}
	return out;
}

local function lastParenTwoInts( _s )
{
	local close = -1;
	for (local k = _s.len() - 1; k >= 0; k--)
	{
		if (_s[k] == ')') { close = k; break; }
	}
	if (close < 1) return null;

	local open = -1;
	for (local k = close - 1; k >= 0; k--)
	{
		if (_s[k] == '(') { open = k; break; }
	}
	if (open < 0) return null;

	local inside = _s.slice(open + 1, close);
	local nums = [];
	local cur = "";
	local n = inside.len();
	for (local i = 0; i < n; i++)
	{
		local c = inside[i];
		if (c >= '0' && c <= '9')
		{
			cur += inside.slice(i, i + 1);
		}
		else if (cur.len() > 0)
		{
			nums.push(cur.tointeger());
			cur = "";
			if (nums.len() >= 2) break;
		}
	}
	if (cur.len() > 0 && nums.len() < 2) nums.push(cur.tointeger());
	if (nums.len() < 2) return null;

	return { chance = nums[0], rolled = nums[1] };
}

// Parse Chinese full-width attack roll brackets: "...（几率：75，掷出：32）".
local function lastFullwidthParenTwoInts( _s )
{
	local OPEN = "（";
	local CLOSE = "）";

	local close = null;
	local idx = _s.find(CLOSE);
	while (idx != null)
	{
		close = idx;
		idx = _s.find(CLOSE, idx + CLOSE.len());
	}
	if (close == null) return null;

	local open = null;
	idx = _s.find(OPEN);
	while (idx != null && idx < close)
	{
		open = idx;
		idx = _s.find(OPEN, idx + OPEN.len());
	}
	if (open == null) return null;

	local inside = _s.slice(open + OPEN.len(), close);
	if (inside.find("几率") == null || inside.find("掷出") == null) return null;

	return lastParenTwoInts("(" + inside + ")");
}

::CareerStats.MH.hook("scripts/ui/screens/tactical/modules/topbar/tactical_screen_topbar_event_log", function(q)
{
	q.logEx = @(__original) function( _text )
	{
		if (typeof _text == "string")
		{
			local text = stripMarkup(_text);
			local roll = lastFullwidthParenTwoInts(text);
			if (roll == null) roll = lastParenTwoInts(text);
			if (roll != null)
			{
				local chance = roll.chance;
				local hits = roll.rolled <= chance;

				if (::MSU.isKindOf(::CareerStats.ActiveUser, "player")
					&& ("CareerStats_Stats" in ::CareerStats.ActiveUser.m)
					&& ::CareerStats.ActiveUser.m.CareerStats_Stats != null)
				{
					local st = ::CareerStats.ActiveUser.m.CareerStats_Stats.m.Stats;
					if (hits)
					{
						if (chance <= ::CareerStats.MinHitChance) ++st.Num5PercentHits;
						++st.NumAccuracyHits;
					}
					else
					{
						if (chance >= ::CareerStats.MaxHitChance) ++st.Num95PercentMisses;
						++st.NumAccuracyMisses;
					}
				}

				if (::MSU.isKindOf(::CareerStats.ActiveTarget, "player")
					&& ("CareerStats_Stats" in ::CareerStats.ActiveTarget.m)
					&& ::CareerStats.ActiveTarget.m.CareerStats_Stats != null)
				{
					local st = ::CareerStats.ActiveTarget.m.CareerStats_Stats.m.Stats;
					if (hits) ++st.NumAccuracyHitsReceived;
					else ++st.NumAccuracyDodges;
				}
			}
		}

		return __original(_text);
	};
});
