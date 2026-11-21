// ============================================================================
// BB Seed Tool - heavily reworked community edition.
//
// ORIGIN: this mod is built on top of an earlier Battle Brothers seed
// search mod. The original author of that base mod is unknown to the
// current maintainer - if that is you and you have any concerns, please
// get in touch and state your purpose: QQ 76345492 (walter).
//
// AUTHORSHIP: starting from v1.32 the codebase was massively restructured
// and extended with many new features by walter (QQ 76345492). The current
// version differs substantially from the original base mod.
// Contact: QQ 76345492 (walter) - please state your purpose.
// ============================================================================
// BB Seed Tool 1.1.22 - pure Battle Brothers mod edition.
// Requires mod_hooks. Contains no executable code outside the game.
// 1.1.22 fix: port analysis (ports/south-north/arena) now runs AFTER the world
// is fully built exactly like vanilla startNewCampaign (Assets.init ->
// createFactions -> buildRoadAmbushSpots) for EVERY origin, and the global
// building counters are reset before each map. Previously the analysis ran
// right after Worldmap.fill() on a half-built world and faction creation was
// skipped for non-deserter origins, so arena/north-south flags did not match
// what a real new campaign produces for the same seed.
// 1.1.23 perf: cheaper per-seed loop. World generation itself is untouched so
// results stay identical; only redundant script work was removed:
//  - one getTalents() call per brother instead of eight
//  - UI progress notification every LogEvery seeds instead of every seed
//  - removed the duplicate roster cleanup at the end of each step
//  - expected brother count and seed charset length hoisted out of the loop
//  - fast path in the string sanitizer for strings without special chars
// 1.1.40 feature: detail star filters (min melee attack/defense stars),
// per-record batch id and max brother talent score, batch highlight data,
// mutually exclusive result sorting (talent/max/batch, asc/desc), and
// player-managed seed marks persisted in their own storage file.
// 1.1.41 feature: elapsed-time clock and average seeds-per-time rate in the
// collection-running dialog (pure UI, refreshed once per second).
// 1.1.42 feature: latest batch speed shown in the header after each run.
// 1.1.43 fix: map generation now replicates vanilla startNewCampaign
// EXACTLY in the critical window. A fresh worldmap generator instance is
// fetched via MapGen.get AFTER seedRandomString(seed) on every iteration -
// the same position vanilla uses - instead of reusing one instance captured
// at job start, and clearWorld() is no longer called on the instance that
// generates the map. Reusing the generator let internal/native state leak
// between iterations, so generated maps (and with them port/arena flags)
// silently diverged from what a real new campaign produces for the same
// seed. Brother data was unaffected because brothers are rolled after the
// second seedRandomString(seed), which resets the RNG stream either way.
// 1.1.44 cosmetic: the main-menu launcher button moved down by exactly one
// button height so it no longer sits flush against the top screen edge.
// 1.1.45 diag+fix: brothers match real campaigns, proving seedRandomString
// fully resets the RNG stream - so map divergence must come from non-RNG
// scene state. The FIRST seed of a job now runs with ZERO cleanup calls
// (pristine world, exact vanilla replica) to confirm whether the cleanup
// calls contaminate the scene. Also adds a last-batch elapsed-time display
// in the header next to the last-batch speed.
// 1.1.46 fix: the per-seed cleanup dropped the worldmap generator's
// clearWorld() call and added time-event/flag clears. WRONG - see 1.1.47.
// 1.1.47 fix (crash): v1.46 crashed the game hard (native, empty script
// stack) while building roads for the SECOND seed of a job. clearWorld() is
// a NATIVE engine function that resets native tile/map data; without it the
// previous map's native data corrupts the next generation. It is restored
// exactly as v1.45 had it (called on a THROWAWAY generator instance only,
// never on the instance that generates the map). Time.clearEvents() was
// also removed again: calling it from inside a scheduled time event (every
// seed step runs as one) risks native use-after-free, and vanilla only ever
// calls it while destroying a campaign. The building-counter resets before
// real campaigns and at job finish (added in 1.1.46) are kept.
// 1.1.48 feature: the "north port" flag is now GEOGRAPHIC instead of
// class-based. Players mean "a port in the upper half of the map", but the
// old check counted every non-city-state port as northern - including
// towns on the southern desert fringe. Each record now stores three extra
// port bits: has-a-port-north-of 50% / 65% / 80% of the map height
// (BB's Y axis grows northward: desert music kicks in below 20%, the
// snowline sits at 90%). A new UI selector ("north port line" 50/65/80,
// default 80) picks which line the south+north filter and the table column
// use. The south-port flag is unchanged (city-states only). Storage magic
// bumped to BBSEEDDB3: old shards used the class-based semantics and are
// skipped, so regenerate the library.
// 1.1.49 feature: talent-only collection mode, map backfill, talent-only
// cleanup, and a ranged-attack 3-star detail filter.
//  - Talent-only mode skips map generation entirely: brothers are rolled
//    after a bare seedRandomString(seed) + Assets.setCampaignSettings(),
//    which fully resets the RNG stream, so brother data is byte-identical
//    to a full map run while each seed costs ~0.1s instead of ~5s. Such
//    records store ports=0 / portFlags=0 (Known bit NOT set) and show as
//    "not recorded" for every port column and filter. Deserters are
//    rejected in talent-only mode (their brothers spawn in onSpawnPlayer,
//    which needs the map). The chosen mode persists in the settings file
//    (magic bumped to BBSEEDSET2; BBSEEDSET1 files still load).
//  - Map backfill re-runs FULL generation for a caller-supplied seed list
//    and rewrites the port data of the EXISTING records in place (batch,
//    brothers and marks untouched), so talent-only seeds can be upgraded
//    later without losing their place in the library.
//  - Talent-only cleanup deletes every unmarked record that has no map
//    data, after a precheck reports how many of them carry a max talent
//    score >= 90 so the UI can warn before anything is deleted.
//  - The detail filter row gains an independent "ranged attack 3 stars"
//    toggle (srsk >= 3), matching the existing melee star toggles.
// 1.1.50 fix: talent-only mode rolled zero brothers - every seed failed
//  with "the index '0' does not exist". Root cause: vanilla
//  Assets.setCampaignSettings() runs buildDescription(true) on each
//  brother's background, which reads World.EntityManager.getSettlements()
//  unguarded and crashes when no map exists. Talent mode now calls the
//  map-free BBSeedTool_SetupTalentCampaign() instead; RNG order and all
//  recorded data are unchanged. Stage-tagged errors (talent_spawn /
//  talent_postspawn) make any future failure locatable from the log.

// 1.1.51 fix: the generic dialog layer (backfill / cleanup) used the CSS
//  `inset` shorthand and translateY() centering, which the game UI engine
//  does not support - the layer collapsed to zero size and the dialog was
//  pushed off the left edge, leaving only its right-aligned button visible.
//  It now mirrors the collection dialog (explicit edges + negative margins).
//  The talent-cleanup backend now refuses to run while a collection or
//  backfill job is active, closing a shard-file race.

// 1.1.52 fix: talent-only mode STILL produced zero seeds after 1.1.50 -
//  the stage-tagged log (talent_spawn) proved the crash is inside
//  onSpawnAssets, not the post-spawn loop: setStartValuesEx() itself calls
//  buildDescription() twice while rolling a brother, mid RNG-stream.
//  character_background.buildDescription is now hooked: without a map it
//  burns the exact same number of Math.rand draws as vanilla (one dummy
//  draw per town pick) so rolled brothers stay identical to a real
//  campaign of the same seed; with a map the original runs untouched.
//  The panel header now shows the running version under the title.

// 1.1.53 fix: the first "use this seed" click right after a collection run
//  failed until the game was restarted. Two compounding causes addressed:
//  openNewCampaignMenu() had no retry (unlike backend()) while the main
//  menu is still being rebuilt after the throwaway world is disposed - it
//  now retries for ~4s and logs persistent failures to log.html via the new
//  bbseedLog backend; and vanilla exitGame() could autosave on exit
//  (Ironman on + last seed's brothers still in the roster), which risks an
//  exception stalling the menu return - the roster is now cleared and
//  Ironman forced off before disposing the batch world.

// 1.1.54 fix+feature: backfill runs never started after v1.53 in some
//  sessions - the click produced zero log lines, so the failure sits
//  somewhere between the JS confirm button and BBSeedTool_Run. Both arm
//  entry points (bbseedArmCollection / bbseedArmBackfill) now log their
//  accept/reject decision (ARM / ARM_BACKFILL lines), and BBSeedTool_Run
//  no longer bails silently when the scenario cannot be resolved: it logs
//  RUN_ABORT, notifies bbseedCollectionFailed and disposes the half-entered
//  world state so the player lands back at the main menu instead of a black
//  screen. The JS side adds a 5s start watchdog (disarm + error dialog when
//  no bbseedCollectionStarted arrives) and a dedicated backfill progress /
//  result dialog (eta instead of rate, "skipped N" reporting via the new
//  missed field on bbseedCollectionFinished).

// 1.1.55 fix (crash): the v1.54 watchdog was destructive - it auto-disarmed
//  5s after the start click even when the world entry was legitimately
//  still in progress (log proof: a ~5s main-thread block, then the watchdog
//  fired). The arriving startNewCampaign then ran as a REAL campaign, the
//  UI became clickable again, and a second start click collided with the
//  half-entered world: world_state.onMouseInput -> updateCursorAndTooltip
//  dereferenced the never-created player entity and the game hard-crashed
//  (native critical exception, world_state.nut:2824). Changes:
//  - world_state.onMouseInput now refuses input while this.m.Player == null
//    (half-entered world), turning that whole crash class into a no-op;
//  - the startNewCampaign hook logs START|pending=0/1 at entry so the log
//    always shows whether a world entry completed and which branch it took;
//  - JS: the watchdog is now report-only (30s, never disarms), a start is
//    in-flight guarded against double clicks, and the stop button while the
//    run has not started yet performs an explicit disarm + UI reset.

// 1.1.56 fix: the v1.55 mouse guard swallowed ALL of onMouseInput while
//  there is no player party - including Cursor.setPosition, so the native
//  cursor froze on screen while the real mouse moved invisibly and clicks
//  appeared to miss. The guard now keeps vanilla's cursor tracking (and the
//  loading-screen early-out) and swallows only the world interaction that
//  would dereference the missing player entity.

// 1.1.57 fix+diag: a completed backfill sometimes left the game stuck on
//  the world map - the vanilla exit chain (exitGame -> loading screen ->
//  AboutToFinish -> menu) dropped a message and the world state was never
//  disposed, so every later start silently died (the menu module was not
//  reachable) until a restart. The exit chain is now logged end to end
//  (EXIT_BEGIN / WORLD_DISPOSED / MENU_MODULE_READY), and a new
//  bbseedCheckExit backend lets the JS side verify a few seconds after each
//  job that the world was actually disposed; if not, it re-triggers the
//  exit (bounded retries via repeated checks). JS side: the backfill
//  progress dialog now opens IMMEDIATELY when a backfill starts (previously
//  only when the world entry finished, so single-seed backfills showed no
//  feedback at all), and the slow-entry watchdog warning moved to a red
//  one-line hint at the bottom of the panel that hides itself once the
//  state it warns about is over.

// 1.1.58 fix: the v1.57 exit self-heal itself crashed - LoadingScreen is
//  not reachable from outside the world state instance ("the index
//  'LoadingScreen' does not exist"), so a genuinely stalled exit stayed
//  stalled and the next world entry blocked the main thread for 30+s on
//  top of the undisposed world. The heal now re-calls vanilla exitGame()
//  (idempotent: roster already cleared, Ironman already off) and, on
//  repeated failure, escalates to delivering AboutToFinish directly to the
//  sibling states - exactly what the loading screen's shown callback does
//  once it fires. loading_screen_onScreenShown is now logged
//  (LOADING_SHOWN|exit=0/1) so the stall point is visible in log.html.

// 1.1.59 feature: the detail filter gains an independent "no negative
//  traits" switch. With any star switch active, a seed matches only when a
//  brother who passes those star thresholds is also clean. With no star
//  switch active, the switch checks the seed's highest-scoring brother(s)
//  instead, matching the UI wording. The cleanup panel also gains a red
//  workflow reminder.

// 1.1.60 UI: generation speed is displayed as seeds per second instead of
//  seconds per seed. The numeric value keeps decimal precision where useful,
//  which is much more readable for fast talent-only batches.

// 1.1.61 UI+docs: the Chinese "north port line" label is renamed to
// "north port judgement line", and origin/authorship/contact notes were
// added to the README and to the source file headers for traceability.

// 1.1.62 feature: the legacy Search button (redundant since every filter
// auto-queries) is replaced by a red "wipe library" button with a 10s
// countdown dialog; wiping truncates all shard files, clears marks, and
// resets batch numbering. Opening the panel now auto-loads the list.

// 1.1.63 feature: export/import of marked seeds. Export packs every seed
// marked Yes (full brother data, map flags when present, NO batch id) into
// BBSeedToolExport#<stamp>.sav in the savegames folder; the file is meant
// to be shared between players. Import scans for such files, stores the
// records as the newest batch, marks them all Yes, and skips duplicates.
// The export format is versioned (BBSEEDEXP1) and only ever extended at
// the end, so newer mod versions keep reading older export files. Also:
// the results area gains a green hint line (aligned with the max-score
// column) that is shown only while "no negative traits" is the sole active
// detail condition.

// 1.1.64 feature: the include-trait quick filter becomes a multi-select.
// "Any" is mutually exclusive with the four trait buttons (Drunkard, Huge,
// Sure Footed, Paranoid); at most two traits can be active at once and a
// record must contain ALL selected traits (AND semantics, comma-separated
// in the filter). Trait ids are resolved at runtime from the client's
// localized trait names with fixed-id fallbacks. The area is restyled as a
// framed box: tall Any button, a 2x2 trait grid, and a red hint line.

// 1.1.65 fix: BB's Squirrel provides split() only as a global function, not
// as a string method; quickTrait.split(",") threw inside every record match,
// aborting each shard scan and emptying results for ANY trait selection.
// Switched to split(quickTrait, ",") and added a boot-time self-test
// (MULTI_TRAIT_SELFTEST) proving the AND loop works in the live client.

// 1.1.66 fix: the multi-trait AND now applies at brother granularity via
// BBSeedTool_RecordHasAllTraits - all selected traits must be present on ONE
// and the same brother. Previously the per-trait "any brother" check passed
// seeds whose traits were spread across different brothers. Single-trait
// behaviour is unchanged. MULTI_TRAIT_SELFTEST now covers same-bro pass,
// spread-across-bros reject, missing-trait reject, and single equivalence.

// 1.1.67 change: conditions from the Detail box (star switches, no-negative)
// and the include-trait multi-select now concentrate on ONE brother - the
// quick-trait check moved into BBSeedTool_BroMatches, and the best-score
// "no negative" fallback only applies when neither stars nor traits are
// selected. Self-test gains star_split_reject / star_same_pass cases.

// 1.1.68 change: per-collection seed cap raised from 100k to 300k (talent
// mode scales linearly - 100k in ~2.5h measured, so 300k is an overnight
// run); the running dialog gains an ETA line (hidden for backfill, whose
// rate line already is the ETA).

// 1.1.69 change: filter searches now show "Scanning N seeds..." with the
// library size and yield one frame before the backend scan, so large
// libraries no longer look frozen; stale callbacks from superseded searches
// are dropped via a sequence number.

// 1.1.70 change: text-only update. The export/import hint is now red and
// urges exporting keepers then wiping once the library exceeds 100k seeds;
// the wipe button reads "clear library (avoid filter lag)".

// 1.1.71 feature: export dialog now offers "new file" vs "overwrite an
// existing export". Overwriting passes the chosen file name down to
// BBSeedTool_ExportMarked(_target); createStorage() with an existing export
// name rewrites that file in place (the same proven overwrite path used by
// WriteShard and WipeAll), so no deletion API is needed. The file content
// still carries a fresh stamp. Both the export and import file pickers are
// rendered inside a fixed-height scrollable container, and the full-mode
// hint notes that the deserter origin requires it.

// 1.1.72 change: "paranoid" (偏执) removed from BBSeedTool_NegativeTraits.
// Its -30 initiative buys +5 melee/+5 ranged defense, so for defense
// builds it is a core pick, not a drawback. With stars + "no negative"
// active, brothers carrying paranoid are now kept.

// 1.1.73 feature: the Detail box becomes the "Star" (星位) module - 10 star
// toggles in a 2x5 grid (3-star row over 2-star row; columns melee attack,
// melee defense, fatigue, initiative, ranged attack) plus a vertical
// no-negative switch. At most 3 star conditions at once (UI-enforced); a
// selected 3-star overrides the same stat's 2-star. sftg/sini reuse the
// sfat/sinit values already stored in every record, so the save format is
// unchanged and old libraries keep working. The "any trait" button now
// shows the standard gold selected state.

// 1.1.74 change: sure-footed (稳步) and paranoid (偏执/多疑) trait tags in
// the brother detail view now use the same prime style as huge/drunkard
// (filled rounded tag with a star). The paranoid quick-filter button reads
// 偏执/多疑 since translations differ between versions; the four trait
// buttons are widened equally to fit. Stored trait names are untouched -
// a seed saved as 多疑 still displays as 多疑.

::BBSeedTool <- {
    Version = 1.79,
    Prefix = "BBSeedToolData#",
    ExportPrefix = "BBSeedToolExport#",
    ExportMagic = "BBSEEDEXP2",
    SettingsFile = "BBSeedToolSettings",
    LanguageFile = "BBSeedToolLanguage",
    PortStatsFile = "BBSeedToolPortStats",
    MarksFile = "BBSeedToolMarks",
    Magic = "BBSEEDDB4",
    LegacyMagic = "BBSEEDDB2",
    LegacyMagic3 = "BBSEEDDB3",
    SettingsMagic = "BBSEEDSET2",
    LegacySettingsMagic = "BBSEEDSET1",
    LanguageMagic = "BBSEEDLANG1",
    PortStatsMagic = "BBSEEDPORT3",
    MarksMagic = "BBSEEDMARK1",
    PortFlagKnown = 1,
    PortFlagNorth = 2,
    PortFlagSouth = 4,
    PortFlagArena = 8,
    PortFlagNorth50 = 16,
    PortFlagNorth65 = 32,
    PortFlagNorth80 = 64,
    NorthLineDefault = 80,
    PortFlagSouthKnown = 128,
    PortFlagSouth20 = 256,
    PortFlagSouth35 = 512,
    PortFlagSouth50 = 1024,
    SouthLineDefault = 0,
    BatchSize = 50,
    ShardSize = 1000,
    MaxIters = 100,
    Language = "zh",
    LogEvery = 10,
    UIBackend = null,
    CatalogLoaded = false,
    TotalSeeds = 0,
    TotalBatches = 0,
    NextBatchID = 1,
    PortStats = null,
    Marks = null,
    TalentDistributions = null,
    TalentDistributionTotal = -1,
    ActiveOrigin = "",
    Buffer = [],
    CurrentShard = [],
    CurrentShardID = 0,
    CurrentShardSaved = false,
    Job = null,
    PendingCollection = false,
    PendingOrigin = "",
    PendingMode = "full",
    PendingBackfill = null,
    CollectionMode = "full",
    ReturningWorldState = null,
    ExitHealAttempts = 0,
    SupportedOrigins = [
        "scenario.pale_sovereign",
        "scenario.early_access",
        "scenario.southern_quickstart",
        "scenario.trader",
        "scenario.militia",
        "scenario.rangers",
        "scenario.paladins",
        "scenario.deserters",
        "scenario.raiders",
        "scenario.anatomists",
        "scenario.cultists",
        "scenario.manhunters",
        "scenario.beast_hunters",
        "scenario.gladiators",
        "scenario.lone_wolf"
    ]
};

