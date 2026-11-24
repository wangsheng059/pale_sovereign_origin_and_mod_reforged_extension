/* ==========================================================================
 * BB Seed Tool - heavily reworked community edition (UI layer).
 *
 * ORIGIN: based on an earlier Battle Brothers seed search mod whose
 * original author is unknown to the current maintainer. If that is you
 * and you have any concerns, please get in touch and state your purpose:
 * QQ 76345492 (walter).
 *
 * AUTHORSHIP: massively restructured and extended with many new features
 * by walter (QQ 76345492) since v1.32. The current version differs
 * substantially from the original base mod.
 * ========================================================================== */
(function () {
    "use strict";

    /* This mod owns its translations. Do not read or replace the game's
       localization tables: that keeps it independent from Chinese mods. */
    var currentLanguage = "zh";
    var pageOffset = 0;
    var lastMatched = 0;
    var lastResult = null;
    var lastStatus = null;
    var querySeq = 0;
    var portMinimum = 0;
    var requireSouthNorthPort = false;
    var requireArenaPort = false;
    var talentTop100 = 10000;
    var quickTraits = [];
    var detailStars = {smsk3:false, smsk2:false, smdf3:false, smdf2:false, sftg3:false, sftg2:false, sini3:false, sini2:false, srsk3:false, srsk2:false, noNegative:false};
    var sortField = "talent";
    var sortDir = "desc";
    var markFilter = "all";
    var northLine = 80;
    var southLine = 0;
    var pendingSouthLine = null;
    var collectionStartTime = 0;
    var runTimer = null;
    var traitOptions = [];
    var numericKeysDown = {};
    var lastNumericPress = {input:null, digit:"", time:0};
    var pendingCampaign = null;
    var campaignSeedHookInstalled = false;
    var loadMenuFilterInstalled = false;
    var saveMenuFilterInstalled = false;
    var collectionPrompt = null;
    var collectionMode = "full";
    var lastRateMsPerSeed = 0;
    var backfillQueue = [];
    var collectionIsBackfill = false;
    var collectionStartedFlag = false;
    var collectionWatchdog = null;
    var startInFlight = false;
    var cleanupTimer = null;
    var wipeTimer = null;
    var lastWheel = {target:null, direction:0, time:0};

    var text = {
        zh: {
            launcher: "\u79cd\u5b50\u5de5\u5177", title: "BB \u79cd\u5b50\u7b5b\u9009\u5668", loading: "\u6b63\u5728\u8bfb\u53d6\u6570\u636e\u5e93...",
            stop: "\u5b89\u5168\u505c\u6b62", close: "\u5173\u95ed", count: "\u6bcf\u6b21\u751f\u6210\u6570\u91cf", apply: "\u5e94\u7528\u6570\u91cf", startCollection: "\u5f00\u59cb\u521b\u5efa\u79cd\u5b50",
            instructions: "\u4ece\u4e0a\u81f3\u4e0b\u4f9d\u6b21\u8bbe\u5b9a\uff1a\u6570\u91cf \u2192 \u6a21\u5f0f \u2192 \u8d77\u6e90\uff0c\u7136\u540e\u70b9\u51fb\u201c\u5f00\u59cb\u521b\u5efa\u79cd\u5b50\u201d\u3002\u7ed3\u679c\u4f1a\u81ea\u52a8\u6c38\u4e45\u4fdd\u5b58\u3002",
            origin: "\u8d77\u6e90", anyOrigin: "\u5168\u90e8\u8d77\u6e90", ports: "\u6e2f\u53e3\u6570", anyPorts: "\u4e0d\u9650", atLeastPorts: "\u2265{count}", portNature: "\u6e2f\u53e3\u6027\u8d28", northLine: "\u5317\u6e2f\u5224\u5b9a\u7ebf", anyPortNature: "\u4e0d\u9650", southNorthPort: "\u5357\u5317\u6e2f", arenaPort: "\u7ade\u6280\u6e2f\u53e3", yes: "\u6709", no: "\u65e0", unknown: "\u65e0\u6570\u636e", topPercent: "\u524d{percent}%", slot: "\u4eba\u7269", anyBrother: "\u4efb\u610f\u4eba\u7269", allBrothers: "\u5168\u90e8\u4eba\u7269", brotherNumber: "\u4eba\u7269{index}", mapFilter: "\u6570\u636e\u5e93\u8303\u56f4", attributeFilter: "\u5c5e\u6027\u4e0b\u9650", groupGenerate: "\u751f\u6210\u79cd\u5b50", groupLibrary: "\u79cd\u5b50\u5e93\u7ba1\u7406", groupTalent: "\u4eba\u624d\u7d20\u8d28\uff08\u4f5c\u7528\u4e8e\u89d2\u8272\uff09", groupMap: "\u5730\u56fe\u4e0e\u6807\u8bb0", originScopeHint: "\u65e2\u662f\u5f00\u5237\u7684\u8d77\u6e90\u9009\u62e9\uff0c\u4e5f\u662f\u4e0b\u65b9\u7ed3\u679c\u7684\u7b5b\u9009\u8303\u56f4",
            msk: "\u8fd1\u653b", mdf: "\u8fd1\u9632", rsk: "\u8fdc\u653b", rdf: "\u8fdc\u9632", hp: "\u751f\u547d", fat: "\u75b2\u52b3", res: "\u51b3\u5fc3", init: "\u4e3b\u52a8",
            required: "\u5305\u542b\u7279\u6027", banned: "\u6392\u9664\u7279\u6027", anyTrait: "\u4e0d\u9650", quickTraitFilter: "\u5305\u542b\u7279\u6027", quickTraitDrunkard: "\u9152\u9b3c", quickTraitHuge: "\u5de8\u5927", quickTraitSteady: "\u7a33\u6b65", quickTraitParanoid: "\u504f\u6267/\u591a\u7591", traitMaxHint: "\u7b5b\u9009\u7279\u6027\u6700\u591a\u540c\u65f6\u9009\u4e2d2\u4e2a\uff0c\u5355\u51fb\u9009\u62e9/\u53d6\u6d88\u3002", clear: "\u6e05\u7a7a", search: "\u641c\u7d22", reset: "\u7b5b\u9009\u6761\u4ef6\u91cd\u7f6e", previous: "\u4e0a\u4e00\u9875", next: "\u4e0b\u4e00\u9875",
            initial: "\u6b63\u5728\u8bfb\u53d6\u6570\u636e\u5e93...", searching: "\u6b63\u5728\u641c\u7d22\u6c38\u4e45\u6570\u636e\u5e93...", scanning: "\u6b63\u5728\u626b\u63cf {total} \u9897\u79cd\u5b50\u2026",
            status: "{total} \u4e2a\u79cd\u5b50\uff0c{batches} \u4e2a\u5df2\u4fdd\u5b58\u6279\u6b21", countSet: "\u6bcf\u6b21\u751f\u6210\u6570\u91cf\u5df2\u8bbe\u4e3a {count}",
            matched: "\u5339\u914d {matched}/{total}\uff0c\u663e\u793a {start}-{end}\u3002", seed: "\u79cd\u5b50", port: "\u6e2f\u53e3", settlements: "\u57ce\u9547", brothers: "\u4eba\u7269", traits: "\u7279\u6027", none: "\u65e0", useSeed: "\u4f7f\u7528\u6b64\u79cd\u5b50", talent: "\u4eba\u624d", talentAll: "\u5168\u90e8", talentTop50: "\u524d50%", talentTop20: "\u524d20%", talentTop5: "\u524d5%", talentAverage: "\u4eba\u624d\u5747\u5206", talentPercentile: "\u540c\u8d77\u6e90\u6392\u540d", brotherTalent: "\u4eba\u624d", projectedMelee: "\u9884\u8ba111\u7ea7\u8fd1\u653b", talentScaleTitle: "\u4eba\u624d\u8bc4\u5206\u53c2\u8003", talentScaleAttack: "\u9884\u8ba111\u7ea7\u8fd1\u653b", talentScaleScore: "\u4eba\u624d\u5206",
            detail: "\u661f\u4f4d", starMsk3: "\u8fd1\u653b3\u2605", starMsk2: "\u8fd1\u653b2\u2605", starMdf3: "\u8fd1\u96323\u2605", starMdf2: "\u8fd1\u96322\u2605", starFtg3: "\u75b2\u52b33\u2605", starFtg2: "\u75b2\u52b32\u2605", starIni3: "\u4e3b\u52a83\u2605", starIni2: "\u4e3b\u52a82\u2605", starRsk2: "\u8fdc\u653b2\u2605", noNegative: "\u65e0\u8d1f\u9762", starLabelVert: "\u661f<br>\u4f4d", nonegVert: "\u65e0<br>\u8d1f<br>\u9762", maxScore: "\u6700\u9ad8\u5206", batch: "\u6279\u6b21", mark: "\u6807\u8bb0", markFilter: "\u6807\u8bb0", markYes: "\u662f", markNo: "\u5426", southLine: "\u5357\u6e2f\u5224\u5b9a\u7ebf", southDesert: "\u6c99\u6f20\u57ce\u90a6", southRowHint: "\u5207\u6362\u6863\u4f4d\u540e\uff0c\u65e7\u79cd\u5b50\u9700\u8865\u6d4b\u624d\u751f\u6548", southSwitchTitle: "\u5207\u6362\u5357\u6e2f\u5224\u5b9a\u7ebf", southSwitchDesc: "\u79cd\u5b50\u5e93\u4e2d\u6709 {count} \u9897\u65e7\u7248\u672c\u79cd\u5b50\u7f3a\u5c11\u5357\u6e2f\u5224\u5b9a\u6570\u636e\uff0820% / 35% / 50% \u6863\u4f4d\uff09\u3002", southSwitchNote: "\u4e0d\u8865\u6d4b\u7684\u8bdd\uff0c\u8fd9\u4e9b\u65e7\u79cd\u5b50\u5728\u65b0\u6863\u4f4d\u4e0b\u4f1a\u88ab\u89c6\u4e3a\u300c\u65e0\u5357\u6e2f\u300d\uff1b\u8865\u6d4b\u5730\u56fe\u540e\u65b0\u6863\u4f4d\u7acb\u5373\u751f\u6548\u3002\u8865\u6d4b\u671f\u95f4\u53ef\u968f\u65f6\u5b89\u5168\u505c\u6b62\uff0c\u5269\u4f59\u6570\u91cf\u4f1a\u5728\u4e0b\u6b21\u5207\u6362\u65f6\u7ee7\u7eed\u63d0\u793a\u3002", southSwitchCancel: "\u53d6\u6d88\uff0c\u4fdd\u6301\u6c99\u6f20\u57ce\u90a6", southSwitchGo: "\u7acb\u5373\u8865\u6d4b {count} \u9897",
            runElapsedLabel: "\u5df2\u8017\u65f6\uff1a", lastRateLabel: "\u6700\u65b0\u6279\u6b21\u901f\u5ea6\uff1a", lastElapsedLabel: "\u4e0a\u6279\u6b21\u751f\u6210\u8017\u65f6\uff1a", hourUnitShort: "\u65f6", runRateLabel: "\u5e73\u5747\uff1a", runRate: "{rate}\u79cd\u5b50/\u79d2", runRatePending: "\u7edf\u8ba1\u4e2d\u2026", etaRunLabel: "\u9884\u8ba1\u5269\u4f59\uff1a", hourUnit: "\u5c0f\u65f6", minuteUnit: "\u5206", secondUnit: "\u79d2",
            confirmTitle: "\u5f00\u59cb\u5237\u79cd", confirmWarning: "\u5237\u79cd\u671f\u95f4\u6e38\u620f\u53ef\u80fd\u6682\u65f6\u5361\u4f4f\u3002\u8bf7\u4e0d\u8981\u70b9\u51fb\u6216\u6309\u952e\uff1b\u6570\u91cf\u8f83\u591a\u65f6\u8bf7\u8010\u5fc3\u7b49\u5f85\u3002", confirmSummary: "\u8d77\u6e90\uff1a{origin}\u3000\u6570\u91cf\uff1a{total}", confirmStart: "\u786e\u8ba4\u5f00\u5237", confirmCancel: "\u53d6\u6d88", chooseOriginTitle: "\u8bf7\u9009\u62e9\u8d77\u6e90", chooseOriginFirst: "\u5f00\u5237\u524d\u8bf7\u5148\u9009\u62e9\u4e00\u4e2a\u5177\u4f53\u8d77\u6e90\uff0c\u4e0d\u80fd\u4f7f\u7528\u201c\u5168\u90e8\u8d77\u6e90\u201d\u3002", noticeOK: "\u77e5\u9053\u4e86", runningTitle: "\u6b63\u5728\u5237\u79cd", runSaved: "\u5df2\u4fdd\u5b58\u603b\u6570\uff1a{saved}",
            starting: "\u5f00\u59cb\u751f\u6210 {total} \u4e2a\u79cd\u5b50...", progress: "\u8fdb\u5ea6 {done}/{total} - \u5df2\u4fdd\u5b58\u603b\u6570 {saved}", stopping: "\u5f53\u524d\u79cd\u5b50\u5b8c\u6210\u540e\u5c06\u5b89\u5168\u505c\u6b62\u5e76\u63d0\u4ea4\u6570\u636e...",
            finished: "\u5df2\u5b8c\u6210\uff1a\u751f\u6210 {done} \u4e2a - \u5df2\u4fdd\u5b58\u603b\u6570 {saved}", stopped: "\u5df2\u5b89\u5168\u505c\u6b62\uff1a\u751f\u6210 {done} \u4e2a - \u5df2\u4fdd\u5b58\u603b\u6570 {saved}", error: "\u9519\u8bef\uff1a{error}",
            modeLabel: "\u751f\u6210\u6a21\u5f0f", modeFull: "\u542b\u5730\u56fe", modeTalent: "\u4ec5\u4eba\u624d",
            modeHintFull: "\u542b\u5730\u56fe\uff1a\u5b8c\u6574\u751f\u6210\u5730\u56fe\u4e0e\u89d2\u8272\uff0c\u901f\u5ea6\u8f83\u6162\u3002\u9003\u5175\u8d77\u6e90\u53ea\u80fd\u7528\u6b64\u6a21\u5f0f\u3002", modeHintTalent: "\u4ec5\u4eba\u624d\uff1a\u53ea\u6447\u89d2\u8272\uff0c\u5feb\u6570\u5341\u500d\uff1b\u65e0\u5730\u56fe\u6570\u636e\uff0c\u53ef\u4e8b\u540e\u8865\u6d4b\u3002",
            starRsk3: "\u8fdc\u653b3\u2605", detailHint: "\u70b9\u51fb\uff1a\u9009\u4e2d/\u53d6\u6d88", detailHintMax: "\u661f\u4f4d\u6700\u591a\u540c\u65f6\u90093\u6761\uff1b\u540c\u5c5e\u6027\u9009\u4e2d3\u2605\u751f\u6548\uff0c2\u2605\u5931\u6548\u3002",
            backfillBar: "\u8865\u6d4b\u5168\u90e8\u5730\u56fe\uff08\u5f53\u524d\u7ed3\u679c {count} \u9897\u65e0\u6570\u636e\uff09", backfillRow: "\u8865\u6d4b", backfillTitle: "\u8865\u6d4b\u5730\u56fe",
            backfillDesc: "\u5c06\u5bf9\u5f53\u524d\u7b5b\u9009\u7ed3\u679c\u4e2d {count} \u9897\u672a\u7edf\u8ba1\u5730\u56fe\u6570\u636e\u7684\u79cd\u5b50\u91cd\u65b0\u5b8c\u6574\u751f\u6210\u5730\u56fe\uff0c\u8865\u5199\u5730\u56fe\u6570\u636e\uff08\u6e2f\u53e3\u6570 / \u5357\u5317\u6e2f / \u7ade\u6280\u6e2f\u53e3 / \u5317\u6e2f\u5224\u5b9a\u7ebf\u4e09\u6863\uff09\u3002",
            backfillEta: "\u9884\u8ba1\u8017\u65f6\u7ea6 {eta}\uff08\u6309\u672c\u673a\u6700\u8fd1\u6279\u6b21\u5b9e\u6d4b\u901f\u5ea6 {rate} \u4f30\u7b97\uff09\u3002\u79cd\u5b50\u7684\u6279\u6b21\u3001\u4eba\u624d\u6570\u636e\u548c\u4f60\u7684\u6807\u8bb0\u4fdd\u6301\u4e0d\u53d8\u3002",
            backfillNoEta: "\u79cd\u5b50\u7684\u6279\u6b21\u3001\u4eba\u624d\u6570\u636e\u548c\u4f60\u7684\u6807\u8bb0\u4fdd\u6301\u4e0d\u53d8\u3002",
            backfillMulti: "\u7ed3\u679c\u8de8\u591a\u4e2a\u8d77\u6e90\u65f6\u4f1a\u6309\u8d77\u6e90\u81ea\u52a8\u5206\u6279\u8fdb\u884c\u3002", backfillStart: "\u5f00\u59cb\u8865\u6d4b", backfillCancel: "\u53d6\u6d88",
            backfillRunningTitle: "\u6b63\u5728\u8865\u6d4b\u5730\u56fe\u6570\u636e", backfillWarning: "\u8865\u6d4b\u4f1a\u4e3a\u9009\u4e2d\u7684\u79cd\u5b50\u91cd\u65b0\u751f\u6210\u5b8c\u6574\u5730\u56fe\uff0c\u4ec5\u8865\u5145\u6e2f\u53e3/\u7ade\u6280\u573a\u7b49\u5730\u56fe\u6570\u636e\uff1b\u89d2\u8272\u6570\u636e\u3001\u6279\u6b21\u3001\u6807\u8bb0\u4fdd\u6301\u4e0d\u53d8\u3002\u671f\u95f4\u6e38\u620f\u53ef\u80fd\u6682\u65f6\u5361\u4f4f\uff0c\u8bf7\u52ff\u70b9\u51fb\u6216\u6309\u952e\u3002", backfillSummary: "\u8d77\u6e90\uff1a{origin}\u3000\u5171 {total} \u9897", backfillProgress: "\u5df2\u8865\u6d4b {done} / {total}", backfillSaved: "\u5df2\u4fdd\u5b58\u8865\u6d4b\u7ed3\u679c\uff1a{saved} \u9897", backfillStop: "\u53d6\u6d88\u8865\u6d4b",
            etaLabel: "\u9884\u8ba1\u5269\u4f59\uff1a", etaPending: "\u4f30\u7b97\u4e2d\u2026", startRejected: "\u5237\u79cd\u672a\u80fd\u542f\u52a8\uff085 \u79d2\u5185\u65e0\u54cd\u5e94\uff09\uff0c\u5df2\u81ea\u52a8\u590d\u4f4d\uff0c\u8bf7\u91cd\u8bd5\uff1b\u82e5\u53cd\u590d\u51fa\u73b0\uff0c\u8bf7\u628a log.html \u4e00\u5e76\u53d1\u7ed9\u4f5c\u8005\u6392\u67e5\u3002",
            startSlow: "\u8fdb\u5165\u4e16\u754c\u8017\u65f6\u8f83\u957f\uff0c\u4ecd\u5728\u8fdb\u884c\u4e2d\uff0c\u8bf7\u8010\u5fc3\u7b49\u5f85\uff1b\u82e5\u786e\u8ba4\u5361\u4f4f\uff0c\u53ef\u70b9\u4e0b\u65b9\u6309\u94ae\u53d6\u6d88\u3002", startCancelled: "\u5df2\u53d6\u6d88\u672c\u6b21\u542f\u52a8\u3002",
            backfillDoneTitle: "\u8865\u6d4b\u5b8c\u6210", backfillDoneText: "\u6210\u529f\u8865\u6d4b {done} \u9897\u79cd\u5b50\u7684\u5730\u56fe\u6570\u636e\u3002", backfillSkipped: "\u53e6\u6709 {count} \u9897\u4e0d\u5728\u5e93\u4e2d\uff0c\u5df2\u8df3\u8fc7\u3002", backfillStoppedTitle: "\u5df2\u53d6\u6d88\u8865\u6d4b", backfillStoppedText: "\u5df2\u8865\u6d4b {done} \u9897\u5e76\u4fdd\u7559\uff0c\u5176\u4f59\u4fdd\u6301\u672a\u7edf\u8ba1\uff0c\u53ef\u968f\u65f6\u518d\u6b21\u8865\u6d4b\u3002",
            talentDesertersError: "\u9003\u5175\u8d77\u6e90\u7684\u89d2\u8272\u4f9d\u8d56\u5730\u56fe\u751f\u6210\uff0c\u4ec5\u4eba\u624d\u6a21\u5f0f\u4e0d\u652f\u6301\u8be5\u8d77\u6e90\uff0c\u8bf7\u6539\u7528\u300c\u542b\u5730\u56fe\u300d\u6a21\u5f0f\u3002",
            cleanupBtn: "\u4ec5\u4eba\u624d\u6a21\u5f0f\u6e05\u7406",
            cleanupHint: "\u6e05\u7406\u5220\u9664\u6240\u6709\u672a\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u4e14\u65e0\u5730\u56fe\u6570\u636e\u7684\u4ec5\u4eba\u624d\u79cd\u5b50\uff1b\u542b\u5730\u56fe\u7684\u79cd\u5b50\u548c\u5df2\u6807\u8bb0\u7684\u79cd\u5b50\u4e0d\u53d7\u5f71\u54cd\u3002\u5220\u9664\u524d\u6709\u4e8c\u6b21\u786e\u8ba4\u548c\u5012\u8ba1\u65f6\u3002",
            cleanupAdvice: "\u5efa\u8bae\u7528\u201c\u4ec5\u4eba\u624d\u201d\u7b5b\u9009\u89d2\u8272\u540e\uff0c\u901a\u8fc7\u6807\u8bb0\u4fdd\u5b58\u79cd\u5b50\uff0c\u6e05\u7406\u5b8c\u591a\u4f59\u79cd\u5b50\u540e\u8fdb\u884c\u8865\u6d4b\u5730\u56fe\u6570\u636e\u3002",
            cleanupTitle: "\u4ec5\u4eba\u624d\u6a21\u5f0f\u6e05\u7406", cleanupNone: "\u6ca1\u6709\u53ef\u6e05\u7406\u7684\u4ec5\u4eba\u624d\u79cd\u5b50\u3002",
            cleanupDesc: "\u672c\u6b21\u5c06\u5220\u9664 {count} \u9897\u672a\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u4e14\u65e0\u5730\u56fe\u6570\u636e\u7684\u4ec5\u4eba\u624d\u79cd\u5b50\u3002",
            cleanupWarn: "\u6ce8\u610f\uff1a\u5176\u4e2d\u542b\u6709 {high} \u9897\u6700\u9ad8\u5206 \u2265 90 \u7684\u79cd\u5b50\uff08{examples}\uff09\uff0c\u5c06\u88ab\u4e00\u5e76\u5220\u9664\u3002\u662f\u5426\u7ee7\u7eed\uff1f",
            cleanupYes: "\u662f\uff0c\u7ee7\u7eed\u5220\u9664", cleanupNo: "\u5426\uff0c\u53d6\u6d88", cleanupCancel: "\u53d6\u6d88",
            cleanupCountdown: "\u5c06\u5728 {sec} \u79d2\u540e\u6267\u884c\u5220\u9664\u64cd\u4f5c\uff1a", cleanupDone: "\u6e05\u7406\u5b8c\u6210\uff1a\u5df2\u5220\u9664 {count} \u9897\u4ec5\u4eba\u624d\u79cd\u5b50\u3002",
            wipe: "\u6e05\u7a7a\u79cd\u5b50\u5e93\uff08\u9632\u7b5b\u9009\u5361\u987f\uff09", wipeTitle: "\u6e05\u7a7a\u79cd\u5b50\u5e93", wipeNone: "\u5f53\u524d\u6ca1\u6709\u5df2\u4fdd\u5b58\u7684\u79cd\u5b50\u3002",
            wipeDesc: "\u5c06\u5220\u9664\u672c\u5730\u5168\u90e8 {count} \u9897\u5df2\u4fdd\u5b58\u7684\u79cd\u5b50\uff08\u5305\u62ec\u5df2\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u7684\u79cd\u5b50\uff09\u3002\u5220\u9664\u540e\u672c\u5730\u79cd\u5b50\u6570\u5f52\u96f6\uff0c\u4e0d\u53ef\u6062\u590d\u3002",
            wipeCountdown: "{sec} \u79d2\u540e\u81ea\u52a8\u6267\u884c\u5220\u9664\u3002\u5982\u9700\u4fdd\u7559\uff0c\u8bf7\u70b9\u51fb\u4e0b\u65b9\u6309\u94ae\u53d6\u6d88\u3002",
            wipeCancel: "\u53d6\u6d88\uff08\u4fdd\u7559\u79cd\u5b50\uff09", wipeDone: "\u5df2\u5220\u9664 {count} \u9897\u79cd\u5b50\uff0c\u79cd\u5b50\u5e93\u5df2\u6e05\u7a7a\u3002",
            wipeFailed: "\u6e05\u7a7a\u5931\u8d25\uff1a",
            exportSeeds: "\u5bfc\u51fa\u79cd\u5b50", importSeeds: "\u5bfc\u5165\u79cd\u5b50",
            transferHint: "\u5c06\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u7684\u79cd\u5b50\u6587\u4ef6\u6253\u5305\u5bfc\u51fa\u3002\u672c\u5730\u5b58\u5728\u79cd\u5b50\u8d8510\u4e07\u7b5b\u9009\u5c31\u4f1a\u53d8\u5361\uff0c\u5c3d\u5feb\u5bfc\u51fa\u6709\u7528\u79cd\u5b50\u540e\u6e05\u7a7a\u79cd\u5b50\u5e93\u3002",
            exportTitle: "\u5bfc\u51fa\u79cd\u5b50", exportNone: "\u6ca1\u6709\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u7684\u79cd\u5b50\uff0c\u65e0\u6cd5\u5bfc\u51fa\u3002",
            exportDone: "\u5df2\u5c06 {count} \u9897\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u7684\u79cd\u5b50\u5bfc\u51fa\u5230\u6587\u4ef6\uff1a",
            exportNote: "\u6b64\u6587\u4ef6\u4f4d\u4e8e Documents\\Battle Brothers\\savegames \u6587\u4ef6\u5939\uff0c\u53ef\u590d\u5236\u7ed9\u5176\u4ed6\u73a9\u5bb6\uff1b\u5bf9\u65b9\u4f7f\u7528\u76f8\u540c\u6216\u66f4\u65b0\u7248\u672c\u7684 mod \u5373\u53ef\u5bfc\u5165\u3002",
            exportFailed: "\u5bfc\u51fa\u5931\u8d25\uff1a",
            exportModePick: "\u8bf7\u9009\u62e9\u5bfc\u51fa\u65b9\u5f0f\uff1a", exportModeNew: "\u521b\u5efa\u65b0\u5b58\u6863\u6587\u4ef6", exportModeOverwrite: "\u8986\u76d6\u5df2\u6709\u5b58\u6863",
            exportNewHint: "\u5c06\u65b0\u5efa\u6587\u4ef6 BBSeedToolExport#<\u65f6\u95f4\u6233>.sav\uff08\u63a8\u8350\uff0c\u4e92\u4e0d\u8986\u76d6\uff09\u3002",
            exportPickOverwrite: "\u9009\u62e9\u8981\u88ab\u8986\u76d6\u7684\u5bfc\u51fa\u6587\u4ef6\uff08\u5176\u5185\u5bb9\u5c06\u88ab\u5b8c\u5168\u66ff\u6362\uff09\uff1a",
            exportNoFiles: "\u8fd8\u6ca1\u6709\u53ef\u8986\u76d6\u7684\u5bfc\u51fa\u6587\u4ef6\u3002",
            exportWillExport: "\u5c06\u5bfc\u51fa {count} \u9897\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u7684\u79cd\u5b50\u3002", exportConfirm: "\u5bfc\u51fa",
            importTitle: "\u5bfc\u5165\u79cd\u5b50",
            importNone: "\u672a\u627e\u5230\u53ef\u5bfc\u5165\u7684\u79cd\u5b50\u6587\u4ef6\u3002\u8bf7\u5148\u628a\u5bfc\u51fa\u7684 .sav \u6587\u4ef6\u653e\u5165 Documents\\Battle Brothers\\savegames \u6587\u4ef6\u5939\uff0c\u7136\u540e\u91cd\u65b0\u70b9\u51fb\u300c\u5bfc\u5165\u79cd\u5b50\u300d\u3002",
            importPick: "\u5728 savegames \u6587\u4ef6\u5939\u4e2d\u627e\u5230 {count} \u4e2a\u79cd\u5b50\u6587\u4ef6\uff0c\u8bf7\u9009\u62e9\u8981\u5bfc\u5165\u7684\u4e00\u4e2a\uff1a",
            importOne: "\u5728 savegames \u6587\u4ef6\u5939\u4e2d\u627e\u5230\u79cd\u5b50\u6587\u4ef6\uff1a",
            importRule: "\u5bfc\u5165\u540e\u5c06\u4f5c\u4e3a\u6700\u65b0\u6279\u6b21\uff08\u6279\u6b21 {batch}\uff09\u4fdd\u5b58\uff0c\u5e76\u5168\u90e8\u6807\u8bb0\u4e3a\u300c\u662f\u300d\uff1b\u5e93\u4e2d\u5df2\u5b58\u5728\u7684\u79cd\u5b50\u4f1a\u81ea\u52a8\u8df3\u8fc7\u3002",
            importConfirm: "\u5bfc\u5165", importBad: "\u6587\u4ef6\u635f\u574f\u6216\u683c\u5f0f\u4e0d\u517c\u5bb9\uff0c\u65e0\u6cd5\u5bfc\u5165\u3002",
            importDone: "\u5df2\u5bfc\u5165 {count} \u9897\u79cd\u5b50\uff0c\u6279\u6b21\u53f7 {batch}\uff0c\u5168\u90e8\u6807\u8bb0\u4e3a\u300c\u662f\u300d\u3002",
            importSkipped: "\u8df3\u8fc7\u4e86 {count} \u9897\u5e93\u4e2d\u5df2\u5b58\u5728\u7684\u79cd\u5b50\u3002",
            importFailed: "\u5bfc\u5165\u5931\u8d25\uff1a", seedCount: "\u542b {count} \u9897\u79cd\u5b50",
            nonegHint: "\u7ec6\u8282\u76f8\u5173\u6761\u4ef6\u4e2d\uff0c\u82e5\u9009\u4e2d\u4e86\u201c\u65e0\u8d1f\u9762\u201d\uff0c\u672a\u9009\u4e2d\u5176\u4ed6\u4efb\u4f55\u6761\u4ef6\uff1b\u201c\u65e0\u8d1f\u9762\u201d\u7b5b\u9009\u5c06\u751f\u6548\u4e8e\u201c\u6700\u9ad8\u5206\u201d\u6240\u5c5e\u7684\u89d2\u8272\u3002",
            origins: {"scenario.pale_sovereign":"\u4ea1\u7075\u4e3b\u5bb0","scenario.early_access":"\u65b0\u6210\u7acb\u7684\u4f63\u5175\u56e2","scenario.southern_quickstart":"\u5357\u65b9\u4f63\u5175","scenario.trader":"\u5546\u961f","scenario.militia":"\u519c\u6c11\u6c11\u5175","scenario.rangers":"\u5077\u730e\u8005\u56e2\u961f","scenario.paladins":"\u5ba3\u8a93\u8005","scenario.deserters":"\u9003\u5175","scenario.raiders":"\u5317\u65b9\u63a0\u593a\u8005","scenario.anatomists":"\u89e3\u5256\u5b66\u5bb6","scenario.cultists":"\u8fbe\u5e93\u5c14\u5f02\u6559\u5f92","scenario.manhunters":"\u730e\u5974\u8005","scenario.beast_hunters":"\u91ce\u517d\u6740\u624b","scenario.gladiators":"\u89d2\u6597\u58eb","scenario.lone_wolf":"\u72ec\u72fc"}
        },
        en: {
            launcher: "Seed Tool", title: "BB Seed Filter", loading: "Loading database...", stop: "Stop safely", close: "Close", count: "Seeds per collection", apply: "Apply count", startCollection: "Create seeds",
            instructions: "Set the count, mode and origin from top to bottom, then click <b>Create seeds</b>. Every result is saved permanently.",
            origin: "Origin", anyOrigin: "All origins", ports: "Port count", anyPorts: "Any", atLeastPorts: "\u2265{count}", portNature: "Port type", northLine: "North port line", anyPortNature: "Any", southNorthPort: "North + South", arenaPort: "Arena port", yes: "Yes", no: "No", unknown: "No data", topPercent: "Top {percent}%", slot: "Brother", anyBrother: "Any brother", allBrothers: "All brothers", brotherNumber: "Brother {index}", mapFilter: "Database scope", attributeFilter: "Attribute minimums", groupGenerate: "Generate", groupLibrary: "Library", groupTalent: "Brother quality (per brother)", groupMap: "Map & marks", originScopeHint: "Both the collection origin and the filter for the results below.",
            msk: "Melee attack", mdf: "Melee defense", rsk: "Ranged attack", rdf: "Ranged defense", hp: "Hitpoints", fat: "Fatigue", res: "Resolve", init: "Initiative",
            required: "Include trait", banned: "Exclude trait", anyTrait: "Any", quickTraitFilter: "Include trait", quickTraitDrunkard: "Drunkard", quickTraitHuge: "Huge", quickTraitSteady: "Sure Footed", quickTraitParanoid: "Paranoid", traitMaxHint: "Select up to 2 traits; click to toggle.", clear: "Clear", search: "Search", reset: "Reset filters", previous: "Previous", next: "Next", initial: "Loading database...", searching: "Searching persistent database...", scanning: "Scanning {total} seeds...",
            status: "{total} seeds in {batches} committed batches", countSet: "Collection count set to {count}", matched: "Matched {matched} of {total}. Showing {start}-{end}.", seed: "Seed", port: "Ports", settlements: "Settlements", brothers: "Brothers", traits: "Traits", none: "none", useSeed: "Use this seed", talent: "Talent", talentAll: "All", talentTop50: "Top 50%", talentTop20: "Top 20%", talentTop5: "Top 5%", talentAverage: "Talent avg.", talentPercentile: "Origin rank", brotherTalent: "Talent", projectedMelee: "Expected Lv11 MATK", talentScaleTitle: "Talent score reference", talentScaleAttack: "Expected Lv11 MATK", talentScaleScore: "Talent score",
            detail: "Stars", starMsk3: "MATK 3\u2605", starMsk2: "MATK 2\u2605", starMdf3: "MDEF 3\u2605", starMdf2: "MDEF 2\u2605", starFtg3: "FAT 3\u2605", starFtg2: "FAT 2\u2605", starIni3: "INIT 3\u2605", starIni2: "INIT 2\u2605", starRsk2: "RATK 2\u2605", noNegative: "No negative", starLabelVert: "S<br>T<br>A<br>R<br>S", nonegVert: "N<br>O<br>N<br>E<br>G", maxScore: "Best score", batch: "Batch", mark: "Mark", markFilter: "Marked", markYes: "Yes", markNo: "No", southLine: "South port line", southDesert: "Desert states", southRowHint: "Legacy seeds need a backfill after switching", southSwitchTitle: "Switch south port line", southSwitchDesc: "{count} legacy seeds in the library lack south-line data (20% / 35% / 50%).", southSwitchNote: "Without a backfill they count as having no south port on the new line. Backfilling maps applies the new line right away; you may stop safely at any time and the remainder is offered again on the next switch.", southSwitchCancel: "Cancel, keep Desert states", southSwitchGo: "Backfill {count} now",
            runElapsedLabel: "Elapsed: ", lastRateLabel: "Last batch: ", lastElapsedLabel: "Last batch time: ", hourUnitShort: "h ", runRateLabel: "Avg: ", runRate: "{rate} seeds/sec", runRatePending: "measuring...", etaRunLabel: "ETA: ", hourUnit: "h ", minuteUnit: "m ", secondUnit: "s",
            confirmTitle: "Create seeds", confirmWarning: "The game may appear frozen during collection. Do not click or press keys; large batches can take time, so please wait patiently.", confirmSummary: "Origin: {origin}   Seeds: {total}", confirmStart: "Start now", confirmCancel: "Cancel", chooseOriginTitle: "Choose an origin", chooseOriginFirst: "Choose one concrete origin before starting; All origins cannot be collected as one batch.", noticeOK: "OK", runningTitle: "Collecting seeds", runSaved: "Saved total: {saved}",
            starting: "Starting {total} seeds...", progress: "Progress {done}/{total} - committed total {saved}", stopping: "Stopping after the current seed and committing data...", finished: "Finished: {done} generated - {saved} saved total", stopped: "Stopped safely: {done} generated - {saved} saved total", error: "ERROR: {error}",
            modeLabel: "Mode", modeFull: "With map", modeTalent: "Talent only",
            modeHintFull: "With map: full map + brothers, slower. The deserter origin requires this mode.", modeHintTalent: "Talent only: brothers only, dozens of times faster; no map data, backfillable later.",
            starRsk3: "RATK 3\u2605", detailHint: "Click: select / cancel", detailHintMax: "Up to 3 star conditions; a selected 3\u2605 overrides the 2\u2605 of the same stat.",
            backfillBar: "Backfill all maps ({count} without map data in results)", backfillRow: "Backfill", backfillTitle: "Backfill maps",
            backfillDesc: "Re-run full map generation for the {count} seeds without map data in the current results and fill in their map data (ports / north+south / arena port / north-port lines).",
            backfillEta: "Estimated time: about {eta} (based on the last measured batch speed of {rate}). Batch, talent data and your marks stay untouched.",
            backfillNoEta: "Batch, talent data and your marks stay untouched.",
            backfillMulti: "Results spanning several origins are processed one origin at a time automatically.", backfillStart: "Start backfill", backfillCancel: "Cancel",
            backfillRunningTitle: "Backfilling map data", backfillWarning: "Backfill regenerates the full map for the selected seeds and only fills in map data (ports / arena); brothers, batch and marks stay untouched. The game may appear frozen - do not click or press keys.", backfillSummary: "Origin: {origin}   Seeds: {total}", backfillProgress: "Backfilled {done} / {total}", backfillSaved: "Backfilled results saved: {saved}", backfillStop: "Cancel backfill",
            etaLabel: "ETA: ", etaPending: "estimating...", startRejected: "Collection did not start within 5 seconds. The state was reset - please retry; if it persists, send log.html to the author.",
            startSlow: "Entering the world is taking longer than usual - please wait, or cancel with the button below.", startCancelled: "Start cancelled.",
            backfillDoneTitle: "Backfill complete", backfillDoneText: "Map data backfilled for {done} seeds. ", backfillSkipped: "{count} seeds were no longer in the library and were skipped.", backfillStoppedTitle: "Backfill cancelled", backfillStoppedText: "{done} seeds were backfilled and kept; the rest stay unmapped and can be backfilled anytime. ",
            talentDesertersError: "Deserters brothers need the map to spawn, so talent-only mode is unavailable for this origin. Use \"With map\" instead.",
            cleanupBtn: "Talent-only cleanup",
            cleanupHint: "Deletes every talent-only seed (no map data) that is not marked Yes. Mapped seeds and marked seeds are never touched. A confirmation and a countdown run before anything is deleted.",
            cleanupAdvice: "Use Talent only to filter brothers, mark seeds to keep, clean up extras, then backfill map data.",
            cleanupTitle: "Talent-only cleanup", cleanupNone: "There are no talent-only seeds to clean up.",
            cleanupDesc: "This will delete {count} talent-only seeds (no map data) that are not marked Yes.",
            cleanupWarn: "Warning: {high} of them have a best score of 90 or more ({examples}) and will be deleted as well. Continue?",
            cleanupYes: "Yes, delete", cleanupNo: "No, cancel", cleanupCancel: "Cancel",
            cleanupCountdown: "Deleting in {sec} seconds:", cleanupDone: "Cleanup finished: {count} talent-only seeds deleted.",
            wipe: "Clear library (avoid filter lag)", wipeTitle: "Clear Seed Library", wipeNone: "There are no saved seeds.",
            wipeDesc: "This will delete ALL {count} saved seeds (including seeds marked Yes). The library will be empty and this cannot be undone.",
            wipeCountdown: "Deleting in {sec} seconds. Click the button below to keep your seeds.",
            wipeCancel: "Cancel (keep seeds)", wipeDone: "Deleted {count} seeds. The library is now empty.",
            wipeFailed: "Wipe failed: ",
            exportSeeds: "Export seeds", importSeeds: "Import seeds",
            transferHint: "Export packs every seed marked Yes into one file. Over 100k local seeds slows filtering - export the keepers, then clear the library.",
            exportTitle: "Export seeds", exportNone: "No seeds are marked Yes; nothing to export.",
            exportDone: "Exported {count} marked seeds to file:",
            exportNote: "The file is in Documents\\Battle Brothers\\savegames and can be copied to other players; they need the same or a newer mod version to import it.",
            exportFailed: "Export failed: ",
            exportModePick: "Choose how to export:", exportModeNew: "Create a new file", exportModeOverwrite: "Overwrite existing file",
            exportNewHint: "Creates BBSeedToolExport#<timestamp>.sav (recommended; nothing is overwritten).",
            exportPickOverwrite: "Pick the export file to overwrite (its content will be fully replaced):",
            exportNoFiles: "No existing export file to overwrite yet.",
            exportWillExport: "Will export {count} seeds marked Yes.", exportConfirm: "Export",
            importTitle: "Import seeds",
            importNone: "No importable seed file found. Put an exported .sav file into Documents\\Battle Brothers\\savegames first, then click Import seeds again.",
            importPick: "Found {count} seed files in savegames. Pick one to import:",
            importOne: "Found a seed file in savegames:",
            importRule: "Imported seeds are stored as the newest batch (batch {batch}) and all marked Yes; seeds already in the library are skipped.",
            importConfirm: "Import", importBad: "The file is corrupt or incompatible; import aborted.",
            importDone: "Imported {count} seeds as batch {batch}, all marked Yes.",
            importSkipped: "Skipped {count} seeds already in the library.",
            importFailed: "Import failed: ", seedCount: "{count} seeds",
            nonegHint: "With only the No-negative switch active in the detail conditions, the filter applies to the top-scoring brother.",
            origins: {"scenario.pale_sovereign":"The Pale Sovereign","scenario.early_access":"A New Company","scenario.southern_quickstart":"Southern Mercenaries","scenario.trader":"Trading Caravan","scenario.militia":"Peasant Militia","scenario.rangers":"Band of Poachers","scenario.paladins":"Oathtakers","scenario.deserters":"Deserters","scenario.raiders":"Northern Raiders","scenario.anatomists":"Anatomists","scenario.cultists":"Davkul Cultists","scenario.manhunters":"Manhunters","scenario.beast_hunters":"Beast Slayers","scenario.gladiators":"Gladiators","scenario.lone_wolf":"Lone Wolf"}
        }
    };

    var chineseTraits = {
        ailing:"\u4f53\u5f31\u591a\u75c5", asthmatic:"\u6c14\u5598", athletic:"\u8fd0\u52a8\u5065\u5c06", bleeder:"\u6613\u6d41\u8840", bloodthirsty:"\u55dc\u8840", brave:"\u52c7\u6562", bright:"\u806a\u660e", brute:"\u91ce\u86ee", clubfooted:"\u7578\u8db3", clumsy:"\u7b28\u62d9", cocky:"\u81ea\u8d1f", craven:"\u61e6\u5f31", dastard:"\u602f\u61e6", deathwish:"\u6c42\u6b7b", determined:"\u575a\u5b9a", dexterous:"\u7075\u5de7", disloyal:"\u4e0d\u5fe0", drunkard:"\u9152\u9b3c", dumb:"\u611a\u7b28", eagle_eyes:"\u9e70\u773c", fainthearted:"\u80c6\u602f", fat:"\u80a5\u80d6", fearless:"\u65e0\u754f", fragile:"\u8106\u5f31", gluttonous:"\u8d2a\u5403", greedy:"\u8d2a\u5a6a", hesitant:"\u72b9\u8c6b", huge:"\u5de8\u5927", impatient:"\u6025\u8e81", insecure:"\u7f3a\u4e4f\u81ea\u4fe1", iron_jaw:"\u94c1\u4e0b\u5df4", iron_lungs:"\u94c1\u80ba", irrational:"\u53cd\u590d\u65e0\u5e38", loyal:"\u5fe0\u8bda", lucky:"\u5e78\u8fd0", mad:"\u75af\u72c2", night_blind:"\u591c\u76f2", night_owl:"\u591c\u732b\u5b50", optimist:"\u4e50\u89c2", paranoid:"\u591a\u7591", pessimist:"\u60b2\u89c2", quick:"\u8fc5\u6377", short_sighted:"\u8fd1\u89c6", spartan:"\u65af\u5df4\u8fbe", strong:"\u5f3a\u58ee", superstitious:"\u8ff7\u4fe1", sure_footing:"\u811a\u6b65\u7a33\u5065", survivor:"\u751f\u8fd8\u8005", swift:"\u8fc5\u6377", teamplayer:"\u56e2\u961f\u7cbe\u795e", tiny:"\u77ee\u5c0f", tough:"\u575a\u97e7", weasel:"\u72e1\u733e", fear_beasts:"\u6050\u60e7\u91ce\u517d", fear_greenskins:"\u6050\u60e7\u7eff\u76ae", fear_undead:"\u6050\u60e7\u4ea1\u7075", hate_beasts:"\u4ec7\u6068\u91ce\u517d", hate_greenskins:"\u4ec7\u6068\u7eff\u76ae", hate_undead:"\u4ec7\u6068\u4ea1\u7075"
    };

    function tr(key, values) {
        var value = text[currentLanguage][key];
        values = values || {};
        Object.keys(values).forEach(function (name) { value = value.split("{" + name + "}").join(values[name]); });
        return value;
    }

    function backend(method, data, callback) {
        try {
            var module = Screens.MainMenuScreen.getModule("MainMenuModule");
            SQ.call(module.mSQHandle, method, data || null, callback || function () {});
        } catch (e) {
            setTimeout(function () { backend(method, data, callback); }, 500);
        }
    }

    function esc(value) {
        return String(value == null ? "" : value).replace(/[&<>"']/g, function (c) {
            return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
        });
    }

    function applyPendingCampaign(module) {
        if (!pendingCampaign || !module) return null;
        var request = pendingCampaign;
        pendingCampaign = null;
        if (request.mode !== "collect" && module.mSeed) module.mSeed.setInputText(request.seed || "");
        var scenarios = module.mScenarios || [];
        for (var i = 0; i < scenarios.length; ++i) {
            if (scenarios[i].ID !== request.origin) continue;
            module.mSelectedScenario = i;
            try { module.mScenariosRow.find("#cb-scenario-" + i).iCheck("check"); } catch (e) {}
            if (module.updateStartingScenarioDescription) module.updateStartingScenarioDescription(scenarios[i].Description, scenarios[i].Difficulty);
            break;
        }
        return request;
    }

    function armStartWatchdog() {
        startInFlight = true;
        hideSlowHint();
        // v1.54: if no bbseedCollectionStarted arrives within 5s of arming,
        // the run silently died between the click and BBSeedTool_Run - log it,
        // disarm the backend and surface an error instead of hanging forever.
        collectionStartedFlag = false;
        if (collectionWatchdog) { clearTimeout(collectionWatchdog); collectionWatchdog = null; }
        collectionWatchdog = setTimeout(function () {
            collectionWatchdog = null;
            if (collectionStartedFlag) return;
            // v1.55: report only - NEVER disarm here. A slow world entry is
            // legitimate; v1.54 auto-disarmed mid-entry, the arriving
            // startNewCampaign then ran as a REAL campaign and a second
            // start click hard-crashed the game on the half-built world.
            try { backend("bbseedLog", {message:"watchdog: world entry still running after 30s"}); } catch (e) {}
            showSlowHint();
        }, 30000);
    }

    function clearStartWatchdog() {
        collectionStartedFlag = true;
        startInFlight = false;
        if (collectionWatchdog) { clearTimeout(collectionWatchdog); collectionWatchdog = null; }
        hideSlowHint();
    }

    function showSlowHint() {
        var hint = document.getElementById("bbseed-slow-hint");
        if (!hint) return;
        hint.textContent = tr("startSlow");
        hint.classList.remove("bbseed-hidden");
    }

    function hideSlowHint() {
        var hint = document.getElementById("bbseed-slow-hint");
        if (hint) hint.classList.add("bbseed-hidden");
    }

    function installCampaignSeedHook() {
        if (campaignSeedHookInstalled || typeof NewCampaignMenuModule === "undefined") return;
        var originalShow = NewCampaignMenuModule.prototype.show;
        NewCampaignMenuModule.prototype.show = function () {
            var result = originalShow.apply(this, arguments);
            var request = null;
            try { request = applyPendingCampaign(this); }
            catch (e) {
                // v1.53: a prefill failure must never block the menu itself.
                try { backend("bbseedLog", {message: "applyPendingCampaign: " + e}); } catch (e2) {}
            }
            if (request && request.mode === "collect") {
                var module = this;
                setTimeout(function () {
                    try { module.notifyBackendStartButtonPressed(); }
                    catch (e) {
                        clearStartWatchdog();
                        try { backend("bbseedLog", {message:"startButtonPressed failed: " + e}); } catch (e2) {}
                        backend("bbseedDisarmCollection", {});
                        showCollectionFailure(String(e));
                    }
                }, 120);
            }
            return result;
        };
        campaignSeedHookInstalled = true;
    }

    function isSeedToolStorage(campaign) {
        if (!campaign) return false;
        var fileNameKey = "fileName";
        try {
            if (typeof CampaignMenuModulesIdentifier !== "undefined" && CampaignMenuModulesIdentifier.Campaign) {
                fileNameKey = CampaignMenuModulesIdentifier.Campaign.FileName || fileNameKey;
            }
        } catch (e) {}
        var fileName = campaign[fileNameKey];
        return typeof fileName === "string" && fileName.toLowerCase().indexOf("bbseedtool") === 0;
    }

    function visibleCampaigns(campaigns) {
        if (campaigns === null || typeof campaigns === "undefined" || !jQuery.isArray(campaigns)) return campaigns;
        var visible = [];
        for (var i = 0; i < campaigns.length; ++i) {
            if (!isSeedToolStorage(campaigns[i])) visible.push(campaigns[i]);
        }
        return visible;
    }

    function installStorageVisibilityHooks() {
        if (!loadMenuFilterInstalled && typeof LoadCampaignMenuModule !== "undefined" && LoadCampaignMenuModule.prototype.addCampaignsToList) {
            var originalLoadList = LoadCampaignMenuModule.prototype.addCampaignsToList;
            LoadCampaignMenuModule.prototype.addCampaignsToList = function (campaigns) {
                return originalLoadList.call(this, visibleCampaigns(campaigns));
            };
            loadMenuFilterInstalled = true;
        }
        if (!saveMenuFilterInstalled && typeof SaveCampaignMenuModule !== "undefined" && SaveCampaignMenuModule.prototype.addCampaignsToList) {
            var originalSaveList = SaveCampaignMenuModule.prototype.addCampaignsToList;
            SaveCampaignMenuModule.prototype.addCampaignsToList = function (campaigns) {
                return originalSaveList.call(this, visibleCampaigns(campaigns));
            };
            saveMenuFilterInstalled = true;
        }
    }

    function useSeed(button) {
        pendingCampaign = {mode:"play", seed:button.getAttribute("data-seed") || "", origin:button.getAttribute("data-origin") || ""};
        installCampaignSeedHook();
        document.getElementById("bbseed-overlay").classList.add("bbseed-hidden");
        openNewCampaignMenu();
    }

    function openNewCampaignMenu(attempt) {
        // v1.53: right after a collection run the game is still disposing
        // the throwaway world and rebuilding the main menu, so the first
        // call can hit a not-yet-ready MainMenuModule and die (the user saw
        // "first click errors, works after restart"). Retry like backend()
        // does, and log persistent failures into log.html via bbseedLog.
        attempt = attempt || 0;
        try {
            var mainMenu = Screens.MainMenuScreen.getModule("MainMenuModule");
            if (mainMenu && mainMenu.notifyBackendNewCampaignButtonPressed) { mainMenu.notifyBackendNewCampaignButtonPressed(); return; }
            if (Screens.MainMenuScreen.showNewCampaignMenu) { Screens.MainMenuScreen.showNewCampaignMenu(); return; }
            throw new Error("MainMenuModule not ready");
        } catch (e) {
            if (attempt < 10) {
                setTimeout(function () { openNewCampaignMenu(attempt + 1); }, 400);
                return;
            }
            try { backend("bbseedLog", {message: "openNewCampaignMenu failed after retries: " + e}); } catch (e2) {}
            var overlay = document.getElementById("bbseed-overlay");
            if (overlay) overlay.classList.remove("bbseed-hidden");
            showCollectionFailure("Cannot open the new campaign menu: " + e);
        }
    }

    function star(n) { return Number(n) ? " <span class='stars'>" + new Array(Number(n) + 1).join("&#9733;") + "</span>" : ""; }
    function setText(id, value) { var element = document.getElementById(id); if (element) element.textContent = value; }

    function renderTalentScale() {
        var attacks = ["\u226476", "80", "85", "90", "\u226595"];
        var scores = ["0", "60", "80", "95", "100"];
        function cells(values) { return values.map(function (value) { return "<td>" + value + "</td>"; }).join(""); }
        return "<div class='talent-scale-title'>" + esc(tr("talentScaleTitle")) + "</div><table><tbody>" +
            "<tr><th>" + esc(tr("talentScaleAttack")) + "</th>" + cells(attacks) + "</tr>" +
            "<tr><th>" + esc(tr("talentScaleScore")) + "</th>" + cells(scores) + "</tr>" +
            "</tbody></table>";
    }

    function portPercentage(count, total) {
        if (!total) return "--";
        return (Math.round(count * 1000 / total) / 10).toFixed(1);
    }

    function rebuildPortFilters() {
        var target = document.getElementById("bbseed-port-buttons");
        if (!target) return;
        var stats = lastStatus && lastStatus.portStats ? lastStatus.portStats : {total:0,gte3:0,gte4:0,gte5:0,gte6:0,known:0,southNorth:0,arena:0};
        var choices = [
            {value:0,label:tr("anyPorts"),count:stats.total},
            {value:3,label:tr("atLeastPorts",{count:3}),count:stats.gte3},
            {value:4,label:tr("atLeastPorts",{count:4}),count:stats.gte4},
            {value:5,label:tr("atLeastPorts",{count:5}),count:stats.gte5},
            {value:6,label:tr("atLeastPorts",{count:6}),count:stats.gte6}
        ];
        target.innerHTML = choices.map(function (choice) {
            var percentage = stats.total ? tr("topPercent", {percent:portPercentage(choice.count, stats.total)}) : "--";
            return "<button type='button' class='port-choice" + (choice.value === portMinimum ? " selected" : "") + "' data-ports='" + choice.value + "'><span class='port-threshold'>" + choice.label + "</span><span class='port-percent'>" + percentage + "</span></button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".port-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                portMinimum = parseInt(button.getAttribute("data-ports"), 10) || 0;
                rebuildPortFilters();
                search();
            };
        });
    }

    function rebuildPortNatureFilters() {
        var target = document.getElementById("bbseed-port-nature-buttons");
        if (!target) return;
        var stats = lastStatus && lastStatus.portStats ? lastStatus.portStats : {total:0,known:0,sn50:0,sn65:0,sn80:0,arena:0};
        var southNorthCount = stats["sn" + northLine] || 0;
        var choices = [
            {value:"any",label:tr("anyPortNature"),selected:!requireSouthNorthPort && !requireArenaPort,count:stats.total,total:stats.total},
            {value:"southNorth",label:tr("southNorthPort"),selected:requireSouthNorthPort,count:southNorthCount,total:stats.known},
            {value:"arena",label:tr("arenaPort"),selected:requireArenaPort,count:stats.arena,total:stats.known}
        ];
        target.innerHTML = choices.map(function (choice) {
            var percentage = choice.total ? tr("topPercent", {percent:portPercentage(choice.count, choice.total)}) : "--";
            return "<button type='button' class='port-nature-choice" + (choice.selected ? " selected" : "") + "' data-port-nature='" + choice.value + "'><span class='port-nature-name'>" + esc(choice.label) + "</span><span class='port-nature-percent'>" + percentage + "</span></button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".port-nature-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                var value = button.getAttribute("data-port-nature") || "any";
                if (value === "any") {
                    requireSouthNorthPort = false;
                    requireArenaPort = false;
                } else if (value === "southNorth") requireSouthNorthPort = !requireSouthNorthPort;
                else if (value === "arena") requireArenaPort = !requireArenaPort;
                rebuildPortNatureFilters();
                search();
            };
        });
    }

    function northLineBit() { return northLine <= 50 ? 16 : (northLine <= 65 ? 32 : 64); }

    function rebuildPortLatFilters() {
        var target = document.getElementById("bbseed-port-lat-buttons");
        if (!target) return;
        target.innerHTML = [50, 65, 80].map(function (line) {
            return "<button type='button' class='port-lat-choice" + (northLine === line ? " selected" : "") + "' data-lat='" + line + "'>" + line + "%</button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".port-lat-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                northLine = parseInt(button.getAttribute("data-lat"), 10) || 80;
                rebuildPortLatFilters();
                rebuildPortNatureFilters();
                search(false);
            };
        });
    }

    // v1.78: south port line. 0 = desert states (legacy behaviour);
    // 20/35/50 = "some port below that share of the map height".
    function southLineBit() { return southLine === 20 ? 256 : (southLine === 35 ? 512 : (southLine === 50 ? 1024 : 4)); }

    function rebuildSouthLatFilters() {
        var target = document.getElementById("bbseed-south-lat-buttons");
        if (!target) return;
        var choices = [{value:0,label:tr("southDesert")},{value:20,label:"20%"},{value:35,label:"35%"},{value:50,label:"50%"}];
        target.innerHTML = choices.map(function (choice) {
            return "<button type='button' class='south-lat-choice" + (choice.value === 0 ? " south-desert" : "") + (southLine === choice.value ? " selected" : "") + "' data-slat='" + choice.value + "'>" + esc(choice.label) + "</button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".south-lat-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                requestSouthLine(parseInt(button.getAttribute("data-slat"), 10) || 0);
            };
        });
    }

    function requestSouthLine(value) {
        if (value === southLine) return;
        if (value === 0) { southLine = 0; rebuildSouthLatFilters(); rebuildPortNatureFilters(); search(false); return; }
        backend("bbseedLegacySouth", null, function (res) {
            var count = res && res.count ? parseInt(res.count, 10) : 0;
            if (!(count > 0)) { southLine = value; rebuildSouthLatFilters(); rebuildPortNatureFilters(); search(false); return; }
            showSouthSwitchDialog(value, count, res.groups || []);
        });
    }

    function showSouthSwitchDialog(value, count, groups) {
        showDialog("<h2>" + esc(tr("southSwitchTitle")) + "</h2>" +
            "<p>" + esc(tr("southSwitchDesc", {count:count})) + "</p>" +
            "<p>" + esc(tr("southSwitchNote")) + "</p>" +
            "<div class='dialog-actions'>" +
            "<button type='button' id='bbseed-south-switch-cancel'>" + esc(tr("southSwitchCancel")) + "</button>" +
            "<button type='button' id='bbseed-south-switch-go' class='dialog-primary'>" + esc(tr("southSwitchGo", {count:count})) + "</button>" +
            "</div>");
        document.getElementById("bbseed-south-switch-cancel").onclick = function () { hideDialog(); };
        document.getElementById("bbseed-south-switch-go").onclick = function () {
            hideDialog();
            pendingSouthLine = value;
            startBackfillQueue(groups);
        };
    }

    function rebuildTalentFilters() {
        var target = document.getElementById("bbseed-talent-buttons");
        if (!target) return;
        var choices = [
            {value:10000,label:tr("talentAll")},
            {value:5000,label:tr("talentTop50")},
            {value:2000,label:tr("talentTop20")},
            {value:500,label:tr("talentTop5")}
        ];
        target.innerHTML = choices.map(function (choice) {
            return "<button type='button' class='talent-choice" + (choice.value === talentTop100 ? " selected" : "") + "' data-talent-top='" + choice.value + "'>" + choice.label + "</button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".talent-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                talentTop100 = parseInt(button.getAttribute("data-talent-top"), 10) || 10000;
                rebuildTalentFilters();
                search();
            };
        });
    }

    var quickTraitDefs = [
        {labelKey:"quickTraitDrunkard", names:["\u9152\u9b3c","drunkard"], fallback:"drunkard"},
        {labelKey:"quickTraitHuge", names:["\u5de8\u5927","huge"], fallback:"huge"},
        {labelKey:"quickTraitSteady", names:["\u7a33\u6b65","\u811a\u6b65\u7a33\u5065","sure footing","sure footed"], fallback:"sure_footing"},
        {labelKey:"quickTraitParanoid", names:["\u504f\u6267","\u591a\u7591","paranoid"], fallback:"paranoid"}
    ];

    function resolveQuickTraitId(def) {
        for (var i = 0; i < traitOptions.length; i++) {
            var nm = (traitOptions[i].name || "").toLowerCase();
            for (var j = 0; j < def.names.length; j++)
                if (nm === def.names[j]) return traitOptions[i].id;
        }
        return def.fallback;
    }

    function rebuildQuickTraitFilters() {
        var target = document.getElementById("bbseed-quick-trait-buttons");
        if (!target) return;
        var html = "<button type='button' class='quick-trait-choice trait-any" + (quickTraits.length === 0 ? " selected" : "") + "' data-quick-trait=''>" + esc(tr("anyTrait")) + "</button>";
        html += "<div class='trait-grid'>";
        for (var i = 0; i < quickTraitDefs.length; i++) {
            var id = resolveQuickTraitId(quickTraitDefs[i]);
            html += "<button type='button' class='quick-trait-choice" + (quickTraits.indexOf(id) >= 0 ? " selected" : "") + "' data-quick-trait='" + id + "'>" + esc(tr(quickTraitDefs[i].labelKey)) + "</button>";
        }
        html += "</div><span class='quick-trait-hint'>" + esc(tr("traitMaxHint")) + "</span>";
        target.innerHTML = html;
        Array.prototype.forEach.call(target.querySelectorAll(".quick-trait-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                var id = button.getAttribute("data-quick-trait") || "";
                if (id === "") {
                    quickTraits = [];
                } else {
                    var idx = quickTraits.indexOf(id);
                    if (idx >= 0) quickTraits.splice(idx, 1);
                    else if (quickTraits.length < 2) quickTraits.push(id);
                }
                rebuildQuickTraitFilters();
                search();
            };
        });
    }

    var starPairs = [
        {base:"smsk", label3:"starMsk3", label2:"starMsk2"},
        {base:"smdf", label3:"starMdf3", label2:"starMdf2"},
        {base:"sftg", label3:"starFtg3", label2:"starFtg2"},
        {base:"sini", label3:"starIni3", label2:"starIni2"},
        {base:"srsk", label3:"starRsk3", label2:"starRsk2"}
    ];

    function detailStarCount() {
        var n = 0;
        for (var i = 0; i < starPairs.length; i++) {
            if (detailStars[starPairs[i].base + "3"]) n++;
            if (detailStars[starPairs[i].base + "2"]) n++;
        }
        return n;
    }

    // v1.73: star module. Vertical no-negative switch + 2 rows (3-star top,
    // 2-star bottom) x 5 columns (MATK/MDEF/FAT/INIT/RATK). At most 3 star
    // conditions at once; a selected 3-star dims and disables the same
    // stat's 2-star (3-star overrides it anyway).
    function rebuildDetailFilters() {
        var target = document.getElementById("bbseed-detail-buttons");
        if (!target) return;
        var count = detailStarCount();
        var html = "<button type='button' class='detail-choice noneg-choice noneg-vert" + (detailStars.noNegative ? " selected" : "") + "' data-detail-star='noNegative'>" + tr("nonegVert") + "</button>";
        for (var row = 3; row >= 2; row--) {
            for (var i = 0; i < starPairs.length; i++) {
                var key = starPairs[i].base + row;
                var on = !!detailStars[key];
                var dim = false;
                if (row === 2 && detailStars[starPairs[i].base + "3"]) dim = true;
                if (!on && count >= 3) dim = true;
                html += "<button type='button' class='detail-choice" + (on ? " selected" : "") + (dim ? " dim" : "") + "' data-detail-star='" + key + "'>" + esc(tr(starPairs[i]["label" + row])) + "</button>";
            }
        }
        target.innerHTML = html;
        Array.prototype.forEach.call(target.querySelectorAll(".detail-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                var key = button.getAttribute("data-detail-star");
                if (key === "noNegative") {
                    detailStars.noNegative = !detailStars.noNegative;
                } else if (detailStars[key]) {
                    detailStars[key] = false;
                } else {
                    if (detailStarCount() >= 3) return;
                    var base = key.slice(0, 4);
                    if (key.charAt(4) === "2" && detailStars[base + "3"]) return;
                    detailStars[key] = true;
                    if (key.charAt(4) === "3") detailStars[base + "2"] = false;
                }
                rebuildDetailFilters();
                search();
            };
        });
    }

    function rebuildMarkFilter() {
        var target = document.getElementById("bbseed-mark-buttons");
        if (!target) return;
        var choices = [
            {value:"all", label:tr("talentAll")},
            {value:"yes", label:tr("markYes")},
            {value:"no", label:tr("markNo")}
        ];
        target.innerHTML = choices.map(function (choice) {
            return "<button type='button' class='mark-choice" + (choice.value === markFilter ? " selected" : "") + "' data-mark-filter='" + choice.value + "'>" + esc(choice.label) + "</button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".mark-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                markFilter = button.getAttribute("data-mark-filter") || "all";
                rebuildMarkFilter();
                search();
            };
        });
    }

    function formatTalentAverage(value10) {
        value10 = parseInt(value10, 10) || 0;
        return value10 % 10 === 0 ? String(value10 / 10) : (value10 / 10).toFixed(1);
    }

    function formatTalentTop(value100) {
        value100 = Math.max(1, parseInt(value100, 10) || 10000);
        var value = value100 / 100;
        var digits = value < 1 ? 2 : (value < 10 ? 1 : 0);
        return tr("topPercent", {percent:value.toFixed(digits).replace(/\.0+$|(?:(\.\d*[1-9]))0+$/, "$1")});
    }

    function formatPortProperty(portFlags, property) {
        portFlags = parseInt(portFlags, 10) || 0;
        if ((portFlags & 1) === 0) return "<span class='port-property unknown'>" + esc(tr("unknown")) + "</span>";
        var present = property === "southNorth" ? ((portFlags & southLineBit()) !== 0 && (portFlags & northLineBit()) !== 0) : (portFlags & 8) !== 0;
        return "<span class='port-property " + (present ? "present" : "absent") + "'>" + esc(tr(present ? "yes" : "no")) + "</span>";
    }

    function rebuildOrigins() {
        var input = document.getElementById("bbseed-origin");
        var target = document.getElementById("bbseed-origin-buttons");
        if (!input || !target) return;
        var selected = input.value || "";
        var names = text[currentLanguage].origins;
        target.innerHTML = "<button type='button' class='origin-choice origin-all" + (selected === "" ? " selected" : "") + "' data-origin=''>" + esc(tr("anyOrigin")) + "</button><div class='origin-grid'>" + Object.keys(names).map(function (key) {
            return "<button type='button' class='origin-choice origin-one" + (selected === key ? " selected" : "") + "' data-origin='" + esc(key) + "'>" + esc(names[key]) + "</button>";
        }).join("") + "</div>";
        Array.prototype.forEach.call(target.querySelectorAll(".origin-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                input.value = button.getAttribute("data-origin") || "";
                pageOffset = 0;
                rebuildOrigins();
                search(false);
            };
        });
    }

    var originBrotherCounts = {
        "scenario.pale_sovereign": 3,
        "scenario.early_access": 3,
        "scenario.southern_quickstart": 3,
        "scenario.trader": 2,
        "scenario.militia": 12,
        "scenario.rangers": 3,
        "scenario.paladins": 2,
        "scenario.deserters": 3,
        "scenario.raiders": 4,
        "scenario.anatomists": 3,
        "scenario.cultists": 4,
        "scenario.manhunters": 6,
        "scenario.beast_hunters": 3,
        "scenario.gladiators": 3,
        "scenario.lone_wolf": 1
    };

    function rebuildBrotherTargets() {
        var menu = document.getElementById("bbseed-bro-menu");
        var origin = document.getElementById("bbseed-origin");
        if (!menu || !origin) return;
        var selected = brotherValue();
        var count = originBrotherCounts[origin.value] || 12;
        var selectedSlot = selected.indexOf("slot:") === 0 ? parseInt(selected.slice(5), 10) || 0 : 0;
        if (selectedSlot > count) selected = "any";
        var options = [{value:"any",label:tr("anyBrother")},{value:"all",label:tr("allBrothers")}];
        for (var i = 1; i <= count; i++) options.push({value:"slot:" + i,label:tr("brotherNumber", {index:i})});
        menu.innerHTML = options.map(function (option) {
            return "<button type='button' class='picker-option" + (option.value === selected ? " selected" : "") + "' data-value='" + option.value + "'>" + option.label + "</button>";
        }).join("");
        Array.prototype.forEach.call(menu.querySelectorAll(".picker-option"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                setBrotherValue(button.getAttribute("data-value"));
                menu.classList.add("bbseed-hidden");
                rebuildBrotherTargets();
            };
        });
        setBrotherValue(selected);
    }

    function traitLabel(option) {
        if (currentLanguage === "zh" && chineseTraits[option.id]) return chineseTraits[option.id];
        return option.name && option.name !== option.id ? option.name : option.id.replace(/_/g, " ");
    }

    function traitName(id) {
        if (!id) return tr("none");
        if (currentLanguage === "zh" && chineseTraits[id]) return chineseTraits[id];
        for (var i = 0; i < traitOptions.length; i++) if (traitOptions[i].id === id) return traitLabel(traitOptions[i]);
        return id.replace(/_/g, " ");
    }

    var primeTraits = {drunkard:true, huge:true, sure_footing:true, paranoid:true};
    var severeTraits = {tiny:true, asthmatic:true, dastard:true, insecure:true};
    var originTraits = {
        player:true, player_character:true, cultist_fanatic:true, arena_fighter:true,
        glorious_resolve:true, glorious_endurance:true, glorious_quickness:true, old:true
    };

    function isOriginTrait(id) {
        id = String(id || "").toLowerCase();
        return !!originTraits[id] || id.indexOf("oath_of_") === 0;
    }

    function traitClass(id) {
        id = String(id || "").toLowerCase();
        if (primeTraits[id]) return "trait-prime";
        if (severeTraits[id]) return "trait-severe";
        return "trait-ordinary";
    }

    function renderTraitTags(rawTraits) {
        var ids = (rawTraits ? rawTraits.split(",") : []).filter(function (id) { return id !== "" && !isOriginTrait(id); });
        if (!ids.length) return "<span class='traits-none'>" + esc(tr("none")) + "</span>";
        return ids.map(function (id) {
            return "<span class='trait-tag " + traitClass(id) + "'>" + esc(traitName(id)) + "</span>";
        }).join("");
    }

    function closePickerMenus(exceptId) {
        ["bbseed-bro","bbseed-required","bbseed-banned"].forEach(function (id) {
            if (id !== exceptId) document.getElementById(id + "-menu").classList.add("bbseed-hidden");
        });
    }

    function brotherValue() {
        return document.getElementById("bbseed-bro-value").value || "any";
    }

    function brotherLabel(value) {
        if (value === "all") return tr("allBrothers");
        if (value.indexOf("slot:") === 0) return tr("brotherNumber", {index:parseInt(value.slice(5), 10) || 1});
        return tr("anyBrother");
    }

    function setBrotherValue(value) {
        value = value || "any";
        document.getElementById("bbseed-bro-value").value = value;
        setText("bbseed-bro-label", brotherLabel(value));
    }

    function traitValue(id) {
        return document.getElementById(id + "-value").value;
    }

    function setTraitValue(id, value) {
        document.getElementById(id + "-value").value = value || "";
        setText(id + "-label", value ? traitName(value) : tr("anyTrait"));
    }

    function rebuildTraitPicker(id) {
        var menu = document.getElementById(id + "-menu");
        if (!menu) return;
        var selected = traitValue(id);
        menu.innerHTML = traitOptions.map(function (option) {
            return "<button type='button' class='trait-option" + (option.id === selected ? " selected" : "") + "' data-value='" + esc(option.id) + "'>" + esc(traitLabel(option)) + "</button>";
        }).join("");
        Array.prototype.forEach.call(menu.querySelectorAll(".trait-option"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                setTraitValue(id, button.getAttribute("data-value"));
                menu.classList.add("bbseed-hidden");
                rebuildTraitPicker(id);
            };
        });
        setTraitValue(id, selected);
    }

    function rebuildTraits() {
        rebuildTraitPicker("bbseed-required");
        rebuildTraitPicker("bbseed-banned");
    }

    function loadTraits() {
        backend("bbseedGetTraitOptions", null, function (options) {
            traitOptions = options || [];
            rebuildTraits();
        });
    }

    function makeInputsEditable() {
        var inputs = document.querySelectorAll("#bbseed-panel input");
        Array.prototype.forEach.call(inputs, function (input) {
            if (input.type === "hidden") return;
            input.onclick = function (event) { event.stopPropagation(); this.focus(); };
            input.onfocus = function () { this.select(); };
            input.onkeydown = input.onkeypress = input.onkeyup = function (event) { event.stopPropagation(); };
            if (input.className.indexOf("numeric-input") !== -1) {
                input.oninput = function () { this.value = this.value.replace(/[^0-9]/g, ""); };
                input.onblur = function () {
                    var min = parseInt(this.getAttribute("data-min"), 10);
                    var max = parseInt(this.getAttribute("data-max"), 10);
                    var numberValue = parseInt(this.value, 10);
                    if (isNaN(numberValue)) numberValue = isNaN(min) ? 0 : min;
                    if (!isNaN(min) && numberValue < min) numberValue = min;
                    if (!isNaN(max) && numberValue > max) numberValue = max;
                    this.value = numberValue;
                    this.removeAttribute("data-editing");
                };
            }
            input.onwheel = function (event) { event.preventDefault(); };
        });
    }

    function spinner(id, value, min, max) {
        var maxAttr = max == null ? "" : " data-max='" + max + "'";
        return "<div class='number-spinner'><button type='button' class='spin-button spin-down' data-target='" + id + "'>&#9664;</button><input id='" + id + "' class='numeric-input' type='text' inputmode='numeric' data-min='" + min + "'" + maxAttr + " value='" + value + "'><button type='button' class='spin-button spin-up' data-target='" + id + "'>&#9654;</button></div>";
    }

    function filterRow(key, id, value, min, max, wide) {
        return "<div class='filter-line " + (wide ? "filter-wide" : "filter-half") + "'><label id='bbseed-label-" + key + "'></label>" + spinner(id, value, min, max) + "</div>";
    }

    function clampInput(input, value) {
        var min = parseInt(input.getAttribute("data-min"), 10);
        var max = parseInt(input.getAttribute("data-max"), 10);
        if (isNaN(value)) value = isNaN(min) ? 0 : min;
        if (!isNaN(min) && value < min) value = min;
        if (!isNaN(max) && value > max) value = max;
        input.value = value;
    }

    function changeSpinner(id, delta) {
        var input = document.getElementById(id);
        clampInput(input, (parseInt(input.value, 10) || 0) + delta);
        input.removeAttribute("data-editing");
        input.focus();
        input.select();
    }

    function enableSpinners() {
        Array.prototype.forEach.call(document.querySelectorAll("#bbseed-panel .spin-button"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                changeSpinner(button.getAttribute("data-target"), button.className.indexOf("spin-down") !== -1 ? -1 : 1);
            };
        });
        document.addEventListener("keydown", function (event) {
            var input = document.activeElement;
            if (!input || input.className.indexOf("numeric-input") === -1) return;
            var key = event.key || "";
            var code = event.keyCode || event.which;
            if ((key >= "0" && key <= "9") || (code >= 48 && code <= 57) || (code >= 96 && code <= 105)) {
                var digit = key >= "0" && key <= "9" ? key : String(code >= 96 ? code - 96 : code - 48);
                var keyID = String(code || digit);
                var now = new Date().getTime();
                if (event.repeat || numericKeysDown[keyID] || (lastNumericPress.input === input && lastNumericPress.digit === digit && now - lastNumericPress.time < 100)) {
                    event.preventDefault(); event.stopPropagation(); return false;
                }
                numericKeysDown[keyID] = true;
                lastNumericPress = {input:input, digit:digit, time:now};
                var nextValue = input.getAttribute("data-editing") === "1" ? input.value + digit : digit;
                input.setAttribute("data-editing", "1");
                clampInput(input, parseInt(nextValue, 10));
                event.preventDefault(); event.stopPropagation(); return false;
            }
            if (key === "Backspace" || key === "Delete" || code === 8 || code === 46) {
                input.value = "";
                input.removeAttribute("data-editing");
                event.preventDefault(); event.stopPropagation(); return false;
            }
            if (key === "ArrowLeft" || code === 37) { changeSpinner(input.id, -1); event.preventDefault(); event.stopPropagation(); return false; }
            if (key === "ArrowRight" || code === 39) { changeSpinner(input.id, 1); event.preventDefault(); event.stopPropagation(); return false; }
        }, true);
        document.addEventListener("keyup", function (event) {
            var code = event.keyCode || event.which;
            if (code >= 48 && code <= 57 || code >= 96 && code <= 105) delete numericKeysDown[String(code)];
        }, true);
    }

    function collectionOriginName(origin) {
        return text[currentLanguage].origins[origin] || origin || tr("anyOrigin");
    }

    function pad2(n) { return n < 10 ? "0" + n : String(n); }

    function formatElapsed(ms) {
        var s = Math.floor(ms / 1000);
        return pad2(Math.floor(s / 3600)) + tr("hourUnit") + pad2(Math.floor(s % 3600 / 60)) + tr("minuteUnit") + pad2(s % 60) + tr("secondUnit");
    }

    function formatElapsedShort(ms) {
        var s = Math.floor(ms / 1000);
        return pad2(Math.floor(s / 3600)) + tr("hourUnitShort") + pad2(Math.floor(s % 3600 / 60)) + tr("minuteUnit") + pad2(s % 60) + tr("secondUnit");
    }

    function formatRate(msPerSeed) {
        // Seeds per second. Keep useful decimal precision, but trim zeros:
        // 5000ms -> 0.2, 33ms -> 30.3, 10ms -> 100.
        var seedsPerSecond = 1000 / Math.max(1, msPerSeed);
        var text = seedsPerSecond >= 100 ? seedsPerSecond.toFixed(0) : (seedsPerSecond >= 10 ? seedsPerSecond.toFixed(1) : seedsPerSecond.toFixed(2));
        return text.replace(/\.0+$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
    }

    function updateRunClock() {
        if (!collectionPrompt || collectionPrompt.mode !== "running" || !collectionStartTime) { stopRunClock(); return; }
        var elapsed = Date.now() - collectionStartTime;
        setText("bbseed-run-elapsed-value", formatElapsed(elapsed));
        var done = Math.max(0, parseInt(collectionPrompt.done, 10) || 0);
        if (collectionPrompt.backfill) {
            var rest = Math.max(0, (parseInt(collectionPrompt.total, 10) || 0) - done);
            setText("bbseed-run-rate-value", done > 0 ? formatElapsedShort(rest * elapsed / done) : tr("etaPending"));
        } else {
            setText("bbseed-run-rate-value", done > 0 ? tr("runRate", {rate:formatRate(elapsed / done)}) : tr("runRatePending"));
            // v1.68: ETA for collection runs (backfill mode shows ETA in the
            // rate line instead, so the separate line is hidden there).
            var left = Math.max(0, (parseInt(collectionPrompt.total, 10) || 0) - done);
            setText("bbseed-run-eta-value", done > 0 ? formatElapsedShort(left * elapsed / done) : tr("runRatePending"));
        }
    }

    function startRunClock() {
        stopRunClock();
        runTimer = setInterval(updateRunClock, 1000);
        updateRunClock();
    }

    function stopRunClock() {
        if (runTimer) { clearInterval(runTimer); runTimer = null; }
    }

    function renderCollectionDialog() {
        var layer = document.getElementById("bbseed-collection-layer");
        if (!layer || !collectionPrompt) return;
        var mode = collectionPrompt.mode;
        var isConfirm = mode === "confirm";
        var isRunning = mode === "running";
        var isNotice = mode === "notice";
        var isBackfill = isRunning && !!collectionPrompt.backfill;
        setText("bbseed-collection-dialog-title", isNotice ? tr("chooseOriginTitle") : (isBackfill ? tr("backfillRunningTitle") : (isRunning ? tr("runningTitle") : tr("confirmTitle"))));
        setText("bbseed-collection-warning", isNotice ? tr("chooseOriginFirst") : (isBackfill ? tr("backfillWarning") : tr("confirmWarning")));
        setText("bbseed-collection-summary", isNotice ? "" : (isBackfill ? tr("backfillSummary", {origin:collectionOriginName(collectionPrompt.origin),total:collectionPrompt.total}) : tr("confirmSummary", {origin:collectionOriginName(collectionPrompt.origin),total:collectionPrompt.total})));
        setText("bbseed-confirm-start", tr("confirmStart"));
        setText("bbseed-confirm-cancel", tr("confirmCancel"));
        setText("bbseed-notice-ok", tr("noticeOK"));
        setText("bbseed-run-stop", isBackfill ? tr("backfillStop") : tr("stop"));
        setText("bbseed-run-elapsed-label", tr("runElapsedLabel"));
        setText("bbseed-run-rate-label", isBackfill ? tr("etaLabel") : tr("runRateLabel"));
        // v1.68: separate ETA line, only for collection runs (backfill's rate
        // line already IS the ETA).
        setText("bbseed-run-eta-label", tr("etaRunLabel"));
        document.getElementById("bbseed-run-eta-line").classList.toggle("bbseed-hidden", !isRunning || isBackfill);
        document.getElementById("bbseed-confirm-actions").classList.toggle("bbseed-hidden", !isConfirm);
        document.getElementById("bbseed-notice-actions").classList.toggle("bbseed-hidden", !isNotice);
        document.getElementById("bbseed-running-area").classList.toggle("bbseed-hidden", !isRunning);
        if (isRunning) {
            var done = Math.max(0, parseInt(collectionPrompt.done, 10) || 0);
            var total = Math.max(1, parseInt(collectionPrompt.total, 10) || 1);
            var percentage = Math.max(0, Math.min(100, Math.floor(done * 100 / total)));
            setText("bbseed-run-progress", isBackfill ? tr("backfillProgress", {done:done, total:total}) : done + " / " + total);
            setText("bbseed-run-percent", percentage + "%");
            setText("bbseed-run-saved", isBackfill ? tr("backfillSaved", {saved:collectionPrompt.saved || 0}) : tr("runSaved", {saved:collectionPrompt.saved || 0}));
            document.getElementById("bbseed-run-progress-fill").style.width = percentage + "%";
        }
        layer.classList.remove("bbseed-hidden");
    }

    function hideCollectionDialog() {
        collectionPrompt = null;
        var layer = document.getElementById("bbseed-collection-layer");
        if (layer) layer.classList.add("bbseed-hidden");
    }

    function showCollectionConfirmation() {
        var origin = value("bbseed-origin");
        if (!origin) {
            collectionPrompt = {mode:"notice"};
            renderCollectionDialog();
            return;
        }
        var input = document.getElementById("bbseed-count");
        var total = Math.max(1, Math.min(300000, parseInt(input.value, 10) || 1));
        input.value = total;
        collectionPrompt = {mode:"confirm", origin:origin, total:total};
        renderCollectionDialog();
    }

    function showCollectionRunning(data) {
        data = data || {};
        collectionPrompt = {
            mode:"running",
            origin:data.origin || (collectionPrompt && collectionPrompt.origin) || value("bbseed-origin"),
            done:data.done || 0,
            total:data.total || (collectionPrompt && collectionPrompt.total) || number("bbseed-count"),
            saved:data.saved == null ? (lastStatus ? lastStatus.total : 0) : data.saved,
            backfill:data.backfill != null ? !!data.backfill : !!(collectionPrompt && collectionPrompt.backfill)
        };
        renderCollectionDialog();
    }

    function showCollectionFailure(error) {
        hideCollectionDialog();
        document.getElementById("bbseed-overlay").classList.remove("bbseed-hidden");
        document.getElementById("bbseed-stop").classList.add("bbseed-hidden");
        setText("bbseed-progress", tr("error", {error:error}));
    }

    function beginCollection() {
        if (!collectionPrompt || collectionPrompt.mode !== "confirm") return;
        if (startInFlight) { try { backend("bbseedLog", {message:"double start blocked (collection)"}); } catch (e0) {} return; }
        var request = {origin:collectionPrompt.origin, total:collectionPrompt.total};
        var startButton = document.getElementById("bbseed-confirm-start");
        startButton.disabled = true;
        backend("bbseedSetCount", {count:request.total}, function (status) {
            lastStatus = status;
            document.getElementById("bbseed-count").value = status.maxIters;
            request.total = status.maxIters;
            backend("bbseedArmCollection", {origin:request.origin, mode:collectionMode}, function (result) {
                startButton.disabled = false;
                if (!result || !result.ok) {
                    clearStartWatchdog();
                    var err = result && result.error ? result.error : "Unable to start collection.";
                    if (err === "talent_deserters") err = tr("talentDesertersError");
                    showCollectionFailure(err);
                    return;
                }
                try { backend("bbseedLog", {message:"UI armCollection ok origin=" + result.origin + " total=" + result.total}); } catch (e0) {}
                collectionIsBackfill = false;
                armStartWatchdog();
                pendingCampaign = {mode:"collect", origin:result.origin};
                installCampaignSeedHook();
                showCollectionRunning({origin:result.origin,total:result.total,done:0,saved:status.total});
                setText("bbseed-progress", tr("starting", {total:result.total}));
                openNewCampaignMenu();
            });
        });
    }

    function requestSafeStop() {
        backend("bbseedStop", {});
        if (!collectionStartedFlag) {
            // v1.55: the run never started (stuck or very slow world entry).
            // Disarm so a late startNewCampaign cannot launch a real campaign,
            // then reset the UI. This is the ONLY place that disarms mid-entry.
            clearStartWatchdog();
            backfillQueue = [];
            try { backend("bbseedDisarmCollection", {}); } catch (e) {}
            hideCollectionDialog();
            document.getElementById("bbseed-stop").classList.add("bbseed-hidden");
            setText("bbseed-progress", tr("startCancelled"));
            try { backend("bbseedLog", {message:"start cancelled before world entry finished"}); } catch (e2) {}
            return;
        }
        setText("bbseed-progress", tr("stopping"));
        var button = document.getElementById("bbseed-run-stop");
        if (button) button.disabled = true;
    }

    function findVerticalScroller(node) {
        var panel = document.getElementById("bbseed-panel");
        while (node && node !== panel.parentNode) {
            if (node.nodeType === 1 && node.scrollHeight > node.clientHeight + 2) {
                var style = window.getComputedStyle ? window.getComputedStyle(node) : node.currentStyle;
                var overflowY = style ? style.overflowY : "";
                if (overflowY === "auto" || overflowY === "scroll") return node;
            }
            if (node === panel) break;
            node = node.parentNode;
        }
        return null;
    }

    function normalizeWheel(event) {
        event = event || window.event;
        var target = event.target || event.srcElement;
        if (target && target.className && String(target.className).indexOf("numeric-input") !== -1) return;
        var raw = 0;
        if (typeof event.deltaY === "number" && event.deltaY !== 0) raw = event.deltaY;
        else if (typeof event.wheelDelta === "number" && event.wheelDelta !== 0) raw = -event.wheelDelta;
        else if (typeof event.detail === "number") raw = event.detail;
        if (!raw) return;
        var scroller = findVerticalScroller(target);
        if (!scroller) return;
        var direction = raw > 0 ? 1 : -1;
        var now = new Date().getTime();
        if (!(lastWheel.target === scroller && lastWheel.direction === direction && now - lastWheel.time < 40)) {
            var step = scroller.id === "bbseed-results" ? 46 : (String(scroller.className).indexOf("picker-menu") !== -1 || String(scroller.className).indexOf("trait-menu") !== -1 ? 30 : 34);
            scroller.scrollTop = Math.max(0, Math.min(scroller.scrollHeight - scroller.clientHeight, scroller.scrollTop + direction * step));
            lastWheel = {target:scroller, direction:direction, time:now};
        }
        if (event.preventDefault) event.preventDefault();
        if (event.stopPropagation) event.stopPropagation();
        event.returnValue = false;
        return false;
    }

    function enableNormalizedScrolling() {
        var overlay = document.getElementById("bbseed-overlay");
        if (!overlay || overlay.getAttribute("data-wheel-normalized") === "1") return;
        overlay.setAttribute("data-wheel-normalized", "1");
        overlay.addEventListener("wheel", normalizeWheel, false);
        overlay.addEventListener("mousewheel", normalizeWheel, false);
        overlay.addEventListener("DOMMouseScroll", normalizeWheel, false);
    }

    function applyLanguage() {
        setText("bbseed-launcher", tr("launcher")); setText("bbseed-title", tr("title")); setText("bbseed-stop", tr("stop")); setText("bbseed-close", tr("close"));
        setText("bbseed-lastrate-label", tr("lastRateLabel"));
        setText("bbseed-lastelapsed-label", tr("lastElapsedLabel"));
        setText("bbseed-lang", currentLanguage === "zh" ? "EN" : "\u4e2d\u6587"); setText("bbseed-count-label", tr("count"));
        setText("bbseed-start-collection", tr("startCollection"));
        document.getElementById("bbseed-instructions").innerHTML = tr("instructions");
        document.getElementById("bbseed-talent-help").innerHTML = renderTalentScale();
        ["origin","slot","msk","mdf","rsk","rdf","hp","fat","res","init","required","banned"].forEach(function (key) { setText("bbseed-label-" + key, tr(key)); });
        setText("bbseed-port-filter-label", tr("ports"));
        setText("bbseed-port-nature-filter-label", tr("portNature"));
        setText("bbseed-talent-filter-label", tr("talent"));
        setText("bbseed-quick-trait-filter-label", tr("quickTraitFilter"));
        document.getElementById("bbseed-detail-filter-label").innerHTML = tr("starLabelVert");
        setText("bbseed-mark-filter-label", tr("markFilter"));
        document.getElementById("bbseed-detail-hint").innerHTML = "<span class='hint-gold'>" + esc(tr("detailHint")) + "</span><span class='hint-max'>" + esc(tr("detailHintMax")) + "</span>";
        setText("bbseed-cleanup-talent", tr("cleanupBtn"));
        setText("bbseed-cleanup-hint", tr("cleanupHint"));
        setText("bbseed-cleanup-advice", tr("cleanupAdvice"));
        rebuildModeSwitch();
        setText("bbseed-port-lat-filter-label", tr("northLine"));
        setText("bbseed-south-lat-filter-label", tr("southLine"));
        setText("bbseed-south-lat-hint", tr("southRowHint"));
        setText("bbseed-map-filter", tr("mapFilter")); setText("bbseed-origin-scope-hint", tr("originScopeHint"));
        setText("bbseed-group-generate-label", tr("groupGenerate")); setText("bbseed-group-library-label", tr("groupLibrary"));
        setText("bbseed-group-talent-label", tr("groupTalent")); setText("bbseed-group-map-label", tr("groupMap"));
        setText("bbseed-wipe", tr("wipe")); setText("bbseed-reset", tr("reset"));
        setText("bbseed-export", tr("exportSeeds")); setText("bbseed-import", tr("importSeeds"));
        setText("bbseed-transfer-hint", tr("transferHint"));
        setText("bbseed-clear-required", tr("clear")); setText("bbseed-clear-banned", tr("clear"));
        rebuildOrigins();
        rebuildPortFilters();
        rebuildPortNatureFilters();
        rebuildTalentFilters();
        rebuildQuickTraitFilters();
        rebuildDetailFilters();
        rebuildMarkFilter();
        rebuildPortLatFilters();
        rebuildSouthLatFilters();
        rebuildBrotherTargets();
        rebuildTraits();
        if (collectionPrompt) renderCollectionDialog();
        if (lastStatus) setText("bbseed-status", tr("status", {total:lastStatus.total,batches:lastStatus.batches}));
        if (lastResult) renderRows(lastResult); else setText("bbseed-results", tr("initial"));
    }

    // v1.79 unattended driver: runs the jobs of an optional ::BBSeedAuto table
    // (see the nut file). Does nothing when that table is not defined.
    var autoActive = false;
    function autoLog(message) { try { backend("bbseedLog", {message:"auto: " + message}); } catch (e) {} }
    function autoStep() {
        backend("bbseedAutoNext", {nonce: Math.floor(Math.random() * 2000000000)}, function (job) {
            if (!job || !job.action || job.action === "none") { autoActive = false; return; }
            if (job.action === "quit") {
                autoLog("quit");
                try { Screens.MainMenuScreen.getModule("MainMenuModule").notifyBackendQuitButtonPressed(); }
                catch (e) { autoLog("quit failed: " + e); }
                return;
            }
            autoActive = true;
            if (job.action === "collect") {
                collectionMode = job.mode === "talent" ? "talent" : "full";
                backend("bbseedArmCollection", {origin:job.origin, mode:collectionMode}, function (result) {
                    if (!result || !result.ok) { autoLog("arm failed: " + (result && result.error)); autoActive = false; return; }
                    collectionIsBackfill = false;
                    armStartWatchdog();
                    pendingCampaign = {mode:"collect", origin:result.origin};
                    installCampaignSeedHook();
                    openNewCampaignMenu();
                });
            } else if (job.action === "backfill") {
                if (!job.seeds || !job.seeds.length) { autoLog("backfill: nothing to do"); autoWait(); return; }
                startBackfillQueue([{origin:job.origin, seeds:job.seeds}]);
            }
        });
    }
    function autoWait() {
        setTimeout(function () {
            backend("bbseedAutoReady", {}, function (res) {
                if (res && res.ready) setTimeout(autoStep, 2000); else autoWait();
            });
        }, 2000);
    }

    function build() {
        if (document.getElementById("bbseed-launcher")) return;
        var launcher = document.createElement("button");
        launcher.id = "bbseed-launcher";
        document.body.appendChild(launcher);
        // Hide the launcher on the world map and in battle; keep it while the panel is open or seeds are being collected.
        setInterval(function () {
            var inGame = false;
            ["WorldScreen", "TacticalScreen"].forEach(function (name) {
                try {
                    var screen = Screens[name];
                    if (screen && screen.mContainer && screen.mContainer.is(":visible")) inGame = true;
                } catch (e) {}
            });
            var panel = document.getElementById("bbseed-overlay");
            var busy = runTimer !== null || startInFlight || (panel && !panel.classList.contains("bbseed-hidden"));
            launcher.style.display = inGame && !busy ? "none" : "";
        }, 500);

        var overlay = document.createElement("div");
        overlay.id = "bbseed-overlay";
        overlay.className = "bbseed-hidden";
        overlay.innerHTML = "<div id='bbseed-panel'>"+
            "<div id='bbseed-head'><span id='bbseed-title-wrap'><h1 id='bbseed-title'></h1><span id='bbseed-version'></span></span><span id='bbseed-status'></span><span id='bbseed-progress'></span><span id='bbseed-lastrate'><span id='bbseed-lastrate-label'></span><span id='bbseed-lastrate-value'></span></span><span id='bbseed-lastelapsed'><span id='bbseed-lastelapsed-label'></span><span id='bbseed-lastelapsed-value'></span></span><button id='bbseed-stop' class='bbseed-hidden'></button><button id='bbseed-lang'></button><button id='bbseed-close'></button></div>"+
            "<div id='bbseed-body'><div id='bbseed-controls'><div id='bbseed-controls-scroll'>"+
            "<div class='bbseed-group' id='bbseed-group-generate'><span class='bbseed-group-label' id='bbseed-group-generate-label'></span>"+
            "<div class='count-line'><label id='bbseed-count-label'></label>"+spinner("bbseed-count",100,1,300000)+"</div>"+
            "<div id='bbseed-mode-line'><span id='bbseed-mode-label'></span><div id='bbseed-mode-buttons'></div><div id='bbseed-mode-hint'><div id='bbseed-mode-hint-full'></div><div id='bbseed-mode-hint-talent'></div></div></div>"+
            "<div id='bbseed-origin-scope'><span id='bbseed-map-filter' class='origin-scope-label'></span><span id='bbseed-origin-scope-hint'></span></div>"+
            "<input id='bbseed-origin' type='hidden' value=''><div id='bbseed-origin-buttons'></div>"+
            "<button type='button' id='bbseed-start-collection'></button>"+
            "<p id='bbseed-instructions'></p></div>"+
            "<div class='bbseed-group' id='bbseed-group-library'><span class='bbseed-group-label' id='bbseed-group-library-label'></span>"+
            "<button type='button' id='bbseed-cleanup-talent'></button><p id='bbseed-cleanup-hint'></p><p id='bbseed-cleanup-advice'></p>"+
            "<div class='actions transfer-actions'><button id='bbseed-export'></button><button id='bbseed-import'></button></div><p class='transfer-hint' id='bbseed-transfer-hint'></p>"+
            "<div class='actions primary-actions'><button id='bbseed-wipe'></button><button id='bbseed-reset'></button></div></div>"+
            "<div id='bbseed-talent-help' class='talent-help'></div>"+
            "</div></div><div id='bbseed-results-pane'><div id='bbseed-results-tools'>"+
            "<div class='bbseed-filter-group' id='bbseed-group-talent'><span class='bbseed-group-label' id='bbseed-group-talent-label'></span>"+
            "<div id='bbseed-talent-filter'><span id='bbseed-talent-filter-label'></span><div id='bbseed-talent-buttons'></div></div>"+
            "<div id='bbseed-quick-trait-filter'><span id='bbseed-quick-trait-filter-label'></span><div id='bbseed-quick-trait-buttons'></div></div>"+
            "<div id='bbseed-detail-box'><div id='bbseed-detail-filter'><span id='bbseed-detail-filter-label'></span><div id='bbseed-detail-buttons'></div></div><div class='detail-hint' id='bbseed-detail-hint'></div></div></div>"+
            "<div class='bbseed-filter-group' id='bbseed-group-map'><span class='bbseed-group-label' id='bbseed-group-map-label'></span>"+
            "<div id='bbseed-port-filter'><span id='bbseed-port-filter-label'></span><div id='bbseed-port-buttons'></div></div>"+
            "<div id='bbseed-port-nature-filter'><span id='bbseed-port-nature-filter-label'></span><div id='bbseed-port-nature-buttons'></div></div>"+
            "<div id='bbseed-port-lat-filter'><span id='bbseed-port-lat-filter-label'></span><div id='bbseed-port-lat-buttons'></div></div>"+
            "<div id='bbseed-south-lat-filter'><span id='bbseed-south-lat-filter-label'></span><div id='bbseed-south-lat-buttons'></div><span id='bbseed-south-lat-hint'></span></div>"+
            "<div id='bbseed-mark-filter'><span id='bbseed-mark-filter-label'></span><div id='bbseed-mark-buttons'></div></div></div>"+
            "</div><div id='bbseed-results'></div></div></div>"+
            "<div id='bbseed-dialog-layer' class='bbseed-hidden'><div id='bbseed-dialog'></div></div>"+
            "<div id='bbseed-collection-layer' class='bbseed-hidden'><div id='bbseed-collection-dialog'><h2 id='bbseed-collection-dialog-title'></h2><p id='bbseed-collection-warning'></p><p id='bbseed-collection-summary'></p><div id='bbseed-running-area' class='bbseed-hidden'><div class='run-progress-line'><strong id='bbseed-run-progress'></strong><span id='bbseed-run-percent'></span></div><div id='bbseed-run-progress-track'><div id='bbseed-run-progress-fill'></div></div><p id='bbseed-run-saved'></p><p id='bbseed-run-clock-line'><span id='bbseed-run-elapsed-label'></span><span id='bbseed-run-elapsed-value'></span></p><p id='bbseed-run-rate-line'><span id='bbseed-run-rate-label'></span><span id='bbseed-run-rate-value'></span></p><p id='bbseed-run-eta-line'><span id='bbseed-run-eta-label'></span><span id='bbseed-run-eta-value'></span></p><button type='button' id='bbseed-run-stop'></button></div><div id='bbseed-confirm-actions'><button type='button' id='bbseed-confirm-cancel'></button><button type='button' id='bbseed-confirm-start'></button></div><div id='bbseed-notice-actions' class='bbseed-hidden'><button type='button' id='bbseed-notice-ok'></button></div></div></div></div>";
        document.body.appendChild(overlay);
        var slowHint = document.createElement("div");
        slowHint.id = "bbseed-slow-hint";
        slowHint.className = "bbseed-hidden";
        overlay.appendChild(slowHint);

        launcher.onclick = function () { overlay.classList.remove("bbseed-hidden"); refreshStatus(); search(false); };
        document.getElementById("bbseed-close").onclick = function () { overlay.classList.add("bbseed-hidden"); };
        document.getElementById("bbseed-lang").onclick = function () { currentLanguage = currentLanguage === "zh" ? "en" : "zh"; applyLanguage(); backend("bbseedSetLanguage", {language:currentLanguage}); };
        document.getElementById("bbseed-start-collection").onclick = showCollectionConfirmation;
        document.getElementById("bbseed-stop").onclick = requestSafeStop;
        document.getElementById("bbseed-confirm-cancel").onclick = hideCollectionDialog;
        document.getElementById("bbseed-confirm-start").onclick = beginCollection;
        document.getElementById("bbseed-notice-ok").onclick = hideCollectionDialog;
        document.getElementById("bbseed-run-stop").onclick = requestSafeStop;
        document.getElementById("bbseed-cleanup-talent").onclick = requestCleanup;
        document.getElementById("bbseed-wipe").onclick = requestWipe;
        document.getElementById("bbseed-export").onclick = requestExport;
        document.getElementById("bbseed-import").onclick = requestImport;
        document.getElementById("bbseed-reset").onclick = resetFilters;
        installCampaignSeedHook();
        installStorageVisibilityHooks();
        setTimeout(installStorageVisibilityHooks, 1000);
        setTimeout(installStorageVisibilityHooks, 5000);
        makeInputsEditable();
        enableSpinners();
        enableNormalizedScrolling();
        applyLanguage(); refreshStatus(); loadTraits(); backend("bbseedReportUIReady", {ready:true}); setTimeout(autoStep, 3000);
    }


    function rebuildModeSwitch() {
        var target = document.getElementById("bbseed-mode-buttons");
        if (!target) return;
        var choices = [{value:"full", label:tr("modeFull")}, {value:"talent", label:tr("modeTalent")}];
        target.innerHTML = choices.map(function (choice) {
            return "<button type='button' class='mode-choice" + (collectionMode === choice.value ? " selected" : "") + "' data-mode='" + choice.value + "'>" + esc(choice.label) + "</button>";
        }).join("");
        Array.prototype.forEach.call(target.querySelectorAll(".mode-choice"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                collectionMode = button.getAttribute("data-mode") === "talent" ? "talent" : "full";
                rebuildModeSwitch();
                backend("bbseedSetMode", {mode:collectionMode});
            };
        });
        setText("bbseed-mode-label", tr("modeLabel"));
        var hintFull = document.getElementById("bbseed-mode-hint-full");
        var hintTalent = document.getElementById("bbseed-mode-hint-talent");
        if (hintFull) { hintFull.textContent = tr("modeHintFull"); hintFull.className = collectionMode === "full" ? "mh-on" : ""; }
        if (hintTalent) { hintTalent.textContent = tr("modeHintTalent"); hintTalent.className = collectionMode === "talent" ? "mh-on" : ""; }
    }

    function showDialog(html) {
        var layer = document.getElementById("bbseed-dialog-layer");
        if (!layer) return;
        document.getElementById("bbseed-dialog").innerHTML = html;
        layer.classList.remove("bbseed-hidden");
    }

    function hideDialog() {
        stopCleanupCountdown();
        stopWipeCountdown();
        var layer = document.getElementById("bbseed-dialog-layer");
        if (layer) layer.classList.add("bbseed-hidden");
    }

    function isUnmapped(row) { return ((parseInt(row.portFlags, 10) || 0) & 1) === 0; }

    function groupByOrigin(rows) {
        var groups = {};
        var order = [];
        rows.forEach(function (row) {
            if (!groups[row.origin]) { groups[row.origin] = []; order.push(row.origin); }
            groups[row.origin].push(row.seed);
        });
        return order.map(function (origin) { return {origin:origin, seeds:groups[origin]}; });
    }

    function confirmBackfill(groups) {
        var total = 0;
        groups.forEach(function (g) { total += g.seeds.length; });
        if (!total) return;
        var eta = lastRateMsPerSeed > 0
            ? "<p>" + esc(tr("backfillEta", {eta:formatElapsedShort(total * lastRateMsPerSeed), rate:tr("runRate", {rate:formatRate(lastRateMsPerSeed)})})) + "</p>"
            : "<p>" + esc(tr("backfillNoEta")) + "</p>";
        var multi = groups.length > 1 ? "<p>" + esc(tr("backfillMulti")) + "</p>" : "";
        showDialog("<h2>" + esc(tr("backfillTitle")) + "</h2>" +
            "<p>" + esc(tr("backfillDesc", {count:total})) + "</p>" + eta + multi +
            "<div class='dialog-actions'>" +
            "<button type='button' id='bbseed-backfill-cancel'>" + esc(tr("backfillCancel")) + "</button>" +
            "<button type='button' id='bbseed-backfill-start' class='dialog-primary'>" + esc(tr("backfillStart")) + "</button>" +
            "</div>");
        document.getElementById("bbseed-backfill-cancel").onclick = function () { hideDialog(); };
        document.getElementById("bbseed-backfill-start").onclick = function () {
            try { backend("bbseedLog", {message:"UI backfill start clicked groups=" + groups.length}); } catch (e0) {}
            hideDialog();
            startBackfillQueue(groups);
        };
    }

    function startBackfillQueue(groups) {
        backfillQueue = groups.slice();
        runNextBackfill();
    }

    function runNextBackfill() {
        if (!backfillQueue.length) return;
        if (startInFlight) { try { backend("bbseedLog", {message:"double start blocked (backfill)"}); } catch (e0) {} backfillQueue = []; return; }
        var group = backfillQueue[0];
        try { backend("bbseedLog", {message:"UI armBackfill origin=" + group.origin + " seeds=" + group.seeds.length}); } catch (e0) {}
        backend("bbseedArmBackfill", {origin:group.origin, seeds:group.seeds}, function (result) {
            try { backend("bbseedLog", {message:"UI armBackfill result ok=" + (result && result.ok)}); } catch (e1) {}
            if (!result || !result.ok) {
                clearStartWatchdog();
                backfillQueue = [];
                showCollectionFailure(result && result.error ? result.error : "Unable to start backfill.");
                return;
            }
            collectionIsBackfill = true;
            armStartWatchdog();
            pendingCampaign = {mode:"collect", origin:group.origin};
            installCampaignSeedHook();
            // v1.57: open the progress dialog NOW - the world entry blocks
            // the main thread for seconds, and for single-seed backfills the
            // whole job may finish before the first backend notification
            // would otherwise arrive, leaving zero visible feedback.
            showCollectionRunning({origin:group.origin, total:group.seeds.length, done:0, saved:lastStatus ? lastStatus.total : 0, backfill:true});
            setText("bbseed-progress", tr("starting", {total:group.seeds.length}));
            collectionStartTime = Date.now();
            startRunClock();
            openNewCampaignMenu();
        });
    }

    function stopCleanupCountdown() {
        if (cleanupTimer) { clearInterval(cleanupTimer); cleanupTimer = null; }
    }

    function startCleanupCountdown(total) {
        var seconds = 5;
        showDialog("<h2>" + esc(tr("cleanupTitle")) + "</h2>" +
            "<p>" + esc(tr("cleanupDesc", {count:total})) + "</p>" +
            "<p>" + esc(tr("cleanupCountdown", {sec:seconds})) + "</p>" +
            "<div class='cl-count' id='bbseed-cleanup-count'>" + seconds + "</div>" +
            "<div class='dialog-actions'>" +
            "<button type='button' id='bbseed-cleanup-cancel' class='dialog-primary'>" + esc(tr("cleanupCancel")) + "</button>" +
            "</div>");
        document.getElementById("bbseed-cleanup-cancel").onclick = function () { hideDialog(); };
        stopCleanupCountdown();
        cleanupTimer = setInterval(function () {
            seconds--;
            var box = document.getElementById("bbseed-cleanup-count");
            if (seconds <= 0) {
                stopCleanupCountdown();
                hideDialog();
                backend("bbseedCleanupTalent", {}, function (res) {
                    if (res && res.ok === false) { showCollectionFailure(res.error || "cleanup failed"); return; }
                    var deleted = res && res.deleted != null ? res.deleted : 0;
                    setText("bbseed-progress", tr("cleanupDone", {count:deleted}));
                    refreshStatus();
                    search(false);
                });
                return;
            }
            if (box) box.textContent = seconds;
        }, 1000);
    }

    function requestCleanup() {
        backend("bbseedCleanupPrecheck", {}, function (res) {
            res = res || {total:0, high:0, examples:[]};
            if (!res.total) {
                showDialog("<h2>" + esc(tr("cleanupTitle")) + "</h2><p>" + esc(tr("cleanupNone")) + "</p>" +
                    "<div class='dialog-actions'><button type='button' id='bbseed-cleanup-ok' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
                document.getElementById("bbseed-cleanup-ok").onclick = function () { hideDialog(); };
                return;
            }
            if (res.high > 0) {
                var examples = (res.examples || []).map(function (e) { return e.seed + " (" + e.score + ")"; }).join(", ");
                showDialog("<h2>" + esc(tr("cleanupTitle")) + "</h2>" +
                    "<p>" + esc(tr("cleanupDesc", {count:res.total})) + "</p>" +
                    "<p class='cl-danger'>" + esc(tr("cleanupWarn", {high:res.high, examples:examples})) + "</p>" +
                    "<div class='dialog-actions'>" +
                    "<button type='button' id='bbseed-cleanup-yes'>" + esc(tr("cleanupYes")) + "</button>" +
                    "<button type='button' id='bbseed-cleanup-no' class='dialog-primary'>" + esc(tr("cleanupNo")) + "</button>" +
                    "</div>");
                document.getElementById("bbseed-cleanup-yes").onclick = function () { startCleanupCountdown(res.total); };
                document.getElementById("bbseed-cleanup-no").onclick = function () { hideDialog(); };
                return;
            }
            startCleanupCountdown(res.total);
        });
    }

    function stopWipeCountdown() {
        if (wipeTimer) { clearInterval(wipeTimer); wipeTimer = null; }
    }

    function startWipeCountdown(total) {
        // v1.62: 10 second countdown before wiping the whole library.
        // Cancel (or any dialog close) aborts via hideDialog -> stopWipeCountdown.
        var seconds = 10;
        showDialog("<h2>" + esc(tr("wipeTitle")) + "</h2>" +
            "<p class='cl-danger'>" + esc(tr("wipeDesc", {count:total})) + "</p>" +
            "<p>" + esc(tr("wipeCountdown", {sec:seconds})) + "</p>" +
            "<div class='cl-count' id='bbseed-wipe-count'>" + seconds + "</div>" +
            "<div class='dialog-actions'>" +
            "<button type='button' id='bbseed-wipe-cancel' class='dialog-primary'>" + esc(tr("wipeCancel")) + "</button>" +
            "</div>");
        document.getElementById("bbseed-wipe-cancel").onclick = function () { hideDialog(); };
        stopWipeCountdown();
        wipeTimer = setInterval(function () {
            seconds--;
            var box = document.getElementById("bbseed-wipe-count");
            if (seconds <= 0) {
                stopWipeCountdown();
                hideDialog();
                backend("bbseedWipeAll", {}, function (res) {
                    if (res && res.ok === false) { showCollectionFailure(tr("wipeFailed") + (res.error || "unknown")); return; }
                    var deleted = res && res.deleted != null ? res.deleted : 0;
                    lastResult = null;
                    showDialog("<h2>" + esc(tr("wipeTitle")) + "</h2><p>" + esc(tr("wipeDone", {count:deleted})) + "</p>" +
                        "<div class='dialog-actions'><button type='button' id='bbseed-wipe-ok' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
                    document.getElementById("bbseed-wipe-ok").onclick = function () { hideDialog(); };
                    refreshStatus();
                    search(false);
                });
                return;
            }
            if (box) box.textContent = seconds;
        }, 1000);
    }

    function requestWipe() {
        backend("bbseedWipePrecheck", {}, function (res) {
            res = res || {total:0};
            if (!res.total) {
                showDialog("<h2>" + esc(tr("wipeTitle")) + "</h2><p>" + esc(tr("wipeNone")) + "</p>" +
                    "<div class='dialog-actions'><button type='button' id='bbseed-wipe-ok' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
                document.getElementById("bbseed-wipe-ok").onclick = function () { hideDialog(); };
                return;
            }
            startWipeCountdown(res.total);
        });
    }

    // ----- v1.63: export / import of marked seeds -----

    function noticeDialog(titleKey, text) {
        showDialog("<h2>" + esc(tr(titleKey)) + "</h2><p>" + text + "</p>" +
            "<div class='dialog-actions'><button type='button' id='bbseed-notice-ok2' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
        document.getElementById("bbseed-notice-ok2").onclick = function () { hideDialog(); };
    }

    function runExport(payload) {
        backend("bbseedExportMarked", payload, function (res) {
            res = res || {ok:false};
            if (res.ok === false) { showCollectionFailure(tr("exportFailed") + (res.error || "unknown")); return; }
            if (!res.total) { noticeDialog("exportTitle", esc(tr("exportNone"))); return; }
            showDialog("<h2>" + esc(tr("exportTitle")) + "</h2>" +
                "<p>" + esc(tr("exportDone", {count:res.total})) + "</p>" +
                "<p><b>" + esc(res.file || "") + "</b></p>" +
                "<p>" + esc(tr("exportNote")) + "</p>" +
                "<div class='dialog-actions'><button type='button' id='bbseed-export-ok' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
            document.getElementById("bbseed-export-ok").onclick = function () { hideDialog(); };
        });
    }

    // v1.71: two-step export dialog - pick "new file" vs "overwrite an
    // existing export" first, then run the export. The marked count comes
    // from a fresh status call so the dialog can refuse early with zero.
    function requestExport() {
        backend("bbseedGetStatus", null, function (status) {
            status = status || {};
            var markedCount = status.marked || 0;
            if (!markedCount) { noticeDialog("exportTitle", esc(tr("exportNone"))); return; }
            backend("bbseedImportList", {}, function (listRes) {
                listRes = listRes || {files:[]};
                var files = listRes.files || [];
                var mode = "new", target = "";
                showDialog("<h2>" + esc(tr("exportTitle")) + "</h2>" +
                    "<p>" + esc(tr("exportWillExport", {count:markedCount})) + " " + esc(tr("exportModePick")) + "</p>" +
                    "<div class='export-mode'>" +
                    "<button type='button' id='bbseed-export-mode-new' class='export-mode-choice selected'>" + esc(tr("exportModeNew")) + "</button>" +
                    "<button type='button' id='bbseed-export-mode-overwrite' class='export-mode-choice'>" + esc(tr("exportModeOverwrite")) + "</button>" +
                    "</div>" +
                    "<p id='bbseed-export-mode-hint' class='export-mode-hint'></p>" +
                    "<div id='bbseed-export-filewrap' class='file-list-scroll' style='display:none'></div>" +
                    "<div class='dialog-actions'>" +
                    "<button type='button' id='bbseed-export-cancel'>" + esc(tr("cleanupCancel")) + "</button>" +
                    "<button type='button' id='bbseed-export-go' class='dialog-primary'>" + esc(tr("exportConfirm")) + "</button>" +
                    "</div>");
                var wrap = document.getElementById("bbseed-export-filewrap");
                var hint = document.getElementById("bbseed-export-mode-hint");
                var goBtn = document.getElementById("bbseed-export-go");
                function refresh() {
                    document.getElementById("bbseed-export-mode-new").className = "export-mode-choice" + (mode === "new" ? " selected" : "");
                    document.getElementById("bbseed-export-mode-overwrite").className = "export-mode-choice" + (mode === "overwrite" ? " selected" : "");
                    if (mode === "new") {
                        hint.textContent = tr("exportNewHint");
                        wrap.style.display = "none";
                        goBtn.disabled = false;
                        return;
                    }
                    hint.textContent = tr("exportPickOverwrite");
                    wrap.style.display = "";
                    if (!files.length) {
                        wrap.innerHTML = "<p class='export-mode-hint'>" + esc(tr("exportNoFiles")) + "</p>";
                        goBtn.disabled = true;
                        return;
                    }
                    var inner = "";
                    files.forEach(function (f, idx) {
                        inner += "<button type='button' class='import-file-choice export-file-choice" + (f.file === target ? " selected" : "") + "' data-idx='" + idx + "'><b>" + esc(f.file + ".sav") + "</b><br><span class='import-file-meta'>" + esc(tr("seedCount", {count:f.count})) + " \u00b7 " + esc(f.stamp) + "</span></button>";
                    });
                    wrap.innerHTML = inner;
                    Array.prototype.forEach.call(wrap.querySelectorAll(".export-file-choice"), function (button) {
                        button.onclick = function () {
                            target = files[parseInt(button.getAttribute("data-idx"), 10) || 0].file;
                            refresh();
                        };
                    });
                    goBtn.disabled = !target;
                }
                document.getElementById("bbseed-export-mode-new").onclick = function () { mode = "new"; refresh(); };
                document.getElementById("bbseed-export-mode-overwrite").onclick = function () { mode = "overwrite"; refresh(); };
                document.getElementById("bbseed-export-cancel").onclick = function () { hideDialog(); };
                goBtn.onclick = function () {
                    if (goBtn.disabled) return;
                    var payload = (mode === "overwrite" && target) ? {target:target} : {};
                    hideDialog();
                    runExport(payload);
                };
                refresh();
            });
        });
    }

    function doImport(file) {
        backend("bbseedImport", {file:file}, function (res) {
            res = res || {ok:false};
            if (res.ok === false) {
                noticeDialog("importTitle", esc(res.error === "bad file" ? tr("importBad") : (tr("importFailed") + (res.error || "unknown"))));
                return;
            }
            var text = tr("importDone", {count:res.imported || 0, batch:res.batch || "?"});
            if (res.skipped) text += " " + tr("importSkipped", {count:res.skipped});
            noticeDialog("importTitle", esc(text));
            refreshStatus();
            search(false);
        });
    }

    function requestImport() {
        backend("bbseedImportList", {}, function (res) {
            res = res || {files:[]};
            var files = res.files || [];
            var nextBatch = res.nextBatch || 0;
            if (!files.length) { noticeDialog("importTitle", esc(tr("importNone"))); return; }
            if (files.length === 1) {
                var f = files[0];
                showDialog("<h2>" + esc(tr("importTitle")) + "</h2>" +
                    "<p>" + esc(tr("importOne")) + "<br><b>" + esc(f.file + ".sav") + "</b> (" + esc(tr("seedCount", {count:f.count})) + ")</p>" +
                    "<p>" + esc(tr("importRule", {batch:nextBatch})) + "</p>" +
                    "<div class='dialog-actions'>" +
                    "<button type='button' id='bbseed-import-cancel'>" + esc(tr("cleanupCancel")) + "</button>" +
                    "<button type='button' id='bbseed-import-go' class='dialog-primary'>" + esc(tr("importConfirm")) + "</button>" +
                    "</div>");
                document.getElementById("bbseed-import-cancel").onclick = function () { hideDialog(); };
                document.getElementById("bbseed-import-go").onclick = function () { hideDialog(); doImport(f.file); };
                return;
            }
            var html = "<h2>" + esc(tr("importTitle")) + "</h2>" +
                "<p>" + esc(tr("importPick", {count:files.length})) + "</p>" +
                "<div class='file-list-scroll'>";
            files.forEach(function (f, idx) {
                html += "<button type='button' class='import-file-choice' data-idx='" + idx + "'><b>" + esc(f.file + ".sav") + "</b><br><span class='import-file-meta'>" + esc(tr("seedCount", {count:f.count})) + " \u00b7 " + esc(f.stamp) + "</span></button>";
            });
            html += "</div><p>" + esc(tr("importRule", {batch:nextBatch})) + "</p>" +
                "<div class='dialog-actions'><button type='button' id='bbseed-import-cancel' class='dialog-primary'>" + esc(tr("cleanupCancel")) + "</button></div>";
            showDialog(html);
            document.getElementById("bbseed-import-cancel").onclick = function () { hideDialog(); };
            Array.prototype.forEach.call(document.getElementById("bbseed-dialog").querySelectorAll(".import-file-choice"), function (button) {
                button.onclick = function () {
                    var f = files[parseInt(button.getAttribute("data-idx"), 10) || 0];
                    hideDialog();
                    doImport(f.file);
                };
            });
        });
    }

    function value(id) { return document.getElementById(id).value; }
    function number(id) { return Math.max(0, parseInt(value(id), 10) || 0); }

    function refreshStatus() {
        backend("bbseedGetStatus", null, function (status) {
            lastStatus = status;
            if (status.language === "zh" || status.language === "en") currentLanguage = status.language;
            if (status.mode === "talent" || status.mode === "full") collectionMode = status.mode;
            if (status.version != null) setText("bbseed-version", "v" + Number(status.version).toFixed(2));
            rebuildModeSwitch();
            document.getElementById("bbseed-count").value = status.maxIters;
            applyLanguage();
        });
    }

    function filters() {
        return {origin:value("bbseed-origin"),ports:portMinimum,southNorthPort:requireSouthNorthPort ? 1 : 0,arenaPort:requireArenaPort ? 1 : 0,northLine:northLine,southLine:southLine,talentTop100:talentTop100,quickTrait:quickTraits.join(","),smsk:detailStars.smsk3 ? 3 : (detailStars.smsk2 ? 2 : 0),smdf:detailStars.smdf3 ? 3 : (detailStars.smdf2 ? 2 : 0),srsk:detailStars.srsk3 ? 3 : (detailStars.srsk2 ? 2 : 0),sftg:detailStars.sftg3 ? 3 : (detailStars.sftg2 ? 2 : 0),sini:detailStars.sini3 ? 3 : (detailStars.sini2 ? 2 : 0),noNegative:detailStars.noNegative ? 1 : 0,sortField:sortField,sortDir:sortDir,marked:markFilter === "all" ? "" : markFilter,offset:pageOffset,limit:200};
    }

    function search(resetPage) {
        if (resetPage !== false) pageOffset = 0;
        // v1.69: show a scanning notice WITH the library size, and give the UI
        // one frame to paint it before the (potentially slow) backend scan.
        // querySeq drops stale callbacks from superseded searches.
        var seq = ++querySeq;
        var total = lastStatus && lastStatus.total ? lastStatus.total : 0;
        setText("bbseed-results", tr("scanning", {total:total}));
        setTimeout(function () {
            if (seq !== querySeq) return;
            backend("bbseedQuery", filters(), function (result) {
                if (seq !== querySeq) return;
                lastResult = result;
                renderRows(result);
            });
        }, 60);
    }

    function sortHeaderCell(field, label, cls) {
        var active = sortField === field;
        var arrow = active ? (sortDir === "desc" ? "&#9660;" : "&#9650;") : "&#8691;";
        return "<th class='" + cls + " sortable' data-sort='" + field + "'>" + esc(label) + "<span class='sort-arrow" + (active ? "" : " inactive") + "'>" + arrow + "</span></th>";
    }

    function renderRows(result) {
        lastMatched = result.matched;
        var target = document.getElementById("bbseed-results");
        var rangeStart = result.rows.length ? pageOffset + 1 : 0;
        var rangeEnd = result.rows.length ? Math.min(pageOffset + result.rows.length, result.matched) : 0;
        var names = text[currentLanguage].origins;
        var latestBatch = result.latestBatch || 0;
        var unmapped = [];
        result.rows.forEach(function (row) { if (isUnmapped(row)) unmapped.push(row); });
        var backfillBar = unmapped.length ? "<span class='backfill-bar'><button type='button' id='bbseed-backfill-btn'>" + esc(tr("backfillBar", {count:unmapped.length})) + "</button></span>" : "";
        // v1.63: green hint shown only while "no negative traits" is the
        // SOLE active detail condition (then it filters the top brother).
        // v1.67: the best-score rule also requires no trait multi-select,
        // because with traits selected everything must sit on one brother.
        var starActive = detailStars.smsk3 || detailStars.smsk2 || detailStars.smdf3 || detailStars.smdf2 || detailStars.sftg3 || detailStars.sftg2 || detailStars.sini3 || detailStars.sini2 || detailStars.srsk3 || detailStars.srsk2;
        var nonegHintHtml = (detailStars.noNegative && !starActive && quickTraits.length === 0) ? "<p class='noneg-hint'>" + esc(tr("nonegHint")) + "</p>" : "";
        var html = "<p>" + tr("matched", {matched:result.matched,total:result.total,start:rangeStart,end:rangeEnd}) + backfillBar + "</p>" + nonegHintHtml + "<table><thead><tr><th class='origin-column'>"+tr("origin")+"</th>"+sortHeaderCell("batch",tr("batch"),"batch-column")+sortHeaderCell("talent",tr("talentAverage"),"talent-column")+sortHeaderCell("max",tr("maxScore"),"max-column")+"<th class='rank-column'>"+tr("talentPercentile")+"</th><th class='mark-column'>"+tr("mark")+"</th><th class='port-count-column'>"+tr("ports")+"</th><th class='port-property-column'>"+tr("southNorthPort")+"</th><th class='port-property-column'>"+tr("arenaPort")+"</th><th class='seed-column'>"+tr("seed")+"</th></tr></thead><tbody>";
        result.rows.forEach(function (row, idx) {
            html += "<tr class='seed-row' data-detail='bbseed-detail-"+idx+"'><td>"+esc(names[row.origin]||row.origin)+"</td><td><span class='batch-cell"+(row.batch && row.batch === latestBatch ? " latest" : "")+"'>"+(row.batch || "?")+"</span></td><td><span class='seed-talent-score'>"+formatTalentAverage(row.talentScore10)+"</span></td><td><span class='seed-max-score'>"+(row.maxScore || 0)+"</span></td><td><span class='seed-talent-top'>"+formatTalentTop(row.talentTop100)+"</span></td><td><button type='button' class='mark-btn"+(row.marked ? " on" : "")+"' data-seed='"+esc(row.seed)+"' data-origin='"+esc(row.origin)+"' data-index='"+idx+"'>"+esc(tr(row.marked ? "markYes" : "markNo"))+"</button></td><td>"+(isUnmapped(row)?"<span class='port-property unknown'>"+esc(tr("unknown"))+"</span>":row.ports)+"</td><td>"+formatPortProperty(row.portFlags,"southNorth")+"</td><td>"+formatPortProperty(row.portFlags,"arena")+"</td><td class='seed'>"+esc(row.seed)+(isUnmapped(row)?"<button type='button' class='row-backfill-btn' data-seed='"+esc(row.seed)+"' data-origin='"+esc(row.origin)+"'>"+esc(tr("backfillRow"))+"</button>":"")+"</td></tr>";
            html += "<tr id='bbseed-detail-"+idx+"' class='bro-row bbseed-hidden'><td colspan='10'>"+row.bros.map(function (b) {
                return "<div class='bro'><div class='bro-name'><b>#"+b.slot+" "+esc(b.name)+"</b><span class='bro-talent-summary'><span class='bro-talent-score'>"+tr("brotherTalent")+" "+b.talentScore+"</span><span class='bro-projected'>"+tr("projectedMelee")+" "+b.projectedMSK+"</span></span></div><div class='bro-stats'>"+
                    statCell(tr("msk"),b.msk,b.smsk)+statCell(tr("mdf"),b.mdf,b.smdf)+statCell(tr("rsk"),b.rsk,b.srsk)+statCell(tr("rdf"),b.rdf,b.srdf)+
                    statCell(tr("hp"),b.hp,b.shp)+statCell(tr("fat"),b.fat,b.sfat)+statCell(tr("res"),b.res,b.sres)+statCell(tr("init"),b.init,b.sinit)+
                    "</div><div class='bro-traits'><b>"+tr("traits")+"\uff1a</b><span class='trait-list'>"+renderTraitTags(b.traits)+"</span></div></div>";
            }).join("")+"<button type='button' class='use-seed' data-seed='"+esc(row.seed)+"' data-origin='"+esc(row.origin)+"'>"+tr("useSeed")+"</button></td></tr>";
        });
        target.innerHTML = html + "</tbody></table>";
        Array.prototype.forEach.call(target.querySelectorAll(".seed-row"), function (rowElement) {
            rowElement.onclick = function () { document.getElementById(rowElement.getAttribute("data-detail")).classList.toggle("bbseed-hidden"); };
        });
        Array.prototype.forEach.call(target.querySelectorAll(".use-seed"), function (button) { button.onclick = function (event) { event.stopPropagation(); useSeed(button); }; });
        Array.prototype.forEach.call(target.querySelectorAll(".row-backfill-btn"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                confirmBackfill([{origin:button.getAttribute("data-origin"), seeds:[button.getAttribute("data-seed")]}]);
            };
        });
        var backfillBtn = document.getElementById("bbseed-backfill-btn");
        if (backfillBtn) backfillBtn.onclick = function (event) {
            event.stopPropagation();
            confirmBackfill(groupByOrigin(unmapped));
        };
        Array.prototype.forEach.call(target.querySelectorAll("th.sortable"), function (header) {
            header.onclick = function (event) {
                event.stopPropagation();
                var field = header.getAttribute("data-sort");
                if (sortField === field) sortDir = sortDir === "desc" ? "asc" : "desc";
                else { sortField = field; sortDir = "desc"; }
                pageOffset = 0;
                search(false);
            };
        });
        Array.prototype.forEach.call(target.querySelectorAll(".mark-btn"), function (button) {
            button.onclick = function (event) {
                event.stopPropagation();
                var idx = parseInt(button.getAttribute("data-index"), 10);
                backend("bbseedToggleMark", {origin:button.getAttribute("data-origin"), seed:button.getAttribute("data-seed")}, function (res) {
                    if (!res || !res.ok) return;
                    var marked = !!res.marked;
                    button.className = "mark-btn" + (marked ? " on" : "");
                    button.textContent = tr(marked ? "markYes" : "markNo");
                    if (lastResult && lastResult.rows && lastResult.rows[idx]) lastResult.rows[idx].marked = marked;
                });
            };
        });
    }

    function statCell(label, value, stars) {
        return "<div class='stat-cell'><span class='stat-label'>"+esc(label)+"</span><span class='stat-value'>"+value+star(stars)+"</span></div>";
    }

    function resetFilters() {
        portMinimum = 0;
        requireSouthNorthPort = false;
        requireArenaPort = false;
        talentTop100 = 10000;
        quickTraits = [];
        detailStars = {smsk3:false, smsk2:false, smdf3:false, smdf2:false, sftg3:false, sftg2:false, sini3:false, sini2:false, srsk3:false, srsk2:false, noNegative:false};
        sortField = "talent";
        sortDir = "desc";
        markFilter = "all";
        northLine = 80;
        southLine = 0;
        document.getElementById("bbseed-origin").value = "";
        pageOffset = 0;
        rebuildPortFilters();
        rebuildPortNatureFilters();
        rebuildPortLatFilters();
        rebuildSouthLatFilters();
        rebuildTalentFilters();
        rebuildQuickTraitFilters();
        rebuildDetailFilters();
        rebuildMarkFilter();
        search(false);
    }

    function scheduleExitCheck(attempt) {
        // v1.58: after a job the world must dispose back to the main menu.
        // Verify a few seconds later; if the exit chain dropped a message,
        // the backend re-triggers the exit (bounded retries, all logged).
        attempt = attempt || 0;
        setTimeout(function () {
            backend("bbseedCheckExit", {}, function (res) {
                if (res && res.ok) return;
                try { backend("bbseedLog", {message:"exit check: world still active, heal attempt " + (attempt + 1)}); } catch (e) {}
                if (attempt < 4) scheduleExitCheck(attempt + 1);
            });
        }, 4000);
    }

    MainMenuModule.prototype.bbseedCollectionStarted = function (data) {
        clearStartWatchdog();
        build();
        document.getElementById("bbseed-overlay").classList.remove("bbseed-hidden");
        document.getElementById("bbseed-stop").classList.remove("bbseed-hidden");
        showCollectionRunning({origin:data.origin,total:data.total,done:0,saved:lastStatus ? lastStatus.total : 0, backfill:collectionIsBackfill});
        collectionStartTime = Date.now();
        startRunClock();
        setText("bbseed-progress", tr("starting", {total:data.total}));
    };
    MainMenuModule.prototype.bbseedCollectionProgress = function (data) {
        build();
        document.getElementById("bbseed-overlay").classList.remove("bbseed-hidden");
        showCollectionRunning(data);
        if (!runTimer) {
            if (!collectionStartTime) collectionStartTime = Date.now();
            startRunClock();
        }
        setText("bbseed-progress", tr("progress", {done:data.done,total:data.total,saved:data.saved}));
    };
    MainMenuModule.prototype.bbseedCollectionFinished = function (data) {
        stopRunClock();
        build();
        var finishedDone = Math.max(0, parseInt(data.done, 10) || 0);
        if (finishedDone > 0 && collectionStartTime) {
            lastRateMsPerSeed = (Date.now() - collectionStartTime) / finishedDone;
            setText("bbseed-lastrate-value", tr("runRate", {rate:formatRate(lastRateMsPerSeed)}));
            setText("bbseed-lastelapsed-value", formatElapsedShort(Date.now() - collectionStartTime));
        }
        if (backfillQueue.length) {
            backfillQueue.shift();
            if (backfillQueue.length) { runNextBackfill(); return; }
        }
        // v1.78: a south-line switch that triggered this backfill applies
        // only when the queue ran to completion (not stopped mid-way).
        if (pendingSouthLine !== null) {
            if (!data.stopped) { southLine = pendingSouthLine; rebuildSouthLatFilters(); rebuildPortNatureFilters(); }
            pendingSouthLine = null;
        }
        document.getElementById("bbseed-overlay").classList.remove("bbseed-hidden");
        document.getElementById("bbseed-stop").classList.add("bbseed-hidden");
        hideCollectionDialog();
        setText("bbseed-progress", tr(data.stopped ? "stopped" : "finished", {done:data.done,saved:data.saved}));
        refreshStatus();
        search(false);
        scheduleExitCheck();
        if (autoActive) autoWait();
        if (data.backfill) {
            collectionIsBackfill = false;
            var missed = Math.max(0, parseInt(data.missed, 10) || 0);
            var bfTitle = data.stopped ? tr("backfillStoppedTitle") : tr("backfillDoneTitle");
            var bfText = data.stopped ? tr("backfillStoppedText", {done:data.done}) : tr("backfillDoneText", {done:data.done});
            if (missed > 0) bfText += tr("backfillSkipped", {count:missed});
            showDialog("<h2>" + esc(bfTitle) + "</h2><p>" + esc(bfText) + "</p>" +
                "<div class='dialog-actions'><button type='button' id='bbseed-backfill-ok' class='dialog-primary'>" + esc(tr("noticeOK")) + "</button></div>");
            document.getElementById("bbseed-backfill-ok").onclick = function () { hideDialog(); };
        }
    };
    MainMenuModule.prototype.bbseedCollectionFailed = function (data) { if (autoActive) { autoLog("job failed: " + (data && data.error)); autoActive = false; } stopRunClock(); clearStartWatchdog(); backfillQueue = []; build(); showCollectionFailure(data.error); };

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", build); else build();
}());
