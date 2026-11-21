(function () {
    var createLoadingScreen = LoadingScreen.prototype.createDIV;
    LoadingScreen.prototype.createDIV = function (parent) {
        createLoadingScreen.call(this, parent);
        this.mPaleDefaultLoadingTitle = this.mTipOfTheDayLabel.siblings(".title").text();
    };

    var showLoadingScreen = LoadingScreen.prototype.show;
    LoadingScreen.prototype.show = function (data) {
        showLoadingScreen.call(this, data);
        if (this.mTipOfTheDayLabel !== null) {
            this.mTipOfTheDayLabel.siblings(".title").text(
                data && data.PaleSovereignTitle ? data.PaleSovereignTitle : this.mPaleDefaultLoadingTitle
            );
        }
    };

    var champion = [
        "perk.bgp_necro_possess", "perk.bgp_necro_flesh_reforge",
        "perk.bgp_necro_mind_meld", "perk.bgp_necro_infusion", "perk.bgp_necro_undying_champion"
    ];
    var scourge = [
        "perk.bgp_necro_flesh_of_iron", "perk.bgp_necro_regeneration", "perk.bgp_necro_blood_sucking",
        "perk.bgp_necro_fly_swarm", "perk.bgp_necro_curse_of_ages", "perk.bgp_corpse_explosion"
    ];

    var original = CharacterScreenPerksModule.prototype.createPerkUnlockDialogContent;
    CharacterScreenPerksModule.prototype.createPerkUnlockDialogContent = function (perk) {
        var content = original.call(this, perk);
        var brother = this.mDataSource.getSelectedBrother();
        if (brother == null || brother.PaleOath !== 0) {
            return content;
        }
        var warning = null;
        if (champion.indexOf(perk.ID) !== -1) {
            warning = "确认立下亡灵冠军誓约，开放缚魂锁链、冠军和候补管理。亡灵天灾永久锁定，洗点后仍遵守誓约。";
        } else if (scourge.indexOf(perk.ID) !== -1) {
            warning = "确认立下亡灵天灾誓约，开放尸弹、尸骸储备、常驻亡灵的征召和修补。亡灵冠军永久锁定，洗点后仍遵守誓约。";
        }
        if (warning !== null) {
            content.find(".right-column").append(
                $('<div class="description description-font-small font-color-title"/>').css("margin-top", "0.7em").text(warning)
            );
        }
        return content;
    };
}());