// ============================================================================
// v1.79 fast path
// ----------------------------------------------------------------------------
// 1. Talent-only collection no longer rolls ONE seed per rendered frame. Each
//    scheduled step keeps rolling seeds until a small time budget is used up,
//    so the speed is bound by the CPU instead of the frame rate.
// 2. Optional prefilter (::BBSeedTool.Prefilter). When set, a talent-only job
//    stores ONLY the seeds where at least `minBros` starting brothers reach
//    the projected level-11 thresholds:
//        melee attack  = current + 20 + 5 per talent star   >= atk
//        melee defense = current + 20 + 5 per talent star   >= def
//        fatigue       = current + 30 + 5 per talent star   >= fat
//    Everything else is dropped on the spot (no disk writes, no library
//    bloat). Each stored seed is also written to log.html as a HIT line.
// 3. With a prefilter the roll of a seed is abandoned as soon as it can no
//    longer satisfy it (early abort), skipping the remaining brothers.
// The brothers of a kept seed are produced by exactly the same game code as
// before, so they still match a real campaign started with that seed.
// ============================================================================
::BBSeedTool.Fast <- {
    Enabled = true,          // several seeds per step (talent-only mode)
    BudgetSec = 0.1,         // time budget of one step, in seconds
    SkipAssetsInit = false,  // experimental: skip World.Assets.init() after the first seed
    SkipPostSpawn = true,    // skip the vanilla post-spawn re-roll of level-up values (never recorded)
    EarlyAbort = true,       // only used together with a prefilter
    AtkMargin = 10,          // safety margin of the early melee-attack probe
    NoUpdate = true,         // no property recomputation while the origin spawns its brothers
    NoEquip = false,         // experimental: starting gear is created but not put on
    Profile = false,         // accumulate per-phase timings and log them at the end
    LogAll = false           // log a SIG line for every stored record (regression tests)
};
::BBSeedTool.Prefilter <- null;      // see BBSeedTool_NormalizePrefilter below
::BBSeedTool.Abort <- null;          // live early-abort state of the seed being rolled
::BBSeedTool.AutoSeedState <- null;  // fixed seed-generator state (regression tests)
::BBSeedTool.Prof <- null;
::BBSeedTool.SuppressUpdate <- false; // live switches, only true inside a fast talent roll
::BBSeedTool.SuppressEquip <- false;
::BBSeedTool.AutoMark <- false;       // unattended backfill: mark every processed seed
::BBSeedTool.ScratchProps <- null;    // throwaway property set for light refreshes

::BBSeedTool_ResetProf <- function()
{
    ::BBSeedTool.Prof = { clean = 0.0, init = 0.0, spawn = 0.0, collect = 0.0, commit = 0.0, steps = 0, seeds = 0, aborted = 0, precheck = 0, kept = 0 };
};

// Seeds come from a small private LCG instead of the game RNG. The game RNG
// is reseeded for every campaign roll, so drawing the next seed from it made
// the whole sequence depend on how many draws the previous roll consumed -
// which the early abort changes. A private generator keeps runs reproducible.
::BBSeedTool_NextSeed <- function(_job)
{
    if (_job.SeedList != null) return _job.SeedList[_job.Index];
    local st = _job.SeedState;
    local seed = "";
    for (local i = 0; i < 10; i++)
    {
        st = st * 1103515245 + 12345;
        seed += _job.Chars[((st >> 16) & 0x7FFF) % 36];
    }
    _job.SeedState = st;
    return seed;
};

// ---------------------------------------------------------------------------
// Prefilter. A prefilter is a list of groups; every group asks for `need`
// brothers that reach its projected level-11 thresholds, and one brother can
// serve only one group:
//   { groups = [ { need = 2, atk = 90, def = 30, fat = 126 },
//                { need = 1, atk = 80 } ],
//     full   = [ { need = 2, atk = 90, def = 30, fat = 126 },
//                { need = 1, atk = 80, res = 85, fat = 130 } ] }
// `groups` decides which seeds are stored. The optional `full` list is a
// stricter wish: stored seeds that also satisfy it are flagged full=1.
// Projection per attribute: current value + 10 level-ups at the average roll
// (melee attack / melee defense 2 per level, fatigue / resolve / hitpoints 3
// per level) + 0.5 per level and talent star, i.e. +5 per star.
// The short form { minBros, atk, def, fat } is still accepted.
// ---------------------------------------------------------------------------
::BBSeedTool_NormalizePrefilter <- function(_pf)
{
    if (_pf == null) return null;
    if (!("groups" in _pf))
    {
        local g = { need = _pf.minBros };
        foreach (key in [ "atk", "def", "fat", "res", "hp" ])
            if (key in _pf) g[key] <- _pf[key];
        _pf = { groups = [ g ] };
    }
    if (!("full" in _pf)) _pf.full <- null;
    // Optional alternatives: a seed is stored if it meets `groups` or `alt`, and flagged
    // full=1 if it meets `full` or `fullAlt`. With alternatives the early abort may only
    // rely on what all of them have in common: pass that as `abortGroups`.
    if (!("alt" in _pf)) _pf.alt <- null;
    if (!("fullAlt" in _pf)) _pf.fullAlt <- null;
    local abortGroups = ("abortGroups" in _pf) ? _pf.abortGroups : _pf.groups;
    // Early-abort table: for every melee-attack threshold t, how many brothers
    // must reach at least t for the seed to stay possible.
    local list = [];
    foreach (g in abortGroups)
    {
        if (!("atk" in g)) continue;
        local known = false;
        foreach (e in list) if (e.atk == g.atk) known = true;
        if (!known) list.push({ atk = g.atk, need = 0 });
    }
    foreach (e in list)
        foreach (g in abortGroups)
            if ("atk" in g && g.atk >= e.atk) e.need += g.need;
    _pf.abortList <- list;
    return _pf;
};

::BBSeedTool_PrefilterText <- function(_groups)
{
    if (_groups == null) return "none";
    local out = "";
    foreach (g in _groups)
    {
        out += (out == "" ? "" : " + ") + g.need + "x(";
        local first = true;
        foreach (key in [ "atk", "def", "fat", "res", "hp" ])
        {
            if (!(key in g)) continue;
            out += (first ? "" : ",") + key + ">=" + g[key];
            first = false;
        }
        out += ")";
    }
    return out;
};

::BBSeedTool_BroMeets <- function(_bro, _g)
{
    if ("atk" in _g && _bro.msk + 20 + _bro.smsk * 5 < _g.atk) return false;
    if ("def" in _g && _bro.mdf + 20 + _bro.smdf * 5 < _g.def) return false;
    if ("fat" in _g && _bro.fat + 30 + _bro.sfat * 5 < _g.fat) return false;
    if ("res" in _g && _bro.res + 30 + _bro.sres * 5 < _g.res) return false;
    if ("hp" in _g && _bro.hp + 30 + _bro.shp * 5 < _g.hp) return false;
    return true;
};

::BBSeedTool_AssignSlots <- function(_bros, _slots, _used, _index)
{
    if (_index >= _slots.len()) return true;
    foreach (i, bro in _bros)
    {
        if (_used[i] || !::BBSeedTool_BroMeets(bro, _slots[_index])) continue;
        _used[i] = true;
        if (::BBSeedTool_AssignSlots(_bros, _slots, _used, _index + 1)) return true;
        _used[i] = false;
    }
    return false;
};

// Can every group be served, each by different brothers?
::BBSeedTool_GroupsMatch <- function(_bros, _groups)
{
    local slots = [];
    foreach (g in _groups)
        for (local i = 0; i < g.need; i++) slots.push(g);
    if (slots.len() > _bros.len()) return false;
    return ::BBSeedTool_AssignSlots(_bros, slots, array(_bros.len(), false), 0);
};

::BBSeedTool_BroSig <- function(_bro)
{
    return _bro.bg + ":" + _bro.hp + "/" + _bro.fat + "/" + _bro.res + "/" + _bro.init + "/" + _bro.msk + "/" + _bro.rsk + "/" + _bro.mdf + "/" + _bro.rdf
        + ":" + _bro.shp + _bro.sfat + _bro.sres + _bro.sinit + _bro.smsk + _bro.srsk + _bro.smdf + _bro.srdf + ":" + _bro.traits;
};

::BBSeedTool_RecordSig <- function(_record)
{
    local out = "";
    foreach (bro in _record.bros) out += (out == "" ? "" : ";") + ::BBSeedTool_BroSig(bro);
    return out;
};

::BBSeedTool_HitText <- function(_record)
{
    local out = "";
    foreach (bro in _record.bros)
    {
        out += (out == "" ? "" : ";") + bro.name + "," + bro.bg
            + ",atk" + (bro.msk + 20 + bro.smsk * 5) + "(" + bro.msk + "*" + bro.smsk + ")"
            + ",def" + (bro.mdf + 20 + bro.smdf * 5) + "(" + bro.mdf + "*" + bro.smdf + ")"
            + ",fat" + (bro.fat + 30 + bro.sfat * 5) + "(" + bro.fat + "*" + bro.sfat + ")"
            + ",res" + (bro.res + 30 + bro.sres * 5) + "(" + bro.res + "*" + bro.sres + ")"
            + ",[" + bro.traits + "]";
    }
    return out;
};

// One talent-only seed. Returns the record to store, or null when the seed
// was dropped by the prefilter / early abort.
::BBSeedTool_TalentSeed <- function(_job, _seed)
{
    local fast = ::BBSeedTool.Fast;
    local prof = fast.Profile ? ::BBSeedTool.Prof : null;
    local t = 0.0;
    local n = 0.0;
    if (prof != null) t = ::Time.getExactTime();

    ::BBSeedTool_CleanupRoster(_job.Roster);
    _job.WorldState.m.CampaignSettings.Seed = _seed;
    if (prof != null) { n = ::Time.getExactTime(); prof.clean += n - t; t = n; }

    // v1.50: guard init - from the 2nd seed on it re-runs Origin.onInit(),
    // which is untested without a map. Its output (economy/stash) is
    // irrelevant to the recorded brother data and the RNG stream is fully
    // reseeded right after, so a failure here must not abort the seed.
    if (!fast.SkipAssetsInit || _job.Index == 0)
    {
        try { ::World.Assets.init(); }
        catch (e) { ::logWarning("[BBSEED] TALENT_ASSETS_INIT|" + ::BBSeedTool_Safe(e)); }
    }
    if (prof != null) { n = ::Time.getExactTime(); prof.init += n - t; t = n; }

    ::Math.seedRandomString(_seed);
    local pf = ::BBSeedTool.Prefilter;
    if (pf != null && fast.EarlyAbort)
    {
        local list = [];
        foreach (e in pf.abortList) list.push({ atk = e.atk - fast.AtkMargin, need = e.need, count = 0 });
        ::BBSeedTool.Abort = {
            seen = 0, aborted = false, expected = _job.Expected, list = list,
            idx = ::Const.Attributes.MeleeSkill
        };
    }
    else ::BBSeedTool.Abort = null;
    // v1.50: vanilla setCampaignSettings() crashes mapless inside
    // buildDescription(); use the map-free equivalent instead.
    ::BBSeedTool.SuppressUpdate = fast.Enabled && fast.NoUpdate;
    ::BBSeedTool.SuppressEquip = fast.Enabled && fast.NoEquip;
    local complete = ::BBSeedTool_SetupTalentCampaign(_job.WorldState.m.CampaignSettings, fast.SkipPostSpawn && fast.Enabled);
    ::BBSeedTool.SuppressUpdate = false;
    ::BBSeedTool.SuppressEquip = false;
    ::BBSeedTool.Abort = null;
    if (prof != null) { n = ::Time.getExactTime(); prof.spawn += n - t; t = n; }
    if (!complete)
    {
        if (prof != null) prof.aborted++;
        return null;
    }

    local brothers = _job.Roster.getAll();
    if (brothers.len() != _job.Expected)
        throw "brother_count_mismatch|origin=" + _job.Origin + "|expected=" + _job.Expected + "|actual=" + brothers.len();

    if (pf != null)
    {
        // Cheap probe on the live brothers before the (slower) full collect:
        // melee skill is not touched by starting gear, the margin covers the rest.
        local possible = true;
        local idx = ::Const.Attributes.MeleeSkill;
        foreach (e in pf.abortList)
        {
            local maybe = 0;
            foreach (bro in brothers)
            {
                local stars = 0;
                try { stars = bro.getTalents()[idx]; } catch (ex) {}
                if (bro.getCurrentProperties().getMeleeSkill() + 20 + stars * 5 >= e.atk - fast.AtkMargin) maybe++;
            }
            if (maybe < e.need) { possible = false; break; }
        }
        if (!possible)
        {
            if (prof != null) { n = ::Time.getExactTime(); prof.collect += n - t; prof.precheck++; }
            return null;
        }
    }

    local record = { seed = _seed, ports = 0, portFlags = 0, settlements = 0, bros = [] };
    foreach (i, bro in brothers) record.bros.push(::BBSeedTool_CollectBro(i + 1, bro));
    if (prof != null) { n = ::Time.getExactTime(); prof.collect += n - t; t = n; }
    if (pf != null)
    {
        if (!::BBSeedTool_GroupsMatch(record.bros, pf.groups) && !(pf.alt != null && ::BBSeedTool_GroupsMatch(record.bros, pf.alt))) return null;
        local full = pf.full == null || ::BBSeedTool_GroupsMatch(record.bros, pf.full) || (pf.fullAlt != null && ::BBSeedTool_GroupsMatch(record.bros, pf.fullAlt));
        _job.Hits++;
        if (full) _job.FullHits++;
        ::logWarning("[BBSEED] HIT|seed=" + _seed + "|full=" + (full ? "1" : "0") + "|bros=" + ::BBSeedTool_HitText(record));
    }
    if (fast.LogAll) ::logWarning("[BBSEED] SIG|seed=" + _seed + "|" + ::BBSeedTool_RecordSig(record));
    if (prof != null) prof.kept++;
    return record;
};

// All stored seeds of one origin (optionally only those without map data).
::BBSeedTool_ListSeeds <- function(_origin, _unmappedOnly, _pf = null)
{
    local seeds = [];
    local prefix = ::BBSeedTool.Prefix + ::BBSeedTool_OriginCode(_origin) + "#";
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local stored = ::BBSeedTool_ReadRecord(input, _origin, databaseVersion);
                if (_unmappedOnly && (stored.portFlags & ::BBSeedTool.PortFlagKnown) != 0) continue;
                if (_pf != null && !::BBSeedTool_GroupsMatch(stored.bros, _pf.groups) && !(_pf.alt != null && ::BBSeedTool_GroupsMatch(stored.bros, _pf.alt))) continue;
                seeds.push(stored.seed);
            }
            input.endRead();
        }
        catch (e) { ::logWarning("[BBSEED] LIST_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e)); }
    }
    return seeds;
};

// Optional unattended driver. If another script defines ::BBSeedAuto =
// { Jobs = [ ... ] }, the UI runs those jobs one after another as soon as the
// main menu is ready. Without that table nothing changes for normal use.
//   { action = "collect", origin = "scenario.cultists", mode = "talent", count = 100000,
//     prefilter = { groups = [ { need = 2, atk = 90, def = 30, fat = 126 } ] } }
//   { action = "backfill", origin = "scenario.cultists", prefilter = {...}, mark = true }
//       // maps for the unmapped stored seeds (only those passing the prefilter, if one is given)
//   parallel = true on a collect job: several game processes may run the same plan side by side
//   { action = "quit" }
::BBSeedTool_AutoNext <- function(_data = null)
{
    local nonce = 0;
    try { nonce = ::BBSeedTool_Number(_data, "nonce", 0).tointeger(); } catch (e) {}
    local root = ::getroottable();
    if (!("BBSeedAuto" in root) || ::BBSeedAuto == null) return { action = "none" };
    local auto = ::BBSeedAuto;
    if (!("Index" in auto)) auto.Index <- 0;
    if (auto.Index >= auto.Jobs.len()) return { action = "none" };
    local job = auto.Jobs[auto.Index];
    auto.Index++;
    ::logWarning("[BBSEED] AUTO|index=" + auto.Index + "|of=" + auto.Jobs.len() + "|action=" + job.action);
    if (job.action == "quit") return { action = "quit" };
    if ("fast" in job)
        foreach (key, value in job.fast) ::BBSeedTool.Fast[key] = value;
    ::BBSeedTool.Prefilter = ("prefilter" in job) ? ::BBSeedTool_NormalizePrefilter(job.prefilter) : null;
    ::BBSeedTool.AutoSeedState = ("seedState" in job) ? job.seedState : null;
    ::BBSeedTool.AutoMark = ("mark" in job) && job.mark;
    if ("parallel" in job && job.parallel)
    {
        // Several game processes share one savegames folder: give this one
        // its own seed stream and its own shard numbers.
        ::BBSeedTool.AutoSeedState = nonce * 7919 + ::Time.getRealTime().tointeger();
        if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();
        ::BBSeedTool.NextBatchID = 100000 + (nonce < 0 ? -nonce : nonce) % 2000000000;
        ::logWarning("[BBSEED] AUTO_PARALLEL|nonce=" + nonce + "|shardBase=" + ::BBSeedTool.NextBatchID);
    }
    if (job.action == "collect")
    {
        ::BBSeedTool.MaxIters = job.count;
        return { action = "collect", origin = job.origin, mode = job.mode };
    }
    if (job.action == "backfill")
    {
        local seeds = ("seeds" in job) ? job.seeds : ::BBSeedTool_ListSeeds(job.origin, true, ::BBSeedTool.Prefilter);
        ::logWarning("[BBSEED] AUTO_BACKFILL|seeds=" + seeds.len());
        return { action = "backfill", origin = job.origin, seeds = seeds };
    }
    return { action = "none" };
};

::BBSeedTool_IsOriginTrait <- function(_id)
{
    local id = _id == null ? "" : ("" + _id).tolower();
    if (id.len() > 6 && id.slice(0, 6) == "trait.") id = id.slice(6);
    if (id == "player" || id == "player_character" || id == "cultist_fanatic"
        || id == "arena_fighter" || id == "glorious_resolve"
        || id == "glorious_endurance" || id == "glorious_quickness"
        || id == "old") return true;
    return id.len() >= 8 && id.slice(0, 8) == "oath_of_";
};

