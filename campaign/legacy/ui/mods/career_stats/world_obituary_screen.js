var CareerStats = {
	ID : "mod_career_stats"
};

// Atlas pre-loading
CareerStats.PortraitAtlas = null;
CareerStats.PortraitAtlasGray = null;
CareerStats.PortraitAtlasLoaded = false;
CareerStats.PortraitAtlasGrayLoaded = false;

CareerStats.loadAtlas = function()
{
	if (CareerStats.PortraitAtlas !== null) return;
	CareerStats.PortraitAtlas = new Image();
	CareerStats.PortraitAtlas.onload = function() {
		CareerStats.PortraitAtlasLoaded = true;
	};
	CareerStats.PortraitAtlas.src = 'coui://gfx/portraits/portrait_atlas.png';

	CareerStats.PortraitAtlasGray = new Image();
	CareerStats.PortraitAtlasGray.onload = function() {
		CareerStats.PortraitAtlasGrayLoaded = true;
	};
	CareerStats.PortraitAtlasGray.src = 'coui://gfx/portraits/portrait_desaturate_atlas.png';
};

// Composite portrait from Appearance brush names using canvas
CareerStats.renderPortraitFromAppearance = function(appearance, container, statusType)
{
	if (!appearance || typeof CareerStats_SpriteMap === 'undefined') return false;

	// Layer order: body → tattoo_body → head → tattoo_head → beard → beard_top → hair
	var layerOrder = ['body', 'tattoo_body', 'head', 'tattoo_head',
		'permanent_injury_1', 'permanent_injury_2', 'permanent_injury_3', 'permanent_injury_4',
		'beard', 'beard_top', 'hair'];

	// Нежить (тело bust_skeleton_*): человеческие слои травм (напр. «травма мозга»,
	// «выколотый глаз») на скелете/мумии/некросаванте смотрятся чужеродно — пропускаем их.
	var isUndead = (appearance['body'] || '').indexOf('bust_skeleton') === 0;

	// Collect valid layers
	var layers = [];
	for (var i = 0; i < layerOrder.length; i++)
	{
		var key = layerOrder[i];
		if (isUndead && key.indexOf('permanent_injury') === 0) continue;
		var brushName = appearance[key];
		if (!brushName || brushName === '') continue;
		var sprite = CareerStats_SpriteMap[brushName];
		if (!sprite) continue;
		layers.push(sprite);
	}

	if (layers.length === 0) return false;

	// Determine canvas size from body sprite (or first available)
	var bodyBrush = appearance['body'] || '';
	var isSouthern = bodyBrush.indexOf('southern') >= 0;
	var canvasW = isSouthern ? 140 : 104;
	var canvasH = isSouthern ? 248 : 142;

	var canvas = document.createElement('canvas');
	canvas.width = canvasW;
	canvas.height = canvasH;
	var ctx = canvas.getContext('2d');

	var isFallen = statusType === 'fallen';
	var useAtlas = isFallen ? CareerStats.PortraitAtlasGray : CareerStats.PortraitAtlas;
	var atlasReady = isFallen ? CareerStats.PortraitAtlasGrayLoaded : CareerStats.PortraitAtlasLoaded;

	if (!useAtlas || !atlasReady)
	{
		var retryCount = 0;
		var retry = setInterval(function() {
			retryCount++;
			var ready = isFallen ? CareerStats.PortraitAtlasGrayLoaded : CareerStats.PortraitAtlasLoaded;
			if (ready || retryCount > 20) {
				clearInterval(retry);
				if (ready) {
					var a = isFallen ? CareerStats.PortraitAtlasGray : CareerStats.PortraitAtlas;
					CareerStats._drawLayers(canvas, ctx, layers, canvasW, canvasH, a);
				}
			}
		}, 100);
		container.append(canvas);
		return true;
	}

	CareerStats._drawLayers(canvas, ctx, layers, canvasW, canvasH, useAtlas);
	container.append(canvas);
	return true;
};

CareerStats._drawLayers = function(canvas, ctx, layers, canvasW, canvasH, atlas)
{
	ctx.clearRect(0, 0, canvasW, canvasH);

	for (var i = 0; i < layers.length; i++)
	{
		var s = layers[i];
		var dx = Math.round((canvasW - s.w) / 2);
		var dy = Math.round((canvasH - s.h) / 2);
		try {
			ctx.drawImage(atlas, s.x, s.y, s.w, s.h, dx, dy, s.w, s.h);
		} catch(e) {}
	}
};

// ── Sorting state ────────────────────────────────────────────────
CareerStats._sortColumn = null;   // current sort key or null (default order)
CareerStats._sortAsc = false;     // descending by default for numbers
CareerStats._entries = [];        // stored entries for re-sorting
CareerStats._screenRef = null;    // reference to the screen instance
CareerStats._aliveOnly = false;   // фильтр «только живые» (без пересчёта Rank)

CareerStats._sortKeys = {
	'name':   function(e) { return (e.NameOnly || e.Name || '').toLowerCase(); },
	'rating': function(e) { return e.Rank !== undefined ? e.Rank : 9999; },
	'level':  function(e) { return e.Level || 0; },
	'dps':    function(e) { return (e.DPSHp || 0) + (e.DPSArmor || 0); },
	'hit':    function(e) { return CareerStats.rateValue(e, 'Hit'); },
	'days':   function(e) { return e.TimeWithCompany || 0; },
	'kills':  function(e) { return e.Kills || 0; },
	'status': function(e) { return e.StatusType || ''; }
};

// ── Сглаженные точность / уклонение ─────────────────────────────
// Окно рейтинга показывает сглаженные значения (как в расчёте места).
// Пока попыток меньше порога (STRENGTH2_RAMP_FULL, 50) — значение ещё
// «устаканивается»: показываем «~NN%» серым. Нет статистики — «—».
// _kind: 'Hit' или 'Dodge'.
CareerStats.rateValue = function(e, _kind)
{
	var v = e[_kind + 'Smoothed'];
	if (v === undefined || v === null) v = (_kind === 'Hit') ? e.HitChance : e.DodgeChance;  // старые данные
	if ((e[_kind + 'Attempts'] !== undefined) && e[_kind + 'Attempts'] < 0) return -1;      // без статистики — в конец сортировки
	return v || 0;
};

CareerStats.rateInfo = function(e, _kind)
{
	var n = e[_kind + 'Attempts'];
	if (n !== undefined && n < 0) return { text: '\u2014', unproven: true };
	var v = CareerStats.rateValue(e, _kind);
	var proven = (e[_kind + 'Proven'] === undefined) ? true : !!e[_kind + 'Proven'];
	var pct = Math.round(v * 100) + '%';
	return { text: proven ? pct : '~' + pct, unproven: !proven };
};

CareerStats.sortAndRender = function()
{
	if (!CareerStats._screenRef) return;

	var entries = CareerStats._entries.slice(); // copy

	// Фильтр «только живые»: просто скрываем выбывших, места (Rank) не пересчитываются
	if (CareerStats._aliveOnly)
		entries = entries.filter(function(e) { return e.StatusType === 'alive'; });

	if (CareerStats._sortColumn && CareerStats._sortKeys[CareerStats._sortColumn])
	{
		var keyFn = CareerStats._sortKeys[CareerStats._sortColumn];
		var asc = CareerStats._sortAsc;

		entries.sort(function(a, b) {
			var va = keyFn(a);
			var vb = keyFn(b);
			if (typeof va === 'string') {
				var cmp = va.localeCompare(vb);
				return asc ? cmp : -cmp;
			}
			return asc ? (va - vb) : (vb - va);
		});
	}

	// Re-render
	var screen = CareerStats._screenRef;
	screen.mListScrollContainer.empty();
	for (var i = 0; i < entries.length; i++)
		screen.addListEntry(entries[i]);

	// Update header arrows
	$('.world-obituary-screen .hof-hdr').each(function() {
		$(this).removeClass('hof-sort-active');
		$(this).find('.hof-sort-arrow').remove();
	});

	if (CareerStats._sortColumn)
	{
		var activeHdr = $('.world-obituary-screen .hof-hdr-' + CareerStats._sortColumn);
		activeHdr.addClass('hof-sort-active');
		var arrow = CareerStats._sortAsc ? '\u25B2' : '\u25BC';
		activeHdr.append('<span class="hof-sort-arrow">' + arrow + '</span>');
	}
};

// ── Фильтр «только живые» ───────────────────────────────────────
// Нарисованная вручную галочка в стиле UI игры (без зависимости от iCheck)
CareerStats.buildAliveOnlyCheckbox = function(isRu)
{
	// Переключатель-точка: пустой кружок — выкл., кружок с точкой — вкл.
	var wrap = $('<div class="hof-alive-filter"/>').css({
		'display': 'flex', 'flex-direction': 'row', 'align-items': 'center',
		'cursor': 'pointer', 'user-select': 'none'
	});
	var ring = $('<div class="hof-alive-ring"/>').css({
		'position': 'relative', 'width': '1.4rem', 'height': '1.4rem', 'flex-shrink': '0',
		'border': '1px solid #c8b870', 'border-radius': '50%',
		'background-color': 'rgba(0,0,0,0.45)', 'margin-right': '0.5rem'
	});
	var dot = $('<div class="hof-alive-dot"/>').css({
		'position': 'absolute', 'left': '50%', 'top': '50%',
		'width': '0.7rem', 'height': '0.7rem', 'margin-left': '-0.35rem', 'margin-top': '-0.35rem',
		'border-radius': '50%', 'background-color': '#ffcc00',
		'box-shadow': '0 0 3px rgba(255,204,0,0.8)', 'display': 'none'
	});
	ring.append(dot);
	var label = $('<div class="text-font-normal"/>')
		.text(isRu ? 'Только живые' : '仅在役')
		.css({ 'color': '#c8b870', 'font-size': '1.4rem' });

	var refresh = function(hover) {
		var on = CareerStats._aliveOnly;
		dot.css('display', on ? 'block' : 'none');
		var c = (on || hover) ? '#ffcc00' : '#c8b870';
		ring.css('border-color', c);
		label.css('color', c);
	};
	refresh(false);

	wrap.on('click', function() {
		CareerStats._aliveOnly = !CareerStats._aliveOnly;
		refresh(true);
		CareerStats.sortAndRender();
		if (CareerStats.TierList._visible) CareerStats.TierList.render();
	});
	wrap.on('mouseenter', function() { refresh(true); });
	wrap.on('mouseleave', function() { refresh(false); });

	wrap.append(ring).append(label);
	return wrap;
};

CareerStats.onHeaderClick = function(column)
{
	if (CareerStats._sortColumn === column)
	{
		// Toggle direction, or reset on third click
		if (!CareerStats._sortAsc)
			CareerStats._sortAsc = true;
		else
		{
			// Reset to default
			CareerStats._sortColumn = null;
			CareerStats._sortAsc = false;
		}
	}
	else
	{
		CareerStats._sortColumn = column;
		// Name and status sort ascending by default, numbers descending
		CareerStats._sortAsc = (column === 'name' || column === 'status' || column === 'rating');
	}

	CareerStats.sortAndRender();
};

CareerStats.resetSort = function()
{
	CareerStats._sortColumn = null;
	CareerStats._sortAsc = false;
	CareerStats._aliveOnly = false;
	CareerStats._entries = [];
	CareerStats._screenRef = null;
};

