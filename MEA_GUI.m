function MEA_GUI()
% MEA_GUI  Interactive GUI for examining Intan RHS recordings from MEAs.
%
% Compatible with: Octave (uses figure/uicontrol, not uifigure/uibutton)
%
%Features to Add:
%custom downsampling rate
%
% Required files in the same directory:
%   - read_Intan_RHS2000_multifile_BMSEED.m
%
% -------------------------------------------------------------------------
% LAYOUT:
%   LEFT   (px 0-280)    : controls — MEA type, load, Vrms window, table
%   CENTER (px 285-900)  : electrode grid — one mini-plot per channel
%   RIGHT  (px 905-1380) : detail waveform + Z/Vrms bar charts
% -------------------------------------------------------------------------

pkg load signal
pkg load statistics


%%=========================================================================
%  Create the main window
%=========================================================================

fig = figure('Units',       'pixels', ...
             'Position',    [50 50 1380 800], ...
             'Name',        'MEA Examiner', ...
             'NumberTitle', 'off', ...
             'MenuBar',     'none', ...
             'Color',       [0.18 0.18 0.20]);


%% =========================================================================
%  Define a shared "state" structure
%  =========================================================================
%


state.Files_Data       = [];       % raw output from the Intan file reader
state.Extracted        = [];       % our processed data (one entry per file)
state.current_file_idx = 1;        % which file we're currently looking at
state.current_ch_idx   = 1;        % which electrode is selected in the grid
state.MEA_type         = '';       % e.g. 'sMEA_gen4ef'
state.start_sec        = 1.0;      % Vrms window start (seconds)
state.end_sec          = 1.5;      % Vrms window end (seconds)
state.y_limits         = [-50 50]; % Y-axis range for waveform plots (uV)
state.spikes_computed = false;
state.spikes = {};
state.spike_thresh = [];
state.spikes_indices = {};   % sample indices, not just times
state.sort_results   = {};   % per-channel sort output
state.filter_mode  = 'butter';
state.filter_order = 2;
state.highpass     = 300;
state.lowpass      = 3000;
state.notch_freq   = 60;
state.lfp_cutoff   = 300;

set(fig, 'UserData', state);       % attach state to the figure
set(fig, 'Position', [50 50 1380 800]);

%% =========================================================================
%  Colour palette
%  =========================================================================


c.bg      = [0.18 0.18 0.20];   % dark background
c.panel   = [0.22 0.22 0.26];   % slightly lighter panel background
c.ctrl    = [0.28 0.28 0.34];   % control background (buttons, fields)
c.accent  = [0.18 0.52 0.80];   % blue — primary action colour
c.text    = [0.92 0.92 0.92];   % near-white text
c.textdim = [0.55 0.55 0.62];   % dimmed text for secondary labels
c.good    = [0.20 0.75 0.45];   % green  — healthy electrode
c.warn    = [0.95 0.75 0.20];   % yellow — marginal
c.bad     = [0.85 0.30 0.25];   % red    — problem electrode
c.sel     = [1.00 0.65 0.10];   % orange — selected electrode highlight

% Set color as part of app data
setappdata(fig, 'colors', c);


%% =========================================================================
%  LEFT PANEL (controls)
%  =========================================================================


leftPanel = uipanel(fig, ...
    'Units',           'pixels', ...
    'Position',        [0 0 280 800], ...
    'BackgroundColor', c.panel, ...
    'BorderType',      'none');

btnToggleMain = uicontrol(fig, ...
    'Style', 'pushbutton', 'String', 'Controls', ...
    'Units', 'pixels', 'Position', [0 775 140 25], ...
    'ForegroundColor', [0.1 0.1 0.1], 'BackgroundColor', [0.18 0.52 0.80], ...
    'FontSize', 9, 'FontWeight', 'bold');

btnToggleAnalysis = uicontrol(fig, ...
    'Style', 'pushbutton', 'String', 'Analysis', ...
    'Units', 'pixels', 'Position', [140 775 140 25], ...
    'ForegroundColor', c.text, 'BackgroundColor', [0.28 0.28 0.34], ...
    'FontSize', 9, 'FontWeight', 'bold');

% Main controls panel
leftPanel = uipanel(fig, ...
    'Units', 'pixels', 'Position', [0 0 280 775], ...
    'BackgroundColor', c.panel, 'BorderType', 'none', ...
    'Visible', 'on');

% Analysis panel (new)
analysisPanel = uipanel(fig, ...
    'Units', 'pixels', 'Position', [0 0 280 775], ...
    'BackgroundColor', c.panel, 'BorderType', 'none', ...
    'Visible', 'off');

% Wire toggle buttons
set(btnToggleMain, 'Callback', @(s,e) cb_TogglePanel(fig, leftPanel, analysisPanel, btnToggleMain, btnToggleAnalysis));
set(btnToggleAnalysis, 'Callback', @(s,e) cb_TogglePanel(fig, analysisPanel, leftPanel, btnToggleAnalysis, btnToggleMain));

setappdata(fig, 'analysisPanel', analysisPanel);


% ---- Title label ----
%
% Key properties:
%   'String'              the text to display
%   'HorizontalAlignment' 'left', 'center', or 'right'
%   'ForegroundColor'     text colour  [R G B]
%   'BackgroundColor'     background   [R G B]  (match parent to look clean)
%   'FontSize'            in points
%   'FontWeight'          'normal' or 'bold'

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'MEA Examiner', ...
    'Units',              'pixels', ...
    'Position',           [5 758 270 32], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           16, ...
    'FontWeight',         'bold');


% ---- MEA type label + dropdown ----

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'MEA Type', ...
    'Units',              'pixels', ...
    'Position',           [5 728 120 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

mea_types = {'sMEA_gen4ad','sMEA_gen4ef','sMEA_gen4g', ...
             'sMEA_gen6a','sMEA_gen6b','sMEA_gen7a', ...
             '60ch_gMEA','120ch_gMEA'};

ddMEA = uicontrol(leftPanel, ...
    'Style',           'popupmenu', ...
    'String',          mea_types, ...
    'Value',           2, ...           % default: index 2 = 'sMEA_gen4ef'
    'Units',           'pixels', ...
    'Position',        [5 700 268 26], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);



% ---- Load files button ----

btnLoad = uicontrol(leftPanel, ...
    'Style',           'pushbutton', ...
    'String',          'Load Intan File(s)...', ...
    'Units',           'pixels', ...
    'Position',        [5 660 268 34], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.accent, ...
    'FontSize',        10, ...
    'FontWeight',      'bold');

% Set the callback separately so we can pass btnLoad as an argument.
set(btnLoad, 'Callback', @(src,event) cb_LoadFiles(fig, ddMEA, btnLoad));


% ---- Active file dropdown ----
%
% Populated with filenames after loading. We store the handle so
% callbacks can update it later.

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Active File', ...
    'Units',              'pixels', ...
    'Position',           [5 633 120 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

ddFile = uicontrol(leftPanel, ...
    'Style',           'popupmenu', ...
    'String',          {'(no file loaded)'}, ...
    'Value',           1, ...
    'Units',           'pixels', ...
    'Position',        [5 606 268 26], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_ChangeFile(fig, src));


% ---- Vrms time window controls ----


uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Vrms Time Window', ...
    'Units',              'pixels', ...
    'Position',           [5 573 268 20], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           10, ...
    'FontWeight',         'bold');

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Start (s):', ...
    'Units',              'pixels', ...
    'Position',           [5 548 70 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efStart = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '1.0', ...
    'Units',           'pixels', ...
    'Position',        [50 546 80 22], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_UpdateWindow(fig));

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'End (s):', ...
    'Units',              'pixels', ...
    'Position',           [135 548 70 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efEnd = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '1.5', ...
    'Units',           'pixels', ...
    'Position',        [175 546 80 22], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_UpdateWindow(fig));

% ---- Y-axis limit controls ----

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Y-axis Limits (uV)', ...
    'Units',              'pixels', ...
    'Position',           [5 525 268 20], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           10, ...
    'FontWeight',         'bold');

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Min:', ...
    'Units',              'pixels', ...
    'Position',           [5 500 35 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efYmin = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '-50', ...
    'Units',           'pixels', ...
    'Position',        [25 500 70 22], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_UpdateYLimits(fig));

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Max:', ...
    'Units',              'pixels', ...
    'Position',           [110 500 35 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efYmax = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '50', ...
    'Units',           'pixels', ...
    'Position',        [150 500 70 22], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_UpdateYLimits(fig));