// Kept in sync with the negative-trait list used by the offline seed review
// scripts. The UI calls this simply "no negative traits".
// v1.72: "paranoid" removed - its -30 initiative is the price for
// +5 melee/+5 ranged defense, which makes it a CORE trait for defense
// builds, not a negative one.
::BBSeedTool_NegativeTraits <- {
    tiny = true, asthmatic = true, dastard = true, insecure = true,
    ailing = true, bleeder = true, clubfooted = true, clumsy = true,
    craven = true, fainthearted = true, fat = true, fragile = true,
    gluttonous = true, greedy = true, hesitant = true, irrational = true,
    night_blind = true, pessimist = true, short_sighted = true,
    superstitious = true, weasel = true, cocky = true, mad = true,
    dumb = true, disloyal = true, fear_beasts = true,
    fear_greenskins = true, fear_undead = true
};

::BBSeedTool_BroHasNegativeTrait <- function(_bro)
{
    local traits = "";
    try { traits = _bro.traits.tolower(); } catch (e) {}
    if (traits == "") return false;
    local storedTraits = "," + traits + ",";
    foreach (id, _enabled in ::BBSeedTool_NegativeTraits)
        if (storedTraits.find("," + id + ",") != null) return true;
    return false;
};

::BBSeedTool_GetTraitOptions <- function()
{
    local result = [];
    local seen = {};
    try
    {
        foreach (entry in ::Const.CharacterTraits)
        {
            if (entry == null || entry.len() < 2) continue;
            local id = ::BBSeedTool_Safe(entry[0]);
            if (id.len() > 6 && id.slice(0, 6) == "trait.") id = id.slice(6);
            if (id == "" || id in seen || ::BBSeedTool_IsOriginTrait(id)) continue;
            local name = id;
            try
            {
                local trait = ::new(entry[1]);
                name = ::BBSeedTool_Safe(trait.getName());
            }
            catch (e) {}
            seen[id] <- true;
            result.push({ id = id, name = name });
        }
    }
    catch (e) { ::logWarning("[BBSEED] TRAIT_OPTIONS_ERROR|" + ::BBSeedTool_Safe(e)); }
    result.sort(function(a, b) { return a.id <=> b.id; });
    ::logWarning("[BBSEED] TRAIT_OPTIONS|count=" + result.len());
    return result;
};

::BBSeedTool_BlocksWorldState <- function(_worldState)
{
    if (::BBSeedTool.Job != null && ::BBSeedTool.Job.WorldState == _worldState) return true;
    return ::BBSeedTool.ReturningWorldState != null && ::BBSeedTool.ReturningWorldState == _worldState;
};

::BBSeedTool_SaveLanguage <- function()
{
    local output = ::PersistenceManager.createStorage(::BBSeedTool.LanguageFile);
    output.beginWrite();
    output.writeString(::BBSeedTool.LanguageMagic);
    output.writeString(::BBSeedTool.Language);
    output.endWrite();
};

::BBSeedTool_LoadLanguage <- function()
{
    try
    {
        local exists = false;
        foreach (meta in ::PersistenceManager.queryStorages())
            if (meta.getFileName() == ::BBSeedTool.LanguageFile) { exists = true; break; }
        if (!exists) return;
        local input = ::PersistenceManager.loadStorage(::BBSeedTool.LanguageFile);
        input.beginRead();
        if (input.readString() == ::BBSeedTool.LanguageMagic)
        {
            local language = input.readString();
            if (language == "zh" || language == "en") ::BBSeedTool.Language = language;
        }
        input.endRead();
    }
    catch (e) { ::logWarning("[BBSEED] LANGUAGE_ERROR|" + e); }
};

// Player-managed seed marks. Stored as a set of "origin|seed" keys in their
// own tiny storage file so marks survive restarts independently of the
// seed database files (which players may delete between batches).
::BBSeedTool_MarkKey <- function(_origin, _seed)
{
    return _origin + "|" + _seed;
};

::BBSeedTool_LoadMarks <- function()
{
    ::BBSeedTool.Marks = {};
    try
    {
        local exists = false;
        foreach (meta in ::PersistenceManager.queryStorages())
            if (meta.getFileName() == ::BBSeedTool.MarksFile) { exists = true; break; }
        if (!exists) return;
        local input = ::PersistenceManager.loadStorage(::BBSeedTool.MarksFile);
        input.beginRead();
        if (input.readString() == ::BBSeedTool.MarksMagic)
        {
            local count = input.readU32();
            for (local i = 0; i < count; i++) ::BBSeedTool.Marks[input.readString()] <- true;
        }
        input.endRead();
    }
    catch (e) { ::logWarning("[BBSEED] MARKS_LOAD_ERROR|" + ::BBSeedTool_Safe(e)); }
};

::BBSeedTool_SaveMarks <- function()
{
    if (::BBSeedTool.Marks == null) return;
    try
    {
        local output = ::PersistenceManager.createStorage(::BBSeedTool.MarksFile);
        output.beginWrite();
        output.writeString(::BBSeedTool.MarksMagic);
        output.writeU32(::BBSeedTool.Marks.len());
        foreach (key, _value in ::BBSeedTool.Marks) output.writeString(key);
        output.endWrite();
    }
    catch (e) { ::logWarning("[BBSEED] MARKS_SAVE_ERROR|" + ::BBSeedTool_Safe(e)); }
};

::BBSeedTool_IsMarked <- function(_origin, _seed)
{
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    return ::BBSeedTool_MarkKey(_origin, _seed) in ::BBSeedTool.Marks;
};

::BBSeedTool_ToggleMark <- function(_origin, _seed)
{
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    local key = ::BBSeedTool_MarkKey(_origin, _seed);
    local marked = false;
    if (key in ::BBSeedTool.Marks) delete ::BBSeedTool.Marks[key];
    else { ::BBSeedTool.Marks[key] <- true; marked = true; }
    ::BBSeedTool_SaveMarks();
    return marked;
};

::BBSeedTool_SaveSettings <- function()
{
    local output = ::PersistenceManager.createStorage(::BBSeedTool.SettingsFile);
    output.beginWrite();
    output.writeString(::BBSeedTool.SettingsMagic);
    output.writeU32(::BBSeedTool.MaxIters);
    output.writeString(::BBSeedTool.CollectionMode);
    output.endWrite();
};

::BBSeedTool_LoadSettings <- function()
{
    try
    {
        local exists = false;
        foreach (meta in ::PersistenceManager.queryStorages())
            if (meta.getFileName() == ::BBSeedTool.SettingsFile) { exists = true; break; }
        if (!exists) return;
        local input = ::PersistenceManager.loadStorage(::BBSeedTool.SettingsFile);
        input.beginRead();
        local magic = input.readString();
        if (magic == ::BBSeedTool.SettingsMagic || magic == ::BBSeedTool.LegacySettingsMagic)
        {
            local n = input.readU32();
            if (n >= 1 && n <= 300000) ::BBSeedTool.MaxIters = n;
            if (magic == ::BBSeedTool.SettingsMagic)
            {
                local mode = input.readString();
                if (mode == "talent" || mode == "full") ::BBSeedTool.CollectionMode = mode;
            }
        }
        input.endRead();
    }
    catch (e) { ::logWarning("[BBSEED] SETTINGS_ERROR|" + e); }
};

::BBSeedTool_StartsWith <- function(_text, _prefix)
{
    return _text != null && _text.len() >= _prefix.len() && _text.slice(0, _prefix.len()) == _prefix;
};

::BBSeedTool_Safe <- function(_value)
{
    if (_value == null) return "";
    local s = "" + _value;
    if (s.find("|") == null && s.find("\n") == null && s.find("\r") == null) return s;
    local out = "";
    for (local i = 0; i < s.len(); i++)
    {
        local c = s.slice(i, i + 1);
        if (c == "|" || c == "\n" || c == "\r") out += "/";
        else out += c;
    }
    return out;
};

::BBSeedTool_OriginCode <- function(_origin)
{
    if (_origin == "scenario.pale_sovereign") return "palesovereign";
    if (_origin == "scenario.early_access") return "newcompany";
    if (_origin == "scenario.southern_quickstart") return "southern";
    if (_origin == "scenario.trader") return "trader";
    if (_origin == "scenario.militia") return "militia";
    if (_origin == "scenario.rangers") return "rangers";
    if (_origin == "scenario.paladins") return "paladins";
    if (_origin == "scenario.deserters") return "deserters";
    if (_origin == "scenario.raiders") return "raiders";
    if (_origin == "scenario.anatomists") return "anatomists";
    if (_origin == "scenario.cultists") return "cultists";
    if (_origin == "scenario.manhunters") return "manhunters";
    if (_origin == "scenario.beast_hunters") return "beasthunters";
    if (_origin == "scenario.gladiators") return "gladiators";
    if (_origin == "scenario.lone_wolf") return "lonewolf";
    return "unknown";
};

::BBSeedTool_ExpectedBrothers <- function(_origin)
{
    if (_origin == "scenario.pale_sovereign") return 3;
    if (_origin == "scenario.early_access") return 3;
    if (_origin == "scenario.southern_quickstart") return 3;
    if (_origin == "scenario.trader") return 2;
    if (_origin == "scenario.militia") return 12;
    if (_origin == "scenario.rangers") return 3;
    if (_origin == "scenario.paladins") return 2;
    if (_origin == "scenario.deserters") return 3;
    if (_origin == "scenario.raiders") return 4;
    if (_origin == "scenario.anatomists") return 3;
    if (_origin == "scenario.cultists") return 4;
    if (_origin == "scenario.manhunters") return 6;
    if (_origin == "scenario.beast_hunters") return 3;
    if (_origin == "scenario.gladiators") return 3;
    if (_origin == "scenario.lone_wolf") return 1;
    return 0;
};

::BBSeedTool_SpawnDeserters <- function(_job)
{
    // Deserters are the only vanilla origin whose three brothers are created
    // in onSpawnPlayer instead of onSpawnAssets. Run the original game method
    // so it consumes RNG exactly like an unmodded campaign. Its final delayed
    // callback only opens the intro event, which must not run for every seed.
    local oldScheduleEvent = ::Time.scheduleEvent;
    local spawnError = null;
    ::Time.scheduleEvent = function(_unit, _delay, _callback, _tag) { return null; };
    try { _job.Scenario.onSpawnPlayer(); }
    catch (e) { spawnError = e; }
    ::Time.scheduleEvent = oldScheduleEvent;
    if (spawnError != null) throw spawnError;
};

::BBSeedTool_AttrIdx <- function(_name)
{
    if (!(_name in ::Const.Attributes)) return null;
    return ::Const.Attributes[_name];
};

// Read one talent from an already-fetched talents array. Fetching the array
// once per brother instead of once per attribute saves seven getTalents()
// calls per brother on the collection hot path.
::BBSeedTool_TalentAt <- function(_talents, _attrName)
{
    if (_talents == null) return 0;
    local idx = ::BBSeedTool_AttrIdx(_attrName);
    if (idx == null || _talents.len() <= idx) return 0;
    return _talents[idx];
};

::BBSeedTool_Traits <- function(_bro)
{
    local out = "";
    local skills = null;
    try { skills = _bro.getSkills().m.Skills; } catch (e) {}
    if (skills == null) return out;
    foreach (skill in skills)
    {
        if (skill == null) continue;
        local id = null;
        try { id = skill.getID(); } catch (e) {}
        if (id == null || id.len() <= 6 || id.slice(0, 6) != "trait.") continue;
        if (::BBSeedTool_IsOriginTrait(id)) continue;
        if (out.len() > 0) out += ",";
        out += id.slice(6);
    }
    return out;
};

::BBSeedTool_RemoveAllItems <- function(_bro)
{
    local items = _bro.getItems();
    for (local i = ::Const.ItemSlot.Mainhand; i <= ::Const.ItemSlot.Ammo; i++)
    {
        local item = items.getItemAtSlot(i);
        if (item != null && item != "-1") items.unequip(item);
    }
    for (local i = 0; i < items.getUnlockedBagSlots(); i++)
    {
        local item = items.getItemAtBagSlot(i);
        if (item != null && item != "-1") items.removeFromBag(item);
    }
};

::BBSeedTool_CollectBro <- function(_slot, _bro)
{
    ::BBSeedTool_RemoveAllItems(_bro);
    try { _bro.getSkills().update(); } catch (e) {}
    local p = _bro.getCurrentProperties();
    local bg = "";
    try { bg = _bro.getBackground().getID(); } catch (e) {}
    local talents = null;
    try { talents = _bro.getTalents(); } catch (e) {}
    return {
        slot = _slot,
        name = ::BBSeedTool_Safe(_bro.getName()),
        bg = ::BBSeedTool_Safe(bg),
        hp = _bro.getHitpointsMax(),
        fat = _bro.getFatigueMax(),
        res = _bro.getBravery(),
        init = _bro.getInitiative(),
        msk = p.getMeleeSkill(),
        rsk = p.getRangedSkill(),
        mdf = p.getMeleeDefense(),
        rdf = p.getRangedDefense(),
        shp = ::BBSeedTool_TalentAt(talents, "Hitpoints"),
        sfat = ::BBSeedTool_TalentAt(talents, "Fatigue"),
        sres = ::BBSeedTool_TalentAt(talents, "Bravery"),
        sinit = ::BBSeedTool_TalentAt(talents, "Initiative"),
        smsk = ::BBSeedTool_TalentAt(talents, "MeleeSkill"),
        srsk = ::BBSeedTool_TalentAt(talents, "RangedSkill"),
        smdf = ::BBSeedTool_TalentAt(talents, "MeleeDefense"),
        srdf = ::BBSeedTool_TalentAt(talents, "RangedDefense"),
        traits = ::BBSeedTool_Traits(_bro)
    };
};

::BBSeedTool_AnalyzePorts <- function(_settlements)
{
    local result = { count = 0, flags = ::BBSeedTool.PortFlagKnown, detail = "" };
    if (_settlements == null) return result;
    // v1.48: north-port flags are geographic. BB's Y axis grows northward
    // (desert music below 20% of map height, snowline at 90%), so a port
    // counts as northern only if its tile sits above the configured line.
    local mapY = 0;
    try { mapY = ::World.getMapSize().Y; } catch (e) {}
    // v1.78: SouthKnown marks "this record carries south-latitude data".
    // It is set even on zero-port maps so legacy shards (which have none of
    // the south bits) can be told apart from mapped empty ones.
    if (mapY > 0) result.flags = result.flags | ::BBSeedTool.PortFlagSouthKnown;
    foreach (settlement in _settlements)
    {
        local hasPort = false;
        try { hasPort = settlement.hasBuilding("building.port"); } catch (e) {}
        if (!hasPort) continue;
        result.count++;
        local isSouthern = false;
        try { isSouthern = settlement.isSouthern(); }
        catch (e)
        {
            // A failed isSouthern() used to silently count the port as northern,
            // corrupting the south/north flags. Log it so the data can be
            // distrusted instead of silently wrong.
            ::logWarning("[BBSEED] PORT_ISSOUTHERN_ERROR|" + ::BBSeedTool_Safe(e));
        }
        if (isSouthern) result.flags = result.flags | ::BBSeedTool.PortFlagSouth;
        else result.flags = result.flags | ::BBSeedTool.PortFlagNorth;
        // Latitude bits are purely positional and apply to every port,
        // whatever settlement class owns it.
        if (mapY > 0)
        {
            local tileY = -1;
            try { tileY = settlement.getTile().SquareCoords.Y; } catch (e) {}
            if (tileY >= 0)
            {
                local rel = tileY.tofloat() / mapY.tofloat();
                if (rel > 0.5) result.flags = result.flags | ::BBSeedTool.PortFlagNorth50;
                if (rel > 0.65) result.flags = result.flags | ::BBSeedTool.PortFlagNorth65;
                if (rel > 0.8) result.flags = result.flags | ::BBSeedTool.PortFlagNorth80;
                if (rel < 0.5) result.flags = result.flags | ::BBSeedTool.PortFlagSouth50;
                if (rel < 0.35) result.flags = result.flags | ::BBSeedTool.PortFlagSouth35;
                if (rel < 0.2) result.flags = result.flags | ::BBSeedTool.PortFlagSouth20;
            }
            else ::logWarning("[BBSEED] PORT_TILE_ERROR|no_tile_y");
        }
        local hasArena = false;
        try
        {
            if (settlement.hasBuilding("building.arena"))
            {
                result.flags = result.flags | ::BBSeedTool.PortFlagArena;
                hasArena = true;
            }
        }
        catch (e) {}
        try
        {
            local relY = mapY > 0 ? (settlement.getTile().SquareCoords.Y * 100 / mapY) : -1;
            result.detail += (result.detail == "" ? "" : ";") + ::BBSeedTool_Safe(settlement.getName()) + ":y" + relY
                + (isSouthern ? ":S" : ":N") + (hasArena ? ":arena" : "");
        }
        catch (e) {}
    }
    return result;
};

::BBSeedTool_CleanupRoster <- function(_roster)
{
    foreach (bro in _roster.getAll())
    {
        try { _roster.remove(bro); } catch (e) {}
    }
    try
    {
        local stash = ::World.Assets.getStash();
        stash.clear();
        stash.resize(200);
    }
    catch (e) {}
};

// v1.50: talent-only equivalent of World.Assets.setCampaignSettings().
// Vanilla setCampaignSettings() calls buildDescription(true) on every
// brother's background after spawning them, and buildDescription() reads
// World.EntityManager.getSettlements() UNGUARDED (villages[rand(...)],
// northern[0]). Without a generated map that list is empty and every seed
// died with "the index '0' does not exist" - this was the talent-mode bug.
// Everything the tool records (stats, talents, traits, name, background)
// is rolled inside onSpawnAssets(), BEFORE vanilla would build the
// descriptions, so skipping that step cannot change the recorded data.
// RNG order is preserved: the CampaignID rand() consumes the same first
// roll as vanilla, then onSpawnAssets() runs on the identical stream.
::BBSeedTool_SetupTalentCampaign <- function(_settings, _skipPost = false)
{
    local assets = ::World.Assets;
    assets.m.CampaignID = ::Math.max(0, ::Math.rand());
    assets.m.Name = _settings.Name;
    assets.m.Banner = _settings.Banner;
    assets.m.CombatDifficulty = _settings.Difficulty;
    assets.m.EconomicDifficulty = _settings.EconomicDifficulty;
    assets.m.IsIronman = _settings.Ironman;
    assets.m.IsPermanentDestruction = _settings.PermanentDestruction;
    assets.m.Origin = _settings.StartingScenario;
    assets.m.IsExplorationMode = _settings.ExplorationMode;
    assets.m.BusinessReputation = 0;
    assets.m.SeedString = _settings.Seed;
    assets.m.Stash.clear();
    try
    {
        assets.m.Origin.onSpawnAssets();
    }
    catch (e)
    {
        // v1.79: an early abort is not an error - the seed simply cannot
        // reach the prefilter any more, so the rest of the roll is skipped.
        local st = ::BBSeedTool.Abort;
        ::BBSeedTool.Abort = null;
        if (st != null && st.aborted) return false;
        throw "talent_spawn|" + ::BBSeedTool_Safe(e);
    }
    ::BBSeedTool.Abort = null;
    // v1.79: everything the tool records is final once onSpawnAssets()
    // returned. The vanilla post-spawn loop below only re-rolls level-up
    // values that are never stored, so the fast path may skip it.
    if (_skipPost) return true;
    try
    {
        local bros = ::World.getPlayerRoster().getAll();
        foreach (bro in bros)
        {
            // Skipped vs vanilla: buildDescription(true) - needs a map, and
            // the tool never records description text.
            bro.m.XP = ::Const.LevelXP[bro.m.Level - 1];
            bro.m.Attributes = [];
            bro.fillAttributeLevelUpValues(::Const.XP.MaxLevelWithPerkpoints - 1);
            bro.getSkills().update();
        }
    }
    catch (e) { throw "talent_postspawn|" + ::BBSeedTool_Safe(e); }
    return true;
};