CareerStats.WorldObituaryScreen_createDiv = WorldObituaryScreen.prototype.createDIV;
WorldObituaryScreen.prototype.createDIV = function (_parentDiv)
{
	CareerStats.WorldObituaryScreen_createDiv.call(this, _parentDiv);

	// Start loading atlas
	CareerStats.loadAtlas();

	if ($('#career-stats-halloffame-css').length === 0)
	{
		var css = '<style id="career-stats-halloffame-css">';

		css += '.world-obituary-screen .content .scroll-container .l-row.hof-row { height: 10.0rem; position: relative; overflow: visible; margin-bottom: 0rem; }';

		css += '.world-obituary-screen .l-row .hof-portrait { position: absolute; top: 0; left: 2.0rem; width: 8.5rem; height: 10.0rem; overflow: hidden; }';
		css += '.world-obituary-screen .l-row .hof-portrait img { position: absolute; display: block; }';
		css += '.world-obituary-screen .l-row .hof-portrait canvas { position: absolute; display: block; }';

		// Name colors (bilingual)
		css += '.world-obituary-screen .l-row .hof-name { }';
		css += '.world-obituary-screen .l-row.status-fallen .hof-name { color: #8e8e8e !important; }';

		// Grey out all data cells for anyone who is NOT alive (except name and status)
		css += '.world-obituary-screen .l-row:not(.status-alive) .hof-cell:not(.hof-name):not(.hof-status) { color: #8e8e8e !important; }';

		// Status column coloring
		css += '.world-obituary-screen .l-row.status-alive  .hof-status { color: #1e8a1e !important; }';   // green
		css += '.world-obituary-screen .l-row.status-fallen .hof-status { color: #c43030 !important; }';  // red
		css += '.world-obituary-screen .l-row:not(.status-alive):not(.status-fallen) .hof-status { color: #8e8e8e !important; }'; // grey

		// Rank medal colors
		css += '.world-obituary-screen .l-row .rank-gold { color: #ffd700 !important; font-weight: bold; }';
		css += '.world-obituary-screen .l-row .rank-silver { color: #c0c0c0 !important; font-weight: bold; }';
		css += '.world-obituary-screen .l-row .rank-bronze { color: #cd7f32 !important; font-weight: bold; }';

		css += '.world-obituary-screen .l-row .hof-cell { position: absolute; top: 0; line-height: 10.0rem; }';
		css += '.world-obituary-screen .l-row .hof-cell.hof-unproven { color: #8e8e8e !important; }';

		// Column positions
		css += '.world-obituary-screen .l-row .hof-name     { left: 11.0rem; width: 21.0rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }';
		css += '.world-obituary-screen .l-row .hof-rating   { left: 28.5rem; }';
		css += '.world-obituary-screen .l-row .hof-level    { left: 35.5rem; }';
		css += '.world-obituary-screen .l-row .hof-dps      { left: 41.5rem; width: 8.0rem; }';
		css += '.world-obituary-screen .l-row .hof-hit      { left: 50.5rem; }';
		css += '.world-obituary-screen .l-row .hof-days     { left: 57.5rem; }';
		css += '.world-obituary-screen .l-row .hof-kills    { left: 65.0rem; }';
		css += '.world-obituary-screen .l-row .hof-status   { left: 73.0rem; max-width: 22rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }';

		// Hide original headers
		css += '.world-obituary-screen > .l-obituary-dialog-container .table-header .table-header-name { display: none !important; }';
		css += '.world-obituary-screen > .l-obituary-dialog-container .table-header .table-header-time { display: none !important; }';
		css += '.world-obituary-screen > .l-obituary-dialog-container .table-header .table-header-battles { display: none !important; }';
		css += '.world-obituary-screen > .l-obituary-dialog-container .table-header .table-header-kills { display: none !important; }';
		css += '.world-obituary-screen > .l-obituary-dialog-container .table-header .table-header-killed-by { display: none !important; }';

		// Our headers
		css += '.world-obituary-screen .table-header .hof-hdr { position: absolute; top: 0; }';
		css += '.world-obituary-screen .table-header .hof-hdr.hof-sortable { cursor: pointer; user-select: none; }';
		css += '.world-obituary-screen .table-header .hof-hdr.hof-sortable:hover { color: #ffcc00 !important; }';
		css += '.world-obituary-screen .table-header .hof-hdr.hof-sort-active { color: #ffcc00 !important; }';
		css += '.world-obituary-screen .table-header .hof-hdr .hof-sort-arrow { font-size: 0.7em; margin-left: 0.2em; }';
		css += '.world-obituary-screen .table-header .hof-hdr-portrait { left: 2.0rem; width: 8.5rem; text-align: center; }';
		css += '.world-obituary-screen .table-header .hof-hdr-name     { left: 11.0rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-rating   { left: 28.5rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-level    { left: 35.5rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-dps      { left: 41.5rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-hit      { left: 50.5rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-days     { left: 57.5rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-kills    { left: 65.0rem; }';
		css += '.world-obituary-screen .table-header .hof-hdr-status   { left: 73.0rem; }';

		css += '</style>';
		$('head').append(css);
	}

	var empty = this.mListScrollContainer.empty;
	this.mListScrollContainer.empty = function()
	{
		this.children('.l-row').each(function() { $(this).unbindTooltip(); });
		empty.call(this);
	}
};

CareerStats.WorldObituaryScreen_addListEntry = WorldObituaryScreen.prototype.addListEntry;
WorldObituaryScreen.prototype.addListEntry = function (_data)
{
	var statusClass = 'status-' + (_data.StatusType || 'fallen');
	var result = $('<div class="l-row hof-row ' + statusClass + '"/>');
	this.mListScrollContainer.append(result);

	// Portrait
	var portraitDiv = $('<div class="hof-portrait"/>');
	result.append(portraitDiv);

	var hasImage = _data.ImagePath && _data.ImagePath.length > 0;
	var hasAppearance = _data.Appearance && typeof _data.Appearance === 'object';

	if (hasAppearance)
	{
		var rendered = CareerStats.renderPortraitFromAppearance(_data.Appearance, portraitDiv, _data.StatusType);
		if (rendered)
		{
			var bodyBrush = _data.Appearance.body || '';
			var isSouthern = bodyBrush.indexOf('southern') >= 0;
			var isNegro = bodyBrush.indexOf('southern_00') >= 0;
			var scale = 0.84;
			var leftOff = isSouthern ? '-24px' : '-10px';
			var topOff = '-4px';
			if (isNegro) topOff = '-44px';
			else if (isSouthern) topOff = '-50px';
			portraitDiv.find('canvas').css({
				'left': leftOff,
				'top': topOff,
				'transform': 'scale(' + scale + ')',
				'transform-origin': 'top left'
			});
		}
	}
	else if (hasImage)
	{
		var imgSrc = Path.PROCEDURAL + _data.ImagePath;
		var offsetX = _data.ImageOffsetX !== undefined ? _data.ImageOffsetX : 0;
		var offsetY = _data.ImageOffsetY !== undefined ? _data.ImageOffsetY : 0;
		var scale = 0.81;
		var img = $('<img/>');
		img.attr('src', imgSrc);
		img.css({
			'left': Math.round(offsetX * scale) + 'px',
			'top': Math.round(offsetY * scale + 4) + 'px',
			'transform': 'scale(' + scale + ')',
			'transform-origin': 'top left'
		});
		portraitDiv.append(img);
	}

	// Name
	var displayName = _data.NameOnly || _data.Name || '';
	var rankNum = _data.Rank !== undefined ? _data.Rank : '';

	// Rank change arrow — show only for living brothers
	var arrow = '';
	if (_data.StatusType === 'alive')
	{
		var prevRank = _data.PrevRank !== undefined ? _data.PrevRank : -1;
		if (rankNum !== '' && prevRank > 0)
		{
			if (rankNum < prevRank)
			{
				arrow = '<span style="color:#3cb54a;font-size:0.85em;margin-left:0.3em;position:relative;top:-2px;left:2px;">▲</span>';
			}
			else if (rankNum > prevRank)
			{
				arrow = '<span style="color:#c43030;font-size:0.85em;margin-left:0.3em;position:relative;top:1px;left:2px;">▼</span>';
			}
		}
	}

	result.append($('<div class="hof-cell hof-name text-font-normal font-color-description">' + displayName + arrow + '</div>'));

	// Top
	var rankClass = 'font-color-description';
	var rankBold = '';
	var rankText = rankNum;
	if (rankNum === 1) { rankClass = 'rank-gold'; rankBold = 'font-bold'; rankText = '[1]'; }
	else if (rankNum === 2) { rankClass = 'rank-silver'; rankBold = 'font-bold'; rankText = '[2]'; }
	else if (rankNum === 3) { rankClass = 'rank-bronze'; rankBold = 'font-bold'; rankText = '[3]'; }
	result.append($('<div class="hof-cell hof-rating text-font-normal ' + rankBold + ' ' + rankClass + '">' + rankText + '</div>'));

	// Lvl
	result.append($('<div class="hof-cell hof-level text-font-normal font-color-description">' + (_data.Level || '') + '</div>'));

	// DPS (hp/armor)
	var dpsHp = _data.DPSHp !== undefined ? Math.round(_data.DPSHp) : 0;
	var dpsAr = _data.DPSArmor !== undefined ? Math.round(_data.DPSArmor) : 0;
	var dpsStr = dpsHp + '/' + dpsAr;
	result.append($('<div class="hof-cell hof-dps text-font-normal font-color-description">' + dpsStr + '</div>'));

	// Hit %
	// Сглаженная точность; «~NN%» серым, пока попыток меньше порога
	var hitInfo = CareerStats.rateInfo(_data, 'Hit');
	var hitCell = $('<div class="hof-cell hof-hit text-font-normal font-color-description"/>').text(hitInfo.text);
	if (hitInfo.unproven) hitCell.addClass('hof-unproven');
	result.append(hitCell);

	// Days
	result.append($('<div class="hof-cell hof-days text-font-normal font-color-description">' + (_data.TimeWithCompany || 0) + '</div>'));

	// Kills
	result.append($('<div class="hof-cell hof-kills text-font-normal font-color-description">' + (_data.Kills || 0) + '</div>'));

	// State
	var statusText = _data.Status || '';
	if (_data.StatusType === 'fallen' && statusText.indexOf(' / ') > 0)
		statusText = statusText.substring(0, statusText.indexOf(' / '));
	// Translate non-fallen statuses based on global language flag
	if (_data.StatusType !== 'fallen') {
		var statusTypeMap = CareerStats._isRu ? {
			'alive':     '\u0412 \u0441\u0442\u0440\u043E\u044E',     // В строю
			'dismissed': '\u0423\u0448\u0451\u043B \u043D\u0430 \u043F\u0435\u043D\u0441\u0438\u044E', // Ушёл на пенсию
			'deserted':  '\u0414\u0435\u0437\u0435\u0440\u0442\u0438\u0440\u043E\u0432\u0430\u043B',         // Дезертировал
			'banished':  '\u0418\u0437\u0433\u043D\u0430\u043D \u043A\u0430\u043A \u0437\u0430\u0440\u0430\u0436\u0451\u043D\u043D\u044B\u0439', // Изгнан как заражённый
			'left':      '\u0423\u0448\u0451\u043B'                                  // Ушёл
		} : {
			'alive':     '在役',
			'dismissed': '退役',
			'deserted':  '逃兵',
			'banished':  '因感染被驱逐',
			'left':      '离队'
		};
		statusText = statusTypeMap[_data.StatusType] || statusText;
	}

	var statusColorClass = 'font-color-description';
	if (_data.StatusType === 'alive')
		statusColorClass = 'status-color-alive';
	else if (_data.StatusType === 'fallen')
		statusColorClass = 'status-color-fallen';
	else
		statusColorClass = 'font-color-description';   // grey for departed

	result.append($('<div class="hof-cell hof-status text-font-normal ' + statusColorClass + '">' + statusText + '</div>'));
};

