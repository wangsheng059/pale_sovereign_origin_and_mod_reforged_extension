// Company Finance History tracker (compacts automatically past 5000 transactions).

::CareerStats.MH.hook("scripts/states/world/asset_manager", function(q)
{
	q.m.CareerStats_FinanceHistory <- [];

	q.create = @(__original) function()
	{
		__original();
		this.m.CareerStats_FinanceHistory = [];
	};

	local FINANCE_HISTORY_SOFT_CAP = 5000;

	q.addMoney = @(__original) function( _f )
	{
		local ret = __original(_f);
		if (!::CareerStats.IsLoading && _f != 0)
		{
			try
			{
				this.m.CareerStats_FinanceHistory.push({
					day = ::World.getTime().Days,
					balance = this.getMoney(),
					delta = _f
				});

				if (this.m.CareerStats_FinanceHistory.len() > FINANCE_HISTORY_SOFT_CAP)
				{
					this.m.CareerStats_FinanceHistory =
						::CareerStats.compactFinanceHistory(this.m.CareerStats_FinanceHistory, 1);
				}
			}
			catch (e) {}
		}

		if (!::CareerStats.IsLoading)
		{
			try
			{
				if ("updateStrengthSnapshots" in ::CareerStats)
					::CareerStats.updateStrengthSnapshots();
			}
			catch (e) {}
		}

		return ret;
	};
});