::BBSeedTool_WriteBro <- function(_out, _bro)
{
    _out.writeU8(_bro.slot);
    _out.writeString(_bro.name);
    _out.writeString(_bro.bg);
    _out.writeU16(_bro.hp); _out.writeU16(_bro.fat); _out.writeU16(_bro.res); _out.writeU16(_bro.init);
    _out.writeU16(_bro.msk); _out.writeU16(_bro.rsk); _out.writeI16(_bro.mdf); _out.writeI16(_bro.rdf);
    _out.writeU8(_bro.shp); _out.writeU8(_bro.sfat); _out.writeU8(_bro.sres); _out.writeU8(_bro.sinit);
    _out.writeU8(_bro.smsk); _out.writeU8(_bro.srsk); _out.writeU8(_bro.smdf); _out.writeU8(_bro.srdf);
    _out.writeString(_bro.traits);
};

::BBSeedTool_ReadBro <- function(_input)
{
    return {
        slot = _input.readU8(), name = _input.readString(), bg = _input.readString(),
        hp = _input.readU16(), fat = _input.readU16(), res = _input.readU16(), init = _input.readU16(),
        msk = _input.readU16(), rsk = _input.readU16(), mdf = _input.readI16(), rdf = _input.readI16(),
        shp = _input.readU8(), sfat = _input.readU8(), sres = _input.readU8(), sinit = _input.readU8(),
        smsk = _input.readU8(), srsk = _input.readU8(), smdf = _input.readU8(), srdf = _input.readU8(),
        traits = _input.readString()
    };
};

::BBSeedTool_WriteRecord <- function(_out, _record)
{
    _out.writeString(_record.seed);
    _out.writeU16(_record.ports);
    _out.writeU16(_record.settlements);
    // v1.78: portFlags grew past 8 bits (south latitude lines); DB4 writes U16.
    _out.writeU16(_record.portFlags);
    _out.writeU8(_record.bros.len());
    foreach (bro in _record.bros) ::BBSeedTool_WriteBro(_out, bro);
};

::BBSeedTool_ReadRecord <- function(_input, _origin, _databaseVersion)
{
    local result = {
        seed = _input.readString(), origin = _origin,
        ports = _input.readU16(), settlements = _input.readU16(), portFlags = 0, bros = []
    };
    if (_databaseVersion >= 4) result.portFlags = _input.readU16();
    else if (_databaseVersion >= 2) result.portFlags = _input.readU8();
    local count = _input.readU8();
    for (local i = 0; i < count; i++) result.bros.push(::BBSeedTool_ReadBro(_input));
    return result;
};

::BBSeedTool_ReadDatabaseVersion <- function(_input)
{
    local magic = _input.readString();
    // v1.48: only BBSEEDDB3 is accepted. Older shards stored class-based
    // north-port flags (no latitude bits) and would silently misreport
    // north ports under the new geographic semantics, so they are skipped.
    if (magic == ::BBSeedTool.Magic) return 4;
    // v1.78: DB3 shards stay readable. They simply lack the south-latitude
    // bits, so the new south lines report "no south port" for them until a
    // map backfill rewrites the shard as DB4.
    if (magic == ::BBSeedTool.LegacyMagic3) return 3;
    return 0;
};

::BBSeedTool_HasPortFlag <- function(_record, _flag)
{
    return (_record.portFlags & _flag) != 0;
};

// v1.48: map the UI's north-port-line selection (50/65/80) to the flag bit
// that records "has a port north of that line".
::BBSeedTool_NorthLineFlag <- function(_northLine)
{
    if (_northLine <= 50) return ::BBSeedTool.PortFlagNorth50;
    if (_northLine <= 65) return ::BBSeedTool.PortFlagNorth65;
    return ::BBSeedTool.PortFlagNorth80;
};

::BBSeedTool_HasNorthPort <- function(_record, _northLine = 80)
{
    return ::BBSeedTool_HasPortFlag(_record, ::BBSeedTool_NorthLineFlag(_northLine));
};

// v1.78: south-port line selection. 0 = desert states only (the historical
// behaviour); 20/35/50 = "some port sits below that share of map height".
::BBSeedTool_SouthLineFlag <- function(_southLine)
{
    if (_southLine == 20) return ::BBSeedTool.PortFlagSouth20;
    if (_southLine == 35) return ::BBSeedTool.PortFlagSouth35;
    if (_southLine == 50) return ::BBSeedTool.PortFlagSouth50;
    return ::BBSeedTool.PortFlagSouth;
};

::BBSeedTool_HasSouthPort <- function(_record, _southLine = 0)
{
    if (_southLine == 0)
        return ::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagSouth);
    // The geographic south lines need data legacy shards never recorded.
    if (!::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagSouthKnown)) return false;
    return ::BBSeedTool_HasPortFlag(_record, ::BBSeedTool_SouthLineFlag(_southLine));
};

// South+north now means: a city-state port (unchanged) AND a port north of
// the selected latitude line (v1.48, geographic - replaces the old
// class-based check that counted desert-fringe towns as northern).
::BBSeedTool_HasSouthNorthPorts <- function(_record, _northLine = 80, _southLine = 0)
{
    return ::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagKnown)
        && ::BBSeedTool_HasNorthPort(_record, _northLine)
        && ::BBSeedTool_HasSouthPort(_record, _southLine);
};

::BBSeedTool_EmptyPortStats <- function()
{
    return { total = 0, gte3 = 0, gte4 = 0, gte5 = 0, gte6 = 0, known = 0, sn50 = 0, sn65 = 0, sn80 = 0, arena = 0 };
};

::BBSeedTool_AddPortStat <- function(_stats, _record)
{
    _stats.total++;
    if (_record.ports >= 3) _stats.gte3++;
    if (_record.ports >= 4) _stats.gte4++;
    if (_record.ports >= 5) _stats.gte5++;
    if (_record.ports >= 6) _stats.gte6++;
    if (::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagKnown))
    {
        _stats.known++;
        if (::BBSeedTool_HasSouthNorthPorts(_record, 50)) _stats.sn50++;
        if (::BBSeedTool_HasSouthNorthPorts(_record, 65)) _stats.sn65++;
        if (::BBSeedTool_HasSouthNorthPorts(_record, 80)) _stats.sn80++;
        if (::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagArena)) _stats.arena++;
    }
};

::BBSeedTool_SavePortStats <- function()
{
    if (::BBSeedTool.PortStats == null) return;
    try
    {
        local output = ::PersistenceManager.createStorage(::BBSeedTool.PortStatsFile);
        output.beginWrite();
        output.writeString(::BBSeedTool.PortStatsMagic);
        output.writeU32(::BBSeedTool.PortStats.total);
        output.writeU32(::BBSeedTool.PortStats.gte3);
        output.writeU32(::BBSeedTool.PortStats.gte4);
        output.writeU32(::BBSeedTool.PortStats.gte5);
        output.writeU32(::BBSeedTool.PortStats.gte6);
        output.writeU32(::BBSeedTool.PortStats.known);
        output.writeU32(::BBSeedTool.PortStats.sn50);
        output.writeU32(::BBSeedTool.PortStats.sn65);
        output.writeU32(::BBSeedTool.PortStats.sn80);
        output.writeU32(::BBSeedTool.PortStats.arena);
        output.endWrite();
    }
    catch (e) { ::logWarning("[BBSEED] PORT_STATS_SAVE_ERROR|" + ::BBSeedTool_Safe(e)); }
};

::BBSeedTool_LoadPortStats <- function()
{
    try
    {
        local exists = false;
        foreach (meta in ::PersistenceManager.queryStorages())
            if (meta.getFileName() == ::BBSeedTool.PortStatsFile) { exists = true; break; }
        if (!exists) return false;
        local input = ::PersistenceManager.loadStorage(::BBSeedTool.PortStatsFile);
        input.beginRead();
        if (input.readString() != ::BBSeedTool.PortStatsMagic) { input.endRead(); return false; }
        local stats = {
            total = input.readU32(),
            gte3 = input.readU32(),
            gte4 = input.readU32(),
            gte5 = input.readU32(),
            gte6 = input.readU32(),
            known = input.readU32(),
            sn50 = input.readU32(),
            sn65 = input.readU32(),
            sn80 = input.readU32(),
            arena = input.readU32()
        };
        input.endRead();
        if (stats.total != ::BBSeedTool.TotalSeeds) return false;
        ::BBSeedTool.PortStats = stats;
        ::logWarning("[BBSEED] PORT_STATS|source=cache|total=" + stats.total + "|known=" + stats.known + "|sn50=" + stats.sn50 + "|sn65=" + stats.sn65 + "|sn80=" + stats.sn80 + "|arena=" + stats.arena);
        return true;
    }
    catch (e)
    {
        ::logWarning("[BBSEED] PORT_STATS_LOAD_ERROR|" + ::BBSeedTool_Safe(e));
        return false;
    }
};

::BBSeedTool_ScanPortStats <- function()
{
    local stats = ::BBSeedTool_EmptyPortStats();
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                ::BBSeedTool_AddPortStat(stats, record);
            }
            input.endRead();
        }
        catch (e) { ::logWarning("[BBSEED] PORT_STATS_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e)); }
    }
    ::BBSeedTool.PortStats = stats;
    if (stats.total == ::BBSeedTool.TotalSeeds) ::BBSeedTool_SavePortStats();
    else ::logWarning("[BBSEED] PORT_STATS_COUNT_MISMATCH|catalog=" + ::BBSeedTool.TotalSeeds + "|scanned=" + stats.total);
    ::logWarning("[BBSEED] PORT_STATS|source=scan|total=" + stats.total + "|known=" + stats.known + "|sn50=" + stats.sn50 + "|sn65=" + stats.sn65 + "|sn80=" + stats.sn80 + "|arena=" + stats.arena);
    return stats;
};

::BBSeedTool_GetPortStats <- function()
{
    if (::BBSeedTool.PortStats != null && ::BBSeedTool.PortStats.total == ::BBSeedTool.TotalSeeds)
        return ::BBSeedTool.PortStats;
    ::BBSeedTool.PortStats = null;
    if (::BBSeedTool_LoadPortStats()) return ::BBSeedTool.PortStats;
    return ::BBSeedTool_ScanPortStats();
};

::BBSeedTool_LoadCatalog <- function()
{
    ::BBSeedTool.TotalSeeds = 0;
    ::BBSeedTool.TotalBatches = 0;
    ::BBSeedTool.NextBatchID = 1;
    ::BBSeedTool.PortStats = null;
    ::BBSeedTool.TalentDistributions = null;
    ::BBSeedTool.TalentDistributionTotal = -1;
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            input.readString();
            local batchID = input.readU32();
            local count = input.readU32();
            input.endRead();
            ::BBSeedTool.TotalSeeds += count;
            ::BBSeedTool.TotalBatches++;
            if (batchID >= ::BBSeedTool.NextBatchID) ::BBSeedTool.NextBatchID = batchID + 1;
        }
        catch (e)
        {
            ::logWarning("[BBSEED] DB_SKIP|file=" + name + "|error=" + e);
        }
    }
    ::BBSeedTool.CatalogLoaded = true;
};

::BBSeedTool_SaveCurrentShard <- function(_newRecords)
{
    if (::BBSeedTool.CurrentShard.len() == 0) return;
    local filename = ::BBSeedTool.Prefix + ::BBSeedTool_OriginCode(::BBSeedTool.ActiveOrigin) + "#" + ::BBSeedTool.CurrentShardID;
    local output = ::PersistenceManager.createStorage(filename);
    output.beginWrite();
    output.writeString(::BBSeedTool.Magic);
    output.writeString(::BBSeedTool.ActiveOrigin);
    output.writeU32(::BBSeedTool.CurrentShardID);
    output.writeU32(::BBSeedTool.CurrentShard.len());
    local maxPorts = 0;
    local maxMSK = 0;
    local maxMDF = -100;
    local maxFat = 0;
    local maxRes = 0;
    local maxSMSK = 0;
    local maxSMDF = 0;
    foreach (record in ::BBSeedTool.CurrentShard)
    {
        if (record.ports > maxPorts) maxPorts = record.ports;
        foreach (bro in record.bros)
        {
            if (bro.msk > maxMSK) maxMSK = bro.msk;
            if (bro.mdf > maxMDF) maxMDF = bro.mdf;
            if (bro.fat > maxFat) maxFat = bro.fat;
            if (bro.res > maxRes) maxRes = bro.res;
            if (bro.smsk > maxSMSK) maxSMSK = bro.smsk;
            if (bro.smdf > maxSMDF) maxSMDF = bro.smdf;
        }
    }
    output.writeU16(maxPorts);
    output.writeU16(maxMSK);
    output.writeI16(maxMDF);
    output.writeU16(maxFat);
    output.writeU16(maxRes);
    output.writeU8(maxSMSK);
    output.writeU8(maxSMDF);
    foreach (record in ::BBSeedTool.CurrentShard) ::BBSeedTool_WriteRecord(output, record);
    output.endWrite();

    local updatePortStats = ::BBSeedTool.PortStats != null && ::BBSeedTool.PortStats.total == ::BBSeedTool.TotalSeeds;
    if (updatePortStats)
    {
        local firstNew = ::BBSeedTool.CurrentShard.len() - _newRecords;
        for (local i = firstNew; i < ::BBSeedTool.CurrentShard.len(); i++)
            ::BBSeedTool_AddPortStat(::BBSeedTool.PortStats, ::BBSeedTool.CurrentShard[i]);
    }
    ::BBSeedTool.TotalSeeds += _newRecords;
    ::BBSeedTool.TalentDistributions = null;
    ::BBSeedTool.TalentDistributionTotal = -1;
    if (updatePortStats) ::BBSeedTool_SavePortStats();
    if (!::BBSeedTool.CurrentShardSaved)
    {
        ::BBSeedTool.TotalBatches++;
        ::BBSeedTool.CurrentShardSaved = true;
    }
    ::logWarning("[BBSEED] COMMIT|file=" + filename + "|new_records=" + _newRecords
        + "|shard_records=" + ::BBSeedTool.CurrentShard.len()
        + "|total=" + ::BBSeedTool.TotalSeeds);
};

::BBSeedTool_CommitBatch <- function()
{
    if (::BBSeedTool.Buffer.len() == 0) return;
    local sourceIndex = 0;
    while (sourceIndex < ::BBSeedTool.Buffer.len())
    {
        if (::BBSeedTool.CurrentShardID == 0)
        {
            ::BBSeedTool.CurrentShardID = ::BBSeedTool.NextBatchID++;
            ::BBSeedTool.CurrentShard = [];
            ::BBSeedTool.CurrentShardSaved = false;
        }
        local room = ::BBSeedTool.ShardSize - ::BBSeedTool.CurrentShard.len();
        local take = ::Math.min(room, ::BBSeedTool.Buffer.len() - sourceIndex);
        for (local i = 0; i < take; i++)
            ::BBSeedTool.CurrentShard.push(::BBSeedTool.Buffer[sourceIndex + i]);
        sourceIndex += take;
        ::BBSeedTool_SaveCurrentShard(take);
        if (::BBSeedTool.CurrentShard.len() >= ::BBSeedTool.ShardSize)
        {
            ::BBSeedTool.CurrentShardID = 0;
            ::BBSeedTool.CurrentShard = [];
            ::BBSeedTool.CurrentShardSaved = false;
        }
    }
    ::BBSeedTool.Buffer.clear();
};

// v1.49: shard rewrite helper shared by backfill and cleanup. Recomputes the
// header maxima exactly like SaveCurrentShard does.
::BBSeedTool_WriteShard <- function(_filename, _origin, _batchID, _records)
{
    local output = ::PersistenceManager.createStorage(_filename);
    output.beginWrite();
    output.writeString(::BBSeedTool.Magic);
    output.writeString(_origin);
    output.writeU32(_batchID);
    output.writeU32(_records.len());
    local maxPorts = 0;
    local maxMSK = 0;
    local maxMDF = -100;
    local maxFat = 0;
    local maxRes = 0;
    local maxSMSK = 0;
    local maxSMDF = 0;
    foreach (record in _records)
    {
        if (record.ports > maxPorts) maxPorts = record.ports;
        foreach (bro in record.bros)
        {
            if (bro.msk > maxMSK) maxMSK = bro.msk;
            if (bro.mdf > maxMDF) maxMDF = bro.mdf;
            if (bro.fat > maxFat) maxFat = bro.fat;
            if (bro.res > maxRes) maxRes = bro.res;
            if (bro.smsk > maxSMSK) maxSMSK = bro.smsk;
            if (bro.smdf > maxSMDF) maxSMDF = bro.smdf;
        }
    }
    output.writeU16(maxPorts);
    output.writeU16(maxMSK);
    output.writeI16(maxMDF);
    output.writeU16(maxFat);
    output.writeU16(maxRes);
    output.writeU8(maxSMSK);
    output.writeU8(maxSMDF);
    foreach (record in _records) ::BBSeedTool_WriteRecord(output, record);
    output.endWrite();
};