CareerStats.WorldObituaryScreen_loadFromData = WorldObituaryScreen.prototype.loadFromData;
WorldObituaryScreen.prototype.loadFromData = function (_data)
{
	if (_data === undefined || _data === null) return;
	this.mListScrollContainer.empty();

	if (_data.Entries !== undefined)
	{
		var isRu = (_data.Lang === 'ru');
		CareerStats._isRu = isRu;
		var companyName = _data.CompanyName || '';
		var titlePrefix = isRu ? '\u0420\u0435\u0439\u0442\u0438\u043D\u0433 \u043E\u0442\u0440\u044F\u0434\u0430 ' : '战团排名 ';
		this.mDialogContainer.findDialogTitle().text(titlePrefix + '\u00AB' + companyName + '\u00BB');

		var total = _data.TotalCount || 0;
		var alive = _data.AliveCount || 0;
		var fallen = _data.FallenCount || 0;
		var departed = _data.DepartedCount || 0;
		var subtitle = '';
		if (total === 0)
			subtitle = isRu ? '\u041D\u0438 \u043E\u0434\u0438\u043D \u0434\u043E\u0441\u0442\u043E\u0439\u043D\u044B\u0439 \u0432\u043E\u0438\u043D \u0435\u0449\u0451 \u043D\u0435 \u0441\u043B\u0443\u0436\u0438\u043B \u0432 \u043E\u0442\u0440\u044F\u0434\u0435' : '战团里还没有值得一提的战士';
		else
		{
			var parts = [];
			if (alive > 0) parts.push(alive + (isRu ? ' \u0432 \u0441\u0442\u0440\u043E\u044E' : '人在役'));
			if (fallen > 0) parts.push(fallen + (isRu ? ' \u043F\u0430\u0432\u0448\u0438\u0445' : '人阵亡'));
			if (departed > 0) parts.push(departed + (isRu ? ' \u0443\u0448\u0435\u0434\u0448\u0438\u0445' : '人离队'));
			subtitle = (isRu ? '\u0412\u0441\u0435\u0433\u043E ' : '共 ') + total + (isRu ? ' \u0432\u043E\u0438\u043D\u043E\u0432: ' : ' 名战士：') + parts.join(', ');
		}
		this.mDialogContainer.findDialogSubTitle().text(subtitle);

		var headerParent = this.mColumnName.parent();
		headerParent.find('.hof-hdr').remove();
		var h = 'hof-hdr title title-font-big font-bold font-color-description';
		var hs = h + ' hof-sortable';
		headerParent.append($('<div class="' + h + ' hof-hdr-portrait">' + (isRu ? '\u0411\u0440\u0430\u0442' : '兄弟') + '</div>'));

		var cols = isRu ? [
			['name',   '\u0418\u043C\u044F'],
			['rating', '\u0422\u043E\u043F'],
			['level',  '\u0423\u0440'],
			['dps',    '\u0423\u0440\u043E\u043D'],
			['hit',    '\u0422\u043E\u0447'],
			['days',   '\u0414\u043D\u0438'],
			['kills',  '\u0423\u0431.'],
			['status', '\u0421\u0442\u0430\u0442\u0443\u0441']
		] : [
			['name',   '姓名'],
			['rating', '排名'],
			['level',  '等级'],
			['dps',    '伤害'],
			['hit',    '命中'],
			['days',   '天数'],
			['kills',  '击杀'],
			['status', '状态']
		];

		for (var c = 0; c < cols.length; c++)
		{
			(function(colKey, colLabel) {
				var hdr = $('<div class="' + hs + ' hof-hdr-' + colKey + '">' + colLabel + '</div>');
				hdr.on('click', function() { CareerStats.onHeaderClick(colKey); });
				headerParent.append(hdr);
			})(cols[c][0], cols[c][1]);
		}

		// Store entries for sorting, reset sort state
		CareerStats._entries = _data.Entries.slice();
		CareerStats._screenRef = this;
		CareerStats._sortColumn = null;
		CareerStats._sortAsc = false;
		CareerStats._aliveOnly = false;   // по умолчанию галочка снята

		CareerStats.sortAndRender();

		// Party Strength Chart integration (button above the level chart)
		var dialogContent = this.mDialogContainer;
		dialogContent.css('position', 'relative');
		CareerStats.StrengthChart.init(_data.StrengthHistory || [], _data.DeathMarkers || [], _data.InjuryMarkers || [], isRu, {
			hardened: !!_data.StrengthHardened,
			curDiff: (_data.StrengthCurDiffPct != null) ? _data.StrengthCurDiffPct : null,
			maxDiff: (_data.StrengthMaxDiffPct != null) ? _data.StrengthMaxDiffPct : null,
			rings: (_data.RingMarkers || [])
		});
		dialogContent.find('.sc-chart-btn').remove();
		var strBtnLabel = isRu ? '[\u0441\u0438\u043B\u0430 \u043E\u0442\u0440\u044F\u0434\u0430]' : '[战团实力]';
		var strBtn = $('<div class="sc-chart-btn text-font-normal"/>').text(strBtnLabel).css({
			'position': 'absolute', 'top': '2.8rem', 'right': '3.7rem',  // [сила отряда]
			'color': '#c8b870', 'cursor': 'pointer', 'font-size': '1.2rem',
			'z-index': '100', 'text-decoration': 'underline'
		});
		strBtn.on('click', function() {
			if (CareerStats.StrengthChart._visible) CareerStats.StrengthChart.hide();
			else CareerStats.StrengthChart.show(dialogContent);
		});
		dialogContent.append(strBtn);

		// Level Chart integration
		CareerStats.LevelChart.init(_data.Entries, isRu);
		dialogContent.find('.lc-chart-btn').remove();
		var chartBtnLabel = isRu ? '[прогрессия уровней]' : '[等级曲线]';
		var chartBtn = $('<div class="lc-chart-btn text-font-normal"/>').text(chartBtnLabel).css({
			'position': 'absolute', 'top': '4.45rem', 'right': '3.7rem',
			'color': '#c8b870', 'cursor': 'pointer', 'font-size': '1.2rem',
			'z-index': '100', 'text-decoration': 'underline'
		});
		chartBtn.on('click', function() {
			if (CareerStats.LevelChart._visible) CareerStats.LevelChart.hide();
			else CareerStats.LevelChart.show(dialogContent);
		});
		dialogContent.append(chartBtn);

		// Finance Chart integration
		CareerStats.FinanceChart.init(_data.FinanceHistory || [], isRu);
		dialogContent.find('.fc-chart-btn').remove();
		var finBtnLabel = isRu ? '[финансы отряда]' : '[财务曲线]';
		var finBtn = $('<div class="fc-chart-btn text-font-normal"/>').text(finBtnLabel).css({
			'position': 'absolute', 'top': '6.1rem', 'right': '3.7rem',
			'color': '#c8b870', 'cursor': 'pointer', 'font-size': '1.2rem',
			'z-index': '100', 'text-decoration': 'underline'
		});
		finBtn.on('click', function() {
			if (CareerStats.FinanceChart._visible) CareerStats.FinanceChart.hide();
			else CareerStats.FinanceChart.show(dialogContent);
		});
		dialogContent.append(finBtn);

		// Tier List — второй режим окна рейтинга (кнопка первой в списке справа)
		dialogContent.find('.tl-btn').remove();
		var tierBtnLabel = isRu ? '[тир-лист отряда]' : '[战团梯队榜]';
		var tierBtn = $('<div class="tl-btn text-font-normal"/>').text(tierBtnLabel).css({
			'position': 'absolute', 'top': '1.15rem', 'right': '3.7rem',
			'color': '#c8b870', 'cursor': 'pointer', 'font-size': '1.2rem',
			'z-index': '100', 'text-decoration': 'underline'
		});
		CareerStats.TierList.init(_data.Entries, isRu, tierBtn);
		tierBtn.on('click', function() {
			if (CareerStats.TierList._visible) CareerStats.TierList.hide();
			else CareerStats.TierList.show(dialogContent);
		});
		dialogContent.append(tierBtn);

		// Фильтр «только живые» — слева, симметрично нижней кнопке справа
		dialogContent.find('.hof-toolbar').remove();
		dialogContent.find('.hof-alive-filter').remove();
		var aliveFilter = CareerStats.buildAliveOnlyCheckbox(isRu).css({
			'position': 'absolute', 'top': '5.3rem', 'left': '3.7rem', 'z-index': '100'
		});
		dialogContent.append(aliveFilter);
	}
	else
	{
		CareerStats.WorldObituaryScreen_loadFromData.call(this, _data);
	}
};

// ============================================================
// TIER LIST — второй режим окна рейтинга (A/B/C/D/E)
// Делит бойцов по готовому Rank из statistics_manager.nut:
//   A — места 1..3, B — 4..10, C — 11..20, D — 21..50, E — 51+
// Ничьи учитываются по Rank. Бойцы без Rank не показываются.
// Каждый тир, кроме E, вмещает не больше 15 бойцов: лишние (с худшими
// местами) сдвигаются в начало следующего тира. E растёт вниз без ограничений.
// Тир-лист занимает область таблицы (шапка + список), а заголовок окна,
// кнопки и фильтр «только живые» остаются видны и работают.
// ============================================================
CareerStats.TierList = {
	_entries: [],
	_visible: false,
	_isRu: false,
	_container: null,
	_hiddenEls: null,     // элементы таблицы, скрытые на время тир-листа
	_savedTitle: null,
	_btn: null,

	ROW_CAP: 15,

	_tiers: [
		{ label: 'A', max: 3,        color: '#ff7f3f' },
		{ label: 'B', max: 10,       color: '#fed618' },
		{ label: 'C', max: 20,       color: '#00fe1e' },
		{ label: 'D', max: 50,       color: '#00febc' },
		{ label: 'E', max: Infinity, color: '#0bb2fd' }
	],

	_tileH: '7.0rem',
	_scale: 0.58,

	init: function(entries, isRu, btn) {
		// Сброс без восстановления заголовка (loadFromData уже выставил новый)
		if (this._visible) {
			this._showTable();
			if (this._container) this._container.find('.tl-overlay, .tl-tooltip').remove();
			this._visible = false;
		}
		this._savedTitle = null;
		this._entries = (entries || []).slice();
		this._isRu = isRu;
		this._btn = btn || null;
	},

	_tierIndex: function(rank) {
		for (var t = 0; t < this._tiers.length; t++)
			if (rank <= this._tiers[t].max) return t;
		return this._tiers.length - 1;
	},

	_buildBuckets: function() {
		var buckets = [];
		for (var t = 0; t < this._tiers.length; t++) buckets.push([]);
		for (var i = 0; i < this._entries.length; i++) {
			var e = this._entries[i];
			if (e.Rank === undefined || e.Rank === null) continue;
			if (CareerStats._aliveOnly && e.StatusType !== 'alive') continue;
			buckets[this._tierIndex(e.Rank)].push(e);
		}
		var byRank = function(a, b) { return a.Rank - b.Rank; };
		for (var t = 0; t < buckets.length; t++) buckets[t].sort(byRank);

		// Лимит строки: перелив худших в следующий тир (E — без лимита)
		for (var t = 0; t < buckets.length - 1; t++) {
			if (buckets[t].length > this.ROW_CAP) {
				var overflow = buckets[t].splice(this.ROW_CAP, buckets[t].length - this.ROW_CAP);
				buckets[t + 1] = overflow.concat(buckets[t + 1]);
			}
		}
		return buckets;
	},

	_buildPortrait: function(tile, e) {
		var alive = (e.StatusType === 'alive');
		var s = this._scale;
		var k = s / 0.84;   // смещения основной таблицы заданы при масштабе 0.84
		// Якорь в центре плитки: портрет центрируется по голове
		var anchor = $('<div/>').css({ 'position': 'absolute', 'left': '50%', 'top': '0', 'width': '0', 'height': '100%' });
		tile.append(anchor);

		if (e.Appearance && typeof e.Appearance === 'object')
		{
			var rendered = CareerStats.renderPortraitFromAppearance(e.Appearance, anchor, alive ? 'alive' : 'fallen');
			if (rendered)
			{
				var bodyBrush = e.Appearance.body || '';
				var isSouthern = bodyBrush.indexOf('southern') >= 0;
				var isNegro = bodyBrush.indexOf('southern_00') >= 0;
				var leftOff = isSouthern ? -24 : -10;
				var topOff = -4;
				if (isNegro) topOff = -44;
				else if (isSouthern) topOff = -50;
				anchor.find('canvas').css({
					'position': 'absolute',
					'left': Math.round((leftOff - 42.5) * k) + 'px',
					'top': Math.round(topOff * k + 3) + 'px',
					'transform': 'scale(' + s + ')',
					'transform-origin': 'top left'
				});
				return;
			}
		}

		if (e.ImagePath && e.ImagePath.length > 0)
		{
			var ox = e.ImageOffsetX !== undefined ? e.ImageOffsetX : 0;
			var oy = e.ImageOffsetY !== undefined ? e.ImageOffsetY : 0;
			var img = $('<img/>').attr('src', Path.PROCEDURAL + e.ImagePath).css({
				'position': 'absolute',
				'left': Math.round((ox - 42.5) * k) + 'px',
				'top': Math.round(oy * s + 3) + 'px',
				'transform': 'scale(' + s + ')',
				'transform-origin': 'top left'
			});
			if (!alive) img.css({ '-webkit-filter': 'grayscale(100%)', 'filter': 'grayscale(100%)', 'opacity': '0.75' });
			anchor.append(img);
		}
	},

	// Иконка происхождения в левом нижнем углу портрета.
	// Нет иконки (старые записи до этой версии) — ничего не рисуем.
	_buildBackgroundIcon: function(tile, e) {
		if (!e.BackgroundIcon) return;
		var alive = (e.StatusType === 'alive');
		var gfx = (typeof Path !== 'undefined' && Path.GFX) ? Path.GFX : 'coui://gfx/';
		// Без обводки: иконка сама по себе медальон. Немного выходит за низ
		// портрета, как в макете (плитка не обрезает её — обрезается только портрет).
		var img = $('<img class="tl-bg-icon"/>').attr('src', gfx + e.BackgroundIcon).css({
			'position': 'absolute', 'left': '50%', 'bottom': '-0.8rem',
			'width': '2.7rem', 'height': '2.7rem', 'margin-left': '-3.0rem',
			'z-index': '2', 'pointer-events': 'none'
		});
		if (!alive) img.css({ '-webkit-filter': 'grayscale(100%)', 'filter': 'grayscale(100%)', 'opacity': '0.7' });
		tile.append(img);
	},

	// Скрыть таблицу (шапку, список и его полосу прокрутки)
	_hideTable: function() {
		if (this._hiddenEls) this._hiddenEls.css('visibility', 'hidden');
	},
	_showTable: function() {
		if (this._hiddenEls) this._hiddenEls.css('visibility', 'visible');
	},

	_setBtnActive: function(on) {
		if (!this._btn) return;
		this._btn.css('color', on ? '#ffcc00' : '#c8b870');
	},

	show: function(container) {
		if (CareerStats.StrengthChart._visible) CareerStats.StrengthChart.hide();
		if (CareerStats.LevelChart._visible) CareerStats.LevelChart.hide();
		if (CareerStats.FinanceChart._visible) CareerStats.FinanceChart.hide();

		this._container = container;
		container.find('.tl-overlay').remove();

		// Основная таблица (до создания оверлея — у него может быть свой .scroll-container)
		var header = container.find('.table-header').first();
		var sc = container.find('.scroll-container').first();
		// Поднимаемся от списка до самого внешнего блока, в котором нет шапки:
		// в нём лежат и список, и его «цепная» полоса прокрутки. Этот блок
		// перехватывал мышь у тир-листа ниже первой строки, поэтому прячем его целиком
		// (visibility:hidden не получает событий мыши).
		var list = sc;
		while (list.parent().length && list.parent()[0] !== container[0] && list.parent().find(header).length === 0)
			list = list.parent();
		this._hiddenEls = header.add(list).add(sc).add(sc.siblings());

		// Область тир-листа = от верха шапки до низа списка
		var cR = container[0].getBoundingClientRect();
		var hR = header[0].getBoundingClientRect();
		var lR = list[0].getBoundingClientRect();
		var top = Math.round(hR.top - cR.top);
		var bottom = Math.round(lR.bottom - cR.top);
		var left = Math.round(Math.min(hR.left, lR.left) - cR.left);
		var right = Math.round(Math.max(hR.right, lR.right) - cR.left);

		this._visible = true;
		this._hideTable();
		this._setBtnActive(true);

		// Заголовок окна → «Тир-лист отряда «…»»
		var titleEl = container.findDialogTitle ? container.findDialogTitle() : $();
		if (titleEl.length) {
			if (this._savedTitle === null) this._savedTitle = titleEl.text();
			var t = this._savedTitle;
			var q = t.indexOf('\u00AB');
			var name = q >= 0 ? t.substring(q) : '';
			titleEl.text((this._isRu ? 'Тир-лист отряда ' : '战团梯队榜 ') + name);
		}

		// Прозрачный оверлей: видна «древесина» окна, как в рейтинге.
		// z-index ниже кнопок (100), чтобы переключатели оставались кликабельными.
		var overlay = $('<div class="tl-overlay"/>').css({
			'position': 'absolute', 'top': top + 'px', 'left': left + 'px',
			'width': (right - left) + 'px', 'height': (bottom - top) + 'px',
			'z-index': '90', 'overflow': 'hidden'
		});
		container.append(overlay);
		this._overlay = overlay;

		// Прокрутка: игровой список с «цепной» полосой, если доступен; иначе нативный overflow
		var scroll = null;
		if (typeof $.fn.createList === 'function') {
			try {
				var gameList = overlay.createList(2);
				scroll = gameList.findListScrollContainer();
				if (!scroll || !scroll.length) scroll = null;
			} catch (err) { scroll = null; }
		}
		if (!scroll) {
			overlay.empty();
			scroll = $('<div/>').css({ 'width': '100%', 'height': '100%', 'overflow-x': 'hidden', 'overflow-y': 'auto' });
			overlay.append(scroll);
		}
		this._scroll = scroll;

		// Подсказка вешается на сам диалог, а не внутрь оверлея: игровой список
		// (createList) создаёт свой слой, и внутри него подсказка уходила под портреты.
		container.find('.tl-tooltip').remove();
		this._tooltip = $('<div class="tl-tooltip"/>').css({
			'position': 'absolute', 'display': 'none', 'pointer-events': 'none',
			'background': 'rgba(0,0,0,0.85)', 'color': '#fff', 'padding': '2px 8px',
			'font-size': '12px', 'border-radius': '3px', 'white-space': 'nowrap', 'z-index': '1000'
		});
		container.append(this._tooltip);

		this.render();
	},

	render: function() {
		if (!this._visible || !this._scroll) return;
		var scroll = this._scroll, tooltip = this._tooltip, host = this._container;
		scroll.find('.tl-row').remove();
		tooltip.css('display', 'none');

		var buckets = this._buildBuckets();
		var isRu = this._isRu;
		var pct = (100 / this.ROW_CAP) + '%';

		for (var t = 0; t < this._tiers.length; t++)
		{
			var tier = this._tiers[t];
			var row = $('<div class="tl-row"/>').css({
				'display': 'flex', 'flex-direction': 'row', 'align-items': 'stretch',
				'min-height': '7.6rem', 'margin': '0 0.4rem 0.4rem 0.4rem'
			});

			var label = $('<div class="tl-label title-font-very-big font-bold"/>').text(tier.label).css({
				'flex': '0 0 7.6rem', 'width': '7.6rem',
				'display': 'flex', 'align-items': 'center', 'justify-content': 'center',
				'background-color': tier.color, 'color': '#000000',
				'font-size': '4.0rem', 'font-weight': 'bold',
				// «утолщение» засечного шрифта игры, ближе к жирным буквам образца
				'text-shadow': '1px 0 0 #000',
				'margin-right': '0.4rem',
				'box-shadow': 'inset 0 0 0 1px rgba(0,0,0,0.6)'
			});
			row.append(label);

			// Фон строки — полупрозрачное затемнение поверх текстуры окна
			var cells = $('<div class="tl-cells"/>').css({
				'flex': '1 1 auto', 'display': 'flex', 'flex-direction': 'row', 'flex-wrap': 'wrap',
				'align-content': 'flex-start',
				'background-color': (t % 2 === 0) ? 'rgba(0,0,0,0.28)' : 'rgba(0,0,0,0.18)',
				'border-top': '1px solid rgba(0,0,0,0.55)',
				'border-bottom': '1px solid rgba(255,220,150,0.08)',
				'padding': '0.3rem 0 0.3rem 0.4rem'
			});

			var list = buckets[t];
			for (var j = 0; j < list.length; j++)
			{
				var bro = list[j];
				var tile = $('<div class="tl-tile"/>').css({
					'position': 'relative', 'overflow': 'visible',
					'width': pct, 'height': this._tileH
				});
				// Портрет обрезается своей рамкой, иконка происхождения — нет
				var clip = $('<div class="tl-clip"/>').css({
					'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0', 'overflow': 'hidden'
				});
				tile.append(clip);
				this._buildPortrait(clip, bro);
				this._buildBackgroundIcon(tile, bro);

				(function(entry, tileEl) {
					var name = entry.NameOnly || entry.Name || '';
					var alive = (entry.StatusType === 'alive');
					// «Имя [точность атак 74%, уклонение 30%]» — Total hit / Total dodge
					// Сглаженные значения; «~NN%» серым, пока попыток меньше порога
					var baseColor = alive ? '#c8b870' : '#8e8e8e';
					var fmt = function(info) {
						return info.unproven ? '<span style="color:#8e8e8e;">' + info.text + '</span>' : info.text;
					};
					var hitTxt = fmt(CareerStats.rateInfo(entry, 'Hit'));
					var dodgeTxt = fmt(CareerStats.rateInfo(entry, 'Dodge'));
					var stats = isRu
						? '[точность атак ' + hitTxt + ', уклонение ' + dodgeTxt + ']'
						: '[攻击命中 ' + hitTxt + '，闪避 ' + dodgeTxt + ']';
					var tipHtml = $('<span/>').text(name).html()
						+ ' <span style="color:' + baseColor + ';">' + stats + '</span>';
					tileEl.on('mousemove', function(ev) {
						var o = host.offset();
						tooltip.html(tipHtml);
						var x = ev.pageX - o.left + 14;
						// не вылезать за правый край окна
						if (x + tooltip.outerWidth() > host.width() - 8) x = ev.pageX - o.left - 14 - tooltip.outerWidth();
						tooltip.css({
							'display': 'block',
							'color': alive ? '#ffffff' : '#8e8e8e',
							'left': x + 'px',
							'top': (ev.pageY - o.top - 10) + 'px'
						});
					});
					tileEl.on('mouseleave', function() { tooltip.css('display', 'none'); });
				})(bro, tile);

				cells.append(tile);
			}

			row.append(cells);
			scroll.append(row);
		}
	},

	hide: function() {
		this._visible = false;
		this._setBtnActive(false);
		this._showTable();
		if (this._container) {
			this._container.find('.tl-overlay').remove();
			this._container.find('.tl-tooltip').remove();
			if (this._savedTitle !== null && this._container.findDialogTitle)
				this._container.findDialogTitle().text(this._savedTitle);
		}
		this._savedTitle = null;
		this._scroll = null;
	}
};

