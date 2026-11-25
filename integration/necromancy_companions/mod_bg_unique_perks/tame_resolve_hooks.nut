// Resolve-scaled taming probability and UI hit-chance visibility for companions_tame.
// Keeps Const.Companions.TameChance.Default (30.0) untouched so actor.nut death drops stay 3%.
::BGP.Tame <- {};

::BGP.Tame.getResolveMult <- function( _actor )
{
	local w = ::BGP.Necro.getWill(_actor);
	if (w <= 60)
		return 0.50 + w * 0.01;
	return 1.10 + (w - 60) * 0.005;
};

::BGP.Tame.getBasePct <- function( _actor )
{
	if (_actor != null && _actor.getSkills().hasSkill("background.companions_beastmaster"))
		return ::Const.Companions.TameChance.Beastmaster / 10.0;
	return ::Const.Companions.TameChance.Default / 10.0;
};

::BGP.Tame.getMult <- function()
{
	try
	{
		if ("AC" in ::getroottable() && "getTameChanceMult" in ::AC)
			return ::AC.getTameChanceMult();
	}
	catch (e)
	{
	}
	try
	{
		if ("TameChanceMult" in ::Const.Companions)
			return ::Const.Companions.TameChanceMult;
	}
	catch (e)
	{
	}
	return 1.0;
};

::BGP.Tame.calcChancePct <- function( _actor, _target )
{
	if (_actor == null || _target == null)
		return 0.0;
	local missing = ::Math.maxf(0.0, 1.0 - _target.getHitpointsPct());
	local pct = missing * ::BGP.Tame.getBasePct(_actor) * ::BGP.Tame.getMult() * ::BGP.Tame.getResolveMult(_actor);
	try
	{
		if (_target.getCurrentProperties().IsRooted)
			pct *= 1.25;
	}
	catch (e)
	{
	}
	return ::Math.minf(100.0, ::Math.maxf(0.0, pct));
};

::BGP.Tame.calcRefPct <- function( _actor, _remainPct )
{
	if (_actor == null)
		return 0.0;
	local missing = ::Math.maxf(0.0, 1.0 - _remainPct);
	local pct = missing * ::BGP.Tame.getBasePct(_actor) * ::BGP.Tame.getMult() * ::BGP.Tame.getResolveMult(_actor);
	return ::Math.minf(100.0, ::Math.maxf(0.0, pct));
};

::BGP.Tame.formatPct <- function( _pct )
{
	return (::Math.round(_pct * 10.0) / 10.0) + "%";
};

if (::BGP.HasAC)
{
	::LocalNecroAC.hook("scripts/companions/player/companions_tame", function(q)
	{
		q.create = @(__original) function()
		{
			__original();
			this.m.IsUsingHitchance = true;
		};

		q.getTameChancePct <- function( _targetEntity )
		{
			return ::BGP.Tame.calcChancePct(this.getContainer().getActor(), _targetEntity);
		};

		q.getHitchance = @(__original) function( _targetEntity )
		{
			return ::Math.round(this.getTameChancePct(_targetEntity)).tointeger();
		};

		q.getHitFactors <- function( _targetTile )
		{
			local ret = [];
			if (_targetTile == null || !_targetTile.IsOccupiedByActor)
				return ret;
			local target = _targetTile.getEntity();
			local actor = this.getContainer().getActor();
			if (target == null || actor == null)
				return ret;

			local isBM = actor.getSkills().hasSkill("background.companions_beastmaster");
			local basePct = ::BGP.Tame.getBasePct(actor);
			local mult = ::BGP.Tame.getMult();
			ret.push({
				icon = "ui/tooltips/positive.png",
				text = (isBM ? "驯兽师专精基础率 " : "基础率 ") + basePct + "% × " + mult + " 倍"
			});

			local remainPct = ::Math.round(target.getHitpointsPct() * 100.0);
			local lostPct = ::Math.max(0, 100 - remainPct);
			ret.push({
				icon = lostPct > 0 ? "ui/tooltips/positive.png" : "ui/tooltips/negative.png",
				text = "目标剩余生命 " + remainPct + "%（已损失 " + lostPct + "%）"
			});

			local resolve = ::BGP.Necro.getResolve(actor);
			local rMult = ::BGP.Tame.getResolveMult(actor);
			local rStr = (::Math.round(rMult * 100.0) / 100.0) + "";
			ret.push({
				icon = rMult >= 1.0 ? "ui/tooltips/positive.png" : "ui/tooltips/negative.png",
				text = "当前决心 " + resolve + "（决心系数 ×" + rStr + "）"
			});

			try
			{
				if (target.getCurrentProperties().IsRooted)
					ret.push({ icon = "ui/tooltips/positive.png", text = "目标已被定身（×1.25）" });
			}
			catch (e)
			{
			}
			return ret;
		};

		q.getTooltip = @(__original) function()
		{
			local ret = __original();
			local actor = this.getContainer().getActor();
			local resolve = ::BGP.Necro.getResolve(actor);
			local rMult = ::BGP.Tame.getResolveMult(actor);
			local rStr = (::Math.round(rMult * 100.0) / 100.0) + "";
			local isBM = actor.getSkills().hasSkill("background.companions_beastmaster");
			ret.push({
				id = 8,
				type = "text",
				icon = "ui/icons/bravery.png",
				text = "当前决心 " + ::MSU.Text.colorPositive(resolve + "") + "（决心系数 ×" + rStr + "）" + (isBM ? "，驯兽师基础率 2×" : "")
			});
			ret.push({
				id = 9,
				type = "text",
				icon = "ui/icons/hitchance.png",
				text = "未定身参考成功率：目标剩 50% 血 " + ::BGP.Tame.formatPct(::BGP.Tame.calcRefPct(actor, 0.50))
					+ " / 25% 血 " + ::BGP.Tame.formatPct(::BGP.Tame.calcRefPct(actor, 0.25))
					+ " / 10% 血 " + ::MSU.Text.colorPositive(::BGP.Tame.formatPct(::BGP.Tame.calcRefPct(actor, 0.10)))
					+ " / 5% 血 " + ::MSU.Text.colorPositive(::BGP.Tame.formatPct(::BGP.Tame.calcRefPct(actor, 0.05)))
			});
			ret.push({
				id = 11,
				type = "text",
				icon = "ui/icons/special.png",
				text = "目标被定身时额外 ×1.25；亡灵法师学会第 7 阶“亡灵法术大师”后可驯服亡灵"
			});
			return ret;
		};
	});
}