// v1.49 backfill: find the shard record for (_origin, _record.seed) and
// overwrite ONLY its map data (ports / portFlags / settlements). Batch id,
// brothers and marks are preserved. Returns true when the record was found.
::BBSeedTool_UpdatePortData <- function(_origin, _record)
{
    local prefix = ::BBSeedTool.Prefix + ::BBSeedTool_OriginCode(_origin) + "#";
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, prefix)) continue;
        local input = null;
        local records = [];
        local batchID = 0;
        local found = false;
        try
        {
            input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            input.readString();
            batchID = input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local stored = ::BBSeedTool_ReadRecord(input, _origin, databaseVersion);
                if (stored.seed == _record.seed)
                {
                    // v1.79: full-map generation rolls the brothers again;
                    // prove they equal the talent-only record.
                    local same = ::BBSeedTool_RecordSig(stored) == ::BBSeedTool_RecordSig(_record);
                    ::logWarning("[BBSEED] BACKFILL_BROS|seed=" + _record.seed + "|match=" + (same ? "1" : "0")
                        + (same ? "" : "|stored=" + ::BBSeedTool_RecordSig(stored) + "|fresh=" + ::BBSeedTool_RecordSig(_record)));
                    local pfNow = ::BBSeedTool.Prefilter;
                    local fullNow = pfNow != null && ((pfNow.full != null && ::BBSeedTool_GroupsMatch(_record.bros, pfNow.full)) || (pfNow.fullAlt != null && ::BBSeedTool_GroupsMatch(_record.bros, pfNow.fullAlt)));
                    ::logWarning("[BBSEED] BACKFILL_HIT|seed=" + _record.seed + "|full=" + (fullNow ? "1" : "0") + "|ports=" + _record.ports + "|flags=" + _record.portFlags + "|bros=" + ::BBSeedTool_HitText(_record));
                    if (::BBSeedTool.AutoMark && !::BBSeedTool_IsMarked(_origin, _record.seed)) ::BBSeedTool_ToggleMark(_origin, _record.seed);
                    stored.ports = _record.ports;
                    stored.portFlags = _record.portFlags;
                    stored.settlements = _record.settlements;
                    found = true;
                }
                records.push(stored);
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] BACKFILL_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
            continue;
        }
        if (!found) continue;
        ::BBSeedTool_WriteShard(name, _origin, batchID, records);
        // The cached aggregate port stats no longer match the library.
        ::BBSeedTool.PortStats = null;
        ::logWarning("[BBSEED] BACKFILL_UPDATE|file=" + name + "|seed=" + _record.seed + "|ports=" + _record.ports + "|flags=" + _record.portFlags);
        return true;
    }
    return false;
};

// v1.49: best talent score of a record, same formula the query path uses.
::BBSeedTool_RecordMaxScore <- function(_record)
{
    local best = 0;
    foreach (bro in _record.bros)
    {
        local score = ::BBSeedTool_TalentScore(::BBSeedTool_ProjectedMelee(bro));
        if (score > best) best = score;
    }
    return best;
};

// v1.49 cleanup: scan (and optionally delete) every record that has NO map
// data (talent-only) and is NOT marked. Returns { total, high, examples }.
// With _execute = true the matching records are dropped and their shards
// rewritten; empty shards stay on disk with zero records.
::BBSeedTool_CleanupTalent <- function(_execute)
{
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    local total = 0;
    local high = 0;
    local examples = [];
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        local records = [];
        local keep = [];
        local origin = "";
        local batchID = 0;
        local changed = false;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            origin = input.readString();
            batchID = input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++) records.push(::BBSeedTool_ReadRecord(input, origin, databaseVersion));
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] CLEANUP_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
            continue;
        }
        foreach (record in records)
        {
            local talentOnly = (record.portFlags & ::BBSeedTool.PortFlagKnown) == 0;
            if (talentOnly && !::BBSeedTool_IsMarked(origin, record.seed))
            {
                total++;
                local best = ::BBSeedTool_RecordMaxScore(record);
                if (best >= 90)
                {
                    high++;
                    if (examples.len() < 2) examples.push({ seed = record.seed, score = best });
                }
                changed = true;
                continue;
            }
            keep.push(record);
        }
        if (_execute && changed)
        {
            ::BBSeedTool_WriteShard(name, origin, batchID, keep);
            ::logWarning("[BBSEED] CLEANUP_SHARD|file=" + name + "|dropped=" + (records.len() - keep.len()) + "|kept=" + keep.len());
        }
    }
    if (_execute && total > 0)
    {
        // Library totals changed: force every cache to rebuild.
        ::BBSeedTool.CatalogLoaded = false;
        ::BBSeedTool.PortStats = null;
        ::BBSeedTool.TalentDistributions = null;
        ::BBSeedTool.TalentDistributionTotal = -1;
        ::BBSeedTool_LoadCatalog();
    }
    ::logWarning("[BBSEED] CLEANUP_" + (_execute ? "EXECUTE" : "PRECHECK") + "|total=" + total + "|high=" + high);
    return { total = total, high = high, examples = examples };
};

// v1.62: wipe the ENTIRE library (every shard, marked or not, mapped or
// not). Precheck counts records from shard headers only. Execute truncates
// every shard file to zero bytes: an empty file fails the magic check, so
// it is skipped everywhere and - importantly - no longer contributes its
// batch id, which makes the next run start at batch 1 again (the agreed
// "batch numbering follows the stored shards" behaviour). Truncation via
// createStorage is the proven overwrite path already used by WriteShard;
// it avoids relying on a storage-deletion API that may not exist.
::BBSeedTool_WipeAll <- function(_execute)
{
    local total = 0;
    local files = 0;
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion != 0)
            {
                input.readString();
                input.readU32();
                total += input.readU32();
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] WIPE_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
        if (!_execute) continue;
        try
        {
            local output = ::PersistenceManager.createStorage(name);
            output.beginWrite();
            output.endWrite();
            files++;
        }
        catch (e)
        {
            ::logWarning("[BBSEED] WIPE_FAIL|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
    }
    if (_execute)
    {
        // Marks reference seeds that no longer exist: clear them too, then
        // force every cache to rebuild exactly like the cleanup path does.
        if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
        ::BBSeedTool.Marks = {};
        ::BBSeedTool_SaveMarks();
        ::BBSeedTool.CatalogLoaded = false;
        ::BBSeedTool.PortStats = null;
        ::BBSeedTool.TalentDistributions = null;
        ::BBSeedTool.TalentDistributionTotal = -1;
        ::BBSeedTool_LoadCatalog();
    }
    ::logWarning("[BBSEED] WIPE_" + (_execute ? "EXECUTE" : "PRECHECK") + "|total=" + total + "|files=" + files);
    return { total = total, files = files };
};

// ----- v1.63: export / import of marked seeds -----

::BBSeedTool_Pad2 <- function(_n)
{
    return _n < 10 ? "0" + _n : "" + _n;
};

::BBSeedTool_ExportStamp <- function()
{
    // Local wall-clock stamp for the export file name (also shown in the
    // import picker). Falls back to a sequence number if date() is missing.
    try
    {
        local d = date();
        return d.year + ::BBSeedTool_Pad2(d.month + 1) + ::BBSeedTool_Pad2(d.day)
            + "-" + ::BBSeedTool_Pad2(d.hour) + ::BBSeedTool_Pad2(d.min);
    }
    catch (e) {}
    local seq = 1;
    foreach (meta in ::PersistenceManager.queryStorages())
        if (::BBSeedTool_StartsWith(meta.getFileName(), ::BBSeedTool.ExportPrefix)) seq++;
    return "export-" + seq;
};

// v1.78: count/group mapped seeds whose records predate the south-latitude
// bits. The UI calls this before switching the south port line away from
// "desert states"; the returned groups feed the normal backfill queue, which
// re-runs the maps and rewrites those shards as DB4.
::BBSeedTool_LegacySouthGroups <- function()
{
    local groups = {};
    local order = [];
    local total = 0;
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                if (::BBSeedTool_HasPortFlag(record, ::BBSeedTool.PortFlagKnown)
                    && !::BBSeedTool_HasPortFlag(record, ::BBSeedTool.PortFlagSouthKnown))
                {
                    if (!(origin in groups)) { groups[origin] <- []; order.push(origin); }
                    groups[origin].push(record.seed);
                    total++;
                }
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] LEGACY_SOUTH_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
    }
    local result = [];
    foreach (origin in order) result.push({ origin = origin, seeds = groups[origin] });
    return { count = total, groups = result };
};

::BBSeedTool_ReadExportHeader <- function(_input)
{
    // Returns the export format version (1+), or 0 when the file is not a
    // supported export. Newer mod versions keep reading older versions:
    // the layout is only ever extended at the end, never changed in place.
    local magic = _input.readString();
    if (!::BBSeedTool_StartsWith(magic, "BBSEEDEXP")) return 0;
    local version = 0;
    try { version = magic.slice(9).tointeger(); } catch (e) { return 0; }
    if (version < 1 || version > 2) return 0; // this build speaks v1-v2
    return version;
};

// v1.71: _target optionally names an existing export file to overwrite.
::BBSeedTool_ExportMarked <- function(_target = "")
{
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    local found = []; // entries: { origin = ..., record = ... }
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                if (::BBSeedTool_IsMarked(origin, record.seed)) found.push({ origin = origin, record = record });
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] EXPORT_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
    }
    if (found.len() == 0) return { ok = true, total = 0 };
    local stamp = ::BBSeedTool_ExportStamp();
    local filename = ::BBSeedTool.ExportPrefix + stamp;
    // v1.71 overwrite mode: a valid existing export name rewrites that file
    // in place; the content still carries the fresh stamp generated above.
    if (_target != "" && ::BBSeedTool_StartsWith(_target, ::BBSeedTool.ExportPrefix)) filename = _target;
    try
    {
        local output = ::PersistenceManager.createStorage(filename);
        output.beginWrite();
        output.writeString(::BBSeedTool.ExportMagic);
        output.writeString(stamp);
        output.writeU32(found.len());
        foreach (entry in found)
        {
            output.writeString(entry.origin);
            ::BBSeedTool_WriteRecord(output, entry.record);
        }
        output.endWrite();
    }
    catch (e)
    {
        ::logWarning("[BBSEED] EXPORT_FAIL|error=" + ::BBSeedTool_Safe(e));
        return { ok = false, error = "export write failed", total = 0 };
    }
    ::logWarning("[BBSEED] EXPORT_DONE|file=" + filename + "|total=" + found.len());
    return { ok = true, total = found.len(), file = filename + ".sav", stamp = stamp };
};

::BBSeedTool_ImportList <- function()
{
    if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();
    local files = [];
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.ExportPrefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local version = ::BBSeedTool_ReadExportHeader(input);
            if (version > 0)
            {
                local stamp = input.readString();
                local count = input.readU32();
                files.push({ file = name, stamp = stamp, count = count });
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] IMPORT_LIST_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
    }
    // Newest first: the stamp strings are chronological.
    files.sort(function(a, b) { return a.stamp > b.stamp ? -1 : (a.stamp < b.stamp ? 1 : 0); });
    return { ok = true, files = files, nextBatch = ::BBSeedTool.NextBatchID };
};

::BBSeedTool_ImportFile <- function(_filename)
{
    // Read the whole export file first - fail before touching the library.
    local records = []; // entries: { origin = ..., record = ... }
    try
    {
        local input = ::PersistenceManager.loadStorage(_filename);
        input.beginRead();
        local version = ::BBSeedTool_ReadExportHeader(input);
        if (version == 0) { input.endRead(); return { ok = false, error = "bad file" }; }
        input.readString(); // stamp
        local count = input.readU32();
        for (local i = 0; i < count; i++)
        {
            local origin = input.readString();
            // v1.78: export v2 stores 16-bit portFlags, v1 stored 8-bit.
            local record = ::BBSeedTool_ReadRecord(input, origin, version >= 2 ? 4 : 3);
            records.push({ origin = origin, record = record });
        }
        input.endRead();
    }
    catch (e)
    {
        ::logWarning("[BBSEED] IMPORT_READ_FAIL|file=" + _filename + "|error=" + ::BBSeedTool_Safe(e));
        return { ok = false, error = "bad file" };
    }

    // Collect existing (origin, seed) keys so duplicates can be skipped.
    local existing = {};
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                existing[::BBSeedTool_MarkKey(origin, record.seed)] <- true;
            }
            input.endRead();
        }
        catch (e)
        {
            ::logWarning("[BBSEED] IMPORT_SCAN_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e));
        }
    }

    // Group fresh records by origin; the whole import shares ONE new batch
    // id (the newest batch), per the agreed numbering rule.
    if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();
    local batch = ::BBSeedTool.NextBatchID;
    local byOrigin = {};
    local skipped = 0;
    foreach (entry in records)
    {
        local key = ::BBSeedTool_MarkKey(entry.origin, entry.record.seed);
        if (key in existing) { skipped++; continue; }
        existing[key] <- true; // also dedupes repeats inside the file itself
        if (!(entry.origin in byOrigin)) byOrigin[entry.origin] <- [];
        byOrigin[entry.origin].push(entry.record);
    }
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    local imported = 0;
    foreach (origin, list in byOrigin)
    {
        local filename = ::BBSeedTool.Prefix + ::BBSeedTool_OriginCode(origin) + "#" + batch;
        try
        {
            ::BBSeedTool_WriteShard(filename, origin, batch, list);
            imported += list.len();
            // Imported seeds arrive pre-marked (the whole point of exporting).
            foreach (record in list) ::BBSeedTool.Marks[::BBSeedTool_MarkKey(origin, record.seed)] <- true;
        }
        catch (e)
        {
            ::logWarning("[BBSEED] IMPORT_WRITE_FAIL|file=" + filename + "|error=" + ::BBSeedTool_Safe(e));
        }
    }
    if (imported > 0)
    {
        ::BBSeedTool_SaveMarks();
        ::BBSeedTool.CatalogLoaded = false;
        ::BBSeedTool.PortStats = null;
        ::BBSeedTool.TalentDistributions = null;
        ::BBSeedTool.TalentDistributionTotal = -1;
        ::BBSeedTool_LoadCatalog();
    }
    ::logWarning("[BBSEED] IMPORT_DONE|file=" + _filename + "|imported=" + imported + "|skipped=" + skipped + "|batch=" + batch);
    return { ok = true, imported = imported, skipped = skipped, batch = (imported > 0 ? batch : 0) };
};

::BBSeedTool_Number <- function(_data, _key, _default = 0)
{
    try { return _data[_key].tointeger(); } catch (e) {}
    try { return _data[_key]; } catch (e) {}
    return _default;
};

// Expected level-11 melee attack uses the vanilla average gain for ten level
// ups: +20 with no stars, then +5 expected points for each melee-skill star.
// The score is intentionally an absolute 0-100 description of one brother;
// cross-origin seed comparisons use origin-relative percentile instead.
::BBSeedTool_ProjectedMelee <- function(_bro)
{
    return _bro.msk + 20 + _bro.smsk * 5;
};

::BBSeedTool_TalentScore <- function(_projectedMelee)
{
    if (_projectedMelee <= 76) return 0;
    if (_projectedMelee == 77) return 15;
    if (_projectedMelee == 78) return 30;
    if (_projectedMelee == 79) return 45;
    if (_projectedMelee == 80) return 60;
    if (_projectedMelee == 81) return 64;
    if (_projectedMelee == 82) return 68;
    if (_projectedMelee == 83) return 72;
    if (_projectedMelee == 84) return 76;
    if (_projectedMelee == 85) return 80;
    if (_projectedMelee == 86) return 83;
    if (_projectedMelee == 87) return 86;
    if (_projectedMelee == 88) return 89;
    if (_projectedMelee == 89) return 92;
    if (_projectedMelee == 90) return 95;
    if (_projectedMelee == 91) return 96;
    if (_projectedMelee == 92) return 97;
    if (_projectedMelee == 93) return 98;
    if (_projectedMelee == 94) return 99;
    return 100;
};

::BBSeedTool_AddTalentScores <- function(_record)
{
    local total = 0;
    local maxScore = 0;
    foreach (bro in _record.bros)
    {
        local projected = ::BBSeedTool_ProjectedMelee(bro);
        local score = ::BBSeedTool_TalentScore(projected);
        if ("projectedMSK" in bro) bro.projectedMSK = projected;
        else bro.projectedMSK <- projected;
        if ("talentScore" in bro) bro.talentScore = score;
        else bro.talentScore <- score;
        total += score;
        if (score > maxScore) maxScore = score;
    }
    local average10 = _record.bros.len() == 0 ? 0 : (total.tofloat() * 10.0 / _record.bros.len() + 0.5).tointeger();
    if ("talentScore10" in _record) _record.talentScore10 = average10;
    else _record.talentScore10 <- average10;
    if ("maxScore" in _record) _record.maxScore = maxScore;
    else _record.maxScore <- maxScore;
    return average10;
};

::BBSeedTool_BuildTalentDistributions <- function()
{
    local distributions = {};
    local scanned = 0;
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            input.readU32();
            local count = input.readU32();
            input.readU16(); input.readU16(); input.readI16(); input.readU16(); input.readU16(); input.readU8(); input.readU8();
            if (!(origin in distributions)) distributions[origin] <- [];
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                distributions[origin].push(::BBSeedTool_AddTalentScores(record));
                scanned++;
            }
            input.endRead();
        }
        catch (e) { ::logWarning("[BBSEED] TALENT_SCAN_SKIP|file=" + name + "|error=" + ::BBSeedTool_Safe(e)); }
    }
    foreach (origin, scores in distributions)
        scores.sort(function(a, b) { return b <=> a; });
    ::BBSeedTool.TalentDistributions = distributions;
    ::BBSeedTool.TalentDistributionTotal = scanned;
    ::logWarning("[BBSEED] TALENT_DISTRIBUTIONS|total=" + scanned + "|catalog=" + ::BBSeedTool.TotalSeeds);
    return distributions;
};

::BBSeedTool_GetTalentDistributions <- function()
{
    if (::BBSeedTool.TalentDistributions != null && ::BBSeedTool.TalentDistributionTotal == ::BBSeedTool.TotalSeeds)
        return ::BBSeedTool.TalentDistributions;
    return ::BBSeedTool_BuildTalentDistributions();
};

::BBSeedTool_AddTalentPercentile <- function(_record, _distributions)
{
    local scores = _record.origin in _distributions ? _distributions[_record.origin] : [];
    local lo = 0;
    local hi = scores.len();
    while (lo < hi)
    {
        local mid = (lo + hi) / 2;
        if (scores[mid] > _record.talentScore10) lo = mid + 1;
        else hi = mid;
    }
    local rank = scores.len() == 0 ? 0 : lo + 1;
    local top100 = scores.len() == 0 ? 10000 : ::Math.ceil(rank.tofloat() * 10000.0 / scores.len()).tointeger();
    if ("talentRank" in _record) _record.talentRank = rank;
    else _record.talentRank <- rank;
    if ("talentOriginTotal" in _record) _record.talentOriginTotal = scores.len();
    else _record.talentOriginTotal <- scores.len();
    if ("talentTop100" in _record) _record.talentTop100 = top100;
    else _record.talentTop100 <- top100;
};

::BBSeedTool_ContainsTrait <- function(_traits, _needle)
{
    if (_needle == null || _needle == "") return true;
    return _traits.tolower().find(_needle.tolower()) != null;
};