// ============================================================
// LEVEL PROGRESSION CHART (dual panel, smooth curves)
// ============================================================
CareerStats.LevelChart = {
	_alive: [],
	_gone: [],
	_selA: {},
	_selG: {},
	_visible: false,
	_isRu: false,
	_colors: [
		'#e6194b','#3cb44b','#4363d8','#f58231','#911eb4',
		'#42d4f4','#f032e6','#bfef45','#fabed4','#469990',
		'#dcbeff','#9A6324','#fffac8','#800000','#aaffc3',
		'#808000','#ffd8b1','#000075','#a9a9a9','#e6beff',
		'#ff6f61','#6b5b95','#88b04b','#92a8d1','#b565a7'
	],

	init: function(entries, isRu) {
		this._alive = []; this._gone = [];
		this._selA = {}; this._selG = {};
		this._isRu = isRu;
		var cA = 0, cG = 0;
		for (var i = 0; i < entries.length; i++) {
			var e = entries[i];
			var hist = e.LevelHistory || [];
			var rec = {
				name: e.NameOnly || e.Name || ('Bro #' + i),
				level: e.Level || 1,
				status: e.StatusType || 'alive',
				history: hist,
				color: this._colors[(e.StatusType === 'alive' ? cA : cG) % this._colors.length]
			};
			if (e.StatusType === 'alive') {
				this._alive.push(rec);
				if (hist.length > 0) this._selA[this._alive.length - 1] = true;
				cA++;
			} else {
				this._gone.push(rec);
				if (hist.length > 0) this._selG[this._gone.length - 1] = true;
				cG++;
			}
		}
	},

	// Monotone cubic Hermite spline (Fritsch-Carlson) — smooth curves through points
	_monotoneX: function(pts) {
		if (pts.length < 2) return [];
		var n = pts.length, dx = [], dy = [], m = [], a = [];
		for (var i = 0; i < n - 1; i++) {
			dx[i] = pts[i+1].x - pts[i].x;
			dy[i] = pts[i+1].y - pts[i].y;
			m[i] = dx[i] !== 0 ? dy[i] / dx[i] : 0;
		}
		a[0] = m[0]; a[n-1] = m[n-2];
		for (var i = 1; i < n - 1; i++) {
			a[i] = (m[i-1] * m[i] <= 0) ? 0 : (m[i-1] + m[i]) / 2;
		}
		for (var i = 0; i < n - 1; i++) {
			if (Math.abs(m[i]) < 1e-6) { a[i] = 0; a[i+1] = 0; continue; }
			var ak = a[i]/m[i], bk = a[i+1]/m[i], s = ak*ak + bk*bk;
			if (s > 9) { var t = 3/Math.sqrt(s); a[i] = t*ak*m[i]; a[i+1] = t*bk*m[i]; }
		}
		var segs = [];
		for (var i = 0; i < n - 1; i++) {
			var p0 = pts[i], p1 = pts[i+1], d = dx[i] / 3;
			segs.push({ cx1: p0.x+d, cy1: p0.y+a[i]*d, cx2: p1.x-d, cy2: p1.y-a[i+1]*d, x1: p1.x, y1: p1.y });
		}
		return segs;
	},

	_drawChart: function(canvas, bros, sel, maxDay, isTop) {
		var rect = canvas.parentElement.getBoundingClientRect();
		canvas.width = Math.floor(rect.width);
		canvas.height = Math.floor(rect.height);
		var ctx = canvas.getContext('2d');
		var W = canvas.width, H = canvas.height;
		ctx.clearRect(0, 0, W, H);

		var ml = 38, mr = 30, mt = 10, mb = 22;
		var cw = W - ml - mr, ch = H - mt - mb;
		if (cw < 50 || ch < 50) return;

		var maxLv = 6;
		for (var idx in sel) {
			if (!sel[idx]) continue;
			var b = bros[idx];
			for (var j = 0; j < b.history.length; j++) {
				if (b.history[j].level > maxLv) maxLv = b.history[j].level;
			}
			if (b.level > maxLv) maxLv = b.level;
		}
		maxLv = Math.min(maxLv + 2, 33);

		function xP(d) { return ml + (d / maxDay) * cw; }
		function yP(l) { return mt + ch - ((l - 1) / (maxLv - 1)) * ch; }

		// Grid — levels
		ctx.strokeStyle = 'rgba(255,255,255,0.05)'; ctx.lineWidth = 1;
		ctx.font = '10px sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.25)'; ctx.textAlign = 'right';
		for (var lv = 1; lv <= maxLv; lv++) {
			var y = Math.round(yP(lv)) + 0.5;
			ctx.beginPath(); ctx.moveTo(ml, y); ctx.lineTo(ml + cw, y); ctx.stroke();
			if (lv % 2 === 1 || maxLv <= 15) ctx.fillText('' + lv, ml - 4, y + 3);
		}

		// Grid — days
		ctx.textAlign = 'center'; ctx.fillStyle = 'rgba(255,255,255,0.2)';
		var step = 25;
		if (maxDay > 200) step = 50;
		if (maxDay > 500) step = 100;
		if (maxDay > 1000) step = 200;
		for (var dd = step; dd <= maxDay; dd += step) {
			var x = Math.round(xP(dd)) + 0.5;
			ctx.beginPath(); ctx.moveTo(x, mt); ctx.lineTo(x, mt + ch); ctx.stroke();
			ctx.fillText('' + dd, x, mt + ch + 13);
		}

		// Axes
		ctx.strokeStyle = 'rgba(255,255,255,0.15)'; ctx.lineWidth = 1;
		ctx.beginPath(); ctx.moveTo(ml, mt); ctx.lineTo(ml, mt + ch); ctx.lineTo(ml + cw, mt + ch); ctx.stroke();

		// Draw smooth lines
		var self = this;
		this._renderedPts = [];
		for (var idx in sel) {
			if (!sel[idx]) continue;
			var b = bros[idx];
			var h = b.history.slice().sort(function(a, b) { return a.day - b.day; });
			if (h.length === 0) continue;

			var pts = [];
			for (var j = 0; j < h.length; j++) pts.push({ x: xP(h[j].day), y: yP(h[j].level) });
			// For alive brothers, extend to current day
			if (isTop && h.length > 0) {
				var last = h[h.length - 1];
				if (last.day < maxDay) pts.push({ x: xP(maxDay), y: yP(last.level) });
			}

			// Store for hover detection
			this._renderedPts.push({ name: b.name, color: b.color, pts: pts });

			ctx.strokeStyle = b.color; ctx.lineWidth = 2.5;
			ctx.beginPath();
			ctx.moveTo(pts[0].x, pts[0].y);
			if (pts.length === 2) {
				ctx.lineTo(pts[1].x, pts[1].y);
			} else if (pts.length > 2) {
				var segs = self._monotoneX(pts);
				for (var j = 0; j < segs.length; j++) {
					var s = segs[j];
					ctx.bezierCurveTo(s.cx1, s.cy1, s.cx2, s.cy2, s.x1, s.y1);
				}
			}
			ctx.stroke();

			// Dots at level-up points
			ctx.fillStyle = b.color;
			for (var j = 0; j < h.length; j++) {
				ctx.beginPath();
				ctx.arc(xP(h[j].day), yP(h[j].level), 3.5, 0, Math.PI * 2);
				ctx.fill();
			}

			// Level label near the right end of the line (inside chart area)
			var lastLv = h[h.length - 1].level;
			var labelX = ml + cw - 8;
			var labelY = yP(lastLv) - 8;
			ctx.font = 'bold 13px sans-serif';
			ctx.textAlign = 'right';
			// Dark outline for readability
			ctx.strokeStyle = 'rgba(0,0,0,0.7)';
			ctx.lineWidth = 3;
			ctx.strokeText('' + lastLv, labelX, labelY);
			// Colored text
			ctx.fillStyle = b.color;
			ctx.fillText('' + lastLv, labelX, labelY);
		}
	},

	_buildLegend: function(container, bros, sel, canvasId, isTop) {
		container.empty();
		var self = this;
		for (var i = 0; i < bros.length; i++) {
			var b = bros[i];
			if (b.history.length === 0 && b.level <= 1) continue;

			var item = $('<label/>').css({
				'display': 'inline-flex', 'align-items': 'center', 'cursor': 'pointer',
				'white-space': 'nowrap', 'font-size': '1.0rem', 'margin-right': '1.5rem'
			});
			var cb = $('<input type="checkbox"/>').attr('data-idx', i).css({
				'margin': '0 3px 0 0', 'width': '16px', 'height': '16px', 'accent-color': b.color
			});
			if (sel[i]) cb.prop('checked', true);
			(function(idx, s, canvas, brs, top) {
				cb.on('change', function() {
					if ($(this).is(':checked')) s[idx] = true;
					else delete s[idx];
					self._drawChart(document.getElementById(canvas), brs, s, self._maxDay, top);
				});
			})(i, sel, canvasId, bros, isTop);
			var swatch = $('<span/>').css({
				'display': 'inline-block', 'width': '16px', 'height': '4px',
				'background': b.color, 'margin': '0 4px', 'border-radius': '2px', 'flex-shrink': '0'
			});
			var icon = b.status === 'fallen' ? '\u2620 ' : (b.status !== 'alive' ? '\u2192 ' : '');
			var nm = $('<span/>').text(icon + b.name).css({
				'color': b.status === 'alive' ? '#bbb' : '#777'
			});
			item.append(cb).append(swatch).append(nm);
			container.append(item);
		}
	},

	show: function(container) {
		this._visible = true;
		this._container = container;
		container.find('.lc-overlay').remove();

		// Hide the hall of fame rows so they don't bleed through
		container.find('.scroll-container').css('visibility', 'hidden');
		container.find('.table-header').css('visibility', 'hidden');

		// Max day from alive brothers only
		var maxDay = 10;
		for (var i = 0; i < this._alive.length; i++) {
			for (var j = 0; j < this._alive[i].history.length; j++) {
				if (this._alive[i].history[j].day > maxDay) maxDay = this._alive[i].history[j].day;
			}
		}
		this._maxDay = maxDay;
		var isRu = this._isRu;

		var overlay = $('<div class="lc-overlay"/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'background-color': '#1a1510',
			'z-index': '9999', 'overflow': 'hidden'
		});

		// Background texture
		var bgImg = $('<img/>').attr('src', 'coui://gfx/mods/career_stats/progress_bar_fon_3.png').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'width': '100%', 'height': '100%',
			'pointer-events': 'none', 'z-index': '0'
		});
		overlay.append(bgImg);

		// Content wrapper — fixed layout, no scroll
		var contentWrap = $('<div/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'z-index': '1', 'display': 'flex', 'flex-direction': 'column', 'padding': '0.6rem 0.8rem'
		});

		// Title bar
		var titleBar = $('<div/>').css({ 'display': 'flex', 'justify-content': 'space-between', 'align-items': 'center', 'flex-shrink': '0' });
		titleBar.append($('<div class="title title-font-big font-bold font-color-description"/>').text(isRu ? '\u041F\u0440\u043E\u0433\u0440\u0435\u0441\u0441\u0438\u044F \u0443\u0440\u043E\u0432\u043D\u0435\u0439' : '等级成长'));
		var self = this;
		// Native game close button (icon_cross.png with hover highlight)
		var closeBtnWrap = $('<div/>').css({
			'width': '2.2rem', 'height': '2.2rem', 'flex-shrink': '0', 'margin-right': '22px',
			'position': 'relative', 'top': '5px', 'left': '11px'
		});
		var closeBtn = $('<div class="ui-control button"/>').css({
			'width': '100%', 'height': '100%', 'cursor': 'pointer'
		});
		closeBtn.append($('<img/>').attr('src', 'coui://gfx/ui/skin/icon_cross.png'));
		closeBtn.on('click', function() { self.hide(); });
		closeBtn.on('mouseenter', function() { $(this).addClass('is-selected'); });
		closeBtn.on('mouseleave', function() { $(this).removeClass('is-selected'); });
		closeBtnWrap.append(closeBtn);
		titleBar.append(closeBtnWrap);
		contentWrap.append(titleBar);

		// Chart canvas — fills all remaining space
		var chartWrapA = $('<div/>').css({ 'flex': '1 1 auto', 'position': 'relative', 'min-height': '0' });
		var canvasA = $('<canvas id="lc-alive"/>').css({ 'width': '100%', 'height': '100%', 'display': 'block' });
		chartWrapA.append(canvasA);
		contentWrap.append(chartWrapA);

		// Legend — compact, at the bottom
		var legendA = $('<div class="lc-leg-alive"/>').css({ 'display': 'flex', 'flex-wrap': 'wrap', 'gap': '0.3rem 2.0rem', 'padding': '0.4rem 0.5rem', 'flex-shrink': '0' });
		contentWrap.append(legendA);

		overlay.append(contentWrap);
		container.append(overlay);

		// Render after DOM insertion
		var cvA = canvasA[0];
		var rA = chartWrapA[0].getBoundingClientRect();
		cvA.width = Math.floor(rA.width); cvA.height = Math.floor(rA.height);
		this._drawChart(cvA, this._alive, this._selA, maxDay, true);
		this._buildLegend(legendA, this._alive, this._selA, 'lc-alive', true);

		// Hover tooltip — show brother name on mouseover
		var tooltip = $('<div/>').css({
			'position': 'absolute', 'display': 'none', 'pointer-events': 'none',
			'background': 'rgba(0,0,0,0.8)', 'color': '#fff', 'padding': '2px 8px',
			'font-size': '12px', 'border-radius': '3px', 'white-space': 'nowrap', 'z-index': '10'
		});
		chartWrapA.append(tooltip);
		var selfChart = this;

		canvasA.on('mousemove', function(e) {
			var rect = cvA.getBoundingClientRect();
			var mx = e.clientX - rect.left;
			var my = e.clientY - rect.top;
			var bestDist = 20, bestName = null, bestColor = null;
			var rp = selfChart._renderedPts || [];
			for (var i = 0; i < rp.length; i++) {
				var pts = rp[i].pts;
				for (var j = 0; j < pts.length; j++) {
					var dx = mx - pts[j].x, dy = my - pts[j].y;
					var d = Math.sqrt(dx * dx + dy * dy);
					if (d < bestDist) { bestDist = d; bestName = rp[i].name; bestColor = rp[i].color; }
				}
			}
			if (bestName) {
				tooltip.text(bestName).css({
					'display': 'block', 'left': (mx + 12) + 'px', 'top': (my - 8) + 'px',
					'border': '1px solid ' + bestColor
				});
			} else {
				tooltip.css('display', 'none');
			}
		});
		canvasA.on('mouseleave', function() { tooltip.css('display', 'none'); });
	},

	hide: function() {
		this._visible = false;
		if (this._container) {
			this._container.find('.scroll-container').css('visibility', 'visible');
			this._container.find('.table-header').css('visibility', 'visible');
			this._container.find('.lc-overlay').remove();
			if (CareerStats.TierList._visible) CareerStats.TierList._hideTable();
		}
	}
};


