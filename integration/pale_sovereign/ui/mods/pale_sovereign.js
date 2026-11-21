(function () {
    var paleBanner = "banner_90";
    var showCompanyPanel = NewCampaignMenuModule.prototype.showCompanyCrisisSelectionPanel;
    NewCampaignMenuModule.prototype.showCompanyCrisisSelectionPanel = function () {
        var scenario = this.mScenarios && this.mScenarios[this.mSelectedScenario];
        var paleOrigin = scenario && scenario.ID === "scenario.pale_sovereign";
        if (paleOrigin && !this.mPalePreviousBanners) {
            this.mPalePreviousBanners = this.mBanners;
            this.mPalePreviousBannerIndex = this.mCurrentBannerIndex;
            this.mBanners = [paleBanner].concat(this.mBanners);
            this.mCurrentBannerIndex = 0;
        } else if (!paleOrigin && this.mPalePreviousBanners) {
            this.mBanners = this.mPalePreviousBanners;
            this.mCurrentBannerIndex = this.mPalePreviousBannerIndex;
            this.mPalePreviousBanners = null;
        }
        if (this.mBanners && this.mBanners.length) {
            this.mBannerImage.attr("src", Path.GFX + "ui/banners/" + this.mBanners[this.mCurrentBannerIndex] + ".png");
        }
        showCompanyPanel.call(this);
    };

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

    var createOptionsBar = WorldScreenTopbarOptionsModule.prototype.createDIV;
    WorldScreenTopbarOptionsModule.prototype.createDIV = function (parent) {
        createOptionsBar.call(this, parent);
        var optionsBar = this;
        this.mPaleCampButton = this.mContainer.createTextButton("亡灵营地", function () {
            if (optionsBar.mSQHandle !== null) {
                SQ.call(optionsBar.mSQHandle, "onPaleCampButtonPressed");
            }
        }, "pale-camp-button display-none", 1);
    };

    var destroyOptionsBar = WorldScreenTopbarOptionsModule.prototype.destroyDIV;
    WorldScreenTopbarOptionsModule.prototype.destroyDIV = function () {
        destroyOptionsBar.call(this);
        this.mPaleCampButton = null;
    };

    var updateOptionsBar = WorldScreenTopbarOptionsModule.prototype.onAssetsInformation;
    WorldScreenTopbarOptionsModule.prototype.onAssetsInformation = function (source, data) {
        updateOptionsBar.call(this, source, data);
        if (this.mPaleCampButton && data && data.current) {
            this.mPaleCampButton.toggleClass("display-none", !data.current.PaleCampVisible);
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
            warning = "“枯骨重铸王冠，万魂归于一躯。”\n\n确认立下亡灵冠军誓约，开放缚魂锁链、冠军和候补管理，可征召至多 3 名常驻亡灵。亡灵天灾永久锁定，洗点后仍遵守誓约。";
        } else if (scourge.indexOf(perk.ID) !== -1) {
            warning = "“生者皆为柴薪，万物终归死寂。”\n\n确认立下亡灵天灾誓约，开放尸弹，名册上限提高到 20 人、每场最多部署 16 人，可用全部空余战团编制征召常驻亡灵。亡灵冠军永久锁定，洗点后仍遵守誓约。";
        }
        if (warning !== null) {
            content.find(".right-column").append(
                $('<div class="description description-font-small font-color-title"/>').css({ "margin-top": "0.7em", "white-space": "pre-line" }).text(warning)
            );
        }
        return content;
    };
}());