::BBSeedTool_BroMatches <- function(_bro, _filter, _ignoreNoNegative = false)
{
    local hp = ::BBSeedTool_Number(_filter, "hp");
    local msk = ::BBSeedTool_Number(_filter, "msk");
    local rsk = ::BBSeedTool_Number(_filter, "rsk");
    local mdf = ::BBSeedTool_Number(_filter, "mdf");
    local rdf = ::BBSeedTool_Number(_filter, "rdf");
    local fat = ::BBSeedTool_Number(_filter, "fat");
    local res = ::BBSeedTool_Number(_filter, "res");
    local initiative = ::BBSeedTool_Number(_filter, "init");
    local smsk = ::BBSeedTool_Number(_filter, "smsk");
    local smdf = ::BBSeedTool_Number(_filter, "smdf");
    local srsk = ::BBSeedTool_Number(_filter, "srsk");
    local sftg = ::BBSeedTool_Number(_filter, "sftg");
    local sini = ::BBSeedTool_Number(_filter, "sini");
    if (hp > 0 && _bro.hp < hp) return false;
    if (msk > 0 && _bro.msk < msk) return false;
    if (rsk > 0 && _bro.rsk < rsk) return false;
    if (mdf > 0 && _bro.mdf < mdf) return false;
    if (rdf > 0 && _bro.rdf < rdf) return false;
    if (fat > 0 && _bro.fat < fat) return false;
    if (res > 0 && _bro.res < res) return false;
    if (initiative > 0 && _bro.init < initiative) return false;
    if (smsk > 0 && _bro.smsk < smsk) return false;
    if (smdf > 0 && _bro.smdf < smdf) return false;
    if (srsk > 0 && _bro.srsk < srsk) return false;
    if (sftg > 0 && _bro.sfat < sftg) return false;
    if (sini > 0 && _bro.sinit < sini) return false;
    if (!_ignoreNoNegative && ::BBSeedTool_Number(_filter, "noNegative") > 0
        && ::BBSeedTool_BroHasNegativeTrait(_bro)) return false;
    local required = "";
    local banned = "";
    try { required = _filter.required; } catch (e) {}
    try { banned = _filter.banned; } catch (e) {}
    if (!::BBSeedTool_ContainsTrait(_bro.traits, required)) return false;
    if (banned != "" && ::BBSeedTool_ContainsTrait(_bro.traits, banned)) return false;
    // v1.67: quick-trait multi-select is checked HERE, at brother granularity,
    // together with stars/noNegative, so one brother must carry everything.
    local quickTrait = "";
    try { quickTrait = _filter.quickTrait; } catch (e) {}
    if (quickTrait != "")
    {
        local storedTraits = "," + _bro.traits.tolower() + ",";
        foreach (traitId in split(quickTrait, ","))
            if (traitId != "" && storedTraits.find("," + traitId.tolower() + ",") == null) return false;
    }
    return true;
};

::BBSeedTool_RecordHasTrait <- function(_record, _trait)
{
    if (_trait == null || _trait == "") return true;
    local wantedTrait = "," + _trait.tolower() + ",";
    foreach (bro in _record.bros)
    {
        local storedTraits = "," + bro.traits.tolower() + ",";
        if (storedTraits.find(wantedTrait) != null) return true;
    }
    return false;
};

// v1.66: multi-trait filter must match on a SINGLE brother. The previous
// per-trait "any brother" loop passed when the traits were spread across
// different brothers; now every selected trait id must be present in one
// and the same brother's trait string.
::BBSeedTool_RecordHasAllTraits <- function(_record, _traitIds)
{
    if (_traitIds.len() == 0) return true;
    foreach (bro in _record.bros)
    {
        local storedTraits = "," + bro.traits.tolower() + ",";
        local allOnBro = true;
        foreach (traitId in _traitIds)
        {
            if (traitId == "") continue;
            if (storedTraits.find("," + traitId.tolower() + ",") == null)
            {
                allOnBro = false;
                break;
            }
        }
        if (allOnBro) return true;
    }
    return false;
};

::BBSeedTool_RecordMatches <- function(_record, _filter)
{
    if (_record.ports < ::BBSeedTool_Number(_filter, "ports")) return false;
    local northLine = ::BBSeedTool_Number(_filter, "northLine", ::BBSeedTool.NorthLineDefault);
    if (northLine != 50 && northLine != 65 && northLine != 80) northLine = ::BBSeedTool.NorthLineDefault;
    local southLine = ::BBSeedTool_Number(_filter, "southLine", ::BBSeedTool.SouthLineDefault);
    if (southLine != 20 && southLine != 35 && southLine != 50) southLine = ::BBSeedTool.SouthLineDefault;
    if (::BBSeedTool_Number(_filter, "southNorthPort") > 0 && !::BBSeedTool_HasSouthNorthPorts(_record, northLine, southLine)) return false;
    if (::BBSeedTool_Number(_filter, "arenaPort") > 0
        && !::BBSeedTool_HasPortFlag(_record, ::BBSeedTool.PortFlagArena)) return false;
    local wantedOrigin = "";
    try { wantedOrigin = _filter.origin; } catch (e) {}
    if (wantedOrigin != "" && wantedOrigin != _record.origin) return false;
    local quickTrait = "";
    try { quickTrait = _filter.quickTrait; } catch (e) {}
    // v1.67: traits moved INTO BroMatches so stars/noNegative/traits all
    // concentrate on ONE brother. (v1.64 added multi-select; v1.65 fixed the
    // split() call; v1.66 made traits brother-granular among themselves.)

    local noNegative = ::BBSeedTool_Number(_filter, "noNegative") > 0;
    local hasStarFilter = ::BBSeedTool_Number(_filter, "smsk") > 0
        || ::BBSeedTool_Number(_filter, "smdf") > 0
        || ::BBSeedTool_Number(_filter, "srsk") > 0
        || ::BBSeedTool_Number(_filter, "sftg") > 0
        || ::BBSeedTool_Number(_filter, "sini") > 0;
    local ignoreNoNegative = false;
    if (noNegative && !hasStarFilter && quickTrait == "")
    {
        // With no star switch AND no quick-trait active, "no negative" refers
        // to the brother who owns the seed's displayed best score. Ties are
        // treated conservatively: any negative trait on any equal-best brother
        // hides the seed. When traits or stars are also selected, v1.67
        // requires everything on one brother, so this fallback is skipped.
        local maxScore = -1;
        foreach (bro in _record.bros)
        {
            local score = 0;
            if ("talentScore" in bro) score = bro.talentScore;
            else score = ::BBSeedTool_TalentScore(::BBSeedTool_ProjectedMelee(bro));
            if (score > maxScore) maxScore = score;
        }
        foreach (bro in _record.bros)
        {
            local score = 0;
            if ("talentScore" in bro) score = bro.talentScore;
            else score = ::BBSeedTool_TalentScore(::BBSeedTool_ProjectedMelee(bro));
            if (score == maxScore && ::BBSeedTool_BroHasNegativeTrait(bro)) return false;
        }
        ignoreNoNegative = true;
    }

    local slot = 0;
    local broScope = "any";
    try { broScope = _filter.broScope; } catch (e) {}
    try { slot = _filter.slot.tointeger(); } catch (e) { try { slot = _filter.slot; } catch (e2) {} }
    if (broScope == "slot" || slot > 0)
    {
        foreach (bro in _record.bros)
            if (bro.slot == slot) return ::BBSeedTool_BroMatches(bro, _filter, ignoreNoNegative);
        return false;
    }
    if (broScope == "all")
    {
        if (_record.bros.len() == 0) return false;
        foreach (bro in _record.bros)
            if (!::BBSeedTool_BroMatches(bro, _filter, ignoreNoNegative)) return false;
        return true;
    }
    foreach (bro in _record.bros)
        if (::BBSeedTool_BroMatches(bro, _filter, ignoreNoNegative)) return true;
    return false;
};

::BBSeedTool_Query <- function(_filter)
{
    if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();
    local distributions = ::BBSeedTool_GetTalentDistributions();
    local offset = ::BBSeedTool_Number(_filter, "offset");
    local limit = ::BBSeedTool_Number(_filter, "limit", 200);
    if (limit < 1) limit = 200;
    if (limit > 500) limit = 500;
    local keep = offset + limit;
    if (keep < limit) keep = limit;
    local talentTop100 = ::BBSeedTool_Number(_filter, "talentTop100", 10000);
    if (talentTop100 < 1 || talentTop100 > 10000) talentTop100 = 10000;
    local wantedOrigin = "";
    try { wantedOrigin = _filter.origin; } catch (e) {}
    local markFilter = "";
    try { markFilter = _filter.marked; } catch (e) {}
    local sortField = "talent";
    try { if (_filter.sortField == "max" || _filter.sortField == "batch") sortField = _filter.sortField; } catch (e) {}
    // sortDir multiplies the natural ascending comparison; -1 = best/newest first.
    local sortDir = -1;
    try { if (_filter.sortDir == "asc") sortDir = 1; } catch (e) {}
    local minSMSK = ::BBSeedTool_Number(_filter, "smsk");
    local minSMDF = ::BBSeedTool_Number(_filter, "smdf");
    local matched = 0;
    local candidates = [];
    local compareRows = function(a, b)
    {
        local cmp = 0;
        if (sortField == "max") cmp = a.maxScore <=> b.maxScore;
        else if (sortField == "batch") cmp = a.batch <=> b.batch;
        else if (wantedOrigin != "" || a.origin == b.origin) cmp = a.talentScore10 <=> b.talentScore10;
        else cmp = b.talentTop100 <=> a.talentTop100;
        if (cmp != 0) return cmp * sortDir;
        if (a.origin != b.origin) return a.origin <=> b.origin;
        return a.seed <=> b.seed;
    };
    foreach (meta in ::PersistenceManager.queryStorages())
    {
        local name = meta.getFileName();
        if (!::BBSeedTool_StartsWith(name, ::BBSeedTool.Prefix)) continue;
        try
        {
            local input = ::PersistenceManager.loadStorage(name);
            input.beginRead();
            local databaseVersion = ::BBSeedTool_ReadDatabaseVersion(input);
            if (databaseVersion == 0) { input.endRead(); continue; }
            local origin = input.readString();
            local batchID = input.readU32();
            local count = input.readU32();
            local maxPorts = input.readU16();
            local maxMSK = input.readU16();
            local maxMDF = input.readI16();
            local maxFat = input.readU16();
            local maxRes = input.readU16();
            local maxSMSK = input.readU8();
            local maxSMDF = input.readU8();
            local impossible = (wantedOrigin != "" && wantedOrigin != origin)
                || maxPorts < ::BBSeedTool_Number(_filter, "ports")
                || maxMSK < ::BBSeedTool_Number(_filter, "msk")
                || (::BBSeedTool_Number(_filter, "mdf") > 0 && maxMDF < ::BBSeedTool_Number(_filter, "mdf"))
                || maxFat < ::BBSeedTool_Number(_filter, "fat")
                || maxRes < ::BBSeedTool_Number(_filter, "res")
                || maxSMSK < minSMSK
                || maxSMDF < minSMDF;
            if (impossible) { input.endRead(); continue; }
            for (local i = 0; i < count; i++)
            {
                local record = ::BBSeedTool_ReadRecord(input, origin, databaseVersion);
                record.batch <- batchID;
                if (!::BBSeedTool_RecordMatches(record, _filter)) continue;
                local marked = ::BBSeedTool_IsMarked(origin, record.seed);
                if (markFilter == "yes" && !marked) continue;
                if (markFilter == "no" && marked) continue;
                record.marked <- marked;
                ::BBSeedTool_AddTalentScores(record);
                ::BBSeedTool_AddTalentPercentile(record, distributions);
                if (record.talentTop100 > talentTop100) continue;
                candidates.push(record);
                matched++;
                if (candidates.len() > keep + 500)
                {
                    candidates.sort(compareRows);
                    candidates.resize(keep);
                }
            }
            input.endRead();
        }
        catch (e) { ::logWarning("[BBSEED] QUERY_SKIP|file=" + name + "|error=" + e); }
    }
    candidates.sort(compareRows);
    if (candidates.len() > keep) candidates.resize(keep);
    local rows = [];
    for (local i = offset; i < candidates.len() && rows.len() < limit; i++) rows.push(candidates[i]);
    return { rows = rows, matched = matched, total = ::BBSeedTool.TotalSeeds, latestBatch = ::BBSeedTool.NextBatchID - 1 };
};

::BBSeedTool_Status <- function()
{
    if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();
    if (::BBSeedTool.Marks == null) ::BBSeedTool_LoadMarks();
    return {
        version = ::BBSeedTool.Version,
        marked = ::BBSeedTool.Marks.len(),
        total = ::BBSeedTool.TotalSeeds,
        batches = ::BBSeedTool.TotalBatches,
        maxIters = ::BBSeedTool.MaxIters,
        language = ::BBSeedTool.Language,
        mode = ::BBSeedTool.CollectionMode,
        portStats = ::BBSeedTool_GetPortStats(),
        batchSize = ::BBSeedTool.BatchSize,
        storage = "Battle Brothers persistent .sav files"
    };
};

::BBSeedTool_FindScenario <- function(_worldState)
{
    local scenario = null;
    try { scenario = _worldState.m.CampaignSettings.StartingScenario; } catch (e) {}
    if (scenario == null || !("onSpawnAssets" in scenario)) return null;
    local id = "";
    try { id = scenario.getID(); } catch (e) { try { id = scenario.m.ID; } catch (e2) {} }
    if (::BBSeedTool.SupportedOrigins.find(id) == null)
    {
        ::logWarning("[BBSEED] ERROR|message=unsupported_origin|origin=" + id);
        return null;
    }
    return scenario;
};

::BBSeedTool_Notify <- function(_method, _data)
{
    try
    {
        if (::BBSeedTool.UIBackend != null && ::BBSeedTool.UIBackend.m.JSHandle != null)
            ::BBSeedTool.UIBackend.m.JSHandle.asyncCall(_method, _data);
    }
    catch (e) {}
};

::BBSeedTool_FinishJob <- function(_stopped = false)
{
    local job = ::BBSeedTool.Job;
    if (job == null) return;
    try { ::BBSeedTool_CommitBatch(); } catch (e) { ::logWarning("[BBSEED] COMMIT_ERROR|" + e); }
    local worldState = job.WorldState;
    ::BBSeedTool.ReturningWorldState = worldState;
    ::BBSeedTool.Job = null;
    ::logWarning("[BBSEED] FINISH|done=" + job.Completed + "|saved_total=" + ::BBSeedTool.TotalSeeds + "|stopped=" + (_stopped ? "1" : "0"));
    // v1.54: report misses (processed but not saved, e.g. backfill of a seed
    // that is no longer in the library) so the result dialog can say so.
    ::BBSeedTool_Notify("bbseedCollectionFinished", { done = job.Completed, saved = ::BBSeedTool.TotalSeeds, stopped = _stopped, mode = job.Mode, backfill = job.IsBackfill, missed = job.Index - job.Completed });
    // The collection reset the global building counters before every seed;
    // leave them at zero so the next REAL campaign started in this same
    // process also builds its arena like a fresh one (vanilla never resets
    // them because it never reuses the process for a second campaign).
    try { ::Const.World.Buildings.reset(); } catch (e) {}
    // v1.53: vanilla exitGame() autosaves when Ironman is on AND the roster
    // is non-empty. Both can be true after a batch (the last seed's brothers
    // are still in the roster), producing a junk save or - without a map -
    // an exception that stalls the return to the main menu (the suspected
    // reason the first "use this seed" click after a run failed until
    // restart). Clear the roster and force Ironman off before exiting.
    try { job.Roster.clear(); } catch (e) {}
    try { ::World.Assets.m.IsIronman = false; } catch (e) {}
    try
    {
        // This campaign was deliberately never initialized as a playable
        // world. Use the vanilla loading-screen path to dispose it and return
        // to the main menu before normal world updates can resume.
        ::BBSeedTool.ExitHealAttempts = 0;
        ::logWarning("[BBSEED] EXIT_BEGIN");
        worldState.exitGame();
    }
    catch (e)
    {
        ::logWarning("[BBSEED] EXIT_ERROR|" + ::BBSeedTool_Safe(e));
        try
        {
            worldState.m.ExitGame = true;
            worldState.LoadingScreen.show();
        }
        catch (e2) { ::logWarning("[BBSEED] EXIT_FALLBACK_ERROR|" + ::BBSeedTool_Safe(e2)); }
    }
};