// ============================================================
// FINANCE CHART — balance history, yellow smooth curve
// ============================================================
CareerStats.FinanceChart = {
	_history: [],
	_visible: false,
	_isRu: false,
	_container: null,
	_pts: [],

	init: function(history, isRu) {
		this._history = (history && history.length) ? history : [];
		this._isRu = isRu;
	},

	// Monotone cubic Hermite spline
	_monotoneX: function(pts) {
		if (pts.length < 2) return [];
		var n = pts.length, dx = [], dy = [], m = [], a = [];
		for (var i = 0; i < n - 1; i++) {
			dx[i] = pts[i+1].x - pts[i].x;
			dy[i] = pts[i+1].y - pts[i].y;
			m[i] = dx[i] !== 0 ? dy[i] / dx[i] : 0;
		}
		a[0] = m[0]; a[n-1] = m[n-2];
		for (var i = 1; i < n - 1; i++) {
			a[i] = (m[i-1] * m[i] <= 0) ? 0 : (m[i-1] + m[i]) / 2;
		}
		for (var i = 0; i < n - 1; i++) {
			if (Math.abs(m[i]) < 1e-6) { a[i] = 0; a[i+1] = 0; continue; }
			var ak = a[i]/m[i], bk = a[i+1]/m[i], s = ak*ak + bk*bk;
			if (s > 9) { var t = 3/Math.sqrt(s); a[i] = t*ak*m[i]; a[i+1] = t*bk*m[i]; }
		}
		var segs = [];
		for (var i = 0; i < n - 1; i++) {
			var p0 = pts[i], p1 = pts[i+1], d = dx[i] / 3;
			segs.push({ cx1: p0.x+d, cy1: p0.y+a[i]*d, cx2: p1.x-d, cy2: p1.y-a[i+1]*d, x1: p1.x, y1: p1.y });
		}
		return segs;
	},

	_formatMoney: function(v) {
		if (Math.abs(v) >= 1000000) return Math.round(v / 100000) / 10 + 'M';
		if (Math.abs(v) >= 1000) return Math.round(v / 100) / 10 + 'k';
		return '' + Math.round(v);
	},

	_drawChart: function(canvas) {
		var rect = canvas.parentElement.getBoundingClientRect();
		canvas.width  = Math.floor(rect.width);
		canvas.height = Math.floor(rect.height);
		var ctx = canvas.getContext('2d');
		var W = canvas.width, H = canvas.height;
		ctx.clearRect(0, 0, W, H);

		var hist = this._history;
		if (!hist || hist.length === 0) {
			ctx.fillStyle = 'rgba(255,220,80,0.4)';
			ctx.font = '13px sans-serif';
			ctx.textAlign = 'center';
			ctx.fillText(this._isRu ? 'Нет данных' : '暂无数据', W / 2, H / 2);
			return;
		}

		// mb = высота зоны подписей оси X под линией нуля
		var ml = 52, mr = 18, mt = 16, mb = 18;
		var cw = W - ml - mr, ch = H - mt - mb;
		if (cw < 50 || ch < 50) return;

		// --- Y range: строго от 0 до maxBal, никакого отрицательного пространства ---
		var maxBal = 0;
		for (var i = 0; i < hist.length; i++) {
			if (hist[i].balance > maxBal) maxBal = hist[i].balance;
		}
		var spread = maxBal;
		if (spread < 200) spread = 200;
		var pad = spread * 0.10;
		var yMin = 0;
		var yMax = Math.max(maxBal + pad, 1);
		var yRange = yMax - yMin;

		var totalPts = hist.length + 1;

		function xP(idx) { return ml + (idx / Math.max(totalPts - 1, 1)) * cw; }
		function yP(b)   { return mt + ch - ((b - yMin) / yRange) * ch; }

		// zeroY = нижний край области графика = визуальный ноль
		var zeroY = mt + ch;

		// --- Сетка Y ---
		ctx.font = '10px sans-serif';
		ctx.textAlign = 'right';
		var rawStep = yRange / 6;
		var mag = Math.pow(10, Math.floor(Math.log(rawStep) / Math.log(10)));
		var gridStep = Math.ceil(rawStep / mag) * mag;
		var gridStart = Math.ceil(yMin / gridStep) * gridStep;
		for (var gv = gridStart; gv <= yMax + gridStep * 0.01; gv += gridStep) {
			var gy = Math.round(yP(gv)) + 0.5;
			if (gy < mt - 2 || gy > zeroY + 2) continue;
			ctx.strokeStyle = 'rgba(255,220,80,0.10)';
			ctx.lineWidth = 1;
			ctx.beginPath(); ctx.moveTo(ml, gy); ctx.lineTo(ml + cw, gy); ctx.stroke();
			ctx.fillStyle = 'rgba(255,220,80,0.40)';
			ctx.fillText(this._formatMoney(gv), ml - 5, gy + 3);
		}

		// --- Сетка X: вертикальные линии + метки дней СНИЗУ от нулевой линии ---
		ctx.textAlign = 'center';
		var xTickMax = Math.min(8, hist.length);
		var xTickStep = Math.max(1, Math.floor(hist.length / xTickMax));
		for (var i = 0; i < hist.length; i += xTickStep) {
			var xPos = Math.round(xP(i + 1)) + 0.5;
			ctx.strokeStyle = 'rgba(255,220,80,0.10)';
			ctx.lineWidth = 1;
			ctx.beginPath(); ctx.moveTo(xPos, mt); ctx.lineTo(xPos, zeroY); ctx.stroke();
			// Метки прямо под нулевой линией
			ctx.fillStyle = 'rgba(255,220,80,0.50)';
			ctx.fillText((this._isRu ? '\u0434' : '') + hist[i].day, xPos, zeroY + 13);
		}

		// --- Нулевая горизонталь (ось X) ---
		ctx.strokeStyle = 'rgba(255,220,80,0.35)';
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.moveTo(ml, zeroY + 0.5); ctx.lineTo(ml + cw, zeroY + 0.5);
		ctx.stroke();

		// (Отдельная вертикальная ось Y не рисуется — её роль выполняет
		//  крайняя левая линия X-сетки на позиции xP(1), проходящая через
		//  первую точку данных. Это устраняет визуальный артефакт «двойной оси».)

		// --- Строим точки (баланс зажимается снизу нулём) ---
		var pts = [];
		pts.push({ x: xP(0), y: yP(0) });
		for (var i = 0; i < hist.length; i++) {
			pts.push({ x: xP(i + 1), y: yP(Math.max(0, hist[i].balance)) });
		}
		this._pts = pts;

		// --- Строим сегменты один раз ---
		var segments = pts.length > 2 ? this._monotoneX(pts) : null;

		// --- Заливка: один path, один fillStyle, без clip, без shadow ---
		ctx.shadowBlur = 0;
		ctx.beginPath();
		ctx.moveTo(pts[0].x, pts[0].y);
		if (pts.length === 2) {
			ctx.lineTo(pts[1].x, pts[1].y);
		} else if (segments) {
			for (var j = 0; j < segments.length; j++) {
				var fs = segments[j];
				ctx.bezierCurveTo(fs.cx1, fs.cy1, fs.cx2, fs.cy2, fs.x1, fs.y1);
			}
		}
		ctx.lineTo(pts[pts.length - 1].x, zeroY);
		ctx.lineTo(pts[0].x, zeroY);
		ctx.closePath();
		ctx.fillStyle = 'rgba(190,150,25,0.30)'; // заливка графика
		ctx.fill();

		// --- Плавная линия поверх заливки (без shadow) ---
		ctx.strokeStyle = '#ffd832';
		ctx.lineWidth = 2.2;
		ctx.beginPath();
		ctx.moveTo(pts[0].x, pts[0].y);
		if (pts.length === 2) {
			ctx.lineTo(pts[1].x, pts[1].y);
		} else if (segments) {
			for (var j = 0; j < segments.length; j++) {
				var s = segments[j];
				ctx.bezierCurveTo(s.cx1, s.cy1, s.cx2, s.cy2, s.x1, s.y1);
			}
		}
		ctx.stroke();

		// --- Метка текущего баланса у последней точки ---
		if (pts.length > 1) {
			var lp = pts[pts.length - 1];
			var lb = hist[hist.length - 1].balance;
			var labelY = lp.y - 9;
			if (labelY < mt + 12) labelY = lp.y + 16;
			ctx.font = 'bold 12px sans-serif';
			ctx.textAlign = 'right';
			ctx.strokeStyle = 'rgba(0,0,0,0.75)'; ctx.lineWidth = 3;
			ctx.strokeText(this._formatMoney(lb), lp.x, labelY);
			ctx.fillStyle = '#ffd832';
			ctx.fillText(this._formatMoney(lb), lp.x, labelY);
		}
	},

	show: function(container) {
		this._visible = true;
		this._container = container;
		container.find('.fc-overlay').remove();

		container.find('.scroll-container').css('visibility', 'hidden');
		container.find('.table-header').css('visibility', 'hidden');

		var isRu = this._isRu;
		var self = this;

		var overlay = $('<div class="fc-overlay"/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'background-color': '#16120b', 'z-index': '9999', 'overflow': 'hidden'
		});

		var bgImg = $('<img/>').attr('src', 'coui://gfx/mods/career_stats/progress_bar_fon_3.png').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'width': '100%', 'height': '100%',
			'pointer-events': 'none', 'z-index': '0'
		});
		overlay.append(bgImg);

		var contentWrap = $('<div/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'z-index': '1', 'display': 'flex', 'flex-direction': 'column', 'padding': '0.6rem 0.8rem'
		});

		// Заголовок
		var titleBar = $('<div/>').css({ 'display': 'flex', 'justify-content': 'space-between', 'align-items': 'center', 'flex-shrink': '0' });
		titleBar.append($('<div class="title title-font-big font-bold font-color-description"/>').text(isRu ? '\u0420\u0430\u0441\u0445\u043e\u0434\u044b \u0438 \u0434\u043e\u0445\u043e\u0434\u044b' : '收入与支出'));

		var closeBtnWrap = $('<div/>').css({
			'width': '2.2rem', 'height': '2.2rem', 'flex-shrink': '0', 'margin-right': '22px',
			'position': 'relative', 'top': '5px', 'left': '11px'
		});
		var closeBtn = $('<div class="ui-control button"/>').css({ 'width': '100%', 'height': '100%', 'cursor': 'pointer' });
		closeBtn.append($('<img/>').attr('src', 'coui://gfx/ui/skin/icon_cross.png'));
		closeBtn.on('click', function() { self.hide(); });
		closeBtn.on('mouseenter', function() { $(this).addClass('is-selected'); });
		closeBtn.on('mouseleave', function() { $(this).removeClass('is-selected'); });
		closeBtnWrap.append(closeBtn);
		titleBar.append(closeBtnWrap);
		contentWrap.append(titleBar);

		// Canvas
		var chartWrap = $('<div/>').css({ 'flex': '1 1 auto', 'position': 'relative', 'min-height': '0', 'margin-top': '0.4rem' });
		var canvas = $('<canvas id="fc-canvas"/>').css({ 'width': '100%', 'height': '100%', 'display': 'block' });
		chartWrap.append(canvas);
		contentWrap.append(chartWrap);

		overlay.append(contentWrap);
		container.append(overlay);

		var cv = canvas[0];
		var r  = chartWrap[0].getBoundingClientRect();
		cv.width  = Math.floor(r.width);
		cv.height = Math.floor(r.height);
		this._drawChart(cv);

		// Тултип при наведении
		var tooltip = $('<div/>').css({
			'position': 'absolute', 'display': 'none', 'pointer-events': 'none',
			'background': 'rgba(0,0,0,0.85)', 'color': '#ffd832', 'padding': '3px 10px',
			'font-size': '11px', 'border-radius': '3px', 'white-space': 'nowrap',
			'z-index': '10', 'border': '1px solid rgba(255,216,50,0.35)'
		});
		chartWrap.append(tooltip);

		var hist = this._history;
		canvas.on('mousemove', function(e) {
			var pts = self._pts;
			if (!pts || pts.length < 2) return;
			var rect = cv.getBoundingClientRect();
			var mx = e.clientX - rect.left;
			var my = e.clientY - rect.top;
			var bestDist = 22, bestIdx = -1;
			for (var i = 0; i < pts.length; i++) {
				var ddx = mx - pts[i].x, ddy = my - pts[i].y;
				var d = Math.sqrt(ddx * ddx + ddy * ddy);
				if (d < bestDist) { bestDist = d; bestIdx = i; }
			}
			if (bestIdx > 0) {
				// bestIdx 0 = стартовая точка (нет данных)
				var rec = hist[bestIdx - 1];
				var sign = rec.delta > 0 ? '+' : '';
				var tipText = (isRu ? '\u0414\u0435\u043d\u044c ' : '第') + rec.day + (isRu ? '' : '天')
					+ '   ' + rec.balance + ' ' + (isRu ? '\u043a\u0440' : '克朗')
					+ '   ' + sign + rec.delta;
				tooltip.text(tipText).css({ 'display': 'block', 'left': (mx + 14) + 'px', 'top': (my - 10) + 'px' });
			} else {
				tooltip.css('display', 'none');
			}
		});
		canvas.on('mouseleave', function() { tooltip.css('display', 'none'); });
	},

	hide: function() {
		this._visible = false;
		if (this._container) {
			this._container.find('.scroll-container').css('visibility', 'visible');
			this._container.find('.table-header').css('visibility', 'visible');
			this._container.find('.fc-overlay').remove();
			if (CareerStats.TierList._visible) CareerStats.TierList._hideTable();
		}
	}
};