% ---- Export buttons ----

uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Export', ...
    'Units',              'pixels', ...
    'Position',           [5 75 268 20], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           10, ...
    'FontWeight',         'bold');

uicontrol(leftPanel, ...
    'Style',           'pushbutton', ...
    'String',          'Save Z & Vrms  (.csv)', ...
    'Units',           'pixels', ...
    'Position',        [5 42 268 28], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_ExportCSV(fig));

uicontrol(leftPanel, ...
    'Style',           'pushbutton', ...
    'String',          'Save Current Plot  (.png)', ...
    'Units',           'pixels', ...
    'Position',        [5 12 268 28], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9, ...
    'Callback',        @(src,event) cb_ExportPNG(fig));


uicontrol(leftPanel, ...
    'Style',              'text', ...
    'String',             'Exclusion Criteria', ...
    'Units',              'pixels', ...
    'Position',           [5 350 120 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.panel, ...
    'FontSize',        10, ...
    'FontWeight',      'bold', ...
    'HorizontalAlignment',   'left');

uicontrol(leftPanel, ...
    'Style',           'text', ...
    'String',          'Z Threshold (kOhm)', ...
    'Units',           'pixels', ...
    'Position',        [0 325 125 18], ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',        9);

efZthresh = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '3000', ...
    'Units',           'pixels', ...
    'Position',        [125 325 35 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

uicontrol(leftPanel, ...
    'Style',           'text', ...
    'String',          'Vrms High Thresh (uV)', ...
    'Units',           'pixels', ...
    'Position',        [5 300 130 18], ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',        9);

efVrmshigh = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '15', ...
    'Units',           'pixels', ...
    'Position',        [135 300 35 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

uicontrol(leftPanel, ...
    'Style',           'text', ...
    'String',          'Vrms Low Thresh (uV)', ...
    'Units',           'pixels', ...
    'Position',        [5 275 130 18], ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',        9);

efVrmslow = uicontrol(leftPanel, ...
    'Style',           'edit', ...
    'String',          '0', ...
    'Units',           'pixels', ...
    'Position',        [135 275 35 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

cbShowExcluded = uicontrol(leftPanel, ...
    'Style',          'checkbox', ...
    'String',         'Show Excluded Channels', ...
    'Position',       [5 250 300 18], ...
    'Units',          'pixels', ...
    'Value',          0, ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'Callback',       @(src,event) cb_ToggleExcluded(fig, src));

btnZoomWin = uicontrol(leftPanel, ...
    'Style',           'pushbutton', ...
    'String',          'Zoom In', ...
    'Units',           'pixels', ...
    'Position',        [5 350 268 25], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', [0.35 0.20 0.55], ...
    'FontSize',        10, ...
    'Callback', @(src,event) show_zoom_window(fig), ...
    'FontWeight',      'bold');


% ---- Analysis Modules section label ----
btn_configs = {
    'Filter Bank',        @(s,e) show_filter_bank_window(fig), [0.18 0.40 0.42];
    'Spike Detection',      @(s,e) cb_RunSpikes(fig),     [0.45 0.05 0.15];
    'Spike Sorting',      @(s,e) show_sorting_window(fig),     [0.30 0.18 0.48];
    'Feature Extraction', @(s,e) show_features_window(fig),    [0.18 0.35 0.52];
    'Burst Detection',    @(s,e) show_burst_window(fig),       [0.18 0.45 0.25];
    'Network Activity',   @(s,e) show_network_window(fig),     [0.15 0.40 0.55];
    'Waveform Viewer',    @(s,e) show_waveform_window(fig),    [0.42 0.28 0.18];
    'ISI Analysis',       @(s,e) show_isi_window(fig),         [0.20 0.48 0.38];
    'Quality Metrics',    @(s,e) show_quality_window(fig),     [0.25 0.25 0.48];
};

uicontrol(analysisPanel, ...
    'Style', 'text', 'String', 'Analysis Modules', ...
    'Units', 'pixels', 'Position', [5 740 268 24], ...
    'ForegroundColor', c.text, 'BackgroundColor', c.panel, ...
    'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
for i = 1:size(btn_configs, 1)
    uicontrol(analysisPanel, ...
        'Style', 'pushbutton', 'String', btn_configs{i,1}, ...
        'Units', 'pixels', 'Position', [5 710 - (i-1)*38 268 30], ...
        'ForegroundColor', c.text, 'BackgroundColor', btn_configs{i,3}, ...
        'FontSize', 10, 'Callback', btn_configs{i,2});
end

%   Spike Detection Panel
uicontrol(analysisPanel, ...
    'Style',           'text', ...
    'String',          'Spike Detection', ...
    'Units',           'pixels', ...
    'Position',        [5 370 268 20], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.panel, ...
    'FontSize',        10, ...
    'FontWeight',      'bold', ...
    'HorizontalAlignment',   'left');

uicontrol(analysisPanel, ...
    'Style',              'text', ...
    'String',             'Threshold Type', ...
    'Units',              'pixels', ...
    'Position',           [5 350 120 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

threshold_types = {'Relative (xMAD)','Absolute (uV)','Relative (xVrms)','Peak Detection'};

ddThresh = uicontrol(analysisPanel, ...
    'Style',           'popupmenu', ...
    'String',          threshold_types, ...
    'Value',           1, ...
    'Units',           'pixels', ...
    'Position',        [5 320 268 26], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

uicontrol(analysisPanel, ...
    'Style',              'text', ...
    'String',             'Threshold:', ...
    'Units',              'pixels', ...
    'Position',           [5 300 100 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efSpikeThresh = uicontrol(analysisPanel, ...
    'Style',           'edit', ...
    'String',          '4', ...
    'Units',           'pixels', ...
    'Position',        [70 300 35 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

uicontrol(analysisPanel, ...
    'Style',              'text', ...
    'String',             'Refractory (ms):', ...
    'Units',              'pixels', ...
    'Position',           [5 280 100 18], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           9);

efRefrac = uicontrol(analysisPanel, ...
    'Style',           'edit', ...
    'String',          '1.5', ...
    'Units',           'pixels', ...
    'Position',        [100 280 35 18], ...
    'ForegroundColor', c.text, ...
    'BackgroundColor', c.ctrl, ...
    'FontSize',        9);

%% =========================================================================
%  Store all control handles in appdata
%  =========================================================================
%
%  Any callback can retrieve these later with:
%      h = getappdata(fig, 'handles');
%      current_text = get(h.efStart, 'String');

setappdata(fig, 'handles', struct( ...
    'ddMEA',   ddMEA, ...
    'ddThresh', ddThresh, ...
    'ddFile',  ddFile, ...
    'efStart', efStart, ...
    'efEnd',   efEnd, ...
    'efYmin',  efYmin, ...
    'efYmax',  efYmax, ...
    'efSpikeThresh', efSpikeThresh, ...
    'efRefrac', efRefrac, ...
    'efVrmshigh', efVrmshigh, ...
    'efVrmslow', efVrmslow, ...
    'efZthresh', efZthresh, ...
    'cbShowExcluded', cbShowExcluded));


%% =========================================================================
%  Build the CENTER PANEL (electrode grid placeholder)
%  =========================================================================
%
%  The actual grid axes are created dynamically in cb_BuildGrid() because
%  we don't know how many electrodes there are until a file is loaded.
%  For now we just create the panel and a placeholder message.

centerPanel = uipanel(fig, ...
    'Units',           'pixels', ...
    'Position',        [283 0 615 800], ...
    'BackgroundColor', c.bg, ...
    'BorderType',      'none');

lblPlaceholder = uicontrol(centerPanel, ...
    'Style',              'text', ...
    'String',             sprintf('Load a file to\npopulate the electrode grid.'), ...
    'Units',              'pixels', ...
    'Position',           [100 350 415 60], ...
    'HorizontalAlignment','center', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.bg, ...
    'FontSize',           13);

uicontrol(centerPanel, ...
    'Style',              'text', ...
    'String',             'Electrode Grid   (click any cell to inspect)', ...
    'Units',              'pixels', ...
    'Position',           [5 773 600 22], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.bg, ...
    'FontSize',           11, ...
    'FontWeight',         'bold');

setappdata(fig, 'centerPanel',    centerPanel);
setappdata(fig, 'lblPlaceholder', lblPlaceholder);
setappdata(fig, 'gridAxes',       []);


%% =========================================================================
%  Build the RIGHT PANEL (detail waveform)
%  =========================================================================
%


rightPanel = uipanel(fig, ...
    'Units',           'pixels', ...
    'Position',        [901 0 479 800], ...
    'BackgroundColor', c.panel, ...
    'BorderType',      'none');

lblElecName = uicontrol(rightPanel, ...
    'Style',              'text', ...
    'String',             'No electrode selected', ...
    'Units',              'pixels', ...
    'Position',           [5 762 465 30], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.text, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           14, ...
    'FontWeight',         'bold');

lblZVrms = uicontrol(rightPanel, ...
    'Style',              'text', ...
    'String',             'Z: --     Vrms: --', ...
    'Units',              'pixels', ...
    'Position',           [250 762 465 22], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           10);

% Main waveform axes
axDetail = axes('Parent',   rightPanel, ...
                'Units',    'pixels', ...
                'Position', [55 445 410 300], ...
                'Color',    [0.12 0.12 0.15], ...
                'XColor',   c.textdim, ...
                'YColor',   c.textdim, ...
                'XGrid',    'on', ...
                'YGrid',    'on', ...
                'FontSize', 8);
xlabel(axDetail, 'Time (s)');
ylabel(axDetail, 'Signal (uV)');

% Vrms bar chart axes
axVrms = axes('Parent',   rightPanel, ...
              'Units',    'pixels', ...
              'Position', [55 240 410 155], ...
              'Color',    [0.12 0.12 0.15], ...
              'XColor',   c.textdim, ...
              'YColor',   c.textdim, ...
              'XGrid',    'on', ...
              'YGrid',    'on', ...
              'FontSize', 8);
ylabel(axVrms, 'Vrms (uV)');

% Impedance bar chart axes
axZ = axes('Parent',   rightPanel, ...
           'Units',    'pixels', ...
           'Position', [55 45 410 160], ...
           'Color',    [0.12 0.12 0.15], ...
           'XColor',   c.textdim, ...
           'YColor',   c.textdim, ...
           'FontSize', 8);
title(axZ, 'Impedance per Channel', 'Color', c.text);
ylabel(axZ, 'Z (kOhm)');

lblStatus = uicontrol(rightPanel, ...
    'Style',              'text', ...
    'String',             'Ready.  Load a file to begin.', ...
    'Units',              'pixels', ...
    'Position',           [5 5 465 20], ...
    'HorizontalAlignment','left', ...
    'ForegroundColor',    c.textdim, ...
    'BackgroundColor',    c.panel, ...
    'FontSize',           8);

setappdata(fig, 'rightHandles', struct( ...
    'lblElecName', lblElecName, ...
    'lblZVrms',    lblZVrms, ...
    'axDetail',    axDetail, ...
    'axVrms',      axVrms, ...
    'axZ',         axZ, ...
    'lblStatus',   lblStatus));

drawnow();

end   % <-- end of the main MEA_GUI function


%% =========================================================================
%%  CALLBACKS  (prefix: cb_)
%%  These run when the user interacts with the GUI.
%% =========================================================================

function cb_LoadFiles(fig, ddMEA, btnLoad)
% Runs when "Load Intan File(s)..." is clicked.
%
% We immediately disable the button and only re-enable it when the function
% exits. This prevents re-entry: if the user could click Load again while
% this function is still running, Octave would start a second call before
% the first finished -- that nesting is exactly "recursion depth exceeded".
%
% We also removed drawnow() from inside this callback. drawnow() flushes
% Octave's event queue, which can include a queued button click, sending
% us right back into this function before it has returned.

    % Disable button immediately -- re-enabled in the cleanup block below
    set(btnLoad, 'Enable', 'off', 'String', 'Loading...');

    rh    = getappdata(fig, 'rightHandles');
    state = get(fig, 'UserData');

    set(rh.lblStatus, 'String', 'Reading file(s)... please wait.');

    % Read MEA type from dropdown: Value = index, String = cell array
    items    = get(ddMEA, 'String');
    MEA_type = items{get(ddMEA, 'Value')};

    % Call the existing file reader (unchanged from original script)
    try
        Files_Data = read_Intan_RHS2000_multifile_BMSEED();
    catch ME
        % Print the full error to the Octave console so we can see it.
        % disp() is the most reliable output during a callback --
        % it goes straight to the terminal regardless of GUI state.
        disp('=== FILE READ ERROR ===');
        disp(ME.message);
        disp(ME.stack);
        disp('======================');
        set(btnLoad, 'Enable', 'on', 'String', 'Load Intan File(s)...');
        return
    end

    if isempty(Files_Data)
        set(rh.lblStatus, 'String', 'No files selected.');
        set(btnLoad, 'Enable', 'on', 'String', 'Load Intan File(s)...');
        return
    end

    h = getappdata(fig, 'handles');
    z_thresh       = str2double(get(h.efZthresh,   'String'))*1000;
    vrms_highthresh = str2double(get(h.efVrmshigh, 'String'));
    vrms_lowthresh  = str2double(get(h.efVrmslow,  'String'));

    % Process files: map channels, compute Vrms
    Extracted = process_all_files(Files_Data, MEA_type, ...
                                  state.start_sec, state.end_sec, z_thresh, vrms_highthresh, vrms_lowthresh);

    % Update state and save back to figure
    state.Files_Data       = Files_Data;
    state.Extracted        = Extracted;
    state.MEA_type         = MEA_type;
    state.current_file_idx = 1;
    state.current_ch_idx   = 1;
    set(fig, 'UserData', state);

    % Populate the file dropdown with short filenames
    h = getappdata(fig, 'handles');
    file_names = cell(1, length(Files_Data));
    for k = 1:length(Files_Data)
        [~, fn, ext] = fileparts(Files_Data(k).file);
        file_names{k} = [fn ext];
    end
    set(h.ddFile, 'String', file_names, 'Value', 1);

    % Hide placeholder, build grid, refresh panels
    set(getappdata(fig, 'lblPlaceholder'), 'Visible', 'off');
    cb_BuildGrid(fig);
    refresh_bar_charts(fig);
    refresh_detail(fig);

    set(rh.lblStatus, 'String', ...
        sprintf('Loaded %d file(s).   MEA type: %s', ...
                length(Files_Data), MEA_type));

    % Re-enable the button now that we are safely finished
    set(btnLoad, 'Enable', 'on', 'String', 'Load Intan File(s)...');

    t_start = Extracted(1).time(1);
    t_end   = t_start + 0.5;
    state.start_sec = t_start;
    state.end_sec   = t_end;
    set(h.efStart, 'String', sprintf('%.2f', t_start));
    set(h.efEnd,   'String', sprintf('%.2f', t_end));
end

function cb_TogglePanel(fig, show_panel, hide_panel, btn_on, btn_off)
    c = getappdata(fig, 'colors');
    set(show_panel, 'Visible', 'on');
    set(hide_panel, 'Visible', 'off');
    set(btn_on,  'BackgroundColor', [0.18 0.52 0.80], 'ForegroundColor', [0.1 0.1 0.1]);
    set(btn_off, 'BackgroundColor', [0.28 0.28 0.34], 'ForegroundColor', c.text);
end
function cb_ChangeFile(fig, ddFile)
% Runs when the user picks a different file from the dropdown.

    state = get(fig, 'UserData');
    state.current_file_idx = get(ddFile, 'Value');
    state.current_ch_idx   = 1;
    set(fig, 'UserData', state);

    cb_BuildGrid(fig);
    refresh_bar_charts(fig);
    refresh_detail(fig);
end

function cb_ToggleExcluded(fig, src)
    state      = get(fig, 'UserData');
    fi         = state.current_file_idx;
    ext        = state.Extracted(fi);
    show       = get(src, 'Value');
    gridAxes   = getappdata(fig, 'gridAxes');    % add this back

    if ~isfield(ext, 'excluded') || isempty(gridAxes)
        return
    end

    Files_Data = state.Files_Data;

    fprintf('Files_Data amplifier_data size: %d x %d\n', size(Files_Data(fi).amplifier_data));
fprintf('Excluded channels to reload: %d\n', sum(ext.excluded));
for k = find(ext.excluded(:))'
    fprintf('Channel %d raw_row_map = %d\n', k, ext.raw_row_map(k));
end

if show
    for k = find(ext.excluded(:))'
        raw_row = ext.raw_row_map(k);
        if raw_row == 0, continue; end
        state.Extracted(fi).data(:, k) = Files_Data(fi).amplifier_data(raw_row, :)';
    end
    % Recompute Vrms for reloaded channels using current time window
    time   = state.Extracted(fi).time;
    t_mask = (time >= state.start_sec) & (time <= state.end_sec);
    if ~any(t_mask)
      t_mask = (time >= time(1)) & (time <= time(1) + 0.5);
    end
    if any(t_mask)
        for k = find(ext.excluded(:))'
            state.Extracted(fi).Vrms(k) = rms(state.Extracted(fi).data(t_mask, k));
        end
    end
else
    state.Extracted(fi).data(:, ext.excluded) = 0;
    % Zero out Vrms for excluded channels when hiding
    state.Extracted(fi).Vrms(ext.excluded) = 0;
end

    set(fig, 'UserData', state);
    cb_BuildGrid(fig);
    refresh_bar_charts(fig);
    refresh_detail(fig);
end




function cb_UpdateWindow(fig)
% Runs when the user edits the Vrms start or end time fields.

    h     = getappdata(fig, 'handles');
    rh    = getappdata(fig, 'rightHandles');
    state = get(fig, 'UserData');

    % Edit fields store strings — convert to numbers
    new_start = str2double(get(h.efStart, 'String'));
    new_end   = str2double(get(h.efEnd,   'String'));

    % str2double returns NaN for non-numeric input — always validate.
    % We colour the fields to give feedback: red background = bad value.

    if isnan(new_start) || isnan(new_end) || new_start >= new_end
        set(h.efStart, 'BackgroundColor', [0.6 0.2 0.2]);
        set(h.efEnd,   'BackgroundColor', [0.6 0.2 0.2]);
        set(rh.lblStatus, 'String', ...
            'Invalid window: start must be a number less than end.');
        return
    end

    % Values are valid — reset field colours to normal
    set(h.efStart, 'BackgroundColor', [0.28 0.28 0.34]);
    set(h.efEnd,   'BackgroundColor', [0.28 0.28 0.34]);

    state.start_sec = new_start;
    state.end_sec   = new_end;

    if isempty(state.Extracted)
        set(fig, 'UserData', state);
        return
    end

    % Re-compute Vrms for the current file only using the new window
    fi     = state.current_file_idx;
    time   = state.Extracted(fi).time;
    data   = state.Extracted(fi).data;
    t_mask = (time >= new_start) & (time <= new_end);

    if ~any(t_mask)
        set(rh.lblStatus, 'String', 'Time window out of range.');
        set(fig, 'UserData', state);
        return
    end

  for k = 1:size(data, 2)
      if isfield(state.Extracted(fi), 'excluded') && state.Extracted(fi).excluded(k)
         continue
     end
     state.Extracted(fi).Vrms(k) = rms(data(t_mask, k));
  end

    set(fig, 'UserData', state);

    % Only refresh things that depend on Vrms — not the grid waveforms
    refresh_bar_charts(fig);
    refresh_detail(fig);
    rebuild_grid_vrms_labels(fig);

    set(rh.lblStatus, 'String', ...
        sprintf('Vrms recalculated  (%.2f to %.2f s)', new_start, new_end));
end


function cb_UpdateYLimits(fig)
% Runs when the user edits the Y-min or Y-max fields.

    h     = getappdata(fig, 'handles');
    rh    = getappdata(fig, 'rightHandles');
    state = get(fig, 'UserData');

    ymin = str2double(get(h.efYmin, 'String'));
    ymax = str2double(get(h.efYmax, 'String'));

    if isnan(ymin) || isnan(ymax) || ymin >= ymax
        set(h.efYmin, 'BackgroundColor', [0.6 0.2 0.2]);
        set(h.efYmax, 'BackgroundColor', [0.6 0.2 0.2]);
        set(rh.lblStatus, 'String', 'Invalid Y limits: min must be less than max.');
        return
    end

    % Valid — reset colours
    set(h.efYmin, 'BackgroundColor', [0.28 0.28 0.34]);
    set(h.efYmax, 'BackgroundColor', [0.28 0.28 0.34]);

    state.y_limits = [ymin ymax];
    set(fig, 'UserData', state);

    % Update every mini-plot in the grid without rebuilding them
    gridAxes = getappdata(fig, 'gridAxes');
    for k = 1:numel(gridAxes)
        if ishandle(gridAxes(k))
            ylim(gridAxes(k), [ymin ymax]);
        end
    end

    refresh_detail(fig);
end


function cb_SelectElectrode(fig, ch_idx)
% Runs when the user clicks a mini-plot in the electrode grid.
% ch_idx is "captured" in the anonymous function created in cb_BuildGrid.

    state = get(fig, 'UserData');
    state.current_ch_idx = ch_idx;
    set(fig, 'UserData', state);

    highlight_selected_grid_cell(fig);
    refresh_bar_charts(fig);
    refresh_detail(fig);
end


function cb_BuildGrid(fig)
% Creates the electrode grid: one small axes per channel.
% Called after loading or switching files.
%
% We delete any old grid axes first, then build fresh ones.

    state       = get(fig, 'UserData');
    c           = getappdata(fig, 'colors');
    centerPanel = getappdata(fig, 'centerPanel');
    oldAxes     = getappdata(fig, 'gridAxes');

    % Delete old axes — ishandle() checks a handle is still valid
    if ~isempty(oldAxes)
        for k = 1:numel(oldAxes)
            if ishandle(oldAxes(k))
                delete(oldAxes(k));
            end
        end
    end

    fi      = state.current_file_idx;
    ext     = state.Extracted(fi);
    num_chs = size(ext.data, 2);
    labels  = ext.id_label;
    Z_k     = ext.Z_data / 1000;
    Vrms    = ext.Vrms;

    % Grid geometry — aim for a roughly square layout
    ncols = ceil(sqrt(num_chs * 1.6));
    nrows = ceil(num_chs / ncols);

    panW  = 610;
    panH  = 765;
    cellW = floor((panW - 10) / ncols) - 3;
    cellH = floor(panH / nrows) - 3;

    gridAxes = zeros(num_chs, 1);

    for k = 1:num_chs

        % Pixel position for this cell
        % col = 0,1,2... left to right
        % row = 0,1,2... — but Octave's origin is bottom-left, so
        %   row 0 is at the BOTTOM of the panel
        col = mod(k-1, ncols);
        row = nrows - floor((k-1) / ncols) - 1;

        x = 5 + col * (cellW + 3);
        y = 5 + row * (cellH + 3);

        % Colour the background by impedance health
        if     Z_k(k) < 100,  bgcol = [0.10 0.22 0.14];  % green
        elseif Z_k(k) < 1000,  bgcol = [0.24 0.22 0.08];  % yellow
        else,                  bgcol = [0.25 0.10 0.10];  % red
        end

        ax = axes('Parent',   centerPanel, ...
                  'Units',    'pixels', ...
                  'Position', [x y cellW cellH], ...
                  'Color',    bgcol, ...
                  'XColor',   'none', ...
                  'YColor',   'none', ...
                  'XTick',    [], ...
                  'YTick',    []);

        % Downsample for speed: at most 100 points per mini-plot
        t    = ext.time;
        sig  = ext.data(:, k);
        step = max(1, floor(length(t) / 100));


        ph = plot(ax, t(1:step:end), sig(1:step:end), ...
             'Color', c.accent, 'LineWidth', 0.5);
        % HitTest 'off' means mouse clicks pass through the plot line
        % to the axes underneath, so ButtonDownFcn can fire correctly.
        set(ph, 'HitTest', 'off');
        ylim(ax, state.y_limits);

        % Labels in 'normalized' units (0-1 relative to the axes size)
        % so they stay in the right place regardless of data range
        % Use dark text so it is readable on green/yellow/red backgrounds.
        % Also set HitTest 'off' so clicks pass through to the axes.
        th1 = text(ax, 0.03, 0.94, labels{k}, ...
             'Units',             'normalized', ...
             'FontSize',          max(6, min(8, cellH/8)), ...
             'Color',             [0.10 0.10 0.10], ...
             'FontWeight',        'bold', ...
             'Interpreter',       'none', ...
             'VerticalAlignment', 'top');
        set(th1, 'HitTest', 'off');

        th2 = text(ax, 0.97, 0.06, sprintf('%.1f', Vrms(k)), ...
             'Units',              'normalized', ...
             'FontSize',           max(5, min(7, cellH/9)), ...
             'Color',              [0.10 0.10 0.10], ...
             'HorizontalAlignment','right', ...
             'Interpreter',        'none');
        th3 = text(ax, 0.1, 0.06, sprintf('%.1f', Z_k(k)), ...
             'Units',              'normalized', ...
             'FontSize',           max(5, min(7, cellH/9)), ...
             'Color',              [0.10 0.10 0.10], ...
             'HorizontalAlignment','left', ...
             'Interpreter',        'none');
        set(th2, 'HitTest', 'off');
        set(th3, 'HitTest','off');

        % Click callback — capture loop variable k by value.
        % This is a common gotcha: without 'ch_idx = k', every callback
        % would share the same k (the final loop value, num_chs).
        % Creating a new variable each iteration gives each closure its own.
        ch_idx = k;
        set(ax, 'ButtonDownFcn', ...
            @(src,event) cb_SelectElectrode(fig, ch_idx));

        gridAxes(k) = ax;
    end

if isfield(ext, 'excluded')
    h = getappdata(fig, 'handles');
    show_excluded = get(h.cbShowExcluded, 'Value');
    for k = 1:numel(gridAxes)
        if ext.excluded(k) && ~show_excluded
            set(gridAxes(k), 'Visible', 'off');
            kids = get(gridAxes(k), 'Children');
            for j = 1:numel(kids)
                set(kids(j), 'Visible', 'off');
            end
        end
    end
end

    setappdata(fig, 'gridAxes', gridAxes);
    highlight_selected_grid_cell(fig);
    drawnow();
end

function cb_RunSpikes(fig)
    state = get(fig, 'UserData');
    if isempty(state.Extracted)
        disp('No data loaded.')
        return
    end

    h = getappdata(fig, 'handles');


    % Read threshold mode
    mode_idx = get(h.ddThresh, 'Value');
    if mode_idx == 1
        mode = 'relative';
    elseif mode_idx == 2
        mode = 'absolute';
    elseif mode_idx == 3
        mode = 'relative_vrms';
    elseif mode_idx == 4
        mode = 'peak';
    end

    % Read detection parameters
    thresh       = str2double(get(h.efSpikeThresh, 'String'));
    refrac       = str2double(get(h.efRefrac,      'String'));
    filter_mode  = state.filter_mode;
    filter_order = state.filter_order;
    highp        = state.highpass;
    lowp         = state.lowpass;

    % Get data
    fi       = state.current_file_idx;
    ext      = state.Extracted(fi);
    num_chs  = size(ext.data, 2);
    Fs       = state.Files_Data(fi).fqz_param.amplifier_sample_rate;
    time     = ext.time;
    has_excluded = isfield(ext, 'excluded');
    show_excluded = get(h.cbShowExcluded, 'Value');

    for k = 1:num_chs
     if has_excluded && ext.excluded(k) && ~show_excluded
        state.spikes{k}         = [];
        state.spikes_indices{k} = [];   % was missing
        state.spike_thresh(k)   = 0;
        continue
    end
    sig = ext.data(:, k);
    [spike_times, spike_idx, threshold] = detect_spikes(sig, filter_mode, filter_order, highp, lowp, time, Fs, mode, thresh, refrac);
    state.spikes{k}         = spike_times;
    state.spikes_indices{k} = spike_idx;
    state.spike_thresh(k)   = threshold;
  end

    rh = getappdata(fig, 'rightHandles');
    state.spikes_computed = true;
    set(fig, 'UserData', state);
    set(rh.lblStatus, 'String', 'Spike Detection Complete.');
    overlay_spikes_on_grid(fig);
    refresh_detail(fig);
end

function cb_ExportCSV(fig)
% Save Z and Vrms for the current file to a CSV.

    state = get(fig, 'UserData');
    rh    = getappdata(fig, 'rightHandles');

    if isempty(state.Extracted)
        errordlg('No data loaded.', 'Export');
        return
    end

    fi      = state.current_file_idx;
    ext     = state.Extracted(fi);

    default_name = [state.Files_Data(fi).file(1:end-4) '_Z_and_Vrms.csv'];
    [fname, fpath] = uiputfile('*.csv', 'Save Z and Vrms', default_name);
    if isequal(fname, 0), return; end   % user cancelled

    % Write CSV with fprintf
    % fopen returns a file ID (fid); always fclose() when done
    fid = fopen(fullfile(fpath, fname), 'w');
    fprintf(fid, 'Electrode,Z (kOhms),Vrms (uV)\n');
    for k = 1:length(ext.id_label)
        fprintf(fid, '%s,%.3f,%.4f\n', ...
                ext.id_label{k}, ext.Z_data(k)/1000, ext.Vrms(k));
    end
    fclose(fid);

    set(rh.lblStatus, 'String', ['Saved: ' fullfile(fpath, fname)]);
end


function cb_ExportPNG(fig)
% Save the current detail waveform axes as a PNG. WORK IN PROGRESS

    state = get(fig, 'UserData');
    rh    = getappdata(fig, 'rightHandles');

    if isempty(state.Extracted)
        errordlg('No data loaded.', 'Export');
        return
    end

    fi  = state.current_file_idx;
    chi = state.current_ch_idx;
    lbl = state.Extracted(fi).id_label{chi};

    default_name = [state.Files_Data(fi).file(1:end-4) '_' lbl '.png'];
    [fname, fpath] = uiputfile('*.png', 'Save Plot', default_name);
    if isequal(fname, 0), return; end

    % print() saves a figure/axes to file
    % '-dpng' = PNG format, '-r150' = 150 DPI resolution
    print(rh.axDetail, fullfile(fpath, fname), '-dpng', '-r150');

    set(rh.lblStatus, 'String', ['Saved: ' fullfile(fpath, fname)]);
end




%% =========================================================================
%%  RENDER HELPERS  — update visuals without rebuilding the whole GUI
%% =========================================================================

function overlay_spikes_on_grid(fig)

    state = get(fig, 'UserData');
    gridAxes = getappdata(fig, 'gridAxes');

    if state.spikes_computed == false
      disp("Spikes not yet computed");
      return
   end

   for k = 1:numel(gridAxes)
     if ~ishandle(gridAxes(k)), continue; end
     spike_times = state.spikes{k};
      if isempty(spike_times)
        continue
      end
     hold(gridAxes(k), 'on');
     yl = ylim(gridAxes(k));
     tick_height = (yl(2) - yl(1)) * 0.12;
     y_top = yl(2) * 0.95;
     plot(gridAxes(k), [spike_times spike_times]', [ones(size(spike_times))*y_top, ones(size(spike_times))*(y_top - tick_height)]', ...
       'r-', 'LineWidth', 1, 'HitTest', 'off');
     hold(gridAxes(k), 'off');
    end
end

function refresh_detail(fig)
% Redraws the right-panel waveform for the selected electrode.

    state = get(fig, 'UserData');
    rh    = getappdata(fig, 'rightHandles');
    c     = getappdata(fig, 'colors');

    if isempty(state.Extracted), return; end

    fi  = state.current_file_idx;
    chi = min(state.current_ch_idx, size(state.Extracted(fi).data, 2));
    ext = state.Extracted(fi);

    fprintf('refresh_detail: chi=%d, sig range: %.2f to %.2f\n', chi, ...
        min(ext.data(:,chi)), max(ext.data(:,chi)));
    lbl  = ext.id_label{chi};
    Zk   = ext.Z_data(chi) / 1000;
    vrms = ext.Vrms(chi);
    time = ext.time;
    sig  = ext.data(:, chi);

    set(rh.lblElecName, 'String', ['Electrode: ' lbl]);
    set(rh.lblZVrms,    'String', ...
        sprintf('Z = %.1f kOhm     Vrms = %.2f uV', Zk, vrms));

    ax = rh.axDetail;
    cla(ax);    % clear axes content without deleting the axes


    plot(ax, time, sig, 'Color', c.accent, 'LineWidth', 1);
    ylim(ax, state.y_limits);
    xlim(ax, [time(1) time(end)]);

    % Shade the Vrms window using patch() — draws a filled polygon
    t0 = state.start_sec;
    t1 = state.end_sec;
    yl = state.y_limits;
    fprintf('patch window: %.2f to %.2f, time range: %.2f to %.2f\n', ...
        t0, t1, time(1), time(end));
    patch(ax, [t0 t1 t1 t0], [yl(1) yl(1) yl(2) yl(2)], ...
          [1.0 0.8 0.2], ...       % fill colour (yellow)
          'FaceAlpha', 0.13, ...   % transparency 0=invisible, 1=solid
          'EdgeColor', [1.0 0.8 0.2], ...
          'LineStyle', '--', ...
          'LineWidth', 1.2);

    set(ax, 'Color',   [0.12 0.12 0.15], ...
        'XColor',  c.textdim, ...
        'YColor',  c.textdim, ...
        'XGrid',   'on', ...
        'YGrid',   'on', ...
        'FontSize', 8);

    % Vertical marker lines
    line(ax, [t0 t0], yl, 'Color', [1 0.8 0.2], ...
         'LineStyle', '--', 'LineWidth', 1.5);
    line(ax, [t1 t1], yl, 'Color', [1 0.8 0.2], ...
         'LineStyle', '--', 'LineWidth', 1.5);

    title(ax, ['Waveform:  ' lbl], 'Color', c.text, 'Interpreter', 'none');
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Signal (uV)');

    if state.spikes_computed == true
      hold(ax, 'on');
      thr = state.spike_thresh(chi);
      line(ax, [time(1) time(end)], [thr thr], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.2);
      yl = ylim(ax);
      tick_height = (yl(2) - yl(1)) * 0.12;
      y_top = yl(2) * 0.95;
      st = state.spikes{chi};
      if ~isempty(st)
        plot(ax, [st st]', [ones(size(st))*y_top, ones(size(st))*(y_top - tick_height)]', ...
         'r-', 'LineWidth', 1, 'HitTest', 'off');
      end
      text(ax, time(1), thr, sprintf(' %.1f uV', thr), ...
      'Color', 'r', 'FontSize', 8, 'VerticalAlignment', 'bottom');
      hold(ax, 'off');
    end
end


function refresh_bar_charts(fig)
% Redraws the Vrms and Z bar charts in the right panel.

    state = get(fig, 'UserData');
    rh    = getappdata(fig, 'rightHandles');
    c     = getappdata(fig, 'colors');

    fi   = state.current_file_idx;
    chi  = state.current_ch_idx;
    ext  = state.Extracted(fi);
    has_excluded = isfield(ext, 'excluded');
    n    = length(ext.Vrms);

    h = getappdata(fig, 'handles');
    show_excluded = get(h.cbShowExcluded, 'Value');


    % ---- Vrms bar chart ----
    ax = rh.axVrms;
    cla(ax);
    vcols = vrms_colormap(ext.Vrms);
    vcols(chi, :) = c.sel;   % highlight selected channel in orange

    % Draw each bar individually — Octave doesn't support per-bar colour
    % directly through a single bar() call, so we loop
    hold(ax, 'on');
    for k = 1:n
        if has_excluded && ext.excluded(k) && ~show_excluded, continue; end
        bar(ax, k, ext.Vrms(k), 'FaceColor', vcols(k,:), 'EdgeColor','none');
    end
    hold(ax, 'off');
    set(ax, 'XTick', [], 'XLim', [0 n+1]);
    title(ax, 'Vrms per Channel', 'Color', c.text);
    ylabel(ax, 'Vrms (uV)');

    % ---- Z bar chart ----
    ax = rh.axZ;
    cla(ax);
    zcols = z_colormap(ext.Z_data / 1000);
    zcols(chi, :) = c.sel;

    hold(ax, 'on');
    for k = 1:n
        if has_excluded && ext.excluded(k) && ~show_excluded, continue; end
        bar(ax, k, ext.Z_data(k)/1000, 'FaceColor', zcols(k,:), ...
            'EdgeColor', 'none');
    end
    hold(ax, 'off');
    set(ax, 'XTick', [], 'XLim', [0 n+1]);
    title(ax, 'Impedance per Channel', 'Color', c.text);
    ylabel(ax, 'Z (kOhm)');
end


function rebuild_grid_vrms_labels(fig)
% Updates only the Vrms number on each mini-plot after recalculation.
% Much faster than rebuilding the entire grid.

    state    = get(fig, 'UserData');
    c        = getappdata(fig, 'colors');
    gridAxes = getappdata(fig, 'gridAxes');

    if isempty(gridAxes), return; end

    fi   = state.current_file_idx;
    Vrms = state.Extracted(fi).Vrms;

    for k = 1:numel(gridAxes)
        if ~ishandle(gridAxes(k)), continue; end

        % get Children returns all objects inside the axes
        % We find the text objects and update the Vrms one (bottom-right)
        kids     = get(gridAxes(k), 'Children');
        type_arr = get(kids, 'Type');
        if iscell(type_arr)
            is_text = cellfun(@(t) strcmp(t,'text'), type_arr);
        else
            is_text = strcmp(type_arr, 'text');
        end
        txt_kids = kids(is_text);

        % We added: label text first, Vrms text second
        % Children are returned newest-first, so Vrms text is txt_kids(1)
        if numel(txt_kids) >= 1
            set(txt_kids(1), 'String', sprintf('%.1f', Vrms(k)));
        end
    end
end


function highlight_selected_grid_cell(fig)
% Puts an orange border on the currently selected mini-plot cell.

    state    = get(fig, 'UserData');
    c        = getappdata(fig, 'colors');
    gridAxes = getappdata(fig, 'gridAxes');

    if isempty(gridAxes), return; end

    for k = 1:numel(gridAxes)
        if ~ishandle(gridAxes(k)), continue; end
        if k == state.current_ch_idx
            set(gridAxes(k), ...
                'XColor',       c.sel, ...
                'YColor',       c.sel, ...
                'LineWidth',    2, ...
                'Box',          'on');
        else
            set(gridAxes(k), ...
                'XColor', 'none', ...
                'YColor', 'none', ...
                'Box',    'off');
        end
    end
end




%% =========================================================================
%%  DATA PROCESSING
%% =========================================================================

function Extracted = process_all_files(Files_Data, MEA_type, start_sec, end_sec, z_thresh = 600000, vrms_highthresh = 50, vrms_lowthresh = 2)
% Maps Intan channel data onto MEA electrode positions, computes Vrms.

    switch MEA_type
        case 'sMEA_gen4ad',  num_chs = 30;
        case 'sMEA_gen4ef',  num_chs = 32;
        case 'sMEA_gen4g',   num_chs = 32;
        case 'sMEA_gen6a',   num_chs = 60;
        case 'sMEA_gen6b',   num_chs = 60;
        case 'sMEA_gen7a',   num_chs = 34;
        case '60ch_gMEA',    num_chs = 60;
        case '120ch_gMEA',   num_chs = 124;
        otherwise,           num_chs = 60;
    end

    Extracted = struct();

    for f_idx = 1:length(Files_Data)

        amplifier_ch   = Files_Data(f_idx).amplifier_channels;
        amplifier_data = Files_Data(f_idx).amplifier_data;
        t              = Files_Data(f_idx).t;
        stim_data      = Files_Data(f_idx).Stim_data;
        ain_data       = Files_Data(f_idx).b_adc_dat;

        data      = zeros(length(t), num_chs);
        stim      = zeros(length(t), num_chs);
        Z_data    = zeros(num_chs, 1);
        Vrms      = zeros(num_chs, 1);
        id_label  = cell(num_chs, 1);
        id_header = cell(num_chs, 1);
        raw_row_map = zeros(num_chs, 1);

        for k = 1:length(amplifier_ch)

            temp = amplifier_ch(k).custom_channel_name;

            if length(temp) >= 4
                if strcmp(temp(1:4),'Plex') || ~isempty(strfind(temp,'GND'))
                    continue
                end
            end


            char_type_array = isstrprop(temp, 'digit');
            num_char_id     = find(char_type_array, 2);
            if isempty(num_char_id), continue; end

            if ~strcmp(MEA_type, '120ch_gMEA')
                if char_type_array(1)
                    num_char_id = num_char_id(min(2,end));
                else
                    num_char_id = num_char_id(1);
                end
                if num_char_id < 2, continue; end
                prev = temp(num_char_id - 1);
                if prev=='r' || prev=='R'
                    id = temp(num_char_id-1 : num_char_id);
                elseif prev=='C' || prev=='P'
                    id = temp(num_char_id-1 : min(num_char_id+1,end));
                else
                    id = temp(num_char_id : min(num_char_id+1,end));
                end
            else
                num_char_id = num_char_id(1);
                if num_char_id < 2, continue; end
                prev = temp(num_char_id - 1);
                if prev=='r' || prev=='R'
                    id = temp(num_char_id-1 : min(num_char_id+1,end));
                else
                    id = temp(num_char_id : min(num_char_id+2,end));
                end
            end

            idx = map_channel_id(id, MEA_type);
            if idx < 1 || idx > num_chs, continue; end

            raw_row_map(idx) = k;
            data(:, idx)  = amplifier_data(k, :)';
            stim(:, idx)  = stim_data(k, :)';
            Z_data(idx)   = amplifier_ch(k).electrode_impedance_magnitude;

            if id(1)=='r' || id(1)=='R'
                id_label{idx}  = ['REF ' id(2)];
                id_header{idx} = ['REF_' id(2)];
            else
                id_label{idx}  = ['E' id];
                id_header{idx} = ['E' id];
            end

            if strcmp(MEA_type,'sMEA_gen6a') && strcmp(id,'07')
                id_label{idx} = 'REF 1'; id_header{idx} = 'REF_1';
            elseif strcmp(MEA_type,'60ch_gMEA') && strcmp(id,'15')
                id_label{idx} = 'REF 1'; id_header{idx} = 'REF_1';
            end
        end

        % Fill empty labels
        for k = 1:num_chs
            if isempty(id_label{k}),  id_label{k}  = sprintf('Ch%02d',k); end
            if isempty(id_header{k}), id_header{k} = sprintf('Ch%02d',k); end
        end

        % Sort: 'E' before 'R' alphabetically puts recording before reference
        [~, sort_idx] = sort(id_label);
        id_label  = id_label(sort_idx);
        id_header = id_header(sort_idx);
        data      = data(:, sort_idx);
        stim      = stim(:, sort_idx);
        Z_data    = Z_data(sort_idx);
        raw_row_map = raw_row_map(sort_idx);

        % Vrms
        time   = t';
        t_mask = (time >= start_sec) & (time <= end_sec);
        if ~any(t_mask)
          t_mask = (time >= time(1)) & (time <= time(1) + 0.5);
        end
        if any(t_mask)
          for k = 1:num_chs
            Vrms(k) = rms(data(t_mask, k));
          end
        end

        excluded = (Z_data >= z_thresh) | ...
                   (Vrms >= vrms_highthresh) | ...
                   (Vrms <= vrms_lowthresh);

        data(:, excluded) = 0;

        Extracted(f_idx).time      = time;
        Extracted(f_idx).data      = data;
        Extracted(f_idx).stim      = stim;
        Extracted(f_idx).a_in      = ain_data';
        Extracted(f_idx).Z_data    = Z_data;
        Extracted(f_idx).Vrms      = Vrms;
        Extracted(f_idx).id_label  = id_label;
        Extracted(f_idx).id_header = id_header;
        Extracted(f_idx).excluded = excluded;
        Extracted(f_idx).raw_row_map = raw_row_map;
    end
end


function idx = map_channel_id(id, MEA_type)
% Converts a channel ID string (e.g. '06', 'r1', 'C03') to a column index.

    idx = 0;

    if strcmp(id,'r1')||strcmp(id,'R1')
        switch MEA_type
            case 'sMEA_gen4ad', idx=29; case 'sMEA_gen4ef', idx=29;
            case 'sMEA_gen4g',  idx=29; case 'sMEA_gen6a',  idx=7;
            case 'sMEA_gen6b',  idx=9;  case 'sMEA_gen7a',  idx=31;
            case '60ch_gMEA',   idx=15; case '120ch_gMEA',  idx=121;
        end
    elseif strcmp(id,'r2')||strcmp(id,'R2')
        switch MEA_type
            case 'sMEA_gen4ad', idx=30; case 'sMEA_gen4ef', idx=30;
            case 'sMEA_gen4g',  idx=30; case 'sMEA_gen6a',  idx=24;
            case 'sMEA_gen6b',  idx=24; case 'sMEA_gen7a',  idx=32;
            case '120ch_gMEA',  idx=122;
        end
    elseif strcmp(id,'r3')||strcmp(id,'R3')
        switch MEA_type
            case 'sMEA_gen4ef', idx=31; case 'sMEA_gen4g',  idx=31;
            case 'sMEA_gen6a',  idx=38; case 'sMEA_gen6b',  idx=39;
            case 'sMEA_gen7a',  idx=33; case '120ch_gMEA',  idx=123;
        end
    elseif strcmp(id,'r4')||strcmp(id,'R4')
        switch MEA_type
            case 'sMEA_gen4ef', idx=32; case 'sMEA_gen4g',  idx=32;
            case 'sMEA_gen6a',  idx=54; case 'sMEA_gen6b',  idx=54;
            case 'sMEA_gen7a',  idx=34; case '120ch_gMEA',  idx=124;
        end
    else
        idx = round(str2double(id));
        if isnan(idx), idx = 0; return; end

        if strcmp(MEA_type,'sMEA_gen6a')
            if     idx>=17&&idx<=31, idx=idx-1;
            elseif idx>=33&&idx<=47, idx=idx-2;
            elseif idx>=49&&idx<=63, idx=idx-3;
            end
        end

        if strcmp(MEA_type,'sMEA_gen7a')
            if     length(id)>=2 && id(1)=='C', idx=str2double(id(2:end));
            elseif length(id)>=2 && id(1)=='P', idx=10+str2double(id(2:end));
            end
        end
    end
end




%% =========================================================================
%%  COLOUR MAP HELPERS
%% =========================================================================

function rgb = vrms_colormap(Vrms)
% Returns Nx3 colour array: green <5 uV, yellow 5-10 uV, red >10 uV
    n = length(Vrms); rgb = zeros(n,3);
    for k = 1:n
        if     Vrms(k)<5,  rgb(k,:)=[0.20 0.75 0.45];
        elseif Vrms(k)<10,  rgb(k,:)=[0.95 0.75 0.20];
        else,               rgb(k,:)=[0.85 0.30 0.25];
        end
    end
end

function rgb = z_colormap(Z_kOhms)
% Returns Nx3 colour array: green <200, yellow <600, red >=600 kOhm
    n = length(Z_kOhms); rgb = zeros(n,3);
    for k = 1:n
        if     Z_kOhms(k)<200, rgb(k,:)=[0.20 0.75 0.45];
        elseif Z_kOhms(k)<600, rgb(k,:)=[0.95 0.75 0.20];
        else,                   rgb(k,:)=[0.85 0.30 0.25];
        end
    end
end