// One seed of the running job. Never throws.
::BBSeedTool_StepOne <- function(job)
{
    local seed = ::BBSeedTool_NextSeed(job);
    try
    {
        local record = null;
        if (job.Mode == "talent")
        {
            // TALENT-ONLY mode (v1.49): no map is generated at all. The
            // seedRandomString(seed) inside fully resets the RNG stream, so
            // the brothers rolled here are identical to a full-map run of
            // the same seed; only the port/map columns stay "not recorded".
            // Deserters never reach this branch (rejected at arm time):
            // their brothers spawn in onSpawnPlayer, which needs a map.
            record = ::BBSeedTool_TalentSeed(job, seed);
        }
        else
        {
        // CLEANUP(v1.47): the FIRST seed of a job runs on a fresh world, so
        // it skips ALL cleanup and replicates vanilla exactly. Later seeds
        // run the cleanup below: roster/scene/entity/faction clears plus a
        // clearWorld on a THROWAWAY generator instance (required - v1.46
        // removed it and the game crashed building the second seed's roads).
        // Time events and flags are NOT cleared here: Time.clearEvents from
        // inside a scheduled time event (every step is one) risks native
        // use-after-free, and vanilla only clears them on campaign destroy.
        if (job.Index == 0)
        {
            ::logInfo("[BBSEED] PRISTINE_FIRST_SEED|seed=" + seed);
        }
        else
        {
            ::BBSeedTool_CleanupRoster(job.Roster);
            try { ::World.clearScene(); } catch (e) {}
            try { ::World.EntityManager.clear(); } catch (e) {}
            try { ::World.FactionManager.clear(); } catch (e) {}
            // Cleanup-only clearWorld on a THROWAWAY generator instance. It must
            // never run on the instance that will generate the map (see below).
            // v1.47: this call is REQUIRED for stability. v1.46 removed it and
            // the game crashed hard (native, empty script stack) while building
            // roads for the second seed - clearWorld is an engine-native
            // function that resets the native tile data of the previous map.
            try { ::MapGen.get("world.worldmap_generator").clearWorld(job.Box); } catch (e) {}
            try { job.WorldState.m.Player = null; } catch (e) {}
        }

        job.WorldState.m.CampaignSettings.Seed = seed;

        // FIX(arena): vanilla limits one arena per map via the global counter
        // ::Const.World.Buildings.Arenas (city_state.onBuild only adds an arena
        // while it is 0). The counter is not guaranteed to be cleared between
        // iterations, which made every map after the first one lose its arena.
        // Reset it explicitly so each seed builds like a fresh campaign.
        try { ::Const.World.Buildings.reset(); } catch (e) {}

        // FIX(worldgen, v1.43): from here on, replicate vanilla
        // startNewCampaign instruction-for-instruction. Critically, the
        // worldmap generator is a FRESH instance fetched AFTER seeding, in
        // the exact position vanilla fetches it. Reusing a single instance
        // across seeds let internal generator state leak between iterations,
        // so generated maps (ports / arenas) diverged from a real campaign.
        ::Math.seedRandomString(seed);
        local worldmap = ::MapGen.get("world.worldmap_generator");
        local minX = worldmap.getMinX();
        local minY = worldmap.getMinY();
        ::World.resizeScene(minX, minY);
        worldmap.fill({ X = 0, Y = 0, W = minX, H = minY }, null);

        // Vanilla order continues: Assets.init -> createFactions ->
        // buildRoadAmbushSpots, then the analysis runs on the fully built
        // world, matching what a real new campaign produces for this seed.
        ::World.Assets.init();
        ::World.FactionManager.createFactions();
        ::World.EntityManager.buildRoadAmbushSpots();

        // Analyze only AFTER the world is fully built (was: right after fill).
        local settlementList = ::World.EntityManager.getSettlements();
        local portData = ::BBSeedTool_AnalyzePorts(settlementList);
        ::logWarning("[BBSEED] MAP|seed=" + seed + "|ports=" + portData.count + "|flags=" + portData.flags + "|settlements=" + settlementList.len() + "|detail=" + portData.detail);
        record = {
            seed = seed,
            ports = portData.count,
            portFlags = portData.flags,
            settlements = settlementList.len(),
            bros = []
        };

        // Second RNG reseed, exactly like vanilla, then spawn the brothers.
        ::Math.seedRandomString(seed);
        ::World.Assets.setCampaignSettings(job.WorldState.m.CampaignSettings);
        if (job.Origin == "scenario.deserters") ::BBSeedTool_SpawnDeserters(job);

        local brothers = job.Roster.getAll();
        if (brothers.len() != job.Expected)
            throw "brother_count_mismatch|origin=" + job.Origin + "|expected=" + job.Expected + "|actual=" + brothers.len();
        foreach (i, bro in brothers) record.bros.push(::BBSeedTool_CollectBro(i + 1, bro));
        if (::BBSeedTool.Fast.LogAll) ::logWarning("[BBSEED] SIG|seed=" + seed + "|" + ::BBSeedTool_RecordSig(record));
        }

        if (record == null)
        {
            // dropped by the prefilter: nothing to store
        }
        else if (job.IsBackfill)
        {
            // Backfill rewrites the port data of the EXISTING record in
            // place; batch id, brothers and marks stay untouched.
            if (::BBSeedTool_UpdatePortData(job.Origin, record)) job.Completed++;
            else ::logWarning("[BBSEED] BACKFILL_MISS|origin=" + job.Origin + "|seed=" + seed);
        }
        else
        {
            ::BBSeedTool.Buffer.push(record);
            job.Completed++;
            // v1.79: with a prefilter every stored seed is a rare hit - write it to disk at once.
            if (::BBSeedTool.Buffer.len() >= ::BBSeedTool.BatchSize || ::BBSeedTool.Prefilter != null)
            {
                local prof = ::BBSeedTool.Fast.Profile ? ::BBSeedTool.Prof : null;
                local t = prof != null ? ::Time.getExactTime() : 0.0;
                ::BBSeedTool_CommitBatch();
                if (prof != null) prof.commit += ::Time.getExactTime() - t;
            }
        }
    }
    catch (e)
    {
        ::BBSeedTool.Abort = null;
        ::BBSeedTool.SuppressUpdate = false;
        ::BBSeedTool.SuppressEquip = false;
        ::logWarning("[BBSEED] SKIP|seed=" + seed + "|error=" + ::BBSeedTool_Safe(e));
    }

    // No end-of-step roster cleanup: the next step cleans up before it
    // generates, and FinishJob disposes the whole campaign, so the old
    // trailing cleanup was pure duplicate work.
    job.Index++;
    if (::BBSeedTool.Prof != null) ::BBSeedTool.Prof.seeds++;
};

::BBSeedTool_ReportProgress <- function(job, _force)
{
    local now = ::Time.getExactTime();
    local saved = ::BBSeedTool.TotalSeeds + ::BBSeedTool.Buffer.len();
    if (_force || now - job.LastLog >= 10.0)
    {
        job.LastLog = now;
        local elapsed = now - job.StartTime;
        ::logWarning("[BBSEED] PROGRESS|done=" + job.Index + "|total=" + job.Total + "|saved=" + saved
            + "|hits=" + job.Hits + "|full=" + job.FullHits + "|elapsed=" + elapsed + "|rate=" + (elapsed > 0 ? job.Index / elapsed : 0));
    }
    if (_force || now - job.LastNotify >= 0.5)
    {
        job.LastNotify = now;
        ::BBSeedTool_Notify("bbseedCollectionProgress", { done = job.Index, total = job.Total, saved = saved });
    }
};

::BBSeedTool_Step <- function(_unused = null)
{
    local job = ::BBSeedTool.Job;
    if (job == null) return;
    if (job.StopRequested || job.Index >= job.Total)
    {
        ::BBSeedTool_FinishJob(job.StopRequested);
        return;
    }

    // v1.79: talent-only seeds are cheap, so one step rolls as many as fit in
    // the time budget instead of exactly one per rendered frame. Full-map
    // seeds keep the proven one-seed-per-step rhythm.
    local batch = ::BBSeedTool.Fast.Enabled && job.Mode == "talent";
    if (batch)
    {
        local deadline = ::Time.getExactTime() + ::BBSeedTool.Fast.BudgetSec;
        do
        {
            ::BBSeedTool_StepOne(job);
        }
        while (job.Index < job.Total && ::Time.getExactTime() < deadline);
        ::BBSeedTool_ReportProgress(job, job.Index >= job.Total);
    }
    else
    {
        ::BBSeedTool_StepOne(job);
        if (job.Index % ::BBSeedTool.LogEvery == 0 || job.Index == job.Total) ::BBSeedTool_ReportProgress(job, true);
    }
    if (::BBSeedTool.Prof != null) ::BBSeedTool.Prof.steps++;

    if (job.Index >= job.Total)
    {
        local p = ::BBSeedTool.Prof;
        local elapsed = ::Time.getExactTime() - job.StartTime;
        ::logWarning("[BBSEED] PROFILE|seeds=" + job.Index + "|elapsed=" + elapsed + "|rate=" + (elapsed > 0 ? job.Index / elapsed : 0)
            + "|steps=" + p.steps + "|hits=" + job.Hits + "|full=" + job.FullHits
            + "|clean=" + p.clean + "|init=" + p.init + "|spawn=" + p.spawn + "|collect=" + p.collect + "|commit=" + p.commit
            + "|aborted=" + p.aborted + "|precheck=" + p.precheck + "|kept=" + p.kept);
        ::BBSeedTool_FinishJob(false);
    }
    else ::Time.scheduleEvent(::TimeUnit.Real, 1, ::BBSeedTool_Step, null);
};


::BBSeedTool_Run <- function(_worldState)
{
    if (::BBSeedTool.Job != null)
    {
        ::BBSeedTool_Notify("bbseedCollectionFailed", { error = "A collection is already running." });
        return;
    }
    local scenario = ::BBSeedTool_FindScenario(_worldState);
    if (scenario == null)
    {
        // v1.54: never bail silently - the world state is already entered and
        // would sit half-initialized forever (stuck black screen). Report and
        // dispose it so the player lands back at the main menu.
        ::logWarning("[BBSEED] RUN_ABORT|reason=no_scenario");
        ::BBSeedTool_Notify("bbseedCollectionFailed", { error = "no_scenario" });
        try { _worldState.exitGame(); } catch (e) {}
        return;
    }
    local origin = scenario.getID();
    // v1.49: consume the armed mode. "talent" skips map generation; a
    // non-null PendingBackfill list turns the job into a backfill run that
    // rewrites port data of existing records instead of adding new ones.
    local mode = ::BBSeedTool.PendingMode == "talent" ? "talent" : "full";
    local seedList = ::BBSeedTool.PendingBackfill;
    local isBackfill = seedList != null;
    if (isBackfill) mode = "full";
    ::BBSeedTool.PendingMode = "full";
    ::BBSeedTool.PendingBackfill = null;
    if (mode == "talent" && origin == "scenario.deserters")
    {
        ::BBSeedTool_Notify("bbseedCollectionFailed", { error = "talent_deserters" });
        return;
    }
    local jobTotal = isBackfill ? seedList.len() : ::BBSeedTool.MaxIters;
    ::BBSeedTool.ActiveOrigin = origin;
    ::BBSeedTool.Buffer.clear();
    ::BBSeedTool.CurrentShard.clear();
    ::BBSeedTool.CurrentShardID = 0;
    ::BBSeedTool.CurrentShardSaved = false;
    if (!::BBSeedTool.CatalogLoaded) ::BBSeedTool_LoadCatalog();

    ::logWarning("[BBSEED] RUN|version=" + ::BBSeedTool.Version + "|total=" + jobTotal + "|origin=" + origin + "|mode=" + mode + "|backfill=" + (isBackfill ? "1" : "0"));
    ::BBSeedTool_Notify("bbseedCollectionStarted", { total = jobTotal, origin = origin, mode = mode, backfill = isBackfill });

    local worldmap = ::MapGen.get("world.worldmap_generator");
    local minX = worldmap.getMinX();
    local minY = worldmap.getMinY();

    try { _worldState.setAutoPause(true); } catch (e) {}
    try { ::Time.setVirtualTime(0); } catch (e) {}
    _worldState.m.IsRunningUpdatesWhilePaused = true;
    try { _worldState.setPause(true); } catch (e) {}
    ::Math.seedRandom(::Math.floor(::Time.getRealTime()));
    ::BBSeedTool.Job = {
        WorldState = _worldState,
        Worldmap = worldmap,
        MinX = minX,
        MinY = minY,
        Box = { X = 0, Y = 0, W = minX, H = minY },
        Roster = ::World.getPlayerRoster(),
        Scenario = scenario,
        Origin = origin,
        Expected = ::BBSeedTool_ExpectedBrothers(origin),
        Chars = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"],
        CharCount = 36,
        Index = 0,
        Completed = 0,
        Total = jobTotal,
        Mode = mode,
        IsBackfill = isBackfill,
        SeedList = seedList,
        SeedState = ::BBSeedTool.AutoSeedState != null ? ::BBSeedTool.AutoSeedState : (::Time.getRealTime().tointeger() * 2654435 + ::Math.rand(0, 1000000)),
        LastNotify = 0.0,
        LastLog = 0.0,
        Hits = 0,
        FullHits = 0,
        StartTime = ::Time.getExactTime(),
        StopRequested = false
    };
    ::BBSeedTool_ResetProf();
    local pfText = "none";
    if (::BBSeedTool.Prefilter != null)
    {
        pfText = ::BBSeedTool_PrefilterText(::BBSeedTool.Prefilter.groups);
        if (::BBSeedTool.Prefilter.full != null) pfText += " / full: " + ::BBSeedTool_PrefilterText(::BBSeedTool.Prefilter.full);
        if (::BBSeedTool.Prefilter.alt != null) pfText += " / alt: " + ::BBSeedTool_PrefilterText(::BBSeedTool.Prefilter.alt);
    }
    ::logWarning("[BBSEED] RUNCFG|fast=" + (::BBSeedTool.Fast.Enabled ? "1" : "0") + "|budget=" + ::BBSeedTool.Fast.BudgetSec
        + "|skipInit=" + (::BBSeedTool.Fast.SkipAssetsInit ? "1" : "0") + "|skipPost=" + (::BBSeedTool.Fast.SkipPostSpawn ? "1" : "0")
        + "|earlyAbort=" + (::BBSeedTool.Fast.EarlyAbort ? "1" : "0")
        + "|noUpdate=" + (::BBSeedTool.Fast.NoUpdate ? "1" : "0") + "|noEquip=" + (::BBSeedTool.Fast.NoEquip ? "1" : "0") + "|prefilter=" + pfText + "|seedState=" + ::BBSeedTool.Job.SeedState);
    ::Time.scheduleEvent(::TimeUnit.Real, 1, ::BBSeedTool_Step, null);
};

::mods_registerMod("bb_seed_tool", ::BBSeedTool.Version, "BB Seed Tool");
::mods_registerJS("bb_seed_tool/seed_tool.js");
::mods_registerCSS("bb_seed_tool/seed_tool.css");