// ============================================================
// PARTY STRENGTH CHART — столбцы силы отряда (жёлтые), 0..100%
// Данные из strength_tracker.nut:
//   _history  [{day, strength}]            — точка раз в 5 дней
//   _deaths   [{day, name, level, ...}]    — гибель бойца 8+ ур.
//   _injuries [{day, name, level, icon}]   — травма бойца 8+ ур.
// Гибель отмечается черепом (ui/icons/kills.png — как в тултипе
// "Killer potency"), травма — иконкой конкретной травмы.
// ============================================================
CareerStats.StrengthChart = {
	// ============================================================
	// ТЕСТОВАЯ СБОРКА — превью дизайна графика
	//   _TEST_MODE = true   -> график рисуется по ПОДДЕЛЬНЫМ данным
	//   _TEST_MODE = false  -> обычная работа на реальных данных кампании
	// Чтобы вернуть рабочую версию — поставь false.
	// ============================================================
	_TEST_MODE: false,

	_history: [],
	_deaths: [],
	_injuries: [],
	_rings: [],
	_visible: false,
	_isRu: false,
	_container: null,
	_bars: [],          // [{x, w, y, day, strength}] — для ховера
	_geom: null,        // геометрия последней отрисовки — для маркеров
	_meta: null,        // {hardened, curDiff, maxDiff} — масштабирование по сложности Hardened

	// Поддельный набор: ~150 дней роста отряда, 3 гибели, 2 травмы.
	_makeTestData: function() {
		var strengths = [
			3, 6, 9, 13, 17, 21, 25, 22, 25, 28,
			31, 34, 37, 40, 43, 45, 37, 40, 43, 45,
			47, 49, 51, 53, 47, 50, 53, 56, 58, 60
		];
		var history = [];
		for (var i = 0; i < strengths.length; i++)
			history.push({ day: i * 5, strength: strengths[i] });

		// День 75 — 3 гибели + 2 травмы; день 115 — 2 гибели + 3 травмы;
		// плюс одиночная гибель (д.30) и одиночная травма (д.95).
		var deaths = [
			{ day: 30,  name: 'Хайнрих', level: 9  },
			{ day: 75,  name: 'Вендель', level: 11 },
			{ day: 75,  name: 'Бруно',   level: 10 },
			{ day: 75,  name: 'Курт',    level: 8  },
			{ day: 115, name: 'Отто',    level: 11 },
			{ day: 115, name: 'Дитер',   level: 8  }
		];
		var injuries = [
			{ day: 75,  name: 'Вилли', level: 9,  injuryID: 'injury.missing_eye',        icon: 'ui/injury/injury_permanent_icon_03.png' },
			{ day: 75,  name: 'Йорг',  level: 12, injuryID: 'injury.missing_finger',      icon: 'ui/injury/injury_permanent_icon_02.png' },
			{ day: 95,  name: 'Конрад', level: 10, injuryID: 'injury.broken_knee',        icon: 'ui/injury/injury_permanent_icon_08.png' },
			{ day: 115, name: 'Ганс',  level: 10, injuryID: 'injury.maimed_foot',         icon: 'ui/injury/injury_permanent_icon_10.png' },
			{ day: 115, name: 'Пауль', level: 9,  injuryID: 'injury.broken_elbow_joint',  icon: 'ui/injury/injury_permanent_icon_07.png' },
			{ day: 115, name: 'Клаус', level: 13, injuryID: 'injury.traumatized',         icon: 'ui/injury/injury_permanent_icon_11.png' }
		];
		return { history: history, deaths: deaths, injuries: injuries };
	},

	init: function(history, deaths, injuries, isRu, meta) {
		this._isRu = isRu;
		this._meta = meta || { hardened: false, curDiff: null, maxDiff: null };
		this._rings = (meta && meta.rings && meta.rings.length) ? meta.rings : [];
		if (this._TEST_MODE) {
			var fake = this._makeTestData();
			this._history  = fake.history;
			this._deaths   = fake.deaths;
			this._injuries = fake.injuries;
			return;
		}
		this._history  = (history  && history.length)  ? history  : [];
		this._deaths   = (deaths   && deaths.length)   ? deaths   : [];
		this._injuries = (injuries && injuries.length) ? injuries : [];
	},

	// Группировка событий по интервалам сетки (iv). События раньше minDay
	// сливаются в первый видимый интервал. keepIcon — сохранять иконку
	// первого события группы (для травм).
	_group: function(list, keepIcon, iv, minDay) {
		// Группируем по РЕАЛЬНОМУ дню события (а не по 5-дневному интервалу):
		// несколько событий одного дня — одна иконка со счётчиком, а события
		// в разные дни внутри одного интервала разъезжаются по своим дням.
		// Дни левее minDay прижимаем к minDay, чтобы не уехать за левый край.
		var buckets = {};
		for (var i = 0; i < list.length; i++) {
			var d = list[i];
			var key = Math.max(minDay, d.day);
			if (!buckets[key]) buckets[key] = { day: key, names: [], count: 0, icon: null, items: [] };
			var lvl = (d.level != null) ? d.level : '?';
			buckets[key].names.push(d.name + ' (' + lvl + ')');
			buckets[key].items.push({ name: d.name, level: lvl, icon: d.icon || null });
			buckets[key].count++;
			if (keepIcon && buckets[key].icon == null && d.icon) buckets[key].icon = d.icon;
		}
		var out = [];
		for (var k in buckets) out.push(buckets[k]);
		out.sort(function(a, b) { return a.day - b.day; });
		return out;
	},

	_drawChart: function(canvas) {
		var rect = canvas.parentElement.getBoundingClientRect();
		canvas.width  = Math.floor(rect.width);
		canvas.height = Math.floor(rect.height);
		var ctx = canvas.getContext('2d');
		var W = canvas.width, H = canvas.height;
		ctx.clearRect(0, 0, W, H);
		this._bars = [];
		this._geom = null;

		var hist = this._history;
		if (!hist || hist.length === 0) {
			ctx.fillStyle = 'rgba(255,220,80,0.4)';
			ctx.font = '13px sans-serif';
			ctx.textAlign = 'center';
			ctx.fillText(this._isRu ? 'Нет данных' : '暂无数据', W / 2, H / 2);
			return;
		}

		// mt оставляет место сверху под два ряда маркеров (черепа + травмы)
		// mt вмещает сверху два ряда маркеров (черепа + травмы) по 24px.
		var iconSize = 24;
		// Верхний ряд под мифические кольца — только если они есть (иначе
		// раскладка ровно прежняя, вертикаль не тратится). Кольца идут ВЫШЕ
		// черепов гибели и иконок травм и рисуются крупнее (~+1/3).
		var hasRings = !!(this._rings && this._rings.length);
		var ringIconSize = Math.round(iconSize * 4 / 3);   // 24 -> 32
		var ringRowTop = 6;
		var skullRowTop = hasRings ? (ringRowTop + ringIconSize + 2) : 6;   // черепа гибели
		var injuryRowTop = skullRowTop + iconSize + 2;                      // иконки травм
		var ml = 46, mr = 18, mt = injuryRowTop + iconSize + 6, mb = 20;
		var cw = W - ml - mr, ch = H - mt - mb;
		if (cw < 50 || ch < 50) return;

		var zeroY = mt + ch;   // визуальный 0%

		// Окно графика масштабируется: 150 дней (шаг 5) -> при дне 150
		// окно 300 (шаг 10) -> при 300 окно 600 (шаг 20) -> при 600
		// окно 1200 (шаг 40) и т.д. Всегда ~30 интервалов, столбцы
		// одинаковой ширины. Шаг данных задаётся в strength_tracker.nut.
		function ivForDay(d) { var iv = 5; while (d >= iv * 30) iv = iv * 2; return iv; }
		var i;
		var lastDay = hist[hist.length - 1].day;
		var iv = ivForDay(lastDay);
		var maxDay = iv * 30;          // правый край окна
		// Левый край = первый записанный день. Для новой кампании это
		// день 0 — график стартует с полного нуля; для установки мода
		// в середине кампании — с первого реально записанного дня
		// (без пустоты слева).
		var minDay = hist[0].day;
		if (minDay > maxDay - iv) minDay = maxDay - iv;
		var span = maxDay - minDay;
		var steps = span / iv;

		var barW = Math.max(4, Math.min((cw / (steps + 1)) * 0.85, 36));

		// xP(day) — ЛЕВЫЙ край столбца этого дня; xC(day) — его центр.
		function xP(day) { return ml + ((day - minDay) / span) * (cw - barW); }
		function xC(day) { return xP(day) + barW / 2; }
		function yP(pct) { return zeroY - (Math.max(0, Math.min(100, pct)) / 100) * ch; }

		// --- Сетка Y: линии каждые 5%, цифры — только на 10% ---
		ctx.font = '10px sans-serif';
		ctx.textAlign = 'right';
		for (var p = 0; p <= 100; p += 5) {
			var gy = Math.round(yP(p)) + 0.5;
			ctx.strokeStyle = 'rgba(255,255,255,0.05)';
			ctx.lineWidth = 1;
			ctx.beginPath(); ctx.moveTo(ml, gy); ctx.lineTo(ml + cw, gy); ctx.stroke();
			if (p % 10 === 0) {
				ctx.fillStyle = 'rgba(255,220,80,0.42)';
				ctx.fillText(p + '%', ml - 5, gy + 3);
			}
		}

		// --- Сетка X: вертикали на каждом интервале, начиная с minDay ---
		ctx.textAlign = 'center';
		for (var d = minDay; d <= maxDay + 0.5; d += iv) {
			var gx = Math.round(xP(d)) + 0.5;
			ctx.strokeStyle = 'rgba(255,255,255,0.05)';
			ctx.lineWidth = 1;
			ctx.beginPath(); ctx.moveTo(gx, mt); ctx.lineTo(gx, zeroY); ctx.stroke();
			ctx.fillStyle = 'rgba(255,220,80,0.50)';
			ctx.fillText((this._isRu ? 'д' : '') + d, gx, zeroY + 13);
		}

		// --- Нулевая линия ---
		ctx.strokeStyle = 'rgba(255,220,80,0.35)';
		ctx.lineWidth = 1;
		ctx.beginPath(); ctx.moveTo(ml, zeroY + 0.5); ctx.lineTo(ml + cw, zeroY + 0.5); ctx.stroke();

		// --- Столбцы (левый край столбца = xP(day), линия дня) ---
		// Логика красных "шапок" просадки:
		//   Для каждого столбца берём рекорд среди ВСЕХ предыдущих (maxBefore).
		//   Красное рисуем, только если столбец ниже этого рекорда И этот
		//   рекорд НЕ был достигнут/побит ПОЗЖЕ. То есть как только сила
		//   снова дотянулась до прежнего рекорда, вся просадка между ними
		//   "закрывается" и краснота убирается. Открытым (красным) остаётся
		//   лишь последний незавершённый спад от наивысшего рекорда.
		// Сначала отбираем видимые столбцы по порядку.
		var visIdx = [];
		for (i = 0; i < hist.length; i++) {
			if (hist[i].day < minDay) continue;
			visIdx.push(i);
		}
		// Предрасчёт: dropArr[k] — просадка (в пунктах) для visIdx[k], 0 если красного нет.
		var dropArr = [];
		var n = visIdx.length;
		for (var a = 0; a < n; a++) {
			var sa = hist[visIdx[a]].strength;
			if (sa < 0) sa = 0; if (sa > 100) sa = 100;
			// рекорд строго ДО текущего
			var maxBefore = -1;
			for (var b2 = 0; b2 < a; b2++) {
				var sb = hist[visIdx[b2]].strength;
				if (sb > maxBefore) maxBefore = sb;
			}
			var dr = 0;
			if (maxBefore >= 0 && sa < maxBefore) {
				// был ли этот рекорд достигнут снова ПОЗЖE? если да — просадка закрыта
				var recovered = false;
				for (var c = a + 1; c < n; c++) {
					var sc = hist[visIdx[c]].strength;
					if (sc >= maxBefore - 0.0001) { recovered = true; break; }
				}
				if (!recovered) dr = maxBefore - sa;
			}
			dropArr.push(dr);
		}

		for (var vi = 0; vi < n; vi++) {
			i = visIdx[vi];
			var bx = xP(hist[i].day);
			var s = hist[i].strength;
			if (s < 0) s = 0; if (s > 100) s = 100;
			var by = yP(s);
			var bh = zeroY - by;
			if (bh < 1) bh = 1;

			var drop = dropArr[vi];
			var redTopY = (drop > 0) ? yP(s + drop) : by;   // верх красного = уровень рекорда

			var isBf = !!hist[i].bf;   // восстановленная задним числом точка
			var grad = ctx.createLinearGradient(0, by, 0, zeroY);
			if (isBf) {
				// Реконструкция — приглушённые столбцы, чтобы отличать от реальных данных
				grad.addColorStop(0, 'rgba(255,216,50,0.45)');
				grad.addColorStop(1, 'rgba(190,150,25,0.22)');
			} else {
				grad.addColorStop(0, 'rgba(255,216,50,0.95)');
				grad.addColorStop(1, 'rgba(190,150,25,0.55)');
			}
			ctx.fillStyle = grad;
			ctx.fillRect(bx, by, barW, bh);
			ctx.strokeStyle = isBf ? 'rgba(255,228,120,0.28)' : 'rgba(255,228,120,0.55)';
			ctx.lineWidth = 1;
			ctx.strokeRect(bx + 0.5, by + 0.5, Math.max(1, barW - 1), Math.max(1, bh - 1));

			// Красная "шапка" просадки: от верха столбца вверх до уровня рекорда
			if (drop > 0) {
				var rh = by - redTopY;
				if (rh >= 1) {
					var rgrad = ctx.createLinearGradient(0, redTopY, 0, by);
					var ra = isBf ? 0.4 : 0.85;
					rgrad.addColorStop(0, 'rgba(222,62,52,' + ra + ')');
					rgrad.addColorStop(1, 'rgba(150,35,30,' + (ra * 0.6) + ')');
					ctx.fillStyle = rgrad;
					ctx.fillRect(bx, redTopY, barW, rh);
					ctx.strokeStyle = isBf ? 'rgba(255,120,110,0.25)' : 'rgba(255,120,110,0.5)';
					ctx.lineWidth = 1;
					ctx.strokeRect(bx + 0.5, redTopY + 0.5, Math.max(1, barW - 1), Math.max(1, rh - 1));
				}
			}

			this._bars.push({ x: bx + barW / 2, w: barW, y: by, day: hist[i].day,
				strength: s, raw: hist[i].raw, factor: hist[i].factor, diff: hist[i].diff, bf: isBf,
				drop: drop, redTop: redTopY, hit: hist[i].hit, dodge: hist[i].dodge });
		}

		// --- Вертикальные линии маркеров ---
		var deathGroups  = this._group(this._deaths, false, iv, minDay);
		var injuryGroups = this._group(this._injuries, true, iv, minDay);
		var ringGroups   = this._group(this._rings, true, iv, minDay);

		// Линии-указатели идут от маркера ВНИЗ к верхушке столбца того дня,
		// останавливаясь чуть выше неё (столбец не задевают). Линии — серые;
		// к травмам линии не рисуются (только иконки сверху).
		var bars = this._bars;
		function barTopForDay(day) {
			var best = null, bd = 1e9;
			for (var k = 0; k < bars.length; k++) {
				var dd = Math.abs(bars[k].day - day);
				if (dd < bd) { bd = dd; best = bars[k]; }
			}
			if (!best) return zeroY;
			// Если у столбца есть красная "шапка" просадки — линия идёт к её
			// верху (уровню рекорда), а не к верху жёлтой части.
			return (best.drop > 0 && best.redTop != null) ? best.redTop : best.y;
		}

		ctx.setLineDash([4, 4]);
		ctx.lineWidth = 2;
		for (i = 0; i < deathGroups.length; i++) {
			var dxd = Math.round(xC(deathGroups[i].day)) + 0.5;
			ctx.strokeStyle = 'rgba(99,98,99,0.95)';   // серый — гибель
			ctx.beginPath();
			ctx.moveTo(dxd, skullRowTop + iconSize / 2);   // от центра черепа
			ctx.lineTo(dxd, barTopForDay(deathGroups[i].day));   // чуть заходит на столбец
			ctx.stroke();
		}
		// Линии к травмам не рисуем — остаются только иконки травм сверху.
		ctx.setLineDash([]);
		ctx.lineWidth = 1;

		// --- Метка текущего значения у последнего видимого столбца ---
		var last = hist[hist.length - 1];
		if (last.day >= minDay) {
			var lx = xC(last.day);
			var lastS = last.strength;
			var ly = yP(lastS);
			var txt = (Math.round(lastS * 10) / 10) + '%';
			ctx.font = 'bold 12px sans-serif';
			ctx.textAlign = 'center';
			var lblY = ly - 6;
			if (lblY < mt + 10) lblY = ly + 14;
			ctx.strokeStyle = 'rgba(0,0,0,0.75)'; ctx.lineWidth = 3;
			ctx.strokeText(txt, lx, lblY);
			ctx.fillStyle = '#ffd832';
			ctx.fillText(txt, lx, lblY);
		}

		// Геометрия для размещения иконок-маркеров (DOM) поверх canvas
		this._geom = {
			ml: ml, mt: mt, cw: cw, ch: ch, maxDay: maxDay, minDay: minDay, span: span,
			zeroY: zeroY, barW: barW,
			skullRowTop: skullRowTop, injuryRowTop: injuryRowTop, ringRowTop: ringRowTop, iconSize: iconSize, ringIconSize: ringIconSize,
			deathGroups: deathGroups, injuryGroups: injuryGroups, ringGroups: ringGroups
		};
	},

	// Размещает иконки маркеров (DOM) поверх canvas: черепа — верхний ряд,
	// иконки травм — ряд ниже.
	_placeMarkers: function(chartWrap, tooltip) {
		chartWrap.find('.sc-marker').remove();
		if (!this._geom) return;
		var g = this._geom;
		var isRu = this._isRu;

		function xOf(day) { return g.ml + ((day - g.minDay) / g.span) * (g.cw - g.barW) + g.barW / 2; }

		function addMarker(grp, iconUrl, topPx, kind, iconPx) {
			var sz = iconPx || g.iconSize;
			var x = xOf(grp.day);
			var img = $('<img class="sc-marker"/>')
				.attr('src', iconUrl)
				.css({
					'position': 'absolute', 'width': sz + 'px', 'height': sz + 'px',
					'left': (x - sz / 2) + 'px', 'top': topPx + 'px',
					'cursor': 'help', 'z-index': '12'
				});
			if (grp.count > 1) {
				var badge = $('<div class="sc-marker"/>').text(grp.count).css({
					'position': 'absolute', 'left': (x + sz / 2 - 3) + 'px', 'top': (topPx - 5) + 'px',
					'color': '#ffce5a', 'font-size': '11px', 'font-weight': 'bold',
					'z-index': '13', 'pointer-events': 'none'
				});
				chartWrap.append(badge);
			}
			img.on('mouseenter', function() {
				if (kind === 'death') {
					var head = isRu ? (grp.count > 1 ? 'Погибли: ' : 'Погиб: ') : '阵亡：';
					tooltip.html('').text(head + grp.names.join(', '))
						.css({
							'display': 'block', 'white-space': 'nowrap',
							'left': Math.min(x + 14, g.ml + g.cw - 60) + 'px',
							'top': (topPx + sz + 2) + 'px'
						});
				} else if (kind === 'ring') {
					var rhead = isRu
						? (grp.count > 1 ? ('Мифические кольца (' + grp.count + ')') : 'Мифическое кольцо')
						: (grp.count > 1 ? ('神话戒指（' + grp.count + '）') : '神话戒指');
					var rday = isRu ? ('получено на день ' + grp.day) : ('获得于第' + grp.day + '天');
					var rhtml = '<div style="white-space:nowrap;">' + rhead + ' \u2014 ' + rday + '</div>';
					var rits = grp.items || [];
					for (var ri = 0; ri < rits.length; ri++) {
						var rit = rits[ri];
						var ricon = rit.icon ? ('coui://gfx/' + rit.icon) : '';
						rhtml += '<div style="white-space:nowrap;margin-top:3px;">';
						if (ricon) rhtml += '<img src="' + ricon + '" style="width:30px;height:30px;vertical-align:middle;margin-right:6px;">';
						if (rit.name) rhtml += '<span style="vertical-align:middle;">' + rit.name + '</span>';
						rhtml += '</div>';
					}
					tooltip.html(rhtml)
						.css({
							'display': 'block', 'white-space': 'nowrap',
							'left': Math.min(x + 14, g.ml + g.cw - 60) + 'px',
							'top': (topPx + sz + 2) + 'px'
						});
				} else {
					var head = isRu ? (grp.count > 1 ? 'Травмированы:' : 'Травмирован:') : '受伤：';
					var html = '<div style="font-weight:bold;margin-bottom:3px;color:#ffd832;">' + head + '</div>';
					var items = grp.items || [];
					for (var k = 0; k < items.length; k++) {
						var it = items[k];
						var iconUrl = it.icon ? ('coui://gfx/' + it.icon) : 'coui://gfx/ui/icons/injury.png';
						html += '<div style="display:flex;align-items:center;line-height:18px;margin:1px 0;">';
						html += '<img src="' + iconUrl + '" style="width:18px;height:18px;margin-right:5px;flex-shrink:0;"/>';
						html += '<span>' + it.name + ' (' + it.level + ')</span>';
						html += '</div>';
					}
					tooltip.html(html)
						.css({
							'display': 'block', 'white-space': 'normal',
							'left': Math.min(x + 14, g.ml + g.cw - 180) + 'px',
							'top': (topPx + sz + 2) + 'px'
						});
				}
			});
			img.on('mouseleave', function() { tooltip.css('display', 'none'); });
			chartWrap.append(img);
		}

		// Черепа гибели — верхний ряд
		for (var i = 0; i < g.deathGroups.length; i++)
			addMarker(g.deathGroups[i], 'coui://gfx/ui/icons/kills.png', g.skullRowTop, 'death');

		// Иконки травм — ряд ниже
		for (var j = 0; j < g.injuryGroups.length; j++) {
			var grp = g.injuryGroups[j];
			// Иконка маркера: если в группе один тип травм — она; если
			// разные — берём иконку первого бойца в списке.
			// Подробности всё равно в тултипе.
			var iconPath = 'ui/icons/injury.png';
			if (grp.items && grp.items.length > 0) {
				var firstIcon = null;
				for (var u = 0; u < grp.items.length; u++) {
					if (grp.items[u].icon) { firstIcon = grp.items[u].icon; break; }
				}
				if (firstIcon) iconPath = firstIcon;
			} else if (grp.icon) {
				iconPath = grp.icon;
			}
			addMarker(grp, 'coui://gfx/' + iconPath, g.injuryRowTop, 'injury');
		}

		// Мифические (фиолетовые) кольца — самый верхний ряд, выше черепов и травм
		if (g.ringGroups) {
			for (var r = 0; r < g.ringGroups.length; r++) {
				var rgrp = g.ringGroups[r];
				var rIcon = (rgrp.icon) ? rgrp.icon : 'ui/items/accessory/ring_1.png';
				addMarker(rgrp, 'coui://gfx/' + rIcon, g.ringRowTop, 'ring', g.ringIconSize);
			}
		}
	},

	show: function(container) {
		this._visible = true;
		this._container = container;
		container.find('.sc-overlay').remove();
		container.find('.scroll-container').css('visibility', 'hidden');
		container.find('.table-header').css('visibility', 'hidden');

		var isRu = this._isRu;
		var self = this;

		var overlay = $('<div class="sc-overlay"/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'background-color': '#16120b', 'z-index': '9999', 'overflow': 'hidden'
		});

		var bgImg = $('<img/>').attr('src', 'coui://gfx/mods/career_stats/progress_bar_fon_3.png').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'width': '100%', 'height': '100%',
			'pointer-events': 'none', 'z-index': '0'
		});
		overlay.append(bgImg);

		var contentWrap = $('<div/>').css({
			'position': 'absolute', 'top': '0', 'left': '0', 'right': '0', 'bottom': '0',
			'z-index': '1', 'display': 'flex', 'flex-direction': 'column', 'padding': '0.6rem 0.8rem'
		});

		// Заголовок
		var titleText = isRu ? 'Сила отряда' : '战团实力';
		if (self._meta && self._meta.hardened) {
			var mx = (self._meta.maxDiff != null) ? Math.round(self._meta.maxDiff) : null;
			if (mx != null)
				titleText += (isRu ? ' (макс. сложность мира ' : '（最高世界难度 ') + mx + (isRu ? '%)' : '%）');
		}
		var titleBar = $('<div/>').css({ 'display': 'flex', 'justify-content': 'space-between', 'align-items': 'center', 'flex-shrink': '0' });
		titleBar.append($('<div class="title title-font-big font-bold font-color-description"/>')
			.text(titleText));

		var closeBtnWrap = $('<div/>').css({
			'width': '2.2rem', 'height': '2.2rem', 'flex-shrink': '0', 'margin-right': '22px',
			'position': 'relative', 'top': '5px', 'left': '11px'
		});
		var closeBtn = $('<div class="ui-control button"/>').css({ 'width': '100%', 'height': '100%', 'cursor': 'pointer' });
		closeBtn.append($('<img/>').attr('src', 'coui://gfx/ui/skin/icon_cross.png'));
		closeBtn.on('click', function() { self.hide(); });
		closeBtn.on('mouseenter', function() { $(this).addClass('is-selected'); });
		closeBtn.on('mouseleave', function() { $(this).removeClass('is-selected'); });
		closeBtnWrap.append(closeBtn);
		titleBar.append(closeBtnWrap);
		contentWrap.append(titleBar);

		// Canvas
		var chartWrap = $('<div/>').css({ 'flex': '1 1 auto', 'position': 'relative', 'min-height': '0', 'margin-top': '0.4rem' });
		var canvas = $('<canvas id="sc-canvas"/>').css({ 'width': '100%', 'height': '100%', 'display': 'block' });
		chartWrap.append(canvas);
		contentWrap.append(chartWrap);

		overlay.append(contentWrap);
		container.append(overlay);

		var cv = canvas[0];
		var r = chartWrap[0].getBoundingClientRect();
		cv.width = Math.floor(r.width);
		cv.height = Math.floor(r.height);
		this._drawChart(cv);

		// Ховер-тултип
		var tooltip = $('<div/>').css({
			'position': 'absolute', 'display': 'none', 'pointer-events': 'none',
			'background': 'rgba(0,0,0,0.85)', 'color': '#ffd832', 'padding': '3px 10px',
			'font-size': '11px', 'border-radius': '3px', 'white-space': 'nowrap',
			'z-index': '14', 'border': '1px solid rgba(255,216,50,0.35)'
		});
		chartWrap.append(tooltip);

		// Иконки маркеров поверх canvas
		this._placeMarkers(chartWrap, tooltip);

		// Ховер по столбцам — отключён по запросу (может понадобиться позже).
		// Подсказки маркеров гибели/травм продолжают работать (см. _placeMarkers).
		// Ховер по столбцам: показывает данные дня, включая последний столбец.
		canvas.on('mousemove', function(e) {
			var bars = self._bars;
			if (!bars || bars.length === 0) return;
			var rect = cv.getBoundingClientRect();
			var mx = e.clientX - rect.left;
			var my = e.clientY - rect.top;
			var best = -1, bestDist = 1e9;
			for (var i = 0; i < bars.length; i++) {
				var dd = Math.abs(mx - bars[i].x);
				if (dd < bestDist) { bestDist = dd; best = i; }
			}
			if (best >= 0 && bestDist <= Math.max(14, bars[best].w)) {
				var b = bars[best];
				var tip;
				// Зона красной "шапки" с допуском в пару пикселей, чтобы в неё
				// было легко попасть курсором (она бывает тонкой).
				var inRed = (b.drop > 0) && (my >= b.redTop - 2) && (my <= b.y + 2);
				if (inRed) {
					// курсор на красной "шапке" — показываем падение от рекорда
					tip = (isRu ? 'День ' : '第') + b.day + (isRu ? ', ' : '天，')
						+ (isRu ? 'падение ' : '下降 ')
						+ '-' + (Math.round(b.drop * 10) / 10) + '%';
				} else {
					tip = (isRu ? 'День ' : '第') + b.day + (isRu ? ', ' : '天，')
						+ (isRu ? 'сила отряда ' : '战团实力 ')
						+ (Math.round(b.strength * 10) / 10) + '%';
					if (self._meta && self._meta.hardened && b.diff != null && b.factor != null) {
						tip += (isRu ? ' (сложность мира ' : '（世界难度 ') + Math.round(b.diff) + '%'
							+ (isRu ? ', множитель ' : '，倍率 ') + (Math.round(b.factor * 10) / 10) + (isRu ? '%)' : '%）');
					}
					if (b.bf) tip += (isRu ? '  · восст.' : '  · 推算');
				}
				tooltip.text(tip).css({
					'display': 'block',
					'left': (b.x + 12) + 'px',
					'top': (b.y - 6) + 'px'
				});
			} else {
				tooltip.css('display', 'none');
			}
		});
		canvas.on('mouseleave', function() { tooltip.css('display', 'none'); });
	},

	hide: function() {
		this._visible = false;
		if (this._container) {
			this._container.find('.scroll-container').css('visibility', 'visible');
			this._container.find('.table-header').css('visibility', 'visible');
			this._container.find('.sc-overlay').remove();
			if (CareerStats.TierList._visible) CareerStats.TierList._hideTable();
		}
	}
};