::mods_queue("bb_seed_tool", null, function()
{
    ::logInfo("[BBSEED] INIT|version=" + ::BBSeedTool.Version);
    ::BBSeedTool_LoadSettings();
    ::BBSeedTool_LoadLanguage();
    ::BBSeedTool_LoadMarks();
    ::BBSeedTool_LoadCatalog();

    ::mods_hookExactClass("ui/screens/menu/modules/main_menu_module", function(o)
    {
        local oldCreate = o.create;
        o.create = function()
        {
            oldCreate();
            ::BBSeedTool.UIBackend = this;
            // v1.57: the menu module being (re)built is the observable signal
            // that the game returned to the main menu after a job's exitGame.
            ::logWarning("[BBSEED] MENU_MODULE_READY");
        };

        o.bbseedGetStatus <- function() { return ::BBSeedTool_Status(); };
        o.bbseedGetTraitOptions <- function() { return ::BBSeedTool_GetTraitOptions(); };
        o.bbseedQuery <- function(_filter) { return ::BBSeedTool_Query(_filter); };
        o.bbseedLegacySouth <- function() { return ::BBSeedTool_LegacySouthGroups(); };
        o.bbseedSetCount <- function(_data)
        {
            local n = ::BBSeedTool_Number(_data, "count", 100);
            if (n < 1) n = 1;
            if (n > 300000) n = 300000;
            ::BBSeedTool.MaxIters = n;
            ::BBSeedTool_SaveSettings();
            return ::BBSeedTool_Status();
        };
        o.bbseedSetLanguage <- function(_data)
        {
            local language = "zh";
            try { language = _data.language; } catch (e) {}
            if (language != "en") language = "zh";
            ::BBSeedTool.Language = language;
            ::BBSeedTool_SaveLanguage();
            return ::BBSeedTool_Status();
        };
        o.bbseedArmCollection <- function(_data)
        {
            if (::BBSeedTool.Job != null)
            {
                ::logWarning("[BBSEED] ARM|ok=0|error=busy");
                return { ok = false, error = "A collection is already running." };
            }
            local origin = "";
            local mode = "full";
            try { origin = _data.origin; } catch (e) {}
            try { mode = _data.mode; } catch (e) {}
            if (mode != "talent") mode = "full";
            if (::BBSeedTool.SupportedOrigins.find(origin) == null)
            {
                ::logWarning("[BBSEED] ARM|ok=0|error=unknown_origin|origin=" + ::BBSeedTool_Safe(origin));
                return { ok = false, error = "Choose one concrete origin before starting." };
            }
            if (mode == "talent" && origin == "scenario.deserters")
            {
                ::logWarning("[BBSEED] ARM|ok=0|error=talent_deserters");
                return { ok = false, error = "talent_deserters" };
            }
            ::BBSeedTool.PendingCollection = true;
            ::BBSeedTool.PendingOrigin = origin;
            ::BBSeedTool.PendingMode = mode;
            ::BBSeedTool.PendingBackfill = null;
            ::logWarning("[BBSEED] ARM|ok=1|origin=" + origin + "|mode=" + mode);
            return { ok = true, origin = origin, total = ::BBSeedTool.MaxIters, mode = mode };
        };
        o.bbseedArmBackfill <- function(_data)
        {
            if (::BBSeedTool.Job != null)
            {
                ::logWarning("[BBSEED] ARM_BACKFILL|ok=0|error=busy");
                return { ok = false, error = "A collection is already running." };
            }
            local origin = "";
            try { origin = _data.origin; } catch (e) {}
            if (::BBSeedTool.SupportedOrigins.find(origin) == null)
            {
                ::logWarning("[BBSEED] ARM_BACKFILL|ok=0|error=unknown_origin|origin=" + ::BBSeedTool_Safe(origin));
                return { ok = false, error = "Unknown origin." };
            }
            local seeds = [];
            try
            {
                foreach (seed in _data.seeds)
                {
                    local text = ::BBSeedTool_Safe(seed);
                    if (text.len() > 0) seeds.push(text);
                }
            }
            catch (e) {}
            if (seeds.len() == 0)
            {
                ::logWarning("[BBSEED] ARM_BACKFILL|ok=0|error=no_seeds");
                return { ok = false, error = "No seeds to backfill." };
            }
            ::BBSeedTool.PendingCollection = true;
            ::BBSeedTool.PendingOrigin = origin;
            ::BBSeedTool.PendingMode = "full";
            ::BBSeedTool.PendingBackfill = seeds;
            ::logWarning("[BBSEED] ARM_BACKFILL|ok=1|origin=" + origin + "|seeds=" + seeds.len());
            return { ok = true, origin = origin, total = seeds.len() };
        };
        o.bbseedSetMode <- function(_data)
        {
            local mode = "full";
            try { mode = _data.mode; } catch (e) {}
            if (mode != "talent") mode = "full";
            ::BBSeedTool.CollectionMode = mode;
            ::BBSeedTool_SaveSettings();
            return { ok = true, mode = mode };
        };
        o.bbseedCleanupPrecheck <- function(_data)
        {
            return ::BBSeedTool_CleanupTalent(false);
        };
        o.bbseedCleanupTalent <- function(_data)
        {
            // v1.51: refuse to delete while a job is running - the job
            // rewrites shard files on every batch commit, so a mid-run
            // cleanup could lose freshly written records or resurrect
            // deleted ones depending on timing.
            if (::BBSeedTool.Job != null) return { ok = false, error = "A collection is already running.", deleted = 0 };
            local result = ::BBSeedTool_CleanupTalent(true);
            return { ok = true, deleted = result.total };
        };
        o.bbseedWipePrecheck <- function(_data)
        {
            return ::BBSeedTool_WipeAll(false);
        };
        o.bbseedWipeAll <- function(_data)
        {
            // Same guard as cleanup: never wipe mid-run, the job rewrites
            // shard files on every batch commit.
            if (::BBSeedTool.Job != null) return { ok = false, error = "A collection is already running.", deleted = 0 };
            local result = ::BBSeedTool_WipeAll(true);
            return { ok = true, deleted = result.total };
        };
        o.bbseedExportMarked <- function(_data)
        {
            if (::BBSeedTool.Job != null) return { ok = false, error = "A collection is already running.", total = 0 };
            // v1.71: optional overwrite target, must name an export file.
            local target = "";
            try { target = _data.target; } catch (e) {}
            if (target == null) target = "";
            if (target != "" && !::BBSeedTool_StartsWith(target, ::BBSeedTool.ExportPrefix)) return { ok = false, error = "bad file", total = 0 };
            return ::BBSeedTool_ExportMarked(target);
        };
        o.bbseedImportList <- function(_data)
        {
            return ::BBSeedTool_ImportList();
        };
        o.bbseedImport <- function(_data)
        {
            if (::BBSeedTool.Job != null) return { ok = false, error = "A collection is already running." };
            local file = "";
            try { file = _data.file; } catch (e) {}
            if (file == "" || !::BBSeedTool_StartsWith(file, ::BBSeedTool.ExportPrefix)) return { ok = false, error = "bad file" };
            return ::BBSeedTool_ImportFile(file);
        };
        o.bbseedDisarmCollection <- function(_data)
        {
            if (::BBSeedTool.Job == null)
            {
                ::BBSeedTool.PendingCollection = false;
                ::BBSeedTool.PendingOrigin = "";
                ::BBSeedTool.PendingMode = "full";
                ::BBSeedTool.PendingBackfill = null;
            }
            return { ok = true };
        };
        o.bbseedCheckExit <- function(_data)
        {
            // v1.58: self-heal for "stuck in the world after a job". The JS
            // side calls this a few seconds after bbseedCollectionFinished.
            // ReturningWorldState is cleared by the world state's onFinish,
            // so a non-null value means the vanilla exit chain (exitGame ->
            // loading screen shown event -> AboutToFinish -> menu) dropped a
            // message and the world was never disposed. Log proof from the
            // field: the loading screen's shown event never arrived for the
            // throwaway world, and LoadingScreen is not reachable from
            // outside the instance (v1.57's heal died on that access).
            // Retry ladder: first re-call vanilla exitGame() (idempotent -
            // the roster is already cleared and Ironman already off), then
            // escalate to delivering AboutToFinish directly, which is exactly
            // what the loading screen's shown callback would have done.
            if (::BBSeedTool.ReturningWorldState == null) return { ok = true };
            local ws = ::BBSeedTool.ReturningWorldState;
            ::BBSeedTool.ExitHealAttempts++;
            ::logWarning("[BBSEED] EXIT_HEAL|attempt=" + ::BBSeedTool.ExitHealAttempts);
            if (::BBSeedTool.ExitHealAttempts < 2)
            {
                try { ws.exitGame(); } catch (e) { ::logWarning("[BBSEED] EXIT_HEAL_ERROR|" + ::BBSeedTool_Safe(e)); }
            }
            else
            {
                try { ws.m.ExitGame = true; } catch (e) {}
                try { ws.sendMessageToSiblings("AboutToFinish"); } catch (e) { ::logWarning("[BBSEED] EXIT_HEAL_ERROR|" + ::BBSeedTool_Safe(e)); }
            }
            return { ok = false };
        };
        o.bbseedAutoNext <- function(_data) { return ::BBSeedTool_AutoNext(_data); };
        o.bbseedAutoReady <- function(_data)
        {
            return { ready = ::BBSeedTool.Job == null && ::BBSeedTool.ReturningWorldState == null && !::BBSeedTool.PendingCollection };
        };
        o.bbseedStop <- function(_data)
        {
            if (::BBSeedTool.Job != null) ::BBSeedTool.Job.StopRequested = true;
            return { running = ::BBSeedTool.Job != null };
        };
        // v1.53: lets the JS side drop diagnostic lines into log.html, so
        // UI-layer failures (which never reach the Squirrel log otherwise)
        // become visible after the fact.
        o.bbseedLog <- function(_data)
        {
            local message = "";
            try { message = _data.message; } catch (e) {}
            ::logWarning("[BBSEED-UI] " + ::BBSeedTool_Safe(message));
            return { ok = true };
        };
        o.bbseedToggleMark <- function(_data)
        {
            local origin = "";
            local seed = "";
            try { origin = _data.origin; } catch (e) {}
            try { seed = _data.seed; } catch (e) {}
            if (origin == "" || seed == "") return { ok = false, marked = false };
            return { ok = true, marked = ::BBSeedTool_ToggleMark(origin, seed) };
        };
        o.bbseedReportUIReady <- function(_data)
        {
            local testRecord = { bros = [{ traits = "strong" }, { traits = "tiny,huge" }] };
            local anyBrotherMatch = ::BBSeedTool_RecordHasTrait(testRecord, "huge");
            local missingTraitMatch = ::BBSeedTool_RecordHasTrait(testRecord, "drunkard");
            local negativeDetected = ::BBSeedTool_BroHasNegativeTrait({ traits = "strong,asthmatic" });
            local cleanDetected = ::BBSeedTool_BroHasNegativeTrait({ traits = "strong,huge" });
            local portRecord = { portFlags = ::BBSeedTool.PortFlagKnown | ::BBSeedTool.PortFlagNorth | ::BBSeedTool.PortFlagSouth | ::BBSeedTool.PortFlagArena
                | ::BBSeedTool.PortFlagNorth50 | ::BBSeedTool.PortFlagNorth65 | ::BBSeedTool.PortFlagNorth80 };
            // Has South + a class-based north port but NO port north of the
            // 80% line: must pass at line 50/65 and fail at line 80.
            local fringeRecord = { portFlags = ::BBSeedTool.PortFlagKnown | ::BBSeedTool.PortFlagNorth | ::BBSeedTool.PortFlagSouth
                | ::BBSeedTool.PortFlagNorth50 | ::BBSeedTool.PortFlagNorth65 };
            local unknownPortRecord = { portFlags = 0 };
            ::logWarning("[BBSEED] TRAIT_FILTER_SELFTEST|any_brother=" + (anyBrotherMatch ? "1" : "0") + "|missing=" + (missingTraitMatch ? "1" : "0"));
            // v1.65: prove the global split() works in this client.
            // v1.66: AND must apply at brother granularity - traits spread
            // across two brothers must NOT match; on one brother they must.
            // v1.67: stars and traits together must also concentrate on ONE
            // brother (tested through the full RecordMatches path).
            try
            {
                local sameBroPass = ::BBSeedTool_RecordHasAllTraits(testRecord, split("huge,tiny", ","));
                local spreadRecord = { bros = [{ traits = "huge" }, { traits = "paranoid" }] };
                local spreadReject = !::BBSeedTool_RecordHasAllTraits(spreadRecord, split("huge,paranoid", ","));
                local missingReject = !::BBSeedTool_RecordHasAllTraits(testRecord, split("huge,drunkard", ","));
                local singleSame = ::BBSeedTool_RecordHasAllTraits(testRecord, split("huge", ",")) == anyBrotherMatch;
                // star on bro1, trait on bro2 -> must NOT match
                local splitBroRecord = { ports = 0, origin = "", bros = [
                    { slot = 1, traits = "", hp = 60, msk = 70, rsk = 40, mdf = 10, rdf = 5, fat = 100, res = 40, init = 100, smsk = 3, smdf = 0, srsk = 0 },
                    { slot = 2, traits = "huge", hp = 60, msk = 50, rsk = 40, mdf = 10, rdf = 5, fat = 100, res = 40, init = 100, smsk = 0, smdf = 0, srsk = 0 }
                ] };
                local starFilter = { quickTrait = "huge", smsk = 3 };
                local starSplitReject = !::BBSeedTool_RecordMatches(splitBroRecord, starFilter);
                // star AND trait on the same brother -> must match
                local sameBroRecord = { ports = 0, origin = "", bros = [
                    { slot = 1, traits = "huge", hp = 60, msk = 70, rsk = 40, mdf = 10, rdf = 5, fat = 100, res = 40, init = 100, smsk = 3, smdf = 0, srsk = 0 }
                ] };
                local starSamePass = ::BBSeedTool_RecordMatches(sameBroRecord, starFilter);
                ::logWarning("[BBSEED] MULTI_TRAIT_SELFTEST|same_bro_pass=" + (sameBroPass ? "1" : "0")
                    + "|spread_reject=" + (spreadReject ? "1" : "0")
                    + "|missing_reject=" + (missingReject ? "1" : "0")
                    + "|single_same=" + (singleSame ? "1" : "0")
                    + "|star_split_reject=" + (starSplitReject ? "1" : "0")
                    + "|star_same_pass=" + (starSamePass ? "1" : "0"));
            }
            catch (e) { ::logWarning("[BBSEED] MULTI_TRAIT_SELFTEST|error=" + ::BBSeedTool_Safe(e)); }
            ::logWarning("[BBSEED] NO_NEGATIVE_SELFTEST|negative=" + (negativeDetected ? "1" : "0") + "|clean=" + (!cleanDetected ? "1" : "0"));
            ::logWarning("[BBSEED] PORT_FILTER_SELFTEST|south_north=" + (::BBSeedTool_HasSouthNorthPorts(portRecord, 80) ? "1" : "0")
                + "|arena=" + (::BBSeedTool_HasPortFlag(portRecord, ::BBSeedTool.PortFlagArena) ? "1" : "0")
                + "|fringe_passes_50=" + (::BBSeedTool_HasSouthNorthPorts(fringeRecord, 50) ? "1" : "0")
                + "|fringe_passes_65=" + (::BBSeedTool_HasSouthNorthPorts(fringeRecord, 65) ? "1" : "0")
                + "|fringe_rejected_80=" + (!::BBSeedTool_HasSouthNorthPorts(fringeRecord, 80) ? "1" : "0")
                + "|unknown_rejected=" + (!::BBSeedTool_HasSouthNorthPorts(unknownPortRecord, 80) ? "1" : "0"));
            ::logWarning("[BBSEED] UI_READY|version=" + ::BBSeedTool.Version + "|storage=" + ::BBSeedTool.TotalSeeds);
        };
    });

    ::mods_hookExactClass("states/world_state", function(o)
    {
        // The seed collector intentionally owns a half-initialized WorldState.
        // Vanilla onUpdate would interpret its empty roster as game over, and
        // vanilla rendering would touch scene objects that do not exist yet.
        local oldOnProcessInThread = o.onProcessInThread;
        o.onProcessInThread = function()
        {
            if (::BBSeedTool_BlocksWorldState(this)) return;
            oldOnProcessInThread();
        };

        local oldOnUpdate = o.onUpdate;
        o.onUpdate = function()
        {
            if (::BBSeedTool_BlocksWorldState(this)) return;
            oldOnUpdate();
        };

        local oldOnRender = o.onRender;
        o.onRender = function()
        {
            if (::BBSeedTool_BlocksWorldState(this)) return;
            oldOnRender();
        };

        local oldOnMouseInput = o.onMouseInput;
        o.onMouseInput = function(_mouse)
        {
            if (this.m.Player == null)
            {
                // v1.56: half-entered / seed-job world. v1.55 swallowed the
                // whole handler here - including Cursor.setPosition, which
                // froze the native cursor while the real mouse kept moving
                // invisibly. Keep vanilla's cursor tracking, swallow every
                // world interaction that would dereference the missing
                // player entity (the native crash at world_state.nut:2824).
                if (this.isInLoadingScreen()) return true;
                if (_mouse.getID() == 6) this.Cursor.setPosition(_mouse.getX(), _mouse.getY());
                return true;
            }
            return oldOnMouseInput(_mouse);
        };

        local oldOnFinish = o.onFinish;
        o.onFinish = function()
        {
            ::logWarning("[BBSEED] WORLD_DISPOSED");
            if (::BBSeedTool.Job != null && ::BBSeedTool.Job.WorldState == this)
            {
                try { ::BBSeedTool_CommitBatch(); } catch (e) {}
                ::BBSeedTool.Job = null;
            }
            if (::BBSeedTool.ReturningWorldState == this) ::BBSeedTool.ReturningWorldState = null;
            oldOnFinish();
        };

        // v1.58: observe whether the exit loading screen's shown event ever
        // fires - field logs show the exit chain stalls exactly here.
        local oldLoadingShown = o.loading_screen_onScreenShown;
        o.loading_screen_onScreenShown = function()
        {
            ::logWarning("[BBSEED] LOADING_SHOWN|exit=" + (this.m.ExitGame ? "1" : "0"));
            oldLoadingShown();
        };

        local oldStart = o.startNewCampaign;
        o.startNewCampaign = function()
        {
            // v1.55: always log the entry so the log shows whether a world
            // entry completed and which branch (collection vs real) it took.
            ::logWarning("[BBSEED] START|pending=" + (::BBSeedTool.PendingCollection ? "1" : "0"));
            if (::BBSeedTool.PendingCollection)
            {
                ::BBSeedTool.PendingCollection = false;
                local requestedOrigin = ::BBSeedTool.PendingOrigin;
                ::BBSeedTool.PendingOrigin = "";
                try { ::BBSeedTool_Run(this); }
                catch (e)
                {
                    ::logWarning("[BBSEED] ERROR|message=" + ::BBSeedTool_Safe(e) + "|requested_origin=" + requestedOrigin);
                    ::BBSeedTool_Notify("bbseedCollectionFailed", { error = ::BBSeedTool_Safe(e) });
                }
                return;
            }
            // A real campaign is starting. Reset the global building
            // counters first: vanilla gets a fresh process per campaign and
            // never needs this, but a seed-collection job in the same
            // process may have left them dirty.
            try { ::Const.World.Buildings.reset(); } catch (e) {}
            oldStart();
        };
    });

    // v1.52: make character_background.buildDescription() survive a mapless
    // world. Talent-only collection generates no map, so the settlement
    // lists are empty and vanilla crashes on villages[rand]/northern[0]
    // with "the index '0' does not exist" - the real reason talent-only
    // mode produced zero seeds (the crash happens INSIDE
    // setStartValuesEx(), mid RNG-stream). This override preserves the
    // EXACT random-call sequence of vanilla: every town pick in vanilla
    // consumes exactly one Math.rand draw, so when the source list is
    // empty we burn one dummy draw and use an empty string. Brother
    // stats/traits/talents therefore stay identical to a real campaign of
    // the same seed; only the discarded description text differs. When a
    // map DOES exist (full mode, real gameplay) the original runs
    // unchanged.
    // v1.79 early abort. fillAttributeLevelUpValues() is the LAST statement
    // of the vanilla brother roll (talent stars are already final), and runs
    // before the expensive perk-tree build of the same brother. While a
    // prefiltered talent job is rolling, count how many brothers can still
    // reach the melee-attack threshold; once the seed can no longer supply
    // enough of them, abandon it. Outside such a job this is a no-op.
    ::mods_hookExactClass("entity/tactical/player", function(o)
    {
        local oldFillLevelUps = o.fillAttributeLevelUpValues;
        o.fillAttributeLevelUpValues = function( _amount, _maxOnly = false, _minOnly = false )
        {
            oldFillLevelUps(_amount, _maxOnly, _minOnly);
            local st = ::BBSeedTool.Abort;
            if (st == null || _amount < 2) return;
            st.seen++;
            local stars = 0;
            try { stars = this.m.Talents[st.idx]; } catch (e) {}
            local projected = this.m.CurrentProperties.getMeleeSkill() + 20 + stars * 5;
            local remaining = st.expected - st.seen;
            foreach (e in st.list)
            {
                if (projected >= e.atk) e.count++;
                if (e.count + remaining < e.need)
                {
                    st.aborted = true;
                    throw "bbseed_abort";
                }
            }
        };

        // The talent roll reads per-brother star weights that traits and the
        // background set while properties are recomputed. A fast roll runs
        // with that recomputation switched off (see below), so do the ONE
        // refresh vanilla performs right before rolling the talents. The
        // perk-tree build that follows reads the same refreshed state.
        local oldFillTalents = o.fillTalentValues;
        o.fillTalentValues = function()
        {
            if (::BBSeedTool.SuppressUpdate)
            {
                ::BBSeedTool.SuppressUpdate = false;
                this.m.Skills.update();
                this.m.Hitpoints = this.m.CurrentProperties.Hitpoints;
                ::BBSeedTool.SuppressUpdate = true;
            }
            oldFillTalents();
        };
    });

    // v1.79: adding a skill or equipping an item makes the game recompute
    // ALL properties of the brother - about 44 times per starting brother,
    // which is where most of the time of a roll goes. None of those
    // intermediate results is used by the roll itself, so a fast talent-only
    // job switches the recomputation off while the origin spawns its
    // brothers (one refresh per brother is done right before the talent roll, and the
    // final values are recomputed before they are read). SuppressEquip
    // additionally skips putting the starting gear on (experimental).
    ::mods_hookExactClass("skills/skill_container", function(o)
    {
        local oldUpdate = o.update;
        o.update = function()
        {
            if (::BBSeedTool.SuppressUpdate)
            {
                // Light refresh: no skill is evaluated, but every equipped
                // item still sees its property callback exactly once, in slot
                // order. Item mods may roll random numbers in there, and the
                // roll of the NEXT brother depends on how many were drawn.
                if (this.m.IsUpdating) return;
                local slots = this.m.Actor.getItems().m.Items;
                local scratch = ::BBSeedTool.ScratchProps;
                for (local s = ::Const.ItemSlot.Mainhand; s <= ::Const.ItemSlot.Ammo; s++)
                {
                    foreach (item in slots[s])
                    {
                        if (item == null || item == -1) continue;
                        if (scratch == null) scratch = ::BBSeedTool.ScratchProps = this.m.Actor.getBaseProperties().getClone();
                        item.onUpdateProperties(scratch);
                    }
                }
                return;
            }
            oldUpdate();
        };
    });
    ::mods_hookExactClass("items/item_container", function(o)
    {
        local oldEquip = o.equip;
        o.equip = function( _item )
        {
            if (::BBSeedTool.SuppressEquip) return true;
            return oldEquip(_item);
        };
    });

    ::mods_hookExactClass("skills/backgrounds/character_background", function(o)
    {
        local oldBuildDescription = o.buildDescription;
        o.buildDescription = function( _isFinal = false )
        {
            if (this.m.IsScenarioOnly) return;
            local villages = this.World.EntityManager.getSettlements();
            if (villages.len() != 0)
            {
                oldBuildDescription(_isFinal);
                return;
            }
            // Mapless path: mirror vanilla draw-for-draw. Vanilla order:
            // brother(1) townname(1) randomtown(1) randomcity(0!)
            // randomcitystate(1, city-states always exist on a real map)
            // randomname(1) randomnoble(1) randomvizier(2).
            local brother = this.World.getPlayerRoster().getAll();
            brother = brother.len() != 0 ? brother[this.Math.rand(0, brother.len() - 1)].getName() : "";
            this.Math.rand(0, 1); // townname draw
            this.Math.rand(0, 1); // randomtown draw
            this.Math.rand(0, 1); // randomcitystate draw
            local vars = [
                [ "townname", "" ],
                [ "randomtown", "" ],
                [ "randomcity", "" ],
                [ "randomcitystate", "" ],
                [ "randomname", this.Const.Strings.CharacterNames[this.Math.rand(0, this.Const.Strings.CharacterNames.len() - 1)] ],
                [ "randomnoble", this.Const.Strings.KnightNames[this.Math.rand(0, this.Const.Strings.KnightNames.len() - 1)] ],
                [ "randomvizier", this.Const.Strings.SouthernNames[this.Math.rand(0, this.Const.Strings.SouthernNames.len() - 1)] + " " + this.Const.Strings.VizierTitles[this.Math.rand(0, this.Const.Strings.VizierTitles.len() - 1)] ],
                [ "companyname", this.World.Assets.getName() ],
                [ "randombrother", brother ]
            ];
            this.onPrepareVariables(vars);
            if (!_isFinal)
            {
                this.m.RawDescription = this.buildTextFromTemplate(this.onBuildDescription(), vars);
            }
            vars.push([ "name", this.getContainer().getActor().getNameOnly() ]);
            vars.push([ "fullname", this.getContainer().getActor().getName() ]);
            vars.push([ "title", this.getContainer().getActor().getTitle() ]);
            this.m.Description = this.buildTextFromTemplate(this.m.RawDescription, vars);
        };
    });
});
