//+------------------------------------------------------------------+
//|                                           MT5_EnergyTrading.mq5 |
//|                        Copyright 2026, Quantitative Trading Model|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Quantitative Trading Model"
#property link      "https://www.mql5.com"
#property version   "2.40"

#include <Canvas\Canvas.mqh>
#include "Opportunity\PureRelease\PR_Facade.mqh"
#include "CaseManagement\Deletion\CD_Facade.mqh"
#include "UI\UI_Router.mqh"

// Keep a plain-text version string for runtime logging (helps detect wrong/old compiled ex5 running).
#define EA_VERSION_STR "2.40"

// --- DLL Imports for Named Pipe (Kernel32) ---
#import "kernel32.dll"
long CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, uint lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, long hTemplateFile);
bool ReadFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToRead, uint &lpNumberOfBytesRead, long lpOverlapped);
bool WriteFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToWrite, uint &lpNumberOfBytesWritten, long lpOverlapped);
bool CloseHandle(long hObject);
bool PeekNamedPipe(long hNamedPipe, long lpBuffer, int nBufferSize, long lpBytesRead, uint &lpTotalBytesAvail, long lpBytesLeftThisMessage);
#import

#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

// --- Inputs ---
input bool     InpCreateCustomSymbol = true;          // Create Custom Symbol (EURUSD_2024)?
input string   InpSymbolName         = "EURUSD@_2024"; // Custom Symbol Name (with @ suffix)
input string   InpBaseSymbol         = "EURUSD@";     // Base Symbol (Source Specs)
input ENUM_TIMEFRAMES InpReplayTimeframe = PERIOD_M15; // Replay Chart Timeframe
input bool     InpEnableFullChart    = true;          // Open full-history chart?
input bool     InpFullOnlyMode       = true;          // Keep only the FULL chart and disable replay startup
input string   InpFullSymbolName     = "EURUSD@_2002_FULL"; // Full-history Custom Symbol
input ENUM_TIMEFRAMES InpFullTimeframe = PERIOD_H1;   // Full-history Chart Timeframe
input string   InpFullCsvPath        = "split_by_year\\EURUSD_2002.csv"; // MQL5/Files-relative full-history CSV path
input bool     InpFullLoadAllYears   = false;         // Legacy compatibility; yearly FULL symbols load one CSV each
input int      InpFullStartYear      = 2002;          // First year for all-history import
input int      InpFullEndYear        = 2008;          // Last selectable work year
input bool     InpFullAutoLoad       = true;          // Auto-load full history on start
input bool     InpFullForceReload    = false;         // Force reload even if already loaded
input bool     InpFullApplyTemplate = true;         // Apply template to FULL chart?
input bool     InpFullAutoAttachEA  = true;         // Auto-attach EA on FULL chart via template?
input string   InpFullEATemplateName = "MT5_EnergyTrading_FULL.tpl"; // Template that contains EA for FULL chart
input string   InpFullEATemplateAltPath = "";      // Optional absolute path for FULL EA template
input bool     InpShowFullModeLabel = false;        // Show FULL MODE text label on chart?
input bool     InpFullAutoLoadAccumulation = false; // Auto-load Phase-A accumulation zones on FULL chart?
input string   InpAccumulationCsvPath = "E:\\Quantitative trading model\\Data\\Local_Data\\labels\\accumulation_labels.csv"; // Phase-A labels CSV
input int      InpAccumulationMaxZones = 1200;      // Hard cap to avoid too many objects
input color    InpAccumulationZoneColor = C'250,225,130'; // Zone rectangle color
input bool     InpAccumulationDrawInBackground = true; // Draw zones behind candles?
input string   InpManualBoxesCsvPath = "manual_accumulation_boxes.csv"; // Exported manual annotation boxes
input bool     InpOpenDefaultCaseOnStartup = false; // Open the configured default case when no session exists?
input string   InpAnnotationCaseId = "EURUSD-2002-H1-CHANNEL-001"; // Optional default opportunity case ID
input string   InpAnnotationCaseType = "ASCENDING_CHANNEL"; // Optional default opportunity type
input string   InpOpportunityCasesCsvPath = "opportunity_annotations\\opportunity_cases.csv"; // Case snapshot archive
input string   InpOpportunityAnchorsCsvPath = "opportunity_annotations\\opportunity_anchors.csv"; // Anchor snapshot archive
input string   InpOpportunityKeyBarsCsvPath = "opportunity_annotations\\opportunity_key_bars.csv"; // Key-bar snapshot archive
input string   InpOpportunityDrawingsCsvPath = "opportunity_annotations\\opportunity_drawings.csv"; // Native drawing snapshot archive
input string   InpOpportunityRegionsCsvPath = "opportunity_annotations\\opportunity_regions.csv"; // Three-stage region archive
input string   InpOpportunityDrawingSemanticsCsvPath = "opportunity_annotations\\opportunity_drawing_semantics.csv"; // Derived drawing semantic archive
input string   InpOpportunityChannelBoundariesCsvPath = "opportunity_annotations\\opportunity_channel_boundaries.csv"; // Expanded native-channel boundary archive
input string   InpOpportunityCaseSequencesCsvPath = "opportunity_annotations\\opportunity_case_sequences.csv"; // Deleted-case sequence high-water archive
input string   InpOpportunityCaseDeleteJournalPath = "opportunity_annotations\\opportunity_case_delete.txn"; // Case-deletion recovery journal
input bool     InpOpportunityGeometryAdvice = true; // Log read-only geometry semantic advice?
input bool     InpOpportunityGeometryPreview = true; // Show non-persistent geometry semantic overlay?
input int      InpStructureRadiusBars = 2; // Default structure-circle radius in chart bars
input color    InpStructureCircleColor = C'46,110,80'; // Structure-circle outline color
input color    InpKeyBarColor = clrGold; // Native key-bar highlight color
input double   InpChannelParallelTolerance = 0.35; // Maximum relative upper/lower slope difference
input bool     InpReplayApplyTemplate = false;         // Apply template to REPLAY chart?
input bool     InpTemplateForceReapply = false;        // Force re-apply template (may restart EA once)
input bool     InpReplayUseTemplateColors = true;      // Use template colors on REPLAY chart without ChartApplyTemplate (prevents EA removal)
input bool     InpBringFullChartToTop   = true;      // Bring FULL chart to top when opened

// --- Chart Appearance (Colors Only; avoids template side-effects) ---
input bool  InpColorsEnabled      = false;  // Apply color theme via ChartSetInteger (no template)
input bool  InpShowGrid           = false;  // Show grid
input color InpColorBackground    = clrBlack;
input color InpColorForeground    = clrSilver;
input color InpColorGrid          = clrDimGray;
input color InpColorBullCandle    = clrLime;
input color InpColorBearCandle    = clrRed;
input color InpColorChartUp       = clrLime;
input color InpColorChartDown     = clrRed;
input color InpColorBid           = clrDodgerBlue;
input color InpColorAsk           = clrTomato;
input color InpColorStopLevels    = clrOrange;
// input string   InpFileName           = "EURUSD_2024_Import.csv"; // REMOVED: No longer used
input string   InpTemplateName       = "red_green_entry.tpl"; // Chart template to apply
input string   InpTemplateAltPath    = ""; // Fallback absolute path
input string   InpPythonPath         = "E:\\Quantitative trading model\\src\\AsipanEnergyTradingSystem\\modules\\replay\\launch_feed.bat"; // Launcher Batch File
input string   InpScriptPath         = ""; // Script Path (Handled by Batch File)

// --- Constants ---
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000
#define OPEN_EXISTING 3
#define INVALID_HANDLE_VALUE -1
#define PIPE_ACCESS_DUPLEX 3
#define FULL_VIEWPORT_RESTORE_MAX_AGE_SECONDS 30
#define FULL_VIEWPORT_RESTORE_MAX_PASSES 3

// --- Global Variables ---
string pipeName = "\\\\.\\pipe\\MT5_Python_Bridge";
long hPipe = INVALID_HANDLE_VALUE;
bool isPaused = true; // Default to PAUSED (matches Python state)
bool isFullChartInstance = false; // If EA is running on full-history chart, keep it passive

// UI Globals
int ui_base_x = 6;
int ui_base_y = 20;
bool isDraggingPanel = false; // No longer used for panel, but maybe for general drag state?
bool isDraggingKnob = false;  // Track if we are currently dragging the knob
int last_mouse_x = 0;
int last_mouse_y = 0;
double currentSpeed = 3.0; // Default Speed
int batchSize = 1; // Default Batch Size (x1)
string rx_buffer = ""; // Accumulate pipe data for line-based parsing
string GV_FULL_LOADED = "Energy_FullLoaded";
string GV_FULL_WORK_YEAR = "Energy_FullWorkYear";
string GV_FULL_VIEWPORT_PREFIX = "Energy_FullViewport_";
bool GV_DEBUG_FULL = true; // Full-history debug logs
string fullRuntimeSymbol = "";
int fullWorkYear = 0;

// UI object names (replay/main chart)
string OBJ_BTN_FULL_LOAD_MAIN = "btn_full_load_main";
string OBJ_FULL_PANEL_BG = "full_ui_bg";
string OBJ_FULL_BTN_LOAD = "btn_full_load";
string OBJ_FULL_BTN_HOME = "btn_full_home";
string OBJ_FULL_BTN_WORK_YEAR = "btn_full_work_year";
string OBJ_FULL_WORK_YEAR_OPTION_PREFIX = "btn_full_work_year_option_";
string OBJ_FULL_BTN_KEY_BAR = "btn_full_key_bar";
string OBJ_FULL_BTN_SAVE_STRUCTURE = "btn_full_save_structure";
string OBJ_FULL_BTN_ACC_LOAD = "btn_full_acc_load";
string OBJ_FULL_BTN_ACC_CLEAR = "btn_full_acc_clear";
string OBJ_FULL_BTN_EXPORT_MANUAL = "btn_full_export_manual";
string OBJ_FULL_BTN_NEW_BOX = "btn_full_new_box";
string OBJ_FULL_BTN_FILL_MANUAL = "btn_full_fill_manual";
string ACC_OBJECT_PREFIX = "ACC_";
string OBJ_FULL_BTN_STRUCTURE = "btn_full_structure";
string OBJ_FULL_BTN_SIZE_DOWN = "btn_full_structure_size_down";
string OBJ_FULL_STRUCTURE_SIZE = "lbl_full_structure_size";
string OBJ_FULL_BTN_SIZE_UP = "btn_full_structure_size_up";
string OBJ_FULL_BTN_UPPER = "btn_full_upper";
string OBJ_FULL_BTN_LOWER = "btn_full_lower";
string OBJ_FULL_BTN_OPPORTUNITY_TYPE = "btn_full_opportunity_type";
string OBJ_FULL_OPPORTUNITY_TYPE_OPTION_PREFIX = "btn_full_opportunity_type_option_";
string OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE = "btn_full_opportunity_standardity_toggle";
string OBJ_FULL_BTN_UNDO = "btn_full_undo";
string OBJ_FULL_BTN_CLEAR_CHART = "btn_full_clear_chart";
string OBJ_FULL_ANNOTATION_STATUS = "lbl_full_annotation_status";
string OBJ_FULL_BTN_CASE_SELECTOR = "btn_full_case_selector";
string OBJ_FULL_BTN_CASE_SEARCH_YEAR = "btn_full_case_search_year";
string OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY = "btn_full_case_search_opportunity";
string OBJ_FULL_LBL_CASE_DIRECT_YEAR = "lbl_full_case_direct_year";
string OBJ_FULL_EDIT_CASE_DIRECT_YEAR = "edit_full_case_direct_year";
string OBJ_FULL_LBL_CASE_DIRECT_NUMBER = "lbl_full_case_direct_number";
string OBJ_FULL_EDIT_CASE_DIRECT_NUMBER = "edit_full_case_direct_number";
string OBJ_FULL_BTN_CASE_DETAILS = "btn_full_case_details";
string OBJ_FULL_CASE_OPTION_PREFIX = "btn_full_case_option_";
string OBJ_FULL_CASE_YEAR_PREFIX = "btn_full_case_year_";
string OBJ_FULL_CASE_TYPE_PREFIX = "btn_full_case_type_";
string OBJ_FULL_CASE_BACK = "btn_full_case_back";
string OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY = "full_opportunity_session_state";
string OPPORTUNITY_SESSION_OBJECT_PREFIX = "full_opp_session_";
string OBJ_FULL_OPPORTUNITY_NO_SELECTION = "full_opportunity_no_selection_v1";
string OPPORTUNITY_OBJECT_PREFIX = "OPP_ANNOT_";
string OPPORTUNITY_DRAWING_OBJECT_PREFIX = "OPP_DRAW_";
string OPPORTUNITY_REGION_OBJECT_PREFIX = "OPP_REGION_";
string OPPORTUNITY_GEOMETRY_OBJECT_PREFIX = "OPP_GEOMETRY_";
string OPPORTUNITY_DETAILS_OBJECT_PREFIX = "full_case_details_";
string OBJ_OPPORTUNITY_DETAILS_BG = "full_case_details_bg";
string OBJ_OPPORTUNITY_DETAILS_TITLE = "full_case_details_title";
string OBJ_OPPORTUNITY_DETAILS_PAGE = "full_case_details_page";
string OBJ_OPPORTUNITY_DETAILS_CLOSE = "full_case_details_close";
string OBJ_OPPORTUNITY_DETAILS_PREV = "full_case_details_prev";
string OBJ_OPPORTUNITY_DETAILS_NEXT = "full_case_details_next";

#define OPPORTUNITY_LINE_ANCHOR_COUNT 4
#define OPPORTUNITY_STRUCTURE_RADIUS_MIN 1
#define OPPORTUNITY_STRUCTURE_RADIUS_MAX 10
#define OPPORTUNITY_STRUCTURE_MARKER_MIN_RADIUS_PX 8
#define OPPORTUNITY_STRUCTURE_MARKER_MAX_RADIUS_PX 240
#define OPPORTUNITY_STRUCTURE_DOUBLE_CLICK_MS 450
#define OPPORTUNITY_KEY_BAR_HALF_WIDTH_RATIO 0.45
#define OPPORTUNITY_KEY_BAR_MIN_HALF_WIDTH_PX 4
#define OPPORTUNITY_KEY_BAR_VERTICAL_PADDING_PX 3
#define OPPORTUNITY_KEY_BAR_BORDER_WIDTH_PX 2
#define OPPORTUNITY_DRAWING_MAX_ANCHORS 3
#define OPPORTUNITY_REGION_COUNT 3
#define OPPORTUNITY_REGION_BOUNDARY_COUNT 4
#define OPPORTUNITY_REGION_LABEL_HEIGHT_PX 24
#define OPPORTUNITY_REGION_LABEL_FONT_SIZE 8
#define OPPORTUNITY_REGION_LABEL_BOTTOM_GAP_PX 58
#define OPPORTUNITY_CASE_TEXT_BOTTOM_PX 30
#define OPPORTUNITY_CASE_TEXT_START_GAP_PX 14
#define OPPORTUNITY_SAVE_FEEDBACK_SUCCESS_MS 2000
#define OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS 3000
#define OPPORTUNITY_CASE_FEEDBACK_SUCCESS_MS 3000
#define OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS 4000
#define OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS 250
#define OPPORTUNITY_TYPE_MENU_CLICK_GUARD_MS 250
#define OPPORTUNITY_TYPE_COUNT 14
#define OPPORTUNITY_LEVEL_H1_MAX_H1_BARS 168
#define OPPORTUNITY_LEVEL_H4_MAX_H1_BARS 672
#define OPPORTUNITY_SESSION_STATE_VERSION "V4"
#define OPPORTUNITY_GEOMETRY_PRE_MIN_R1_OVERLAP 0.55
#define OPPORTUNITY_GEOMETRY_STRUCTURE_MIN_R2_OVERLAP 0.45
#define OPPORTUNITY_GEOMETRY_PRE_MIN_DISPLACEMENT_ATR 5.0
#define OPPORTUNITY_GEOMETRY_PRE_MIN_SLOPE_ATR 0.05
#define OPPORTUNITY_GEOMETRY_PRE_MIN_EFFICIENCY 0.10
#define OPPORTUNITY_GEOMETRY_PREVIEW_RELEASE_WIDTH 4
#define OPPORTUNITY_GEOMETRY_PREVIEW_STRUCTURE_WIDTH 2
#define OPPORTUNITY_GEOMETRY_PREVIEW_REVIEW_WIDTH 3
#define OPPORTUNITY_GEOMETRY_PREVIEW_TAG_FONT_SIZE 9
#define OPPORTUNITY_GEOMETRY_ALGORITHM_VERSION "GEOMETRY_V3"
#define OPPORTUNITY_GEOMETRY_FEATURE_VERSION "H1_GEOMETRY_V3"
#define OPPORTUNITY_GEOMETRY_LEGACY_ALGORITHM_VERSION "GEOMETRY_V1"
#define OPPORTUNITY_GEOMETRY_LEGACY_FEATURE_VERSION "H1_GEOMETRY_V1"
#define OPPORTUNITY_GEOMETRY_PREVIOUS_ALGORITHM_VERSION "GEOMETRY_V2"
#define OPPORTUNITY_GEOMETRY_PREVIOUS_FEATURE_VERSION "H1_GEOMETRY_V2"
#define OPPORTUNITY_DRAWING_SEMANTIC_SCHEMA_VERSION "1"
#define OPPORTUNITY_CHANNEL_ALGORITHM_VERSION "CHANNEL_GEOMETRY_V1"
#define OPPORTUNITY_CHANNEL_FEATURE_VERSION "CHANNEL_BOUNDARY_V1"
#define OPPORTUNITY_CHANNEL_SCHEMA_VERSION "1"
#define OPPORTUNITY_CHANNEL_PRICE_DIGITS 16
#define OPPORTUNITY_STRUCTURE_LINE_WIDTH 2
#define OPPORTUNITY_DETAILS_PAGE_COUNT 4
#define OPPORTUNITY_DETAILS_LINE_HEIGHT_PX 17

struct OpportunityStructureState
  {
   string role;
   datetime centerTime;
   double centerPrice;
   int centerBarShift;
   int radiusBars;
   datetime rangeStartTime;
   datetime rangeEndTime;
   double circleLow;
   double circleHigh;
   double zoneLow;
   double zoneHigh;
   datetime representativeTime;
   double representativePrice;
   string representativeType;
   int representativeBarShift;
   int actionSequence;
  };

struct OpportunityAnchorState
  {
   string role;
   datetime barTime;
   double price;
   string snapType;
   int barShift;
   int actionSequence;
   bool active;
  };

struct OpportunityKeyBarState
  {
   string role;
   datetime barTime;
   datetime confirmTime;
   datetime highlightStartTime;
   datetime highlightEndTime;
   double openPrice;
   double highPrice;
   double lowPrice;
   double closePrice;
   int barShift;
   string direction;
   int actionSequence;
   bool active;
  };

struct OpportunityDrawingState
  {
   string drawingId;
   string sourceName;
   ENUM_OBJECT objectType;
   int subwindow;
   int anchorCount;
   datetime time1;
   double price1;
   datetime time2;
   double price2;
   datetime time3;
   double price3;
   string price1ArchiveText;
   string price2ArchiveText;
   string price3ArchiveText;
   color objectColor;
   ENUM_LINE_STYLE lineStyle;
   int lineWidth;
   bool drawInBackground;
   bool fill;
   bool rayLeft;
   bool rayRight;
   double angle;
   double scale;
   double deviation;
   long timeframes;
   long zorder;
   string text;
   int arrowCode;
   ENUM_ANCHOR_POINT anchor;
   string semanticRole;
   string pathId;
   int segmentOrder;
   string anchor1Role;
   string anchor2Role;
   string semanticSource;
   bool semanticConfirmed;
  };

struct OpportunityRegionState
  {
   string regionId;
   string role;
   string displayName;
   string startDrawingId;
   string endDrawingId;
   datetime startTime;
   datetime endTime;
  };

struct OpportunityGeometryAdvice
  {
   string suggestedRole;
   double confidence;
   double r1Overlap;
   double r2Overlap;
   int effectiveH1Bars;
   double referenceAtr;
   double displacementAtr;
   double slopeAtrPerBar;
   double pathEfficiency;
   string firstStructureRole;
   bool firstStructureConnected;
   double endpointTimeDistanceBars;
   double endpointPriceDistanceAtr;
   bool channelExcluded;
   string evidence;
  };

struct OpportunityDrawingSemanticState
  {
   string drawingId;
   string symbol;
   string timeframe;
   ENUM_OBJECT objectType;
   datetime time1;
   double price1;
   datetime time2;
   double price2;
   string price1ArchiveText;
   string price2ArchiveText;
   string drawingFingerprint;
   string inputFingerprint;
   string semanticRole;
   string pathId;
   int segmentOrder;
   string anchor1Role;
   string anchor2Role;
   string semanticSource;
   string algorithmVersion;
   string featureVersion;
   string schemaVersion;
   string decisionStatus;
   double score;
   string evidence;
   double r1Overlap;
   double r2Overlap;
   int effectiveH1Bars;
   double referenceAtr;
   double displacementAtr;
   double slopeAtrPerBar;
   double pathEfficiency;
   string firstStructureRole;
   bool firstStructureConnected;
   string connectedEndpoint;
   double endpointTimeDistanceBars;
   double endpointPriceDistanceAtr;
   bool channelExcluded;
   datetime derivedAt;
   string archiveComparableLine;
  };

struct OpportunityChannelBoundaryState
  {
   string channelId;
   string sourceDrawingId;
   string componentId;
   int nativeLineIndex;
   string componentRole;
   string boundaryRole;
   string channelDirection;
   string symbol;
   string timeframe;
   datetime time1;
   double price1;
   datetime time2;
   double price2;
   double slopePricePerH1Bar;
   double referenceAtr;
   double channelWidthPrice;
   double channelWidthAtr;
   double parallelErrorPrice;
   double parallelErrorRatio;
   bool parallelOK;
   int touchCount;
   string touchAnchorRoles;
   string touchDistancePrices;
   string sourceAnchorRefs;
   string coordinateSource;
   string sourceDrawingFingerprint;
   string boundaryFingerprint;
   string algorithmVersion;
   string featureVersion;
   string schemaVersion;
   string decisionStatus;
   string evidence;
   datetime derivedAt;
   string archiveComparableLine;
  };

struct OpportunityCaseCatalogEntry
  {
   string caseId;
   string caseType;
   string symbol;
   string timeframe;
   string status;
   datetime formationStart;
   datetime readyTime;
   int pivotCount;
   int upperCount;
   int lowerCount;
   string timeOrderRule;
   string alternationRule;
   string progressionRule;
   string upperDirectionRule;
   string lowerDirectionRule;
   string parallelRule;
   string ruleStatus;
   string futureOutcome;
   string updatedAt;
   datetime regionStart;
   datetime regionEnd;
   datetime accumulationStart;
   datetime accumulationEnd;
   double accumulationDurationHours;
   int accumulationH1Bars;
   string opportunityLevel;
   string caseCode;
   string standardity;
   bool standardityConfirmed;
   datetime sortTime;
   int year;
   int typeSequence;
   int structureCount;
   int lineCount;
   int keyBarCount;
   int drawingCount;
   int regionCount;
   bool annotationComplete;
  };

OpportunityStructureState opportunityStructures[];
OpportunityAnchorState opportunityLineAnchors[OPPORTUNITY_LINE_ANCHOR_COUNT];
OpportunityKeyBarState opportunityKeyBar;
OpportunityDrawingState opportunityDrawings[];
OpportunityRegionState opportunityRegions[];
OpportunityDrawingSemanticState opportunityDrawingSemantics[];
OpportunityChannelBoundaryState opportunityChannelBoundaries[];
OpportunityCaseCatalogEntry opportunityCaseCatalog[];
string opportunityActiveCaseId = "";
string opportunityActiveCaseType = "";
string opportunityArchivedCaseType = "";
bool opportunityCaseTypeDirty = false;
bool opportunityCaseTypeCommitInProgress = false;
string opportunityActiveStandardity = "UNREVIEWED";
string opportunityArchivedStandardity = "UNREVIEWED";
bool opportunityStandardityDirty = false;
bool opportunityStandardityCommitInProgress = false;
bool opportunityTypeMenuOpen = false;
uint opportunityTypeMenuOpenedTick = 0;
uint opportunityTypeMenuLastActionTick = 0;
bool opportunityCaseCatalogReady = false;
bool fullWorkYearMenuOpen = false;
uint fullWorkYearMenuOpenedTick = 0;
bool opportunityCaseMenuOpen = false;
uint opportunityCaseMenuOpenedTick = 0;
int opportunityCaseMenuLevel = 0;
int opportunityCaseMenuYear = 0;
string opportunityCaseMenuType = "";
int opportunityCaseMenuYears[];
string opportunityCaseMenuTypes[];
int opportunityCaseMenuCaseIndexes[];
int opportunityCaseSearchYear = 0;
string opportunityCaseSearchCaseId = "";
string opportunityCaseFeedbackStatus = "";
uint opportunityCaseFeedbackStartedTick = 0;
uint opportunityCaseFeedbackDurationMs = 0;
bool opportunityExplicitNoSelection = false;
bool fullControlPanelLayerCaptured = false;
bool fullControlPanelOriginalForeground = false;
bool fullControlPanelOriginalCreateEvents = false;
bool fullControlPanelRaisePending = false;
bool fullControlPanelRaiseInProgress = false;
bool opportunityDetailsVisible = false;
int opportunityDetailsPage = 0;
string opportunityAnnotationMode = "";
string opportunityFutureOutcome = "";
int opportunityStructureRadiusBars = 2;
bool opportunityAnnotationReadOnly = false;
string opportunityAnnotationNativeSymbol = "";
string opportunityAnnotationNativeTimeframe = "";
int opportunityNextActionSequence = 1;
bool opportunityChartViewVisible = true;
uint opportunityModeSelectedTick = 0;
uint opportunityLastButtonTick = 0;
string opportunityLastButtonName = "";
int opportunityEditStructureIndex = -1;
uint opportunityLastStructureLabelClickTick = 0;
string opportunityLastStructureLabelClickName = "";
uint opportunityEditStateTick = 0;
string opportunitySaveFeedbackState = "";
string opportunitySaveFeedbackStatus = "";
uint opportunitySaveFeedbackStartedTick = 0;
uint opportunitySaveFeedbackDurationMs = 0;
bool opportunitySessionStateRestored = false;
int opportunitySessionWorkYear = 0;

string pureReleaseLastSignature = "";
string pureReleaseLastCaseId = "";
string pureReleaseLastType = "";
int pureReleaseDraftRevision = 0;
int pureReleaseAnalysisRuns = 0;
bool pureReleaseShadowRunning = false;
bool pureReleaseLastValid = false;
bool pureReleaseLastAnalysisCompleted = false;
string pureReleaseLastStatus = PR_STATUS_CAPTURE_FAILED;
string pureReleaseLastReason = PR_REASON_CAPTURE_FAILED;
string pureReleaseLastMarketDirection = PR_DIRECTION_UNKNOWN;
string pureReleaseLastDirectionAgreement = PR_AGREEMENT_NOT_EVALUATED;
string pureReleaseLastQualityStatus = PR_QUALITY_NOT_EVALUATED;
string pureReleaseLastDataGapStatus = PR_SESSION_GAP_STATUS_NOT_EVALUATED;
string pureReleaseLastDataGapReason = PR_SESSION_GAP_REASON_NONE;
string pureReleaseLastSessionPolicy = PR_SESSION_POLICY_VERSION;
int pureReleaseLastCalendarSpanHours = 0;
int pureReleaseLastCalendarExpectedBars = 0;
int pureReleaseLastActualBars = 0;
int pureReleaseLastExpectedClosureGaps = 0;
int pureReleaseLastExpectedClosureHours = 0;
int pureReleaseLastUnexpectedGaps = 0;
datetime pureReleaseLastFirstGapPrevious = 0;
datetime pureReleaseLastFirstGapNext = 0;
int pureReleaseLastFirstGapHours = 0;


// --- Forward Declarations ---
void CreateCustomSymbol();
bool EnsureCustomSymbol(string symbol);
bool EnsureFullSymbol();
string FullSymbolName();
int ExtractFullSymbolYear(string symbol);
string BuildFullSymbolForYear(int year);
bool IsManagedFullSymbol(string symbol);
void ConfigureFullRuntime(int year);
int ResolvePersistedFullWorkYear(int chartYear);
bool EnsureFullYearHistory(int year);
bool SwitchFullWorkYear(long chartID, int targetYear, string reason, string targetCaseId);
int CloseAllChartsExcept(long keepChartID);
string ExtractFileName(string path);
string ExtractDirectoryName(string path);
string BuildYearCsvPath(string samplePath, int year);
int OpenFullCsvFile(string path, string &openedName);
bool ParseCsvRateLine(string line, MqlRates &rate);
bool FlushFullHistoryRates(MqlRates &rates[], int count, int &chunkCount, int total);
bool LoadFullHistoryCsvFile(string csvPath, MqlRates &rates[], int &idx, int &total, int &chunkCount);
bool LoadFullHistory();
void ShowFullModeLabel(long chartID);
void UpdateFullModeLabel(long chartID, string text);
bool AutoAttachEAOnFullChart(long chartID);
void CreateFullControlPanel();
void DestroyFullControlPanel();
void CreateOpportunityDetailsButton();
bool HandleOpportunityDetailsClick(long chartID, string objectName);
void ShowOpportunityDetailsPanel(long chartID);
void HideOpportunityDetailsPanel(long chartID);
void RenderOpportunityDetailsPanel(long chartID);
void DeleteOpportunityDetailsPanelObjects(long chartID);
bool IsOpportunityDetailsObject(string objectName);
bool EnsureFullControlPanelChartLayer(long chartID);
void RestoreFullControlPanelChartLayer(long chartID);
bool IsFullControlPanelObject(string objectName);
void RaiseFullControlPanelToFront(long chartID);
void UpdateFullWorkYearButton();
void OpenFullWorkYearMenu(long chartID);
void CloseFullWorkYearMenu(long chartID);
bool HandleFullWorkYearSelectorClick(long chartID, string objectName);
void GoFullChartToStart(long chartID);
bool LoadAccumulationZones(long chartID);
void ClearAccumulationZones(long chartID);
bool ExportManualRectangles(long chartID);
string InferManualLabel(string objName, color objColor);
string TimeframeName(ENUM_TIMEFRAMES tf);
string FullViewportStateKey(long chartID, string field);
void ClearFullViewportState(long chartID);
bool CaptureFullChartViewport(long chartID);
bool RestoreFullChartViewport(long chartID);
void CreateManualBoxAtViewport(long chartID);
int FillManualRectangles(long chartID);
bool ResolveZonePriceRange(string symbol, ENUM_TIMEFRAMES tf, datetime startTime, datetime endTime, double &zoneLow, double &zoneHigh);
void InitializeOpportunityAnnotation(long chartID);
bool LoadOpportunityCaseCatalog(long chartID);
string OpportunityCaseId();
string OpportunityCaseType();
int FindOpportunityCaseCatalogIndex(string caseId);
bool HandleOpportunityCaseSelectorClick(long chartID, string objectName);
bool HandleOpportunityCaseDirectSearch(long chartID, string objectName);
void UpdateOpportunityCaseSearchButtons();
void CloseOpportunityCaseMenu(long chartID);
void OpenOpportunityCaseYearMenu(long chartID);
void OpenOpportunityCaseTypeMenu(long chartID, int year);
void OpenOpportunityCaseItemMenu(long chartID, int year);
bool SwitchOpportunityCase(long chartID, int targetIndex);
bool LoadOpportunityCaseArchivesReadOnly(long chartID,
                                         OpportunityCaseCatalogEntry &entry,
                                         string &failureReason);
bool FocusOpportunityCaseOnChart(long chartID, OpportunityCaseCatalogEntry &entry);
bool RedrawOpportunityCase(long chartID,
                           OpportunityCaseCatalogEntry &entry,
                           int &drawingsDrawn,
                           int &regionLabelsDrawn);
void SetOpportunityCaseFeedback(string statusText, uint durationMs);
void RefreshOpportunityCaseFeedback();
string OpportunityTypeId(int index);
bool IsOpportunityTypeSupported(string caseType);
bool IsOpportunityStandarditySupported(string standardity);
string OpportunityStandardityDisplayName(string standardity);
string OpportunityAnnotationWriteStandardity();
bool SaveOpportunitySessionState(long chartID, string reason);
bool RestoreOpportunitySessionState(long chartID);
int CountOpportunitySessionMarkers(long chartID);
bool PersistOpportunityExplicitNoSelection(long chartID);
void RefreshOpportunityAnnotationReadOnly(long chartID);
void UpdateOpportunityCaseSelectorButton();
void UpdateOpportunityTypeSelectorButton();
void OpenOpportunityTypeMenu(long chartID);
void CloseOpportunityTypeMenu(long chartID);
bool HandleOpportunityTypeSelectorClick(long chartID, string objectName);
bool ValidateOpportunityCaseTypeArchives(string expectedType,
                                         int expectedCases,
                                         int expectedAnchors,
                                         int expectedKeyBars,
                                         int expectedDrawings,
                                         int expectedRegions);
bool ValidateOpportunityCaseStandardityArchive(string expectedStandardity);
void ResetOpportunityAnnotationState();
void ResetOpportunityKeyBar();
bool HandleOpportunityAnnotationButton(string objectName);
bool HandleOpportunityChartClick(long chartID, int mouseX, int mouseY);
bool HandleOpportunityStructureLabelClick(long chartID, string objectName);
bool HandleOpportunityStructureLabelDrag(long chartID, string objectName);
void SetOpportunityStructureEdit(long chartID, int structureIndex, string reason);
void SetOpportunityAnnotationMode(string mode);
void UpdateOpportunityAnnotationPanel();
void SetOpportunityStructureSaveFeedback(string state, string statusText, uint durationMs);
void RefreshOpportunityStructureSaveFeedback();
void DrawOpportunityAnnotations(long chartID);
void DrawOpportunityKeyBar(long chartID);
void RefreshOpportunityStructureMarkers(long chartID);
bool ResolveOpportunityKeyBarMarkerGeometry(long chartID,
                                            int &markerLeft,
                                            int &markerTop,
                                            int &markerWidth,
                                            int &markerHeight);
void RefreshOpportunityKeyBarMarker(long chartID);
void DeleteOpportunityAnnotationObjects(long chartID);
bool DeleteAllOpportunityDisplayObjects(long chartID, string reason);
bool SaveOpportunityStructureDrawings(long chartID, string &resultText);
bool LoadOpportunityDrawings(long chartID);
bool LoadOpportunityDrawingSemantics(long chartID, bool allowLegacyReadOnlyRecompute);
bool LoadOpportunityChannelBoundaries(long chartID);
int DrawOpportunityDrawings(long chartID);
void DeleteOpportunityDrawingObjects(long chartID);
int DrawOpportunityGeometryPreview(long chartID);
void DeleteOpportunityGeometryPreviewObjects(long chartID);
bool BuildOpportunityRegionsFromDrawings(long chartID,
                                         OpportunityDrawingState &drawings[],
                                         OpportunityRegionState &regions[]);
bool SaveOpportunityRegionSnapshot(long chartID, OpportunityRegionState &regions[]);
bool LoadOpportunityRegions(long chartID);
int DrawOpportunityRegionLabels(long chartID);
void RefreshOpportunityRegionLabels(long chartID);
void DeleteOpportunityRegionObjects(long chartID);
bool CreateOpportunityCaseChartLabel(long chartID);
bool SaveOpportunityCaseSnapshot(long chartID);
bool SaveOpportunityAnnotation(long chartID);
bool SaveOpportunityKeyBar(long chartID);
bool LoadOpportunityAnnotation(long chartID);
bool LoadOpportunityKeyBar(long chartID, int &maxSequence);
bool UndoOpportunityAnnotation(long chartID);
void RestoreOpportunityChartView(long chartID, string reason);
bool ClearOpportunityChartView(long chartID);
int OpportunityCaseIdYear(string caseId);
string BuildNextOpportunityCaseId(long chartID, int year,
                                  ENUM_TIMEFRAMES timeframe);
bool PrepareOpportunitySessionForYear(long chartID, int year, string targetCaseId,
                                      string reason);
bool StartNewOpportunityCase(long chartID);
bool IsPureReleaseShadowDraft();
void BuildPureReleaseReservedPrefixes(string &reservedPrefixes[]);
bool RunPureReleaseShadowPreflight(long chartID, string trigger);
void ResetPureReleaseShadowState(string reason);

void CreateControlPanel();
void DestroyControlPanel();
void UpdateUIState();
void UpdateSpeedLabel(double speed);
void UpdateBatchLabel();
void ClickFlash(string name);
void CreateButton(string name, int x, int y, int w, int h, string text, color bg);
void CreateEdit(string name, int x, int y, int w, int h, string text);
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, int border);
void CreateLabel(string name, int x, int y, string text, color col, int size);
void ShiftControlPanel(int dx, int dy);
void ShiftObj(string name, int dx, int dy);

#include "Compatibility\LegacyMainEA\CaseManagement\Deletion\CM_DeleteModule.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   int chartFullYear = ExtractFullSymbolYear(_Symbol);
   if(chartFullYear <= 0) chartFullYear = ExtractFullSymbolYear(InpFullSymbolName);
   if(chartFullYear <= 0) chartFullYear = InpFullStartYear;
   ConfigureFullRuntime(chartFullYear);




   Print("EA INIT | ver=", EA_VERSION_STR, " | program=", MQLInfoString(MQL_PROGRAM_PATH), " | data=", TerminalInfoString(TERMINAL_DATA_PATH));





   Print("Initializing Python Bridge EA (Remote Control - Empty Mode)...");
   ApplyColorTheme(ChartID());
   if(GV_DEBUG_FULL) Print("FULL-DBG | OnInit | Symbol=", _Symbol,
                           " | FullSymbol=", FullSymbolName(),
                           " | work_year=", fullWorkYear);


   // Identify if this EA instance is running on the FULL chart
   isFullChartInstance = IsManagedFullSymbol(_Symbol);
     if(isFullChartInstance)
       {
        HideOpportunityDetailsPanel(ChartID());
       DeleteAllOpportunityDisplayObjects(ChartID(), "full_init_preload");
       opportunityActiveCaseId = InpOpenDefaultCaseOnStartup ?
                                 OpportunityCsvSafe(InpAnnotationCaseId) : "";
       opportunityActiveCaseType = InpOpenDefaultCaseOnStartup ?
                                   OpportunityCsvSafe(InpAnnotationCaseType) :
                                   "UNSELECTED";
       opportunityArchivedCaseType = InpOpenDefaultCaseOnStartup ?
                                     opportunityActiveCaseType : "";
       opportunityCaseTypeDirty = false;
       opportunityActiveStandardity = "UNREVIEWED";
       opportunityArchivedStandardity = "UNREVIEWED";
       opportunityStandardityDirty = false;
       opportunityAnnotationNativeSymbol = "";
        opportunityAnnotationNativeTimeframe = "";
       opportunitySessionStateRestored = false;
       opportunitySessionWorkYear = 0;
       opportunityExplicitNoSelection = false;
       RestoreOpportunitySessionState(ChartID());
       Print("Running in FULL chart mode. Skipping pipe/UI.");
      ShowFullModeLabel(ChartID());

      if(!InpFullOnlyMode)
        {
         // Legacy dual-chart mode: keep a replay chart available alongside FULL.
         if(InpCreateCustomSymbol) EnsureCustomSymbol(InpSymbolName);
         long replayChartHint = GetReplayChartID();
         if(replayChartHint == 0)
           {
            replayChartHint = ChartOpen(InpSymbolName, InpReplayTimeframe);
            if(GV_DEBUG_FULL) Print("FULL-DBG | FULL instance opened replay chart (no EA attached) | id=", replayChartHint, " symbol=", InpSymbolName);
           }
        }
      else
        {
         Print("[EA|FULL|ONLY] INFO replay and pipe functions disabled | chart=", ChartID(), " symbol=", _Symbol);
        }
      // Enable chart events on FULL chart too (some terminals require this for UI interaction)
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
       EventSetMillisecondTimer(100);

       bool deleteRecoveryPendingAtStartup =
          CM_DeleteModulePrepareStartup(ChartID());
       if(!deleteRecoveryPendingAtStartup)
         {
          LoadOpportunityCaseCatalog(ChartID());
          int persistedWorkYear = ResolvePersistedFullWorkYear(fullWorkYear);
          if(persistedWorkYear != fullWorkYear)
            {
             Print("[EA|FULL|YEAR] INFO persisted year restore requested | chart_year=",
                   fullWorkYear, " | target_year=", persistedWorkYear,
                   " | session_case=", OpportunityCaseId(),
                   " | archive_touched=0");
             if(SwitchFullWorkYear(ChartID(), persistedWorkYear,
                                   "startup_restore", ""))
                return(INIT_SUCCEEDED);
             GlobalVariableSet(GV_FULL_WORK_YEAR, fullWorkYear);
             GlobalVariablesFlush();
            }
          if(!opportunitySessionStateRestored && !InpOpenDefaultCaseOnStartup)
            {
             if(!PrepareOpportunitySessionForYear(ChartID(), fullWorkYear, "",
                                                   "startup_no_selection"))
               {
                Print("[EA|FULL|CASE] ERROR blank startup session unavailable | year=",
                      fullWorkYear, " | err=", GetLastError(),
                      " | archive_touched=0");
                return(INIT_FAILED);
               }
            }
          else if(!opportunityExplicitNoSelection &&
                  OpportunityCaseIdYear(OpportunityCaseId()) != fullWorkYear)
            {
             PrepareOpportunitySessionForYear(ChartID(), fullWorkYear, "",
                                               "session_year_repair");
            }
         }
       GlobalVariableSet(GV_FULL_WORK_YEAR, fullWorkYear);
       GlobalVariablesFlush();
       CreateFullControlPanel();
       if(!deleteRecoveryPendingAtStartup)
          InitializeOpportunityAnnotation(ChartID());
       else
          UpdateOpportunityAnnotationPanel();
      if(GV_DEBUG_FULL) Print("FULL-DBG | FULL mode branch | AutoLoad=", (int)InpFullAutoLoad, " ForceReload=", (int)InpFullForceReload);

      if(InpCreateCustomSymbol)
        {
         EnsureFullSymbol();
        }
      if(InpFullAutoLoad && (InpFullForceReload || !GlobalVariableCheck(GV_FULL_LOADED)))
        {
         LoadFullHistory();
        }

      if(InpFullAutoLoadAccumulation)
        {
         LoadAccumulationZones(ChartID());
        }

      bool periodViewportRestored = RestoreFullChartViewport(ChartID());
      if(periodViewportRestored)
        {
         Print("[EA|FULL|VIEW] INFO initialization navigation preserved | case=",
               OpportunityCaseId(),
               " | navigation=period_viewport | archive_touched=0");
        }
      else if(opportunitySessionStateRestored)
        {
         int activeCaseIndex = FindOpportunityCaseCatalogIndex(OpportunityCaseId());
         if(activeCaseIndex >= 0)
           {
            OpportunityCaseCatalogEntry activeEntry = opportunityCaseCatalog[activeCaseIndex];
            bool focused = FocusOpportunityCaseOnChart(ChartID(), activeEntry);
            Print("[EA|FULL|CASE] INFO restored session view initialized | case=", OpportunityCaseId(),
                  " | catalog_index=", activeCaseIndex,
                  " | focused=", (int)focused,
                  " | navigation=case_range | archive_touched=0");
           }
         else
           {
            Print("[EA|FULL|CASE] INFO restored draft view preserved | case=", OpportunityCaseId(),
                  " | catalog_ready=", (int)opportunityCaseCatalogReady,
                  " | catalog_index=-1 | navigation=unchanged | archive_touched=0");
           }
        }
      else
        {
         GoFullChartToStart(ChartID());
         Print("[EA|FULL|CASE] INFO initial chart view initialized | session_restored=0",
               " | navigation=history_start | archive_touched=0");
        }
      if(InpFullOnlyMode)
        {
         CloseAllChartsExcept(ChartID());
         ChartSetInteger(ChartID(), CHART_BRING_TO_TOP, true);
        }
      RaiseFullControlPanelToFront(ChartID());
      return(INIT_SUCCEEDED);
     }

// --- 1. Custom Symbol Creation Logic ---
   if(InpCreateCustomSymbol)
     {
      // Ensure replay symbol exists
      EnsureCustomSymbol(InpSymbolName);

      // Switch current chart to replay symbol (keep EA on this chart)
      if(_Symbol != InpSymbolName)
        {
         Print("Switching chart to replay symbol: ", InpSymbolName);
         ChartSetSymbolPeriod(ChartID(), InpSymbolName, InpReplayTimeframe);
         ChartRedraw(0);
        }

      if(InpReplayUseTemplateColors)
        {
         ApplyTemplateColorsToChart(ChartID());
        }

      // Ensure full-history chart exists and is opened
      if(GV_DEBUG_FULL) Print("FULL-DBG | Ensure full chart | InpEnableFullChart=", (int)InpEnableFullChart);
      if(InpEnableFullChart)
        {
         if(EnsureFullSymbol())
           {
            long fullChart = GetFullChartID();
            if(GV_DEBUG_FULL) Print("FULL-DBG | FullChartID=", fullChart);

            if(fullChart == 0)
              {
               fullChart = ChartOpen(FullSymbolName(), InpFullTimeframe);
               if(fullChart != 0 && InpBringFullChartToTop) ChartSetInteger(fullChart, CHART_BRING_TO_TOP, true);
               if(GV_DEBUG_FULL) Print("FULL-DBG | ChartOpen full returned id=", fullChart);
               if(fullChart != 0 && InpFullApplyTemplate) ApplyTemplateOnce(fullChart);
              }
            else
              {
               bool cps = ChartSetSymbolPeriod(fullChart, FullSymbolName(), InpFullTimeframe);
               if(InpBringFullChartToTop) ChartSetInteger(fullChart, CHART_BRING_TO_TOP, true);
               if(GV_DEBUG_FULL) Print("FULL-DBG | ChartSetSymbolPeriod full=", (int)cps);
               if(fullChart != 0 && InpFullApplyTemplate) ApplyTemplateOnce(fullChart);
              }

            if(fullChart != 0)
              {
               ApplyColorTheme(fullChart);
               ShowFullModeLabel(fullChart);
               AutoAttachEAOnFullChart(fullChart);
              }

            if(InpFullAutoLoad && (InpFullForceReload || !GlobalVariableCheck(GV_FULL_LOADED)))
              {
               LoadFullHistory();
              }
           }
        }
     }


   // --- 2. Pipe Connection & Auto-Launch ---
   EventSetMillisecondTimer(50); // Faster polling to prevent pipe blocking
   ConnectPipe();

   // Auto-Launch if not connected
   if(hPipe == INVALID_HANDLE_VALUE)
   {
      Print("馃殌 Auto-Launching Python Server on Startup...");
      ShellExecuteW(0, "open", InpPythonPath, InpScriptPath, "", 1);
   }

   // --- 3. UI Initialization ---
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // Enable mouse move events for slider

   // Cleanup any leftover legacy labels from previous runs
   ObjectDelete(0, "PythonMsg");

   CreateControlPanel();

   // --- Restore Play/Pause State ---
   if(GlobalVariableCheck("Energy_IsPaused"))
     {
      isPaused = (bool)GlobalVariableGet("Energy_IsPaused");
     }
   else
     {
      isPaused = true; // Default if no history
     }

   // Sync UI and Python with restored state
   if(!isPaused)
     {
      // If we were playing, update button to PAUSE style and send RESUME
      ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "PAUSE");
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed);

      // We need to send RESUME, but pipe might not be ready yet.
      // ConnectPipe() is called in OnTimer.
      // So we'll set a flag or handle it in OnTimer?
      // Actually, ConnectPipe is called immediately in OnInit via OnTimer? No.
      // Let's just set the state. When pipe connects, Python is waiting.
      // Python defaults to PAUSED. So we MUST send RESUME once connected.
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(isFullChartInstance && reason == REASON_CHARTCHANGE)
      CaptureFullChartViewport(ChartID());
   if(isFullChartInstance)
  {
   GlobalVariableSet(GV_FULL_WORK_YEAR, fullWorkYear);
   GlobalVariablesFlush();
   SaveOpportunitySessionState(ChartID(), "deinit_" + IntegerToString(reason));
   HideOpportunityDetailsPanel(ChartID());
   DeleteAllOpportunityDisplayObjects(ChartID(), "full_deinit_" + IntegerToString(reason));
   DestroyFullControlPanel();
   RestoreFullControlPanelChartLayer(ChartID());
   ObjectDelete(0, "FullModeMsg");
   return;
  }

   // Save UI Position (Always save position)
   GlobalVariableSet("EnergyUI_X", ui_base_x);
   GlobalVariableSet("EnergyUI_Y", ui_base_y);

   // Save Play/Pause State ONLY if switching timeframes or parameters
   // If removing EA or closing terminal, we want a fresh start next time.
   // BUT, speed preference is usually persistent across sessions (User Preference).
   // So we save speed regardless of reason.
   GlobalVariableSet("Energy_Speed", currentSpeed);
   GlobalVariablesFlush(); // Ensure persistence on shutdown

   if(reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS)
     {
      // FIX: Only save state if pipe is connected.
      // Prevents UI from getting stuck in "Resume" mode if timeframe changes before connection.
      if(hPipe != INVALID_HANDLE_VALUE)
        {
         GlobalVariableSet("Energy_IsPaused", isPaused);
        }
      else
        {
         // If not connected, clear any state so we reset to Launch screen
         GlobalVariableDel("Energy_IsPaused");
        }
     }
   else
     {
      // Clean up state so next run shows Launch button
      GlobalVariableDel("Energy_IsPaused");
     }

   DestroyControlPanel(); // Cleanup UI
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      CloseHandle(hPipe);
      Print("Pipe handle closed.");
     }
  }

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(isFullChartInstance &&
      CM_DeleteModuleHandleRecoveryGate(ChartID(), id, sparam))
      return;

   if(isFullChartInstance &&
      (id == CHARTEVENT_OBJECT_CREATE ||
       id == CHARTEVENT_OBJECT_DELETE ||
       id == CHARTEVENT_OBJECT_CHANGE ||
       id == CHARTEVENT_OBJECT_DRAG))
     {
      RunPureReleaseShadowPreflight(ChartID(), "object_event");
     }

   if(id == CHARTEVENT_OBJECT_CREATE && isFullChartInstance)
     {
      if(!fullControlPanelRaiseInProgress && !IsFullControlPanelObject(sparam))
         fullControlPanelRaisePending = true;
     }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && isFullChartInstance)
     {
      if(HandleOpportunityCaseDirectSearch(ChartID(), sparam))
        {
         ChartRedraw(0);
         return;
        }
     }

   // Handle Button Click (Play/Pause/Reconnect)
    if(id == CHARTEVENT_OBJECT_CLICK)
      {
      if(sparam == OBJ_BTN_FULL_LOAD_MAIN)
        {
         if(GV_DEBUG_FULL) Print("FULL-DBG | Manual FULL LOAD clicked (replay chart)");
         ClickFlash(sparam);
         LoadFullHistory();
         ChartRedraw(0);
         return;
        }

       if(isFullChartInstance && GV_DEBUG_FULL) Print("FULL-DBG | OBJECT_CLICK | obj=", sparam);

       if(isFullChartInstance &&
          CM_DeleteModuleTryHandleAction(ChartID(), sparam))
         {
          ChartRedraw(0);
          return;
         }

       if(isFullChartInstance && HandleFullWorkYearSelectorClick(ChartID(), sparam))
         {
          ChartRedraw(0);
          return;
         }

       if(isFullChartInstance && HandleOpportunityCaseSelectorClick(ChartID(), sparam))
         {
          ChartRedraw(0);
          return;
         }

       if(isFullChartInstance && HandleOpportunityDetailsClick(ChartID(), sparam))
         {
          ChartRedraw(0);
          return;
         }

       if(isFullChartInstance && HandleOpportunityTypeSelectorClick(ChartID(), sparam))
         {
          ChartRedraw(0);
          return;
         }

      if(isFullChartInstance && HandleOpportunityStructureLabelClick(ChartID(), sparam))
        {
         ChartRedraw(0);
         return;
        }

      if(sparam == OBJ_FULL_BTN_LOAD)
        {
         if(!isFullChartInstance) return;
         if(GV_DEBUG_FULL) Print("FULL-DBG | Manual LOAD clicked");
         ClickFlash(sparam);
         LoadFullHistory();
         ChartRedraw(0);
         return;
        }

      if(sparam == OBJ_FULL_BTN_HOME)
        {
         if(!isFullChartInstance) return;
         ClickFlash(sparam);
         GoFullChartToStart(ChartID());
         ChartRedraw(0);
         return;
        }

      if(isFullChartInstance && HandleOpportunityAnnotationButton(sparam))
        {
         ChartRedraw(0);
         return;
        }

      // FULL-chart instance is passive: it only handles FULL control buttons.
      if(isFullChartInstance) return;

      if(sparam == "btn_play_pause")
        {
         ClickFlash("btn_play_pause");

         // 1. Check if Offline -> Try to Connect/Launch
         if(hPipe == INVALID_HANDLE_VALUE)
         {
            Print("Start clicked (Offline). Launching Python...");
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "WAIT");
            ChartRedraw(0);

            // Try Launch
            ShellExecuteW(0, "open", InpPythonPath, InpScriptPath, "", 1);

            // Note: We don't change state here immediately.
            // The OnTimer will detect the connection and UpdateUIState will switch it to RESUME/PAUSE.
            return;
         }

         // 2. Normal Toggle Logic (Online)
         isPaused = !isPaused; // Toggle State

         if(isPaused)
           {
            // State is now PAUSED
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "RESUME"); // Show what will happen next
            ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGreen); // Green for "Go"
            Print("UI Event: Switched to PAUSE");
            SendCommand("PAUSE");
           }
         else
           {
            // State is now PLAYING
            ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "PAUSE"); // Show what will happen next
            ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed); // Red for "Stop"
            Print("UI Event: Switched to PLAY");
            SendCommand("RESUME");
           }
         ChartRedraw(0);
        }
      else if(sparam == "btn_batch_down" || sparam == "btn_batch_up")
        {
         int delta = (sparam == "btn_batch_up") ? 1 : -1;
         int newBatch = batchSize + delta;
         if(newBatch < 1) newBatch = 1;
         if(newBatch > 10) newBatch = 10;

         if(newBatch != batchSize)
           {
            batchSize = newBatch;
            UpdateBatchLabel();

            GlobalVariableSet("Energy_BatchSize", batchSize);
            GlobalVariablesFlush();

            if(hPipe != INVALID_HANDLE_VALUE)
              {
               SendCommand("BATCH|" + IntegerToString(batchSize));
              }
           }

         ClickFlash(sparam);
         ChartRedraw(0);
        }
      else if(sparam == "btn_launch")
        {
           // REMOVED LOGIC
        }
      }

   if(id == CHARTEVENT_OBJECT_DRAG && isFullChartInstance)
     {
      if(HandleOpportunityStructureLabelDrag(ChartID(), sparam))
        {
         ChartRedraw(0);
         return;
        }
     }

   if(id == CHARTEVENT_CHART_CHANGE && isFullChartInstance)
     {
       EnsureFullControlPanelChartLayer(ChartID());
       if(opportunityDetailsVisible) RenderOpportunityDetailsPanel(ChartID());
       if(!opportunityChartViewVisible) return;
       RefreshOpportunityStructureMarkers(ChartID());
       RefreshOpportunityKeyBarMarker(ChartID());
       RefreshOpportunityRegionLabels(ChartID());
       return;
     }

    if(id == CHARTEVENT_CLICK && isFullChartInstance)
      {
       if(opportunityDetailsVisible) return;
       if(opportunityTypeMenuLastActionTick > 0)
         {
          uint typeActionElapsed = GetTickCount() - opportunityTypeMenuLastActionTick;
          if(typeActionElapsed < OPPORTUNITY_TYPE_MENU_CLICK_GUARD_MS)
            {
             Print("[EA|FULL|TYPE] INFO menu action click bubble ignored | elapsed_ms=",
                   typeActionElapsed, " | guard_ms=", OPPORTUNITY_TYPE_MENU_CLICK_GUARD_MS);
             return;
            }
         }
       if(opportunityTypeMenuOpen)
         {
          uint typeMenuElapsed = GetTickCount() - opportunityTypeMenuOpenedTick;
          if(typeMenuElapsed < OPPORTUNITY_TYPE_MENU_CLICK_GUARD_MS)
            {
             Print("[EA|FULL|TYPE] INFO chart click bubble ignored | elapsed_ms=",
                   typeMenuElapsed, " | guard_ms=", OPPORTUNITY_TYPE_MENU_CLICK_GUARD_MS);
             return;
            }
          CloseOpportunityTypeMenu(ChartID());
          Print("[EA|FULL|TYPE] INFO menu closed | reason=chart_click");
          ChartRedraw(0);
          return;
         }
       if(fullWorkYearMenuOpen)
         {
          uint yearMenuElapsed = GetTickCount() - fullWorkYearMenuOpenedTick;
          if(yearMenuElapsed < OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS)
            {
             Print("[EA|FULL|YEAR] INFO chart click bubble ignored | elapsed_ms=",
                   yearMenuElapsed, " | guard_ms=",
                   OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS);
             return;
            }
          CloseFullWorkYearMenu(ChartID());
          Print("[EA|FULL|YEAR] INFO menu closed | reason=chart_click");
          ChartRedraw(0);
          return;
         }
       if(opportunityCaseMenuOpen)
         {
          uint menuOpenElapsed = GetTickCount() - opportunityCaseMenuOpenedTick;
          if(menuOpenElapsed < OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS)
            {
             Print("[EA|FULL|CASE] INFO chart click bubble ignored | elapsed_ms=",
                   menuOpenElapsed, " | guard_ms=", OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS);
             return;
            }
          CloseOpportunityCaseMenu(ChartID());
          Print("[EA|FULL|CASE] INFO menu closed | reason=chart_click");
          ChartRedraw(0);
          return;
         }
       if(opportunityEditStructureIndex >= 0 &&
         (GetTickCount() - opportunityEditStateTick) >= 250)
        {
         SetOpportunityStructureEdit(ChartID(), -1, "chart_click");
         ChartRedraw(0);
         return;
        }
      if(HandleOpportunityChartClick(ChartID(), (int)lparam, (int)dparam))
        {
         ChartRedraw(0);
         return;
        }
     }

   // Handle Mouse Move (Slider Drag ONLY - Panel is now fixed)
   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      if(isFullChartInstance) return;

      int x = (int)lparam;
      int y = (int)dparam;
      uint mouseState = (uint)sparam;

      // --- Prevent Chart Scrolling when interacting with UI ---
      // Check if mouse is inside the Main Panel area
      // Panel: x=ui_base_x, y=ui_base_y, w=260, h=90
      bool isInsidePanel = (x >= ui_base_x && x <= ui_base_x + 260 && y >= ui_base_y && y <= ui_base_y + 90);

      // If we are dragging the knob OR inside the panel, disable chart scroll
      if(isDraggingKnob || isInsidePanel)
      {
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
      }
      else
      {
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      }

      // Check Mouse Left Button Down
      if((mouseState & 1) == 1)
        {
         // Check Slider Area (Relative: 90-190, 20-50)
         // Track is at base_x + 90. Width 100.
         // Knob is roughly at y+50, size 20.
         // Tight Hitbox: 45 to 75 (30px height) to match visual knob area
         int slider_x_min = ui_base_x + 90;
         int slider_x_max = ui_base_x + 190;
         int slider_y_min = ui_base_y + 45; // Tightened Top (was 10)
         int slider_y_max = ui_base_y + 75; // Tightened Bottom (was 80)

         // Sticky Drag: If already dragging, ignore boundary check
         bool inside = (x >= slider_x_min && x <= slider_x_max && y >= slider_y_min && y <= slider_y_max);

         if(isDraggingKnob || inside)
           {
            // Start or Continue Dragging
            isDraggingKnob = true;

            // Slider Drag Logic (Track 100px, Knob 20px)
            int knob_w = 20;
            int track_w = 100;
            int knob_x = x - (knob_w / 2); // Center the 20px knob
            int knob_min = slider_x_min;
            int knob_max = slider_x_min + track_w - knob_w;
            // Clamp knob position
            if(knob_x < knob_min) knob_x = knob_min;
            if(knob_x > knob_max) knob_x = knob_max;

            ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);

            double travel = (double)(track_w - knob_w);
            double pct = (double)(knob_x - knob_min) / travel;
            if(pct < 0) pct = 0;
            if(pct > 1) pct = 1;

            double speed = 0.5 + pct * 2.5;
            currentSpeed = speed; // Update global state
            UpdateSpeedLabel(speed);
            ChartRedraw(0);
           }
        }
      else
        {
         // Mouse Up (Release)
         if(isDraggingKnob)
         {
            isDraggingKnob = false;
            // Strategy A: Send SPEED command only on release
            Print("馃柋锔?Slider Released. Sending New Speed: ", currentSpeed);
            SendCommand("SPEED|" + DoubleToString(currentSpeed, 2));

            // IMMEDIATE SAVE: Persist speed preference to disk instantly
            GlobalVariableSet("Energy_Speed", currentSpeed);
            GlobalVariablesFlush();
         }
        }
     }
  }

//+------------------------------------------------------------------+
//| UI Creation Functions                                            |
//+------------------------------------------------------------------+
bool EnsureFullControlPanelChartLayer(long chartID)
  {
   if(!fullControlPanelLayerCaptured)
     {
      long foregroundValue = 0;
      long createEventsValue = 0;
      ResetLastError();
      bool foregroundRead = ChartGetInteger(chartID, CHART_FOREGROUND, 0,
                                            foregroundValue);
      int foregroundError = GetLastError();
      ResetLastError();
      bool createEventsRead = ChartGetInteger(chartID, CHART_EVENT_OBJECT_CREATE,
                                              0, createEventsValue);
      int createEventsError = GetLastError();
      if(!foregroundRead || !createEventsRead)
        {
         Print("[EA|FULL|UI] ERROR panel layer capture failed | chart=", chartID,
               " | foreground_read=", (int)foregroundRead,
               " | foreground_err=", foregroundError,
               " | create_events_read=", (int)createEventsRead,
               " | create_events_err=", createEventsError);
         return false;
        }
      fullControlPanelOriginalForeground = (foregroundValue != 0);
      fullControlPanelOriginalCreateEvents = (createEventsValue != 0);
      fullControlPanelLayerCaptured = true;
     }

   bool configured = true;
   long foregroundValue = 0;
   ResetLastError();
   if(!ChartGetInteger(chartID, CHART_FOREGROUND, 0, foregroundValue))
     {
      Print("[EA|FULL|UI] ERROR panel foreground read failed | chart=", chartID,
            " | err=", GetLastError());
      configured = false;
     }
   else if(foregroundValue != 0)
     {
      ResetLastError();
      if(!ChartSetInteger(chartID, CHART_FOREGROUND, false))
        {
         Print("[EA|FULL|UI] ERROR panel foreground disable failed | chart=",
               chartID, " | err=", GetLastError());
         configured = false;
        }
     }

   long createEventsValue = 0;
   ResetLastError();
   if(!ChartGetInteger(chartID, CHART_EVENT_OBJECT_CREATE, 0, createEventsValue))
     {
      Print("[EA|FULL|UI] ERROR object-create event read failed | chart=", chartID,
            " | err=", GetLastError());
      configured = false;
     }
   else if(createEventsValue == 0)
     {
      ResetLastError();
      if(!ChartSetInteger(chartID, CHART_EVENT_OBJECT_CREATE, true))
        {
         Print("[EA|FULL|UI] ERROR object-create event enable failed | chart=",
               chartID, " | err=", GetLastError());
         configured = false;
        }
     }
   return configured;
  }

void RestoreFullControlPanelChartLayer(long chartID)
  {
   if(!fullControlPanelLayerCaptured) return;
   ResetLastError();
   bool foregroundRestored = ChartSetInteger(chartID, CHART_FOREGROUND,
                                             fullControlPanelOriginalForeground);
   int foregroundError = GetLastError();
   ResetLastError();
   bool createEventsRestored = ChartSetInteger(chartID, CHART_EVENT_OBJECT_CREATE,
                                               fullControlPanelOriginalCreateEvents);
   int createEventsError = GetLastError();
   if(!foregroundRestored || !createEventsRestored)
      Print("[EA|FULL|UI] WARN panel layer restore incomplete | chart=", chartID,
            " | foreground_ok=", (int)foregroundRestored,
            " | foreground_err=", foregroundError,
            " | create_events_ok=", (int)createEventsRestored,
            " | create_events_err=", createEventsError);
   fullControlPanelLayerCaptured = false;
   fullControlPanelRaisePending = false;
  }

bool IsFullControlPanelObject(string objectName)
  {
   if(objectName == OBJ_FULL_PANEL_BG) return true;
   if(StringFind(objectName, OPPORTUNITY_DETAILS_OBJECT_PREFIX) == 0) return true;
   if(StringFind(objectName, "btn_full_") == 0) return true;
   if(StringFind(objectName, "lbl_full_") == 0) return true;
   if(StringFind(objectName, "edit_full_") == 0) return true;
   return false;
  }

void RaiseFullControlPanelToFront(long chartID)
  {
   if(fullControlPanelRaiseInProgress || ObjectFind(chartID, OBJ_FULL_PANEL_BG) < 0)
      return;

   bool yearInputExists = (ObjectFind(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR) >= 0);
   bool numberInputExists = (ObjectFind(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER) >= 0);
   string yearText = yearInputExists ?
                     ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                     OBJPROP_TEXT) : "";
   string numberText = numberInputExists ?
                       ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                       OBJPROP_TEXT) : "";
   long yearBackground = yearInputExists ?
                         ObjectGetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                          OBJPROP_BGCOLOR) : clrWhite;
   long numberBackground = numberInputExists ?
                           ObjectGetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                            OBJPROP_BGCOLOR) : clrWhite;
   long yearBorder = yearInputExists ?
                     ObjectGetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                      OBJPROP_BORDER_COLOR) : clrDimGray;
   long numberBorder = numberInputExists ?
                       ObjectGetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                        OBJPROP_BORDER_COLOR) : clrDimGray;
   string yearTooltip = yearInputExists ?
                        ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                        OBJPROP_TOOLTIP) : "";
   string numberTooltip = numberInputExists ?
                          ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                          OBJPROP_TOOLTIP) : "";

   fullControlPanelRaiseInProgress = true;
   fullControlPanelRaisePending = false;
   DestroyFullControlPanel();
   CreateFullControlPanel();
   if(yearInputExists && ObjectFind(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR) >= 0)
     {
      ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR, OBJPROP_TEXT, yearText);
      ObjectSetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                       OBJPROP_BGCOLOR, yearBackground);
      ObjectSetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                       OBJPROP_BORDER_COLOR, yearBorder);
      ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                      OBJPROP_TOOLTIP, yearTooltip);
     }
   if(numberInputExists && ObjectFind(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER) >= 0)
     {
      ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER, OBJPROP_TEXT,
                      numberText);
      ObjectSetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                       OBJPROP_BGCOLOR, numberBackground);
      ObjectSetInteger(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                       OBJPROP_BORDER_COLOR, numberBorder);
      ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                      OBJPROP_TOOLTIP, numberTooltip);
     }
   fullControlPanelRaiseInProgress = false;
   ChartRedraw(chartID);
  }

void CreateFullControlPanel()
  {
   EnsureFullControlPanelChartLayer(ChartID());
   ObjectDelete(0, "btn_full_clear_case");
   ObjectDelete(0, "btn_full_extract_structure");
   ObjectDelete(0, OBJ_FULL_BTN_ACC_LOAD);
   ObjectDelete(0, OBJ_FULL_BTN_ACC_CLEAR);
   ObjectDelete(0, OBJ_FULL_BTN_EXPORT_MANUAL);
   ObjectDelete(0, OBJ_FULL_BTN_NEW_BOX);
   ObjectDelete(0, OBJ_FULL_BTN_FILL_MANUAL);

   CreateRectLabel(OBJ_FULL_PANEL_BG, 6, 20, 330, 238, C'50,50,50', BORDER_FLAT);
   ObjectSetInteger(0, OBJ_FULL_PANEL_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_FULL_PANEL_BG, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, OBJ_FULL_PANEL_BG, OBJPROP_ZORDER, 900);
   CreateButton(OBJ_FULL_BTN_WORK_YEAR, 12, 30, 128, 24, "年份 | 2002", clrDarkGreen);
   ObjectSetString(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetString(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_TOOLTIP,
                   "切换当前标注工作年份；不会改写正式案例档案");
   CreateButton(OBJ_FULL_BTN_LOAD, 144, 30, 52, 24, "LOAD", clrDarkSlateGray);
   CreateButton(OBJ_FULL_BTN_HOME, 200, 30, 126, 24, "GO START", clrDarkSlateGray);
   CreateButton(OBJ_FULL_BTN_KEY_BAR, 12, 58, 82, 24, "KEY BAR", clrDarkGoldenrod);
   CreateButton(OBJ_FULL_BTN_SAVE_STRUCTURE, 98, 58, 90, 24, "保存结构", clrDarkSlateGray);
   ObjectSetString(0, OBJ_FULL_BTN_SAVE_STRUCTURE, OBJPROP_FONT, "Microsoft YaHei");
   if(!UI_CM_CreateDeleteButton(ChartID()))
      Print("[EA|FULL|UI] ERROR delete button creation failed | err=",
            GetLastError());
   ObjectDelete(0, "btn_full_p1");
   ObjectDelete(0, "btn_full_p2");
   ObjectDelete(0, "btn_full_p3");
   ObjectDelete(0, "btn_full_p4");
   ObjectDelete(0, "btn_full_p5");
   CreateButton(OBJ_FULL_BTN_STRUCTURE, 12, 86, 92, 24, "STRUCT", clrDarkSlateGray);
   CreateButton(OBJ_FULL_BTN_SIZE_DOWN, 108, 86, 58, 24, "SIZE -", clrDarkSlateGray);
   CreateLabel(OBJ_FULL_STRUCTURE_SIZE, 174, 92, "R=2", clrWhite, 8);
   CreateButton(OBJ_FULL_BTN_SIZE_UP, 210, 86, 58, 24, "SIZE +", clrDarkSlateGray);
   ObjectDelete(0, OBJ_FULL_BTN_UPPER);
   ObjectDelete(0, OBJ_FULL_BTN_LOWER);
   CreateButton(OBJ_FULL_BTN_OPPORTUNITY_TYPE, 12, 114, 128, 24,
                 "类型 | 未选择", clrFireBrick);
   ObjectSetString(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetString(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_TOOLTIP,
                   "选择当前交易机会类型；点击保存结构后写入档案");
   CreateButton(OBJ_FULL_BTN_UNDO, 144, 114, 62, 24, "UNDO", clrDarkGoldenrod);
   CreateButton(OBJ_FULL_BTN_CLEAR_CHART, 210, 114, 116, 24, "新建案例", clrDarkSlateGray);
   ObjectSetString(0, OBJ_FULL_BTN_CLEAR_CHART, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetString(0, OBJ_FULL_BTN_CLEAR_CHART, OBJPROP_TOOLTIP,
                   "保留当前案例档案并开始一个空白新案例");
   CreateLabel(OBJ_FULL_ANNOTATION_STATUS, 12, 144, " ", clrWhite, 8);
   ObjectSetString(0, OBJ_FULL_ANNOTATION_STATUS, OBJPROP_FONT, "Microsoft YaHei");
   CreateButton(OBJ_FULL_BTN_CASE_SELECTOR, 12, 164, 314, 24, "案例 | 本年 0 | 总计 0", clrDimGray);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_TOOLTIP, "案例数量统计");
   CreateButton(OBJ_FULL_BTN_CASE_SEARCH_YEAR, 12, 192, 128, 24,
                "年份 | 请选择", clrDimGray);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_FONT, "Microsoft YaHei");
   CreateButton(OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, 144, 192, 182, 24,
                "交易机会 | 请选择", clrDimGray);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, OBJPROP_FONT,
                   "Microsoft YaHei");
   CreateLabel(OBJ_FULL_LBL_CASE_DIRECT_YEAR, 12, 226, "年份", clrWhite, 8);
   ObjectSetString(0, OBJ_FULL_LBL_CASE_DIRECT_YEAR, OBJPROP_FONT,
                   "Microsoft YaHei");
   CreateEdit(OBJ_FULL_EDIT_CASE_DIRECT_YEAR, 50, 220, 90, 24, "");
   ObjectSetString(0, OBJ_FULL_EDIT_CASE_DIRECT_YEAR, OBJPROP_TOOLTIP,
                   "输入年份，例如 2002；两项填写后按 Enter");
   CreateLabel(OBJ_FULL_LBL_CASE_DIRECT_NUMBER, 144, 226, "机会编号", clrWhite, 8);
   ObjectSetString(0, OBJ_FULL_LBL_CASE_DIRECT_NUMBER, OBJPROP_FONT,
                   "Microsoft YaHei");
   CreateEdit(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER, 206, 220, 120, 24, "");
   ObjectSetString(0, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER, OBJPROP_TOOLTIP,
                   "输入年内机会编号，例如 5 或 005；按 Enter 直接加载");
   CreateOpportunityDetailsButton();
   UpdateFullWorkYearButton();
   UpdateOpportunityCaseSelectorButton();
   UpdateOpportunityCaseSearchButtons();
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(0);
  }

void DestroyFullControlPanel()
  {
   CloseFullWorkYearMenu(0);
   CloseOpportunityCaseMenu(0);
   CloseOpportunityTypeMenu(0);
   ObjectDelete(0, OBJ_FULL_PANEL_BG);
   ObjectDelete(0, OBJ_FULL_BTN_LOAD);
   ObjectDelete(0, OBJ_FULL_BTN_HOME);
   ObjectDelete(0, OBJ_FULL_BTN_WORK_YEAR);
   ObjectDelete(0, OBJ_FULL_BTN_KEY_BAR);
   ObjectDelete(0, OBJ_FULL_BTN_SAVE_STRUCTURE);
   UI_CM_DestroyDeleteButton(ChartID());
   ObjectDelete(0, OBJ_FULL_BTN_ACC_LOAD);
   ObjectDelete(0, OBJ_FULL_BTN_ACC_CLEAR);
   ObjectDelete(0, OBJ_FULL_BTN_EXPORT_MANUAL);
   ObjectDelete(0, OBJ_FULL_BTN_NEW_BOX);
   ObjectDelete(0, OBJ_FULL_BTN_FILL_MANUAL);
   ObjectDelete(0, OBJ_FULL_BTN_STRUCTURE);
   ObjectDelete(0, OBJ_FULL_BTN_SIZE_DOWN);
   ObjectDelete(0, OBJ_FULL_STRUCTURE_SIZE);
   ObjectDelete(0, OBJ_FULL_BTN_SIZE_UP);
   ObjectDelete(0, "btn_full_p1");
   ObjectDelete(0, "btn_full_p2");
   ObjectDelete(0, "btn_full_p3");
   ObjectDelete(0, "btn_full_p4");
   ObjectDelete(0, "btn_full_p5");
   ObjectDelete(0, OBJ_FULL_BTN_UPPER);
   ObjectDelete(0, OBJ_FULL_BTN_LOWER);
   ObjectDelete(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE);
   ObjectDelete(0, OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE);
   ObjectDelete(0, OBJ_FULL_BTN_UNDO);
   ObjectDelete(0, OBJ_FULL_BTN_CLEAR_CHART);
   ObjectDelete(0, OBJ_FULL_ANNOTATION_STATUS);
   ObjectDelete(0, OBJ_FULL_BTN_CASE_SELECTOR);
   ObjectDelete(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR);
   ObjectDelete(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY);
   ObjectDelete(0, OBJ_FULL_LBL_CASE_DIRECT_YEAR);
   ObjectDelete(0, OBJ_FULL_EDIT_CASE_DIRECT_YEAR);
   ObjectDelete(0, OBJ_FULL_LBL_CASE_DIRECT_NUMBER);
   ObjectDelete(0, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER);
   ObjectDelete(0, OBJ_FULL_BTN_CASE_DETAILS);
   ChartRedraw(0);
  }

bool IsOpportunityDetailsObject(string objectName)
  {
   if(objectName == OBJ_FULL_BTN_CASE_DETAILS) return true;
   return (StringFind(objectName, OPPORTUNITY_DETAILS_OBJECT_PREFIX) == 0);
  }

void DeleteOpportunityDetailsPanelObjects(long chartID)
  {
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OPPORTUNITY_DETAILS_OBJECT_PREFIX) != 0) continue;
      ResetLastError();
      if(!ObjectDelete(chartID, objectName))
         Print("[EA|FULL|DETAILS] ERROR object delete failed | name=",
               objectName, " | err=", GetLastError());
     }
  }

string OpportunityDetailsValue(string value)
  {
   return StringLen(value) > 0 ? value : "-";
  }

string OpportunityDetailsTime(datetime value)
  {
   if(value <= 0) return "-";
   return TimeToString(value, TIME_DATE|TIME_MINUTES);
  }

string OpportunityDetailsPrice(double value)
  {
   if(value <= 0.0) return "-";
   return DoubleToString(value, 5);
  }

string OpportunityDetailsRuleValue(string value)
  {
   if(value == "1") return "通过(1)";
   if(value == "0") return "未通过(0)";
   return OpportunityDetailsValue(value);
  }

string OpportunityDetailsBoolValue(bool value)
  {
   return value ? "是" : "否";
  }

string OpportunityDetailsPageTitle(int page)
  {
   if(page == 0) return "案例概览与规则";
   if(page == 1) return "S 结构与 Key Bar";
   if(page == 2) return "Drawings 与 R1/R2/R3";
   return "通道、语义与数据完整性";
  }

void CreateOpportunityDetailsLabel(long chartID, string name,
                                   int x, int y, string text,
                                   color textColor, int fontSize,
                                   string tooltip)
  {
   if(ObjectFind(chartID, name) < 0)
     {
      ResetLastError();
      if(!ObjectCreate(chartID, name, OBJ_LABEL, 0, 0, 0))
        {
         Print("[EA|FULL|DETAILS] ERROR label creation failed | name=",
               name, " | err=", GetLastError());
         return;
        }
     }
   ObjectSetInteger(chartID, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chartID, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(chartID, name, OBJPROP_TEXT, text);
   ObjectSetString(chartID, name, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetInteger(chartID, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(chartID, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, name, OBJPROP_ZORDER, 3100);
   ObjectSetString(chartID, name, OBJPROP_TOOLTIP,
                   StringLen(tooltip) > 0 ? tooltip : "\n");
  }

void AddOpportunityDetailsLine(long chartID, int panelX, int panelY,
                               int &row, string text, color textColor,
                               string tooltip)
  {
   string name = OPPORTUNITY_DETAILS_OBJECT_PREFIX + "row_" +
                 StringFormat("%02d", row);
   int y = panelY + 66 + row * OPPORTUNITY_DETAILS_LINE_HEIGHT_PX;
   CreateOpportunityDetailsLabel(chartID, name, panelX + 16, y,
                                  text, textColor, 8, tooltip);
   row++;
  }

void ConfigureOpportunityDetailsPanelButton(long chartID, string name)
  {
   ObjectSetInteger(chartID, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetString(chartID, name, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetInteger(chartID, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(chartID, name, OBJPROP_ZORDER, 3200);
  }

void CreateOpportunityDetailsButton()
  {
   CreateButton(OBJ_FULL_BTN_CASE_DETAILS, 12, 48, 96, 26,
                "数据详情", clrDarkSlateGray);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_DETAILS, OBJPROP_CORNER,
                    CORNER_LEFT_LOWER);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_DETAILS, OBJPROP_ANCHOR,
                    ANCHOR_LEFT_LOWER);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_DETAILS, OBJPROP_FONT,
                   "Microsoft YaHei");
   ObjectSetString(0, OBJ_FULL_BTN_CASE_DETAILS, OBJPROP_TOOLTIP,
                   "查看当前案例的只读数据详情；不会写入正式档案");
  }

void HideOpportunityDetailsPanel(long chartID)
  {
   bool wasVisible = opportunityDetailsVisible;
   opportunityDetailsVisible = false;
   opportunityDetailsPage = 0;
   DeleteOpportunityDetailsPanelObjects(chartID);
   if(wasVisible)
      Print("[EA|FULL|DETAILS] INFO panel closed | case=",
            OpportunityCaseId(), " | archive_touched=0");
   ChartRedraw(chartID);
  }

void ShowOpportunityDetailsPanel(long chartID)
  {
   CloseFullWorkYearMenu(chartID);
   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);
   opportunityDetailsVisible = true;
   opportunityDetailsPage = 0;
   RenderOpportunityDetailsPanel(chartID);
   Print("[EA|FULL|DETAILS] INFO panel opened | case=",
         OpportunityCaseId(), " | catalog_index=",
         FindOpportunityCaseCatalogIndex(OpportunityCaseId()),
         " | archive_touched=0");
  }

bool HandleOpportunityDetailsClick(long chartID, string objectName)
  {
   if(objectName == OBJ_FULL_BTN_CASE_DETAILS)
     {
      ClickFlash(objectName);
      if(opportunityDetailsVisible) HideOpportunityDetailsPanel(chartID);
      else ShowOpportunityDetailsPanel(chartID);
      return true;
     }

   if(!opportunityDetailsVisible) return false;
   if(objectName == OBJ_OPPORTUNITY_DETAILS_CLOSE)
     {
      ClickFlash(objectName);
      HideOpportunityDetailsPanel(chartID);
      return true;
     }
   if(objectName == OBJ_OPPORTUNITY_DETAILS_PREV)
     {
      ClickFlash(objectName);
      if(opportunityDetailsPage > 0) opportunityDetailsPage--;
      RenderOpportunityDetailsPanel(chartID);
      return true;
     }
   if(objectName == OBJ_OPPORTUNITY_DETAILS_NEXT)
     {
      ClickFlash(objectName);
      if(opportunityDetailsPage < OPPORTUNITY_DETAILS_PAGE_COUNT - 1)
         opportunityDetailsPage++;
      RenderOpportunityDetailsPanel(chartID);
      return true;
     }

   return true;
  }

void RenderOpportunityDetailsPanel(long chartID)
  {
   DeleteOpportunityDetailsPanelObjects(chartID);
   if(!opportunityDetailsVisible) return;

   long chartWidthValue = 0;
   long chartHeightValue = 0;
   ResetLastError();
   bool widthRead = ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0,
                                    chartWidthValue);
   int widthError = GetLastError();
   ResetLastError();
   bool heightRead = ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0,
                                     chartHeightValue);
   int heightError = GetLastError();
   if(!widthRead || !heightRead)
      Print("[EA|FULL|DETAILS] ERROR chart size unavailable | width_ok=",
            (int)widthRead, " | width_err=", widthError,
            " | height_ok=", (int)heightRead,
            " | height_err=", heightError);

   int chartWidth = widthRead ? (int)chartWidthValue : 1100;
   int chartHeight = heightRead ? (int)chartHeightValue : 700;
   int panelWidth = 820;
   int panelHeight = 500;
   if(panelWidth > chartWidth - 24) panelWidth = chartWidth - 24;
   if(panelHeight > chartHeight - 48) panelHeight = chartHeight - 48;
   if(panelWidth < 360) panelWidth = 360;
   if(panelHeight < 320) panelHeight = 320;
   int panelX = (chartWidth - panelWidth) / 2;
   int panelY = (chartHeight - panelHeight) / 2;
   if(panelX < 6) panelX = 6;
   if(panelY < 8) panelY = 8;

   CreateRectLabel(OBJ_OPPORTUNITY_DETAILS_BG, panelX, panelY,
                   panelWidth, panelHeight, C'24,28,34', BORDER_FLAT);
   ObjectSetInteger(chartID, OBJ_OPPORTUNITY_DETAILS_BG, OBJPROP_CORNER,
                    CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, OBJ_OPPORTUNITY_DETAILS_BG, OBJPROP_ANCHOR,
                    ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, OBJ_OPPORTUNITY_DETAILS_BG, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, OBJ_OPPORTUNITY_DETAILS_BG, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartID, OBJ_OPPORTUNITY_DETAILS_BG, OBJPROP_ZORDER, 3000);

   string title = "案例数据详情 | " +
                  OpportunityDetailsPageTitle(opportunityDetailsPage);
   CreateOpportunityDetailsLabel(chartID, OBJ_OPPORTUNITY_DETAILS_TITLE,
                                  panelX + 16, panelY + 14, title,
                                  clrWhite, 11,
                                  "当前案例只读详情；所有内容来自已加载档案");
   CreateOpportunityDetailsLabel(chartID, OBJ_OPPORTUNITY_DETAILS_PAGE,
                                  panelX + 16, panelY + 42,
                                  "当前案例 | " +
                                  OpportunityDetailsValue(OpportunityCaseId()),
                                  clrLightSteelBlue, 9,
                                  "archive_touched=0");

   CreateButton(OBJ_OPPORTUNITY_DETAILS_CLOSE,
                panelX + panelWidth - 50, panelY + 10, 36, 24,
                "关闭", clrFireBrick);
   ConfigureOpportunityDetailsPanelButton(chartID,
                                           OBJ_OPPORTUNITY_DETAILS_CLOSE);

   int footerY = panelY + panelHeight - 38;
   CreateButton(OBJ_OPPORTUNITY_DETAILS_PREV, panelX + 16, footerY,
                58, 24, "上一页", clrDarkSlateGray);
   ConfigureOpportunityDetailsPanelButton(chartID,
                                           OBJ_OPPORTUNITY_DETAILS_PREV);
   CreateButton(OBJ_OPPORTUNITY_DETAILS_NEXT, panelX + 80, footerY,
                58, 24, "下一页", clrDarkSlateGray);
   ConfigureOpportunityDetailsPanelButton(chartID,
                                           OBJ_OPPORTUNITY_DETAILS_NEXT);
   CreateOpportunityDetailsLabel(chartID,
                                  OPPORTUNITY_DETAILS_OBJECT_PREFIX + "footer",
                                  panelX + 154, footerY + 4,
                                  StringFormat("第 %d / %d 页 | 只读展示 | 长字段请悬浮对应行查看",
                                               opportunityDetailsPage + 1,
                                               OPPORTUNITY_DETAILS_PAGE_COUNT),
                                  clrSilver, 8, "archive_touched=0");

   int row = 0;
   int activeIndex = FindOpportunityCaseCatalogIndex(OpportunityCaseId());
   if(opportunityDetailsPage == 0)
     {
      if(activeIndex < 0)
        {
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "当前案例尚未进入正式案例目录，暂无正式案例快照可展示。",
                                   clrGold, "catalog_index=-1");
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "当前会话 | 类型 " +
                                   OpportunityDetailsValue(OpportunityCaseType()) +
                                   " | 标准性 " +
                                   OpportunityDetailsValue(opportunityActiveStandardity),
                                   clrWhite, "当前会话状态；未触发任何保存");
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   StringFormat("已加载内存 | S %d | 线锚点 %d | Key Bar %d | Drawings %d | Regions %d",
                                                ArraySize(opportunityStructures),
                                                CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1),
                                                opportunityKeyBar.active ? 1 : 0,
                                                ArraySize(opportunityDrawings),
                                                ArraySize(opportunityRegions)),
                                   clrSilver, "只读内存计数");
        }
      else
        {
         OpportunityCaseCatalogEntry entry = opportunityCaseCatalog[activeIndex];
         int actualLines = CountOpportunityLineAnchors(
                              0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1);
         int actualKeyBars = opportunityKeyBar.active ? 1 : 0;
         bool countsMatch =
            (ArraySize(opportunityStructures) == entry.structureCount &&
             actualLines == entry.lineCount &&
             actualKeyBars == entry.keyBarCount &&
             ArraySize(opportunityDrawings) == entry.drawingCount &&
             ArraySize(opportunityRegions) == entry.regionCount);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "案例 ID | " + entry.caseId,
                                   clrWhite, "case_id=" + entry.caseId);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "类型 | " + entry.caseType +
                                   " | Case Code " +
                                   OpportunityDetailsValue(entry.caseCode) +
                                   " | 级别 " +
                                   OpportunityDetailsValue(entry.opportunityLevel),
                                   clrWhite, "case_type=" + entry.caseType);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "市场 | " + entry.symbol + " / " +
                                   entry.timeframe + " | 年份 " +
                                   IntegerToString(entry.year),
                                   clrSilver, "symbol=" + entry.symbol +
                                   "\ntimeframe=" + entry.timeframe);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "状态 | " + OpportunityDetailsValue(entry.status) +
                                   " | 标准性 " +
                                   OpportunityDetailsValue(entry.standardity) +
                                   " | 已确认 " +
                                   OpportunityDetailsBoolValue(entry.standardityConfirmed),
                                   clrSilver, "standardity_confirmed=" +
                                   IntegerToString((int)entry.standardityConfirmed));
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "形成区间 | " +
                                   OpportunityDetailsTime(entry.formationStart) +
                                   " -> " + OpportunityDetailsTime(entry.readyTime),
                                   clrSilver, "formation_start=" +
                                   OpportunityDetailsTime(entry.formationStart) +
                                   "\nready_time=" +
                                   OpportunityDetailsTime(entry.readyTime));
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "积累区间 | " +
                                   OpportunityDetailsTime(entry.accumulationStart) +
                                   " -> " +
                                   OpportunityDetailsTime(entry.accumulationEnd) +
                                   " | " +
                                   DoubleToString(entry.accumulationDurationHours, 1) +
                                   " 小时 | H1 bars " +
                                   IntegerToString(entry.accumulationH1Bars),
                                   clrSilver, "opportunity_level=" +
                                   entry.opportunityLevel);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   StringFormat("案例计数 | pivot %d | upper %d | lower %d",
                                                entry.pivotCount,
                                                entry.upperCount,
                                                entry.lowerCount),
                                   clrWhite, "正式 cases.csv 保存值");
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "规则位 | 时间顺序 " +
                                   OpportunityDetailsRuleValue(entry.timeOrderRule) +
                                   " | 交替 " +
                                   OpportunityDetailsRuleValue(entry.alternationRule) +
                                   " | 进展 " +
                                   OpportunityDetailsRuleValue(entry.progressionRule),
                                   clrWhite, "time_order_ok=" + entry.timeOrderRule +
                                   "\nalternation_ok=" + entry.alternationRule +
                                   "\nprogression_ok=" + entry.progressionRule);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "规则位 | 上边界方向 " +
                                   OpportunityDetailsRuleValue(entry.upperDirectionRule) +
                                   " | 下边界方向 " +
                                   OpportunityDetailsRuleValue(entry.lowerDirectionRule) +
                                   " | 平行 " +
                                   OpportunityDetailsRuleValue(entry.parallelRule),
                                   clrWhite,
                                   "upper_rising_ok=" + entry.upperDirectionRule +
                                   "\nlower_rising_ok=" + entry.lowerDirectionRule +
                                   "\nparallel_ok=" + entry.parallelRule +
                                   "\n通道案例中 rising 列保存的是对应方向是否符合所选通道类型");
         color ruleColor = entry.ruleStatus == "PASS" ? clrLime : clrGold;
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "规则结果 | " +
                                   OpportunityDetailsValue(entry.ruleStatus) +
                                   " | Future Outcome " +
                                   OpportunityDetailsValue(entry.futureOutcome),
                                   ruleColor, "rule_status=" + entry.ruleStatus +
                                   "\nfuture_outcome=" + entry.futureOutcome);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "更新时间 | " +
                                   OpportunityDetailsValue(entry.updatedAt),
                                   clrSilver, "cases.csv updated_at=" +
                                   entry.updatedAt);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   StringFormat("档案行数 | S %d/%d | 线锚点 %d/%d | Key Bar %d/%d | Drawings %d/%d | Regions %d/%d",
                                                ArraySize(opportunityStructures), entry.structureCount,
                                                actualLines, entry.lineCount,
                                                actualKeyBars, entry.keyBarCount,
                                                ArraySize(opportunityDrawings), entry.drawingCount,
                                                ArraySize(opportunityRegions), entry.regionCount),
                                   countsMatch ? clrLime : clrTomato,
                                   "当前已加载内存计数 / 案例目录计数");
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   StringFormat("派生档案 | Semantics %d | Channel Boundaries %d | 目录完整 %s | 数量一致 %s",
                                                ArraySize(opportunityDrawingSemantics),
                                                ArraySize(opportunityChannelBoundaries),
                                                OpportunityDetailsBoolValue(entry.annotationComplete),
                                                OpportunityDetailsBoolValue(countsMatch)),
                                   countsMatch ? clrLime : clrTomato,
                                   "只读展示；未重新计算或写入档案");
        }
     }
   else if(opportunityDetailsPage == 1)
     {
      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                StringFormat("结构汇总 | S %d | 通道线锚点 %d | Key Bar %d",
                                             ArraySize(opportunityStructures),
                                             CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1),
                                             opportunityKeyBar.active ? 1 : 0),
                                clrLightSteelBlue, "当前案例已加载锚点档案");
      if(ArraySize(opportunityStructures) == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "S 结构 | 无保存记录", clrSilver, "rows=0");
      for(int i = 0; i < ArraySize(opportunityStructures); i++)
        {
         OpportunityStructureState structure = opportunityStructures[i];
         string structureText = structure.role +
            " | seq " + IntegerToString(structure.actionSequence) +
            " | center " + OpportunityDetailsTime(structure.centerTime) +
            " @ " + OpportunityDetailsPrice(structure.centerPrice) +
            " | rep " + OpportunityDetailsTime(structure.representativeTime) +
            " @ " + OpportunityDetailsPrice(structure.representativePrice) +
            " " + OpportunityDetailsValue(structure.representativeType);
         string structureTooltip =
            "role=" + structure.role +
            "\naction_sequence=" + IntegerToString(structure.actionSequence) +
            "\ncenter_time=" + OpportunityDetailsTime(structure.centerTime) +
            "\ncenter_price=" + DoubleToString(structure.centerPrice, 8) +
            "\ncenter_bar_shift=" + IntegerToString(structure.centerBarShift) +
            "\nradius_bars=" + IntegerToString(structure.radiusBars) +
            "\nrange_start_time=" + OpportunityDetailsTime(structure.rangeStartTime) +
            "\nrange_end_time=" + OpportunityDetailsTime(structure.rangeEndTime) +
            "\ncircle_low=" + DoubleToString(structure.circleLow, 8) +
            "\ncircle_high=" + DoubleToString(structure.circleHigh, 8) +
            "\nzone_low=" + DoubleToString(structure.zoneLow, 8) +
            "\nzone_high=" + DoubleToString(structure.zoneHigh, 8) +
            "\nrepresentative_time=" + OpportunityDetailsTime(structure.representativeTime) +
            "\nrepresentative_price=" + DoubleToString(structure.representativePrice, 8) +
            "\nsnap_type=" + structure.representativeType +
            "\nrepresentative_bar_shift=" + IntegerToString(structure.representativeBarShift);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   structureText, clrWhite,
                                   structureTooltip);
        }

      int activeLineAnchors = 0;
      for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
        {
         OpportunityAnchorState anchor = opportunityLineAnchors[i];
         if(!anchor.active) continue;
         activeLineAnchors++;
         string anchorText = anchor.role +
            " | seq " + IntegerToString(anchor.actionSequence) +
            " | " + OpportunityDetailsTime(anchor.barTime) +
            " @ " + OpportunityDetailsPrice(anchor.price) +
            " | snap " + OpportunityDetailsValue(anchor.snapType) +
            " | shift " + IntegerToString(anchor.barShift);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   anchorText, clrSilver,
                                   "anchor_kind=LINE\nanchor_role=" + anchor.role +
                                   "\naction_sequence=" + IntegerToString(anchor.actionSequence) +
                                   "\ncenter_time=" + OpportunityDetailsTime(anchor.barTime) +
                                   "\ncenter_price=" + DoubleToString(anchor.price, 8) +
                                   "\ncenter_bar_shift=" + IntegerToString(anchor.barShift) +
                                   "\nsnap_type=" + anchor.snapType);
        }
      if(activeLineAnchors == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "通道线锚点 | 无保存记录", clrSilver,
                                   "rows=0");

      if(opportunityKeyBar.active)
        {
         string keyBarText = "Key Bar | " + opportunityKeyBar.role +
            " | seq " + IntegerToString(opportunityKeyBar.actionSequence) +
            " | " + OpportunityDetailsTime(opportunityKeyBar.barTime) +
            " | " + OpportunityDetailsValue(opportunityKeyBar.direction) +
            " | O/H/L/C " +
            OpportunityDetailsPrice(opportunityKeyBar.openPrice) + "/" +
            OpportunityDetailsPrice(opportunityKeyBar.highPrice) + "/" +
            OpportunityDetailsPrice(opportunityKeyBar.lowPrice) + "/" +
            OpportunityDetailsPrice(opportunityKeyBar.closePrice);
         string keyBarTooltip =
            "role=" + opportunityKeyBar.role +
            "\naction_sequence=" + IntegerToString(opportunityKeyBar.actionSequence) +
            "\nbar_time=" + OpportunityDetailsTime(opportunityKeyBar.barTime) +
            "\nconfirm_time=" + OpportunityDetailsTime(opportunityKeyBar.confirmTime) +
            "\nhighlight_start_time=" + OpportunityDetailsTime(opportunityKeyBar.highlightStartTime) +
            "\nhighlight_end_time=" + OpportunityDetailsTime(opportunityKeyBar.highlightEndTime) +
            "\nopen=" + DoubleToString(opportunityKeyBar.openPrice, 8) +
            "\nhigh=" + DoubleToString(opportunityKeyBar.highPrice, 8) +
            "\nlow=" + DoubleToString(opportunityKeyBar.lowPrice, 8) +
            "\nclose=" + DoubleToString(opportunityKeyBar.closePrice, 8) +
            "\nbar_shift=" + IntegerToString(opportunityKeyBar.barShift) +
            "\ndirection=" + opportunityKeyBar.direction;
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   keyBarText, clrGold, keyBarTooltip);
        }
      else
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "Key Bar | 无保存记录", clrSilver,
                                   "rows=0");
     }
   else if(opportunityDetailsPage == 2)
     {
      string caseUpdatedAt = activeIndex >= 0 ?
         opportunityCaseCatalog[activeIndex].updatedAt : "";
      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                StringFormat("绘图与区间汇总 | Drawings %d | Regions %d | 案例更新时间 %s",
                                             ArraySize(opportunityDrawings),
                                             ArraySize(opportunityRegions),
                                             OpportunityDetailsValue(caseUpdatedAt)),
                                clrLightSteelBlue,
                                "绘图长字段与样式参数请悬浮对应行查看");
      if(ArraySize(opportunityDrawings) == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "Drawings | 无保存记录", clrSilver,
                                   "rows=0");
      for(int i = 0; i < ArraySize(opportunityDrawings); i++)
        {
         OpportunityDrawingState drawing = opportunityDrawings[i];
         string drawingText = drawing.drawingId +
            " | type " + IntegerToString((int)drawing.objectType) +
            " | anchors " + IntegerToString(drawing.anchorCount) +
            " | " + OpportunityDetailsTime(drawing.time1) +
            " @ " + OpportunityDetailsPrice(drawing.price1) +
            " -> " + OpportunityDetailsTime(drawing.time2) +
            " @ " + OpportunityDetailsPrice(drawing.price2) +
            " | role " + OpportunityDetailsValue(drawing.semanticRole);
         string drawingTooltip =
            "drawing_id=" + drawing.drawingId +
            "\nsource_name=" + drawing.sourceName +
            "\nobject_type=" + IntegerToString((int)drawing.objectType) +
            "\nsubwindow=" + IntegerToString(drawing.subwindow) +
            "\nanchor_count=" + IntegerToString(drawing.anchorCount) +
            "\ntime_1=" + OpportunityDetailsTime(drawing.time1) +
            "\nprice_1=" + DoubleToString(drawing.price1, 16) +
            "\ntime_2=" + OpportunityDetailsTime(drawing.time2) +
            "\nprice_2=" + DoubleToString(drawing.price2, 16) +
            "\ntime_3=" + OpportunityDetailsTime(drawing.time3) +
            "\nprice_3=" + DoubleToString(drawing.price3, 16) +
            "\ncolor=" + IntegerToString((int)drawing.objectColor) +
            "\nstyle=" + IntegerToString((int)drawing.lineStyle) +
            "\nwidth=" + IntegerToString(drawing.lineWidth) +
            "\nback=" + IntegerToString((int)drawing.drawInBackground) +
            "\nfill=" + IntegerToString((int)drawing.fill) +
            "\nray_left=" + IntegerToString((int)drawing.rayLeft) +
            "\nray_right=" + IntegerToString((int)drawing.rayRight) +
            "\nangle=" + DoubleToString(drawing.angle, 8) +
            "\nscale=" + DoubleToString(drawing.scale, 8) +
            "\ndeviation=" + DoubleToString(drawing.deviation, 8) +
            "\ntimeframes=" + IntegerToString((int)drawing.timeframes) +
            "\nzorder=" + IntegerToString((int)drawing.zorder) +
            "\ntext=" + OpportunityDetailsValue(drawing.text) +
            "\narrow_code=" + IntegerToString(drawing.arrowCode) +
            "\nanchor=" + IntegerToString((int)drawing.anchor) +
            "\nsemantic_role=" + OpportunityDetailsValue(drawing.semanticRole) +
            "\npath_id=" + OpportunityDetailsValue(drawing.pathId) +
            "\nsegment_order=" + IntegerToString(drawing.segmentOrder) +
            "\nanchor_1_role=" + OpportunityDetailsValue(drawing.anchor1Role) +
            "\nanchor_2_role=" + OpportunityDetailsValue(drawing.anchor2Role) +
            "\nsemantic_source=" + OpportunityDetailsValue(drawing.semanticSource) +
            "\nsemantic_confirmed=" + IntegerToString((int)drawing.semanticConfirmed);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   drawingText, clrWhite,
                                   drawingTooltip);
        }

      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                "R1 / R2 / R3 区间", clrGold,
                                "正式 opportunity_regions.csv 已加载内容");
      if(ArraySize(opportunityRegions) == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "Regions | 无保存记录", clrSilver,
                                   "rows=0");
      for(int i = 0; i < ArraySize(opportunityRegions); i++)
        {
         OpportunityRegionState region = opportunityRegions[i];
         string regionText = region.regionId + " | " + region.displayName +
            " | " + region.startDrawingId + " -> " + region.endDrawingId +
            " | " + OpportunityDetailsTime(region.startTime) +
            " -> " + OpportunityDetailsTime(region.endTime);
         string regionTooltip =
            "region_id=" + region.regionId +
            "\nregion_role=" + region.role +
            "\ndisplay_name=" + region.displayName +
            "\nstart_drawing_id=" + region.startDrawingId +
            "\nend_drawing_id=" + region.endDrawingId +
            "\nstart_time=" + OpportunityDetailsTime(region.startTime) +
            "\nend_time=" + OpportunityDetailsTime(region.endTime);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   regionText, clrSilver,
                                   regionTooltip);
        }
     }
   else
     {
      int semanticFingerprints = 0;
      for(int i = 0; i < ArraySize(opportunityDrawingSemantics); i++)
         if(StringLen(opportunityDrawingSemantics[i].drawingFingerprint) > 0 &&
            StringLen(opportunityDrawingSemantics[i].inputFingerprint) > 0)
            semanticFingerprints++;
      int boundaryFingerprints = 0;
      for(int i = 0; i < ArraySize(opportunityChannelBoundaries); i++)
         if(StringLen(opportunityChannelBoundaries[i].sourceDrawingFingerprint) > 0 &&
            StringLen(opportunityChannelBoundaries[i].boundaryFingerprint) > 0)
            boundaryFingerprints++;

      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                StringFormat("完整性摘要 | Semantics %d | 双指纹 %d | Boundaries %d | 双指纹 %d",
                                             ArraySize(opportunityDrawingSemantics),
                                             semanticFingerprints,
                                             ArraySize(opportunityChannelBoundaries),
                                             boundaryFingerprints),
                                (semanticFingerprints == ArraySize(opportunityDrawingSemantics) &&
                                 boundaryFingerprints == ArraySize(opportunityChannelBoundaries)) ?
                                clrLime : clrGold,
                                "本页仅显示已由现有加载校验接受的派生档案行");
      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                "通道边界 | 完整指纹、算法版本和证据请悬浮对应行查看",
                                clrGold, "archive_touched=0");
      if(ArraySize(opportunityChannelBoundaries) == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "Channel Boundaries | 当前案例无通道边界记录",
                                   clrSilver, "rows=0");
      for(int i = 0; i < ArraySize(opportunityChannelBoundaries); i++)
        {
         OpportunityChannelBoundaryState boundary = opportunityChannelBoundaries[i];
         string boundaryText = boundary.componentId +
            " | " + boundary.boundaryRole +
            " | " + boundary.channelDirection +
            " | slope " + DoubleToString(boundary.slopePricePerH1Bar, 8) +
            " | width ATR " + DoubleToString(boundary.channelWidthAtr, 3) +
            " | parallel " + OpportunityDetailsBoolValue(boundary.parallelOK) +
            " | touches " + IntegerToString(boundary.touchCount);
         string boundaryTooltip =
            "channel_id=" + boundary.channelId +
            "\nsource_drawing_id=" + boundary.sourceDrawingId +
            "\ncomponent_id=" + boundary.componentId +
            "\nnative_line_index=" + IntegerToString(boundary.nativeLineIndex) +
            "\ncomponent_role=" + boundary.componentRole +
            "\nboundary_role=" + boundary.boundaryRole +
            "\nchannel_direction=" + boundary.channelDirection +
            "\nsymbol=" + boundary.symbol +
            "\ntimeframe=" + boundary.timeframe +
            "\ntime_1=" + OpportunityDetailsTime(boundary.time1) +
            "\nprice_1=" + DoubleToString(boundary.price1, 16) +
            "\ntime_2=" + OpportunityDetailsTime(boundary.time2) +
            "\nprice_2=" + DoubleToString(boundary.price2, 16) +
            "\nslope_price_per_h1_bar=" + DoubleToString(boundary.slopePricePerH1Bar, 16) +
            "\nreference_atr=" + DoubleToString(boundary.referenceAtr, 16) +
            "\nchannel_width_price=" + DoubleToString(boundary.channelWidthPrice, 16) +
            "\nchannel_width_atr=" + DoubleToString(boundary.channelWidthAtr, 12) +
            "\nparallel_error_price=" + DoubleToString(boundary.parallelErrorPrice, 16) +
            "\nparallel_error_ratio=" + DoubleToString(boundary.parallelErrorRatio, 12) +
            "\nparallel_ok=" + IntegerToString((int)boundary.parallelOK) +
            "\ntouch_count=" + IntegerToString(boundary.touchCount) +
            "\ntouch_anchor_roles=" + boundary.touchAnchorRoles +
            "\ntouch_distance_prices=" + boundary.touchDistancePrices +
            "\nsource_anchor_refs=" + boundary.sourceAnchorRefs +
            "\ncoordinate_source=" + boundary.coordinateSource +
            "\nsource_drawing_fingerprint=" + boundary.sourceDrawingFingerprint +
            "\nboundary_fingerprint=" + boundary.boundaryFingerprint +
            "\nalgorithm_version=" + boundary.algorithmVersion +
            "\nfeature_version=" + boundary.featureVersion +
            "\nschema_version=" + boundary.schemaVersion +
            "\ndecision_status=" + boundary.decisionStatus +
            "\nevidence=" + boundary.evidence +
            "\nderived_at=" + OpportunityDetailsTime(boundary.derivedAt);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   boundaryText, clrWhite,
                                   boundaryTooltip);
        }

      AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                "绘图语义 | 完整输入指纹与几何指标请悬浮对应行查看",
                                clrGold, "archive_touched=0");
      if(ArraySize(opportunityDrawingSemantics) == 0)
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   "Drawing Semantics | 当前案例无语义记录",
                                   clrSilver, "rows=0");
      for(int i = 0; i < ArraySize(opportunityDrawingSemantics); i++)
        {
         OpportunityDrawingSemanticState semantic = opportunityDrawingSemantics[i];
         string semanticText = semantic.drawingId +
            " | " + OpportunityDetailsValue(semantic.semanticRole) +
            " | order " + IntegerToString(semantic.segmentOrder) +
            " | score " + DoubleToString(semantic.score, 3) +
            " | R1/R2 " + DoubleToString(semantic.r1Overlap, 3) +
            "/" + DoubleToString(semantic.r2Overlap, 3) +
            " | " + OpportunityDetailsValue(semantic.decisionStatus);
         string semanticTooltip =
            "drawing_id=" + semantic.drawingId +
            "\nsymbol=" + semantic.symbol +
            "\ntimeframe=" + semantic.timeframe +
            "\nobject_type=" + IntegerToString((int)semantic.objectType) +
            "\ntime_1=" + OpportunityDetailsTime(semantic.time1) +
            "\nprice_1=" + DoubleToString(semantic.price1, 16) +
            "\ntime_2=" + OpportunityDetailsTime(semantic.time2) +
            "\nprice_2=" + DoubleToString(semantic.price2, 16) +
            "\ndrawing_fingerprint=" + semantic.drawingFingerprint +
            "\ninput_fingerprint=" + semantic.inputFingerprint +
            "\nsemantic_role=" + semantic.semanticRole +
            "\npath_id=" + semantic.pathId +
            "\nsegment_order=" + IntegerToString(semantic.segmentOrder) +
            "\nanchor_1_role=" + semantic.anchor1Role +
            "\nanchor_2_role=" + semantic.anchor2Role +
            "\nsemantic_source=" + semantic.semanticSource +
            "\nalgorithm_version=" + semantic.algorithmVersion +
            "\nfeature_version=" + semantic.featureVersion +
            "\nschema_version=" + semantic.schemaVersion +
            "\ndecision_status=" + semantic.decisionStatus +
            "\nscore=" + DoubleToString(semantic.score, 6) +
            "\nevidence=" + semantic.evidence +
            "\nr1_overlap=" + DoubleToString(semantic.r1Overlap, 6) +
            "\nr2_overlap=" + DoubleToString(semantic.r2Overlap, 6) +
            "\neffective_h1_bars=" + IntegerToString(semantic.effectiveH1Bars) +
            "\nreference_atr=" + DoubleToString(semantic.referenceAtr, 8) +
            "\ndisplacement_atr=" + DoubleToString(semantic.displacementAtr, 6) +
            "\nslope_atr_per_bar=" + DoubleToString(semantic.slopeAtrPerBar, 6) +
            "\npath_efficiency=" + DoubleToString(semantic.pathEfficiency, 6) +
            "\nfirst_structure_role=" + semantic.firstStructureRole +
            "\nfirst_structure_connected=" + IntegerToString((int)semantic.firstStructureConnected) +
            "\nconnected_endpoint=" + semantic.connectedEndpoint +
            "\nendpoint_time_distance_bars=" + DoubleToString(semantic.endpointTimeDistanceBars, 3) +
            "\nendpoint_price_distance_atr=" + DoubleToString(semantic.endpointPriceDistanceAtr, 6) +
            "\nchannel_excluded=" + IntegerToString((int)semantic.channelExcluded) +
            "\nderived_at=" + OpportunityDetailsTime(semantic.derivedAt);
         AddOpportunityDetailsLine(chartID, panelX, panelY, row,
                                   semanticText, clrSilver,
                                   semanticTooltip);
        }
     }
   ChartRedraw(chartID);
  }

string OpportunityCsvSafe(string value)
  {
   StringReplace(value, ",", "_");
   StringReplace(value, "\r", " ");
   StringReplace(value, "\n", " ");
   return value;
  }

string OpportunityCaseId()
  {
   if(StringLen(opportunityActiveCaseId) > 0)
      return OpportunityCsvSafe(opportunityActiveCaseId);
   if(!opportunityExplicitNoSelection && InpOpenDefaultCaseOnStartup)
      return OpportunityCsvSafe(InpAnnotationCaseId);
   return "";
  }

int OpportunityCaseIdYear(string caseId)
  {
   string fields[];
   if(StringSplit(caseId, '-', fields) < 2) return 0;
   int year = (int)StringToInteger(fields[1]);
   if(year < 1900 || year > 2100) return 0;
   return year;
  }

int OpportunityCaseAnnualSequence(string caseId)
  {
   string caseToken = "-CASE-";
   int tokenPos = StringFind(caseId, caseToken);
   int sequence = 0;
   if(tokenPos >= 0)
      sequence = (int)StringToInteger(
         StringSubstr(caseId, tokenPos + StringLen(caseToken)));
   else
     {
      int separatorPos = -1;
      for(int charIndex = StringLen(caseId) - 1; charIndex >= 0; charIndex--)
         if(StringSubstr(caseId, charIndex, 1) == "-")
           {
            separatorPos = charIndex;
            break;
           }
      if(separatorPos >= 0)
         sequence = (int)StringToInteger(StringSubstr(caseId, separatorPos + 1));
     }
   return sequence > 0 ? sequence : 0;
  }

string OpportunityCaseType()
  {
   if(StringLen(opportunityActiveCaseType) > 0)
      return OpportunityCsvSafe(opportunityActiveCaseType);
   if(!opportunityExplicitNoSelection && InpOpenDefaultCaseOnStartup)
      return OpportunityCsvSafe(InpAnnotationCaseType);
   return "UNSELECTED";
  }

string OpportunityAnnotationWriteCaseType()
  {
   if(opportunityCaseTypeDirty && !opportunityCaseTypeCommitInProgress &&
      StringLen(opportunityArchivedCaseType) > 0)
      return OpportunityCsvSafe(opportunityArchivedCaseType);
   return OpportunityCaseType();
  }

int FindOpportunityCaseCatalogIndex(string caseId)
  {
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
      if(opportunityCaseCatalog[i].caseId == caseId) return i;
   return -1;
  }

string OpportunityLevelFromAccumulationRange(string symbolName,
                                              datetime startTime,
                                              datetime endTime,
                                              long &durationSeconds,
                                              int &effectiveH1Bars)
  {
   durationSeconds = 0;
   effectiveH1Bars = 0;
   if(startTime <= 0 || endTime <= startTime) return "UNCLASSIFIED";
   durationSeconds = (long)endTime - (long)startTime;

   ResetLastError();
   int startShift = iBarShift(symbolName, PERIOD_H1, startTime, false);
   int startError = GetLastError();
   ResetLastError();
   int endShift = iBarShift(symbolName, PERIOD_H1, endTime, false);
   int endError = GetLastError();
   if(startShift < 0 || endShift < 0)
     {
      Print("[EA|FULL|CASE] ERROR authoritative H1 width unavailable | symbol=",
            symbolName,
            " | range=", TimeToString(startTime, TIME_DATE|TIME_MINUTES),
            "..", TimeToString(endTime, TIME_DATE|TIME_MINUTES),
            " | shifts=", startShift, "/", endShift,
            " | errors=", startError, "/", endError);
      return "UNCLASSIFIED";
     }

   effectiveH1Bars = startShift - endShift;
   if(effectiveH1Bars < 0) effectiveH1Bars = -effectiveH1Bars;
   effectiveH1Bars++;
   if(effectiveH1Bars <= OPPORTUNITY_LEVEL_H1_MAX_H1_BARS) return "H1";
   if(effectiveH1Bars <= OPPORTUNITY_LEVEL_H4_MAX_H1_BARS) return "H4";
   return "UNCLASSIFIED";
  }

string OpportunityLevelCode(string opportunityLevel)
  {
   if(opportunityLevel == "H1" || opportunityLevel == "H4") return opportunityLevel;
   return "UNCL";
  }

string BuildOpportunityCaseCode(string caseId, string opportunityLevel)
  {
   string parts[];
   ushort separator = StringGetCharacter("-", 0);
   int partCount = StringSplit(caseId, separator, parts);
   if(partCount < 4) return caseId + "-" + OpportunityLevelCode(opportunityLevel);

   string caseCode = "";
   for(int i = 0; i < partCount; i++)
     {
      string token = (i == 2) ? OpportunityLevelCode(opportunityLevel) : parts[i];
      if(i > 0) caseCode = caseCode + "-";
      caseCode = caseCode + token;
     }
   return caseCode;
  }

bool GetCurrentOpportunityAccumulationRange(datetime &startTime, datetime &endTime)
  {
   startTime = 0;
   endTime = 0;
   for(int i = 0; i < ArraySize(opportunityRegions); i++)
     {
      if(opportunityRegions[i].role != "ACCUMULATION") continue;
      if(opportunityRegions[i].startTime <= 0 ||
         opportunityRegions[i].endTime <= opportunityRegions[i].startTime) continue;
      startTime = opportunityRegions[i].startTime;
      endTime = opportunityRegions[i].endTime;
      return true;
     }
   return false;
  }

string OpportunityCaseDisplayId()
  {
   datetime accumulationStart = 0;
   datetime accumulationEnd = 0;
   long durationSeconds = 0;
   int effectiveH1Bars = 0;
   int catalogIndex = FindOpportunityCaseCatalogIndex(OpportunityCaseId());
   string classificationSymbol = ChartSymbol(0);
   if(catalogIndex >= 0 && StringLen(opportunityCaseCatalog[catalogIndex].symbol) > 0)
      classificationSymbol = opportunityCaseCatalog[catalogIndex].symbol;
   if(GetCurrentOpportunityAccumulationRange(accumulationStart, accumulationEnd))
     {
      string opportunityLevel = OpportunityLevelFromAccumulationRange(classificationSymbol,
                                                                       accumulationStart,
                                                                       accumulationEnd,
                                                                       durationSeconds,
                                                                       effectiveH1Bars);
      return BuildOpportunityCaseCode(OpportunityCaseId(), opportunityLevel);
     }

   if(catalogIndex >= 0 && StringLen(opportunityCaseCatalog[catalogIndex].caseCode) > 0)
      return opportunityCaseCatalog[catalogIndex].caseCode;
   return BuildOpportunityCaseCode(OpportunityCaseId(), "UNCLASSIFIED");
  }

string OpportunityCaseTypeDisplayName(string caseType)
  {
   if(caseType == "ASCENDING_RECTANGLE") return "上矩";
   if(caseType == "DESCENDING_RECTANGLE") return "下矩";
   if(caseType == "ASCENDING_CHANNEL") return "上升通道";
   if(caseType == "DESCENDING_CHANNEL") return "下降通道";
   if(caseType == "ASCENDING_TRIANGLE") return "上升三角形";
   if(caseType == "DESCENDING_TRIANGLE") return "下降三角形";
   if(caseType == "ASCENDING_FLAG") return "上升旗形";
   if(caseType == "DESCENDING_FLAG") return "下降旗形";
   if(caseType == "DOUBLE_TOP") return "双顶";
   if(caseType == "DOUBLE_BOTTOM") return "双底";
   if(caseType == "HEAD_AND_SHOULDERS_TOP") return "头肩顶";
   if(caseType == "HEAD_AND_SHOULDERS_BOTTOM") return "头肩底";
   if(caseType == "UPWARD_RELEASE") return "向上释放";
   if(caseType == "DOWNWARD_RELEASE") return "向下释放";
   return caseType;
  }

string OpportunityTypeId(int index)
  {
   if(index == 0) return "ASCENDING_RECTANGLE";
   if(index == 1) return "DESCENDING_RECTANGLE";
   if(index == 2) return "ASCENDING_TRIANGLE";
   if(index == 3) return "DESCENDING_TRIANGLE";
   if(index == 4) return "ASCENDING_FLAG";
   if(index == 5) return "DESCENDING_FLAG";
   if(index == 6) return "ASCENDING_CHANNEL";
   if(index == 7) return "DESCENDING_CHANNEL";
   if(index == 8) return "DOUBLE_TOP";
   if(index == 9) return "DOUBLE_BOTTOM";
   if(index == 10) return "HEAD_AND_SHOULDERS_TOP";
   if(index == 11) return "HEAD_AND_SHOULDERS_BOTTOM";
   if(index == 12) return "UPWARD_RELEASE";
   if(index == 13) return "DOWNWARD_RELEASE";
   return "";
  }

bool IsOpportunityTypeSupported(string caseType)
  {
   for(int i = 0; i < OPPORTUNITY_TYPE_COUNT; i++)
      if(OpportunityTypeId(i) == caseType) return true;
   return false;
  }

bool IsOpportunityStandarditySupported(string standardity)
  {
   return (standardity == "UNREVIEWED" ||
           standardity == "STANDARD" ||
           standardity == "NON_STANDARD");
  }

string OpportunityStandardityDisplayName(string standardity)
  {
   if(standardity == "STANDARD") return "标准";
   if(standardity == "NON_STANDARD") return "非标准";
   return "未确认";
  }

string OpportunityAnnotationWriteStandardity()
  {
   if(opportunityStandardityCommitInProgress)
      return (opportunityActiveStandardity == "NON_STANDARD") ?
             "NON_STANDARD" : "STANDARD";
   if(opportunityStandardityDirty)
      return IsOpportunityStandarditySupported(opportunityArchivedStandardity) ?
             opportunityArchivedStandardity : "UNREVIEWED";
   return IsOpportunityStandarditySupported(opportunityActiveStandardity) ?
          opportunityActiveStandardity : "UNREVIEWED";
  }

string OpportunitySessionEncodeField(string value)
  {
   value = OpportunityCsvSafe(value);
   StringReplace(value, "|", "_");
   if(StringLen(value) == 0) return "~";
   return value;
  }

string OpportunitySessionDecodeField(string value)
  {
   if(value == "~") return "";
   return value;
  }

bool OpportunitySessionNameIsRequired(string objectName, string &requiredNames[])
  {
   for(int i = 0; i < ArraySize(requiredNames); i++)
      if(requiredNames[i] == objectName) return true;
   return false;
  }

bool CreateOpportunitySessionMarker(long chartID, string objectName, int &errorCode)
  {
   errorCode = 0;
   if(StringLen(objectName) == 0 || StringLen(objectName) > 63)
     {
      errorCode = 4003;
      return false;
     }

   if(ObjectFind(chartID, objectName) < 0)
     {
      ResetLastError();
      if(!ObjectCreate(chartID, objectName, OBJ_LABEL, 0, 0, 0))
        {
         errorCode = GetLastError();
         return false;
        }
     }

   ResetLastError();
   bool configured = true;
   configured = ObjectSetString(chartID, objectName, OBJPROP_TEXT, "") && configured;
   configured = ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP, "\n") && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_CORNER,
                                 CORNER_LEFT_UPPER) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_ANCHOR,
                                 ANCHOR_LEFT_UPPER) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_XDISTANCE, 0) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_YDISTANCE, 0) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, clrNONE) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_BACK, true) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, true) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_TIMEFRAMES,
                                 OBJ_ALL_PERIODS) && configured;
   if(!configured) errorCode = GetLastError();
   return configured;
  }

int CountOpportunitySessionMarkers(long chartID)
  {
   int count = 0;
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = 0; i < total; i++)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OPPORTUNITY_SESSION_OBJECT_PREFIX) == 0)
         count++;
     }
   if(ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY) >= 0)
      count++;
   return count;
  }

int DeleteOpportunitySessionMarkers(long chartID)
  {
   int deleted = 0;
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OPPORTUNITY_SESSION_OBJECT_PREFIX) != 0) continue;
      if(ObjectDelete(chartID, objectName)) deleted++;
     }
   if(ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY) >= 0 &&
      ObjectDelete(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY))
      deleted++;
   int remaining = CountOpportunitySessionMarkers(chartID);
   if(remaining > 0)
      Print("[EA|FULL|SESSION] ERROR marker cleanup incomplete | remaining=",
            remaining, " | err=", GetLastError(), " | archive_touched=0");
   return remaining == 0 ? deleted : -1;
  }

bool PersistOpportunityExplicitNoSelection(long chartID)
  {
   int deleted = DeleteOpportunitySessionMarkers(chartID);
   if(deleted < 0) return false;
   int markerError = 0;
   if(!CreateOpportunitySessionMarker(chartID,
                                      OBJ_FULL_OPPORTUNITY_NO_SELECTION,
                                      markerError) ||
      ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION) < 0 ||
      CountOpportunitySessionMarkers(chartID) != 0)
     {
      Print("[EA|FULL|SESSION] ERROR explicit no-selection marker failed",
            " | err=", markerError, " | archive_touched=0");
      return false;
     }
   opportunityExplicitNoSelection = true;
   Print("[EA|FULL|SESSION] INFO explicit no-selection state saved",
         " | deleted_markers=", deleted, " | archive_touched=0");
   return true;
  }

bool ReadOpportunitySessionMarker(long chartID,
                                  string fieldPrefix,
                                  string &value,
                                  int &matchCount)
  {
   value = "";
   matchCount = 0;
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = 0; i < total; i++)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, fieldPrefix) != 0) continue;
      matchCount++;
      if(matchCount == 1)
         value = OpportunitySessionDecodeField(
            StringSubstr(objectName, StringLen(fieldPrefix)));
     }
   return (matchCount == 1);
  }

bool SaveOpportunitySessionState(long chartID, string reason)
  {
   if(chartID == 0 || StringLen(OpportunityCaseId()) == 0) return false;

   if(ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION) >= 0 &&
      !ObjectDelete(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION))
     {
      Print("[EA|FULL|SESSION] ERROR no-selection marker cleanup failed",
            " | case=", OpportunityCaseId(), " | reason=", reason,
            " | err=", GetLastError(), " | archive_touched=0");
      return false;
     }
   if(ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION) >= 0)
      return false;
   opportunityExplicitNoSelection = false;

   string requiredNames[];
   ArrayResize(requiredNames, 11);
   requiredNames[0] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "v4";
   requiredNames[1] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "c_" +
                      OpportunitySessionEncodeField(OpportunityCaseId());
   requiredNames[2] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "a_" +
                      OpportunitySessionEncodeField(OpportunityCaseType());
   requiredNames[3] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "r_" +
                      OpportunitySessionEncodeField(opportunityArchivedCaseType);
   requiredNames[4] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "d_" +
                      IntegerToString((int)opportunityCaseTypeDirty);
   requiredNames[5] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "s_" +
                      OpportunitySessionEncodeField(opportunityAnnotationNativeSymbol);
   requiredNames[6] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "t_" +
                      OpportunitySessionEncodeField(opportunityAnnotationNativeTimeframe);
   requiredNames[7] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "q_" +
                      OpportunitySessionEncodeField(opportunityActiveStandardity);
   requiredNames[8] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "p_" +
                      OpportunitySessionEncodeField(opportunityArchivedStandardity);
   requiredNames[9] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "g_" +
                      IntegerToString((int)opportunityStandardityDirty);
   requiredNames[10] = OPPORTUNITY_SESSION_OBJECT_PREFIX + "y_" +
                       IntegerToString(fullWorkYear);

   int markersReady = 0;
   int markerError = 0;
   string failedMarker = "";
   for(int i = 0; i < ArraySize(requiredNames); i++)
     {
      int currentError = 0;
      if(CreateOpportunitySessionMarker(chartID, requiredNames[i], currentError))
         markersReady++;
      else if(StringLen(failedMarker) == 0)
        {
         failedMarker = requiredNames[i];
         markerError = currentError;
        }
     }
   if(markersReady != ArraySize(requiredNames))
     {
      Print("[EA|FULL|SESSION] ERROR marker save failed | case=", OpportunityCaseId(),
            " | reason=", reason, " | markers=", markersReady, "/",
            ArraySize(requiredNames), " | failed=", failedMarker,
            " | err=", markerError);
      return false;
     }

   int staleDeleted = 0;
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OPPORTUNITY_SESSION_OBJECT_PREFIX) != 0 ||
         OpportunitySessionNameIsRequired(objectName, requiredNames)) continue;
      if(ObjectDelete(chartID, objectName)) staleDeleted++;
     }
   if(ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY) >= 0 &&
      ObjectDelete(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY))
      staleDeleted++;

   Print("[EA|FULL|SESSION] INFO state saved | reason=", reason,
         " | format=", OPPORTUNITY_SESSION_STATE_VERSION,
         " | case=", OpportunityCaseId(),
         " | active_type=", OpportunityCaseType(),
         " | archived_type=", opportunityArchivedCaseType,
         " | dirty=", (int)opportunityCaseTypeDirty,
         " | standardity=", opportunityActiveStandardity,
         " | archived_standardity=", opportunityArchivedStandardity,
         " | standardity_dirty=", (int)opportunityStandardityDirty,
          " | native=", opportunityAnnotationNativeSymbol, "/",
          opportunityAnnotationNativeTimeframe,
          " | work_year=", fullWorkYear,
          " | markers=", markersReady,
         " | stale_deleted=", staleDeleted,
         " | archive_touched=0");
   return true;
  }

bool RestoreOpportunitySessionState(long chartID)
  {
   opportunitySessionStateRestored = false;
   opportunitySessionWorkYear = 0;
   opportunityExplicitNoSelection = false;
   bool explicitNoSelection =
      (chartID != 0 &&
       ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION) >= 0);
   if(explicitNoSelection)
     {
      int conflictingMarkers = CountOpportunitySessionMarkers(chartID);
      if(conflictingMarkers != 0)
        {
         ObjectDelete(chartID, OBJ_FULL_OPPORTUNITY_NO_SELECTION);
         DeleteOpportunitySessionMarkers(chartID);
         Print("[EA|FULL|SESSION] WARN conflicting no-selection state discarded",
               " | markers=", conflictingMarkers,
               " | archive_touched=0");
         return false;
        }
      opportunityActiveCaseId = "";
      opportunityActiveCaseType = "UNSELECTED";
      opportunityArchivedCaseType = "";
      opportunityCaseTypeDirty = false;
      opportunityActiveStandardity = "UNREVIEWED";
      opportunityArchivedStandardity = "UNREVIEWED";
      opportunityStandardityDirty = false;
      opportunityAnnotationNativeSymbol = "";
      opportunityAnnotationNativeTimeframe = "";
      opportunitySessionWorkYear = fullWorkYear;
      opportunitySessionStateRestored = true;
      opportunityExplicitNoSelection = true;
      Print("[EA|FULL|SESSION] INFO explicit no-selection state restored",
            " | work_year=", fullWorkYear, " | archive_touched=0");
      return true;
     }
   string versionMarkerV4 = OPPORTUNITY_SESSION_OBJECT_PREFIX + "v4";
   string versionMarkerV3 = OPPORTUNITY_SESSION_OBJECT_PREFIX + "v3";
   string versionMarkerV2 = OPPORTUNITY_SESSION_OBJECT_PREFIX + "v2";
   bool hasV4 = (chartID != 0 && ObjectFind(chartID, versionMarkerV4) >= 0);
   bool hasV3 = (chartID != 0 && ObjectFind(chartID, versionMarkerV3) >= 0);
   bool hasV2 = (chartID != 0 && ObjectFind(chartID, versionMarkerV2) >= 0);
   if(chartID == 0 || (!hasV4 && !hasV3 && !hasV2))
     {
      bool legacyPresent =
         (chartID != 0 && ObjectFind(chartID, OBJ_FULL_OPPORTUNITY_SESSION_STATE_LEGACY) >= 0);
      int discarded = legacyPresent ? DeleteOpportunitySessionMarkers(chartID) : 0;
       Print("[EA|FULL|SESSION] INFO marker state unavailable | default_case_enabled=",
             (int)InpOpenDefaultCaseOnStartup,
             " | configured_case=", OpportunityCsvSafe(InpAnnotationCaseId),
             " | active_case=", OpportunityCaseId(),
             " | legacy_present=", (int)legacyPresent,
             " | discarded=", discarded, " | archive_touched=0");
      return false;
     }

   string caseId = "";
   string activeType = "";
   string archivedType = "";
   string dirtyText = "";
   string nativeSymbol = "";
   string nativeTimeframe = "";
   string activeStandardity = "UNREVIEWED";
   string archivedStandardity = "UNREVIEWED";
   string standardityDirtyText = "0";
   string workYearText = IntegerToString(fullWorkYear);
   int caseMatches = 0;
   int activeMatches = 0;
   int archivedMatches = 0;
   int dirtyMatches = 0;
   int symbolMatches = 0;
   int timeframeMatches = 0;
   bool hasStandardityMarkers = (hasV4 || hasV3);
   int activeStandardityMatches = hasStandardityMarkers ? 0 : 1;
   int archivedStandardityMatches = hasStandardityMarkers ? 0 : 1;
   int standardityDirtyMatches = hasStandardityMarkers ? 0 : 1;
   int workYearMatches = hasV4 ? 0 : 1;
   bool markersOK = true;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "c_", caseId, caseMatches) && markersOK;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "a_", activeType, activeMatches) && markersOK;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "r_", archivedType, archivedMatches) && markersOK;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "d_", dirtyText, dirtyMatches) && markersOK;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "s_", nativeSymbol, symbolMatches) && markersOK;
   markersOK = ReadOpportunitySessionMarker(chartID,
      OPPORTUNITY_SESSION_OBJECT_PREFIX + "t_", nativeTimeframe, timeframeMatches) && markersOK;
   if(hasStandardityMarkers)
     {
      markersOK = ReadOpportunitySessionMarker(chartID,
         OPPORTUNITY_SESSION_OBJECT_PREFIX + "q_", activeStandardity,
         activeStandardityMatches) && markersOK;
      markersOK = ReadOpportunitySessionMarker(chartID,
         OPPORTUNITY_SESSION_OBJECT_PREFIX + "p_", archivedStandardity,
         archivedStandardityMatches) && markersOK;
      markersOK = ReadOpportunitySessionMarker(chartID,
         OPPORTUNITY_SESSION_OBJECT_PREFIX + "g_", standardityDirtyText,
          standardityDirtyMatches) && markersOK;
      }
   if(hasV4)
     {
      markersOK = ReadOpportunitySessionMarker(chartID,
         OPPORTUNITY_SESSION_OBJECT_PREFIX + "y_", workYearText,
         workYearMatches) && markersOK;
     }

   bool formatOK = (markersOK && (dirtyText == "0" || dirtyText == "1") &&
                     (standardityDirtyText == "0" || standardityDirtyText == "1"));
   bool dirty = formatOK && StringToInteger(dirtyText) != 0;
   bool standardityDirty = formatOK && StringToInteger(standardityDirtyText) != 0;
   int restoredWorkYear = hasV4 ? (int)StringToInteger(workYearText) :
                                  OpportunityCaseIdYear(caseId);
   if(restoredWorkYear <= 0) restoredWorkYear = fullWorkYear;
   int configuredStartYear = InpFullStartYear;
   int configuredEndYear = InpFullEndYear;
   if(configuredStartYear > configuredEndYear)
     {
      int swapYear = configuredStartYear;
      configuredStartYear = configuredEndYear;
      configuredEndYear = swapYear;
     }
   bool stateOK = (formatOK && StringLen(caseId) > 0 &&
                   (activeType == "UNSELECTED" || IsOpportunityTypeSupported(activeType)) &&
                   (StringLen(archivedType) == 0 || IsOpportunityTypeSupported(archivedType)) &&
                   IsOpportunityStandarditySupported(activeStandardity) &&
                   IsOpportunityStandarditySupported(archivedStandardity) &&
                   ((StringLen(nativeSymbol) == 0 && StringLen(nativeTimeframe) == 0) ||
                    (StringLen(nativeSymbol) > 0 && StringLen(nativeTimeframe) > 0)) &&
                    !(activeType == "UNSELECTED" && StringLen(archivedType) > 0) &&
                    !(dirty && activeType == "UNSELECTED") &&
                    !(standardityDirty && activeType == "UNSELECTED") &&
                    restoredWorkYear >= configuredStartYear &&
                    restoredWorkYear <= configuredEndYear &&
                    (OpportunityCaseIdYear(caseId) == 0 ||
                     OpportunityCaseIdYear(caseId) == restoredWorkYear));
   if(!stateOK)
     {
       int discarded = DeleteOpportunitySessionMarkers(chartID);
       Print("[EA|FULL|SESSION] WARN invalid marker state discarded | version=",
             hasV4 ? OPPORTUNITY_SESSION_STATE_VERSION : (hasV3 ? "V3" : "V2"),
            " | matches=", caseMatches, "/", activeMatches, "/",
            archivedMatches, "/", dirtyMatches, "/", symbolMatches, "/",
            timeframeMatches, "/", activeStandardityMatches, "/",
             archivedStandardityMatches, "/", standardityDirtyMatches,
             "/", workYearMatches,
            " | case=", caseId, " | active_type=", activeType,
            " | archived_type=", archivedType, " | dirty=", (int)dirty,
            " | standardity=", activeStandardity,
            " | archived_standardity=", archivedStandardity,
             " | standardity_dirty=", (int)standardityDirty,
             " | work_year=", restoredWorkYear,
            " | discarded=", discarded, " | err=0");
      return false;
     }

   opportunityActiveCaseId = OpportunityCsvSafe(caseId);
   opportunityActiveCaseType = OpportunityCsvSafe(activeType);
   opportunityArchivedCaseType = OpportunityCsvSafe(archivedType);
   opportunityCaseTypeDirty = dirty;
   opportunityActiveStandardity = OpportunityCsvSafe(activeStandardity);
   opportunityArchivedStandardity = OpportunityCsvSafe(archivedStandardity);
   opportunityStandardityDirty = standardityDirty;
   opportunityAnnotationNativeSymbol = OpportunityCsvSafe(nativeSymbol);
   opportunityAnnotationNativeTimeframe = OpportunityCsvSafe(nativeTimeframe);
   opportunitySessionWorkYear = restoredWorkYear;
   opportunitySessionStateRestored = true;
   Print("[EA|FULL|SESSION] INFO state restored | format=",
          hasV4 ? OPPORTUNITY_SESSION_STATE_VERSION : (hasV3 ? "V3" : "V2"),
         " | case=", OpportunityCaseId(),
         " | active_type=", OpportunityCaseType(),
         " | archived_type=", opportunityArchivedCaseType,
         " | dirty=", (int)opportunityCaseTypeDirty,
         " | standardity=", opportunityActiveStandardity,
         " | archived_standardity=", opportunityArchivedStandardity,
         " | standardity_dirty=", (int)opportunityStandardityDirty,
          " | native=", opportunityAnnotationNativeSymbol, "/",
          opportunityAnnotationNativeTimeframe,
          " | work_year=", opportunitySessionWorkYear,
         " | matches=", caseMatches, "/", activeMatches, "/",
         archivedMatches, "/", dirtyMatches, "/", symbolMatches, "/",
         timeframeMatches, "/", activeStandardityMatches, "/",
          archivedStandardityMatches, "/", standardityDirtyMatches,
          "/", workYearMatches,
          " | upgraded_from_v3=", (int)(!hasV4 && hasV3),
          " | upgraded_from_v2=", (int)(!hasV4 && !hasV3 && hasV2),
         " | archive_touched=0");
   return true;
  }

void RefreshOpportunityAnnotationReadOnly(long chartID)
  {
   opportunityAnnotationReadOnly = false;
   if(StringLen(opportunityAnnotationNativeSymbol) == 0 ||
      StringLen(opportunityAnnotationNativeTimeframe) == 0) return;
   opportunityAnnotationReadOnly =
      (opportunityAnnotationNativeSymbol != ChartSymbol(chartID) ||
       opportunityAnnotationNativeTimeframe !=
       TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)));
  }

int CountOpportunityCasesForYear(int year)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
      if(opportunityCaseCatalog[i].year == year) count++;
   return count;
  }

int CountOpportunityCasesForYearType(int year, string caseType)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
      if(opportunityCaseCatalog[i].year == year &&
         opportunityCaseCatalog[i].caseType == caseType) count++;
   return count;
  }

string OpportunityCaseCatalogDisplayText(int index)
  {
   if(index < 0 || index >= ArraySize(opportunityCaseCatalog)) return "机会 | 无可用档案";
   int annualSequence = OpportunityCaseAnnualSequence(
                           opportunityCaseCatalog[index].caseId);
   string sequenceText = annualSequence > 0 ?
                         StringFormat("%03d", annualSequence) : "???";
   return "机会 " + sequenceText + " | " +
          OpportunityCaseTypeDisplayName(opportunityCaseCatalog[index].caseType) +
          " | " + opportunityCaseCatalog[index].timeframe + " | " +
          OpportunityStandardityDisplayName(opportunityCaseCatalog[index].standardity);
  }

void UpdateOpportunityCaseSelectorButton()
  {
   if(ObjectFind(0, OBJ_FULL_BTN_CASE_SELECTOR) < 0) return;
   int totalCaseCount = ArraySize(opportunityCaseCatalog);
   int currentYearCaseCount = CountOpportunityCasesForYear(fullWorkYear);
   string buttonText = "案例 | 本年 " + IntegerToString(currentYearCaseCount) +
                       " | 总计 " + IntegerToString(totalCaseCount);
   string tooltipText = "当前年份 " + IntegerToString(fullWorkYear) + "：" +
                        IntegerToString(currentYearCaseCount) +
                        " 个 | 全部年份：" + IntegerToString(totalCaseCount) + " 个";
   color buttonColor = (opportunityCaseCatalogReady && totalCaseCount > 0) ?
                       clrDarkGreen : clrDimGray;
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_TEXT, buttonText);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_TOOLTIP, tooltipText);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_BGCOLOR, buttonColor);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_STATE, false);
  }

void UpdateOpportunityCaseSearchButtons()
  {
   int activeIndex = FindOpportunityCaseCatalogIndex(OpportunityCaseId());
   if(opportunityCaseSearchYear <= 0)
     {
      opportunityCaseSearchYear = activeIndex >= 0 ?
                                  opportunityCaseCatalog[activeIndex].year :
                                  fullWorkYear;
      opportunityCaseSearchCaseId = activeIndex >= 0 ?
                                    opportunityCaseCatalog[activeIndex].caseId : "";
     }

   int selectedIndex = FindOpportunityCaseCatalogIndex(opportunityCaseSearchCaseId);
   if(selectedIndex < 0)
     {
      opportunityCaseSearchCaseId = "";
     }
   else if(opportunityCaseCatalog[selectedIndex].year != opportunityCaseSearchYear)
     {
      opportunityCaseSearchCaseId = "";
      selectedIndex = -1;
     }

   int yearCaseCount = CountOpportunityCasesForYear(opportunityCaseSearchYear);
   if(ObjectFind(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR) >= 0)
     {
      string yearText = opportunityCaseSearchYear > 0 ?
                        IntegerToString(opportunityCaseSearchYear) : "暂无";
      ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_TEXT,
                      "年份 | " + yearText);
      ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_TOOLTIP,
                      "案例搜索年份 | 已保存机会 " +
                      IntegerToString(yearCaseCount) + " 个 | archive_touched=0");
      ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_BGCOLOR,
                       opportunityCaseCatalogReady && yearCaseCount > 0 ?
                       clrDarkGreen : clrDimGray);
      ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_STATE, false);
     }

   if(ObjectFind(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY) < 0) return;
   string opportunityText = "交易机会 | 请选择";
   string opportunityTooltip = "选择当前搜索年份下的交易机会；只读重载";
   color opportunityColor = clrDarkSlateGray;
   if(!opportunityCaseCatalogReady)
     {
      opportunityText = "交易机会 | 不可用";
      opportunityColor = clrDimGray;
     }
   else if(yearCaseCount <= 0)
     {
      opportunityText = "交易机会 | 暂无";
      opportunityColor = clrDimGray;
     }
   else if(selectedIndex >= 0)
     {
      int annualSequence = OpportunityCaseAnnualSequence(
                              opportunityCaseCatalog[selectedIndex].caseId);
      opportunityText = "交易机会 | " + StringFormat("%03d", annualSequence) +
                        " / " + IntegerToString(yearCaseCount);
      opportunityTooltip = opportunityCaseCatalog[selectedIndex].caseCode +
                           " | archive_id=" +
                           opportunityCaseCatalog[selectedIndex].caseId +
                           " | READ-ONLY RELOAD";
      opportunityColor = clrDarkGreen;
     }
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, OBJPROP_TEXT,
                   opportunityText);
   ObjectSetString(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, OBJPROP_TOOLTIP,
                   opportunityTooltip);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, OBJPROP_BGCOLOR,
                    opportunityColor);
   ObjectSetInteger(0, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY, OBJPROP_STATE, false);
  }

void SetOpportunityCaseDirectSearchInputState(string objectName,
                                              bool valid,
                                              string tooltipText)
  {
   if(ObjectFind(0, objectName) < 0) return;
   ObjectSetInteger(0, objectName, OBJPROP_BGCOLOR,
                    valid ? clrWhite : C'255,215,215');
   ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, objectName, OBJPROP_BORDER_COLOR,
                    valid ? clrDimGray : clrFireBrick);
   ObjectSetString(0, objectName, OBJPROP_TOOLTIP, tooltipText);
  }

bool OpportunityCaseDirectSearchPositiveInteger(string value)
  {
   int length = StringLen(value);
   if(length <= 0) return false;
   for(int i = 0; i < length; i++)
     {
      ushort character = StringGetCharacter(value, i);
      if(character < 48 || character > 57) return false;
     }
   return StringToInteger(value) > 0;
  }

int FindOpportunityCaseCatalogIndexByYearSequence(int year, int annualSequence)
  {
   if(year <= 0 || annualSequence <= 0) return -1;
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
      if(opportunityCaseCatalog[i].year == year &&
         OpportunityCaseAnnualSequence(opportunityCaseCatalog[i].caseId) == annualSequence)
         return i;
   return -1;
  }

bool HandleOpportunityCaseDirectSearch(long chartID, string objectName)
  {
   if(objectName != OBJ_FULL_EDIT_CASE_DIRECT_YEAR &&
      objectName != OBJ_FULL_EDIT_CASE_DIRECT_NUMBER)
      return false;

   CloseFullWorkYearMenu(chartID);
   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);

   string yearText = ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                     OBJPROP_TEXT);
   string sequenceText = ObjectGetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                         OBJPROP_TEXT);
   StringTrimLeft(yearText);
   StringTrimRight(yearText);
   StringTrimLeft(sequenceText);
   StringTrimRight(sequenceText);
   ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_YEAR, OBJPROP_TEXT, yearText);
   ObjectSetString(chartID, OBJ_FULL_EDIT_CASE_DIRECT_NUMBER, OBJPROP_TEXT,
                   sequenceText);

   string yearTooltip = "输入年份，例如 2002；两项填写后按 Enter";
   string sequenceTooltip = "输入年内机会编号，例如 5 或 005；按 Enter 直接加载";
   SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                            true, yearTooltip);
   SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                            true, sequenceTooltip);
   if(StringLen(yearText) == 0 || StringLen(sequenceText) == 0) return true;

   bool yearFormatOK = OpportunityCaseDirectSearchPositiveInteger(yearText) &&
                       StringLen(yearText) == 4;
   long yearValue = yearFormatOK ? StringToInteger(yearText) : 0;
   if(!yearFormatOK || yearValue < 1900 || yearValue > 2100)
     {
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                               false,
                                               "请输入 1900-2100 之间的四位年份");
      Print("[EA|FULL|CASE] WARN direct search rejected | reason=invalid_year",
            " | year_text=", yearText, " | archive_touched=0");
      return true;
     }

   bool sequenceFormatOK = OpportunityCaseDirectSearchPositiveInteger(sequenceText);
   long sequenceValue = sequenceFormatOK ? StringToInteger(sequenceText) : 0;
   if(!sequenceFormatOK || sequenceValue > 2147483647)
     {
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                               false,
                                               "请输入大于 0 的交易机会编号");
      Print("[EA|FULL|CASE] WARN direct search rejected | reason=invalid_sequence",
            " | sequence_text=", sequenceText, " | archive_touched=0");
      return true;
     }

   int targetYear = (int)yearValue;
   int targetSequence = (int)sequenceValue;
   if(!LoadOpportunityCaseCatalog(chartID))
     {
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                               false, "正式案例档案不可用");
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                               false, "正式案例档案不可用");
      Print("[EA|FULL|CASE] ERROR direct search failed | reason=catalog_unavailable",
            " | year=", targetYear, " | sequence=", targetSequence,
            " | archive_touched=0");
      return true;
     }

   int yearCaseCount = CountOpportunityCasesForYear(targetYear);
   if(yearCaseCount <= 0)
     {
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                               false,
                                               "该年份没有正式交易机会档案");
      Print("[EA|FULL|CASE] INFO direct search no result | reason=year_not_found",
            " | year=", targetYear, " | sequence=", targetSequence,
            " | archive_touched=0");
      return true;
     }

   int targetIndex = FindOpportunityCaseCatalogIndexByYearSequence(targetYear,
                                                                   targetSequence);
   if(targetIndex < 0)
     {
      SetOpportunityCaseDirectSearchInputState(
         OBJ_FULL_EDIT_CASE_DIRECT_NUMBER, false,
         IntegerToString(targetYear) + " 年没有第 " +
         IntegerToString(targetSequence) + " 号交易机会");
      Print("[EA|FULL|CASE] INFO direct search no result | reason=sequence_not_found",
            " | year=", targetYear, " | sequence=", targetSequence,
            " | year_cases=", yearCaseCount, " | archive_touched=0");
      return true;
     }

   string targetCaseId = opportunityCaseCatalog[targetIndex].caseId;
   Print("[EA|FULL|CASE] INFO direct search submitted | year=", targetYear,
         " | sequence=", targetSequence, " | case=", targetCaseId,
         " | archive_touched=0");
   if(!SwitchOpportunityCase(chartID, targetIndex))
     {
      SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                               false,
                                               "案例加载失败；原案例保持不变");
      Print("[EA|FULL|CASE] ERROR direct search result | loaded=0 | year=",
            targetYear, " | sequence=", targetSequence,
            " | case=", targetCaseId, " | archive_touched=0");
      return true;
     }

   opportunityCaseSearchYear = targetYear;
   opportunityCaseSearchCaseId = targetCaseId;
   UpdateOpportunityCaseSearchButtons();
   SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_YEAR,
                                            true,
                                            "已加载 " + IntegerToString(targetYear) +
                                            " 年第 " + IntegerToString(targetSequence) +
                                            " 号交易机会");
   SetOpportunityCaseDirectSearchInputState(OBJ_FULL_EDIT_CASE_DIRECT_NUMBER,
                                            true,
                                            "已加载 " + targetCaseId);
   Print("[EA|FULL|CASE] INFO direct search result | loaded=1 | year=",
         targetYear, " | sequence=", targetSequence,
         " | case=", targetCaseId, " | archive_touched=0");
   return true;
  }

bool LoadOpportunityCaseRecords()
  {
   ResetLastError();
   int handle = FileOpen(InpOpportunityCasesCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|CASE] ERROR case catalog unavailable | path=", InpOpportunityCasesCsvPath,
            " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int invalidRows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0 || StringFind(line, "case_id,") == 0) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 19 || StringLen(fields[0]) == 0 || StringLen(fields[1]) == 0 ||
         StringLen(fields[2]) == 0 || StringLen(fields[3]) == 0)
        {
         invalidRows++;
         continue;
        }
      if(FindOpportunityCaseCatalogIndex(fields[0]) >= 0)
        {
         Print("[EA|FULL|CASE] ERROR duplicate case record | case=", fields[0]);
         invalidRows++;
         continue;
        }

      int index = ArraySize(opportunityCaseCatalog);
      ArrayResize(opportunityCaseCatalog, index + 1);
      opportunityCaseCatalog[index].caseId = fields[0];
      opportunityCaseCatalog[index].caseType = fields[1];
      opportunityCaseCatalog[index].symbol = fields[2];
      opportunityCaseCatalog[index].timeframe = fields[3];
      opportunityCaseCatalog[index].status = fields[4];
      opportunityCaseCatalog[index].formationStart = StringToTime(fields[5]);
      opportunityCaseCatalog[index].readyTime = StringToTime(fields[6]);
      opportunityCaseCatalog[index].pivotCount = (int)StringToInteger(fields[7]);
      opportunityCaseCatalog[index].upperCount = (int)StringToInteger(fields[8]);
      opportunityCaseCatalog[index].lowerCount = (int)StringToInteger(fields[9]);
      opportunityCaseCatalog[index].timeOrderRule = fields[10];
      opportunityCaseCatalog[index].alternationRule = fields[11];
      opportunityCaseCatalog[index].progressionRule = fields[12];
      opportunityCaseCatalog[index].upperDirectionRule = fields[13];
      opportunityCaseCatalog[index].lowerDirectionRule = fields[14];
      opportunityCaseCatalog[index].parallelRule = fields[15];
      opportunityCaseCatalog[index].ruleStatus = fields[16];
      opportunityCaseCatalog[index].futureOutcome = fields[17];
      opportunityCaseCatalog[index].updatedAt = fields[18];
      opportunityCaseCatalog[index].regionStart = 0;
      opportunityCaseCatalog[index].regionEnd = 0;
      opportunityCaseCatalog[index].accumulationStart = 0;
      opportunityCaseCatalog[index].accumulationEnd = 0;
      opportunityCaseCatalog[index].accumulationDurationHours = 0.0;
      opportunityCaseCatalog[index].accumulationH1Bars = 0;
      opportunityCaseCatalog[index].opportunityLevel = "UNCLASSIFIED";
      opportunityCaseCatalog[index].caseCode = "";
      opportunityCaseCatalog[index].standardity = "UNREVIEWED";
      opportunityCaseCatalog[index].standardityConfirmed = false;
      if(fieldCount >= 24)
        {
         opportunityCaseCatalog[index].opportunityLevel = fields[19];
         opportunityCaseCatalog[index].accumulationStart = StringToTime(fields[20]);
         opportunityCaseCatalog[index].accumulationEnd = StringToTime(fields[21]);
         opportunityCaseCatalog[index].accumulationDurationHours = StringToDouble(fields[22]);
         opportunityCaseCatalog[index].caseCode = fields[23];
        }
      if(fieldCount >= 25)
         opportunityCaseCatalog[index].accumulationH1Bars = (int)StringToInteger(fields[24]);
      if(fieldCount >= 27 && IsOpportunityStandarditySupported(fields[25]))
        {
         opportunityCaseCatalog[index].standardityConfirmed =
            (StringToInteger(fields[26]) != 0 && fields[25] != "UNREVIEWED");
         opportunityCaseCatalog[index].standardity =
            opportunityCaseCatalog[index].standardityConfirmed ?
            fields[25] : "UNREVIEWED";
        }
      opportunityCaseCatalog[index].sortTime = 0;
      opportunityCaseCatalog[index].year = 0;
      opportunityCaseCatalog[index].typeSequence = 0;
      opportunityCaseCatalog[index].structureCount = 0;
      opportunityCaseCatalog[index].lineCount = 0;
      opportunityCaseCatalog[index].keyBarCount = 0;
      opportunityCaseCatalog[index].drawingCount = 0;
      opportunityCaseCatalog[index].regionCount = 0;
      opportunityCaseCatalog[index].annotationComplete = false;
     }
   FileClose(handle);
   if(invalidRows > 0)
     {
      Print("[EA|FULL|CASE] ERROR invalid case catalog rows | invalid=", invalidRows,
            " | path=", InpOpportunityCasesCsvPath);
      return false;
     }
   return true;
  }

bool AccumulateOpportunityCaseArchive(string path, string archiveKind)
  {
   ResetLastError();
   int handle = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|CASE] ERROR archive unavailable while building catalog | kind=", archiveKind,
            " | path=", path, " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int orphanRows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0 || StringFind(line, "case_id,") == 0) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 3) continue;
      int index = FindOpportunityCaseCatalogIndex(fields[0]);
      if(index < 0)
        {
         orphanRows++;
         continue;
        }

      if(archiveKind == "ANCHORS")
        {
         if(fieldCount < 22) continue;
         int sequence = (int)StringToInteger(fields[4]);
         datetime centerTime = StringToTime(fields[7]);
         double centerPrice = StringToDouble(fields[8]);
         if(sequence <= 0 || centerTime <= 0 || centerPrice <= 0.0) continue;
         if(fields[2] == "STRUCT") opportunityCaseCatalog[index].structureCount++;
         else if(fields[2] == "LINE") opportunityCaseCatalog[index].lineCount++;
        }
      else if(archiveKind == "KEY_BARS")
        {
         if(fieldCount < 17) continue;
         int sequence = (int)StringToInteger(fields[3]);
         datetime barTime = StringToTime(fields[6]);
         datetime confirmTime = StringToTime(fields[7]);
         if(sequence > 0 && barTime > 0 && confirmTime > barTime)
            opportunityCaseCatalog[index].keyBarCount++;
        }
      else if(archiveKind == "DRAWINGS")
        {
         if(fieldCount < 31) continue;
         ENUM_OBJECT objectType = (ENUM_OBJECT)StringToInteger(fields[4]);
         int anchorCount = (int)StringToInteger(fields[6]);
         if(StringLen(fields[2]) > 0 && anchorCount > 0 &&
            anchorCount == OpportunityDrawingAnchorCount(objectType))
            opportunityCaseCatalog[index].drawingCount++;
        }
      else if(archiveKind == "REGIONS")
        {
         if(fieldCount < 12) continue;
         datetime startTime = StringToTime(fields[9]);
         datetime endTime = StringToTime(fields[10]);
         if(StringLen(fields[2]) == 0 || StringLen(fields[3]) == 0 ||
            StringLen(fields[4]) == 0 || startTime <= 0 || endTime <= startTime) continue;
          opportunityCaseCatalog[index].regionCount++;
          if(fields[2] == "R1") opportunityCaseCatalog[index].regionStart = startTime;
          if(fields[2] == "R2")
            {
             opportunityCaseCatalog[index].accumulationStart = startTime;
             opportunityCaseCatalog[index].accumulationEnd = endTime;
            }
          if(fields[2] == "R3") opportunityCaseCatalog[index].regionEnd = endTime;
        }
     }
   FileClose(handle);
   if(orphanRows > 0)
      Print("[EA|FULL|CASE] WARN orphan archive rows ignored | kind=", archiveKind,
            " | rows=", orphanRows, " | path=", path);
   return true;
  }

bool OpportunityCaseCatalogComesAfter(OpportunityCaseCatalogEntry &left,
                                      OpportunityCaseCatalogEntry &right)
  {
   if(left.year != right.year) return left.year > right.year;
   int typeCompare = StringCompare(left.caseType, right.caseType);
   if(typeCompare != 0) return typeCompare > 0;
   if(left.sortTime != right.sortTime) return left.sortTime > right.sortTime;
   return StringCompare(left.caseId, right.caseId) > 0;
  }

void FinalizeOpportunityCaseCatalog()
  {
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      long durationSeconds = 0;
      int effectiveH1Bars = 0;
      if(opportunityCaseCatalog[i].accumulationStart > 0 &&
         opportunityCaseCatalog[i].accumulationEnd >
         opportunityCaseCatalog[i].accumulationStart)
        {
         opportunityCaseCatalog[i].opportunityLevel =
            OpportunityLevelFromAccumulationRange(opportunityCaseCatalog[i].symbol,
                                                  opportunityCaseCatalog[i].accumulationStart,
                                                  opportunityCaseCatalog[i].accumulationEnd,
                                                  durationSeconds,
                                                  effectiveH1Bars);
         opportunityCaseCatalog[i].accumulationDurationHours =
            (double)durationSeconds / 3600.0;
         opportunityCaseCatalog[i].accumulationH1Bars = effectiveH1Bars;
         if(opportunityCaseCatalog[i].opportunityLevel == "UNCLASSIFIED")
            Print("[EA|FULL|CASE] WARN accumulation H1 width exceeds defined levels or is unavailable | case=",
                  opportunityCaseCatalog[i].caseId,
                  " | start=", TimeToString(opportunityCaseCatalog[i].accumulationStart,
                                             TIME_DATE|TIME_MINUTES),
                  " | end=", TimeToString(opportunityCaseCatalog[i].accumulationEnd,
                                           TIME_DATE|TIME_MINUTES),
                  " | duration_hours=",
                  DoubleToString(opportunityCaseCatalog[i].accumulationDurationHours, 1),
                  " | h1_bars=", opportunityCaseCatalog[i].accumulationH1Bars);
        }
      else
        {
         opportunityCaseCatalog[i].opportunityLevel = "UNCLASSIFIED";
         opportunityCaseCatalog[i].accumulationDurationHours = 0.0;
         opportunityCaseCatalog[i].accumulationH1Bars = 0;
        }
      opportunityCaseCatalog[i].caseCode =
         BuildOpportunityCaseCode(opportunityCaseCatalog[i].caseId,
                                  opportunityCaseCatalog[i].opportunityLevel);

      datetime referenceTime = opportunityCaseCatalog[i].formationStart;
      if(opportunityCaseCatalog[i].regionCount == OPPORTUNITY_REGION_COUNT &&
         opportunityCaseCatalog[i].regionStart > 0 && opportunityCaseCatalog[i].regionEnd > opportunityCaseCatalog[i].regionStart)
         referenceTime = opportunityCaseCatalog[i].regionStart;
      else if(referenceTime <= 0)
         referenceTime = opportunityCaseCatalog[i].readyTime;
      opportunityCaseCatalog[i].sortTime = referenceTime;
      MqlDateTime parts;
      if(referenceTime > 0 && TimeToStruct(referenceTime, parts))
         opportunityCaseCatalog[i].year = parts.year;
      opportunityCaseCatalog[i].annotationComplete =
         (opportunityCaseCatalog[i].structureCount > 0 &&
          opportunityCaseCatalog[i].keyBarCount > 0 &&
          opportunityCaseCatalog[i].drawingCount > 0 &&
          opportunityCaseCatalog[i].regionCount == OPPORTUNITY_REGION_COUNT);
     }

   for(int i = 1; i < ArraySize(opportunityCaseCatalog); i++)
     {
      OpportunityCaseCatalogEntry current = opportunityCaseCatalog[i];
      int j = i - 1;
      while(j >= 0 && OpportunityCaseCatalogComesAfter(opportunityCaseCatalog[j], current))
        {
         opportunityCaseCatalog[j + 1] = opportunityCaseCatalog[j];
         j--;
        }
      opportunityCaseCatalog[j + 1] = current;
     }

   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      int sequence = 1;
      for(int j = 0; j < i; j++)
         if(opportunityCaseCatalog[j].year == opportunityCaseCatalog[i].year &&
            opportunityCaseCatalog[j].caseType == opportunityCaseCatalog[i].caseType)
            sequence++;
      opportunityCaseCatalog[i].typeSequence = sequence;
     }
  }

bool LoadOpportunityCaseCatalog(long chartID)
  {
   CloseOpportunityCaseMenu(chartID);
   CM_DeleteModuleInvalidateEligibility();
   ArrayResize(opportunityCaseCatalog, 0);
   opportunityCaseCatalogReady = false;
   bool casesOK = LoadOpportunityCaseRecords();
   bool anchorsOK = casesOK && AccumulateOpportunityCaseArchive(InpOpportunityAnchorsCsvPath, "ANCHORS");
   bool keyBarsOK = casesOK && AccumulateOpportunityCaseArchive(InpOpportunityKeyBarsCsvPath, "KEY_BARS");
   bool drawingsOK = casesOK && AccumulateOpportunityCaseArchive(InpOpportunityDrawingsCsvPath, "DRAWINGS");
   bool regionsOK = casesOK && AccumulateOpportunityCaseArchive(InpOpportunityRegionsCsvPath, "REGIONS");
   opportunityCaseCatalogReady = (casesOK && anchorsOK && keyBarsOK && drawingsOK && regionsOK);
   if(opportunityCaseCatalogReady) FinalizeOpportunityCaseCatalog();

   int activeIndex = FindOpportunityCaseCatalogIndex(OpportunityCaseId());
   if(activeIndex >= 0)
     {
      opportunityArchivedCaseType = opportunityCaseCatalog[activeIndex].caseType;
      if(!opportunityCaseTypeDirty)
         opportunityActiveCaseType = opportunityArchivedCaseType;
      opportunityArchivedStandardity = opportunityCaseCatalog[activeIndex].standardity;
      if(!opportunityStandardityDirty)
         opportunityActiveStandardity = opportunityArchivedStandardity;
     }
   UpdateOpportunityCaseSelectorButton();
   UpdateOpportunityCaseSearchButtons();
   CM_DeleteModuleUpdateButton(ChartID());
   Print("[EA|FULL|CASE] INFO catalog loaded | ready=", (int)opportunityCaseCatalogReady,
         " | cases=", ArraySize(opportunityCaseCatalog),
         " | active=", OpportunityCaseId(),
         " | chart=", ChartSymbol(chartID), "/", TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)));
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
       Print("[EA|FULL|CASE] INFO catalog entry | case=", opportunityCaseCatalog[i].caseId,
             " | code=", opportunityCaseCatalog[i].caseCode,
             " | type=", opportunityCaseCatalog[i].caseType,
             " | standardity=", opportunityCaseCatalog[i].standardity,
             " | standardity_confirmed=",
             (int)opportunityCaseCatalog[i].standardityConfirmed,
             " | opportunity_level=", opportunityCaseCatalog[i].opportunityLevel,
             " | accumulation=",
             TimeToString(opportunityCaseCatalog[i].accumulationStart, TIME_DATE|TIME_MINUTES),
             "..", TimeToString(opportunityCaseCatalog[i].accumulationEnd,
                                 TIME_DATE|TIME_MINUTES),
             " | duration_hours=",
             DoubleToString(opportunityCaseCatalog[i].accumulationDurationHours, 1),
             " | h1_bars=", opportunityCaseCatalog[i].accumulationH1Bars,
             " | year=", opportunityCaseCatalog[i].year,
            " | sequence=", opportunityCaseCatalog[i].typeSequence,
            " | structures=", opportunityCaseCatalog[i].structureCount,
            " | lines=", opportunityCaseCatalog[i].lineCount,
            " | key_bars=", opportunityCaseCatalog[i].keyBarCount,
            " | drawings=", opportunityCaseCatalog[i].drawingCount,
            " | regions=", opportunityCaseCatalog[i].regionCount,
            " | complete=", (int)opportunityCaseCatalog[i].annotationComplete);
   return opportunityCaseCatalogReady;
  }

void SetOpportunityCaseFeedback(string statusText, uint durationMs)
  {
   opportunityCaseFeedbackStatus = statusText;
   opportunityCaseFeedbackStartedTick = GetTickCount();
   opportunityCaseFeedbackDurationMs = durationMs;
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(0);
  }

void RefreshOpportunityCaseFeedback()
  {
   if(StringLen(opportunityCaseFeedbackStatus) == 0 || opportunityCaseFeedbackDurationMs == 0) return;
   if((uint)(GetTickCount() - opportunityCaseFeedbackStartedTick) < opportunityCaseFeedbackDurationMs) return;
   opportunityCaseFeedbackStatus = "";
   opportunityCaseFeedbackStartedTick = 0;
   opportunityCaseFeedbackDurationMs = 0;
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(0);
  }

void UpdateFullWorkYearButton()
  {
   if(ObjectFind(0, OBJ_FULL_BTN_WORK_YEAR) < 0) return;
   ObjectSetString(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_TEXT,
                   "年份 | " + IntegerToString(fullWorkYear));
   ObjectSetInteger(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_BGCOLOR, clrDarkGreen);
   ObjectSetInteger(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_STATE, false);
   ObjectSetString(0, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_TOOLTIP,
                   "当前工作年份=" + IntegerToString(fullWorkYear) +
                   " | symbol=" + FullSymbolName() +
                   " | archive_touched=0");
  }

void CloseFullWorkYearMenu(long chartID)
  {
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OBJ_FULL_WORK_YEAR_OPTION_PREFIX) == 0)
         ObjectDelete(chartID, objectName);
     }
   if(ObjectFind(chartID, OBJ_FULL_BTN_WORK_YEAR) >= 0)
      ObjectSetInteger(chartID, OBJ_FULL_BTN_WORK_YEAR, OBJPROP_STATE, false);
   fullWorkYearMenuOpen = false;
   fullWorkYearMenuOpenedTick = 0;
  }

void OpenFullWorkYearMenu(long chartID)
  {
   CloseFullWorkYearMenu(chartID);
   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);
   int startYear = InpFullStartYear;
   int endYear = InpFullEndYear;
   if(startYear > endYear)
     {
      int swapYear = startYear;
      startYear = endYear;
      endYear = swapYear;
     }
   int optionIndex = 0;
   for(int year = startYear; year <= endYear; year++)
     {
      string objectName = OBJ_FULL_WORK_YEAR_OPTION_PREFIX + IntegerToString(year);
      string csvPath = BuildYearCsvPath(InpFullCsvPath, year);
      bool csvAvailable = FileIsExist(csvPath);
      color background = (year == fullWorkYear) ? clrDarkGreen :
                         (csvAvailable ? clrDarkSlateGray : clrFireBrick);
      CreateButton(objectName, 12, 248 + optionIndex * 26, 314, 24,
                   "年份 | " + IntegerToString(year) + " | 案例 " +
                   IntegerToString(CountOpportunityCasesForYear(year)) + " 个" +
                   (csvAvailable ? "" : " | 缺少数据"), background);
      ObjectSetString(chartID, objectName, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP,
                      "CSV=" + csvPath + " | archive_touched=0");
      ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 1200);
      optionIndex++;
     }
   fullWorkYearMenuOpen = (optionIndex > 0);
   fullWorkYearMenuOpenedTick = fullWorkYearMenuOpen ? GetTickCount() : 0;
   Print("[EA|FULL|YEAR] INFO menu opened | active_year=", fullWorkYear,
         " | options=", optionIndex, " | archive_touched=0");
   ChartRedraw(chartID);
  }

bool HandleFullWorkYearSelectorClick(long chartID, string objectName)
  {
   if(objectName == OBJ_FULL_BTN_WORK_YEAR)
     {
      if(fullWorkYearMenuOpen)
        {
         CloseFullWorkYearMenu(chartID);
         Print("[EA|FULL|YEAR] INFO menu closed | reason=selector_toggle");
        }
      else
         OpenFullWorkYearMenu(chartID);
      return true;
     }
   if(StringFind(objectName, OBJ_FULL_WORK_YEAR_OPTION_PREFIX) == 0)
     {
      int targetYear = (int)StringToInteger(
         StringSubstr(objectName, StringLen(OBJ_FULL_WORK_YEAR_OPTION_PREFIX)));
      CloseFullWorkYearMenu(chartID);
      if(targetYear == fullWorkYear)
        {
         Print("[EA|FULL|YEAR] INFO selection unchanged | year=", targetYear,
               " | symbol=", FullSymbolName(), " | archive_touched=0");
         UpdateFullWorkYearButton();
         return true;
        }
      bool switched = SwitchFullWorkYear(chartID, targetYear,
                                         "year_selector", "");
      if(!switched)
         SetOpportunityCaseFeedback("年份切换失败 | 检查数据与日志",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      return true;
     }
   if(fullWorkYearMenuOpen) CloseFullWorkYearMenu(chartID);
   return false;
  }

void CloseOpportunityCaseMenu(long chartID)
  {
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OBJ_FULL_CASE_OPTION_PREFIX) == 0 ||
         StringFind(objectName, OBJ_FULL_CASE_YEAR_PREFIX) == 0 ||
         StringFind(objectName, OBJ_FULL_CASE_TYPE_PREFIX) == 0 ||
         objectName == OBJ_FULL_CASE_BACK)
         ObjectDelete(chartID, objectName);
     }
   if(ObjectFind(chartID, OBJ_FULL_BTN_CASE_SELECTOR) >= 0)
      ObjectSetInteger(chartID, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_STATE, false);
   if(ObjectFind(chartID, OBJ_FULL_BTN_CASE_SEARCH_YEAR) >= 0)
      ObjectSetInteger(chartID, OBJ_FULL_BTN_CASE_SEARCH_YEAR, OBJPROP_STATE, false);
   if(ObjectFind(chartID, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY) >= 0)
      ObjectSetInteger(chartID, OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY,
                       OBJPROP_STATE, false);
   opportunityCaseMenuOpen = false;
   opportunityCaseMenuOpenedTick = 0;
   opportunityCaseMenuLevel = 0;
   opportunityCaseMenuYear = 0;
   opportunityCaseMenuType = "";
   ArrayResize(opportunityCaseMenuYears, 0);
   ArrayResize(opportunityCaseMenuTypes, 0);
   ArrayResize(opportunityCaseMenuCaseIndexes, 0);
  }

void OpenOpportunityCaseYearMenu(long chartID)
  {
   CloseOpportunityCaseMenu(chartID);
   CloseFullWorkYearMenu(chartID);
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      int year = opportunityCaseCatalog[i].year;
      if(year <= 0) continue;
      bool exists = false;
      for(int j = 0; j < ArraySize(opportunityCaseMenuYears); j++)
         if(opportunityCaseMenuYears[j] == year) exists = true;
      if(exists) continue;
      int yearIndex = ArraySize(opportunityCaseMenuYears);
      ArrayResize(opportunityCaseMenuYears, yearIndex + 1);
      opportunityCaseMenuYears[yearIndex] = year;
      }
   for(int i = 1; i < ArraySize(opportunityCaseMenuYears); i++)
     {
      int currentYear = opportunityCaseMenuYears[i];
      int j = i - 1;
      while(j >= 0 && opportunityCaseMenuYears[j] > currentYear)
        {
         opportunityCaseMenuYears[j + 1] = opportunityCaseMenuYears[j];
         j--;
        }
      opportunityCaseMenuYears[j + 1] = currentYear;
     }
   for(int i = 0; i < ArraySize(opportunityCaseMenuYears); i++)
     {
      int year = opportunityCaseMenuYears[i];
      string objectName = OBJ_FULL_CASE_YEAR_PREFIX + IntegerToString(year);
      int yearCaseCount = CountOpportunityCasesForYear(year);
      color background = (year == opportunityCaseSearchYear) ?
                         clrDarkGreen : clrDarkSlateGray;
      CreateButton(objectName, 12, 248 + i * 26, 314, 24,
                   "年份 | " + IntegerToString(year) + " | " +
                   IntegerToString(yearCaseCount) + " 个", background);
      ObjectSetString(chartID, objectName, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 1100);
     }
   opportunityCaseMenuLevel = 1;
   opportunityCaseMenuOpen = (ArraySize(opportunityCaseMenuYears) > 0);
   opportunityCaseMenuOpenedTick = opportunityCaseMenuOpen ? GetTickCount() : 0;
   Print("[EA|FULL|CASE] INFO search menu opened | level=YEAR | options=",
         ArraySize(opportunityCaseMenuYears),
         " | search_year=", opportunityCaseSearchYear,
         " | active=", OpportunityCaseId(), " | archive_touched=0");
   ChartRedraw(chartID);
  }

void OpenOpportunityCaseTypeMenu(long chartID, int year)
  {
   CloseOpportunityCaseMenu(chartID);
   opportunityCaseMenuYear = year;
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      if(opportunityCaseCatalog[i].year != year) continue;
      bool exists = false;
      for(int j = 0; j < ArraySize(opportunityCaseMenuTypes); j++)
         if(opportunityCaseMenuTypes[j] == opportunityCaseCatalog[i].caseType) exists = true;
      if(exists) continue;
      int typeIndex = ArraySize(opportunityCaseMenuTypes);
      ArrayResize(opportunityCaseMenuTypes, typeIndex + 1);
      opportunityCaseMenuTypes[typeIndex] = opportunityCaseCatalog[i].caseType;
      string objectName = OBJ_FULL_CASE_TYPE_PREFIX + IntegerToString(typeIndex);
      int typeCaseCount = CountOpportunityCasesForYearType(year,
                                                            opportunityCaseCatalog[i].caseType);
       CreateButton(objectName, 12, 276 + typeIndex * 26, 314, 24,
                   "类型 | " + OpportunityCaseTypeDisplayName(opportunityCaseCatalog[i].caseType) +
                   " | " + IntegerToString(typeCaseCount) + " 个",
                   clrDarkSlateGray);
      ObjectSetString(chartID, objectName, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 1100);
     }
   CreateButton(OBJ_FULL_CASE_BACK, 12, 248, 314, 24, "返回 | 年份", clrDimGray);
   ObjectSetString(chartID, OBJ_FULL_CASE_BACK, OBJPROP_FONT, "Microsoft YaHei");
   if(ArraySize(opportunityCaseMenuTypes) == 0)
     {
      string emptyObject = OBJ_FULL_CASE_OPTION_PREFIX + "empty";
      CreateButton(emptyObject, 12, 276, 314, 24,
                   IntegerToString(year) + " | 暂无已保存案例", clrDimGray);
      ObjectSetString(chartID, emptyObject, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetInteger(chartID, emptyObject, OBJPROP_ZORDER, 1100);
     }
   opportunityCaseMenuLevel = 2;
   opportunityCaseMenuOpen = true;
   opportunityCaseMenuOpenedTick = opportunityCaseMenuOpen ? GetTickCount() : 0;
   Print("[EA|FULL|CASE] INFO menu opened | level=TYPE | year=", year,
         " | options=", ArraySize(opportunityCaseMenuTypes));
   ChartRedraw(chartID);
  }

void OpenOpportunityCaseItemMenu(long chartID, int year)
  {
   CloseOpportunityCaseMenu(chartID);
   opportunityCaseMenuYear = year;
   opportunityCaseMenuType = "";
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      if(opportunityCaseCatalog[i].year != year) continue;
      int caseIndex = ArraySize(opportunityCaseMenuCaseIndexes);
      ArrayResize(opportunityCaseMenuCaseIndexes, caseIndex + 1);
      opportunityCaseMenuCaseIndexes[caseIndex] = i;
     }
   for(int i = 1; i < ArraySize(opportunityCaseMenuCaseIndexes); i++)
     {
      int currentIndex = opportunityCaseMenuCaseIndexes[i];
      int currentSequence = OpportunityCaseAnnualSequence(
                               opportunityCaseCatalog[currentIndex].caseId);
      if(currentSequence <= 0) currentSequence = 2147483647;
      int j = i - 1;
      while(j >= 0)
        {
         int previousIndex = opportunityCaseMenuCaseIndexes[j];
         int previousSequence = OpportunityCaseAnnualSequence(
                                  opportunityCaseCatalog[previousIndex].caseId);
         if(previousSequence <= 0) previousSequence = 2147483647;
         bool comesAfter = previousSequence > currentSequence ||
            (previousSequence == currentSequence &&
             StringCompare(opportunityCaseCatalog[previousIndex].caseId,
                           opportunityCaseCatalog[currentIndex].caseId) > 0);
         if(!comesAfter) break;
         opportunityCaseMenuCaseIndexes[j + 1] = previousIndex;
         j--;
        }
      opportunityCaseMenuCaseIndexes[j + 1] = currentIndex;
     }
   for(int menuIndex = 0;
       menuIndex < ArraySize(opportunityCaseMenuCaseIndexes);
       menuIndex++)
     {
      int catalogIndex = opportunityCaseMenuCaseIndexes[menuIndex];
      string objectName = OBJ_FULL_CASE_OPTION_PREFIX + IntegerToString(menuIndex);
      color background = opportunityCaseCatalog[catalogIndex].annotationComplete ?
                         clrDarkSlateGray : clrDarkGoldenrod;
      if(opportunityCaseCatalog[catalogIndex].caseId == opportunityCaseSearchCaseId)
         background = clrDarkGreen;
      CreateButton(objectName, 12, 248 + menuIndex * 26, 314, 24,
                   OpportunityCaseCatalogDisplayText(catalogIndex), background);
      ObjectSetString(chartID, objectName, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP,
                      opportunityCaseCatalog[catalogIndex].caseCode +
                      " | archive_id=" + opportunityCaseCatalog[catalogIndex].caseId +
                      " | level=" + opportunityCaseCatalog[catalogIndex].opportunityLevel +
                      " | duration_hours=" +
                      DoubleToString(opportunityCaseCatalog[catalogIndex].accumulationDurationHours, 1) +
                      " | h1_bars=" +
                      IntegerToString(opportunityCaseCatalog[catalogIndex].accumulationH1Bars) +
                      " | READ-ONLY RELOAD");
      ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 1100);
     }
   opportunityCaseMenuLevel = 2;
   opportunityCaseMenuOpen = (ArraySize(opportunityCaseMenuCaseIndexes) > 0);
   opportunityCaseMenuOpenedTick = opportunityCaseMenuOpen ? GetTickCount() : 0;
   Print("[EA|FULL|CASE] INFO search menu opened | level=OPPORTUNITY | year=",
         year, " | options=", ArraySize(opportunityCaseMenuCaseIndexes),
         " | archive_touched=0");
   ChartRedraw(chartID);
  }

bool HandleOpportunityCaseSelectorClick(long chartID, string objectName)
  {
   if(objectName == OBJ_FULL_BTN_CASE_SELECTOR)
     {
      ObjectSetInteger(chartID, OBJ_FULL_BTN_CASE_SELECTOR, OBJPROP_STATE, false);
      return true;
     }

   if(objectName == OBJ_FULL_BTN_CASE_SEARCH_YEAR)
     {
      CloseOpportunityTypeMenu(chartID);
      if(opportunityCaseMenuOpen && opportunityCaseMenuLevel == 1)
        {
         CloseOpportunityCaseMenu(chartID);
         Print("[EA|FULL|CASE] INFO search menu closed | level=YEAR");
         return true;
        }
      if(!LoadOpportunityCaseCatalog(chartID))
        {
         SetOpportunityCaseFeedback("案例加载失败 | 档案目录不可用",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
         return true;
        }
      OpenOpportunityCaseYearMenu(chartID);
      return true;
     }

   if(objectName == OBJ_FULL_BTN_CASE_SEARCH_OPPORTUNITY)
     {
      CloseOpportunityTypeMenu(chartID);
      if(opportunityCaseMenuOpen && opportunityCaseMenuLevel == 2)
        {
         CloseOpportunityCaseMenu(chartID);
         Print("[EA|FULL|CASE] INFO search menu closed | level=OPPORTUNITY");
         return true;
        }
      if(!LoadOpportunityCaseCatalog(chartID))
        {
         SetOpportunityCaseFeedback("案例加载失败 | 档案目录不可用",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
         return true;
        }
      if(opportunityCaseSearchYear <= 0)
         opportunityCaseSearchYear = fullWorkYear;
      if(CountOpportunityCasesForYear(opportunityCaseSearchYear) <= 0)
        {
         UpdateOpportunityCaseSearchButtons();
         Print("[EA|FULL|CASE] INFO opportunity search unavailable | year=",
               opportunityCaseSearchYear,
               " | reason=no_saved_cases | archive_touched=0");
         return true;
        }
      OpenOpportunityCaseItemMenu(chartID, opportunityCaseSearchYear);
      return true;
     }

   if(StringFind(objectName, OBJ_FULL_CASE_YEAR_PREFIX) == 0)
     {
      int year = (int)StringToInteger(StringSubstr(objectName, StringLen(OBJ_FULL_CASE_YEAR_PREFIX)));
      CloseOpportunityCaseMenu(chartID);
      opportunityCaseSearchYear = year;
      opportunityCaseSearchCaseId = "";
      UpdateOpportunityCaseSearchButtons();
      Print("[EA|FULL|CASE] INFO search year selected | year=", year,
            " | cases=", CountOpportunityCasesForYear(year),
            " | archive_touched=0");
      return true;
     }

   if(StringFind(objectName, OBJ_FULL_CASE_OPTION_PREFIX) == 0)
     {
      string indexText = StringSubstr(objectName, StringLen(OBJ_FULL_CASE_OPTION_PREFIX));
      int menuIndex = (int)StringToInteger(indexText);
      if(menuIndex < 0 || menuIndex >= ArraySize(opportunityCaseMenuCaseIndexes)) return true;
      int targetIndex = opportunityCaseMenuCaseIndexes[menuIndex];
      if(targetIndex < 0 || targetIndex >= ArraySize(opportunityCaseCatalog))
         return true;
      string targetCaseId = opportunityCaseCatalog[targetIndex].caseId;
      int targetYear = opportunityCaseCatalog[targetIndex].year;
      Print("[EA|FULL|CASE] INFO search opportunity selected | index=", menuIndex,
            " | catalog_index=", targetIndex,
            " | year=", targetYear,
            " | case=", targetCaseId,
            " | object=", objectName,
            " | archive_touched=0");
      CloseOpportunityCaseMenu(chartID);
      if(SwitchOpportunityCase(chartID, targetIndex))
        {
         opportunityCaseSearchYear = targetYear;
         opportunityCaseSearchCaseId = targetCaseId;
         UpdateOpportunityCaseSearchButtons();
        }
      return true;
     }

   if(opportunityCaseMenuOpen) CloseOpportunityCaseMenu(chartID);
   return false;
  }

void UpdateOpportunityTypeSelectorButton()
  {
   if(ObjectFind(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE) < 0) return;
   bool supported = IsOpportunityTypeSupported(OpportunityCaseType());
   string typeText = supported ? OpportunityCaseTypeDisplayName(OpportunityCaseType()) : "未选择";
   if(opportunityActiveStandardity == "NON_STANDARD") typeText = typeText + " | 非标";
   else if(opportunityActiveStandardity == "UNREVIEWED") typeText = typeText + " | 待判";
   color background = supported ? clrDarkGreen : clrFireBrick;
   if(opportunityCaseTypeDirty || opportunityStandardityDirty) background = clrOrange;
   if(opportunityAnnotationReadOnly) background = clrDimGray;
   ObjectSetString(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_TEXT,
                   "类型 | " + typeText);
   ObjectSetInteger(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_STATE, false);
   ObjectSetString(0, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_TOOLTIP,
                   "类型=" + typeText + " | 标准性=" +
                   OpportunityStandardityDisplayName(opportunityActiveStandardity) +
                   "；保存结构后写入档案");
  }

void CloseOpportunityTypeMenu(long chartID)
  {
   bool wasOpen = opportunityTypeMenuOpen;
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OBJ_FULL_OPPORTUNITY_TYPE_OPTION_PREFIX) == 0)
         ObjectDelete(chartID, objectName);
     }
   ObjectDelete(chartID, OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE);
   if(ObjectFind(chartID, OBJ_FULL_BTN_OPPORTUNITY_TYPE) >= 0)
      ObjectSetInteger(chartID, OBJ_FULL_BTN_OPPORTUNITY_TYPE, OBJPROP_STATE, false);
   opportunityTypeMenuOpen = false;
   opportunityTypeMenuOpenedTick = 0;
   if(wasOpen) opportunityTypeMenuLastActionTick = GetTickCount();
  }

void OpenOpportunityTypeMenu(long chartID)
  {
   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);
   for(int i = 0; i < OPPORTUNITY_TYPE_COUNT; i++)
     {
      string caseType = OpportunityTypeId(i);
      string objectName = OBJ_FULL_OPPORTUNITY_TYPE_OPTION_PREFIX + IntegerToString(i);
      int column = i % 2;
      int row = i / 2;
      color background = caseType == OpportunityCaseType() ? clrDarkGreen : clrDarkSlateGray;
      CreateButton(objectName, 12 + column * 157, 248 + row * 26, 153, 24,
                   OpportunityCaseTypeDisplayName(caseType), background);
      ObjectSetString(chartID, objectName, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP, caseType);
      ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 1120);
     }
   bool nonStandard = (opportunityActiveStandardity == "NON_STANDARD");
   string standardityText = nonStandard ?
      "[X] 非标准交易机会" : "[ ] 非标准交易机会";
   color standardityBackground = clrDimGray;
   if(opportunityActiveStandardity == "STANDARD") standardityBackground = clrDarkGreen;
   if(nonStandard) standardityBackground = clrFireBrick;
   if(opportunityStandardityDirty) standardityBackground = clrOrange;
   int typeRowCount = (OPPORTUNITY_TYPE_COUNT + 1) / 2;
   int standardityY = 248 + typeRowCount * 26;
   CreateButton(OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE, 12, standardityY, 310, 24,
                standardityText, standardityBackground);
   ObjectSetString(chartID, OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE,
                   OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetString(chartID, OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE,
                   OBJPROP_TOOLTIP,
                   "勾选表示轮廓属于当前类型，但内部结构不够标准或伴随假突破");
   ObjectSetInteger(chartID, OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE,
                    OBJPROP_ZORDER, 1120);
   opportunityTypeMenuOpen = true;
   opportunityTypeMenuOpenedTick = GetTickCount();
   Print("[EA|FULL|TYPE] INFO menu opened | options=", OPPORTUNITY_TYPE_COUNT,
         " | selected=", OpportunityCaseType(),
         " | archived=", opportunityArchivedCaseType,
         " | dirty=", (int)opportunityCaseTypeDirty,
         " | standardity=", opportunityActiveStandardity,
         " | archived_standardity=", opportunityArchivedStandardity,
         " | standardity_dirty=", (int)opportunityStandardityDirty);
   ChartRedraw(chartID);
  }

bool HandleOpportunityTypeSelectorClick(long chartID, string objectName)
  {
   if(objectName == OBJ_FULL_BTN_OPPORTUNITY_TYPE)
     {
      if(opportunityTypeMenuOpen)
        {
         CloseOpportunityTypeMenu(chartID);
         Print("[EA|FULL|TYPE] INFO menu closed | reason=selector_toggle");
         return true;
        }
      OpenOpportunityTypeMenu(chartID);
      return true;
     }

   if(objectName == OBJ_FULL_OPPORTUNITY_STANDARDITY_TOGGLE)
     {
      CloseOpportunityTypeMenu(chartID);
      if(opportunityAnnotationReadOnly)
        {
         SetOpportunityCaseFeedback("标准性选择失败 | 只读周期",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
         Print("[EA|FULL|STANDARDITY] WARN selection rejected; read-only chart | case=",
               OpportunityCaseId(), " | err=0");
         return true;
        }
      if(!IsOpportunityTypeSupported(OpportunityCaseType()))
        {
         SetOpportunityCaseFeedback("标准性选择失败 | 请先选择类型",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
         Print("[EA|FULL|STANDARDITY] WARN selection rejected; opportunity type missing | case=",
               OpportunityCaseId(), " | type=", OpportunityCaseType(), " | err=0");
         return true;
        }
      string previousStandardity = opportunityActiveStandardity;
      opportunityActiveStandardity =
         (opportunityActiveStandardity == "NON_STANDARD") ?
         "STANDARD" : "NON_STANDARD";
      opportunityStandardityDirty =
         (opportunityActiveStandardity != opportunityArchivedStandardity);
      SaveOpportunitySessionState(chartID, "standardity_selected");
      string standardityName =
         OpportunityStandardityDisplayName(opportunityActiveStandardity);
      SetOpportunityCaseFeedback(opportunityStandardityDirty ?
                                 "标准性待保存 | " + standardityName :
                                 "标准性未改变 | " + standardityName,
                                 OPPORTUNITY_CASE_FEEDBACK_SUCCESS_MS);
      UpdateOpportunityAnnotationPanel();
      RefreshOpportunityRegionLabels(chartID);
      Print("[EA|FULL|STANDARDITY] INFO standardity selected | case=",
            OpportunityCaseId(), " | previous=", previousStandardity,
            " | selected=", opportunityActiveStandardity,
            " | archived=", opportunityArchivedStandardity,
            " | dirty=", (int)opportunityStandardityDirty,
            " | archive_touched=0 | err=0");
      return true;
     }

   if(StringFind(objectName, OBJ_FULL_OPPORTUNITY_TYPE_OPTION_PREFIX) == 0)
     {
      int typeIndex = (int)StringToInteger(
         StringSubstr(objectName, StringLen(OBJ_FULL_OPPORTUNITY_TYPE_OPTION_PREFIX)));
      if(typeIndex < 0 || typeIndex >= OPPORTUNITY_TYPE_COUNT) return true;
      string selectedType = OpportunityTypeId(typeIndex);
      CloseOpportunityTypeMenu(chartID);
      if(opportunityAnnotationReadOnly)
        {
         SetOpportunityCaseFeedback("类型选择失败 | 只读周期",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
         Print("[EA|FULL|TYPE] WARN selection rejected; read-only chart | selected=",
               selectedType, " | case=", OpportunityCaseId());
         return true;
        }
      string previousType = OpportunityCaseType();
       opportunityActiveCaseType = selectedType;
       opportunityCaseTypeDirty = (opportunityActiveCaseType != opportunityArchivedCaseType);
       SaveOpportunitySessionState(chartID, "type_selected");
       string displayName = OpportunityCaseTypeDisplayName(selectedType);
      SetOpportunityCaseFeedback(opportunityCaseTypeDirty ?
                                 "类型待保存 | " + displayName :
                                 "类型未改变 | " + displayName,
                                 OPPORTUNITY_CASE_FEEDBACK_SUCCESS_MS);
      UpdateOpportunityAnnotationPanel();
      RefreshOpportunityRegionLabels(chartID);
      Print("[EA|FULL|TYPE] INFO type selected | case=", OpportunityCaseId(),
            " | previous=", previousType,
            " | selected=", selectedType,
            " | archived=", opportunityArchivedCaseType,
            " | dirty=", (int)opportunityCaseTypeDirty,
            " | archive_touched=0");
      RunPureReleaseShadowPreflight(chartID, "type_selected");
      return true;
     }

   if(opportunityTypeMenuOpen) CloseOpportunityTypeMenu(chartID);
   return false;
  }

string OpportunityObjectPrefix()
  {
   string safeId = OpportunityCaseId();
   StringReplace(safeId, "\\", "_");
   StringReplace(safeId, "/", "_");
   StringReplace(safeId, ":", "_");
   StringReplace(safeId, ".", "_");
   StringReplace(safeId, " ", "_");
   return OPPORTUNITY_OBJECT_PREFIX + safeId + "_";
  }

int ClampOpportunityStructureRadius(int radiusBars)
  {
   if(radiusBars < OPPORTUNITY_STRUCTURE_RADIUS_MIN) return OPPORTUNITY_STRUCTURE_RADIUS_MIN;
   if(radiusBars > OPPORTUNITY_STRUCTURE_RADIUS_MAX) return OPPORTUNITY_STRUCTURE_RADIUS_MAX;
   return radiusBars;
  }

int FindOpportunityLineAnchorIndex(string role)
  {
   for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
     {
      if(opportunityLineAnchors[i].role == role) return i;
     }
   return -1;
  }

void ResetOpportunityLineAnchor(int index)
  {
   opportunityLineAnchors[index].barTime = 0;
   opportunityLineAnchors[index].price = 0.0;
   opportunityLineAnchors[index].snapType = "";
   opportunityLineAnchors[index].barShift = -1;
   opportunityLineAnchors[index].actionSequence = 0;
   opportunityLineAnchors[index].active = false;
  }

void ResetOpportunityKeyBar()
  {
   opportunityKeyBar.role = "RELEASE_BAR";
   opportunityKeyBar.barTime = 0;
   opportunityKeyBar.confirmTime = 0;
   opportunityKeyBar.highlightStartTime = 0;
   opportunityKeyBar.highlightEndTime = 0;
   opportunityKeyBar.openPrice = 0.0;
   opportunityKeyBar.highPrice = 0.0;
   opportunityKeyBar.lowPrice = 0.0;
   opportunityKeyBar.closePrice = 0.0;
   opportunityKeyBar.barShift = -1;
   opportunityKeyBar.direction = "";
   opportunityKeyBar.actionSequence = 0;
   opportunityKeyBar.active = false;
  }

void ResetOpportunityAnnotationState()
  {
   ArrayResize(opportunityStructures, 0);
   ArrayResize(opportunityDrawings, 0);
   ArrayResize(opportunityRegions, 0);
   ArrayResize(opportunityDrawingSemantics, 0);
   ArrayResize(opportunityChannelBoundaries, 0);
   opportunityFutureOutcome = "";
   string roles[OPPORTUNITY_LINE_ANCHOR_COUNT] =
     {
      "UPPER_1", "UPPER_2", "LOWER_1", "LOWER_2"
     };

   for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
     {
      opportunityLineAnchors[i].role = roles[i];
      ResetOpportunityLineAnchor(i);
     }

   ResetOpportunityKeyBar();

   opportunityStructureRadiusBars = ClampOpportunityStructureRadius(InpStructureRadiusBars);
   opportunityAnnotationReadOnly = false;
   opportunityAnnotationNativeSymbol = "";
   opportunityAnnotationNativeTimeframe = "";
   opportunityAnnotationMode = "";
   opportunityNextActionSequence = 1;
   opportunityChartViewVisible = true;
   opportunityModeSelectedTick = 0;
   opportunityLastButtonTick = 0;
   opportunityLastButtonName = "";
   opportunityEditStructureIndex = -1;
   opportunityLastStructureLabelClickTick = 0;
   opportunityLastStructureLabelClickName = "";
   opportunityEditStateTick = 0;
  }

int CountOpportunityLineAnchors(int startIndex, int endIndex)
  {
   int count = 0;
   for(int i = startIndex; i <= endIndex; i++)
      {
      if(opportunityLineAnchors[i].active) count++;
      }
   return count;
  }

void AddPureReleaseReservedPrefix(string &reservedPrefixes[], string value)
  {
   if(StringLen(value) == 0) return;
   for(int i = 0; i < ArraySize(reservedPrefixes); i++)
      if(reservedPrefixes[i] == value) return;
   int index = ArraySize(reservedPrefixes);
   ArrayResize(reservedPrefixes, index + 1);
   reservedPrefixes[index] = value;
  }

void BuildPureReleaseReservedPrefixes(string &reservedPrefixes[])
  {
   ArrayResize(reservedPrefixes, 0);
   AddPureReleaseReservedPrefix(reservedPrefixes, OPPORTUNITY_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, OPPORTUNITY_DRAWING_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, OPPORTUNITY_REGION_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, OPPORTUNITY_GEOMETRY_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, OPPORTUNITY_SESSION_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, ACC_OBJECT_PREFIX);
   AddPureReleaseReservedPrefix(reservedPrefixes, "full_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "btn_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "lbl_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "edit_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "ui_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "slider_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "FullModeMsg");
   AddPureReleaseReservedPrefix(reservedPrefixes, "PythonMsg");
   AddPureReleaseReservedPrefix(reservedPrefixes, "Py_VLine_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "Range_");
   AddPureReleaseReservedPrefix(reservedPrefixes, "MANUAL_BOX_");
  }

bool IsPureReleaseShadowDraft()
  {
   if(!isFullChartInstance || !opportunityCaseCatalogReady) return false;
   if(opportunityAnnotationReadOnly) return false;
   if(!PR_IsPureReleaseCaseType(OpportunityCaseType())) return false;
   if(FindOpportunityCaseCatalogIndex(OpportunityCaseId()) >= 0) return false;
   if(StringLen(opportunityArchivedCaseType) > 0) return false;
   if(!opportunityCaseTypeDirty) return false;
   return true;
  }

void ResetPureReleaseShadowState(string reason)
  {
   pureReleaseLastSignature = "";
   pureReleaseLastCaseId = "";
   pureReleaseLastType = "";
   pureReleaseDraftRevision = 0;
   pureReleaseAnalysisRuns = 0;
   pureReleaseLastValid = false;
   pureReleaseLastAnalysisCompleted = false;
   pureReleaseLastStatus = PR_STATUS_CAPTURE_FAILED;
   pureReleaseLastReason = PR_REASON_CAPTURE_FAILED;
   pureReleaseLastMarketDirection = PR_DIRECTION_UNKNOWN;
   pureReleaseLastDirectionAgreement = PR_AGREEMENT_NOT_EVALUATED;
   pureReleaseLastQualityStatus = PR_QUALITY_NOT_EVALUATED;
   pureReleaseLastDataGapStatus = PR_SESSION_GAP_STATUS_NOT_EVALUATED;
   pureReleaseLastDataGapReason = PR_SESSION_GAP_REASON_NONE;
   pureReleaseLastSessionPolicy = PR_SESSION_POLICY_VERSION;
   pureReleaseLastCalendarSpanHours = 0;
   pureReleaseLastCalendarExpectedBars = 0;
   pureReleaseLastActualBars = 0;
   pureReleaseLastExpectedClosureGaps = 0;
   pureReleaseLastExpectedClosureHours = 0;
   pureReleaseLastUnexpectedGaps = 0;
   pureReleaseLastFirstGapPrevious = 0;
   pureReleaseLastFirstGapNext = 0;
   pureReleaseLastFirstGapHours = 0;
   Print("[EA|FULL|PURE_RELEASE] INFO shadow state reset | reason=", reason,
         " | archive_touched=0");
  }

string BuildPureReleaseShadowSignature(PR_PreflightResult &preflight,
                                       PR_AnalysisResult &analysis)
  {
   return analysis.statusCode + ":" + analysis.reasonCode + ":" +
          analysis.marketDirection + ":" + analysis.qualityStatus + ":" +
          analysis.analysisFingerprint + ":" + preflight.statusCode + ":" +
          preflight.direction + ":" + IntegerToString(preflight.objectCount) + ":" +
          IntegerToString(preflight.boundaryCount) + ":" +
          IntegerToString(preflight.releasePathCount) + ":" +
          IntegerToString(preflight.unsupportedCount);
  }

void RememberPureReleaseShadowResult(bool qualified,
                                      PR_AnalysisResult &analysis)
  {
   pureReleaseLastValid = qualified;
   pureReleaseLastAnalysisCompleted = analysis.analysisCompleted;
   pureReleaseLastStatus = analysis.statusCode;
   pureReleaseLastReason = analysis.reasonCode;
   pureReleaseLastMarketDirection = analysis.marketDirection;
   pureReleaseLastDirectionAgreement = analysis.directionAgreement;
   pureReleaseLastQualityStatus = analysis.qualityStatus;
   pureReleaseLastDataGapStatus = analysis.dataGapStatus;
   pureReleaseLastDataGapReason = analysis.dataGapReason;
   pureReleaseLastSessionPolicy = analysis.sessionPolicyVersion;
   pureReleaseLastCalendarSpanHours = analysis.calendarSpanHours;
   pureReleaseLastCalendarExpectedBars = analysis.calendarExpectedBars;
   pureReleaseLastActualBars = analysis.actualBars;
   pureReleaseLastExpectedClosureGaps = analysis.expectedClosureGapCount;
   pureReleaseLastExpectedClosureHours = analysis.expectedClosureHours;
   pureReleaseLastUnexpectedGaps = analysis.unexpectedGapCount;
   pureReleaseLastFirstGapPrevious = analysis.firstUnexpectedGapPrevious;
   pureReleaseLastFirstGapNext = analysis.firstUnexpectedGapNext;
   pureReleaseLastFirstGapHours = analysis.firstUnexpectedGapHours;
  }

bool RunPureReleaseShadowPreflight(long chartID, string trigger)
  {
   if(!IsPureReleaseShadowDraft()) return false;
   if(pureReleaseShadowRunning) return pureReleaseLastValid;

   pureReleaseShadowRunning = true;
   string reservedPrefixes[];
   BuildPureReleaseReservedPrefixes(reservedPrefixes);
   PR_DraftSnapshot snapshot;
   PR_PreflightResult preflight;
   PR_AnalysisResult analysis;
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   bool qualified = PR_AnalyzeChartWithState(
      chartID, OpportunityCaseId(), OpportunityCaseType(), ChartSymbol(chartID),
      timeframe, reservedPrefixes, PR_REPRESENTATION_ID,
      ArraySize(opportunityStructures) +
      CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1),
      opportunityKeyBar.active,
      "NOT_APPLICABLE", "NOT_APPLICABLE", snapshot, preflight, analysis);
   string signature = BuildPureReleaseShadowSignature(preflight, analysis);
   bool changed = (signature != pureReleaseLastSignature ||
                   OpportunityCaseId() != pureReleaseLastCaseId ||
                   OpportunityCaseType() != pureReleaseLastType);
   if(changed)
     {
      pureReleaseLastSignature = signature;
      pureReleaseLastCaseId = OpportunityCaseId();
      pureReleaseLastType = OpportunityCaseType();
      pureReleaseDraftRevision++;
      pureReleaseAnalysisRuns++;
      RememberPureReleaseShadowResult(qualified, analysis);
      Print("[EA|FULL|PURE_RELEASE|P2] INFO shadow_analysis",
            " | strategy_id=", PR_STRATEGY_ID,
            " | representation_version=", snapshot.representationID,
            " | contract_version=", snapshot.contractVersion,
            " | feature_version=", analysis.featureVersion,
            " | direction_version=", analysis.directionVersion,
            " | policy_version=", analysis.policyVersion,
            " | case_id=", OpportunityCaseId(),
            " | case_type=", OpportunityCaseType(),
            " | draft_revision=", pureReleaseDraftRevision,
            " | contract_status=", preflight.statusCode,
            " | contract_reason=", preflight.reasonCode,
            " | analysis_status=", analysis.statusCode,
            " | reason_code=", analysis.reasonCode,
            " | data_status=", analysis.dataStatusCode,
            " | data_reason=", analysis.dataReasonCode,
            " | data_last_error=", analysis.dataLastError,
            " | analysis_completed=", (int)analysis.analysisCompleted,
            " | gap_status=", analysis.dataGapStatus,
            " | gap_reason=", analysis.dataGapReason,
            " | session_policy=", analysis.sessionPolicyVersion,
            " | calendar_hours=", analysis.calendarSpanHours,
            " | calendar_bars=", analysis.calendarExpectedBars,
            " | actual_bars=", analysis.actualBars,
            " | expected_closure_gaps=", analysis.expectedClosureGapCount,
            " | expected_closure_hours=", analysis.expectedClosureHours,
            " | unexpected_gaps=", analysis.unexpectedGapCount,
            " | first_gap_previous=", (long)analysis.firstUnexpectedGapPrevious,
            " | first_gap_next=", (long)analysis.firstUnexpectedGapNext,
            " | first_gap_hours=", analysis.firstUnexpectedGapHours,
            " | selected_direction=", analysis.declaredDirection,
            " | line_direction=", analysis.lineDirection,
            " | market_direction=", analysis.marketDirection,
            " | direction_agreement=", analysis.directionAgreement,
            " | quality_status=", analysis.qualityStatus,
            " | quality_review_mask=", analysis.qualityReviewMask,
            " | quality_failure_mask=", analysis.qualityFailureMask,
            " | bars=", analysis.features.releaseBarCount,
            " | atr_reference=", DoubleToString(analysis.features.atrReference, 8),
            " | net_atr=", DoubleToString(analysis.features.netMoveAtr, 6),
            " | slope_span_atr=", DoubleToString(analysis.features.slopeSpanAtr, 6),
            " | efficiency=", DoubleToString(analysis.features.efficiency, 6),
            " | body_alignment=", DoubleToString(analysis.selectedBodyAlignment, 6),
            " | pullback_ratio=", DoubleToString(analysis.selectedPullbackRatio, 6),
            " | range_expansion=", DoubleToString(analysis.features.rangeExpansion, 6),
            " | regression_r2=", DoubleToString(analysis.features.regressionR2, 6),
            " | vline_count=", preflight.boundaryCount,
            " | release_line_count=", preflight.releasePathCount,
            " | object_count=", preflight.objectCount,
            " | unsupported_count=", preflight.unsupportedCount,
            " | invalid_subwindow_count=", preflight.invalidSubwindowCount,
            " | invalid_price_count=", preflight.invalidPriceCount,
            " | invalid_identity_count=", preflight.invalidObjectIdentityCount,
            " | duplicate_identity_count=", preflight.duplicateObjectCount,
            " | structure_count=", snapshot.structureCount,
            " | key_bar_active=", (int)snapshot.keyBarActive,
            " | structure_applicability=", snapshot.structureApplicability,
            " | key_bar_applicability=", snapshot.keyBarApplicability,
            " | draft_fingerprint_length=", StringLen(preflight.fingerprint),
            " | market_fingerprint=", analysis.marketFingerprint,
            " | analysis_fingerprint_length=", StringLen(analysis.analysisFingerprint),
            " | trigger=", trigger,
            " | analysis_runs=", pureReleaseAnalysisRuns,
            " | legacy_region_called=0 | legacy_save_called=0",
            " | archive_touched=0");
     }
   else
     {
      RememberPureReleaseShadowResult(qualified, analysis);
      Print("[EA|FULL|PURE_RELEASE|P2] INFO shadow_analysis_duplicate",
            " | case_id=", OpportunityCaseId(),
            " | draft_revision=", pureReleaseDraftRevision,
            " | trigger=", trigger,
            " | analysis_runs=", pureReleaseAnalysisRuns,
            " | contract_status=", preflight.statusCode,
            " | analysis_status=", analysis.statusCode,
            " | reason_code=", analysis.reasonCode,
            " | data_status=", analysis.dataStatusCode,
            " | analysis_completed=", (int)analysis.analysisCompleted,
            " | gap_status=", analysis.dataGapStatus,
            " | gap_reason=", analysis.dataGapReason,
            " | session_policy=", analysis.sessionPolicyVersion,
            " | calendar_hours=", analysis.calendarSpanHours,
            " | calendar_bars=", analysis.calendarExpectedBars,
            " | actual_bars=", analysis.actualBars,
            " | expected_closure_gaps=", analysis.expectedClosureGapCount,
            " | expected_closure_hours=", analysis.expectedClosureHours,
            " | unexpected_gaps=", analysis.unexpectedGapCount,
            " | first_gap_previous=", (long)analysis.firstUnexpectedGapPrevious,
            " | first_gap_next=", (long)analysis.firstUnexpectedGapNext,
            " | first_gap_hours=", analysis.firstUnexpectedGapHours,
            " | market_direction=", analysis.marketDirection,
            " | direction_agreement=", analysis.directionAgreement,
            " | quality_status=", analysis.qualityStatus,
            " | legacy_region_called=0 | legacy_save_called=0",
            " | archive_touched=0");
     }
   pureReleaseShadowRunning = false;
   return qualified;
  }

void RenumberOpportunityStructures()
  {
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
      opportunityStructures[i].role = "S" + IntegerToString(i + 1);
  }

bool ResolveOpportunityCirclePriceRange(long chartID,
                                        datetime centerTime,
                                        double centerPrice,
                                        datetime rangeStartTime,
                                        datetime rangeEndTime,
                                        double fallbackRadius,
                                        double &circleLow,
                                        double &circleHigh)
  {
   int centerX = 0;
   int centerY = 0;
   int startX = 0;
   int startY = 0;
   int endX = 0;
   int endY = 0;
   bool coordinatesOK = ChartTimePriceToXY(chartID, 0, centerTime, centerPrice, centerX, centerY) &&
                        ChartTimePriceToXY(chartID, 0, rangeStartTime, centerPrice, startX, startY) &&
                        ChartTimePriceToXY(chartID, 0, rangeEndTime, centerPrice, endX, endY);
   if(coordinatesOK)
     {
      int pixelRadius = MathMax(MathAbs(centerX - startX), MathAbs(endX - centerX));
      int chartHeight = (int)ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0);
      if(pixelRadius >= 2 && chartHeight > 2)
        {
         int topY = MathMax(0, centerY - pixelRadius);
         int bottomY = MathMin(chartHeight - 1, centerY + pixelRadius);
         int subWindow = 0;
         datetime convertedTime = 0;
         double topPrice = 0.0;
         double bottomPrice = 0.0;
         bool topOK = ChartXYToTimePrice(chartID, centerX, topY, subWindow, convertedTime, topPrice);
         bool bottomOK = ChartXYToTimePrice(chartID, centerX, bottomY, subWindow, convertedTime, bottomPrice);
         if(topOK && bottomOK && topPrice > 0.0 && bottomPrice > 0.0)
           {
            double priceRadius = MathMax(MathAbs(topPrice - centerPrice), MathAbs(centerPrice - bottomPrice));
            if(priceRadius > 0.0)
              {
               circleLow = NormalizeDouble(centerPrice - priceRadius, _Digits);
               circleHigh = NormalizeDouble(centerPrice + priceRadius, _Digits);
               return true;
              }
           }
        }
     }

   double safeRadius = MathMax(fallbackRadius, _Point * 20.0);
   circleLow = NormalizeDouble(centerPrice - safeRadius, _Digits);
   circleHigh = NormalizeDouble(centerPrice + safeRadius, _Digits);
   return false;
  }

bool RecalculateOpportunityStructure(long chartID, int structureIndex, bool preserveRepresentativeType)
  {
   if(structureIndex < 0 || structureIndex >= ArraySize(opportunityStructures)) return false;
   string symbol = ChartSymbol(chartID);
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   int centerShift = iBarShift(symbol, timeframe, opportunityStructures[structureIndex].centerTime, false);
   int totalBars = Bars(symbol, timeframe);
   if(centerShift < 0 || totalBars <= 0)
     {
      Print("[EA|FULL|ANNOT] ERROR structure bar lookup failed | role=", opportunityStructures[structureIndex].role,
            " | center_time=", TimeToString(opportunityStructures[structureIndex].centerTime, TIME_DATE|TIME_MINUTES),
            " | err=", GetLastError());
      return false;
     }

   int radiusBars = ClampOpportunityStructureRadius(opportunityStructures[structureIndex].radiusBars);
   int secondsPerBar = PeriodSeconds(timeframe);
   if(secondsPerBar <= 0)
     {
      Print("[EA|FULL|ANNOT] ERROR structure timeframe has no fixed duration | role=", opportunityStructures[structureIndex].role,
            " | timeframe=", EnumToString(timeframe), " | seconds_per_bar=", secondsPerBar);
      return false;
     }
   int newestShift = MathMax(0, centerShift - radiusBars);
   int oldestShift = MathMin(totalBars - 1, centerShift + radiusBars);
   double zoneHigh = -DBL_MAX;
   double zoneLow = DBL_MAX;
   double totalRange = 0.0;
   int sampledBars = 0;
   int highShift = -1;
   int lowShift = -1;
   for(int shift = newestShift; shift <= oldestShift; shift++)
     {
      double barHigh = iHigh(symbol, timeframe, shift);
      double barLow = iLow(symbol, timeframe, shift);
      datetime barTime = iTime(symbol, timeframe, shift);
      if(barTime <= 0 || barHigh <= 0.0 || barLow <= 0.0 || barHigh < barLow) continue;
      if(barHigh > zoneHigh)
        {
         zoneHigh = barHigh;
         highShift = shift;
        }
      if(barLow < zoneLow)
        {
         zoneLow = barLow;
         lowShift = shift;
        }
      totalRange += barHigh - barLow;
      sampledBars++;
     }

   if(sampledBars <= 0 || highShift < 0 || lowShift < 0)
     {
      Print("[EA|FULL|ANNOT] ERROR structure range has no valid bars | role=", opportunityStructures[structureIndex].role,
            " | center_shift=", centerShift, " | radius=", radiusBars);
      return false;
     }

   string representativeType = opportunityStructures[structureIndex].representativeType;
   if(!preserveRepresentativeType || (representativeType != "HIGH" && representativeType != "LOW"))
     {
      double highDistance = MathAbs(opportunityStructures[structureIndex].centerPrice - zoneHigh);
      double lowDistance = MathAbs(opportunityStructures[structureIndex].centerPrice - zoneLow);
      representativeType = (highDistance <= lowDistance) ? "HIGH" : "LOW";
     }
   int representativeShift = (representativeType == "HIGH") ? highShift : lowShift;
   double representativePrice = (representativeType == "HIGH") ? zoneHigh : zoneLow;

   opportunityStructures[structureIndex].centerBarShift = centerShift;
   opportunityStructures[structureIndex].radiusBars = radiusBars;
   long halfSpanSeconds = (long)secondsPerBar * radiusBars;
   opportunityStructures[structureIndex].rangeStartTime =
      (datetime)((long)opportunityStructures[structureIndex].centerTime - halfSpanSeconds);
   opportunityStructures[structureIndex].rangeEndTime =
      (datetime)((long)opportunityStructures[structureIndex].centerTime + halfSpanSeconds);
   opportunityStructures[structureIndex].zoneLow = NormalizeDouble(zoneLow, _Digits);
   opportunityStructures[structureIndex].zoneHigh = NormalizeDouble(zoneHigh, _Digits);
   opportunityStructures[structureIndex].representativeTime = iTime(symbol, timeframe, representativeShift);
   opportunityStructures[structureIndex].representativePrice = NormalizeDouble(representativePrice, _Digits);
   opportunityStructures[structureIndex].representativeType = representativeType;
   opportunityStructures[structureIndex].representativeBarShift = representativeShift;

   double averageRange = totalRange / sampledBars;
   bool exactCircle = ResolveOpportunityCirclePriceRange(chartID,
                                                         opportunityStructures[structureIndex].centerTime,
                                                         opportunityStructures[structureIndex].centerPrice,
                                                         opportunityStructures[structureIndex].rangeStartTime,
                                                         opportunityStructures[structureIndex].rangeEndTime,
                                                         averageRange * MathMax(1, radiusBars),
                                                         opportunityStructures[structureIndex].circleLow,
                                                         opportunityStructures[structureIndex].circleHigh);
   if(GV_DEBUG_FULL && !exactCircle)
      Print("[EA|FULL|ANNOT] WARN circle price radius used OHLC fallback | role=", opportunityStructures[structureIndex].role,
            " | radius=", radiusBars);
   return true;
  }

string OpportunityRuleValue(int value)
  {
   if(value < 0) return "";
   return (value == 1) ? "1" : "0";
  }

double OpportunityChannelTouchDistanceSum(
   OpportunityChannelBoundaryState &boundary)
  {
   if(boundary.touchCount <= 0 || StringLen(boundary.touchDistancePrices) == 0)
      return 1.0e100;
   string values[];
   ushort separator = StringGetCharacter("|", 0);
   int count = StringSplit(boundary.touchDistancePrices, separator, values);
   if(count != boundary.touchCount) return 1.0e100;
   double total = 0.0;
   for(int i = 0; i < count; i++) total += MathAbs(StringToDouble(values[i]));
   return total;
  }

int OpportunityChannelRuleDirectionSign(string caseType)
  {
   if(caseType == "ASCENDING_CHANNEL") return 1;
   if(caseType == "DESCENDING_CHANNEL") return -1;
   return 0;
  }

bool OpportunityChannelBoundaryHasTouch(
   OpportunityChannelBoundaryState &boundary,
   string anchorRole)
  {
   if(boundary.touchCount <= 0 || StringLen(boundary.touchAnchorRoles) == 0)
      return false;
   string roles[];
   ushort separator = StringGetCharacter("|", 0);
   int count = StringSplit(boundary.touchAnchorRoles, separator, roles);
   for(int i = 0; i < count; i++)
      if(roles[i] == anchorRole) return true;
   return false;
  }

void EvaluateOpportunityChannelStructureSequence(
   int upperIndex,
   int lowerIndex,
   int directionSign,
   int &alternationOK,
   int &progressionOK)
  {
   alternationOK = 1;
   progressionOK = 1;
   int previousBoundary = 0;
   int upperCount = 0;
   int lowerCount = 0;
   double previousUpperPrice = 0.0;
   double previousLowerPrice = 0.0;
   bool hasUpperPrice = false;
   bool hasLowerPrice = false;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      bool touchesUpper = OpportunityChannelBoundaryHasTouch(
                             opportunityChannelBoundaries[upperIndex],
                             opportunityStructures[i].role);
      bool touchesLower = OpportunityChannelBoundaryHasTouch(
                             opportunityChannelBoundaries[lowerIndex],
                             opportunityStructures[i].role);
      if(touchesUpper == touchesLower)
        {
         alternationOK = 0;
         progressionOK = 0;
         continue;
        }
      int currentBoundary = touchesUpper ? 1 : -1;
      if(previousBoundary == currentBoundary) alternationOK = 0;
      previousBoundary = currentBoundary;
      double currentPrice = opportunityStructures[i].representativePrice > 0.0 ?
                            opportunityStructures[i].representativePrice :
                            opportunityStructures[i].centerPrice;
      if(currentPrice <= 0.0)
        {
         progressionOK = 0;
         continue;
        }
      if(touchesUpper)
        {
         upperCount++;
         if(hasUpperPrice &&
            directionSign * (currentPrice - previousUpperPrice) <= 0.0)
            progressionOK = 0;
         previousUpperPrice = currentPrice;
         hasUpperPrice = true;
        }
      else
        {
         lowerCount++;
         if(hasLowerPrice &&
            directionSign * (currentPrice - previousLowerPrice) <= 0.0)
            progressionOK = 0;
         previousLowerPrice = currentPrice;
         hasLowerPrice = true;
        }
     }
   if(upperCount < 2 || lowerCount < 2) progressionOK = 0;
  }

bool ResolvePrimaryOpportunityChannelBoundaryIndexes(int &upperIndex,
                                                     int &lowerIndex)
  {
   upperIndex = -1;
   lowerIndex = -1;
   int bestTouchCount = -1;
   double bestAverageDistance = 1.0e100;
   for(int i = 0; i < ArraySize(opportunityChannelBoundaries); i++)
     {
      if(opportunityChannelBoundaries[i].componentRole != "MAIN_LINE") continue;
      int parallelIndex = FindOpportunityChannelBoundary(
                             opportunityChannelBoundaries,
                             opportunityChannelBoundaries[i].sourceDrawingId,
                             "PARALLEL_LINE");
      if(parallelIndex < 0 ||
         !opportunityChannelBoundaries[i].parallelOK ||
         !opportunityChannelBoundaries[parallelIndex].parallelOK)
         continue;
      int candidateUpper = opportunityChannelBoundaries[i].boundaryRole ==
                           "CHANNEL_UPPER_BOUNDARY" ? i : parallelIndex;
      int candidateLower = opportunityChannelBoundaries[i].boundaryRole ==
                           "CHANNEL_LOWER_BOUNDARY" ? i : parallelIndex;
      if(opportunityChannelBoundaries[candidateUpper].boundaryRole !=
         "CHANNEL_UPPER_BOUNDARY" ||
         opportunityChannelBoundaries[candidateLower].boundaryRole !=
         "CHANNEL_LOWER_BOUNDARY")
         continue;
      int touchCount = opportunityChannelBoundaries[candidateUpper].touchCount +
                       opportunityChannelBoundaries[candidateLower].touchCount;
      double distanceSum = OpportunityChannelTouchDistanceSum(
                              opportunityChannelBoundaries[candidateUpper]) +
                           OpportunityChannelTouchDistanceSum(
                              opportunityChannelBoundaries[candidateLower]);
      double averageDistance = touchCount > 0 ?
                               distanceSum / (double)touchCount : 1.0e100;
      if(touchCount > bestTouchCount ||
         (touchCount == bestTouchCount && averageDistance < bestAverageDistance))
        {
         bestTouchCount = touchCount;
         bestAverageDistance = averageDistance;
         upperIndex = candidateUpper;
         lowerIndex = candidateLower;
        }
     }
   return (upperIndex >= 0 && lowerIndex >= 0);
  }

void EvaluateOpportunityRules(int &timeOrderOK,
                              int &alternationOK,
                              int &progressionOK,
                              int &upperRisingOK,
                              int &lowerRisingOK,
                              int &parallelOK,
                              string &ruleStatus)
  {
   timeOrderOK = -1;
   alternationOK = -1;
   progressionOK = -1;
   upperRisingOK = -1;
   lowerRisingOK = -1;
   parallelOK = -1;
   ruleStatus = "DRAFT";

   int structureCount = ArraySize(opportunityStructures);
   if(structureCount < 5) return;

   timeOrderOK = 1;
   alternationOK = 1;
   progressionOK = 1;
   double previousHigh = 0.0;
   double previousLow = 0.0;
   bool hasHigh = false;
   bool hasLow = false;
   int highCount = 0;
   int lowCount = 0;
   int progressionDirectionSign = OpportunityChannelRuleDirectionSign(
                                     OpportunityCaseType());
   if(progressionDirectionSign == 0) progressionDirectionSign = 1;

   for(int i = 0; i < structureCount; i++)
     {
      if(i > 0 && opportunityStructures[i].centerTime <= opportunityStructures[i - 1].centerTime)
         timeOrderOK = 0;
      if(i > 0 && opportunityStructures[i].representativeType == opportunityStructures[i - 1].representativeType)
         alternationOK = 0;

      if(opportunityStructures[i].representativeType == "HIGH")
        {
         highCount++;
         if(hasHigh && progressionDirectionSign *
            (opportunityStructures[i].representativePrice - previousHigh) <= 0.0)
            progressionOK = 0;
         previousHigh = opportunityStructures[i].representativePrice;
         hasHigh = true;
        }
      else if(opportunityStructures[i].representativeType == "LOW")
        {
         lowCount++;
         if(hasLow && progressionDirectionSign *
            (opportunityStructures[i].representativePrice - previousLow) <= 0.0)
            progressionOK = 0;
         previousLow = opportunityStructures[i].representativePrice;
         hasLow = true;
        }
      else
        {
         alternationOK = 0;
         progressionOK = 0;
        }
     }

   if(highCount < 2 || lowCount < 2) progressionOK = 0;

   int channelUpperIndex = -1;
   int channelLowerIndex = -1;
   if(IsOpportunityGeometryChannelType(OpportunityCaseType()) &&
      ResolvePrimaryOpportunityChannelBoundaryIndexes(channelUpperIndex,
                                                       channelLowerIndex))
     {
      int channelDirectionSign = OpportunityChannelRuleDirectionSign(
                                    OpportunityCaseType());
      string expectedDirection = channelDirectionSign > 0 ?
                                 "ASCENDING" : "DESCENDING";
      EvaluateOpportunityChannelStructureSequence(channelUpperIndex,
                                                  channelLowerIndex,
                                                  channelDirectionSign,
                                                  alternationOK,
                                                  progressionOK);
      upperRisingOK = opportunityChannelBoundaries[channelUpperIndex].channelDirection ==
                      expectedDirection ? 1 : 0;
      lowerRisingOK = opportunityChannelBoundaries[channelLowerIndex].channelDirection ==
                      expectedDirection ? 1 : 0;
      parallelOK = (opportunityChannelBoundaries[channelUpperIndex].parallelOK &&
                    opportunityChannelBoundaries[channelLowerIndex].parallelOK) ? 1 : 0;
      bool allPassed = (timeOrderOK == 1 && alternationOK == 1 &&
                        progressionOK == 1 && upperRisingOK == 1 &&
                        lowerRisingOK == 1 && parallelOK == 1 &&
                        opportunityChannelBoundaries[channelUpperIndex].touchCount >= 2 &&
                        opportunityChannelBoundaries[channelLowerIndex].touchCount >= 2);
      ruleStatus = allPassed ? "PASS" : "REVIEW";
      return;
     }

   if(CountOpportunityLineAnchors(0, 1) < 2 || CountOpportunityLineAnchors(2, 3) < 2)
     {
      ruleStatus = "PENDING_LINES";
      return;
     }

   long upperSeconds = (long)(opportunityLineAnchors[1].barTime - opportunityLineAnchors[0].barTime);
   long lowerSeconds = (long)(opportunityLineAnchors[3].barTime - opportunityLineAnchors[2].barTime);
   double upperSlope = 0.0;
   double lowerSlope = 0.0;
   int lineDirectionSign = OpportunityChannelRuleDirectionSign(
                              OpportunityCaseType());
   if(lineDirectionSign == 0) lineDirectionSign = 1;

   upperRisingOK = 0;
   lowerRisingOK = 0;
   parallelOK = 0;
   if(upperSeconds > 0)
     {
      upperSlope = (opportunityLineAnchors[1].price - opportunityLineAnchors[0].price) / (double)upperSeconds;
      if(lineDirectionSign * upperSlope > 0.0) upperRisingOK = 1;
     }
   if(lowerSeconds > 0)
     {
      lowerSlope = (opportunityLineAnchors[3].price - opportunityLineAnchors[2].price) / (double)lowerSeconds;
      if(lineDirectionSign * lowerSlope > 0.0) lowerRisingOK = 1;
     }

   double slopeScale = MathMax(MathAbs(upperSlope), MathAbs(lowerSlope));
   if(slopeScale > 0.0)
     {
      double relativeDifference = MathAbs(upperSlope - lowerSlope) / slopeScale;
      if(relativeDifference <= InpChannelParallelTolerance) parallelOK = 1;
     }

   bool allPassed = (timeOrderOK == 1 && alternationOK == 1 && progressionOK == 1 &&
                     upperRisingOK == 1 && lowerRisingOK == 1 && parallelOK == 1);
   ruleStatus = allPassed ? "PASS" : "REVIEW";
  }

void SetOpportunityButtonColor(string objectName, color background)
  {
   if(ObjectFind(0, objectName) < 0) return;
   ObjectSetInteger(0, objectName, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objectName, OBJPROP_STATE, false);
  }

void SetOpportunityStructureSaveFeedback(string state, string statusText, uint durationMs)
  {
   opportunitySaveFeedbackState = state;
   opportunitySaveFeedbackStatus = statusText;
   opportunitySaveFeedbackStartedTick = GetTickCount();
   opportunitySaveFeedbackDurationMs = durationMs;
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(0);
  }

void RefreshOpportunityStructureSaveFeedback()
  {
   if(StringLen(opportunitySaveFeedbackState) == 0 || opportunitySaveFeedbackDurationMs == 0) return;
   if((uint)(GetTickCount() - opportunitySaveFeedbackStartedTick) < opportunitySaveFeedbackDurationMs) return;

   opportunitySaveFeedbackState = "";
   opportunitySaveFeedbackStatus = "";
   opportunitySaveFeedbackStartedTick = 0;
   opportunitySaveFeedbackDurationMs = 0;
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(0);
  }

void UpdateOpportunityAnnotationPanel()
  {
   UpdateOpportunityCaseSelectorButton();
   UpdateOpportunityTypeSelectorButton();
   CM_DeleteModuleUpdateButton(ChartID());
   color structureColor = (ArraySize(opportunityStructures) > 0) ? clrDarkGreen : clrDarkSlateGray;
   if(opportunityAnnotationMode == "STRUCT") structureColor = clrOrange;
   if(opportunityAnnotationReadOnly) structureColor = clrDimGray;
   SetOpportunityButtonColor(OBJ_FULL_BTN_STRUCTURE, structureColor);
   SetOpportunityButtonColor(OBJ_FULL_BTN_SIZE_DOWN, clrDarkSlateGray);
   SetOpportunityButtonColor(OBJ_FULL_BTN_SIZE_UP, clrDarkSlateGray);
   color keyBarColor = opportunityKeyBar.active ? clrDarkGreen : clrDarkGoldenrod;
   if(opportunityAnnotationMode == "KEY_BAR") keyBarColor = clrOrange;
   if(opportunityAnnotationReadOnly) keyBarColor = clrDimGray;
   SetOpportunityButtonColor(OBJ_FULL_BTN_KEY_BAR, keyBarColor);
   color saveStructureColor = ArraySize(opportunityDrawings) > 0 ? clrDarkGreen : clrDarkSlateGray;
   string saveStructureText = "保存结构";
   if(opportunityAnnotationReadOnly) saveStructureColor = clrDimGray;
   if(opportunitySaveFeedbackState == "SAVING")
     {
      saveStructureText = "保存中...";
      saveStructureColor = clrOrange;
     }
   else if(opportunitySaveFeedbackState == "ANALYZED")
     {
      saveStructureText = "分析通过";
      saveStructureColor = clrDeepSkyBlue;
     }
   else if(opportunitySaveFeedbackState == "REVIEW")
     {
      saveStructureText = "待复核";
      saveStructureColor = clrOrange;
     }
   else if(opportunitySaveFeedbackState == "SUCCESS")
     {
      saveStructureText = "保存成功";
      saveStructureColor = clrGreen;
     }
   else if(opportunitySaveFeedbackState == "FAILURE")
     {
      saveStructureText = "保存失败";
      saveStructureColor = clrRed;
     }
   SetOpportunityButtonColor(OBJ_FULL_BTN_SAVE_STRUCTURE, saveStructureColor);
   if(ObjectFind(0, OBJ_FULL_BTN_SAVE_STRUCTURE) >= 0)
      ObjectSetString(0, OBJ_FULL_BTN_SAVE_STRUCTURE, OBJPROP_TEXT, saveStructureText);
   if(ObjectFind(0, OBJ_FULL_STRUCTURE_SIZE) >= 0)
      ObjectSetString(0, OBJ_FULL_STRUCTURE_SIZE, OBJPROP_TEXT,
                      "R=" + IntegerToString(opportunityStructureRadiusBars));

   int upperCount = CountOpportunityLineAnchors(0, 1);
   int lowerCount = CountOpportunityLineAnchors(2, 3);
   color upperColor = (upperCount == 2) ? clrDarkGreen : clrFireBrick;
   color lowerColor = (lowerCount == 2) ? clrDarkGreen : clrSteelBlue;
   if(opportunityAnnotationMode == "UPPER") upperColor = clrOrange;
   if(opportunityAnnotationMode == "LOWER") lowerColor = clrOrange;
   SetOpportunityButtonColor(OBJ_FULL_BTN_UPPER, upperColor);
   SetOpportunityButtonColor(OBJ_FULL_BTN_LOWER, lowerColor);
   SetOpportunityButtonColor(OBJ_FULL_BTN_UNDO, clrDarkGoldenrod);
   SetOpportunityButtonColor(OBJ_FULL_BTN_CLEAR_CHART, clrDarkSlateGray);

   string statusText = " ";
   if(opportunitySaveFeedbackState == "ANALYZED")
      statusText = "分析通过 | 未保存";
   else if(opportunitySaveFeedbackState == "REVIEW")
      statusText = "待复核 | 未保存";
   else if(opportunitySaveFeedbackState == "SUCCESS")
      statusText = "保存成功";
   else if(opportunitySaveFeedbackState == "FAILURE")
      statusText = "保存失败";

   if(ObjectFind(0, OBJ_FULL_ANNOTATION_STATUS) >= 0)
      ObjectSetString(0, OBJ_FULL_ANNOTATION_STATUS, OBJPROP_TEXT, statusText);
  }

bool AdjustOpportunityStructureRadius(long chartID, int delta)
  {
   int previousRadius = opportunityStructureRadiusBars;
   int nextRadius = ClampOpportunityStructureRadius(previousRadius + delta);
   if(nextRadius == previousRadius)
     {
      Print("[EA|FULL|ANNOT] WARN structure radius limit reached | radius=", previousRadius,
            " | min=", OPPORTUNITY_STRUCTURE_RADIUS_MIN,
            " | max=", OPPORTUNITY_STRUCTURE_RADIUS_MAX);
      UpdateOpportunityAnnotationPanel();
      return false;
     }

   opportunityStructureRadiusBars = nextRadius;
   bool recalculated = true;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      opportunityStructures[i].radiusBars = nextRadius;
      if(!RecalculateOpportunityStructure(chartID, i, true)) recalculated = false;
     }

   DrawOpportunityAnnotations(chartID);
   bool saved = true;
   if(ArraySize(opportunityStructures) > 0) saved = SaveOpportunityAnnotation(chartID);
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO structure radius changed | case=", OpportunityCaseId(),
         " | old=", previousRadius, " | new=", nextRadius,
         " | structures=", ArraySize(opportunityStructures),
         " | recalculated=", (int)recalculated, " | saved=", (int)saved);
   return (recalculated && saved);
  }

void SetOpportunityAnnotationMode(string mode)
  {
   opportunityAnnotationMode = mode;
   opportunityModeSelectedTick = GetTickCount();
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO mode selected | case=", OpportunityCaseId(), " | mode=", mode);
  }

bool HandleOpportunityAnnotationButton(string objectName)
  {
   bool isAnnotationButton = (objectName == OBJ_FULL_BTN_STRUCTURE ||
                               objectName == OBJ_FULL_BTN_KEY_BAR ||
                               objectName == OBJ_FULL_BTN_SAVE_STRUCTURE ||
                               objectName == OBJ_FULL_BTN_SIZE_DOWN || objectName == OBJ_FULL_BTN_SIZE_UP ||
                               objectName == OBJ_FULL_BTN_UPPER ||
                               objectName == OBJ_FULL_BTN_LOWER || objectName == OBJ_FULL_BTN_UNDO ||
                               objectName == OBJ_FULL_BTN_CLEAR_CHART);
   if(!isAnnotationButton) return false;

   uint now = GetTickCount();
   if(objectName == opportunityLastButtonName && (now - opportunityLastButtonTick) < 250)
     {
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|ANNOT] INFO duplicate button event ignored | object=", objectName);
      return true;
     }
   opportunityLastButtonName = objectName;
   opportunityLastButtonTick = now;

   if(objectName == OBJ_FULL_BTN_CLEAR_CHART)
     {
      ClickFlash(objectName);
      StartNewOpportunityCase(ChartID());
      return true;
     }

   if(!opportunityChartViewVisible)
      RestoreOpportunityChartView(ChartID(), "annotation_button:" + objectName);

   if(opportunityAnnotationReadOnly)
     {
      if(objectName == OBJ_FULL_BTN_SAVE_STRUCTURE)
         SetOpportunityStructureSaveFeedback("FAILURE", "保存失败 | 只读周期",
                                             OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS);
      Print("[EA|FULL|ANNOT] WARN annotation is read-only outside native chart | case=", OpportunityCaseId(),
            " | native_symbol=", opportunityAnnotationNativeSymbol,
            " | native_timeframe=", opportunityAnnotationNativeTimeframe,
            " | chart_symbol=", ChartSymbol(ChartID()),
            " | chart_timeframe=", TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(ChartID())));
      return true;
     }

   if(!IsOpportunityTypeSupported(OpportunityCaseType()))
     {
      opportunityAnnotationMode = "";
      if(objectName == OBJ_FULL_BTN_SAVE_STRUCTURE)
         SetOpportunityStructureSaveFeedback("FAILURE", "保存失败 | 请先选择机会类型",
                                             OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS);
      else
         SetOpportunityCaseFeedback("请先选择机会类型",
                                    OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      Print("[EA|FULL|ANNOT] WARN annotation rejected; opportunity type not selected | case=",
            OpportunityCaseId(), " | object=", objectName,
            " | type=", OpportunityCaseType(),
            " | archive_touched=0");
      return true;
     }

   if(opportunityEditStructureIndex >= 0)
      SetOpportunityStructureEdit(ChartID(), -1, "annotation_button");

   if(PR_IsPureReleaseCaseType(OpportunityCaseType()) &&
      (objectName == OBJ_FULL_BTN_STRUCTURE ||
       objectName == OBJ_FULL_BTN_KEY_BAR ||
       objectName == OBJ_FULL_BTN_SIZE_DOWN ||
       objectName == OBJ_FULL_BTN_SIZE_UP ||
       objectName == OBJ_FULL_BTN_UPPER ||
       objectName == OBJ_FULL_BTN_LOWER ||
       objectName == OBJ_FULL_BTN_UNDO))
     {
      opportunityAnnotationMode = "";
      SetOpportunityCaseFeedback("纯释放草稿 | 结构与关键 Bar 不适用",
                                 OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      Print("[EA|FULL|PURE_RELEASE] INFO legacy annotation action blocked",
            " | case=", OpportunityCaseId(),
            " | object=", objectName,
            " | structure_applicability=NOT_APPLICABLE",
            " | key_bar_applicability=NOT_APPLICABLE",
            " | legacy_annotation_called=0 | archive_touched=0");
      return true;
     }

   if(objectName == OBJ_FULL_BTN_STRUCTURE)
     {
      ClickFlash(objectName);
      SetOpportunityAnnotationMode("STRUCT");
      return true;
     }

   if(objectName == OBJ_FULL_BTN_KEY_BAR)
     {
      ClickFlash(objectName);
      SetOpportunityAnnotationMode("KEY_BAR");
      return true;
     }

   if(objectName == OBJ_FULL_BTN_SAVE_STRUCTURE)
     {
      if(IsPureReleaseShadowDraft())
        {
         ClickFlash(objectName);
         bool shadowQualified = RunPureReleaseShadowPreflight(ChartID(), "save_button_shadow");
         string shadowText = "";
         if(shadowQualified)
            shadowText = "纯释放分析通过 | " + pureReleaseLastMarketDirection +
                         " | 正式保存未启用";
         else if(!pureReleaseLastAnalysisCompleted)
            shadowText = "纯释放分析失败 | " + pureReleaseLastReason +
                         " | 正式保存未启用";
         else if(pureReleaseLastQualityStatus == PR_QUALITY_REVIEW)
            shadowText = "纯释放分析完成 | 待复核 | " + pureReleaseLastReason +
                         " | 正式保存未启用";
         else
            shadowText = "纯释放分析完成 | 未通过 | " + pureReleaseLastReason +
                         " | 正式保存未启用";
         string shadowFeedbackState = !pureReleaseLastAnalysisCompleted ? "FAILURE" :
                                      (shadowQualified ? "ANALYZED" :
                                       (pureReleaseLastQualityStatus == PR_QUALITY_REVIEW ?
                                        "REVIEW" : "FAILURE"));
         SetOpportunityStructureSaveFeedback(shadowFeedbackState,
                                              shadowText,
                                              shadowQualified ? OPPORTUNITY_SAVE_FEEDBACK_SUCCESS_MS :
                                              OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS);
         Print("[EA|FULL|PURE_RELEASE|P2] INFO save button routed to shadow only",
               " | case=", OpportunityCaseId(),
               " | qualified=", (int)shadowQualified,
               " | analysis_completed=", (int)pureReleaseLastAnalysisCompleted,
               " | analysis_status=", pureReleaseLastStatus,
               " | reason=", pureReleaseLastReason,
               " | gap_status=", pureReleaseLastDataGapStatus,
               " | gap_reason=", pureReleaseLastDataGapReason,
               " | session_policy=", pureReleaseLastSessionPolicy,
               " | calendar_hours=", pureReleaseLastCalendarSpanHours,
               " | calendar_bars=", pureReleaseLastCalendarExpectedBars,
               " | actual_bars=", pureReleaseLastActualBars,
               " | expected_closure_gaps=", pureReleaseLastExpectedClosureGaps,
               " | expected_closure_hours=", pureReleaseLastExpectedClosureHours,
               " | unexpected_gaps=", pureReleaseLastUnexpectedGaps,
               " | first_gap_previous=", (long)pureReleaseLastFirstGapPrevious,
               " | first_gap_next=", (long)pureReleaseLastFirstGapNext,
               " | first_gap_hours=", pureReleaseLastFirstGapHours,
               " | market_direction=", pureReleaseLastMarketDirection,
               " | direction_agreement=", pureReleaseLastDirectionAgreement,
               " | quality_status=", pureReleaseLastQualityStatus,
               " | legacy_save_called=0 | archive_touched=0");
         return true;
        }
      if(PR_IsPureReleaseCaseType(OpportunityCaseType()))
        {
         SetOpportunityStructureSaveFeedback(
            "FAILURE", "纯释放旧格式案例 | 请新建案例后预检",
            OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS);
         Print("[EA|FULL|PURE_RELEASE] WARN legacy representation save blocked",
               " | case=", OpportunityCaseId(),
               " | type=", OpportunityCaseType(),
               " | catalog_index=", FindOpportunityCaseCatalogIndex(OpportunityCaseId()),
               " | archived_type=", opportunityArchivedCaseType,
               " | legacy_save_called=0 | archive_touched=0");
         return true;
        }
      opportunityAnnotationMode = "";
      SetOpportunityStructureSaveFeedback("SAVING", "保存中...", 0);
      string saveResultText = "";
      bool saved = SaveOpportunityStructureDrawings(ChartID(), saveResultText);
      if(saved)
         SetOpportunityStructureSaveFeedback("SUCCESS", saveResultText,
                                             OPPORTUNITY_SAVE_FEEDBACK_SUCCESS_MS);
      else
         SetOpportunityStructureSaveFeedback("FAILURE", saveResultText,
                                             OPPORTUNITY_SAVE_FEEDBACK_FAILURE_MS);
      return true;
     }

   if(objectName == OBJ_FULL_BTN_SIZE_DOWN || objectName == OBJ_FULL_BTN_SIZE_UP)
     {
      ClickFlash(objectName);
      opportunityAnnotationMode = "";
      int delta = (objectName == OBJ_FULL_BTN_SIZE_UP) ? 1 : -1;
      AdjustOpportunityStructureRadius(ChartID(), delta);
      return true;
     }

   if(objectName == OBJ_FULL_BTN_UPPER || objectName == OBJ_FULL_BTN_LOWER)
     {
      ClickFlash(objectName);
      string mode = (objectName == OBJ_FULL_BTN_UPPER) ? "UPPER" : "LOWER";
      int startIndex = (mode == "UPPER") ? 0 : 2;
      if(CountOpportunityLineAnchors(startIndex, startIndex + 1) >= 2)
        {
         Print("[EA|FULL|ANNOT] WARN line already has two endpoints; use UNDO before replacing | line=", mode);
         return true;
        }
      SetOpportunityAnnotationMode(mode);
      return true;
     }

   if(objectName == OBJ_FULL_BTN_UNDO)
     {
      ClickFlash(objectName);
      opportunityAnnotationMode = "";
      UndoOpportunityAnnotation(ChartID());
      return true;
     }

   return false;
  }

bool HandleOpportunityChartClick(long chartID, int mouseX, int mouseY)
  {
   if(StringLen(opportunityAnnotationMode) == 0) return false;
   if(PR_IsPureReleaseCaseType(OpportunityCaseType()))
     {
      string blockedMode = opportunityAnnotationMode;
      opportunityAnnotationMode = "";
      Print("[EA|FULL|PURE_RELEASE] WARN chart annotation blocked",
            " | case=", OpportunityCaseId(),
            " | mode=", blockedMode,
            " | legacy_annotation_called=0 | archive_touched=0");
      return true;
     }
   if((GetTickCount() - opportunityModeSelectedTick) < 250)
     {
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|ANNOT] INFO chart click ignored after button selection | mode=", opportunityAnnotationMode);
      return true;
     }

   int subWindow = 0;
   datetime clickedTime = 0;
   double clickedPrice = 0.0;
   ResetLastError();
   if(!ChartXYToTimePrice(chartID, mouseX, mouseY, subWindow, clickedTime, clickedPrice))
     {
      Print("[EA|FULL|ANNOT] ERROR chart coordinate conversion failed | x=", mouseX, " | y=", mouseY,
            " | err=", GetLastError());
      return true;
     }
   if(subWindow != 0)
     {
      Print("[EA|FULL|ANNOT] WARN click ignored outside main price window | subwindow=", subWindow);
      return true;
     }

   string symbol = ChartSymbol(chartID);
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   int barShift = iBarShift(symbol, timeframe, clickedTime, false);
   if(barShift < 0)
     {
      Print("[EA|FULL|ANNOT] ERROR bar lookup failed | symbol=", symbol, " | timeframe=", TimeframeName(timeframe),
            " | clicked_time=", TimeToString(clickedTime, TIME_DATE|TIME_MINUTES), " | err=", GetLastError());
      return true;
     }

   datetime barTime = iTime(symbol, timeframe, barShift);
   double barHigh = iHigh(symbol, timeframe, barShift);
   double barLow = iLow(symbol, timeframe, barShift);
   if(barTime <= 0 || barHigh <= 0.0 || barLow <= 0.0 || barHigh < barLow)
     {
       Print("[EA|FULL|ANNOT] ERROR invalid OHLC at clicked bar | shift=", barShift, " | time=", barTime,
            " | high=", barHigh, " | low=", barLow, " | err=", GetLastError());
      return true;
     }

   string capturedRole = "";
   if(opportunityAnnotationMode == "STRUCT")
     {
      int structureCount = ArraySize(opportunityStructures);
      if(structureCount > 0 && clickedTime <= opportunityStructures[structureCount - 1].centerTime)
        {
         Print("[EA|FULL|ANNOT] WARN structure center must be later than previous structure | next=S",
               structureCount + 1, " | time=", TimeToString(clickedTime, TIME_DATE|TIME_MINUTES),
               " | previous=", TimeToString(opportunityStructures[structureCount - 1].centerTime, TIME_DATE|TIME_MINUTES));
         return true;
        }

      ArrayResize(opportunityStructures, structureCount + 1);
      opportunityStructures[structureCount].role = "S" + IntegerToString(structureCount + 1);
      opportunityStructures[structureCount].centerTime = clickedTime;
      opportunityStructures[structureCount].centerPrice = NormalizeDouble(clickedPrice, _Digits);
      opportunityStructures[structureCount].centerBarShift = barShift;
      opportunityStructures[structureCount].radiusBars = opportunityStructureRadiusBars;
      opportunityStructures[structureCount].representativeType = "";
      opportunityStructures[structureCount].actionSequence = opportunityNextActionSequence;
      if(!RecalculateOpportunityStructure(chartID, structureCount, false))
        {
         ArrayResize(opportunityStructures, structureCount);
         opportunityAnnotationMode = "";
         UpdateOpportunityAnnotationPanel();
         return true;
        }

      opportunityNextActionSequence++;
      capturedRole = opportunityStructures[structureCount].role;
      Print("[EA|FULL|ANNOT] INFO structure captured | case=", OpportunityCaseId(),
            " | role=", capturedRole,
            " | center_time=", TimeToString(opportunityStructures[structureCount].centerTime, TIME_DATE|TIME_MINUTES),
            " | center_price=", DoubleToString(opportunityStructures[structureCount].centerPrice, _Digits),
            " | radius=", opportunityStructures[structureCount].radiusBars,
            " | range=", TimeToString(opportunityStructures[structureCount].rangeStartTime, TIME_DATE|TIME_MINUTES),
            "..", TimeToString(opportunityStructures[structureCount].rangeEndTime, TIME_DATE|TIME_MINUTES),
             " | circle_price=", DoubleToString(opportunityStructures[structureCount].circleLow, _Digits),
             "..", DoubleToString(opportunityStructures[structureCount].circleHigh, _Digits),
             " | derived_representative=", opportunityStructures[structureCount].representativeType,
            "@", TimeToString(opportunityStructures[structureCount].representativeTime, TIME_DATE|TIME_MINUTES),
            "/", DoubleToString(opportunityStructures[structureCount].representativePrice, _Digits));
      opportunityAnnotationMode = "";
     }
   else if(opportunityAnnotationMode == "KEY_BAR")
     {
      double barOpen = iOpen(symbol, timeframe, barShift);
      double barClose = iClose(symbol, timeframe, barShift);
      int secondsPerBar = PeriodSeconds(timeframe);
      if(barOpen <= 0.0 || barClose <= 0.0 || secondsPerBar <= 0)
        {
         Print("[EA|FULL|ANNOT] ERROR invalid key bar data | shift=", barShift,
               " | time=", TimeToString(barTime, TIME_DATE|TIME_MINUTES),
               " | open=", DoubleToString(barOpen, _Digits),
               " | close=", DoubleToString(barClose, _Digits),
               " | seconds_per_bar=", secondsPerBar, " | err=", GetLastError());
         opportunityAnnotationMode = "";
         UpdateOpportunityAnnotationPanel();
         return true;
        }

      datetime confirmTime = (datetime)((long)barTime + secondsPerBar);

      opportunityKeyBar.role = "RELEASE_BAR";
      opportunityKeyBar.barTime = barTime;
      opportunityKeyBar.confirmTime = confirmTime;
      opportunityKeyBar.highlightStartTime = (datetime)((long)barTime - secondsPerBar / 2);
      opportunityKeyBar.highlightEndTime = (datetime)((long)barTime + secondsPerBar / 2);
      opportunityKeyBar.openPrice = NormalizeDouble(barOpen, _Digits);
      opportunityKeyBar.highPrice = NormalizeDouble(barHigh, _Digits);
      opportunityKeyBar.lowPrice = NormalizeDouble(barLow, _Digits);
      opportunityKeyBar.closePrice = NormalizeDouble(barClose, _Digits);
      opportunityKeyBar.barShift = barShift;
      opportunityKeyBar.direction = (barClose > barOpen) ? "BULL" : ((barClose < barOpen) ? "BEAR" : "DOJI");
      opportunityKeyBar.actionSequence = opportunityNextActionSequence++;
      opportunityKeyBar.active = true;
      capturedRole = opportunityKeyBar.role;
      Print("[EA|FULL|ANNOT] INFO key bar captured | case=", OpportunityCaseId(),
            " | role=", opportunityKeyBar.role,
            " | time=", TimeToString(opportunityKeyBar.barTime, TIME_DATE|TIME_MINUTES),
            " | confirm_time=", TimeToString(opportunityKeyBar.confirmTime, TIME_DATE|TIME_MINUTES),
            " | ohlc=", DoubleToString(opportunityKeyBar.openPrice, _Digits), "/",
            DoubleToString(opportunityKeyBar.highPrice, _Digits), "/",
            DoubleToString(opportunityKeyBar.lowPrice, _Digits), "/",
            DoubleToString(opportunityKeyBar.closePrice, _Digits),
            " | direction=", opportunityKeyBar.direction,
            " | shift=", opportunityKeyBar.barShift,
            " | sequence=", opportunityKeyBar.actionSequence);
      opportunityAnnotationMode = "";
     }
   else
     {
      int targetIndex = -1;
      string snapType = "";
      double snapPrice = 0.0;
      if(opportunityAnnotationMode == "UPPER")
        {
         targetIndex = !opportunityLineAnchors[0].active ? 0 : 1;
         snapType = "HIGH";
         snapPrice = barHigh;
        }
      else if(opportunityAnnotationMode == "LOWER")
        {
         targetIndex = !opportunityLineAnchors[2].active ? 2 : 3;
         snapType = "LOW";
         snapPrice = barLow;
        }

      if(targetIndex < 0 || targetIndex >= OPPORTUNITY_LINE_ANCHOR_COUNT)
        {
         Print("[EA|FULL|ANNOT] ERROR no target anchor for active mode | mode=", opportunityAnnotationMode);
         opportunityAnnotationMode = "";
         UpdateOpportunityAnnotationPanel();
         return true;
        }
      if(targetIndex == 1 && barTime <= opportunityLineAnchors[0].barTime)
        {
         Print("[EA|FULL|ANNOT] WARN UPPER endpoint 2 must be later than endpoint 1");
         return true;
        }
      if(targetIndex == 3 && barTime <= opportunityLineAnchors[2].barTime)
        {
         Print("[EA|FULL|ANNOT] WARN LOWER endpoint 2 must be later than endpoint 1");
         return true;
        }

      opportunityLineAnchors[targetIndex].barTime = barTime;
      opportunityLineAnchors[targetIndex].price = NormalizeDouble(snapPrice, _Digits);
      opportunityLineAnchors[targetIndex].snapType = snapType;
      opportunityLineAnchors[targetIndex].barShift = barShift;
      opportunityLineAnchors[targetIndex].actionSequence = opportunityNextActionSequence++;
      opportunityLineAnchors[targetIndex].active = true;
      capturedRole = opportunityLineAnchors[targetIndex].role;
      Print("[EA|FULL|ANNOT] INFO line anchor captured | case=", OpportunityCaseId(),
            " | role=", capturedRole,
            " | time=", TimeToString(barTime, TIME_DATE|TIME_MINUTES),
            " | price=", DoubleToString(opportunityLineAnchors[targetIndex].price, _Digits),
            " | snap=", snapType, " | shift=", barShift);

      bool keepLineMode = ((opportunityAnnotationMode == "UPPER" && targetIndex == 0) ||
                           (opportunityAnnotationMode == "LOWER" && targetIndex == 2));
      if(!keepLineMode) opportunityAnnotationMode = "";
     }
   DrawOpportunityAnnotations(chartID);
   bool saved = SaveOpportunityAnnotation(chartID);
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO capture result | role=", capturedRole,
         " | saved=", (int)saved, " | next_mode=", opportunityAnnotationMode);
   return true;
  }

void ConfigureOpportunityObject(long chartID, string objectName, color objectColor, ENUM_LINE_STYLE style, int width)
  {
   ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, objectColor);
   ObjectSetInteger(chartID, objectName, OBJPROP_STYLE, style);
   ObjectSetInteger(chartID, objectName, OBJPROP_WIDTH, width);
   ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, false);
  }

bool CreateOpportunityObject(long chartID,
                             string objectName,
                             ENUM_OBJECT objectType,
                             datetime time1,
                             double price1,
                             datetime time2 = 0,
                             double price2 = 0.0)
  {
   ResetLastError();
   bool created = ObjectCreate(chartID, objectName, objectType, 0, time1, price1, time2, price2);
   if(!created)
     {
      Print("[EA|FULL|ANNOT] ERROR object create failed | name=", objectName,
            " | type=", (int)objectType, " | err=", GetLastError());
     }
   return created;
  }

bool DeleteOpportunityObjectWithResource(long chartID, string objectName)
  {
   if(ObjectFind(chartID, objectName) < 0) return true;

   string resourceName = "";
   ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
   if(objectType == OBJ_BITMAP || objectType == OBJ_BITMAP_LABEL)
      resourceName = ObjectGetString(chartID, objectName, OBJPROP_BMPFILE);

   ResetLastError();
   if(!ObjectDelete(chartID, objectName))
     {
      Print("[EA|FULL|ANNOT] ERROR object delete failed | name=", objectName,
            " | err=", GetLastError());
      return false;
     }

   if(StringFind(resourceName, "::") == 0)
     {
      ResetLastError();
      if(!ResourceFree(resourceName))
        {
         Print("[EA|FULL|ANNOT] ERROR bitmap resource free failed | name=", objectName,
               " | resource=", resourceName, " | err=", GetLastError());
         return false;
        }
     }
   return true;
  }

bool DeleteAllOpportunityDisplayObjects(long chartID, string reason)
  {
   if(chartID == 0) return false;

   int total = ObjectsTotal(chartID, -1, -1);
   int matched = 0;
   int deleted = 0;
   int failed = 0;
   int annotationObjects = 0;
   int drawingObjects = 0;
   int regionObjects = 0;
   int geometryObjects = 0;
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      bool isAnnotation = (StringFind(objectName, OPPORTUNITY_OBJECT_PREFIX) == 0);
      bool isDrawing = (StringFind(objectName, OPPORTUNITY_DRAWING_OBJECT_PREFIX) == 0);
      bool isRegion = (StringFind(objectName, OPPORTUNITY_REGION_OBJECT_PREFIX) == 0);
      bool isGeometry = (StringFind(objectName, OPPORTUNITY_GEOMETRY_OBJECT_PREFIX) == 0);
      if(!isAnnotation && !isDrawing && !isRegion && !isGeometry) continue;

      matched++;
      if(isAnnotation) annotationObjects++;
      else if(isDrawing) drawingObjects++;
      else if(isRegion) regionObjects++;
      else geometryObjects++;

      if(DeleteOpportunityObjectWithResource(chartID, objectName)) deleted++;
      else failed++;
     }

   Print("[EA|FULL|DISPLAY] ", failed == 0 ? "INFO" : "ERROR",
         " cleanup result | reason=", reason,
         " | matched=", matched,
         " | deleted=", deleted,
         " | failed=", failed,
         " | annotation=", annotationObjects,
         " | drawings=", drawingObjects,
         " | regions=", regionObjects,
         " | geometry=", geometryObjects,
         " | active_case=", OpportunityCaseId(),
         " | archive_touched=0");
   return (failed == 0);
  }

void DeleteOpportunityAnnotationObjects(long chartID)
  {
   string prefix = OpportunityObjectPrefix();
   int total = ObjectsTotal(chartID, -1, -1);
   int deleted = 0;
   int failed = 0;
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, prefix) != 0) continue;
      if(DeleteOpportunityObjectWithResource(chartID, objectName)) deleted++;
      else failed++;
     }
   if(GV_DEBUG_FULL && (deleted > 0 || failed > 0))
       Print("[EA|FULL|ANNOT] INFO drawing cleanup | deleted=", deleted, " | failed=", failed);
  }

string OpportunityDrawingObjectPrefix()
  {
   string annotationPrefix = OpportunityObjectPrefix();
   return OPPORTUNITY_DRAWING_OBJECT_PREFIX +
          StringSubstr(annotationPrefix, StringLen(OPPORTUNITY_OBJECT_PREFIX));
  }

string OpportunityGeometryObjectPrefix()
  {
   string annotationPrefix = OpportunityObjectPrefix();
   return OPPORTUNITY_GEOMETRY_OBJECT_PREFIX +
          StringSubstr(annotationPrefix, StringLen(OPPORTUNITY_OBJECT_PREFIX));
  }

string OpportunityRegionObjectPrefix()
  {
   string annotationPrefix = OpportunityObjectPrefix();
   return OPPORTUNITY_REGION_OBJECT_PREFIX +
          StringSubstr(annotationPrefix, StringLen(OPPORTUNITY_OBJECT_PREFIX));
  }

string OpportunityRegionRole(int index)
  {
   if(index == 0) return "PRE_ACCUMULATION_RELEASE";
   if(index == 1) return "ACCUMULATION";
   if(index == 2) return "POST_ACCUMULATION_RELEASE";
   return "";
  }

string OpportunityRegionDisplayName(int index)
  {
   if(index == 0) return "积累前释放区";
   if(index == 1) return "积累区";
   if(index == 2) return "积累后释放区";
   return "";
  }

int OpportunityDrawingAnchorCount(ENUM_OBJECT objectType)
  {
   switch(objectType)
     {
      case OBJ_VLINE:
      case OBJ_HLINE:
      case OBJ_TRENDBYANGLE:
      case OBJ_ARROW_THUMB_UP:
      case OBJ_ARROW_THUMB_DOWN:
      case OBJ_ARROW_UP:
      case OBJ_ARROW_DOWN:
      case OBJ_ARROW_STOP:
      case OBJ_ARROW_CHECK:
      case OBJ_ARROW_LEFT_PRICE:
      case OBJ_ARROW_RIGHT_PRICE:
      case OBJ_ARROW_BUY:
      case OBJ_ARROW_SELL:
      case OBJ_ARROW:
      case OBJ_TEXT:
         return 1;

      case OBJ_TREND:
      case OBJ_CYCLES:
      case OBJ_ARROWED_LINE:
      case OBJ_STDDEVCHANNEL:
      case OBJ_REGRESSION:
      case OBJ_GANNLINE:
      case OBJ_GANNFAN:
      case OBJ_GANNGRID:
      case OBJ_FIBO:
      case OBJ_FIBOTIMES:
      case OBJ_FIBOFAN:
      case OBJ_FIBOARC:
      case OBJ_RECTANGLE:
         return 2;

      case OBJ_CHANNEL:
      case OBJ_PITCHFORK:
      case OBJ_FIBOCHANNEL:
      case OBJ_EXPANSION:
      case OBJ_TRIANGLE:
      case OBJ_ELLIPSE:
         return 3;
     }
   return 0;
  }

bool IsOpportunityDrawingInternalObject(string objectName)
  {
   if(StringFind(objectName, OPPORTUNITY_OBJECT_PREFIX) == 0) return true;
   if(StringFind(objectName, OPPORTUNITY_REGION_OBJECT_PREFIX) == 0) return true;
   if(StringFind(objectName, OPPORTUNITY_GEOMETRY_OBJECT_PREFIX) == 0) return true;
   if(StringFind(objectName, ACC_OBJECT_PREFIX) == 0) return true;

   string managedPrefix = OpportunityDrawingObjectPrefix();
   if(StringFind(objectName, OPPORTUNITY_DRAWING_OBJECT_PREFIX) == 0 &&
      StringFind(objectName, managedPrefix) != 0)
      return true;
   return false;
  }

void SetOpportunityDrawingAnchor(OpportunityDrawingState &drawing,
                                 int anchorIndex,
                                 datetime anchorTime,
                                 double anchorPrice)
  {
   if(anchorIndex == 0)
     {
      drawing.time1 = anchorTime;
      drawing.price1 = anchorPrice;
     }
   else if(anchorIndex == 1)
     {
      drawing.time2 = anchorTime;
      drawing.price2 = anchorPrice;
     }
   else if(anchorIndex == 2)
     {
      drawing.time3 = anchorTime;
      drawing.price3 = anchorPrice;
     }
  }

void ResetOpportunityDrawingSemanticFields(OpportunityDrawingState &drawing)
  {
   drawing.semanticRole = "";
   drawing.pathId = "";
   drawing.segmentOrder = 0;
   drawing.anchor1Role = "";
   drawing.anchor2Role = "";
   drawing.semanticSource = "";
   drawing.semanticConfirmed = false;
  }

void OpportunityColorToHsv(color objectColor,
                           double &hue,
                           double &saturation,
                           double &value)
  {
   int packedColor = (int)objectColor;
   double red = (double)(packedColor & 0xFF) / 255.0;
   double green = (double)((packedColor >> 8) & 0xFF) / 255.0;
   double blue = (double)((packedColor >> 16) & 0xFF) / 255.0;
   double maximum = MathMax(red, MathMax(green, blue));
   double minimum = MathMin(red, MathMin(green, blue));
   double delta = maximum - minimum;

   hue = 0.0;
   if(delta > 0.0)
     {
      if(maximum == red)
         hue = 60.0 * MathMod((green - blue) / delta, 6.0);
      else if(maximum == green)
         hue = 60.0 * (((blue - red) / delta) + 2.0);
      else
         hue = 60.0 * (((red - green) / delta) + 4.0);
      if(hue < 0.0) hue += 360.0;
     }
   saturation = maximum <= 0.0 ? 0.0 : delta / maximum;
   value = maximum;
  }

bool IsOpportunityPreReleasePathColor(color objectColor)
  {
   double hue = 0.0;
   double saturation = 0.0;
   double value = 0.0;
   OpportunityColorToHsv(objectColor, hue, saturation, value);
   return (hue >= 265.0 && hue <= 330.0 &&
           saturation >= 0.35 && value >= 0.25);
  }

bool IsOpportunityStructureLineColor(color objectColor)
  {
   double hue = 0.0;
   double saturation = 0.0;
   double value = 0.0;
   OpportunityColorToHsv(objectColor, hue, saturation, value);
   bool redHue = (hue >= 345.0 || hue <= 25.0);
   return (redHue && saturation >= 0.45 && value >= 0.30);
  }

int FindOpportunityStructureForDrawingAnchor(datetime anchorTime, double anchorPrice)
  {
   if(anchorTime <= 0 || anchorPrice <= 0.0) return -1;

   int bestIndex = -1;
   double bestScore = 1.0e100;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      datetime rangeStart = opportunityStructures[i].rangeStartTime;
      datetime rangeEnd = opportunityStructures[i].rangeEndTime;
      if(rangeStart <= 0) rangeStart = opportunityStructures[i].centerTime;
      if(rangeEnd < rangeStart) rangeEnd = rangeStart;
      double timeSpan = MathMax(1.0, (double)(rangeEnd - rangeStart));
      long timePadding = (long)MathMax(3600.0, timeSpan * 0.50);

      double priceLow = opportunityStructures[i].circleLow;
      double priceHigh = opportunityStructures[i].circleHigh;
      if(priceHigh < priceLow)
        {
         double swapPrice = priceLow;
         priceLow = priceHigh;
         priceHigh = swapPrice;
        }
      if(priceHigh <= priceLow)
        {
         priceLow = opportunityStructures[i].centerPrice;
         priceHigh = opportunityStructures[i].centerPrice;
        }
      double priceSpan = MathMax(_Point, priceHigh - priceLow);
      double pricePadding = MathMax(_Point * 10.0, priceSpan * 0.50);

      if(anchorTime < rangeStart - timePadding || anchorTime > rangeEnd + timePadding ||
         anchorPrice < priceLow - pricePadding || anchorPrice > priceHigh + pricePadding)
         continue;

      double timeScore = MathAbs((double)(anchorTime - opportunityStructures[i].centerTime)) /
                         MathMax(1.0, timeSpan * 0.50);
      double priceScore = MathAbs(anchorPrice - opportunityStructures[i].centerPrice) /
                          MathMax(_Point, priceSpan * 0.50);
      double score = timeScore + priceScore;
      if(score < bestScore)
        {
         bestScore = score;
         bestIndex = i;
        }
     }
   return bestIndex;
  }

void ApplyOpportunityDrawingSemanticConvention(OpportunityDrawingState &drawing)
  {
   if(drawing.objectType != OBJ_TREND) return;

   if(StringLen(drawing.semanticRole) == 0)
     {
      if(IsOpportunityPreReleasePathColor(drawing.objectColor))
        {
         drawing.semanticRole = "PRE_ACCUMULATION_RELEASE_PATH";
         drawing.pathId = "R1_RELEASE_PATH";
         drawing.semanticSource = "MANUAL_COLOR_FAMILY_CONVENTION";
         drawing.semanticConfirmed = true;
        }
      else if(IsOpportunityStructureLineColor(drawing.objectColor))
        {
         drawing.semanticRole = "STRUCTURE_LINE";
         drawing.pathId = "STRUCTURE_GRAPH";
         drawing.semanticSource = "MANUAL_COLOR_FAMILY_CONVENTION";
         drawing.semanticConfirmed = true;
        }
     }

   if(drawing.semanticRole != "STRUCTURE_LINE") return;
   if(StringLen(drawing.anchor1Role) == 0)
     {
      int anchor1Index = FindOpportunityStructureForDrawingAnchor(drawing.time1, drawing.price1);
      if(anchor1Index >= 0) drawing.anchor1Role = opportunityStructures[anchor1Index].role;
     }
   if(StringLen(drawing.anchor2Role) == 0)
     {
      int anchor2Index = FindOpportunityStructureForDrawingAnchor(drawing.time2, drawing.price2);
      if(anchor2Index >= 0) drawing.anchor2Role = opportunityStructures[anchor2Index].role;
     }
  }

datetime OpportunityDrawingSemanticSortTime(OpportunityDrawingState &drawing)
  {
   if(drawing.time1 <= 0) return drawing.time2;
   if(drawing.time2 <= 0) return drawing.time1;
   return MathMin(drawing.time1, drawing.time2);
  }

void FinalizeOpportunityDrawingSemantics(OpportunityDrawingState &drawings[])
  {
   int count = ArraySize(drawings);
   for(int i = 0; i < count; i++)
      ApplyOpportunityDrawingSemanticConvention(drawings[i]);

   for(int i = 0; i < count; i++)
     {
      if(drawings[i].semanticRole != "PRE_ACCUMULATION_RELEASE_PATH") continue;
      datetime sortTime = OpportunityDrawingSemanticSortTime(drawings[i]);
      int rank = 1;
      for(int j = 0; j < count; j++)
        {
         if(i == j || drawings[j].semanticRole != "PRE_ACCUMULATION_RELEASE_PATH") continue;
         datetime otherTime = OpportunityDrawingSemanticSortTime(drawings[j]);
         if(otherTime < sortTime ||
            (otherTime == sortTime && StringCompare(drawings[j].drawingId, drawings[i].drawingId) < 0))
            rank++;
        }
      drawings[i].pathId = "R1_RELEASE_PATH";
      drawings[i].segmentOrder = rank;
      drawings[i].semanticConfirmed = true;
     }
  }

double ClampOpportunityGeometryScore(double value)
  {
   if(value < 0.0) return 0.0;
   if(value > 1.0) return 1.0;
   return value;
  }

bool IsOpportunityGeometryChannelType(string caseType)
  {
   return (caseType == "ASCENDING_CHANNEL" || caseType == "DESCENDING_CHANNEL");
  }

int FindOpportunityGeometryRegion(OpportunityRegionState &regions[], string role)
  {
   for(int i = 0; i < ArraySize(regions); i++)
      if(regions[i].role == role && regions[i].startTime > 0 &&
         regions[i].endTime > regions[i].startTime)
         return i;
   return -1;
  }

bool ResolveOpportunityGeometryShiftRange(string symbolName,
                                          datetime startTime,
                                          datetime endTime,
                                          int &olderShift,
                                          int &newerShift)
  {
   olderShift = -1;
   newerShift = -1;
   if(StringLen(symbolName) == 0 || startTime <= 0 || endTime <= 0) return false;
   if(endTime < startTime)
     {
      datetime swapTime = startTime;
      startTime = endTime;
      endTime = swapTime;
     }

   ResetLastError();
   int startShift = iBarShift(symbolName, PERIOD_H1, startTime, false);
   int startError = GetLastError();
   ResetLastError();
   int endShift = iBarShift(symbolName, PERIOD_H1, endTime, false);
   int endError = GetLastError();
   if(startShift < 0 || endShift < 0)
     {
      Print("[EA|FULL|GEOMETRY] WARN H1 shift range unavailable | symbol=", symbolName,
            " | range=", TimeToString(startTime, TIME_DATE|TIME_MINUTES),
            "..", TimeToString(endTime, TIME_DATE|TIME_MINUTES),
            " | shifts=", startShift, "/", endShift,
            " | errors=", startError, "/", endError,
            " | archive_touched=0");
      return false;
     }

   olderShift = (startShift > endShift) ? startShift : endShift;
   newerShift = (startShift < endShift) ? startShift : endShift;
   return true;
  }

double OpportunityGeometryOverlapRatio(int olderShift,
                                       int newerShift,
                                       int regionOlderShift,
                                       int regionNewerShift)
  {
   if(olderShift < newerShift || regionOlderShift < regionNewerShift) return 0.0;
   int intersectionOlder = (olderShift < regionOlderShift) ? olderShift : regionOlderShift;
   int intersectionNewer = (newerShift > regionNewerShift) ? newerShift : regionNewerShift;
   if(intersectionOlder < intersectionNewer) return 0.0;
   int totalBars = olderShift - newerShift + 1;
   int intersectionBars = intersectionOlder - intersectionNewer + 1;
   if(totalBars <= 0 || intersectionBars <= 0) return 0.0;
   return ClampOpportunityGeometryScore((double)intersectionBars / (double)totalBars);
  }

bool CalculateOpportunityGeometryReferenceAtr(string symbolName,
                                               datetime startTime,
                                               datetime endTime,
                                               double &referenceAtr,
                                               int &sampleCount)
  {
   referenceAtr = 0.0;
   sampleCount = 0;
   int olderShift = -1;
   int newerShift = -1;
   if(!ResolveOpportunityGeometryShiftRange(symbolName, startTime, endTime,
                                            olderShift, newerShift))
      return false;

   double trueRanges[];
   for(int shift = olderShift; shift >= newerShift; shift--)
     {
      double highPrice = iHigh(symbolName, PERIOD_H1, shift);
      double lowPrice = iLow(symbolName, PERIOD_H1, shift);
      if(highPrice <= 0.0 || lowPrice <= 0.0 || highPrice < lowPrice) continue;
      double trueRange = highPrice - lowPrice;
      double previousClose = iClose(symbolName, PERIOD_H1, shift + 1);
      if(previousClose > 0.0)
        {
         trueRange = MathMax(trueRange, MathAbs(highPrice - previousClose));
         trueRange = MathMax(trueRange, MathAbs(lowPrice - previousClose));
        }
      if(trueRange <= 0.0) continue;
      ArrayResize(trueRanges, sampleCount + 1);
      trueRanges[sampleCount] = trueRange;
      sampleCount++;
     }
   if(sampleCount <= 0) return false;

   ArraySort(trueRanges);
   int middle = sampleCount / 2;
   if((sampleCount % 2) == 1)
      referenceAtr = trueRanges[middle];
   else
      referenceAtr = (trueRanges[middle - 1] + trueRanges[middle]) * 0.5;
   return (referenceAtr > 0.0 && MathIsValidNumber(referenceAtr));
  }

bool CalculateOpportunityGeometryPathMetrics(string symbolName,
                                              OpportunityDrawingState &drawing,
                                              double referenceAtr,
                                              int &effectiveH1Bars,
                                              double &displacementAtr,
                                              double &slopeAtrPerBar,
                                              double &pathEfficiency,
                                              int &olderShift,
                                              int &newerShift)
  {
   effectiveH1Bars = 0;
   displacementAtr = 0.0;
   slopeAtrPerBar = 0.0;
   pathEfficiency = 0.0;
   if(referenceAtr <= 0.0 || !MathIsValidNumber(referenceAtr)) return false;
   if(!ResolveOpportunityGeometryShiftRange(symbolName, drawing.time1, drawing.time2,
                                            olderShift, newerShift))
      return false;

   effectiveH1Bars = olderShift - newerShift + 1;
   if(effectiveH1Bars <= 0) return false;
   double displacement = MathAbs(drawing.price2 - drawing.price1);
   displacementAtr = displacement / referenceAtr;
   slopeAtrPerBar = displacementAtr / (double)effectiveH1Bars;

   double closePath = 0.0;
   bool previousAvailable = false;
   double previousClose = 0.0;
   double chronologicalStartPrice = (drawing.time1 <= drawing.time2) ?
                                    drawing.price1 : drawing.price2;
   double chronologicalEndPrice = (drawing.time1 <= drawing.time2) ?
                                  drawing.price2 : drawing.price1;
   for(int shift = olderShift; shift >= newerShift; shift--)
     {
      double closePrice = iClose(symbolName, PERIOD_H1, shift);
      if(closePrice <= 0.0) continue;
      if(previousAvailable)
         closePath += MathAbs(closePrice - previousClose);
      else
         closePath += MathAbs(closePrice - chronologicalStartPrice);
      previousClose = closePrice;
      previousAvailable = true;
     }
   if(previousAvailable)
      closePath += MathAbs(chronologicalEndPrice - previousClose);
   if(closePath > 0.0)
      pathEfficiency = ClampOpportunityGeometryScore(displacement / closePath);
   else if(displacement > 0.0)
      pathEfficiency = 1.0;
   return true;
  }

int FindFirstOpportunityStructureInRegion(datetime startTime, datetime endTime)
  {
   int firstIndex = -1;
   datetime firstTime = 0;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      datetime centerTime = opportunityStructures[i].centerTime;
      if(centerTime < startTime || centerTime > endTime) continue;
      if(firstIndex < 0 || centerTime < firstTime)
        {
         firstIndex = i;
         firstTime = centerTime;
        }
     }
   return firstIndex;
  }

datetime OpportunityStructureBoundaryTime(int structureIndex)
  {
   if(structureIndex < 0 || structureIndex >= ArraySize(opportunityStructures)) return 0;
   datetime boundaryTime = opportunityStructures[structureIndex].representativeTime;
   if(boundaryTime <= 0) boundaryTime = opportunityStructures[structureIndex].centerTime;
   return boundaryTime;
  }

int FindFirstOpportunityStructure()
  {
   int firstIndex = -1;
   datetime firstTime = 0;
   bool firstIsS1 = false;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      datetime boundaryTime = OpportunityStructureBoundaryTime(i);
      if(boundaryTime <= 0) continue;
      bool isS1 = (opportunityStructures[i].role == "S1");
      if(firstIndex < 0 || (isS1 && !firstIsS1) ||
         (isS1 == firstIsS1 && boundaryTime < firstTime))
        {
         firstIndex = i;
         firstTime = boundaryTime;
         firstIsS1 = isS1;
        }
     }
   return firstIndex;
  }

void EvaluateOpportunityGeometryEndpoint(string symbolName,
                                         datetime endpointTime,
                                         double endpointPrice,
                                         int structureIndex,
                                         double referenceAtr,
                                         bool &connected,
                                         double &timeDistanceBars,
                                         double &priceDistanceAtr)
  {
   connected = false;
   timeDistanceBars = 1.0e100;
   priceDistanceAtr = 1.0e100;
   if(structureIndex < 0 || structureIndex >= ArraySize(opportunityStructures) ||
      endpointTime <= 0 || endpointPrice <= 0.0)
      return;

   OpportunityStructureState structure = opportunityStructures[structureIndex];
   datetime rangeStart = structure.rangeStartTime;
   datetime rangeEnd = structure.rangeEndTime;
   if(rangeStart <= 0) rangeStart = structure.centerTime;
   if(rangeEnd < rangeStart) rangeEnd = rangeStart;

   int endpointShift = iBarShift(symbolName, PERIOD_H1, endpointTime, false);
   int centerShift = iBarShift(symbolName, PERIOD_H1, structure.centerTime, false);
   if(endpointShift >= 0 && centerShift >= 0)
      timeDistanceBars = (double)MathAbs(endpointShift - centerShift);
   else
      timeDistanceBars = MathAbs((double)(endpointTime - structure.centerTime)) / 3600.0;

   double priceRadius = MathMax(MathAbs(structure.centerPrice - structure.circleLow),
                                MathAbs(structure.circleHigh - structure.centerPrice));
   double symbolPoint = SymbolInfoDouble(symbolName, SYMBOL_POINT);
   if(symbolPoint <= 0.0) symbolPoint = _Point;
   if(priceRadius <= 0.0)
      priceRadius = MathMax(symbolPoint * 10.0,
                            MathAbs(structure.zoneHigh - structure.zoneLow) * 0.5);
   double priceDistance = MathAbs(endpointPrice - structure.centerPrice);
   if(referenceAtr > 0.0) priceDistanceAtr = priceDistance / referenceAtr;
   bool timeConnected = (endpointTime >= rangeStart && endpointTime <= rangeEnd);
   bool priceConnected = (priceDistance <= priceRadius * 1.5);
   connected = (timeConnected && priceConnected);
  }

void ResetOpportunityGeometryAdvice(OpportunityGeometryAdvice &advice)
  {
   advice.suggestedRole = "REVIEW_REQUIRED";
   advice.confidence = 0.0;
   advice.r1Overlap = 0.0;
   advice.r2Overlap = 0.0;
   advice.effectiveH1Bars = 0;
   advice.referenceAtr = 0.0;
   advice.displacementAtr = 0.0;
   advice.slopeAtrPerBar = 0.0;
   advice.pathEfficiency = 0.0;
   advice.firstStructureRole = "";
   advice.firstStructureConnected = false;
   advice.endpointTimeDistanceBars = 0.0;
   advice.endpointPriceDistanceAtr = 0.0;
   advice.channelExcluded = false;
   advice.evidence = "INSUFFICIENT_DATA";
  }

bool ApplyOpportunityP1TimeBoundary(OpportunityDrawingState &drawing,
                                    int firstStructureIndex,
                                    string symbolName,
                                    OpportunityGeometryAdvice &advice)
  {
   datetime boundaryTime = OpportunityStructureBoundaryTime(firstStructureIndex);
   if(boundaryTime <= 0) return false;
   advice.firstStructureRole = opportunityStructures[firstStructureIndex].role;
   datetime drawingStartTime = (drawing.time1 <= drawing.time2) ?
                               drawing.time1 : drawing.time2;
   datetime drawingEndTime = (drawing.time1 >= drawing.time2) ?
                             drawing.time1 : drawing.time2;
   if(drawingEndTime <= boundaryTime)
     {
      if(advice.channelExcluded)
        {
         advice.suggestedRole = "REVIEW_REQUIRED";
         advice.confidence = 1.0;
         advice.evidence = "CHANNEL_PRE_RELEASE_EXCLUDED";
         return true;
        }
      advice.suggestedRole = "PRE_ACCUMULATION_RELEASE_PATH";
      advice.confidence = 1.0;
      advice.evidence = "P1_TIME_BOUNDARY_PRE_RELEASE";
      return true;
     }
   if(drawingStartTime >= boundaryTime)
     {
      advice.suggestedRole = "STRUCTURE_LINE";
      advice.confidence = 1.0;
      advice.evidence = "P1_TIME_BOUNDARY_STRUCTURE";
      return true;
     }
   bool firstConnected = false;
   bool secondConnected = false;
   double firstTimeDistance = 0.0;
   double firstPriceDistance = 0.0;
   double secondTimeDistance = 0.0;
   double secondPriceDistance = 0.0;
   EvaluateOpportunityGeometryEndpoint(symbolName, drawing.time1, drawing.price1,
                                       firstStructureIndex, advice.referenceAtr,
                                       firstConnected, firstTimeDistance,
                                       firstPriceDistance);
   EvaluateOpportunityGeometryEndpoint(symbolName, drawing.time2, drawing.price2,
                                       firstStructureIndex, advice.referenceAtr,
                                       secondConnected, secondTimeDistance,
                                       secondPriceDistance);
   bool firstIsOlder = (drawing.time1 <= drawing.time2);
   bool olderConnected = firstIsOlder ? firstConnected : secondConnected;
   bool newerConnected = firstIsOlder ? secondConnected : firstConnected;
   advice.firstStructureConnected = (olderConnected || newerConnected);
   if(!olderConnected && newerConnected)
     {
      if(advice.channelExcluded)
        {
         advice.suggestedRole = "REVIEW_REQUIRED";
         advice.confidence = 1.0;
         advice.evidence = "CHANNEL_PRE_RELEASE_EXCLUDED";
         return true;
        }
      advice.suggestedRole = "PRE_ACCUMULATION_RELEASE_PATH";
      advice.confidence = 1.0;
      advice.evidence = "P1_ENDPOINT_TO_S1_PRE_RELEASE";
      return true;
     }
   if(olderConnected && !newerConnected)
     {
      advice.suggestedRole = "STRUCTURE_LINE";
      advice.confidence = 1.0;
      advice.evidence = "P1_S1_TO_ENDPOINT_STRUCTURE";
      return true;
     }
   advice.evidence = "P1_TIME_BOUNDARY_CROSSING";
   return false;
  }

bool BuildOpportunityGeometryAdvice(long chartID,
                                    OpportunityDrawingState &drawing,
                                    OpportunityRegionState &regions[],
                                    OpportunityGeometryAdvice &advice)
  {
   ResetOpportunityGeometryAdvice(advice);
   if(drawing.objectType != OBJ_TREND) return false;

   advice.channelExcluded = IsOpportunityGeometryChannelType(OpportunityCaseType());
   int firstStructureIndex = FindFirstOpportunityStructure();
   string symbolName = opportunityAnnotationNativeSymbol;
   if(StringLen(symbolName) == 0) symbolName = ChartSymbol(chartID);

   int r1Index = FindOpportunityGeometryRegion(regions, "PRE_ACCUMULATION_RELEASE");
   int r2Index = FindOpportunityGeometryRegion(regions, "ACCUMULATION");
   if(r1Index < 0 || r2Index < 0)
     {
       if(ApplyOpportunityP1TimeBoundary(drawing, firstStructureIndex,
                                         symbolName, advice)) return true;
      advice.evidence = "REGIONS_UNAVAILABLE";
      return true;
     }

   int r1OlderShift = -1;
   int r1NewerShift = -1;
   int r2OlderShift = -1;
   int r2NewerShift = -1;
   int drawingOlderShift = -1;
   int drawingNewerShift = -1;
   bool rangesReady =
      ResolveOpportunityGeometryShiftRange(symbolName,
                                           regions[r1Index].startTime,
                                           regions[r1Index].endTime,
                                           r1OlderShift, r1NewerShift) &&
      ResolveOpportunityGeometryShiftRange(symbolName,
                                           regions[r2Index].startTime,
                                           regions[r2Index].endTime,
                                           r2OlderShift, r2NewerShift);
   if(!rangesReady)
     {
       if(ApplyOpportunityP1TimeBoundary(drawing, firstStructureIndex,
                                         symbolName, advice)) return true;
      advice.evidence = "H1_REGION_DATA_UNAVAILABLE";
      return true;
     }
   if(r1OlderShift > r1NewerShift) r1NewerShift++;
   if(r2OlderShift > r2NewerShift) r2NewerShift++;

   int atrSamples = 0;
   if(!CalculateOpportunityGeometryReferenceAtr(symbolName,
                                                regions[r2Index].startTime,
                                                regions[r2Index].endTime,
                                                advice.referenceAtr,
                                                atrSamples))
     {
       if(ApplyOpportunityP1TimeBoundary(drawing, firstStructureIndex,
                                         symbolName, advice)) return true;
      advice.evidence = "ATR_UNAVAILABLE";
      return true;
     }
   if(!CalculateOpportunityGeometryPathMetrics(symbolName, drawing,
                                               advice.referenceAtr,
                                               advice.effectiveH1Bars,
                                               advice.displacementAtr,
                                               advice.slopeAtrPerBar,
                                               advice.pathEfficiency,
                                               drawingOlderShift,
                                               drawingNewerShift))
     {
       if(ApplyOpportunityP1TimeBoundary(drawing, firstStructureIndex,
                                         symbolName, advice)) return true;
      advice.evidence = "H1_PATH_DATA_UNAVAILABLE";
      return true;
     }

   advice.r1Overlap = OpportunityGeometryOverlapRatio(drawingOlderShift,
                                                      drawingNewerShift,
                                                      r1OlderShift,
                                                      r1NewerShift);
   advice.r2Overlap = OpportunityGeometryOverlapRatio(drawingOlderShift,
                                                      drawingNewerShift,
                                                      r2OlderShift,
                                                      r2NewerShift);
   if(firstStructureIndex >= 0)
     {
      advice.firstStructureRole = opportunityStructures[firstStructureIndex].role;
      bool firstConnected = false;
      bool secondConnected = false;
      double firstTimeDistance = 0.0;
      double firstPriceDistance = 0.0;
      double secondTimeDistance = 0.0;
      double secondPriceDistance = 0.0;
      EvaluateOpportunityGeometryEndpoint(symbolName, drawing.time1, drawing.price1,
                                          firstStructureIndex, advice.referenceAtr,
                                          firstConnected, firstTimeDistance,
                                          firstPriceDistance);
      EvaluateOpportunityGeometryEndpoint(symbolName, drawing.time2, drawing.price2,
                                          firstStructureIndex, advice.referenceAtr,
                                          secondConnected, secondTimeDistance,
                                          secondPriceDistance);
      advice.firstStructureConnected = (firstConnected || secondConnected);
      double firstScore = firstTimeDistance + firstPriceDistance;
      double secondScore = secondTimeDistance + secondPriceDistance;
      if(firstScore <= secondScore)
        {
         advice.endpointTimeDistanceBars = firstTimeDistance;
         advice.endpointPriceDistanceAtr = firstPriceDistance;
        }
      else
        {
         advice.endpointTimeDistanceBars = secondTimeDistance;
         advice.endpointPriceDistanceAtr = secondPriceDistance;
        }
     }

   if(ApplyOpportunityP1TimeBoundary(drawing, firstStructureIndex,
                                     symbolName, advice)) return true;

   bool preReleaseReady = (!advice.channelExcluded &&
                           advice.r1Overlap >= OPPORTUNITY_GEOMETRY_PRE_MIN_R1_OVERLAP &&
                           advice.firstStructureConnected &&
                           advice.displacementAtr >= OPPORTUNITY_GEOMETRY_PRE_MIN_DISPLACEMENT_ATR &&
                           advice.slopeAtrPerBar >= OPPORTUNITY_GEOMETRY_PRE_MIN_SLOPE_ATR &&
                           advice.pathEfficiency >= OPPORTUNITY_GEOMETRY_PRE_MIN_EFFICIENCY);
   if(preReleaseReady)
     {
      double displacementScore = ClampOpportunityGeometryScore(advice.displacementAtr / 15.0);
      double slopeScore = ClampOpportunityGeometryScore(advice.slopeAtrPerBar / 0.15);
      double efficiencyScore = ClampOpportunityGeometryScore(advice.pathEfficiency / 0.35);
      advice.suggestedRole = "PRE_ACCUMULATION_RELEASE_PATH";
      advice.confidence = ClampOpportunityGeometryScore(
         advice.r1Overlap * 0.30 + 0.30 + displacementScore * 0.15 +
         slopeScore * 0.15 + efficiencyScore * 0.10);
      advice.evidence = "R1_CONNECTED_STEEP_PATH";
      return true;
     }

   if(advice.r2Overlap >= OPPORTUNITY_GEOMETRY_STRUCTURE_MIN_R2_OVERLAP)
     {
      int linkedEndpoints = 0;
      if(FindOpportunityStructureForDrawingAnchor(drawing.time1, drawing.price1) >= 0)
         linkedEndpoints++;
      if(FindOpportunityStructureForDrawingAnchor(drawing.time2, drawing.price2) >= 0)
         linkedEndpoints++;
      advice.suggestedRole = "STRUCTURE_LINE";
      advice.confidence = ClampOpportunityGeometryScore(
         0.55 + advice.r2Overlap * 0.35 + ((double)linkedEndpoints / 2.0) * 0.10);
      advice.evidence = "R2_GEOMETRY";
      return true;
     }

   if(advice.channelExcluded && advice.r1Overlap >= OPPORTUNITY_GEOMETRY_PRE_MIN_R1_OVERLAP)
      advice.evidence = "CHANNEL_PRE_RELEASE_EXCLUDED";
   else if(advice.r1Overlap >= OPPORTUNITY_GEOMETRY_PRE_MIN_R1_OVERLAP)
      advice.evidence = "R1_PATH_NOT_CONFIRMED";
   else
      advice.evidence = "OUTSIDE_CLASSIFIED_GEOMETRY";
   advice.confidence = ClampOpportunityGeometryScore(MathMax(advice.r1Overlap,
                                                              advice.r2Overlap));
   return true;
  }

void SetOpportunityChannelArchivePriceTexts(OpportunityDrawingState &drawing,
                                             string price1Text,
                                             string price2Text,
                                             string price3Text)
  {
   drawing.price1ArchiveText = "";
   drawing.price2ArchiveText = "";
   drawing.price3ArchiveText = "";
   if(drawing.objectType != OBJ_CHANNEL) return;
   drawing.price1ArchiveText = StringLen(price1Text) > 0 ?
                               price1Text :
                               DoubleToString(drawing.price1,
                                              OPPORTUNITY_CHANNEL_PRICE_DIGITS);
   drawing.price2ArchiveText = StringLen(price2Text) > 0 ?
                               price2Text :
                               DoubleToString(drawing.price2,
                                              OPPORTUNITY_CHANNEL_PRICE_DIGITS);
   drawing.price3ArchiveText = StringLen(price3Text) > 0 ?
                               price3Text :
                               DoubleToString(drawing.price3,
                                              OPPORTUNITY_CHANNEL_PRICE_DIGITS);
  }

void SetOpportunityCapturedChannelArchivePriceTexts(
   OpportunityDrawingState &drawing)
  {
   string price1Text = "";
   string price2Text = "";
   string price3Text = "";
   for(int i = 0; i < ArraySize(opportunityDrawings); i++)
     {
      if(opportunityDrawings[i].drawingId != drawing.drawingId ||
         opportunityDrawings[i].objectType != OBJ_CHANNEL)
         continue;
      if(opportunityDrawings[i].price1 == drawing.price1)
         price1Text = opportunityDrawings[i].price1ArchiveText;
      if(opportunityDrawings[i].price2 == drawing.price2)
         price2Text = opportunityDrawings[i].price2ArchiveText;
      if(opportunityDrawings[i].price3 == drawing.price3)
         price3Text = opportunityDrawings[i].price3ArchiveText;
      break;
     }
   SetOpportunityChannelArchivePriceTexts(drawing, price1Text,
                                          price2Text, price3Text);
  }

string OpportunityDrawingArchivePriceText(OpportunityDrawingState &drawing,
                                           int anchorIndex)
  {
   double price = drawing.price1;
   string archiveText = drawing.price1ArchiveText;
   if(anchorIndex == 1)
     {
      price = drawing.price2;
      archiveText = drawing.price2ArchiveText;
     }
   else if(anchorIndex == 2)
     {
      price = drawing.price3;
      archiveText = drawing.price3ArchiveText;
     }
   if(drawing.objectType == OBJ_CHANNEL && StringLen(archiveText) > 0)
      return archiveText;
   int priceDigits = drawing.objectType == OBJ_CHANNEL ?
                     OPPORTUNITY_CHANNEL_PRICE_DIGITS : _Digits;
   return DoubleToString(price, priceDigits);
  }

string OpportunityDrawingSemanticArchivePriceText(
   OpportunityDrawingSemanticState &semantic,
   int anchorIndex)
  {
   double price = anchorIndex == 1 ? semantic.price2 : semantic.price1;
   string archiveText = anchorIndex == 1 ?
                        semantic.price2ArchiveText :
                        semantic.price1ArchiveText;
   if(semantic.objectType == OBJ_CHANNEL && StringLen(archiveText) > 0)
      return archiveText;
   int priceDigits = semantic.objectType == OBJ_CHANNEL ?
                     OPPORTUNITY_CHANNEL_PRICE_DIGITS : _Digits;
   return DoubleToString(price, priceDigits);
  }

string BuildOpportunityDrawingFingerprint(OpportunityDrawingState &drawing)
  {
   return "OBJ=" + IntegerToString((int)drawing.objectType) +
          "|A=" + IntegerToString(drawing.anchorCount) +
          "|T1=" + OpportunityDrawingTime(drawing.time1) +
          "|P1=" + OpportunityDrawingArchivePriceText(drawing, 0) +
          "|T2=" + OpportunityDrawingTime(drawing.time2) +
          "|P2=" + OpportunityDrawingArchivePriceText(drawing, 1) +
          "|T3=" + OpportunityDrawingTime(drawing.time3) +
          "|P3=" + OpportunityDrawingArchivePriceText(drawing, 2) +
          "|RL=" + IntegerToString((int)drawing.rayLeft) +
          "|RR=" + IntegerToString((int)drawing.rayRight);
  }

double OpportunityChannelPriceAtTime(datetime time1,
                                     double price1,
                                     datetime time2,
                                     double price2,
                                     datetime targetTime)
  {
   long durationSeconds = (long)(time2 - time1);
   if(durationSeconds == 0) return 0.0;
   double elapsedRatio = (double)(targetTime - time1) / (double)durationSeconds;
   return price1 + (price2 - price1) * elapsedRatio;
  }

double OpportunityChannelArchivePrice(double value)
  {
   return StringToDouble(DoubleToString(value, OPPORTUNITY_CHANNEL_PRICE_DIGITS));
  }

double OpportunityChannelArchiveRatio(double value)
  {
   return StringToDouble(DoubleToString(value, 12));
  }

double OpportunityDrawingSemanticArchiveValue(double value, int digits)
  {
   return StringToDouble(DoubleToString(value, digits));
  }

void NormalizeOpportunityDrawingSemanticArchiveValues(
   OpportunityDrawingSemanticState &semantic)
  {
   int priceDigits = semantic.objectType == OBJ_CHANNEL ?
                     OPPORTUNITY_CHANNEL_PRICE_DIGITS : _Digits;
   semantic.price1 = OpportunityDrawingSemanticArchiveValue(semantic.price1,
                                                             priceDigits);
   semantic.price2 = OpportunityDrawingSemanticArchiveValue(semantic.price2,
                                                             priceDigits);
   semantic.score = OpportunityDrawingSemanticArchiveValue(semantic.score, 3);
   semantic.r1Overlap = OpportunityDrawingSemanticArchiveValue(
                           semantic.r1Overlap, 3);
   semantic.r2Overlap = OpportunityDrawingSemanticArchiveValue(
                           semantic.r2Overlap, 3);
   semantic.referenceAtr = OpportunityDrawingSemanticArchiveValue(
                              semantic.referenceAtr, _Digits);
   semantic.displacementAtr = OpportunityDrawingSemanticArchiveValue(
                                 semantic.displacementAtr, 3);
   semantic.slopeAtrPerBar = OpportunityDrawingSemanticArchiveValue(
                                semantic.slopeAtrPerBar, 4);
   semantic.pathEfficiency = OpportunityDrawingSemanticArchiveValue(
                                semantic.pathEfficiency, 3);
   semantic.endpointTimeDistanceBars = OpportunityDrawingSemanticArchiveValue(
                                          semantic.endpointTimeDistanceBars, 1);
   semantic.endpointPriceDistanceAtr = OpportunityDrawingSemanticArchiveValue(
                                          semantic.endpointPriceDistanceAtr, 3);
  }

void NormalizeOpportunityChannelBoundaryArchiveValues(
   OpportunityChannelBoundaryState &boundary)
  {
   boundary.price1 = OpportunityChannelArchivePrice(boundary.price1);
   boundary.price2 = OpportunityChannelArchivePrice(boundary.price2);
   boundary.slopePricePerH1Bar = OpportunityChannelArchivePrice(
                                    boundary.slopePricePerH1Bar);
   boundary.referenceAtr = OpportunityChannelArchivePrice(boundary.referenceAtr);
   boundary.channelWidthPrice = OpportunityChannelArchivePrice(
                                   boundary.channelWidthPrice);
   boundary.channelWidthAtr = OpportunityChannelArchiveRatio(
                                 boundary.channelWidthAtr);
   boundary.parallelErrorPrice = OpportunityChannelArchivePrice(
                                    boundary.parallelErrorPrice);
   boundary.parallelErrorRatio = OpportunityChannelArchiveRatio(
                                    boundary.parallelErrorRatio);
  }

string OpportunityChannelDirection(double slopePricePerH1Bar,
                                   double symbolPoint)
  {
   double flatTolerance = MathMax(symbolPoint * 0.000001, 1.0e-12);
   if(slopePricePerH1Bar > flatTolerance) return "ASCENDING";
   if(slopePricePerH1Bar < -flatTolerance) return "DESCENDING";
   return "HORIZONTAL";
  }

string BuildOpportunityChannelBoundaryFingerprint(OpportunityChannelBoundaryState &boundary)
  {
   return "CHANNEL=" + boundary.channelId +
          "|SOURCE=" + boundary.sourceDrawingId +
          "|COMPONENT=" + boundary.componentRole +
          "|LINE=" + IntegerToString(boundary.nativeLineIndex) +
          "|BOUNDARY=" + boundary.boundaryRole +
          "|DIRECTION=" + boundary.channelDirection +
          "|T1=" + OpportunityDrawingTime(boundary.time1) +
          "|P1=" + DoubleToString(boundary.price1, OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|T2=" + OpportunityDrawingTime(boundary.time2) +
          "|P2=" + DoubleToString(boundary.price2, OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|SLOPE=" + DoubleToString(boundary.slopePricePerH1Bar,
                                      OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|WIDTH=" + DoubleToString(boundary.channelWidthPrice,
                                      OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|ATR=" + DoubleToString(boundary.referenceAtr,
                                    OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|WIDTH_ATR=" + DoubleToString(boundary.channelWidthAtr, 12) +
          "|PARALLEL_ERROR=" + DoubleToString(boundary.parallelErrorPrice,
                                               OPPORTUNITY_CHANNEL_PRICE_DIGITS) +
          "|PARALLEL_RATIO=" + DoubleToString(boundary.parallelErrorRatio, 12) +
          "|PARALLEL_OK=" + IntegerToString((int)boundary.parallelOK) +
          "|TOUCHES=" + boundary.touchAnchorRoles +
          "|DISTANCES=" + boundary.touchDistancePrices +
          "|ANCHORS=" + boundary.sourceAnchorRefs +
          "|COORDINATES=" + boundary.coordinateSource +
          "|ALGORITHM=" + boundary.algorithmVersion +
          "|FEATURE=" + boundary.featureVersion +
          "|SCHEMA=" + boundary.schemaVersion +
          "|DRAWING=" + boundary.sourceDrawingFingerprint;
  }

void AppendOpportunityChannelTouch(OpportunityChannelBoundaryState &boundary,
                                   string anchorRole,
                                   double distancePrice)
  {
   if(StringLen(boundary.touchAnchorRoles) > 0)
     {
      boundary.touchAnchorRoles += "|";
      boundary.touchDistancePrices += "|";
     }
   boundary.touchAnchorRoles += anchorRole;
   boundary.touchDistancePrices += DoubleToString(distancePrice,
                                                   OPPORTUNITY_CHANNEL_PRICE_DIGITS);
   boundary.touchCount++;
  }

bool BuildOpportunityNativeChannelBoundaries(long chartID,
                                             OpportunityDrawingState &drawing,
                                             OpportunityRegionState &regions[],
                                             datetime derivedAt,
                                             bool requireNativeEvaluation,
                                             OpportunityChannelBoundaryState &mainBoundary,
                                             OpportunityChannelBoundaryState &parallelBoundary)
  {
   if(drawing.objectType != OBJ_CHANNEL || drawing.anchorCount != 3 ||
      drawing.time1 <= 0 || drawing.time2 <= 0 || drawing.time3 <= 0 ||
      drawing.time1 == drawing.time2 || drawing.price1 <= 0.0 ||
      drawing.price2 <= 0.0 || drawing.price3 <= 0.0)
     {
      Print("[EA|FULL|CHANNEL] ERROR invalid native channel anchors | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | anchors=", drawing.anchorCount, " | err=0 | archive_touched=0");
      return false;
     }
   double nativePrices[4];
   int nativeErrors[4];
   double archivePrice1 = OpportunityChannelArchivePrice(drawing.price1);
   double archivePrice2 = OpportunityChannelArchivePrice(drawing.price2);
   double archivePrice3 = OpportunityChannelArchivePrice(drawing.price3);
   double mainAtThird = OpportunityChannelArchivePrice(
                           OpportunityChannelPriceAtTime(drawing.time1, archivePrice1,
                                                         drawing.time2, archivePrice2,
                                                         drawing.time3));
   double parallelOffset = OpportunityChannelArchivePrice(
                              archivePrice3 - mainAtThird);
   double expectedMain1 = archivePrice1;
   double expectedMain2 = archivePrice2;
   double expectedParallel1 = OpportunityChannelArchivePrice(
                                 archivePrice1 + parallelOffset);
   double expectedParallel2 = OpportunityChannelArchivePrice(
                                 archivePrice2 + parallelOffset);
   nativePrices[0] = expectedMain1;
   nativePrices[1] = expectedMain2;
   nativePrices[2] = expectedParallel1;
   nativePrices[3] = expectedParallel2;
   for(int i = 0; i < 4; i++) nativeErrors[i] = 0;
   if(requireNativeEvaluation)
     {
      ResetLastError();
      int sourceIndex = ObjectFind(chartID, drawing.sourceName);
      int sourceError = GetLastError();
      if(sourceIndex < 0)
        {
         Print("[EA|FULL|CHANNEL] ERROR source channel unavailable | case=",
               OpportunityCaseId(), " | id=", drawing.drawingId,
               " | source=", drawing.sourceName, " | err=", sourceError,
               " | archive_touched=0");
         return false;
        }
      datetime evaluationTimes[3];
      int evaluationLines[3];
      int evaluationValueIndexes[3];
      evaluationTimes[0] = drawing.time1;
      evaluationLines[0] = 0;
      evaluationValueIndexes[0] = 0;
      evaluationTimes[1] = drawing.time2;
      evaluationLines[1] = 0;
      evaluationValueIndexes[1] = 1;
      evaluationTimes[2] = drawing.time3;
      evaluationLines[2] = 1;
      evaluationValueIndexes[2] = -1;
      for(int evaluationIndex = 0; evaluationIndex < 3; evaluationIndex++)
        {
         ResetLastError();
         double nativeValue = ObjectGetValueByTime(chartID, drawing.sourceName,
                                                    evaluationTimes[evaluationIndex],
                                                    evaluationLines[evaluationIndex]);
         int nativeError = GetLastError();
         if(nativeValue <= 0.0 || !MathIsValidNumber(nativeValue) || nativeError != 0)
           {
            Print("[EA|FULL|CHANNEL] ERROR native boundary evaluation failed | case=",
                  OpportunityCaseId(), " | id=", drawing.drawingId,
                  " | source=", drawing.sourceName,
                  " | line=", evaluationLines[evaluationIndex],
                  " | time=", OpportunityDrawingTime(evaluationTimes[evaluationIndex]),
                  " | value=", DoubleToString(nativeValue,
                                                OPPORTUNITY_CHANNEL_PRICE_DIGITS),
                  " | err=", nativeError, " | archive_touched=0");
            return false;
           }
         if(evaluationValueIndexes[evaluationIndex] >= 0)
           {
            int valueIndex = evaluationValueIndexes[evaluationIndex];
            nativePrices[valueIndex] = nativeValue;
            nativeErrors[valueIndex] = nativeError;
           }
         else
           {
            double parallelAnchorError = MathAbs(nativeValue - archivePrice3);
            double anchorTolerance = MathMax(SymbolInfoDouble(ChartSymbol(chartID), SYMBOL_POINT) * 0.01,
                                             1.0e-10);
            if(parallelAnchorError > anchorTolerance)
              {
               Print("[EA|FULL|CHANNEL] ERROR native parallel anchor mismatch | case=",
                     OpportunityCaseId(), " | id=", drawing.drawingId,
                     " | source=", drawing.sourceName,
                     " | time=", OpportunityDrawingTime(drawing.time3),
                     " | native=", DoubleToString(nativeValue,
                                                   OPPORTUNITY_CHANNEL_PRICE_DIGITS),
                     " | expected=", DoubleToString(archivePrice3,
                                                     OPPORTUNITY_CHANNEL_PRICE_DIGITS),
                     " | error=", DoubleToString(parallelAnchorError,
                                                  OPPORTUNITY_CHANNEL_PRICE_DIGITS),
                     " | tolerance=", DoubleToString(anchorTolerance,
                                                      OPPORTUNITY_CHANNEL_PRICE_DIGITS),
                     " | err=0 | archive_touched=0");
               return false;
              }
           }
        }
      }
   double directMatch = MathAbs(nativePrices[0] - expectedMain1) +
                        MathAbs(nativePrices[1] - expectedMain2) +
                        MathAbs(nativePrices[2] - expectedParallel1) +
                        MathAbs(nativePrices[3] - expectedParallel2);
   double swappedMatch = MathAbs(nativePrices[2] - expectedMain1) +
                         MathAbs(nativePrices[3] - expectedMain2) +
                         MathAbs(nativePrices[0] - expectedParallel1) +
                         MathAbs(nativePrices[1] - expectedParallel2);
   int mainLineIndex = 0;
   int parallelLineIndex = 1;
   double mainPrice1 = expectedMain1;
   double mainPrice2 = expectedMain2;
   double parallelPrice1 = expectedParallel1;
   double parallelPrice2 = expectedParallel2;

   string symbolName = opportunityAnnotationNativeSymbol;
   if(StringLen(symbolName) == 0) symbolName = ChartSymbol(chartID);
   string timeframeName = opportunityAnnotationNativeTimeframe;
   if(StringLen(timeframeName) == 0)
      timeframeName = TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID));
   double symbolPoint = SymbolInfoDouble(symbolName, SYMBOL_POINT);
   if(symbolPoint <= 0.0) symbolPoint = _Point;
   double coordinateTolerance = MathMax(symbolPoint * 0.01, 1.0e-10);
   if(directMatch > coordinateTolerance * 4.0)
     {
      Print("[EA|FULL|CHANNEL] ERROR native and three-anchor geometry mismatch | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | direct_error=", DoubleToString(directMatch,
                                                 OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | swapped_error=", DoubleToString(swappedMatch,
                                                  OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | tolerance=", DoubleToString(coordinateTolerance,
                                              OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | err=0 | archive_touched=0");
      return false;
     }

   double width1 = OpportunityChannelArchivePrice(
                      MathAbs(mainPrice1 - parallelPrice1));
   double width2 = OpportunityChannelArchivePrice(
                      MathAbs(mainPrice2 - parallelPrice2));
   double channelWidth = OpportunityChannelArchivePrice(
                            (width1 + width2) * 0.5);
   double parallelErrorPrice = OpportunityChannelArchivePrice(
                                  MathAbs(width2 - width1));
   double parallelErrorRatio = channelWidth > 0.0 ?
                               parallelErrorPrice / channelWidth : 1.0e100;
   bool parallelOK = (channelWidth > coordinateTolerance &&
                      parallelErrorPrice <= coordinateTolerance &&
                      parallelErrorRatio <= 1.0e-8);
   if(!parallelOK)
     {
      Print("[EA|FULL|CHANNEL] ERROR native channel parallel verification failed | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | width_1=", DoubleToString(width1, OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | width_2=", DoubleToString(width2, OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | error=", DoubleToString(parallelErrorPrice,
                                          OPPORTUNITY_CHANNEL_PRICE_DIGITS),
            " | ratio=", DoubleToString(parallelErrorRatio, 12),
            " | err=0 | archive_touched=0");
      return false;
     }

   long durationSeconds = (long)(drawing.time2 - drawing.time1);
   double slopePricePerH1Bar = (mainPrice2 - mainPrice1) * 3600.0 /
                               (double)durationSeconds;
   string direction = OpportunityChannelDirection(slopePricePerH1Bar, symbolPoint);
   double referenceAtr = 0.0;
   int atrSamples = 0;
   if(ArraySize(regions) == OPPORTUNITY_REGION_COUNT)
     {
      int r2Index = FindOpportunityGeometryRegion(regions, "ACCUMULATION");
      if(r2Index >= 0)
         CalculateOpportunityGeometryReferenceAtr(symbolName,
                                                   regions[r2Index].startTime,
                                                   regions[r2Index].endTime,
                                                   referenceAtr, atrSamples);
     }

   string sourceFingerprint = BuildOpportunityDrawingFingerprint(drawing);
   mainBoundary.channelId = drawing.drawingId;
   mainBoundary.sourceDrawingId = drawing.drawingId;
   mainBoundary.componentId = drawing.drawingId + "-MAIN";
   mainBoundary.nativeLineIndex = mainLineIndex;
   mainBoundary.componentRole = "MAIN_LINE";
   mainBoundary.channelDirection = direction;
   mainBoundary.symbol = symbolName;
   mainBoundary.timeframe = timeframeName;
   mainBoundary.time1 = drawing.time1;
   mainBoundary.price1 = mainPrice1;
   mainBoundary.time2 = drawing.time2;
   mainBoundary.price2 = mainPrice2;
   mainBoundary.slopePricePerH1Bar = slopePricePerH1Bar;
   mainBoundary.referenceAtr = referenceAtr;
   mainBoundary.channelWidthPrice = channelWidth;
   mainBoundary.channelWidthAtr = referenceAtr > 0.0 ? channelWidth / referenceAtr : 0.0;
   mainBoundary.parallelErrorPrice = parallelErrorPrice;
   mainBoundary.parallelErrorRatio = parallelErrorRatio;
   mainBoundary.parallelOK = parallelOK;
   mainBoundary.touchCount = 0;
   mainBoundary.touchAnchorRoles = "";
   mainBoundary.touchDistancePrices = "";
   mainBoundary.sourceAnchorRefs = "P1|P2";
   mainBoundary.coordinateSource = "THREE_ANCHOR_GEOMETRY_VERIFIED_BY_MT5_OBJECT_GET_VALUE_BY_TIME";
   mainBoundary.sourceDrawingFingerprint = sourceFingerprint;
   mainBoundary.algorithmVersion = OPPORTUNITY_CHANNEL_ALGORITHM_VERSION;
   mainBoundary.featureVersion = OPPORTUNITY_CHANNEL_FEATURE_VERSION;
   mainBoundary.schemaVersion = OPPORTUNITY_CHANNEL_SCHEMA_VERSION;
   mainBoundary.decisionStatus = "CONFIRMED";
   mainBoundary.evidence = "NATIVE_EQUIDISTANT_CHANNEL_EXPANDED";
   mainBoundary.derivedAt = derivedAt;

   parallelBoundary = mainBoundary;
   parallelBoundary.componentId = drawing.drawingId + "-PARALLEL";
   parallelBoundary.nativeLineIndex = parallelLineIndex;
   parallelBoundary.componentRole = "PARALLEL_LINE";
   parallelBoundary.price1 = parallelPrice1;
   parallelBoundary.price2 = parallelPrice2;
   parallelBoundary.sourceAnchorRefs = "P3";

   if(mainPrice1 > parallelPrice1)
     {
      mainBoundary.boundaryRole = "CHANNEL_UPPER_BOUNDARY";
      parallelBoundary.boundaryRole = "CHANNEL_LOWER_BOUNDARY";
     }
   else
     {
      mainBoundary.boundaryRole = "CHANNEL_LOWER_BOUNDARY";
      parallelBoundary.boundaryRole = "CHANNEL_UPPER_BOUNDARY";
     }

   NormalizeOpportunityChannelBoundaryArchiveValues(mainBoundary);
   NormalizeOpportunityChannelBoundaryArchiveValues(parallelBoundary);

   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      datetime anchorTime = opportunityStructures[i].representativeTime;
      double anchorPrice = opportunityStructures[i].representativePrice;
      if(anchorTime <= 0) anchorTime = opportunityStructures[i].centerTime;
      if(anchorPrice <= 0.0) anchorPrice = opportunityStructures[i].centerPrice;
      datetime channelStart = mainBoundary.time1 < mainBoundary.time2 ?
                              mainBoundary.time1 : mainBoundary.time2;
      datetime channelEnd = mainBoundary.time1 > mainBoundary.time2 ?
                            mainBoundary.time1 : mainBoundary.time2;
      if(!drawing.rayLeft && anchorTime < channelStart) continue;
      if(!drawing.rayRight && anchorTime > channelEnd) continue;
      double mainAtAnchor = OpportunityChannelPriceAtTime(mainBoundary.time1,
                                                          mainBoundary.price1,
                                                          mainBoundary.time2,
                                                          mainBoundary.price2,
                                                          anchorTime);
      double parallelAtAnchor = OpportunityChannelPriceAtTime(parallelBoundary.time1,
                                                              parallelBoundary.price1,
                                                              parallelBoundary.time2,
                                                              parallelBoundary.price2,
                                                              anchorTime);
      double mainDistance = MathAbs(anchorPrice - mainAtAnchor);
      double parallelDistance = MathAbs(anchorPrice - parallelAtAnchor);
      if(mainDistance <= parallelDistance)
         AppendOpportunityChannelTouch(mainBoundary,
                                       opportunityStructures[i].role,
                                       mainDistance);
      else
         AppendOpportunityChannelTouch(parallelBoundary,
                                       opportunityStructures[i].role,
                                       parallelDistance);
     }
   mainBoundary.boundaryFingerprint = BuildOpportunityChannelBoundaryFingerprint(mainBoundary);
   parallelBoundary.boundaryFingerprint =
      BuildOpportunityChannelBoundaryFingerprint(parallelBoundary);
   Print("[EA|FULL|CHANNEL] INFO native channel expanded | case=",
         OpportunityCaseId(), " | id=", drawing.drawingId,
         " | main_line=", mainBoundary.nativeLineIndex,
         "/", mainBoundary.boundaryRole,
         " | parallel_line=", parallelBoundary.nativeLineIndex,
         "/", parallelBoundary.boundaryRole,
         " | direction=", direction,
         " | width=", DoubleToString(channelWidth, OPPORTUNITY_CHANNEL_PRICE_DIGITS),
         " | parallel_error=", DoubleToString(parallelErrorPrice,
                                               OPPORTUNITY_CHANNEL_PRICE_DIGITS),
         " | main_touches=", mainBoundary.touchAnchorRoles,
         " | parallel_touches=", parallelBoundary.touchAnchorRoles,
         " | archive_touched=0");
   return true;
  }

bool BuildOpportunityChannelBoundaries(long chartID,
                                       OpportunityDrawingState &drawings[],
                                       OpportunityRegionState &regions[],
                                       bool requireNativeEvaluation,
                                       OpportunityChannelBoundaryState &boundaries[])
  {
   ArrayResize(boundaries, 0);
   datetime derivedAt = TimeLocal();
   int nativeChannels = 0;
   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(drawings[i].objectType != OBJ_CHANNEL) continue;
      nativeChannels++;
      OpportunityChannelBoundaryState mainBoundary;
      OpportunityChannelBoundaryState parallelBoundary;
      if(!BuildOpportunityNativeChannelBoundaries(chartID, drawings[i], regions,
                                                   derivedAt,
                                                   requireNativeEvaluation,
                                                   mainBoundary,
                                                   parallelBoundary))
         return false;
      int index = ArraySize(boundaries);
      ArrayResize(boundaries, index + 2);
      boundaries[index] = mainBoundary;
      boundaries[index + 1] = parallelBoundary;
     }
   return (ArraySize(boundaries) == nativeChannels * 2);
  }

int FindOpportunityChannelBoundary(OpportunityChannelBoundaryState &boundaries[],
                                   string sourceDrawingId,
                                   string componentRole)
  {
   for(int i = 0; i < ArraySize(boundaries); i++)
      if(boundaries[i].sourceDrawingId == sourceDrawingId &&
         boundaries[i].componentRole == componentRole)
         return i;
   return -1;
  }

string BuildOpportunityChannelSemanticInputFingerprint(
   OpportunityDrawingState &drawing,
   OpportunityChannelBoundaryState &boundaries[])
  {
   int mainIndex = FindOpportunityChannelBoundary(boundaries, drawing.drawingId,
                                                  "MAIN_LINE");
   int parallelIndex = FindOpportunityChannelBoundary(boundaries, drawing.drawingId,
                                                      "PARALLEL_LINE");
   if(mainIndex < 0 || parallelIndex < 0) return "";
   return BuildOpportunityDrawingFingerprint(drawing) +
          "|TYPE=" + OpportunityCaseType() +
          "|SYMBOL=" + boundaries[mainIndex].symbol +
          "|TIMEFRAME=" + boundaries[mainIndex].timeframe +
          "|MAIN=" + boundaries[mainIndex].boundaryFingerprint +
          "|PARALLEL=" + boundaries[parallelIndex].boundaryFingerprint;
  }

string BuildOpportunitySemanticInputFingerprint(OpportunityDrawingState &drawing,
                                                OpportunityRegionState &regions[],
                                                OpportunityGeometryAdvice &advice)
  {
   string fingerprint = BuildOpportunityDrawingFingerprint(drawing) +
                        "|TYPE=" + OpportunityCaseType() +
                        "|SYMBOL=" + opportunityAnnotationNativeSymbol +
                        "|TIMEFRAME=" + opportunityAnnotationNativeTimeframe;
   for(int i = 0; i < ArraySize(regions); i++)
      fingerprint += "|" + regions[i].regionId + "=" +
                     OpportunityDrawingTime(regions[i].startTime) + "/" +
                     OpportunityDrawingTime(regions[i].endTime);
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
      fingerprint += "|" + opportunityStructures[i].role + "=" +
                     OpportunityDrawingTime(opportunityStructures[i].centerTime) + "/" +
                     DoubleToString(opportunityStructures[i].centerPrice, _Digits) + "/" +
                     OpportunityDrawingTime(opportunityStructures[i].rangeStartTime) + "/" +
                     OpportunityDrawingTime(opportunityStructures[i].rangeEndTime) + "/" +
                     DoubleToString(opportunityStructures[i].circleLow, _Digits) + "/" +
                     DoubleToString(opportunityStructures[i].circleHigh, _Digits) + "/" +
                     DoubleToString(opportunityStructures[i].zoneLow, _Digits) + "/" +
                  DoubleToString(opportunityStructures[i].zoneHigh, _Digits) + "/" +
                  OpportunityDrawingTime(opportunityStructures[i].representativeTime) + "/" +
                  DoubleToString(opportunityStructures[i].representativePrice, _Digits) + "/" +
                  opportunityStructures[i].representativeType;
   fingerprint += "|R1=" + DoubleToString(advice.r1Overlap, 3) +
                  "|R2=" + DoubleToString(advice.r2Overlap, 3) +
                  "|H1=" + IntegerToString(advice.effectiveH1Bars) +
                  "|ATR=" + DoubleToString(advice.referenceAtr, _Digits) +
                  "|DISP=" + DoubleToString(advice.displacementAtr, 3) +
                  "|SLOPE=" + DoubleToString(advice.slopeAtrPerBar, 4) +
                  "|EFF=" + DoubleToString(advice.pathEfficiency, 3) +
                  "|FIRST=" + advice.firstStructureRole +
                  "|CONNECTED=" + IntegerToString((int)advice.firstStructureConnected) +
                  "|TIME_DISTANCE=" + DoubleToString(advice.endpointTimeDistanceBars, 1) +
                  "|PRICE_DISTANCE=" + DoubleToString(advice.endpointPriceDistanceAtr, 3) +
                  "|CHANNEL=" + IntegerToString((int)advice.channelExcluded);
   return fingerprint;
  }

int OpportunityDrawingChronologicalOrder(OpportunityDrawingState &drawings[], int drawingIndex)
  {
   datetime sortTime = OpportunityDrawingSemanticSortTime(drawings[drawingIndex]);
   int order = 1;
   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(i == drawingIndex || drawings[i].objectType != OBJ_TREND) continue;
      datetime otherTime = OpportunityDrawingSemanticSortTime(drawings[i]);
      if(otherTime < sortTime ||
         (otherTime == sortTime &&
          StringCompare(drawings[i].drawingId, drawings[drawingIndex].drawingId) < 0))
         order++;
     }
   return order;
  }

int OpportunityChannelSemanticOrder(OpportunityDrawingState &drawings[],
                                    int drawingIndex)
  {
   datetime sortTime = OpportunityDrawingSemanticSortTime(drawings[drawingIndex]);
   int order = 1;
   for(int i = 0; i < ArraySize(drawings); i++)
      if(drawings[i].objectType == OBJ_TREND) order++;
   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(i == drawingIndex || drawings[i].objectType != OBJ_CHANNEL) continue;
      datetime otherTime = OpportunityDrawingSemanticSortTime(drawings[i]);
      if(otherTime < sortTime ||
         (otherTime == sortTime &&
          StringCompare(drawings[i].drawingId, drawings[drawingIndex].drawingId) < 0))
         order++;
     }
   return order;
  }

bool BuildOpportunityDrawingSemantics(long chartID,
                                      OpportunityDrawingState &drawings[],
                                      OpportunityRegionState &regions[],
                                      OpportunityChannelBoundaryState &channelBoundaries[],
                                      OpportunityDrawingSemanticState &semantics[])
  {
   ArrayResize(semantics, 0);
   datetime derivedAt = TimeLocal();
   string symbolName = opportunityAnnotationNativeSymbol;
   if(StringLen(symbolName) == 0) symbolName = ChartSymbol(chartID);
   string timeframeName = opportunityAnnotationNativeTimeframe;
   if(StringLen(timeframeName) == 0)
      timeframeName = TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID));

   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(drawings[i].objectType == OBJ_CHANNEL)
        {
         int mainIndex = FindOpportunityChannelBoundary(channelBoundaries,
                                                        drawings[i].drawingId,
                                                        "MAIN_LINE");
         int parallelIndex = FindOpportunityChannelBoundary(channelBoundaries,
                                                            drawings[i].drawingId,
                                                            "PARALLEL_LINE");
         if(mainIndex < 0 || parallelIndex < 0)
           {
            Print("[EA|FULL|CHANNEL] ERROR object semantic boundaries unavailable | case=",
                  OpportunityCaseId(), " | id=", drawings[i].drawingId,
                  " | main=", mainIndex, " | parallel=", parallelIndex,
                  " | err=0 | archive_touched=0");
            return false;
           }
         OpportunityDrawingState archiveDrawing = drawings[i];
         archiveDrawing.price1 = OpportunityChannelArchivePrice(
                                   archiveDrawing.price1);
         archiveDrawing.price2 = OpportunityChannelArchivePrice(
                                   archiveDrawing.price2);
         archiveDrawing.price3 = OpportunityChannelArchivePrice(
                                   archiveDrawing.price3);
         OpportunityDrawingSemanticState channelSemantic;
         channelSemantic.drawingId = drawings[i].drawingId;
         channelSemantic.symbol = symbolName;
         channelSemantic.timeframe = timeframeName;
         channelSemantic.objectType = drawings[i].objectType;
         channelSemantic.time1 = archiveDrawing.time1;
         channelSemantic.price1 = archiveDrawing.price1;
         channelSemantic.time2 = archiveDrawing.time2;
         channelSemantic.price2 = archiveDrawing.price2;
         channelSemantic.price1ArchiveText =
            OpportunityDrawingArchivePriceText(archiveDrawing, 0);
         channelSemantic.price2ArchiveText =
            OpportunityDrawingArchivePriceText(archiveDrawing, 1);
         channelSemantic.drawingFingerprint =
            BuildOpportunityDrawingFingerprint(archiveDrawing);
         channelSemantic.inputFingerprint =
            BuildOpportunityChannelSemanticInputFingerprint(archiveDrawing,
                                                             channelBoundaries);
         channelSemantic.semanticRole = "CHANNEL_STRUCTURE";
         channelSemantic.pathId = "CHANNEL_" + drawings[i].drawingId;
         channelSemantic.segmentOrder =
            OpportunityChannelSemanticOrder(drawings, i);
         channelSemantic.anchor1Role = "MAIN_LINE_" +
                                       channelBoundaries[mainIndex].boundaryRole;
         channelSemantic.anchor2Role = "PARALLEL_LINE_" +
                                       channelBoundaries[parallelIndex].boundaryRole;
         channelSemantic.semanticSource = "CHANNEL_GEOMETRY_ALGORITHM";
         channelSemantic.algorithmVersion = OPPORTUNITY_CHANNEL_ALGORITHM_VERSION;
         channelSemantic.featureVersion = OPPORTUNITY_CHANNEL_FEATURE_VERSION;
         channelSemantic.schemaVersion = OPPORTUNITY_DRAWING_SEMANTIC_SCHEMA_VERSION;
         channelSemantic.decisionStatus = "CONFIRMED";
         channelSemantic.score = 1.0;
         channelSemantic.evidence = "NATIVE_EQUIDISTANT_CHANNEL_EXPANDED";
         channelSemantic.r1Overlap = 0.0;
         channelSemantic.r2Overlap = 0.0;
         channelSemantic.effectiveH1Bars = 0;
         channelSemantic.referenceAtr = channelBoundaries[mainIndex].referenceAtr;
         channelSemantic.displacementAtr = 0.0;
         channelSemantic.slopeAtrPerBar =
            channelBoundaries[mainIndex].referenceAtr > 0.0 ?
            MathAbs(channelBoundaries[mainIndex].slopePricePerH1Bar) /
            channelBoundaries[mainIndex].referenceAtr : 0.0;
         channelSemantic.pathEfficiency = 0.0;
         channelSemantic.firstStructureRole =
            channelBoundaries[mainIndex].touchAnchorRoles;
         channelSemantic.firstStructureConnected =
            (channelBoundaries[mainIndex].touchCount > 0 &&
             channelBoundaries[parallelIndex].touchCount > 0);
         channelSemantic.connectedEndpoint =
            channelBoundaries[parallelIndex].touchAnchorRoles;
         channelSemantic.endpointTimeDistanceBars = 0.0;
         channelSemantic.endpointPriceDistanceAtr = 0.0;
         channelSemantic.channelExcluded = true;
         channelSemantic.derivedAt = channelBoundaries[mainIndex].derivedAt;
         NormalizeOpportunityDrawingSemanticArchiveValues(channelSemantic);
         int channelSemanticIndex = ArraySize(semantics);
         ArrayResize(semantics, channelSemanticIndex + 1);
         semantics[channelSemanticIndex] = channelSemantic;
         continue;
        }
      if(drawings[i].objectType != OBJ_TREND) continue;
      OpportunityGeometryAdvice advice;
      if(!BuildOpportunityGeometryAdvice(chartID, drawings[i], regions, advice)) continue;

      OpportunityDrawingSemanticState semantic;
      semantic.drawingId = drawings[i].drawingId;
      semantic.symbol = symbolName;
      semantic.timeframe = timeframeName;
      semantic.objectType = drawings[i].objectType;
      semantic.time1 = drawings[i].time1;
      semantic.price1 = drawings[i].price1;
      semantic.time2 = drawings[i].time2;
      semantic.price2 = drawings[i].price2;
      semantic.price1ArchiveText = "";
      semantic.price2ArchiveText = "";
      semantic.drawingFingerprint = BuildOpportunityDrawingFingerprint(drawings[i]);
      semantic.inputFingerprint = BuildOpportunitySemanticInputFingerprint(drawings[i], regions,
                                                                            advice);
      semantic.semanticRole = advice.suggestedRole;
      semantic.pathId = advice.suggestedRole == "PRE_ACCUMULATION_RELEASE_PATH" ?
                        "R1_RELEASE_PATH" :
                        (advice.suggestedRole == "STRUCTURE_LINE" ? "STRUCTURE_GRAPH" : "");
      semantic.segmentOrder = OpportunityDrawingChronologicalOrder(drawings, i);
      int anchor1Index = FindOpportunityStructureForDrawingAnchor(drawings[i].time1,
                                                                  drawings[i].price1);
      int anchor2Index = FindOpportunityStructureForDrawingAnchor(drawings[i].time2,
                                                                  drawings[i].price2);
      semantic.anchor1Role = anchor1Index >= 0 ? opportunityStructures[anchor1Index].role : "";
      semantic.anchor2Role = anchor2Index >= 0 ? opportunityStructures[anchor2Index].role : "";
      semantic.semanticSource = "GEOMETRY_ALGORITHM";
      semantic.algorithmVersion = OPPORTUNITY_GEOMETRY_ALGORITHM_VERSION;
      semantic.featureVersion = OPPORTUNITY_GEOMETRY_FEATURE_VERSION;
      semantic.schemaVersion = OPPORTUNITY_DRAWING_SEMANTIC_SCHEMA_VERSION;
      semantic.decisionStatus = advice.suggestedRole == "REVIEW_REQUIRED" ?
                                "REVIEW_REQUIRED" : "CONFIRMED";
      semantic.score = advice.confidence;
      semantic.evidence = advice.evidence;
      semantic.r1Overlap = advice.r1Overlap;
      semantic.r2Overlap = advice.r2Overlap;
      semantic.effectiveH1Bars = advice.effectiveH1Bars;
      semantic.referenceAtr = advice.referenceAtr;
      semantic.displacementAtr = advice.displacementAtr;
      semantic.slopeAtrPerBar = advice.slopeAtrPerBar;
      semantic.pathEfficiency = advice.pathEfficiency;
      semantic.firstStructureRole = advice.firstStructureRole;
      semantic.firstStructureConnected = advice.firstStructureConnected;
      semantic.connectedEndpoint = "";
      int firstStructureIndex = FindFirstOpportunityStructure();
      if(firstStructureIndex >= 0)
        {
         bool firstConnected = false;
         bool secondConnected = false;
         double firstTimeDistance = 0.0;
         double firstPriceDistance = 0.0;
         double secondTimeDistance = 0.0;
         double secondPriceDistance = 0.0;
         EvaluateOpportunityGeometryEndpoint(symbolName, drawings[i].time1,
                                             drawings[i].price1,
                                             firstStructureIndex,
                                             advice.referenceAtr,
                                             firstConnected,
                                             firstTimeDistance,
                                             firstPriceDistance);
         EvaluateOpportunityGeometryEndpoint(symbolName, drawings[i].time2,
                                             drawings[i].price2,
                                             firstStructureIndex,
                                             advice.referenceAtr,
                                             secondConnected,
                                             secondTimeDistance,
                                             secondPriceDistance);
         if(firstConnected && secondConnected) semantic.connectedEndpoint = "BOTH";
         else if(firstConnected) semantic.connectedEndpoint = "ANCHOR_1";
         else if(secondConnected) semantic.connectedEndpoint = "ANCHOR_2";
        }
      semantic.endpointTimeDistanceBars = advice.endpointTimeDistanceBars;
      semantic.endpointPriceDistanceAtr = advice.endpointPriceDistanceAtr;
      semantic.channelExcluded = advice.channelExcluded;
      semantic.derivedAt = derivedAt;

      int index = ArraySize(semantics);
      ArrayResize(semantics, index + 1);
      semantics[index] = semantic;
     }

   for(int i = 0; i < ArraySize(semantics) - 1; i++)
      for(int j = i + 1; j < ArraySize(semantics); j++)
         if(semantics[j].segmentOrder < semantics[i].segmentOrder)
           {
            OpportunityDrawingSemanticState swap = semantics[i];
            semantics[i] = semantics[j];
            semantics[j] = swap;
           }
   return (ArraySize(semantics) > 0);
  }

bool ValidateOpportunityDrawingFingerprintReload(
   OpportunityDrawingState &expected[],
   OpportunityDrawingState &loaded[],
   string stage)
  {
   if(ArraySize(expected) != ArraySize(loaded))
     {
      Print("[EA|FULL|DRAWING] ERROR fingerprint reload count mismatch | case=",
            OpportunityCaseId(), " | stage=", stage,
            " | expected=", ArraySize(expected),
            " | loaded=", ArraySize(loaded));
      return false;
     }
   for(int i = 0; i < ArraySize(expected); i++)
     {
      int loadedIndex = -1;
      int matches = 0;
      for(int j = 0; j < ArraySize(loaded); j++)
         if(loaded[j].drawingId == expected[i].drawingId)
           {
            loadedIndex = j;
            matches++;
           }
      if(matches != 1)
        {
         Print("[EA|FULL|DRAWING] ERROR fingerprint reload identity mismatch | case=",
               OpportunityCaseId(), " | stage=", stage,
               " | id=", expected[i].drawingId,
               " | matches=", matches);
         return false;
        }
      string expectedFingerprint = BuildOpportunityDrawingFingerprint(expected[i]);
      string loadedFingerprint = BuildOpportunityDrawingFingerprint(loaded[loadedIndex]);
      if(expectedFingerprint != loadedFingerprint)
        {
         Print("[EA|FULL|DRAWING] ERROR fingerprint changed after raw reload | case=",
               OpportunityCaseId(), " | stage=", stage,
               " | id=", expected[i].drawingId,
               " | expected=", expectedFingerprint,
               " | loaded=", loadedFingerprint);
         return false;
        }
     }
   Print("[EA|FULL|DRAWING] INFO fingerprint reload verified | case=",
         OpportunityCaseId(), " | stage=", stage,
         " | drawings=", ArraySize(expected));
   return true;
  }

bool ValidateOpportunityChannelFingerprintLinks(
   OpportunityDrawingState &drawings[],
   OpportunityDrawingSemanticState &semantics[],
   OpportunityChannelBoundaryState &boundaries[],
   string stage)
  {
   int channelCount = 0;
   int channelSemanticCount = 0;
   for(int i = 0; i < ArraySize(drawings); i++)
      if(drawings[i].objectType == OBJ_CHANNEL) channelCount++;
   for(int i = 0; i < ArraySize(semantics); i++)
      if(semantics[i].objectType == OBJ_CHANNEL) channelSemanticCount++;
   if(channelSemanticCount != channelCount ||
      ArraySize(boundaries) != channelCount * 2)
     {
      Print("[EA|FULL|CHANNEL] ERROR fingerprint link count mismatch | case=",
            OpportunityCaseId(), " | stage=", stage,
            " | channels=", channelCount,
            " | semantics=", channelSemanticCount,
            " | boundaries=", ArraySize(boundaries));
      return false;
     }

   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(drawings[i].objectType != OBJ_CHANNEL) continue;
      int semanticIndex = -1;
      int semanticMatches = 0;
      int mainIndex = -1;
      int mainMatches = 0;
      int parallelIndex = -1;
      int parallelMatches = 0;
      for(int j = 0; j < ArraySize(semantics); j++)
         if(semantics[j].drawingId == drawings[i].drawingId &&
            semantics[j].objectType == OBJ_CHANNEL)
           {
            semanticIndex = j;
            semanticMatches++;
           }
      for(int j = 0; j < ArraySize(boundaries); j++)
        {
         if(boundaries[j].sourceDrawingId != drawings[i].drawingId) continue;
         if(boundaries[j].componentRole == "MAIN_LINE")
           {
            mainIndex = j;
            mainMatches++;
           }
         else if(boundaries[j].componentRole == "PARALLEL_LINE")
           {
            parallelIndex = j;
            parallelMatches++;
           }
        }
      if(semanticMatches != 1 || mainMatches != 1 || parallelMatches != 1)
        {
         Print("[EA|FULL|CHANNEL] ERROR fingerprint link identity mismatch | case=",
               OpportunityCaseId(), " | stage=", stage,
               " | id=", drawings[i].drawingId,
               " | semantic=", semanticMatches,
               " | main=", mainMatches,
               " | parallel=", parallelMatches);
         return false;
        }

      string expectedFingerprint = BuildOpportunityDrawingFingerprint(drawings[i]);
      string expectedInputFingerprint =
         BuildOpportunityChannelSemanticInputFingerprint(drawings[i], boundaries);
      string expectedBoundarySuffix = "|DRAWING=" + expectedFingerprint;
      bool mainBoundaryLinked =
         StringFind(boundaries[mainIndex].boundaryFingerprint,
                    expectedBoundarySuffix) ==
         StringLen(boundaries[mainIndex].boundaryFingerprint) -
         StringLen(expectedBoundarySuffix);
      bool parallelBoundaryLinked =
         StringFind(boundaries[parallelIndex].boundaryFingerprint,
                    expectedBoundarySuffix) ==
         StringLen(boundaries[parallelIndex].boundaryFingerprint) -
         StringLen(expectedBoundarySuffix);
      bool linksValid =
         semantics[semanticIndex].drawingFingerprint == expectedFingerprint &&
         semantics[semanticIndex].inputFingerprint == expectedInputFingerprint &&
         semantics[semanticIndex].time1 == drawings[i].time1 &&
         semantics[semanticIndex].time2 == drawings[i].time2 &&
         OpportunityDrawingSemanticArchivePriceText(semantics[semanticIndex], 0) ==
            OpportunityDrawingArchivePriceText(drawings[i], 0) &&
         OpportunityDrawingSemanticArchivePriceText(semantics[semanticIndex], 1) ==
            OpportunityDrawingArchivePriceText(drawings[i], 1) &&
         boundaries[mainIndex].sourceDrawingFingerprint == expectedFingerprint &&
         boundaries[parallelIndex].sourceDrawingFingerprint == expectedFingerprint &&
         mainBoundaryLinked && parallelBoundaryLinked;
      if(!linksValid)
        {
         Print("[EA|FULL|CHANNEL] ERROR fingerprint link mismatch | case=",
               OpportunityCaseId(), " | stage=", stage,
               " | id=", drawings[i].drawingId,
               " | expected=", expectedFingerprint,
               " | semantic=", semantics[semanticIndex].drawingFingerprint,
               " | main=", boundaries[mainIndex].sourceDrawingFingerprint,
               " | parallel=", boundaries[parallelIndex].sourceDrawingFingerprint,
               " | input_match=",
               (int)(semantics[semanticIndex].inputFingerprint ==
                     expectedInputFingerprint));
         return false;
        }
     }
   Print("[EA|FULL|CHANNEL] INFO fingerprint links verified | case=",
         OpportunityCaseId(), " | stage=", stage,
         " | channels=", channelCount,
         " | semantics=", channelSemanticCount,
         " | boundaries=", ArraySize(boundaries));
   return true;
  }

void LogOpportunityGeometrySemanticAdvice(long chartID,
                                          OpportunityDrawingState &drawings[],
                                          OpportunityRegionState &regions[],
                                          string trigger)
  {
   if(!InpOpportunityGeometryAdvice) return;
   int trendLines = 0;
   int preReleaseSuggestions = 0;
   int structureSuggestions = 0;
   int reviewSuggestions = 0;
   int comparable = 0;
   int agreements = 0;
   int channelPreReleaseSuggestions = 0;
   for(int i = 0; i < ArraySize(drawings); i++)
     {
      OpportunityGeometryAdvice advice;
      if(!BuildOpportunityGeometryAdvice(chartID, drawings[i], regions, advice)) continue;
      trendLines++;
      if(advice.suggestedRole == "PRE_ACCUMULATION_RELEASE_PATH")
        {
         preReleaseSuggestions++;
         if(advice.channelExcluded) channelPreReleaseSuggestions++;
        }
      else if(advice.suggestedRole == "STRUCTURE_LINE")
         structureSuggestions++;
      else
         reviewSuggestions++;

      string referenceRole = drawings[i].semanticRole;
      bool referenceComparable =
         (referenceRole == "PRE_ACCUMULATION_RELEASE_PATH" || referenceRole == "STRUCTURE_LINE");
      bool agreement = (referenceComparable && advice.suggestedRole == referenceRole);
      if(referenceComparable)
        {
         comparable++;
         if(agreement) agreements++;
        }
      string logLevel = (referenceComparable && !agreement) ? "WARN" : "INFO";
      Print("[EA|FULL|GEOMETRY] ", logLevel,
            " line advice | trigger=", trigger,
            " | case=", OpportunityCaseId(),
            " | id=", drawings[i].drawingId,
            " | suggested=", advice.suggestedRole,
            " | confidence=", DoubleToString(advice.confidence, 3),
            " | reference_role=", referenceRole,
            " | reference_source=", drawings[i].semanticSource,
            " | reference_confirmed=", (int)drawings[i].semanticConfirmed,
            " | agreement=", (int)agreement,
            " | r1_overlap=", DoubleToString(advice.r1Overlap, 3),
            " | r2_overlap=", DoubleToString(advice.r2Overlap, 3),
            " | h1_bars=", advice.effectiveH1Bars,
            " | atr=", DoubleToString(advice.referenceAtr, _Digits),
            " | displacement_atr=", DoubleToString(advice.displacementAtr, 3),
            " | slope_atr_per_bar=", DoubleToString(advice.slopeAtrPerBar, 4),
            " | efficiency=", DoubleToString(advice.pathEfficiency, 3),
            " | first_structure=", advice.firstStructureRole,
            " | first_structure_connected=", (int)advice.firstStructureConnected,
            " | endpoint_distance=", DoubleToString(advice.endpointTimeDistanceBars, 1),
            "bars/", DoubleToString(advice.endpointPriceDistanceAtr, 3), "ATR",
            " | channel_excluded=", (int)advice.channelExcluded,
            " | evidence=", advice.evidence,
            " | color_used=0 | width_used=0 | semantic_input_used=0",
            " | archive_touched=0 | colors_changed=0");
     }

   Print("[EA|FULL|GEOMETRY] INFO advice summary | trigger=", trigger,
         " | case=", OpportunityCaseId(),
         " | mode=read_only_v3",
         " | trend_lines=", trendLines,
         " | pre_release=", preReleaseSuggestions,
         " | structure=", structureSuggestions,
         " | review=", reviewSuggestions,
         " | agreements=", agreements, "/", comparable,
         " | channel_pre_release=", channelPreReleaseSuggestions,
         " | color_used=0 | width_used=0 | semantic_input_used=0",
          " | archive_touched=0 | colors_changed=0 | semantic_fields_changed=0");
  }

bool ResolveOpportunityGeometryPreviewStyle(string suggestedRole,
                                            color &previewColor,
                                            ENUM_LINE_STYLE &previewStyle,
                                            int &previewWidth,
                                            string &labelText)
  {
   if(suggestedRole == "PRE_ACCUMULATION_RELEASE_PATH")
     {
      previewColor = clrDarkViolet;
      previewStyle = STYLE_SOLID;
      previewWidth = OPPORTUNITY_GEOMETRY_PREVIEW_RELEASE_WIDTH;
      labelText = "积累前释放";
      return true;
     }
   if(suggestedRole == "STRUCTURE_LINE")
     {
      previewColor = clrRed;
      previewStyle = STYLE_SOLID;
      previewWidth = OPPORTUNITY_GEOMETRY_PREVIEW_STRUCTURE_WIDTH;
      labelText = "";
      return true;
     }
   if(suggestedRole == "REVIEW_REQUIRED")
     {
      previewColor = clrOrange;
      previewStyle = STYLE_DASH;
      previewWidth = OPPORTUNITY_GEOMETRY_PREVIEW_REVIEW_WIDTH;
      labelText = "待复核";
      return true;
     }
   return false;
  }

bool CreateOpportunityGeometryPreviewLine(long chartID,
                                          OpportunityDrawingState &drawing,
                                          OpportunityGeometryAdvice &advice,
                                          color previewColor,
                                          ENUM_LINE_STYLE previewStyle,
                                          int previewWidth,
                                          string &objectName)
  {
   objectName = OpportunityGeometryObjectPrefix() + drawing.drawingId + "_LINE";
   if(StringLen(objectName) > 63)
     {
      Print("[EA|FULL|GEOMETRY] ERROR preview line name too long | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | length=", StringLen(objectName), " | err=0");
      return false;
     }

   ResetLastError();
   if(!ObjectCreate(chartID, objectName, OBJ_TREND, drawing.subwindow,
                    drawing.time1, drawing.price1,
                    drawing.time2, drawing.price2))
     {
      Print("[EA|FULL|GEOMETRY] ERROR preview line create failed | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | name=", objectName, " | err=", GetLastError(),
            " | archive_touched=0");
      return false;
     }

   ResetLastError();
   bool configured = true;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, previewColor) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_STYLE, previewStyle) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_WIDTH, previewWidth) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_BACK, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, true) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_TIMEFRAMES,
                                 drawing.timeframes == 0 ? OBJ_ALL_PERIODS : drawing.timeframes) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 950) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_RAY_LEFT, drawing.rayLeft) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_RAY_RIGHT, drawing.rayRight) && configured;
   string tooltip = "几何预览 | " + advice.suggestedRole +
                    " | 置信度=" + DoubleToString(advice.confidence, 3) +
                    " | " + drawing.drawingId + " | 非持久化";
   configured = ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP, tooltip) && configured;
   if(!configured)
     {
      int propertyError = GetLastError();
      ObjectDelete(chartID, objectName);
      Print("[EA|FULL|GEOMETRY] ERROR preview line configure failed | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | name=", objectName, " | err=", propertyError,
            " | archive_touched=0");
      return false;
     }
   return true;
  }

bool CreateOpportunityGeometryPreviewTag(long chartID,
                                         OpportunityDrawingState &drawing,
                                         OpportunityGeometryAdvice &advice,
                                         color previewColor,
                                         string labelText,
                                         string &objectName)
  {
   objectName = OpportunityGeometryObjectPrefix() + drawing.drawingId + "_TAG";
   if(StringLen(objectName) > 63)
     {
      Print("[EA|FULL|GEOMETRY] ERROR preview tag name too long | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | length=", StringLen(objectName), " | err=0");
      return false;
     }

   datetime labelTime = drawing.time1 + (drawing.time2 - drawing.time1) / 2;
   double labelPrice = (drawing.price1 + drawing.price2) / 2.0;
   ResetLastError();
   if(!ObjectCreate(chartID, objectName, OBJ_TEXT, drawing.subwindow,
                    labelTime, labelPrice))
     {
      Print("[EA|FULL|GEOMETRY] ERROR preview tag create failed | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | name=", objectName, " | err=", GetLastError(),
            " | archive_touched=0");
      return false;
     }

   ResetLastError();
   bool configured = true;
   configured = ObjectSetString(chartID, objectName, OBJPROP_TEXT, labelText) && configured;
   configured = ObjectSetString(chartID, objectName, OBJPROP_FONT,
                                "Microsoft YaHei UI Bold") && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_FONTSIZE,
                                 OPPORTUNITY_GEOMETRY_PREVIEW_TAG_FONT_SIZE) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, previewColor) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_ANCHOR,
                                 ANCHOR_LEFT_LOWER) && configured;
   configured = ObjectSetDouble(chartID, objectName, OBJPROP_ANGLE, 0.0) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_BACK, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, true) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_TIMEFRAMES,
                                 drawing.timeframes == 0 ? OBJ_ALL_PERIODS : drawing.timeframes) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 951) && configured;
   string tooltip = "几何预览 | " + labelText +
                    " | 置信度=" + DoubleToString(advice.confidence, 3) +
                    " | " + drawing.drawingId + " | 非持久化";
   configured = ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP, tooltip) && configured;
   if(!configured)
     {
      int propertyError = GetLastError();
      ObjectDelete(chartID, objectName);
      Print("[EA|FULL|GEOMETRY] ERROR preview tag configure failed | case=",
            OpportunityCaseId(), " | id=", drawing.drawingId,
            " | name=", objectName, " | err=", propertyError,
            " | archive_touched=0");
      return false;
     }
   return true;
  }

void DeleteOpportunityGeometryPreviewObjects(long chartID)
  {
   int total = ObjectsTotal(chartID, -1, -1);
   int deleted = 0;
   int failed = 0;
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, OPPORTUNITY_GEOMETRY_OBJECT_PREFIX) != 0) continue;
      ResetLastError();
      if(ObjectDelete(chartID, objectName)) deleted++;
      else
        {
         failed++;
         Print("[EA|FULL|GEOMETRY] ERROR preview delete failed | name=",
               objectName, " | err=", GetLastError(),
               " | archive_touched=0");
        }
     }
   if(GV_DEBUG_FULL && (deleted > 0 || failed > 0))
      Print("[EA|FULL|GEOMETRY] INFO preview cleanup | deleted=", deleted,
            " | failed=", failed, " | archive_touched=0");
  }

int DrawOpportunityGeometryPreview(long chartID)
  {
   DeleteOpportunityGeometryPreviewObjects(chartID);
   if(!InpOpportunityGeometryPreview || !opportunityChartViewVisible)
     {
      Print("[EA|FULL|GEOMETRY] INFO preview skipped | case=", OpportunityCaseId(),
            " | enabled=", (int)InpOpportunityGeometryPreview,
            " | view_visible=", (int)opportunityChartViewVisible,
            " | archive_touched=0");
      return 0;
     }

   int trendLines = 0;
   int previewLines = 0;
   int previewLabels = 0;
   int failures = 0;
   int preReleaseLines = 0;
   int structureLines = 0;
   int reviewLines = 0;
   for(int i = 0; i < ArraySize(opportunityDrawings); i++)
     {
      OpportunityGeometryAdvice advice;
      if(!BuildOpportunityGeometryAdvice(chartID, opportunityDrawings[i],
                                         opportunityRegions, advice))
         continue;
      trendLines++;

      color previewColor = clrOrange;
      ENUM_LINE_STYLE previewStyle = STYLE_DASH;
      int previewWidth = OPPORTUNITY_GEOMETRY_PREVIEW_REVIEW_WIDTH;
      string labelText = "";
      if(!ResolveOpportunityGeometryPreviewStyle(advice.suggestedRole,
                                                 previewColor, previewStyle,
                                                 previewWidth, labelText))
        {
         failures++;
         Print("[EA|FULL|GEOMETRY] ERROR preview style unavailable | case=",
               OpportunityCaseId(), " | id=", opportunityDrawings[i].drawingId,
               " | suggested=", advice.suggestedRole,
               " | err=0 | archive_touched=0");
         continue;
        }

      string lineObjectName = "";
      bool lineCreated = CreateOpportunityGeometryPreviewLine(chartID,
                                                               opportunityDrawings[i],
                                                               advice,
                                                               previewColor,
                                                               previewStyle,
                                                               previewWidth,
                                                               lineObjectName);
      bool labelCreated = false;
      string tagObjectName = "";
      if(lineCreated && StringLen(labelText) > 0)
         labelCreated = CreateOpportunityGeometryPreviewTag(chartID,
                                                             opportunityDrawings[i],
                                                             advice,
                                                             previewColor,
                                                             labelText,
                                                             tagObjectName);
      if(lineCreated) previewLines++;
      else failures++;
      if(labelCreated) previewLabels++;
      else if(lineCreated && StringLen(labelText) > 0) failures++;

      if(advice.suggestedRole == "PRE_ACCUMULATION_RELEASE_PATH") preReleaseLines++;
      else if(advice.suggestedRole == "STRUCTURE_LINE") structureLines++;
      else reviewLines++;

      Print("[EA|FULL|GEOMETRY] INFO preview line | case=", OpportunityCaseId(),
            " | id=", opportunityDrawings[i].drawingId,
            " | suggested=", advice.suggestedRole,
            " | confidence=", DoubleToString(advice.confidence, 3),
            " | line_created=", (int)lineCreated,
            " | label_created=", (int)labelCreated,
            " | color=", (int)previewColor,
            " | width=", previewWidth,
            " | style=", (int)previewStyle,
            " | original_changed=0 | archive_touched=0");
     }

   Print("[EA|FULL|GEOMETRY] INFO preview summary | case=", OpportunityCaseId(),
         " | mode=non_persistent_overlay_v1",
         " | enabled=1 | trend_lines=", trendLines,
         " | preview_lines=", previewLines,
         " | preview_labels=", previewLabels,
         " | pre_release=", preReleaseLines,
         " | structure=", structureLines,
         " | review=", reviewLines,
         " | failures=", failures,
         " | original_objects_changed=0 | semantic_fields_changed=0",
         " | archive_touched=0");
   return previewLines;
  }

bool CaptureOpportunityDrawing(long chartID,
                               string objectName,
                               string drawingId,
                               OpportunityDrawingState &drawing)
  {
   if(ObjectFind(chartID, objectName) < 0) return false;

   drawing.drawingId = drawingId;
   drawing.sourceName = objectName;
   drawing.objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
   drawing.subwindow = ObjectFind(chartID, objectName);
   drawing.anchorCount = OpportunityDrawingAnchorCount(drawing.objectType);
   if(drawing.anchorCount <= 0 || drawing.anchorCount > OPPORTUNITY_DRAWING_MAX_ANCHORS)
      return false;

   drawing.time1 = 0;
   drawing.price1 = 0.0;
   drawing.time2 = 0;
   drawing.price2 = 0.0;
   drawing.time3 = 0;
   drawing.price3 = 0.0;
   for(int i = 0; i < drawing.anchorCount; i++)
     {
      datetime anchorTime = (datetime)ObjectGetInteger(chartID, objectName, OBJPROP_TIME, i);
      double anchorPrice = ObjectGetDouble(chartID, objectName, OBJPROP_PRICE, i);
      SetOpportunityDrawingAnchor(drawing, i, anchorTime, anchorPrice);
     }
   SetOpportunityCapturedChannelArchivePriceTexts(drawing);

   drawing.objectColor = (color)ObjectGetInteger(chartID, objectName, OBJPROP_COLOR);
   drawing.lineStyle = (ENUM_LINE_STYLE)ObjectGetInteger(chartID, objectName, OBJPROP_STYLE);
   drawing.lineWidth = (int)ObjectGetInteger(chartID, objectName, OBJPROP_WIDTH);
   drawing.drawInBackground = (bool)ObjectGetInteger(chartID, objectName, OBJPROP_BACK);
   drawing.fill = (bool)ObjectGetInteger(chartID, objectName, OBJPROP_FILL);
   drawing.rayLeft = (bool)ObjectGetInteger(chartID, objectName, OBJPROP_RAY_LEFT);
   drawing.rayRight = (bool)ObjectGetInteger(chartID, objectName, OBJPROP_RAY_RIGHT);
   drawing.angle = ObjectGetDouble(chartID, objectName, OBJPROP_ANGLE);
   drawing.scale = ObjectGetDouble(chartID, objectName, OBJPROP_SCALE);
   drawing.deviation = ObjectGetDouble(chartID, objectName, OBJPROP_DEVIATION);
   drawing.timeframes = ObjectGetInteger(chartID, objectName, OBJPROP_TIMEFRAMES);
   drawing.zorder = ObjectGetInteger(chartID, objectName, OBJPROP_ZORDER);
   drawing.text = ObjectGetString(chartID, objectName, OBJPROP_TEXT);
   drawing.arrowCode = (int)ObjectGetInteger(chartID, objectName, OBJPROP_ARROWCODE);
   drawing.anchor = (ENUM_ANCHOR_POINT)ObjectGetInteger(chartID, objectName, OBJPROP_ANCHOR);
   ResetOpportunityDrawingSemanticFields(drawing);
   ApplyOpportunityDrawingSemanticConvention(drawing);
   return true;
  }

bool OpportunityDrawingIdUsed(OpportunityDrawingState &drawings[], string drawingId)
  {
   for(int i = 0; i < ArraySize(drawings); i++)
      if(drawings[i].drawingId == drawingId) return true;
   return false;
  }

string ResolveOpportunityCapturedDrawingId(long chartID,
                                           string objectName,
                                           string managedPrefix,
                                           OpportunityDrawingState &captured[])
  {
   if(StringFind(objectName, managedPrefix) == 0)
     {
      string managedId = StringSubstr(objectName, StringLen(managedPrefix));
      int managedNumber = (int)StringToInteger(StringSubstr(managedId, 1));
      if(managedNumber > 0 && StringFormat("D%03d", managedNumber) == managedId &&
         !OpportunityDrawingIdUsed(captured, managedId))
         return managedId;
     }

   for(int nextNumber = 1; nextNumber < 100000; nextNumber++)
     {
      string candidate = StringFormat("D%03d", nextNumber);
      if(!OpportunityDrawingIdUsed(captured, candidate) &&
         ObjectFind(chartID, managedPrefix + candidate) < 0)
         return candidate;
     }
   return "";
  }

string OpportunityDrawingTime(datetime value)
  {
   if(value <= 0) return "";
   return TimeToString(value, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
  }

string OpportunityDrawingCsvHeader()
  {
   return "case_id,case_type,drawing_id,source_name,object_type,subwindow,anchor_count,symbol,timeframe," +
          "time_1,price_1,time_2,price_2,time_3,price_3,color,style,width,back,fill,ray_left,ray_right," +
          "angle,scale,deviation,timeframes,zorder,text,arrow_code,anchor,updated_at," +
          "semantic_role,path_id,segment_order,anchor_1_role,anchor_2_role,semantic_source,semantic_confirmed";
  }

string BuildOpportunityDrawingCsvLine(long chartID,
                                      OpportunityDrawingState &drawing,
                                      string updatedAt)
  {
   return OpportunityCaseId() + "," + OpportunityCaseType() + "," +
          OpportunityCsvSafe(drawing.drawingId) + "," + OpportunityCsvSafe(drawing.sourceName) + "," +
          IntegerToString((int)drawing.objectType) + "," + IntegerToString(drawing.subwindow) + "," +
          IntegerToString(drawing.anchorCount) + "," + OpportunityCsvSafe(ChartSymbol(chartID)) + "," +
          TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
          OpportunityDrawingTime(drawing.time1) + "," + OpportunityDrawingArchivePriceText(drawing, 0) + "," +
          OpportunityDrawingTime(drawing.time2) + "," + OpportunityDrawingArchivePriceText(drawing, 1) + "," +
          OpportunityDrawingTime(drawing.time3) + "," + OpportunityDrawingArchivePriceText(drawing, 2) + "," +
          IntegerToString((int)drawing.objectColor) + "," + IntegerToString((int)drawing.lineStyle) + "," +
          IntegerToString(drawing.lineWidth) + "," + IntegerToString((int)drawing.drawInBackground) + "," +
          IntegerToString((int)drawing.fill) + "," + IntegerToString((int)drawing.rayLeft) + "," +
          IntegerToString((int)drawing.rayRight) + "," + DoubleToString(drawing.angle, 8) + "," +
          DoubleToString(drawing.scale, 8) + "," + DoubleToString(drawing.deviation, 8) + "," +
           IntegerToString((int)drawing.timeframes) + "," + IntegerToString((int)drawing.zorder) + "," +
           OpportunityCsvSafe(drawing.text) + "," + IntegerToString(drawing.arrowCode) + "," +
           IntegerToString((int)drawing.anchor) + "," + updatedAt + ",,,,,,,0";
  }

bool SaveOpportunityDrawingSnapshot(long chartID, OpportunityDrawingState &drawings[])
  {
   FinalizeOpportunityDrawingSemantics(drawings);
   OpportunityDrawingState orderedDrawings[];
   int count = ArraySize(drawings);
   ArrayResize(orderedDrawings, count);
   for(int i = 0; i < count; i++) orderedDrawings[i] = drawings[i];
   for(int i = 0; i < count - 1; i++)
      for(int j = i + 1; j < count; j++)
        {
         datetime firstTime = OpportunityDrawingSemanticSortTime(orderedDrawings[i]);
         datetime secondTime = OpportunityDrawingSemanticSortTime(orderedDrawings[j]);
         bool firstTrend = orderedDrawings[i].objectType == OBJ_TREND;
         bool secondTrend = orderedDrawings[j].objectType == OBJ_TREND;
         bool shouldSwap = (secondTrend && !firstTrend) ||
                           (secondTrend == firstTrend &&
                            (secondTime < firstTime ||
                             (secondTime == firstTime &&
                              StringCompare(orderedDrawings[j].drawingId,
                                            orderedDrawings[i].drawingId) < 0)));
         if(shouldSwap)
           {
            OpportunityDrawingState swap = orderedDrawings[i];
            orderedDrawings[i] = orderedDrawings[j];
            orderedDrawings[j] = swap;
           }
        }
   string drawingLines[];
   ArrayResize(drawingLines, count);
   string updatedAt = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   for(int i = 0; i < count; i++)
      drawingLines[i] = BuildOpportunityDrawingCsvLine(chartID, orderedDrawings[i], updatedAt);
   return RewriteOpportunityCsv(InpOpportunityDrawingsCsvPath,
                                 OpportunityDrawingCsvHeader(), drawingLines);
  }

string OpportunityDrawingSemanticCsvHeader()
  {
   return "case_id,case_type,drawing_id,symbol,timeframe,object_type,time_1,price_1,time_2,price_2," +
          "drawing_fingerprint,input_fingerprint,semantic_role,path_id,segment_order,anchor_1_role," +
          "anchor_2_role,semantic_source,algorithm_version,feature_version,schema_version," +
          "decision_status,score,evidence,r1_overlap,r2_overlap,effective_h1_bars,reference_atr," +
          "displacement_atr,slope_atr_per_bar,path_efficiency,first_structure_role," +
          "first_structure_connected,connected_endpoint,endpoint_time_distance_bars," +
          "endpoint_price_distance_atr,channel_excluded,derived_at";
  }

string BuildOpportunityDrawingSemanticCsvLine(OpportunityDrawingSemanticState &semantic)
  {
   return OpportunityCaseId() + "," + OpportunityCaseType() + "," +
          OpportunityCsvSafe(semantic.drawingId) + "," +
          OpportunityCsvSafe(semantic.symbol) + "," +
          OpportunityCsvSafe(semantic.timeframe) + "," +
          IntegerToString((int)semantic.objectType) + "," +
          OpportunityDrawingTime(semantic.time1) + "," +
          OpportunityDrawingSemanticArchivePriceText(semantic, 0) + "," +
          OpportunityDrawingTime(semantic.time2) + "," +
          OpportunityDrawingSemanticArchivePriceText(semantic, 1) + "," +
          OpportunityCsvSafe(semantic.drawingFingerprint) + "," +
          OpportunityCsvSafe(semantic.inputFingerprint) + "," +
          OpportunityCsvSafe(semantic.semanticRole) + "," +
          OpportunityCsvSafe(semantic.pathId) + "," +
          IntegerToString(semantic.segmentOrder) + "," +
          OpportunityCsvSafe(semantic.anchor1Role) + "," +
          OpportunityCsvSafe(semantic.anchor2Role) + "," +
          OpportunityCsvSafe(semantic.semanticSource) + "," +
          OpportunityCsvSafe(semantic.algorithmVersion) + "," +
          OpportunityCsvSafe(semantic.featureVersion) + "," +
          OpportunityCsvSafe(semantic.schemaVersion) + "," +
          OpportunityCsvSafe(semantic.decisionStatus) + "," +
          DoubleToString(semantic.score, 3) + "," +
          OpportunityCsvSafe(semantic.evidence) + "," +
          DoubleToString(semantic.r1Overlap, 3) + "," +
          DoubleToString(semantic.r2Overlap, 3) + "," +
          IntegerToString(semantic.effectiveH1Bars) + "," +
          DoubleToString(semantic.referenceAtr, _Digits) + "," +
          DoubleToString(semantic.displacementAtr, 3) + "," +
          DoubleToString(semantic.slopeAtrPerBar, 4) + "," +
          DoubleToString(semantic.pathEfficiency, 3) + "," +
          OpportunityCsvSafe(semantic.firstStructureRole) + "," +
          IntegerToString((int)semantic.firstStructureConnected) + "," +
          OpportunityCsvSafe(semantic.connectedEndpoint) + "," +
          DoubleToString(semantic.endpointTimeDistanceBars, 1) + "," +
          DoubleToString(semantic.endpointPriceDistanceAtr, 3) + "," +
          IntegerToString((int)semantic.channelExcluded) + "," +
          OpportunityDrawingTime(semantic.derivedAt);
  }

string BuildOpportunityDrawingSemanticComparableLine(
   OpportunityDrawingSemanticState &semantic)
  {
   string fullLine = BuildOpportunityDrawingSemanticCsvLine(semantic);
   int lastComma = -1;
   int searchStart = 0;
   while(true)
     {
      int comma = StringFind(fullLine, ",", searchStart);
      if(comma < 0) break;
      lastComma = comma;
      searchStart = comma + 1;
     }
   return lastComma >= 0 ? StringSubstr(fullLine, 0, lastComma) : fullLine;
  }

string OpportunityDrawingSemanticComparableCsvText(string fullLine)
  {
   int lastComma = -1;
   int searchStart = 0;
   while(true)
     {
      int comma = StringFind(fullLine, ",", searchStart);
      if(comma < 0) break;
      lastComma = comma;
      searchStart = comma + 1;
     }
   return lastComma >= 0 ? StringSubstr(fullLine, 0, lastComma) : fullLine;
  }

int OpportunityDrawingSemanticFirstStringDifference(string expectedValue,
                                                     string loadedValue)
  {
   int expectedLength = StringLen(expectedValue);
   int loadedLength = StringLen(loadedValue);
   int commonLength = expectedLength < loadedLength ? expectedLength : loadedLength;
   for(int i = 0; i < commonLength; i++)
      if(StringGetCharacter(expectedValue, i) != StringGetCharacter(loadedValue, i))
         return i;
   return expectedLength == loadedLength ? -1 : commonLength;
  }

string OpportunityDrawingSemanticMismatchExcerpt(string value,
                                                  int differenceOffset)
  {
   int start = differenceOffset > 40 ? differenceOffset - 40 : 0;
   return StringSubstr(value, start, 80);
  }

void LogOpportunityDrawingSemanticComparableMismatch(string drawingId,
                                                      string expectedLine,
                                                      string loadedLine)
  {
   ushort separator = StringGetCharacter(",", 0);
   string headerFields[];
   string expectedFields[];
   string loadedFields[];
   int headerCount = StringSplit(OpportunityDrawingSemanticCsvHeader(), separator,
                                 headerFields);
   int expectedCount = StringSplit(expectedLine, separator, expectedFields);
   int loadedCount = StringSplit(loadedLine, separator, loadedFields);
   int fieldCount = expectedCount > loadedCount ? expectedCount : loadedCount;
   for(int i = 0; i < fieldCount; i++)
     {
      string expectedValue = i < expectedCount ? expectedFields[i] : "<MISSING>";
      string loadedValue = i < loadedCount ? loadedFields[i] : "<MISSING>";
      if(expectedValue == loadedValue) continue;
      int differenceOffset = OpportunityDrawingSemanticFirstStringDifference(
                                expectedValue, loadedValue);
      string fieldName = i < headerCount ? headerFields[i] : "<UNKNOWN>";
      Print("[EA|FULL|SEMANTIC] ERROR semantic field mismatch | case=",
            OpportunityCaseId(), " | id=", drawingId,
            " | field_index=", i + 1,
            " | field=", fieldName,
            " | difference_offset=", differenceOffset,
            " | expected_length=", StringLen(expectedValue),
            " | loaded_length=", StringLen(loadedValue),
            " | expected_excerpt=",
            OpportunityDrawingSemanticMismatchExcerpt(expectedValue,
                                                       differenceOffset),
            " | loaded_excerpt=",
            OpportunityDrawingSemanticMismatchExcerpt(loadedValue,
                                                       differenceOffset),
            " | archive_touched=0");
      return;
     }
  }

bool SaveOpportunityDrawingSemanticSnapshot(OpportunityDrawingSemanticState &semantics[])
  {
   string semanticLines[];
   ArrayResize(semanticLines, ArraySize(semantics));
   for(int i = 0; i < ArraySize(semantics); i++)
      semanticLines[i] = BuildOpportunityDrawingSemanticCsvLine(semantics[i]);
   return RewriteOpportunityCsv(InpOpportunityDrawingSemanticsCsvPath,
                                OpportunityDrawingSemanticCsvHeader(), semanticLines);
  }

string OpportunityChannelBoundaryCsvHeader()
  {
   return "case_id,case_type,channel_id,source_drawing_id,component_id,native_line_index," +
          "component_role,boundary_role,channel_direction,symbol,timeframe,time_1,price_1," +
          "time_2,price_2,slope_price_per_h1_bar,reference_atr,channel_width_price," +
          "channel_width_atr,parallel_error_price,parallel_error_ratio,parallel_ok," +
          "touch_count,touch_anchor_roles,touch_distance_prices,source_anchor_refs," +
          "coordinate_source,source_drawing_fingerprint,boundary_fingerprint," +
          "algorithm_version,feature_version,schema_version,decision_status,evidence,derived_at";
  }

string BuildOpportunityChannelBoundaryCsvLine(OpportunityChannelBoundaryState &boundary)
  {
   return OpportunityCaseId() + "," + OpportunityCaseType() + "," +
          OpportunityCsvSafe(boundary.channelId) + "," +
          OpportunityCsvSafe(boundary.sourceDrawingId) + "," +
          OpportunityCsvSafe(boundary.componentId) + "," +
          IntegerToString(boundary.nativeLineIndex) + "," +
          OpportunityCsvSafe(boundary.componentRole) + "," +
          OpportunityCsvSafe(boundary.boundaryRole) + "," +
          OpportunityCsvSafe(boundary.channelDirection) + "," +
          OpportunityCsvSafe(boundary.symbol) + "," +
          OpportunityCsvSafe(boundary.timeframe) + "," +
          OpportunityDrawingTime(boundary.time1) + "," +
          DoubleToString(boundary.price1, OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          OpportunityDrawingTime(boundary.time2) + "," +
          DoubleToString(boundary.price2, OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          DoubleToString(boundary.slopePricePerH1Bar,
                         OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          DoubleToString(boundary.referenceAtr,
                         OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          DoubleToString(boundary.channelWidthPrice,
                         OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          DoubleToString(boundary.channelWidthAtr, 12) + "," +
          DoubleToString(boundary.parallelErrorPrice,
                         OPPORTUNITY_CHANNEL_PRICE_DIGITS) + "," +
          DoubleToString(boundary.parallelErrorRatio, 12) + "," +
          IntegerToString((int)boundary.parallelOK) + "," +
          IntegerToString(boundary.touchCount) + "," +
          OpportunityCsvSafe(boundary.touchAnchorRoles) + "," +
          OpportunityCsvSafe(boundary.touchDistancePrices) + "," +
          OpportunityCsvSafe(boundary.sourceAnchorRefs) + "," +
          OpportunityCsvSafe(boundary.coordinateSource) + "," +
          OpportunityCsvSafe(boundary.sourceDrawingFingerprint) + "," +
          OpportunityCsvSafe(boundary.boundaryFingerprint) + "," +
          OpportunityCsvSafe(boundary.algorithmVersion) + "," +
          OpportunityCsvSafe(boundary.featureVersion) + "," +
          OpportunityCsvSafe(boundary.schemaVersion) + "," +
          OpportunityCsvSafe(boundary.decisionStatus) + "," +
          OpportunityCsvSafe(boundary.evidence) + "," +
          OpportunityDrawingTime(boundary.derivedAt);
  }

string BuildOpportunityChannelBoundaryComparableLine(
   OpportunityChannelBoundaryState &boundary)
  {
   string fullLine = BuildOpportunityChannelBoundaryCsvLine(boundary);
   int lastComma = -1;
   int searchStart = 0;
   while(true)
     {
      int comma = StringFind(fullLine, ",", searchStart);
      if(comma < 0) break;
      lastComma = comma;
      searchStart = comma + 1;
     }
   return lastComma >= 0 ? StringSubstr(fullLine, 0, lastComma) : fullLine;
  }

string OpportunityChannelBoundaryComparableCsvText(string fullLine)
  {
   int lastComma = -1;
   int searchStart = 0;
   while(true)
     {
      int comma = StringFind(fullLine, ",", searchStart);
      if(comma < 0) break;
      lastComma = comma;
      searchStart = comma + 1;
     }
   return lastComma >= 0 ? StringSubstr(fullLine, 0, lastComma) : fullLine;
  }

int OpportunityChannelBoundaryFirstStringDifference(string expectedValue,
                                                     string loadedValue)
  {
   int expectedLength = StringLen(expectedValue);
   int loadedLength = StringLen(loadedValue);
   int commonLength = expectedLength < loadedLength ? expectedLength : loadedLength;
   for(int i = 0; i < commonLength; i++)
      if(StringGetCharacter(expectedValue, i) != StringGetCharacter(loadedValue, i))
         return i;
   return expectedLength == loadedLength ? -1 : commonLength;
  }

string OpportunityChannelBoundaryMismatchExcerpt(string value, int differenceOffset)
  {
   int start = differenceOffset > 40 ? differenceOffset - 40 : 0;
   return StringSubstr(value, start, 80);
  }

void LogOpportunityChannelBoundaryComparableMismatch(string sourceDrawingId,
                                                      string componentRole,
                                                      string expectedLine,
                                                      string loadedLine)
  {
   ushort separator = StringGetCharacter(",", 0);
   string headerFields[];
   string expectedFields[];
   string loadedFields[];
   int headerCount = StringSplit(OpportunityChannelBoundaryCsvHeader(), separator,
                                 headerFields);
   int expectedCount = StringSplit(expectedLine, separator, expectedFields);
   int loadedCount = StringSplit(loadedLine, separator, loadedFields);
   int fieldCount = expectedCount > loadedCount ? expectedCount : loadedCount;
   for(int i = 0; i < fieldCount; i++)
     {
      string expectedValue = i < expectedCount ? expectedFields[i] : "<MISSING>";
      string loadedValue = i < loadedCount ? loadedFields[i] : "<MISSING>";
      if(expectedValue == loadedValue) continue;
      int differenceOffset = OpportunityChannelBoundaryFirstStringDifference(
                                expectedValue, loadedValue);
      string fieldName = i < headerCount ? headerFields[i] : "<UNKNOWN>";
      Print("[EA|FULL|CHANNEL] ERROR boundary field mismatch | case=",
            OpportunityCaseId(), " | id=", sourceDrawingId,
            " | component=", componentRole,
            " | field_index=", i + 1,
            " | field=", fieldName,
            " | difference_offset=", differenceOffset,
            " | expected_length=", StringLen(expectedValue),
            " | loaded_length=", StringLen(loadedValue),
            " | expected_excerpt=",
            OpportunityChannelBoundaryMismatchExcerpt(expectedValue,
                                                       differenceOffset),
            " | loaded_excerpt=",
            OpportunityChannelBoundaryMismatchExcerpt(loadedValue,
                                                       differenceOffset),
            " | archive_touched=0");
      return;
     }
  }

bool SaveOpportunityChannelBoundarySnapshot(OpportunityChannelBoundaryState &boundaries[])
  {
   string boundaryLines[];
   ArrayResize(boundaryLines, ArraySize(boundaries));
   for(int i = 0; i < ArraySize(boundaries); i++)
      boundaryLines[i] = BuildOpportunityChannelBoundaryCsvLine(boundaries[i]);
   return RewriteOpportunityCsv(InpOpportunityChannelBoundariesCsvPath,
                                OpportunityChannelBoundaryCsvHeader(),
                                boundaryLines);
  }

int FindLoadedOpportunityChannelBoundary(string sourceDrawingId,
                                         string componentRole)
  {
   return FindOpportunityChannelBoundary(opportunityChannelBoundaries,
                                         sourceDrawingId, componentRole);
  }

bool ValidateOpportunityChannelBoundaryReload(
   OpportunityChannelBoundaryState &expected[])
  {
   if(ArraySize(opportunityChannelBoundaries) != ArraySize(expected)) return false;
   for(int i = 0; i < ArraySize(expected); i++)
     {
      int loadedIndex = FindLoadedOpportunityChannelBoundary(
                           expected[i].sourceDrawingId,
                           expected[i].componentRole);
      if(loadedIndex < 0) return false;
      string expectedLine =
         BuildOpportunityChannelBoundaryComparableLine(expected[i]);
      string loadedLine = opportunityChannelBoundaries[loadedIndex].archiveComparableLine;
      if(StringLen(loadedLine) == 0)
         loadedLine = BuildOpportunityChannelBoundaryComparableLine(
                         opportunityChannelBoundaries[loadedIndex]);
      if(expectedLine != loadedLine)
        {
         LogOpportunityChannelBoundaryComparableMismatch(
            expected[i].sourceDrawingId, expected[i].componentRole,
            expectedLine, loadedLine);
         Print("[EA|FULL|CHANNEL] ERROR reloaded boundary mismatch | case=",
               OpportunityCaseId(), " | id=", expected[i].sourceDrawingId,
               " | component=", expected[i].componentRole,
               " | expected_role=", expected[i].boundaryRole,
               " | loaded_role=",
               opportunityChannelBoundaries[loadedIndex].boundaryRole,
               " | expected_p1=", DoubleToString(expected[i].price1,
                                                   OPPORTUNITY_CHANNEL_PRICE_DIGITS),
               " | loaded_p1=", DoubleToString(
                                     opportunityChannelBoundaries[loadedIndex].price1,
                                     OPPORTUNITY_CHANNEL_PRICE_DIGITS));
         return false;
        }
     }
   return true;
  }

bool LoadOpportunityChannelBoundaries(long chartID)
  {
   ArrayResize(opportunityChannelBoundaries, 0);
   OpportunityChannelBoundaryState expected[];
   if(!BuildOpportunityChannelBoundaries(chartID, opportunityDrawings,
                                         opportunityRegions, false, expected))
     {
      Print("[EA|FULL|CHANNEL] ERROR expected boundaries unavailable | case=",
            OpportunityCaseId(), " | err=0 | archive_touched=0");
      return false;
     }

   ResetLastError();
   int handle = FileOpen(InpOpportunityChannelBoundariesCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      int openError = GetLastError();
      bool validEmpty = (ArraySize(expected) == 0);
      Print("[EA|FULL|CHANNEL] ", validEmpty ? "INFO" : "WARN",
            " archive unavailable | case=", OpportunityCaseId(),
            " | expected=", ArraySize(expected),
            " | path=", InpOpportunityChannelBoundariesCsvPath,
            " | err=", openError,
            " | verified=", (int)validEmpty, " | archive_touched=0");
      return validEmpty;
     }

   ushort separator = StringGetCharacter(",", 0);
   int invalidRows = 0;
   int staleRows = 0;
   int duplicateComponents = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount != 35)
        {
         invalidRows++;
         continue;
        }

      OpportunityChannelBoundaryState boundary;
      boundary.channelId = fields[2];
      boundary.sourceDrawingId = fields[3];
      boundary.componentId = fields[4];
      boundary.nativeLineIndex = (int)StringToInteger(fields[5]);
      boundary.componentRole = fields[6];
      boundary.boundaryRole = fields[7];
      boundary.channelDirection = fields[8];
      boundary.symbol = fields[9];
      boundary.timeframe = fields[10];
      boundary.time1 = StringToTime(fields[11]);
      boundary.price1 = StringToDouble(fields[12]);
      boundary.time2 = StringToTime(fields[13]);
      boundary.price2 = StringToDouble(fields[14]);
      boundary.slopePricePerH1Bar = StringToDouble(fields[15]);
      boundary.referenceAtr = StringToDouble(fields[16]);
      boundary.channelWidthPrice = StringToDouble(fields[17]);
      boundary.channelWidthAtr = StringToDouble(fields[18]);
      boundary.parallelErrorPrice = StringToDouble(fields[19]);
      boundary.parallelErrorRatio = StringToDouble(fields[20]);
      boundary.parallelOK = (bool)StringToInteger(fields[21]);
      boundary.touchCount = (int)StringToInteger(fields[22]);
      boundary.touchAnchorRoles = fields[23];
      boundary.touchDistancePrices = fields[24];
      boundary.sourceAnchorRefs = fields[25];
      boundary.coordinateSource = fields[26];
      boundary.sourceDrawingFingerprint = fields[27];
      boundary.boundaryFingerprint = fields[28];
      boundary.algorithmVersion = fields[29];
      boundary.featureVersion = fields[30];
      boundary.schemaVersion = fields[31];
      boundary.decisionStatus = fields[32];
      boundary.evidence = fields[33];
      boundary.derivedAt = StringToTime(fields[34]);

      int expectedIndex = FindOpportunityChannelBoundary(expected,
                                                         boundary.sourceDrawingId,
                                                         boundary.componentRole);
      bool basicValid = (fields[1] == OpportunityCaseType() &&
                         boundary.channelId == boundary.sourceDrawingId &&
                         boundary.componentId == boundary.sourceDrawingId +
                                                 (boundary.componentRole == "MAIN_LINE" ?
                                                  "-MAIN" : "-PARALLEL") &&
                         (boundary.nativeLineIndex == 0 ||
                          boundary.nativeLineIndex == 1) &&
                         (boundary.componentRole == "MAIN_LINE" ||
                          boundary.componentRole == "PARALLEL_LINE") &&
                         (boundary.boundaryRole == "CHANNEL_UPPER_BOUNDARY" ||
                          boundary.boundaryRole == "CHANNEL_LOWER_BOUNDARY") &&
                         boundary.symbol == opportunityAnnotationNativeSymbol &&
                         boundary.timeframe == opportunityAnnotationNativeTimeframe &&
                         boundary.time1 > 0 && boundary.time2 > 0 &&
                         boundary.time1 != boundary.time2 &&
                         boundary.price1 > 0.0 && boundary.price2 > 0.0 &&
                         boundary.parallelOK && boundary.touchCount >= 0 &&
                         boundary.algorithmVersion == OPPORTUNITY_CHANNEL_ALGORITHM_VERSION &&
                         boundary.featureVersion == OPPORTUNITY_CHANNEL_FEATURE_VERSION &&
                         boundary.schemaVersion == OPPORTUNITY_CHANNEL_SCHEMA_VERSION &&
                         boundary.decisionStatus == "CONFIRMED" &&
                         boundary.evidence == "NATIVE_EQUIDISTANT_CHANNEL_EXPANDED");
      if(!basicValid)
        {
         invalidRows++;
         continue;
        }
      string loadedComparableLine =
         OpportunityChannelBoundaryComparableCsvText(line);
      string expectedComparableLine = expectedIndex >= 0 ?
         BuildOpportunityChannelBoundaryComparableLine(expected[expectedIndex]) : "";
      if(expectedIndex < 0 || loadedComparableLine != expectedComparableLine)
        {
         staleRows++;
         if(expectedIndex >= 0)
            LogOpportunityChannelBoundaryComparableMismatch(
               boundary.sourceDrawingId, boundary.componentRole,
               expectedComparableLine, loadedComparableLine);
         Print("[EA|FULL|CHANNEL] WARN stale boundary ignored | case=",
               OpportunityCaseId(), " | id=", boundary.sourceDrawingId,
               " | component=", boundary.componentRole,
               " | source_match=", (int)(expectedIndex >= 0),
               " | archive_touched=0");
         continue;
        }
      if(FindLoadedOpportunityChannelBoundary(boundary.sourceDrawingId,
                                              boundary.componentRole) >= 0)
        {
         duplicateComponents++;
         continue;
        }
      int index = ArraySize(opportunityChannelBoundaries);
      ArrayResize(opportunityChannelBoundaries, index + 1);
      boundary.archiveComparableLine = loadedComparableLine;
      opportunityChannelBoundaries[index] = boundary;
     }
   FileClose(handle);

   bool valid = (ArraySize(opportunityChannelBoundaries) == ArraySize(expected) &&
                 invalidRows == 0 && staleRows == 0 && duplicateComponents == 0 &&
                 ValidateOpportunityChannelBoundaryReload(expected));
   Print("[EA|FULL|CHANNEL] ", valid ? "INFO" : "WARN",
         " archive loaded | case=", OpportunityCaseId(),
         " | rows=", ArraySize(opportunityChannelBoundaries),
         " | expected=", ArraySize(expected),
         " | invalid=", invalidRows,
         " | stale=", staleRows,
         " | duplicate_components=", duplicateComponents,
         " | verified=", (int)valid,
         " | archive_touched=0");
   return valid;
  }

int FindOpportunityDrawingById(string drawingId)
  {
   for(int i = 0; i < ArraySize(opportunityDrawings); i++)
      if(opportunityDrawings[i].drawingId == drawingId) return i;
   return -1;
  }

bool LoadOpportunityDrawingSemantics(long chartID, bool allowLegacyReadOnlyRecompute)
  {
   ArrayResize(opportunityDrawingSemantics, 0);
   OpportunityDrawingSemanticState expected[];
   BuildOpportunityDrawingSemantics(chartID, opportunityDrawings,
                                    opportunityRegions,
                                    opportunityChannelBoundaries,
                                    expected);
   ResetLastError();
   int handle = FileOpen(InpOpportunityDrawingSemanticsCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      int openError = GetLastError();
      bool validEmpty = (ArraySize(expected) == 0);
      Print("[EA|FULL|SEMANTIC] ", validEmpty ? "INFO" : "WARN",
            " archive unavailable | case=", OpportunityCaseId(),
            " | expected=", ArraySize(expected),
            " | path=", InpOpportunityDrawingSemanticsCsvPath,
            " | err=", openError, " | verified=", (int)validEmpty,
            " | archive_touched=0");
      return validEmpty;
     }

   ushort separator = StringGetCharacter(",", 0);
   int invalidRows = 0;
   int staleRows = 0;
   int duplicateOrders = 0;
   int duplicateDrawingIds = 0;
   int compatibleLegacyRows = 0;
   int compatibleV1Rows = 0;
   int compatibleV2Rows = 0;
   int caseRows = 0;
   bool expectedSeen[];
   ArrayResize(expectedSeen, ArraySize(expected));
   for(int i = 0; i < ArraySize(expectedSeen); i++) expectedSeen[i] = false;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;
      caseRows++;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount != 38)
        {
         invalidRows++;
         continue;
        }

      OpportunityDrawingSemanticState semantic;
      semantic.drawingId = fields[2];
      semantic.symbol = fields[3];
      semantic.timeframe = fields[4];
      semantic.objectType = (ENUM_OBJECT)StringToInteger(fields[5]);
      semantic.time1 = StringToTime(fields[6]);
      semantic.price1 = StringToDouble(fields[7]);
      semantic.time2 = StringToTime(fields[8]);
      semantic.price2 = StringToDouble(fields[9]);
      semantic.price1ArchiveText = semantic.objectType == OBJ_CHANNEL ? fields[7] : "";
      semantic.price2ArchiveText = semantic.objectType == OBJ_CHANNEL ? fields[9] : "";
      semantic.drawingFingerprint = fields[10];
      semantic.inputFingerprint = fields[11];
      semantic.semanticRole = fields[12];
      semantic.pathId = fields[13];
      semantic.segmentOrder = (int)StringToInteger(fields[14]);
      semantic.anchor1Role = fields[15];
      semantic.anchor2Role = fields[16];
      semantic.semanticSource = fields[17];
      semantic.algorithmVersion = fields[18];
      semantic.featureVersion = fields[19];
      semantic.schemaVersion = fields[20];
      semantic.decisionStatus = fields[21];
      semantic.score = StringToDouble(fields[22]);
      semantic.evidence = fields[23];
      semantic.r1Overlap = StringToDouble(fields[24]);
      semantic.r2Overlap = StringToDouble(fields[25]);
      semantic.effectiveH1Bars = (int)StringToInteger(fields[26]);
      semantic.referenceAtr = StringToDouble(fields[27]);
      semantic.displacementAtr = StringToDouble(fields[28]);
      semantic.slopeAtrPerBar = StringToDouble(fields[29]);
      semantic.pathEfficiency = StringToDouble(fields[30]);
      semantic.firstStructureRole = fields[31];
      semantic.firstStructureConnected = (bool)StringToInteger(fields[32]);
      semantic.connectedEndpoint = fields[33];
      semantic.endpointTimeDistanceBars = StringToDouble(fields[34]);
      semantic.endpointPriceDistanceAtr = StringToDouble(fields[35]);
      semantic.channelExcluded = (bool)StringToInteger(fields[36]);
      semantic.derivedAt = StringToTime(fields[37]);

      int expectedIndex = -1;
      for(int i = 0; i < ArraySize(expected); i++)
         if(expected[i].drawingId == semantic.drawingId)
           {
            expectedIndex = i;
            break;
           }
      if(expectedIndex >= 0)
        {
         if(expectedSeen[expectedIndex]) duplicateDrawingIds++;
         else expectedSeen[expectedIndex] = true;
        }
      string loadedComparableLine =
         OpportunityDrawingSemanticComparableCsvText(line);
      string expectedComparableLine = expectedIndex >= 0 ?
         BuildOpportunityDrawingSemanticComparableLine(expected[expectedIndex]) : "";
      if(expectedIndex < 0 || loadedComparableLine != expectedComparableLine)
        {
         staleRows++;
         bool legacyV1 =
            (semantic.algorithmVersion == OPPORTUNITY_GEOMETRY_LEGACY_ALGORITHM_VERSION &&
             semantic.featureVersion == OPPORTUNITY_GEOMETRY_LEGACY_FEATURE_VERSION);
         bool legacyV2 =
            (semantic.algorithmVersion == OPPORTUNITY_GEOMETRY_PREVIOUS_ALGORITHM_VERSION &&
             semantic.featureVersion == OPPORTUNITY_GEOMETRY_PREVIOUS_FEATURE_VERSION);
         bool compatibleLegacy =
            (allowLegacyReadOnlyRecompute && expectedIndex >= 0 &&
             fields[1] == OpportunityCaseType() &&
             semantic.objectType == OBJ_TREND &&
             semantic.symbol == expected[expectedIndex].symbol &&
             semantic.timeframe == expected[expectedIndex].timeframe &&
             semantic.drawingFingerprint == expected[expectedIndex].drawingFingerprint &&
             semantic.semanticSource == "GEOMETRY_ALGORITHM" &&
             (legacyV1 || legacyV2) &&
             semantic.schemaVersion == OPPORTUNITY_DRAWING_SEMANTIC_SCHEMA_VERSION);
         if(compatibleLegacy)
           {
            compatibleLegacyRows++;
            if(legacyV1) compatibleV1Rows++;
            else if(legacyV2) compatibleV2Rows++;
           }
         else
           {
            if(expectedIndex >= 0)
               LogOpportunityDrawingSemanticComparableMismatch(
                  semantic.drawingId, expectedComparableLine, loadedComparableLine);
            Print("[EA|FULL|SEMANTIC] WARN derived row mismatch ignored | case=",
                  OpportunityCaseId(), " | id=", semantic.drawingId,
                  " | stored_role=", semantic.semanticRole,
                  " | expected_role=", expectedIndex >= 0 ?
                                        expected[expectedIndex].semanticRole : "MISSING",
                  " | stored_order=", semantic.segmentOrder,
                  " | expected_order=", expectedIndex >= 0 ?
                                         expected[expectedIndex].segmentOrder : 0,
                  " | archive_touched=0");
           }
         continue;
        }
      for(int i = 0; i < ArraySize(opportunityDrawingSemantics); i++)
         if(opportunityDrawingSemantics[i].segmentOrder == semantic.segmentOrder)
            duplicateOrders++;
      int index = ArraySize(opportunityDrawingSemantics);
      ArrayResize(opportunityDrawingSemantics, index + 1);
      semantic.archiveComparableLine = loadedComparableLine;
      opportunityDrawingSemantics[index] = semantic;
     }
   FileClose(handle);

   int exactRows = ArraySize(opportunityDrawingSemantics);
   bool strictValid = (exactRows == ArraySize(expected) &&
                       invalidRows == 0 && staleRows == 0 &&
                       duplicateOrders == 0 && duplicateDrawingIds == 0);
   bool recomputedReadOnly =
      (!strictValid && allowLegacyReadOnlyRecompute && compatibleLegacyRows > 0 &&
       invalidRows == 0 && duplicateOrders == 0 && duplicateDrawingIds == 0 &&
       caseRows == ArraySize(expected) &&
       exactRows + compatibleLegacyRows == ArraySize(expected));
   if(recomputedReadOnly)
     {
      ArrayResize(opportunityDrawingSemantics, ArraySize(expected));
      for(int i = 0; i < ArraySize(expected); i++)
         opportunityDrawingSemantics[i] = expected[i];
     }
   bool valid = (strictValid || recomputedReadOnly);
   Print("[EA|FULL|SEMANTIC] ", valid ? "INFO" : "WARN",
         " archive resolved | case=", OpportunityCaseId(),
         " | rows=", ArraySize(opportunityDrawingSemantics),
         " | expected=", ArraySize(expected),
         " | archive_rows=", caseRows,
         " | invalid=", invalidRows,
         " | stale=", staleRows,
         " | duplicate_orders=", duplicateOrders,
         " | duplicate_drawing_ids=", duplicateDrawingIds,
         " | compatible_legacy=", compatibleLegacyRows,
         " | compatible_v1=", compatibleV1Rows,
         " | compatible_v2=", compatibleV2Rows,
         " | strict=", (int)strictValid,
         " | recomputed_read_only=", (int)recomputedReadOnly,
         " | verified=", (int)valid,
         " | archive_touched=0");
   return valid;
  }

int FindLoadedOpportunityDrawingSemantic(string drawingId)
  {
   for(int i = 0; i < ArraySize(opportunityDrawingSemantics); i++)
      if(opportunityDrawingSemantics[i].drawingId == drawingId) return i;
   return -1;
  }

bool ValidateOpportunityDrawingSemanticReload(OpportunityDrawingSemanticState &expected[])
  {
   if(ArraySize(opportunityDrawingSemantics) != ArraySize(expected)) return false;
   for(int i = 0; i < ArraySize(expected); i++)
     {
      int loadedIndex = FindLoadedOpportunityDrawingSemantic(expected[i].drawingId);
      if(loadedIndex < 0) return false;
      string expectedLine =
         BuildOpportunityDrawingSemanticComparableLine(expected[i]);
      string loadedLine =
         opportunityDrawingSemantics[loadedIndex].archiveComparableLine;
      if(StringLen(loadedLine) == 0)
         loadedLine = BuildOpportunityDrawingSemanticComparableLine(
                         opportunityDrawingSemantics[loadedIndex]);
      if(expectedLine != loadedLine)
        {
         LogOpportunityDrawingSemanticComparableMismatch(
            expected[i].drawingId, expectedLine, loadedLine);
         Print("[EA|FULL|SEMANTIC] ERROR reloaded row mismatch | case=",
               OpportunityCaseId(), " | id=", expected[i].drawingId,
               " | expected_role=", expected[i].semanticRole,
               " | loaded_role=", opportunityDrawingSemantics[loadedIndex].semanticRole,
               " | expected_order=", expected[i].segmentOrder,
               " | loaded_order=", opportunityDrawingSemantics[loadedIndex].segmentOrder,
               " | expected_score=", DoubleToString(expected[i].score, 3),
               " | loaded_score=", DoubleToString(
                                      opportunityDrawingSemantics[loadedIndex].score, 3));
         return false;
        }
     }
   return true;
  }

string OpportunityRegionCsvHeader()
  {
   return "case_id,case_type,region_id,region_role,display_name,symbol,timeframe," +
          "start_drawing_id,end_drawing_id,start_time,end_time,updated_at";
  }

bool BuildOpportunityRegionsFromDrawings(long chartID,
                                         OpportunityDrawingState &drawings[],
                                         OpportunityRegionState &regions[])
  {
   ArrayResize(regions, 0);
   int boundaryIndices[];
   for(int i = 0; i < ArraySize(drawings); i++)
     {
      if(drawings[i].objectType != OBJ_VLINE) continue;
      int boundaryIndex = ArraySize(boundaryIndices);
      ArrayResize(boundaryIndices, boundaryIndex + 1);
      boundaryIndices[boundaryIndex] = i;
     }

   int boundaryCount = ArraySize(boundaryIndices);
   if(boundaryCount != OPPORTUNITY_REGION_BOUNDARY_COUNT)
     {
      Print("[EA|FULL|REGION] WARN region labels require exactly four vertical boundaries | case=",
            OpportunityCaseId(), " | boundaries=", boundaryCount,
            " | expected=", OPPORTUNITY_REGION_BOUNDARY_COUNT);
      return false;
     }

   for(int i = 1; i < boundaryCount; i++)
     {
      int current = boundaryIndices[i];
      int j = i - 1;
      while(j >= 0 && drawings[boundaryIndices[j]].time1 > drawings[current].time1)
        {
         boundaryIndices[j + 1] = boundaryIndices[j];
         j--;
        }
      boundaryIndices[j + 1] = current;
     }

   for(int i = 0; i < boundaryCount; i++)
     {
      datetime boundaryTime = drawings[boundaryIndices[i]].time1;
      if(boundaryTime <= 0 ||
         (i > 0 && boundaryTime <= drawings[boundaryIndices[i - 1]].time1))
        {
         Print("[EA|FULL|REGION] ERROR invalid or duplicate vertical boundary time | case=",
               OpportunityCaseId(), " | order=", i + 1,
               " | time=", TimeToString(boundaryTime, TIME_DATE|TIME_MINUTES));
         ArrayResize(regions, 0);
         return false;
        }
     }

   ArrayResize(regions, OPPORTUNITY_REGION_COUNT);
   for(int i = 0; i < OPPORTUNITY_REGION_COUNT; i++)
     {
      OpportunityDrawingState startBoundary = drawings[boundaryIndices[i]];
      OpportunityDrawingState endBoundary = drawings[boundaryIndices[i + 1]];
      regions[i].regionId = "R" + IntegerToString(i + 1);
      regions[i].role = OpportunityRegionRole(i);
      regions[i].displayName = OpportunityRegionDisplayName(i);
      regions[i].startDrawingId = startBoundary.drawingId;
      regions[i].endDrawingId = endBoundary.drawingId;
      regions[i].startTime = startBoundary.time1;
      regions[i].endTime = endBoundary.time1;
     }

   Print("[EA|FULL|REGION] INFO regions derived | case=", OpportunityCaseId(),
         " | boundaries=", boundaryCount,
         " | regions=", ArraySize(regions),
         " | span=", TimeToString(regions[0].startTime, TIME_DATE|TIME_MINUTES),
         "..", TimeToString(regions[OPPORTUNITY_REGION_COUNT - 1].endTime,
                             TIME_DATE|TIME_MINUTES));
   return true;
  }

bool SaveOpportunityRegionSnapshot(long chartID, OpportunityRegionState &regions[])
  {
   string regionLines[];
   int count = ArraySize(regions);
   ArrayResize(regionLines, count);
   string updatedAt = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   for(int i = 0; i < count; i++)
     {
      regionLines[i] = OpportunityCaseId() + "," + OpportunityCaseType() + "," +
                       OpportunityCsvSafe(regions[i].regionId) + "," +
                       OpportunityCsvSafe(regions[i].role) + "," +
                       OpportunityCsvSafe(regions[i].displayName) + "," +
                       OpportunityCsvSafe(ChartSymbol(chartID)) + "," +
                       TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
                       OpportunityCsvSafe(regions[i].startDrawingId) + "," +
                       OpportunityCsvSafe(regions[i].endDrawingId) + "," +
                       OpportunityDrawingTime(regions[i].startTime) + "," +
                       OpportunityDrawingTime(regions[i].endTime) + "," + updatedAt;
     }
   return RewriteOpportunityCsv(InpOpportunityRegionsCsvPath,
                                OpportunityRegionCsvHeader(), regionLines);
  }

bool LoadOpportunityRegions(long chartID)
  {
   ArrayResize(opportunityRegions, 0);
   ResetLastError();
   int handle = FileOpen(InpOpportunityRegionsCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|REGION] INFO archive unavailable; starting empty | path=",
               InpOpportunityRegionsCsvPath, " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int invalidRows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 12)
        {
         invalidRows++;
         continue;
        }

      OpportunityRegionState region;
      region.regionId = fields[2];
      region.role = fields[3];
      region.displayName = fields[4];
      region.startDrawingId = fields[7];
      region.endDrawingId = fields[8];
      region.startTime = StringToTime(fields[9]);
      region.endTime = StringToTime(fields[10]);
      if(StringLen(region.regionId) == 0 || StringLen(region.role) == 0 ||
         StringLen(region.displayName) == 0 || region.startTime <= 0 ||
         region.endTime <= region.startTime)
        {
         invalidRows++;
         continue;
        }

      int index = ArraySize(opportunityRegions);
      ArrayResize(opportunityRegions, index + 1);
      opportunityRegions[index] = region;
     }
   FileClose(handle);

   int count = ArraySize(opportunityRegions);
   for(int i = 1; i < count; i++)
     {
      OpportunityRegionState current = opportunityRegions[i];
      int j = i - 1;
      while(j >= 0 && opportunityRegions[j].startTime > current.startTime)
        {
         opportunityRegions[j + 1] = opportunityRegions[j];
         j--;
        }
      opportunityRegions[j + 1] = current;
     }

   if(count != 0 && count != OPPORTUNITY_REGION_COUNT) invalidRows++;
   if(count == OPPORTUNITY_REGION_COUNT)
     {
      for(int i = 0; i < count; i++)
        {
         if(opportunityRegions[i].role != OpportunityRegionRole(i) ||
            (i > 0 && opportunityRegions[i].startTime != opportunityRegions[i - 1].endTime))
            invalidRows++;
        }
     }

   if(invalidRows > 0)
     {
      Print("[EA|FULL|REGION] ERROR archive validation failed | case=", OpportunityCaseId(),
            " | rows=", count, " | invalid=", invalidRows,
            " | path=", InpOpportunityRegionsCsvPath);
      ArrayResize(opportunityRegions, 0);
      return false;
     }

   Print("[EA|FULL|REGION] INFO archive loaded | case=", OpportunityCaseId(),
         " | regions=", count, " | invalid_rows=0",
         " | path=", InpOpportunityRegionsCsvPath);
   return (count == OPPORTUNITY_REGION_COUNT);
  }

bool LoadOpportunityDrawings(long chartID)
  {
   ArrayResize(opportunityDrawings, 0);
   ResetLastError();
   int handle = FileOpen(InpOpportunityDrawingsCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|DRAWING] INFO archive unavailable; starting empty | path=",
               InpOpportunityDrawingsCsvPath, " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int invalidRows = 0;
   int semanticRows = 0;
   int legacyRows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
       if(fieldCount < 31)
         {
          invalidRows++;
          continue;
         }
       if(fieldCount > 31 && fieldCount < 38)
         {
          invalidRows++;
          continue;
         }

       OpportunityDrawingState drawing;
       ResetOpportunityDrawingSemanticFields(drawing);
       drawing.drawingId = fields[2];
      drawing.sourceName = fields[3];
      drawing.objectType = (ENUM_OBJECT)StringToInteger(fields[4]);
      drawing.subwindow = (int)StringToInteger(fields[5]);
      drawing.anchorCount = (int)StringToInteger(fields[6]);
      drawing.time1 = StringToTime(fields[9]);
      drawing.price1 = StringToDouble(fields[10]);
      drawing.time2 = StringToTime(fields[11]);
      drawing.price2 = StringToDouble(fields[12]);
      drawing.time3 = StringToTime(fields[13]);
      drawing.price3 = StringToDouble(fields[14]);
      SetOpportunityChannelArchivePriceTexts(drawing, fields[10],
                                             fields[12], fields[14]);
      drawing.objectColor = (color)StringToInteger(fields[15]);
      drawing.lineStyle = (ENUM_LINE_STYLE)StringToInteger(fields[16]);
      drawing.lineWidth = (int)StringToInteger(fields[17]);
      drawing.drawInBackground = (bool)StringToInteger(fields[18]);
      drawing.fill = (bool)StringToInteger(fields[19]);
      drawing.rayLeft = (bool)StringToInteger(fields[20]);
      drawing.rayRight = (bool)StringToInteger(fields[21]);
      drawing.angle = StringToDouble(fields[22]);
      drawing.scale = StringToDouble(fields[23]);
      drawing.deviation = StringToDouble(fields[24]);
      drawing.timeframes = (long)StringToInteger(fields[25]);
      drawing.zorder = (long)StringToInteger(fields[26]);
       drawing.text = fields[27];
       drawing.arrowCode = (int)StringToInteger(fields[28]);
       drawing.anchor = (ENUM_ANCHOR_POINT)StringToInteger(fields[29]);
       if(fieldCount >= 38)
         {
          drawing.semanticRole = fields[31];
          drawing.pathId = fields[32];
          drawing.segmentOrder = (int)StringToInteger(fields[33]);
          drawing.anchor1Role = fields[34];
          drawing.anchor2Role = fields[35];
          drawing.semanticSource = fields[36];
          drawing.semanticConfirmed = (bool)StringToInteger(fields[37]);
          semanticRows++;
         }
       else
          legacyRows++;

      int expectedAnchors = OpportunityDrawingAnchorCount(drawing.objectType);
      if(StringLen(drawing.drawingId) == 0 || drawing.anchorCount != expectedAnchors ||
         drawing.anchorCount <= 0 || drawing.anchorCount > OPPORTUNITY_DRAWING_MAX_ANCHORS)
        {
         invalidRows++;
         continue;
        }

      int index = ArraySize(opportunityDrawings);
      ArrayResize(opportunityDrawings, index + 1);
       opportunityDrawings[index] = drawing;
      }
    FileClose(handle);

    FinalizeOpportunityDrawingSemantics(opportunityDrawings);
    int preReleaseSegments = 0;
    int structureLines = 0;
    int linkedStructureAnchors = 0;
    int unclassifiedTrendLines = 0;
    for(int i = 0; i < ArraySize(opportunityDrawings); i++)
      {
       if(opportunityDrawings[i].semanticRole == "PRE_ACCUMULATION_RELEASE_PATH")
          preReleaseSegments++;
       else if(opportunityDrawings[i].semanticRole == "STRUCTURE_LINE")
         {
          structureLines++;
          if(StringLen(opportunityDrawings[i].anchor1Role) > 0) linkedStructureAnchors++;
          if(StringLen(opportunityDrawings[i].anchor2Role) > 0) linkedStructureAnchors++;
         }
       else if(opportunityDrawings[i].objectType == OBJ_TREND)
          unclassifiedTrendLines++;
      }

    Print("[EA|FULL|DRAWING] INFO archive loaded | case=", OpportunityCaseId(),
          " | drawings=", ArraySize(opportunityDrawings),
          " | invalid_rows=", invalidRows,
          " | semantic_rows=", semanticRows,
          " | legacy_derived=", legacyRows,
          " | pre_release_segments=", preReleaseSegments,
          " | structure_lines=", structureLines,
          " | linked_structure_anchors=", linkedStructureAnchors,
          " | unclassified_trend_lines=", unclassifiedTrendLines,
          " | path=", InpOpportunityDrawingsCsvPath);
   return (ArraySize(opportunityDrawings) > 0 && invalidRows == 0);
  }

bool OpportunityDrawingSupportsFill(ENUM_OBJECT objectType)
  {
   return (objectType == OBJ_CHANNEL || objectType == OBJ_STDDEVCHANNEL ||
           objectType == OBJ_REGRESSION || objectType == OBJ_FIBOCHANNEL ||
           objectType == OBJ_RECTANGLE || objectType == OBJ_TRIANGLE ||
           objectType == OBJ_ELLIPSE);
  }

bool OpportunityDrawingSupportsRays(ENUM_OBJECT objectType)
  {
   return (objectType == OBJ_TREND || objectType == OBJ_ARROWED_LINE ||
           objectType == OBJ_CHANNEL || objectType == OBJ_STDDEVCHANNEL ||
           objectType == OBJ_REGRESSION || objectType == OBJ_PITCHFORK ||
           objectType == OBJ_GANNLINE || objectType == OBJ_GANNFAN ||
           objectType == OBJ_GANNGRID || objectType == OBJ_FIBO ||
           objectType == OBJ_FIBOTIMES || objectType == OBJ_FIBOFAN ||
           objectType == OBJ_FIBOARC || objectType == OBJ_FIBOCHANNEL ||
           objectType == OBJ_EXPANSION);
  }

bool CreateOpportunityDrawing(long chartID, OpportunityDrawingState &drawing)
  {
   string objectName = OpportunityDrawingObjectPrefix() + drawing.drawingId;
   ResetLastError();
   bool created = false;
   if(drawing.anchorCount == 1)
      created = ObjectCreate(chartID, objectName, drawing.objectType, drawing.subwindow,
                             drawing.time1, drawing.price1);
   else if(drawing.anchorCount == 2)
      created = ObjectCreate(chartID, objectName, drawing.objectType, drawing.subwindow,
                             drawing.time1, drawing.price1,
                             drawing.time2, drawing.price2);
   else if(drawing.anchorCount == 3)
      created = ObjectCreate(chartID, objectName, drawing.objectType, drawing.subwindow,
                             drawing.time1, drawing.price1,
                             drawing.time2, drawing.price2,
                             drawing.time3, drawing.price3);

   if(!created)
     {
      Print("[EA|FULL|DRAWING] ERROR redraw create failed | id=", drawing.drawingId,
            " | source=", drawing.sourceName,
            " | type=", (int)drawing.objectType,
            " | anchors=", drawing.anchorCount,
            " | err=", GetLastError());
      return false;
     }

   ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, drawing.objectColor);
   ObjectSetInteger(chartID, objectName, OBJPROP_STYLE, drawing.lineStyle);
   ObjectSetInteger(chartID, objectName, OBJPROP_WIDTH, MathMax(1, drawing.lineWidth));
   ObjectSetInteger(chartID, objectName, OBJPROP_BACK, drawing.drawInBackground);
   ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartID, objectName, OBJPROP_TIMEFRAMES,
                    drawing.timeframes == 0 ? OBJ_ALL_PERIODS : drawing.timeframes);
   ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, drawing.zorder);
   if(StringLen(drawing.text) > 0)
      ObjectSetString(chartID, objectName, OBJPROP_TEXT, drawing.text);

   if(OpportunityDrawingSupportsFill(drawing.objectType))
      ObjectSetInteger(chartID, objectName, OBJPROP_FILL, drawing.fill);
   if(OpportunityDrawingSupportsRays(drawing.objectType))
     {
      ObjectSetInteger(chartID, objectName, OBJPROP_RAY_LEFT, drawing.rayLeft);
      ObjectSetInteger(chartID, objectName, OBJPROP_RAY_RIGHT, drawing.rayRight);
     }
   if(drawing.objectType == OBJ_TRENDBYANGLE)
      ObjectSetDouble(chartID, objectName, OBJPROP_ANGLE, drawing.angle);
   if(drawing.objectType == OBJ_GANNLINE || drawing.objectType == OBJ_GANNFAN ||
      drawing.objectType == OBJ_GANNGRID || drawing.objectType == OBJ_FIBOARC)
      ObjectSetDouble(chartID, objectName, OBJPROP_SCALE, drawing.scale);
   if(drawing.objectType == OBJ_STDDEVCHANNEL)
      ObjectSetDouble(chartID, objectName, OBJPROP_DEVIATION, drawing.deviation);

   if(drawing.objectType >= OBJ_ARROW_THUMB_UP && drawing.objectType <= OBJ_ARROW)
     {
      ObjectSetInteger(chartID, objectName, OBJPROP_ARROWCODE, drawing.arrowCode);
      ObjectSetInteger(chartID, objectName, OBJPROP_ANCHOR, drawing.anchor);
     }
   if(drawing.objectType == OBJ_TEXT)
      ObjectSetInteger(chartID, objectName, OBJPROP_ANCHOR, drawing.anchor);

   string semanticText = StringLen(drawing.semanticRole) > 0 ?
                         " | " + drawing.semanticRole : "";
   ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP,
                   "EXTRACTED | " + drawing.sourceName + semanticText + " | " + OpportunityCaseId());
   if(drawing.objectType == OBJ_CHANNEL)
     {
      ResetLastError();
      color actualColor = (color)ObjectGetInteger(chartID, objectName, OBJPROP_COLOR);
      ENUM_LINE_STYLE actualStyle =
         (ENUM_LINE_STYLE)ObjectGetInteger(chartID, objectName, OBJPROP_STYLE);
      int actualWidth = (int)ObjectGetInteger(chartID, objectName, OBJPROP_WIDTH);
      int propertyError = GetLastError();
      bool styleVerified = (actualColor == drawing.objectColor &&
                            actualStyle == drawing.lineStyle &&
                            actualWidth == MathMax(1, drawing.lineWidth) &&
                            propertyError == 0);
      if(!styleVerified)
        {
         ObjectDelete(chartID, objectName);
         Print("[EA|FULL|CHANNEL] ERROR managed channel style verification failed | id=",
               drawing.drawingId, " | color=", (int)actualColor,
               " | style=", (int)actualStyle, " | width=", actualWidth,
               " | expected=", (int)drawing.objectColor, "/",
               (int)drawing.lineStyle, "/", MathMax(1, drawing.lineWidth),
               " | err=", propertyError);
         return false;
        }
     }
   return true;
  }

void DeleteOpportunityDrawingObjects(long chartID)
  {
   DeleteOpportunityGeometryPreviewObjects(chartID);
   string prefix = OpportunityDrawingObjectPrefix();
   int total = ObjectsTotal(chartID, -1, -1);
   int deleted = 0;
   int failed = 0;
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, prefix) != 0) continue;
      ResetLastError();
      if(ObjectDelete(chartID, objectName)) deleted++;
      else
        {
         failed++;
         Print("[EA|FULL|DRAWING] ERROR managed object delete failed | name=",
               objectName, " | err=", GetLastError());
        }
     }
   if(GV_DEBUG_FULL && (deleted > 0 || failed > 0))
      Print("[EA|FULL|DRAWING] INFO managed cleanup | deleted=", deleted,
            " | failed=", failed);
  }

int DrawOpportunityDrawings(long chartID)
  {
   DeleteOpportunityDrawingObjects(chartID);
   if(!opportunityChartViewVisible)
     {
      ChartRedraw(chartID);
      return 0;
     }
   int drawn = 0;
   for(int i = 0; i < ArraySize(opportunityDrawings); i++)
      if(CreateOpportunityDrawing(chartID, opportunityDrawings[i])) drawn++;
   int previewDrawn = DrawOpportunityGeometryPreview(chartID);
   ChartRedraw(chartID);
   Print("[EA|FULL|DRAWING] INFO redraw result | case=", OpportunityCaseId(),
         " | requested=", ArraySize(opportunityDrawings),
         " | drawn=", drawn,
         " | failed=", ArraySize(opportunityDrawings) - drawn,
         " | geometry_preview_lines=", previewDrawn);
   return drawn;
  }

void DeleteOpportunityRegionLabelPair(long chartID, string regionId)
  {
   string prefix = OpportunityRegionObjectPrefix() + regionId;
   string names[2];
   names[0] = prefix + "_BOX";
   names[1] = prefix + "_TEXT";
   for(int i = 0; i < 2; i++)
     {
      if(ObjectFind(chartID, names[i]) < 0) continue;
      ResetLastError();
      if(!ObjectDelete(chartID, names[i]))
         Print("[EA|FULL|REGION] ERROR label delete failed | name=", names[i],
               " | err=", GetLastError());
     }
  }

void DeleteOpportunityRegionObjects(long chartID)
  {
   string prefix = OpportunityRegionObjectPrefix();
   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string objectName = ObjectName(chartID, i, -1, -1);
      if(StringFind(objectName, prefix) != 0) continue;
      ResetLastError();
      if(!ObjectDelete(chartID, objectName))
         Print("[EA|FULL|REGION] ERROR object delete failed | name=", objectName,
               " | err=", GetLastError());
     }
  }

bool CreateOpportunityRegionLabel(long chartID, int regionIndex)
  {
   if(regionIndex < 0 || regionIndex >= ArraySize(opportunityRegions)) return false;

   OpportunityRegionState region = opportunityRegions[regionIndex];
   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0);
   if(chartWidth < 200 || chartHeight < 180) return false;

   double priceMin = ChartGetDouble(chartID, CHART_PRICE_MIN, 0);
   double priceMax = ChartGetDouble(chartID, CHART_PRICE_MAX, 0);
   double referencePrice = (priceMin + priceMax) / 2.0;
   int desiredWidth = (regionIndex == 1) ? 80 : 128;
   int startX = 0;
   int startY = 0;
   int endX = 0;
   int endY = 0;
   bool startOK = ChartTimePriceToXY(chartID, 0, region.startTime,
                                     referencePrice, startX, startY);
   bool endOK = ChartTimePriceToXY(chartID, 0, region.endTime,
                                   referencePrice, endX, endY);
   if(!startOK || !endOK)
     {
      DeleteOpportunityRegionLabelPair(chartID, region.regionId);
      return false;
     }

   int regionLeft = (startX < endX ? startX : endX);
   int regionRight = (startX > endX ? startX : endX);
   if(regionRight < 0 || regionLeft >= chartWidth)
     {
      DeleteOpportunityRegionLabelPair(chartID, region.regionId);
      return false;
     }

   int centerX = (startX + endX) / 2;
   if(centerX < 0 || centerX >= chartWidth)
     {
      DeleteOpportunityRegionLabelPair(chartID, region.regionId);
      return false;
     }

   int availableWidth = MathAbs(endX - startX) - 12;
   if(availableWidth < 72)
     {
      DeleteOpportunityRegionLabelPair(chartID, region.regionId);
      return false;
     }
   int boxWidth = desiredWidth;
   if(boxWidth > availableWidth) boxWidth = availableWidth;

   int boxLeft = centerX - boxWidth / 2;
   if(boxLeft < 4) boxLeft = 4;
   if(boxLeft + boxWidth > chartWidth - 4) boxLeft = chartWidth - boxWidth - 4;
   int labelCenterX = boxLeft + boxWidth / 2;
   int boxTop = chartHeight - OPPORTUNITY_REGION_LABEL_BOTTOM_GAP_PX -
                OPPORTUNITY_REGION_LABEL_HEIGHT_PX;
   int labelCenterY = boxTop + OPPORTUNITY_REGION_LABEL_HEIGHT_PX / 2;
   color background = (color)ChartGetInteger(chartID, CHART_COLOR_BACKGROUND, 0);
   color labelColor = InpStructureCircleColor;

   string objectPrefix = OpportunityRegionObjectPrefix() + region.regionId;
   string boxName = objectPrefix + "_BOX";
   string textName = objectPrefix + "_TEXT";
   ResetLastError();
   if(ObjectFind(chartID, boxName) < 0 &&
      !ObjectCreate(chartID, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
     {
      Print("[EA|FULL|REGION] ERROR box create failed | region=", region.regionId,
            " | err=", GetLastError());
      return false;
     }
   ObjectSetInteger(chartID, boxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, boxName, OBJPROP_XDISTANCE, boxLeft);
   ObjectSetInteger(chartID, boxName, OBJPROP_YDISTANCE, boxTop);
   ObjectSetInteger(chartID, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(chartID, boxName, OBJPROP_YSIZE, OPPORTUNITY_REGION_LABEL_HEIGHT_PX);
   ObjectSetInteger(chartID, boxName, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(chartID, boxName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(chartID, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chartID, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(chartID, boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chartID, boxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartID, boxName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, boxName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chartID, boxName, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, boxName, OBJPROP_ZORDER, 900);
   ObjectSetString(chartID, boxName, OBJPROP_TOOLTIP,
                   region.displayName + " | " +
                   TimeToString(region.startTime, TIME_DATE|TIME_MINUTES) + " - " +
                   TimeToString(region.endTime, TIME_DATE|TIME_MINUTES));

   ResetLastError();
   if(ObjectFind(chartID, textName) < 0 &&
      !ObjectCreate(chartID, textName, OBJ_LABEL, 0, 0, 0))
     {
      Print("[EA|FULL|REGION] ERROR text create failed | region=", region.regionId,
            " | err=", GetLastError());
      return false;
     }
   ObjectSetInteger(chartID, textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(chartID, textName, OBJPROP_XDISTANCE, labelCenterX);
   ObjectSetInteger(chartID, textName, OBJPROP_YDISTANCE, labelCenterY);
   ObjectSetString(chartID, textName, OBJPROP_TEXT, region.displayName);
   ObjectSetString(chartID, textName, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetInteger(chartID, textName, OBJPROP_FONTSIZE,
                    OPPORTUNITY_REGION_LABEL_FONT_SIZE);
   ObjectSetInteger(chartID, textName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(chartID, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartID, textName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, textName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chartID, textName, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, textName, OBJPROP_ZORDER, 901);
   ObjectSetString(chartID, textName, OBJPROP_TOOLTIP,
                   region.role + " | " + OpportunityCaseId());
   return true;
  }

bool CreateOpportunityCaseChartLabel(long chartID)
  {
   if(ArraySize(opportunityRegions) != OPPORTUNITY_REGION_COUNT)
     {
      DeleteOpportunityRegionLabelPair(chartID, "TYPE");
      return false;
     }

   datetime caseStartTime = opportunityRegions[0].startTime;
   datetime caseEndTime = opportunityRegions[OPPORTUNITY_REGION_COUNT - 1].endTime;
   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0);
   if(chartWidth < 240 || chartHeight < 220 ||
      caseStartTime <= 0 || caseEndTime <= caseStartTime)
     {
      DeleteOpportunityRegionLabelPair(chartID, "TYPE");
      return false;
     }

   double priceMin = ChartGetDouble(chartID, CHART_PRICE_MIN, 0);
   double priceMax = ChartGetDouble(chartID, CHART_PRICE_MAX, 0);
   double referencePrice = (priceMin + priceMax) / 2.0;
   int startX = 0;
   int startY = 0;
   int endX = 0;
   int endY = 0;
   bool startOK = ChartTimePriceToXY(chartID, 0, caseStartTime,
                                     referencePrice, startX, startY);
   bool endOK = ChartTimePriceToXY(chartID, 0, caseEndTime,
                                   referencePrice, endX, endY);
   if(!startOK || !endOK)
     {
      DeleteOpportunityRegionLabelPair(chartID, "TYPE");
      return false;
     }

   int caseLeft = (startX < endX ? startX : endX);
   int caseRight = (startX > endX ? startX : endX);
   if(caseRight < 0 || caseLeft >= chartWidth)
     {
      DeleteOpportunityRegionLabelPair(chartID, "TYPE");
      return false;
     }

   bool supported = IsOpportunityTypeSupported(OpportunityCaseType());
   string displayName = supported ? OpportunityCaseTypeDisplayName(OpportunityCaseType()) : "未选择";
   string displayCaseId = OpportunityCaseDisplayId();
   string labelText = displayCaseId + " | " + displayName;
   if(opportunityActiveStandardity == "NON_STANDARD")
      labelText = labelText + " | 非标准";
   else if(opportunityActiveStandardity == "UNREVIEWED")
      labelText = labelText + " | 标准性未确认";
   if(opportunityCaseTypeDirty || opportunityStandardityDirty)
      labelText = labelText + " | 待保存";

   ENUM_ANCHOR_POINT labelAnchor = ANCHOR_RIGHT_LOWER;
   int labelX = startX - OPPORTUNITY_CASE_TEXT_START_GAP_PX;
   if(labelX < 120)
     {
      labelAnchor = ANCHOR_LEFT_LOWER;
      labelX = 8;
     }
   if(labelX > chartWidth - 8) labelX = chartWidth - 8;
   int labelY = chartHeight - OPPORTUNITY_CASE_TEXT_BOTTOM_PX;

   string objectPrefix = OpportunityRegionObjectPrefix() + "TYPE";
   string boxName = objectPrefix + "_BOX";
   string textName = objectPrefix + "_TEXT";
   ObjectDelete(chartID, boxName);

   ResetLastError();
   if(ObjectFind(chartID, textName) < 0 &&
      !ObjectCreate(chartID, textName, OBJ_LABEL, 0, 0, 0))
     {
      Print("[EA|FULL|TYPE] ERROR chart label text create failed | err=", GetLastError());
      return false;
     }
   ObjectSetInteger(chartID, textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartID, textName, OBJPROP_ANCHOR, labelAnchor);
   ObjectSetInteger(chartID, textName, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(chartID, textName, OBJPROP_YDISTANCE, labelY);
   ObjectSetString(chartID, textName, OBJPROP_TEXT, labelText);
   ObjectSetString(chartID, textName, OBJPROP_FONT, "Microsoft YaHei UI Bold");
   ObjectSetInteger(chartID, textName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(chartID, textName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(chartID, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartID, textName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartID, textName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chartID, textName, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, textName, OBJPROP_ZORDER, 906);
   ObjectSetString(chartID, textName, OBJPROP_TOOLTIP,
                   "archive_id=" + OpportunityCaseId() + " | display_id=" + displayCaseId + " | " +
                   (opportunityCaseTypeDirty ? "类型待保存" : "已归档类型") +
                   " | 标准性=" +
                   OpportunityStandardityDisplayName(opportunityActiveStandardity) +
                   (opportunityStandardityDirty ? "待保存" : ""));
   return true;
  }

void RefreshOpportunityRegionLabels(long chartID)
  {
   if(!opportunityChartViewVisible)
     {
      DeleteOpportunityRegionObjects(chartID);
      return;
     }
   if(ArraySize(opportunityRegions) != OPPORTUNITY_REGION_COUNT)
     {
      DeleteOpportunityRegionObjects(chartID);
      return;
     }

   for(int i = 0; i < ArraySize(opportunityRegions); i++)
      CreateOpportunityRegionLabel(chartID, i);
   CreateOpportunityCaseChartLabel(chartID);
   ChartRedraw(chartID);
  }

int DrawOpportunityRegionLabels(long chartID)
  {
   RefreshOpportunityRegionLabels(chartID);
   int drawn = 0;
   for(int i = 0; i < ArraySize(opportunityRegions); i++)
     {
      string boxName = OpportunityRegionObjectPrefix() +
                       opportunityRegions[i].regionId + "_BOX";
      string textName = OpportunityRegionObjectPrefix() +
                        opportunityRegions[i].regionId + "_TEXT";
      if(ObjectFind(chartID, boxName) >= 0 && ObjectFind(chartID, textName) >= 0)
         drawn++;
     }
   string typeTextName = OpportunityRegionObjectPrefix() + "TYPE_TEXT";
   bool caseLabelDrawn = (ObjectFind(chartID, typeTextName) >= 0);
   Print("[EA|FULL|REGION] INFO label result | case=", OpportunityCaseId(),
         " | requested=", ArraySize(opportunityRegions),
         " | drawn=", drawn,
          " | hidden=", ArraySize(opportunityRegions) - drawn,
          " | case_label=", (int)caseLabelDrawn,
          " | display_id=", OpportunityCaseDisplayId(),
          " | archive_id=", OpportunityCaseId(),
         " | type=", OpportunityCaseType(),
         " | type_dirty=", (int)opportunityCaseTypeDirty,
         " | standardity=", opportunityActiveStandardity,
         " | standardity_dirty=", (int)opportunityStandardityDirty);
   return drawn;
  }

void CopyOpportunityDrawingStates(OpportunityDrawingState &source[],
                                  OpportunityDrawingState &target[])
  {
   int count = ArraySize(source);
   ArrayResize(target, count);
   for(int i = 0; i < count; i++) target[i] = source[i];
  }

void CopyOpportunityRegionStates(OpportunityRegionState &source[],
                                 OpportunityRegionState &target[])
  {
   int count = ArraySize(source);
   ArrayResize(target, count);
   for(int i = 0; i < count; i++) target[i] = source[i];
  }

void CopyOpportunityChannelBoundaryStates(OpportunityChannelBoundaryState &source[],
                                          OpportunityChannelBoundaryState &target[])
  {
   int count = ArraySize(source);
   ArrayResize(target, count);
   for(int i = 0; i < count; i++) target[i] = source[i];
  }

bool PrepareOpportunityArchiveBackup(string archivePath,
                                     string backupPath,
                                     bool &archiveExisted)
  {
   archiveExisted = FileIsExist(archivePath, 0);
   if(FileIsExist(backupPath, 0))
     {
      ResetLastError();
      if(!FileDelete(backupPath, 0))
        {
         Print("[EA|FULL|DRAWING] ERROR stale transaction backup delete failed | path=",
               backupPath, " | err=", GetLastError());
         return false;
        }
     }

   if(!archiveExisted) return true;

   ResetLastError();
   if(!FileCopy(archivePath, 0, backupPath, FILE_REWRITE))
     {
      Print("[EA|FULL|DRAWING] ERROR transaction backup failed | archive=", archivePath,
            " | backup=", backupPath, " | err=", GetLastError());
      return false;
     }
   return true;
  }

bool RestoreOpportunityArchiveBackup(string archivePath,
                                     string backupPath,
                                     bool archiveExisted)
  {
   if(archiveExisted)
     {
      if(!FileIsExist(backupPath, 0))
        {
         Print("[EA|FULL|DRAWING] ERROR transaction rollback backup missing | archive=",
               archivePath, " | backup=", backupPath);
         return false;
        }

      ResetLastError();
      if(!FileCopy(backupPath, 0, archivePath, FILE_REWRITE))
        {
         Print("[EA|FULL|DRAWING] ERROR transaction rollback copy failed | archive=",
               archivePath, " | backup=", backupPath, " | err=", GetLastError());
         return false;
        }
      return true;
     }

   if(!FileIsExist(archivePath, 0)) return true;
   ResetLastError();
   if(!FileDelete(archivePath, 0))
     {
      Print("[EA|FULL|DRAWING] ERROR transaction rollback delete failed | archive=",
            archivePath, " | err=", GetLastError());
      return false;
     }
   return true;
  }

void CleanupOpportunityArchiveBackup(string backupPath)
  {
   if(!FileIsExist(backupPath, 0)) return;
   ResetLastError();
   if(!FileDelete(backupPath, 0))
      Print("[EA|FULL|DRAWING] WARN transaction backup cleanup failed | path=",
            backupPath, " | err=", GetLastError());
  }

bool ValidateOpportunityArchiveCaseType(string archivePath,
                                        string archiveName,
                                        string expectedType,
                                        int expectedRows)
  {
   ResetLastError();
   int handle = FileOpen(archivePath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|TYPE] ERROR archive type validation open failed | archive=",
            archiveName, " | path=", archivePath, " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int rows = 0;
   int invalid = 0;
   int mismatches = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0 || StringFind(line, "case_id,") == 0) continue;
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 2)
        {
         invalid++;
         continue;
        }
      rows++;
      if(fields[1] != expectedType) mismatches++;
     }
   FileClose(handle);
   bool valid = (rows == expectedRows && invalid == 0 && mismatches == 0);
   Print("[EA|FULL|TYPE] ", valid ? "INFO" : "ERROR",
         " archive type validation | archive=", archiveName,
         " | case=", OpportunityCaseId(),
         " | expected_type=", expectedType,
         " | rows=", rows, "/", expectedRows,
         " | mismatches=", mismatches,
         " | invalid=", invalid,
         " | verified=", (int)valid);
   return valid;
  }

bool ValidateOpportunityCaseTypeArchives(string expectedType,
                                         int expectedCases,
                                         int expectedAnchors,
                                         int expectedKeyBars,
                                         int expectedDrawings,
                                         int expectedRegions)
  {
   if(!IsOpportunityTypeSupported(expectedType))
     {
      Print("[EA|FULL|TYPE] ERROR unsupported expected type | type=", expectedType,
            " | case=", OpportunityCaseId());
      return false;
     }
   bool casesOK = ValidateOpportunityArchiveCaseType(InpOpportunityCasesCsvPath,
                                                      "CASES", expectedType, expectedCases);
   bool anchorsOK = ValidateOpportunityArchiveCaseType(InpOpportunityAnchorsCsvPath,
                                                        "ANCHORS", expectedType, expectedAnchors);
   bool keyBarsOK = ValidateOpportunityArchiveCaseType(InpOpportunityKeyBarsCsvPath,
                                                        "KEY_BARS", expectedType, expectedKeyBars);
   bool drawingsOK = ValidateOpportunityArchiveCaseType(InpOpportunityDrawingsCsvPath,
                                                         "DRAWINGS", expectedType, expectedDrawings);
   bool regionsOK = ValidateOpportunityArchiveCaseType(InpOpportunityRegionsCsvPath,
                                                        "REGIONS", expectedType, expectedRegions);
   bool verified = (casesOK && anchorsOK && keyBarsOK && drawingsOK && regionsOK);
   Print("[EA|FULL|TYPE] INFO five-archive type result | case=", OpportunityCaseId(),
         " | expected=", expectedType,
         " | verified=", (int)verified);
   return verified;
  }

bool ValidateOpportunityCaseStandardityArchive(string expectedStandardity)
  {
   if(expectedStandardity != "STANDARD" && expectedStandardity != "NON_STANDARD")
     {
      Print("[EA|FULL|STANDARDITY] ERROR unsupported expected standardity | case=",
            OpportunityCaseId(), " | expected=", expectedStandardity, " | err=0");
      return false;
     }

   ResetLastError();
   int handle = FileOpen(InpOpportunityCasesCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|STANDARDITY] ERROR archive validation open failed | case=",
            OpportunityCaseId(), " | path=", InpOpportunityCasesCsvPath,
            " | err=", GetLastError());
      return false;
     }

   ushort separator = StringGetCharacter(",", 0);
   int rows = 0;
   int invalid = 0;
   int mismatches = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0 || StringFind(line, "case_id,") == 0) continue;
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 27)
        {
         invalid++;
         continue;
        }
      rows++;
      if(fields[25] != expectedStandardity || StringToInteger(fields[26]) != 1)
         mismatches++;
     }
   FileClose(handle);
   bool valid = (rows == 1 && invalid == 0 && mismatches == 0);
   Print("[EA|FULL|STANDARDITY] ", valid ? "INFO" : "ERROR",
         " archive validation | case=", OpportunityCaseId(),
         " | expected=", expectedStandardity,
         " | rows=", rows, "/1 | mismatches=", mismatches,
         " | invalid=", invalid, " | confirmed=1 | verified=", (int)valid,
         " | err=0");
   return valid;
  }

bool RollbackOpportunityStructureSave(long chartID,
                                       string reason,
                                       bool caseArchiveTouched,
                                       bool typeArchivesTouched,
                                      string caseBackupPath,
                                      bool caseArchiveExisted,
                                      string anchorBackupPath,
                                      bool anchorArchiveExisted,
                                      string keyBarBackupPath,
                                      bool keyBarArchiveExisted,
                                      string drawingBackupPath,
                                      bool drawingArchiveExisted,
                                       string regionBackupPath,
                                       bool regionArchiveExisted,
                                       string semanticBackupPath,
                                       bool semanticArchiveExisted,
                                       string channelBoundaryBackupPath,
                                       bool channelBoundaryArchiveExisted,
                                       OpportunityDrawingState &previousDrawings[],
                                       OpportunityRegionState &previousRegions[],
                                       OpportunityChannelBoundaryState &previousChannelBoundaries[])
  {
   bool casesRestored = !caseArchiveTouched ||
                        RestoreOpportunityArchiveBackup(InpOpportunityCasesCsvPath,
                                                        caseBackupPath,
                                                        caseArchiveExisted);
   bool anchorsRestored = !typeArchivesTouched ||
                          RestoreOpportunityArchiveBackup(InpOpportunityAnchorsCsvPath,
                                                          anchorBackupPath,
                                                          anchorArchiveExisted);
   bool keyBarsRestored = !typeArchivesTouched ||
                          RestoreOpportunityArchiveBackup(InpOpportunityKeyBarsCsvPath,
                                                          keyBarBackupPath,
                                                          keyBarArchiveExisted);
   bool drawingsRestored = RestoreOpportunityArchiveBackup(InpOpportunityDrawingsCsvPath,
                                                            drawingBackupPath,
                                                            drawingArchiveExisted);
   bool regionsRestored = RestoreOpportunityArchiveBackup(InpOpportunityRegionsCsvPath,
                                                            regionBackupPath,
                                                            regionArchiveExisted);
   bool semanticsRestored = RestoreOpportunityArchiveBackup(InpOpportunityDrawingSemanticsCsvPath,
                                                             semanticBackupPath,
                                                             semanticArchiveExisted);
   bool channelBoundariesRestored = RestoreOpportunityArchiveBackup(
                                      InpOpportunityChannelBoundariesCsvPath,
                                      channelBoundaryBackupPath,
                                      channelBoundaryArchiveExisted);
   CopyOpportunityDrawingStates(previousDrawings, opportunityDrawings);
   CopyOpportunityRegionStates(previousRegions, opportunityRegions);
   CopyOpportunityChannelBoundaryStates(previousChannelBoundaries,
                                        opportunityChannelBoundaries);
   bool channelBoundariesReloaded = false;
   if(channelBoundariesRestored)
      channelBoundariesReloaded = LoadOpportunityChannelBoundaries(chartID);
   bool semanticsReloaded = false;
   if(semanticsRestored)
      semanticsReloaded = LoadOpportunityDrawingSemantics(chartID, true);
   int drawingsRedrawn = DrawOpportunityDrawings(chartID);
   int regionLabelsRedrawn = DrawOpportunityRegionLabels(chartID);

   if(caseArchiveTouched && casesRestored) CleanupOpportunityArchiveBackup(caseBackupPath);
   if(typeArchivesTouched && anchorsRestored) CleanupOpportunityArchiveBackup(anchorBackupPath);
   if(typeArchivesTouched && keyBarsRestored) CleanupOpportunityArchiveBackup(keyBarBackupPath);
   if(drawingsRestored) CleanupOpportunityArchiveBackup(drawingBackupPath);
   if(regionsRestored) CleanupOpportunityArchiveBackup(regionBackupPath);
   if(semanticsRestored) CleanupOpportunityArchiveBackup(semanticBackupPath);
   if(channelBoundariesRestored)
      CleanupOpportunityArchiveBackup(channelBoundaryBackupPath);

   Print("[EA|FULL|DRAWING] INFO structure save rollback result | case=", OpportunityCaseId(),
         " | reason=", reason,
         " | case_archive_touched=", (int)caseArchiveTouched,
         " | type_archives_touched=", (int)typeArchivesTouched,
         " | cases_restored=", (int)casesRestored,
         " | anchors_restored=", (int)anchorsRestored,
         " | key_bars_restored=", (int)keyBarsRestored,
         " | drawings_restored=", (int)drawingsRestored,
          " | regions_restored=", (int)regionsRestored,
          " | semantics_restored=", (int)semanticsRestored,
          " | channel_boundaries_restored=", (int)channelBoundariesRestored,
          " | channel_boundaries_reloaded=", (int)channelBoundariesReloaded,
          " | channel_boundary_rows=", ArraySize(opportunityChannelBoundaries),
          " | semantics_reloaded=", (int)semanticsReloaded,
          " | semantic_rows=", ArraySize(opportunityDrawingSemantics),
         " | drawings_redrawn=", drawingsRedrawn,
          " | region_labels_redrawn=", regionLabelsRedrawn,
          " | backup_retained=", (int)(!casesRestored || !anchorsRestored ||
                                         !keyBarsRestored || !drawingsRestored ||
                                         !regionsRestored || !semanticsRestored ||
                                         !channelBoundariesRestored));
   return (casesRestored && anchorsRestored && keyBarsRestored &&
            drawingsRestored && regionsRestored && semanticsRestored &&
            channelBoundariesRestored);
  }

bool SaveOpportunityStructureDrawings(long chartID, string &resultText)
  {
   resultText = "保存失败 | 未知错误";
   if(!IsOpportunityTypeSupported(OpportunityCaseType()))
     {
      resultText = "保存失败 | 请选择机会类型";
      Print("[EA|FULL|TYPE] WARN structure save rejected; opportunity type missing | case=",
            OpportunityCaseId(), " | type=", OpportunityCaseType());
      return false;
     }

   if(!IsOpportunityStandarditySupported(opportunityActiveStandardity))
     {
      resultText = "保存失败 | 标准性状态无效";
      Print("[EA|FULL|STANDARDITY] ERROR structure save rejected; invalid state | case=",
            OpportunityCaseId(), " | standardity=", opportunityActiveStandardity,
            " | err=0");
      return false;
     }
   string standardityToCommit =
      (opportunityActiveStandardity == "NON_STANDARD") ?
      "NON_STANDARD" : "STANDARD";

   int currentAnchorCount = ArraySize(opportunityStructures) +
                            CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1);
   int currentKeyBarCount = opportunityKeyBar.active ? 1 : 0;
   string preflightType = (opportunityCaseTypeDirty &&
                           StringLen(opportunityArchivedCaseType) > 0) ?
                          opportunityArchivedCaseType : OpportunityCaseType();
   bool preflightTypeOK = ValidateOpportunityCaseTypeArchives(preflightType,
                                                               1,
                                                               currentAnchorCount,
                                                               currentKeyBarCount,
                                                               ArraySize(opportunityDrawings),
                                                               ArraySize(opportunityRegions));
   if(!preflightTypeOK)
     {
      resultText = "保存失败 | 五档案类型不一致";
      Print("[EA|FULL|TYPE] ERROR structure save rejected; preflight type mismatch | case=",
            OpportunityCaseId(), " | selected=", OpportunityCaseType(),
            " | archived=", opportunityArchivedCaseType,
            " | dirty=", (int)opportunityCaseTypeDirty);
      return false;
     }

   OpportunityDrawingState captured[];
   int candidateCount = 0;
   int unsupportedCount = 0;
   int total = ObjectsTotal(chartID, -1, -1);
   string managedPrefix = OpportunityDrawingObjectPrefix();

   Print("[EA|FULL|DRAWING] INFO structure save started | case=", OpportunityCaseId(),
         " | chart=", chartID, " | objects_total=", total,
         " | standardity_selected=", opportunityActiveStandardity,
         " | standardity_commit=", standardityToCommit,
         " | standardity_dirty=", (int)opportunityStandardityDirty);
    for(int i = 0; i < total; i++)
      {
       string objectName = ObjectName(chartID, i, -1, -1);
       if(StringFind(objectName, OPPORTUNITY_GEOMETRY_OBJECT_PREFIX) == 0) continue;
       if(StringLen(objectName) == 0 || IsOpportunityDrawingInternalObject(objectName)) continue;

      ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
      int anchorCount = OpportunityDrawingAnchorCount(objectType);
      if(anchorCount <= 0)
        {
         // Screen-space controls and labels are not chart drawings and are intentionally ignored.
         if(objectType != OBJ_LABEL && objectType != OBJ_BUTTON &&
            objectType != OBJ_BITMAP && objectType != OBJ_BITMAP_LABEL &&
            objectType != OBJ_EDIT && objectType != OBJ_RECTANGLE_LABEL &&
            objectType != OBJ_CHART)
           {
            unsupportedCount++;
            Print("[EA|FULL|DRAWING] ERROR unsupported manual object | name=", objectName,
                  " | type=", (int)objectType);
           }
         continue;
        }

      int captureIndex = ArraySize(captured);
      ArrayResize(captured, captureIndex + 1);
      string drawingId = ResolveOpportunityCapturedDrawingId(chartID,
                                                              objectName,
                                                              managedPrefix,
                                                              captured);
      if(StringLen(drawingId) == 0)
        {
         ArrayResize(captured, captureIndex);
         unsupportedCount++;
         Print("[EA|FULL|DRAWING] ERROR drawing id unavailable | name=", objectName,
               " | err=0");
         continue;
        }
      if(!CaptureOpportunityDrawing(chartID, objectName, drawingId, captured[captureIndex]))
        {
         ArrayResize(captured, captureIndex);
         unsupportedCount++;
         Print("[EA|FULL|DRAWING] ERROR object capture failed | name=", objectName,
               " | type=", (int)objectType, " | err=", GetLastError());
         continue;
        }
      candidateCount++;
      double colorHue = 0.0;
      double colorSaturation = 0.0;
      double colorValue = 0.0;
      OpportunityColorToHsv(captured[captureIndex].objectColor,
                            colorHue, colorSaturation, colorValue);
      Print("[EA|FULL|DRAWING] INFO object captured | id=", drawingId,
             " | source=", objectName,
             " | type=", (int)objectType,
             " | color=", (int)captured[captureIndex].objectColor,
             " | hsv=", DoubleToString(colorHue, 1), "/",
             DoubleToString(colorSaturation, 3), "/", DoubleToString(colorValue, 3),
             " | semantic_role=", captured[captureIndex].semanticRole,
             " | anchor_roles=", captured[captureIndex].anchor1Role, "/",
             captured[captureIndex].anchor2Role,
             " | anchors=", anchorCount,
             " | subwindow=", captured[captureIndex].subwindow);
      }

   FinalizeOpportunityDrawingSemantics(captured);
   int preReleaseSegments = 0;
   int structureLines = 0;
   int linkedStructureAnchors = 0;
   int unclassifiedTrendLines = 0;
   for(int i = 0; i < ArraySize(captured); i++)
     {
      if(captured[i].semanticRole == "PRE_ACCUMULATION_RELEASE_PATH")
         preReleaseSegments++;
      else if(captured[i].semanticRole == "STRUCTURE_LINE")
        {
         structureLines++;
         if(StringLen(captured[i].anchor1Role) > 0) linkedStructureAnchors++;
         if(StringLen(captured[i].anchor2Role) > 0) linkedStructureAnchors++;
        }
      else if(captured[i].objectType == OBJ_TREND)
        {
         unclassifiedTrendLines++;
         double unclassifiedHue = 0.0;
         double unclassifiedSaturation = 0.0;
         double unclassifiedValue = 0.0;
         OpportunityColorToHsv(captured[i].objectColor,
                               unclassifiedHue, unclassifiedSaturation, unclassifiedValue);
         Print("[EA|FULL|DRAWING] WARN trend line color outside semantic families | id=",
               captured[i].drawingId,
               " | color=", (int)captured[i].objectColor,
               " | hsv=", DoubleToString(unclassifiedHue, 1), "/",
               DoubleToString(unclassifiedSaturation, 3), "/",
               DoubleToString(unclassifiedValue, 3),
               " | semantic_role=UNCLASSIFIED");
        }
      if(StringLen(captured[i].semanticRole) > 0)
         Print("[EA|FULL|DRAWING] INFO line semantic | id=", captured[i].drawingId,
               " | role=", captured[i].semanticRole,
               " | path_id=", captured[i].pathId,
               " | segment_order=", captured[i].segmentOrder,
               " | anchor_roles=", captured[i].anchor1Role, "/", captured[i].anchor2Role,
               " | source=", captured[i].semanticSource,
               " | confirmed=", (int)captured[i].semanticConfirmed);
     }
   Print("[EA|FULL|DRAWING] INFO semantic summary | case=", OpportunityCaseId(),
         " | pre_release_segments=", preReleaseSegments,
         " | structure_lines=", structureLines,
         " | linked_structure_anchors=", linkedStructureAnchors, "/", structureLines * 2,
         " | unclassified_trend_lines=", unclassifiedTrendLines,
         " | convention=hsv_color_family");

   if(unsupportedCount > 0)
     {
       resultText = StringFormat("保存失败 | 不支持对象 %d", unsupportedCount);
       Print("[EA|FULL|DRAWING] ERROR structure save aborted; unsupported objects remain | candidates=",
             candidateCount, " | unsupported=", unsupportedCount);
       return false;
      }
   if(candidateCount <= 0)
     {
      resultText = "保存失败 | 未找到绘图";
      Print("[EA|FULL|DRAWING] WARN structure save ignored; no chart drawings found | case=",
            OpportunityCaseId());
      return false;
     }

   OpportunityRegionState capturedRegions[];
   bool regionsDerived = BuildOpportunityRegionsFromDrawings(chartID, captured, capturedRegions);
   if(!regionsDerived || ArraySize(capturedRegions) != OPPORTUNITY_REGION_COUNT)
     {
      resultText = "保存失败 | 需要4条区间线";
      Print("[EA|FULL|DRAWING] WARN structure save rejected; archive unchanged | case=",
            OpportunityCaseId(), " | candidates=", candidateCount,
            " | regions=", ArraySize(capturedRegions),
            " | expected_regions=", OPPORTUNITY_REGION_COUNT);
      return false;
     }
   OpportunityChannelBoundaryState preflightChannelBoundaries[];
   bool channelBoundariesDerived = BuildOpportunityChannelBoundaries(
                                      chartID, captured, capturedRegions, true,
                                      preflightChannelBoundaries);
   if(!channelBoundariesDerived)
     {
      resultText = "保存失败 | 无法生成通道边界";
      Print("[EA|FULL|CHANNEL] ERROR structure save rejected; boundary derivation failed | case=",
            OpportunityCaseId(), " | drawings=", candidateCount,
            " | archive_touched=0");
      return false;
     }
   for(int i = 0; i < ArraySize(captured); i++)
      if(captured[i].objectType == OBJ_CHANNEL)
        {
         captured[i].objectColor = clrRed;
         captured[i].lineStyle = STYLE_SOLID;
         captured[i].lineWidth = OPPORTUNITY_STRUCTURE_LINE_WIDTH;
        }
   OpportunityDrawingSemanticState preflightSemantics[];
   bool semanticsDerived = BuildOpportunityDrawingSemantics(chartID, captured,
                                                             capturedRegions,
                                                             preflightChannelBoundaries,
                                                             preflightSemantics);
   if(!semanticsDerived)
     {
      resultText = "保存失败 | 无法生成线段语义";
      Print("[EA|FULL|SEMANTIC] ERROR structure save rejected; no derived semantics | case=",
            OpportunityCaseId(), " | drawings=", candidateCount,
            " | archive_touched=0");
      return false;
     }
   bool preflightFingerprintLinksValid = ValidateOpportunityChannelFingerprintLinks(
                                            captured, preflightSemantics,
                                            preflightChannelBoundaries,
                                            "save_preflight");
   if(!preflightFingerprintLinksValid)
     {
      resultText = "保存失败 | 通道指纹不一致";
      Print("[EA|FULL|CHANNEL] ERROR structure save rejected; fingerprint links invalid | case=",
            OpportunityCaseId(), " | drawings=", candidateCount,
            " | archive_touched=0");
      return false;
     }
   LogOpportunityGeometrySemanticAdvice(chartID, captured, capturedRegions,
                                         "save_preflight");

   OpportunityDrawingState previousDrawings[];
   OpportunityRegionState previousRegions[];
   OpportunityChannelBoundaryState previousChannelBoundaries[];
   CopyOpportunityDrawingStates(opportunityDrawings, previousDrawings);
   CopyOpportunityRegionStates(opportunityRegions, previousRegions);
   CopyOpportunityChannelBoundaryStates(opportunityChannelBoundaries,
                                        previousChannelBoundaries);

   string transactionId = IntegerToString((int)GetTickCount());
   bool caseArchiveTouched = true;
   bool typeArchivesTouched = opportunityCaseTypeDirty;
   string caseBackupPath = InpOpportunityCasesCsvPath + ".save_structure_" + transactionId + ".bak";
   string anchorBackupPath = InpOpportunityAnchorsCsvPath + ".save_structure_" + transactionId + ".bak";
   string keyBarBackupPath = InpOpportunityKeyBarsCsvPath + ".save_structure_" + transactionId + ".bak";
   string drawingBackupPath = InpOpportunityDrawingsCsvPath + ".save_structure_" + transactionId + ".bak";
   string regionBackupPath = InpOpportunityRegionsCsvPath + ".save_structure_" + transactionId + ".bak";
   string semanticBackupPath = InpOpportunityDrawingSemanticsCsvPath + ".save_structure_" + transactionId + ".bak";
   string channelBoundaryBackupPath = InpOpportunityChannelBoundariesCsvPath +
                                      ".save_structure_" + transactionId + ".bak";
   bool caseArchiveExisted = false;
   bool anchorArchiveExisted = false;
   bool keyBarArchiveExisted = false;
   bool drawingArchiveExisted = false;
   bool regionArchiveExisted = false;
   bool semanticArchiveExisted = false;
   bool channelBoundaryArchiveExisted = false;

   bool caseBackupReady = PrepareOpportunityArchiveBackup(InpOpportunityCasesCsvPath,
                                                           caseBackupPath,
                                                           caseArchiveExisted);
   bool anchorBackupReady = caseBackupReady && (!typeArchivesTouched ||
      PrepareOpportunityArchiveBackup(InpOpportunityAnchorsCsvPath,
                                      anchorBackupPath, anchorArchiveExisted));
   bool keyBarBackupReady = anchorBackupReady && (!typeArchivesTouched ||
      PrepareOpportunityArchiveBackup(InpOpportunityKeyBarsCsvPath,
                                      keyBarBackupPath, keyBarArchiveExisted));
   if(!caseBackupReady || !anchorBackupReady || !keyBarBackupReady)
     {
      resultText = "保存失败 | 无法创建案例备份";
      CleanupOpportunityArchiveBackup(caseBackupPath);
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
      Print("[EA|FULL|CASE] ERROR structure save metadata backup failed; archive unchanged | case=",
            OpportunityCaseId(),
            " | cases=", (int)caseBackupReady,
            " | anchors=", (int)anchorBackupReady,
            " | key_bars=", (int)keyBarBackupReady);
      return false;
     }

   bool drawingBackupReady = PrepareOpportunityArchiveBackup(InpOpportunityDrawingsCsvPath,
                                                              drawingBackupPath,
                                                              drawingArchiveExisted);
   if(!drawingBackupReady)
     {
      resultText = "保存失败 | 无法创建备份";
      CleanupOpportunityArchiveBackup(caseBackupPath);
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
      Print("[EA|FULL|DRAWING] ERROR structure save backup failed; archive unchanged | case=",
            OpportunityCaseId(), " | archive=drawings");
      return false;
     }

   bool regionBackupReady = PrepareOpportunityArchiveBackup(InpOpportunityRegionsCsvPath,
                                                             regionBackupPath,
                                                             regionArchiveExisted);
   if(!regionBackupReady)
     {
      resultText = "保存失败 | 无法创建备份";
      CleanupOpportunityArchiveBackup(caseBackupPath);
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
      CleanupOpportunityArchiveBackup(drawingBackupPath);
      Print("[EA|FULL|DRAWING] ERROR structure save backup failed; archive unchanged | case=",
            OpportunityCaseId(), " | archive=regions");
      return false;
     }

   bool semanticBackupReady = PrepareOpportunityArchiveBackup(InpOpportunityDrawingSemanticsCsvPath,
                                                               semanticBackupPath,
                                                               semanticArchiveExisted);
   if(!semanticBackupReady)
     {
      resultText = "保存失败 | 无法创建语义备份";
      CleanupOpportunityArchiveBackup(caseBackupPath);
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
      CleanupOpportunityArchiveBackup(drawingBackupPath);
      CleanupOpportunityArchiveBackup(regionBackupPath);
      Print("[EA|FULL|SEMANTIC] ERROR structure save backup failed; archive unchanged | case=",
            OpportunityCaseId(), " | archive=semantics");
      return false;
     }

   bool channelBoundaryBackupReady = PrepareOpportunityArchiveBackup(
                                        InpOpportunityChannelBoundariesCsvPath,
                                        channelBoundaryBackupPath,
                                        channelBoundaryArchiveExisted);
   if(!channelBoundaryBackupReady)
     {
      resultText = "保存失败 | 无法创建通道边界备份";
      CleanupOpportunityArchiveBackup(caseBackupPath);
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
      CleanupOpportunityArchiveBackup(drawingBackupPath);
      CleanupOpportunityArchiveBackup(regionBackupPath);
      CleanupOpportunityArchiveBackup(semanticBackupPath);
      Print("[EA|FULL|CHANNEL] ERROR structure save backup failed; archive unchanged | case=",
            OpportunityCaseId(), " | archive=channel_boundaries");
      return false;
     }

   opportunityCaseTypeCommitInProgress = typeArchivesTouched;
   bool annotationSaved = !typeArchivesTouched || SaveOpportunityAnnotation(chartID);
   opportunityCaseTypeCommitInProgress = false;
   if(!annotationSaved)
     {
      Print("[EA|FULL|TYPE] ERROR type archive write failed; rolling back | case=",
            OpportunityCaseId(), " | selected=", OpportunityCaseType());
      bool restored = RollbackOpportunityStructureSave(chartID, "type_archive_write_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool saved = SaveOpportunityDrawingSnapshot(chartID, captured);
   if(!saved)
     {
      Print("[EA|FULL|DRAWING] ERROR structure save archive failed; rolling back | case=",
            OpportunityCaseId(), " | candidates=", candidateCount);
       bool restored = RollbackOpportunityStructureSave(chartID, "drawing_archive_write_failed",
                                                         caseArchiveTouched,
                                                         typeArchivesTouched,
                                                         caseBackupPath, caseArchiveExisted,
                                                         anchorBackupPath, anchorArchiveExisted,
                                                         keyBarBackupPath, keyBarArchiveExisted,
                                                         drawingBackupPath, drawingArchiveExisted,
                                                         regionBackupPath, regionArchiveExisted,
                                                         semanticBackupPath, semanticArchiveExisted,
                                                         channelBoundaryBackupPath,
                                                         channelBoundaryArchiveExisted,
                                                         previousDrawings, previousRegions,
                                                         previousChannelBoundaries);
       resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
       return false;
     }

   bool regionsSaved = SaveOpportunityRegionSnapshot(chartID, capturedRegions);
   if(!regionsSaved)
     {
      Print("[EA|FULL|REGION] ERROR structure save region archive failed; rolling back | case=",
            OpportunityCaseId(), " | regions=", ArraySize(capturedRegions));
       bool restored = RollbackOpportunityStructureSave(chartID, "region_archive_write_failed",
                                                         caseArchiveTouched,
                                                         typeArchivesTouched,
                                                         caseBackupPath, caseArchiveExisted,
                                                         anchorBackupPath, anchorArchiveExisted,
                                                         keyBarBackupPath, keyBarArchiveExisted,
                                                         drawingBackupPath, drawingArchiveExisted,
                                                         regionBackupPath, regionArchiveExisted,
                                                         semanticBackupPath, semanticArchiveExisted,
                                                         channelBoundaryBackupPath,
                                                         channelBoundaryArchiveExisted,
                                                         previousDrawings, previousRegions,
                                                         previousChannelBoundaries);
       resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool loaded = LoadOpportunityDrawings(chartID);
   int verified = ArraySize(opportunityDrawings);
   bool drawingFingerprintsMatch = loaded && verified == candidateCount &&
      ValidateOpportunityDrawingFingerprintReload(captured, opportunityDrawings,
                                                   "save_raw_reload");
   if(!loaded || verified != candidateCount || !drawingFingerprintsMatch)
     {
      Print("[EA|FULL|DRAWING] ERROR structure save verification failed; rolling back | case=",
            OpportunityCaseId(), " | expected=", candidateCount,
            " | verified=", verified,
            " | fingerprints_match=", (int)drawingFingerprintsMatch);
       bool restored = RollbackOpportunityStructureSave(chartID, "drawing_archive_verification_failed",
                                                         caseArchiveTouched,
                                                         typeArchivesTouched,
                                                         caseBackupPath, caseArchiveExisted,
                                                         anchorBackupPath, anchorArchiveExisted,
                                                         keyBarBackupPath, keyBarArchiveExisted,
                                                         drawingBackupPath, drawingArchiveExisted,
                                                         regionBackupPath, regionArchiveExisted,
                                                         semanticBackupPath, semanticArchiveExisted,
                                                         channelBoundaryBackupPath,
                                                         channelBoundaryArchiveExisted,
                                                         previousDrawings, previousRegions,
                                                         previousChannelBoundaries);
       resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
       return false;
     }

   bool regionsLoaded = LoadOpportunityRegions(chartID);
   int regionsVerified = ArraySize(opportunityRegions);
   if(!regionsLoaded || regionsVerified != OPPORTUNITY_REGION_COUNT)
     {
      Print("[EA|FULL|REGION] ERROR structure save region verification failed; rolling back | case=",
            OpportunityCaseId(), " | expected=", OPPORTUNITY_REGION_COUNT,
            " | verified=", regionsVerified);
       bool restored = RollbackOpportunityStructureSave(chartID, "region_archive_verification_failed",
                                                         caseArchiveTouched,
                                                         typeArchivesTouched,
                                                         caseBackupPath, caseArchiveExisted,
                                                         anchorBackupPath, anchorArchiveExisted,
                                                         keyBarBackupPath, keyBarArchiveExisted,
                                                         drawingBackupPath, drawingArchiveExisted,
                                                         regionBackupPath, regionArchiveExisted,
                                                         semanticBackupPath, semanticArchiveExisted,
                                                         channelBoundaryBackupPath,
                                                         channelBoundaryArchiveExisted,
                                                         previousDrawings, previousRegions,
                                                         previousChannelBoundaries);
       resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
       return false;
     }

   OpportunityChannelBoundaryState capturedChannelBoundaries[];
   bool canonicalChannelBoundariesDerived = BuildOpportunityChannelBoundaries(
                                               chartID, opportunityDrawings,
                                               opportunityRegions, false,
                                               capturedChannelBoundaries);
   if(!canonicalChannelBoundariesDerived)
     {
      Print("[EA|FULL|CHANNEL] ERROR canonical boundary derivation failed; rolling back | case=",
            OpportunityCaseId(), " | drawings=", ArraySize(opportunityDrawings),
            " | archive_touched=1");
      bool restored = RollbackOpportunityStructureSave(
                         chartID, "canonical_channel_boundary_derivation_failed",
                         caseArchiveTouched, typeArchivesTouched,
                         caseBackupPath, caseArchiveExisted,
                         anchorBackupPath, anchorArchiveExisted,
                         keyBarBackupPath, keyBarArchiveExisted,
                         drawingBackupPath, drawingArchiveExisted,
                         regionBackupPath, regionArchiveExisted,
                         semanticBackupPath, semanticArchiveExisted,
                         channelBoundaryBackupPath,
                         channelBoundaryArchiveExisted,
                         previousDrawings, previousRegions,
                         previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   OpportunityDrawingSemanticState capturedSemantics[];
   bool canonicalSemanticsDerived = BuildOpportunityDrawingSemantics(
                                       chartID, opportunityDrawings,
                                       opportunityRegions,
                                       capturedChannelBoundaries,
                                       capturedSemantics);
   bool canonicalFingerprintLinksValid = canonicalSemanticsDerived &&
      ValidateOpportunityChannelFingerprintLinks(opportunityDrawings,
                                                 capturedSemantics,
                                                 capturedChannelBoundaries,
                                                 "save_canonical_prewrite");
   if(!canonicalSemanticsDerived || !canonicalFingerprintLinksValid)
     {
      Print("[EA|FULL|SEMANTIC] ERROR canonical semantic or fingerprint derivation failed; rolling back | case=",
            OpportunityCaseId(), " | drawings=", ArraySize(opportunityDrawings),
            " | semantics_derived=", (int)canonicalSemanticsDerived,
            " | fingerprint_links=", (int)canonicalFingerprintLinksValid,
            " | archive_touched=1");
      bool restored = RollbackOpportunityStructureSave(
                         chartID, canonicalSemanticsDerived ?
                                  "canonical_fingerprint_link_verification_failed" :
                                  "canonical_semantic_derivation_failed",
                         caseArchiveTouched, typeArchivesTouched,
                         caseBackupPath, caseArchiveExisted,
                         anchorBackupPath, anchorArchiveExisted,
                         keyBarBackupPath, keyBarArchiveExisted,
                         drawingBackupPath, drawingArchiveExisted,
                         regionBackupPath, regionArchiveExisted,
                         semanticBackupPath, semanticArchiveExisted,
                         channelBoundaryBackupPath,
                         channelBoundaryArchiveExisted,
                         previousDrawings, previousRegions,
                         previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool channelBoundariesSaved = SaveOpportunityChannelBoundarySnapshot(
                                    capturedChannelBoundaries);
   if(!channelBoundariesSaved)
     {
      Print("[EA|FULL|CHANNEL] ERROR structure save boundary archive failed; rolling back | case=",
            OpportunityCaseId(), " | boundaries=",
            ArraySize(capturedChannelBoundaries));
      bool restored = RollbackOpportunityStructureSave(
                         chartID, "channel_boundary_archive_write_failed",
                         caseArchiveTouched, typeArchivesTouched,
                         caseBackupPath, caseArchiveExisted,
                         anchorBackupPath, anchorArchiveExisted,
                         keyBarBackupPath, keyBarArchiveExisted,
                         drawingBackupPath, drawingArchiveExisted,
                         regionBackupPath, regionArchiveExisted,
                         semanticBackupPath, semanticArchiveExisted,
                         channelBoundaryBackupPath,
                         channelBoundaryArchiveExisted,
                         previousDrawings, previousRegions,
                         previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool semanticsSaved = SaveOpportunityDrawingSemanticSnapshot(capturedSemantics);
   if(!semanticsSaved)
     {
      Print("[EA|FULL|SEMANTIC] ERROR structure save semantic archive failed; rolling back | case=",
            OpportunityCaseId(), " | semantics=", ArraySize(capturedSemantics));
      bool restored = RollbackOpportunityStructureSave(chartID, "semantic_archive_write_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool channelBoundariesLoaded = LoadOpportunityChannelBoundaries(chartID);
   int channelBoundariesVerified = ArraySize(opportunityChannelBoundaries);
   bool channelBoundaryRowsMatch = channelBoundariesLoaded &&
      ValidateOpportunityChannelBoundaryReload(capturedChannelBoundaries);
   if(!channelBoundaryRowsMatch)
     {
      Print("[EA|FULL|CHANNEL] ERROR structure save boundary verification failed; rolling back | case=",
            OpportunityCaseId(), " | expected=",
            ArraySize(capturedChannelBoundaries),
            " | verified=", channelBoundariesVerified,
            " | rows_match=", (int)channelBoundaryRowsMatch);
      bool restored = RollbackOpportunityStructureSave(
                         chartID, "channel_boundary_archive_verification_failed",
                         caseArchiveTouched, typeArchivesTouched,
                         caseBackupPath, caseArchiveExisted,
                         anchorBackupPath, anchorArchiveExisted,
                         keyBarBackupPath, keyBarArchiveExisted,
                         drawingBackupPath, drawingArchiveExisted,
                         regionBackupPath, regionArchiveExisted,
                         semanticBackupPath, semanticArchiveExisted,
                         channelBoundaryBackupPath,
                         channelBoundaryArchiveExisted,
                         previousDrawings, previousRegions,
                         previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool semanticsLoaded = LoadOpportunityDrawingSemantics(chartID, false);
   int semanticsVerified = ArraySize(opportunityDrawingSemantics);
   bool semanticRowsMatch = semanticsLoaded &&
                            ValidateOpportunityDrawingSemanticReload(capturedSemantics);
   bool fingerprintLinksMatch = semanticRowsMatch &&
      ValidateOpportunityChannelFingerprintLinks(opportunityDrawings,
                                                 opportunityDrawingSemantics,
                                                 opportunityChannelBoundaries,
                                                 "save_postwrite_reload");
   if(!semanticRowsMatch || !fingerprintLinksMatch)
     {
      Print("[EA|FULL|SEMANTIC] ERROR structure save semantic verification failed; rolling back | case=",
            OpportunityCaseId(), " | expected=", ArraySize(capturedSemantics),
            " | verified=", semanticsVerified,
            " | rows_match=", (int)semanticRowsMatch,
            " | fingerprint_links=", (int)fingerprintLinksMatch);
      bool restored = RollbackOpportunityStructureSave(chartID,
                                                        semanticRowsMatch ?
                                                        "channel_fingerprint_link_verification_failed" :
                                                        "semantic_archive_verification_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   opportunityCaseTypeCommitInProgress = typeArchivesTouched;
   opportunityStandardityCommitInProgress = true;
   bool caseMetadataSaved = SaveOpportunityCaseSnapshot(chartID);
   opportunityCaseTypeCommitInProgress = false;
   opportunityStandardityCommitInProgress = false;
   if(!caseMetadataSaved)
     {
      Print("[EA|FULL|CASE] ERROR opportunity level metadata write failed; rolling back | case=",
            OpportunityCaseId(), " | display_id=", OpportunityCaseDisplayId());
      bool restored = RollbackOpportunityStructureSave(chartID, "case_metadata_write_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool typesVerified = ValidateOpportunityCaseTypeArchives(OpportunityCaseType(),
                                                             1,
                                                             currentAnchorCount,
                                                             currentKeyBarCount,
                                                             candidateCount,
                                                             regionsVerified);
   if(!typesVerified)
     {
      Print("[EA|FULL|TYPE] ERROR post-save type verification failed; rolling back | case=",
            OpportunityCaseId(), " | selected=", OpportunityCaseType());
      bool restored = RollbackOpportunityStructureSave(chartID, "type_archive_verification_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   bool standardityVerified =
      ValidateOpportunityCaseStandardityArchive(standardityToCommit);
   if(!standardityVerified)
     {
      Print("[EA|FULL|STANDARDITY] ERROR post-save verification failed; rolling back | case=",
            OpportunityCaseId(), " | expected=", standardityToCommit, " | err=0");
      bool restored = RollbackOpportunityStructureSave(chartID,
                                                        "standardity_archive_verification_failed",
                                                        caseArchiveTouched,
                                                        typeArchivesTouched,
                                                        caseBackupPath, caseArchiveExisted,
                                                        anchorBackupPath, anchorArchiveExisted,
                                                        keyBarBackupPath, keyBarArchiveExisted,
                                                        drawingBackupPath, drawingArchiveExisted,
                                                        regionBackupPath, regionArchiveExisted,
                                                        semanticBackupPath, semanticArchiveExisted,
                                                        channelBoundaryBackupPath,
                                                        channelBoundaryArchiveExisted,
                                                        previousDrawings, previousRegions,
                                                        previousChannelBoundaries);
      resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
      return false;
     }

   int drawn = DrawOpportunityDrawings(chartID);
   if(drawn != candidateCount)
     {
      Print("[EA|FULL|DRAWING] ERROR structure save redraw incomplete; rolling back | case=",
            OpportunityCaseId(), " | expected=", candidateCount,
            " | drawn=", drawn);
       bool restored = RollbackOpportunityStructureSave(chartID, "managed_redraw_failed",
                                                         caseArchiveTouched,
                                                         typeArchivesTouched,
                                                         caseBackupPath, caseArchiveExisted,
                                                         anchorBackupPath, anchorArchiveExisted,
                                                         keyBarBackupPath, keyBarArchiveExisted,
                                                         drawingBackupPath, drawingArchiveExisted,
                                                         regionBackupPath, regionArchiveExisted,
                                                         semanticBackupPath, semanticArchiveExisted,
                                                         channelBoundaryBackupPath,
                                                         channelBoundaryArchiveExisted,
                                                         previousDrawings, previousRegions,
                                                         previousChannelBoundaries);
       resultText = restored ? "保存失败 | 已恢复旧档案" : "保存失败 | 备份已保留";
       return false;
     }
    if(typeArchivesTouched)
      {
       opportunityArchivedCaseType = OpportunityCaseType();
       opportunityCaseTypeDirty = false;
      }
   opportunityActiveStandardity = standardityToCommit;
   opportunityArchivedStandardity = standardityToCommit;
   opportunityStandardityDirty = false;
   int regionLabelsDrawn = DrawOpportunityRegionLabels(chartID);

   CleanupOpportunityArchiveBackup(caseBackupPath);
   if(typeArchivesTouched)
     {
      CleanupOpportunityArchiveBackup(anchorBackupPath);
      CleanupOpportunityArchiveBackup(keyBarBackupPath);
     }
   CleanupOpportunityArchiveBackup(drawingBackupPath);
   CleanupOpportunityArchiveBackup(regionBackupPath);
   CleanupOpportunityArchiveBackup(semanticBackupPath);
   CleanupOpportunityArchiveBackup(channelBoundaryBackupPath);

    bool catalogReloaded = LoadOpportunityCaseCatalog(chartID);
    if(!catalogReloaded)
       Print("[EA|FULL|CASE] WARN catalog reload failed after structure save | case=",
             OpportunityCaseId());
    SaveOpportunitySessionState(chartID, "structure_saved");

   int removed = 0;
   int deleteFailed = 0;
   for(int i = 0; i < ArraySize(captured); i++)
     {
      string sourceName = captured[i].sourceName;
      if(StringFind(sourceName, managedPrefix) == 0) continue;
      if(ObjectFind(chartID, sourceName) < 0) continue;
      ResetLastError();
      if(ObjectDelete(chartID, sourceName)) removed++;
      else
        {
         deleteFailed++;
         Print("[EA|FULL|DRAWING] ERROR source object delete failed | name=", sourceName,
               " | err=", GetLastError());
        }
     }
   ChartRedraw(chartID);

   Print("[EA|FULL|DRAWING] INFO structure save result | case=", OpportunityCaseId(),
         " | saved=", (int)saved,
         " | verified=", verified,
         " | drawn=", drawn,
         " | regions=", regionsVerified,
         " | channel_boundaries=", channelBoundariesVerified,
         " | semantics=", semanticsVerified,
         " | region_labels=", regionLabelsDrawn,
         " | type=", OpportunityCaseType(),
         " | type_changed=", (int)typeArchivesTouched,
         " | type_verified=", (int)typesVerified,
         " | standardity=", opportunityActiveStandardity,
         " | standardity_verified=", (int)standardityVerified,
         " | case_metadata_saved=", (int)caseMetadataSaved,
         " | display_id=", OpportunityCaseDisplayId(),
         " | catalog_reloaded=", (int)catalogReloaded,
         " | archive_replaced=1",
         " | originals_removed=", removed,
         " | delete_failed=", deleteFailed);
   if(deleteFailed > 0)
      resultText = StringFormat("已保存 | %s/%s | 绘图 %d | 区间 %d | 清理失败 %d",
                                OpportunityCaseTypeDisplayName(OpportunityCaseType()),
                                OpportunityStandardityDisplayName(opportunityActiveStandardity),
                                verified, regionsVerified, deleteFailed);
   else
      resultText = StringFormat("已保存 | %s/%s | 绘图 %d | 区间 %d",
                                OpportunityCaseTypeDisplayName(OpportunityCaseType()),
                                OpportunityStandardityDisplayName(opportunityActiveStandardity),
                                verified, regionsVerified);
   return true;
  }

void DrawOpportunityTrendLine(long chartID, int firstIndex, int secondIndex, string lineRole, color lineColor)
  {
   if(!opportunityLineAnchors[firstIndex].active || !opportunityLineAnchors[secondIndex].active) return;
   string objectName = OpportunityObjectPrefix() + lineRole + "_LINE";
   if(!CreateOpportunityObject(chartID, objectName, OBJ_TREND,
                               opportunityLineAnchors[firstIndex].barTime, opportunityLineAnchors[firstIndex].price,
                               opportunityLineAnchors[secondIndex].barTime, opportunityLineAnchors[secondIndex].price)) return;
   ConfigureOpportunityObject(chartID, objectName, lineColor, STYLE_SOLID, 2);
   ObjectSetInteger(chartID, objectName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(chartID, objectName, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP, lineRole + " | " + OpportunityCaseId());
  }

bool ResolveOpportunityStructureMarkerGeometry(long chartID,
                                                int structureIndex,
                                                int &markerLeft,
                                                int &markerTop,
                                                int &markerDiameter)
  {
   if(structureIndex < 0 || structureIndex >= ArraySize(opportunityStructures)) return false;

   int centerX = 0;
   int centerY = 0;
   if(!ChartTimePriceToXY(chartID, 0,
                          opportunityStructures[structureIndex].centerTime,
                          opportunityStructures[structureIndex].centerPrice,
                          centerX, centerY))
      return false;

   int startX = 0;
   int startY = 0;
   int endX = 0;
   int endY = 0;
   int pixelRadius = 0;
   bool startOK = ChartTimePriceToXY(chartID, 0,
                                     opportunityStructures[structureIndex].rangeStartTime,
                                     opportunityStructures[structureIndex].centerPrice,
                                     startX, startY);
   bool endOK = ChartTimePriceToXY(chartID, 0,
                                   opportunityStructures[structureIndex].rangeEndTime,
                                   opportunityStructures[structureIndex].centerPrice,
                                   endX, endY);
   if(startOK && endOK)
      pixelRadius = (int)MathMax(MathAbs(centerX - startX), MathAbs(endX - centerX));

   if(pixelRadius <= 0)
     {
      int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
      int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
      if(chartWidth > 0 && visibleBars > 0)
         pixelRadius = (int)MathRound((double)chartWidth *
                                      opportunityStructures[structureIndex].radiusBars /
                                      visibleBars);
     }

   if(pixelRadius < OPPORTUNITY_STRUCTURE_MARKER_MIN_RADIUS_PX)
      pixelRadius = OPPORTUNITY_STRUCTURE_MARKER_MIN_RADIUS_PX;
   if(pixelRadius > OPPORTUNITY_STRUCTURE_MARKER_MAX_RADIUS_PX)
      pixelRadius = OPPORTUNITY_STRUCTURE_MARKER_MAX_RADIUS_PX;

   markerDiameter = pixelRadius * 2 + 5;
   markerLeft = centerX - markerDiameter / 2;
   markerTop = centerY - markerDiameter / 2;
   return true;
  }

bool CreateOpportunityStructureMarker(long chartID, int structureIndex)
  {
   int markerLeft = 0;
   int markerTop = 0;
   int markerDiameter = 0;
   if(!ResolveOpportunityStructureMarkerGeometry(chartID, structureIndex,
                                                 markerLeft, markerTop, markerDiameter))
      return false;

   bool editing = (structureIndex == opportunityEditStructureIndex);
   color markerColor = editing ? clrGold : InpStructureCircleColor;
   string role = opportunityStructures[structureIndex].role;
   string objectName = OpportunityObjectPrefix() + role + "_LABEL";
   CCanvas markerCanvas;
   ResetLastError();
   if(!markerCanvas.CreateBitmapLabel(chartID, 0, objectName,
                                      markerLeft, markerTop,
                                      markerDiameter, markerDiameter,
                                      COLOR_FORMAT_ARGB_NORMALIZE))
     {
      Print("[EA|FULL|ANNOT] ERROR structure marker canvas create failed | role=", role,
            " | size=", markerDiameter, " | err=", GetLastError());
      markerCanvas.Destroy();
      return false;
     }

   int canvasCenter = markerDiameter / 2;
   int pixelRadius = (markerDiameter - 5) / 2;
   uint markerARGB = COLOR2RGB(markerColor);
   markerCanvas.Erase(ARGB(0, 0, 0, 0));
   markerCanvas.CircleAA(canvasCenter, canvasCenter, pixelRadius, markerARGB);

   string displayNumber = IntegerToString(structureIndex + 1);
   int fontSize = (int)MathRound(pixelRadius * 1.15);
   if(fontSize < 9) fontSize = 9;
   bool fontOK = markerCanvas.FontSet("Arial", fontSize, FW_SEMIBOLD);
   int textWidth = fontOK ? markerCanvas.TextWidth(displayNumber) : 0;
   int textHeight = fontOK ? markerCanvas.TextHeight(displayNumber) : 0;
   while(fontOK && fontSize > 7 &&
         (textWidth > (int)MathRound(pixelRadius * 1.45) ||
          textHeight > (int)MathRound(pixelRadius * 1.45)))
     {
      fontSize--;
      fontOK = markerCanvas.FontSet("Arial", fontSize, FW_SEMIBOLD);
      textWidth = fontOK ? markerCanvas.TextWidth(displayNumber) : 0;
      textHeight = fontOK ? markerCanvas.TextHeight(displayNumber) : 0;
     }
   if(!fontOK)
     {
      Print("[EA|FULL|ANNOT] ERROR structure marker font setup failed | role=", role,
            " | size=", fontSize, " | err=", GetLastError());
      markerCanvas.Destroy();
      return false;
     }
   markerCanvas.TextOut(canvasCenter, canvasCenter, displayNumber, markerARGB,
                        TA_CENTER | TA_VCENTER);

   bool propertyOK = true;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_CORNER, CORNER_LEFT_UPPER) && propertyOK;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_BACK, false) && propertyOK;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, editing) && propertyOK;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, editing) && propertyOK;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, false) && propertyOK;
   propertyOK = ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, editing ? 20 : 10) && propertyOK;
   propertyOK = ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP,
                                editing ? role + " | EDIT: drag circled number" :
                                          role + " | double-click number to edit") && propertyOK;
   if(!propertyOK)
     {
      Print("[EA|FULL|ANNOT] ERROR structure marker property setup failed | role=", role,
            " | err=", GetLastError());
      markerCanvas.Destroy();
      return false;
     }

   markerCanvas.Update(false);
   return true;
  }

void RefreshOpportunityStructureMarkers(long chartID)
  {
   if(!opportunityChartViewVisible)
     {
      DeleteOpportunityAnnotationObjects(chartID);
      return;
     }
   bool changed = false;
   string prefix = OpportunityObjectPrefix();
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      string objectName = prefix + opportunityStructures[i].role + "_LABEL";
      int markerLeft = 0;
      int markerTop = 0;
      int markerDiameter = 0;
      bool geometryOK = ResolveOpportunityStructureMarkerGeometry(chartID, i,
                                                                  markerLeft, markerTop,
                                                                  markerDiameter);
      if(!geometryOK)
        {
         if(ObjectFind(chartID, objectName) >= 0)
           {
            DeleteOpportunityObjectWithResource(chartID, objectName);
            changed = true;
           }
         continue;
        }

      bool rebuild = (ObjectFind(chartID, objectName) < 0);
      if(!rebuild)
        {
         ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
         int currentWidth = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XSIZE);
         int currentHeight = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YSIZE);
         rebuild = (objectType != OBJ_BITMAP_LABEL ||
                    currentWidth != markerDiameter || currentHeight != markerDiameter);
        }

      if(rebuild)
        {
         if(ObjectFind(chartID, objectName) >= 0)
            DeleteOpportunityObjectWithResource(chartID, objectName);
         if(CreateOpportunityStructureMarker(chartID, i)) changed = true;
         continue;
        }

      int currentLeft = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XDISTANCE);
      int currentTop = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YDISTANCE);
      if(currentLeft != markerLeft)
        {
         ObjectSetInteger(chartID, objectName, OBJPROP_XDISTANCE, markerLeft);
         changed = true;
        }
      if(currentTop != markerTop)
        {
         ObjectSetInteger(chartID, objectName, OBJPROP_YDISTANCE, markerTop);
         changed = true;
        }
     }
   if(changed) ChartRedraw(chartID);
  }

bool ResolveOpportunityKeyBarMarkerGeometry(long chartID,
                                            int &markerLeft,
                                            int &markerTop,
                                            int &markerWidth,
                                            int &markerHeight)
  {
   if(!opportunityKeyBar.active || opportunityKeyBar.barTime <= 0 ||
      opportunityKeyBar.highPrice < opportunityKeyBar.lowPrice)
      return false;

   int centerX = 0;
   int highY = 0;
   int lowX = 0;
   int lowY = 0;
   if(!ChartTimePriceToXY(chartID, 0, opportunityKeyBar.barTime,
                          opportunityKeyBar.highPrice, centerX, highY) ||
      !ChartTimePriceToXY(chartID, 0, opportunityKeyBar.barTime,
                          opportunityKeyBar.lowPrice, lowX, lowY))
      return false;

   centerX = (centerX + lowX) / 2;
   int barSpacing = 0;
   int currentShift = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                opportunityKeyBar.barTime, true);
   if(currentShift >= 0)
     {
      datetime adjacentTimes[2];
      adjacentTimes[0] = (currentShift > 0) ?
                         iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, currentShift - 1) : 0;
      adjacentTimes[1] = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, currentShift + 1);
      for(int i = 0; i < 2; i++)
        {
         if(adjacentTimes[i] <= 0) continue;
         int adjacentX = 0;
         int adjacentY = 0;
         if(!ChartTimePriceToXY(chartID, 0, adjacentTimes[i],
                                opportunityKeyBar.highPrice, adjacentX, adjacentY))
            continue;
         int candidateSpacing = MathAbs(adjacentX - centerX);
         if(candidateSpacing > 0 &&
            (barSpacing == 0 || candidateSpacing < barSpacing))
            barSpacing = candidateSpacing;
        }
     }

   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0);
   if(barSpacing <= 0)
     {
      int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
      if(chartWidth > 0 && visibleBars > 0)
         barSpacing = (int)MathRound((double)chartWidth / visibleBars);
     }
   if(barSpacing <= 0) return false;

   int halfWidth = (int)MathRound(barSpacing * OPPORTUNITY_KEY_BAR_HALF_WIDTH_RATIO);
   if(halfWidth < OPPORTUNITY_KEY_BAR_MIN_HALF_WIDTH_PX)
      halfWidth = OPPORTUNITY_KEY_BAR_MIN_HALF_WIDTH_PX;

   int topY = (highY < lowY ? highY : lowY) - OPPORTUNITY_KEY_BAR_VERTICAL_PADDING_PX;
   int bottomY = (highY > lowY ? highY : lowY) + OPPORTUNITY_KEY_BAR_VERTICAL_PADDING_PX;
   markerLeft = centerX - halfWidth;
   markerTop = topY;
   markerWidth = halfWidth * 2 - 1;
   markerHeight = bottomY - topY - 1;

   if(markerWidth <= OPPORTUNITY_KEY_BAR_BORDER_WIDTH_PX * 2 ||
      markerHeight <= OPPORTUNITY_KEY_BAR_BORDER_WIDTH_PX * 2)
      return false;
   if(chartWidth > 0 &&
      (markerLeft < 0 || markerLeft + markerWidth > chartWidth))
      return false;
   if(chartHeight > 0 &&
      (markerTop < 0 || markerTop + markerHeight > chartHeight))
      return false;
   return true;
  }

void DrawOpportunityKeyBar(long chartID)
  {
   if(!opportunityKeyBar.active) return;
   if(opportunityKeyBar.barTime <= 0 ||
      opportunityKeyBar.highlightStartTime >= opportunityKeyBar.highlightEndTime ||
      opportunityKeyBar.highPrice < opportunityKeyBar.lowPrice)
     {
      Print("[EA|FULL|ANNOT] ERROR invalid key bar highlight state | time=",
            TimeToString(opportunityKeyBar.barTime, TIME_DATE|TIME_MINUTES),
            " | range=", TimeToString(opportunityKeyBar.highlightStartTime, TIME_DATE|TIME_MINUTES),
            "..", TimeToString(opportunityKeyBar.highlightEndTime, TIME_DATE|TIME_MINUTES),
            " | price=", DoubleToString(opportunityKeyBar.lowPrice, _Digits),
            "..", DoubleToString(opportunityKeyBar.highPrice, _Digits));
      return;
     }

   int markerLeft = 0;
   int markerTop = 0;
   int markerWidth = 0;
   int markerHeight = 0;
   if(!ResolveOpportunityKeyBarMarkerGeometry(chartID, markerLeft, markerTop,
                                              markerWidth, markerHeight))
      return;

   string objectName = OpportunityObjectPrefix() + "KEY_BAR_FRAME";
   CCanvas markerCanvas;
   ResetLastError();
   if(!markerCanvas.CreateBitmapLabel(chartID, 0, objectName,
                                      markerLeft, markerTop,
                                      markerWidth, markerHeight,
                                      COLOR_FORMAT_ARGB_NORMALIZE))
     {
      Print("[EA|FULL|ANNOT] ERROR key bar canvas create failed | time=",
            TimeToString(opportunityKeyBar.barTime, TIME_DATE|TIME_MINUTES),
            " | size=", markerWidth, "x", markerHeight,
            " | err=", GetLastError());
      markerCanvas.Destroy();
      return;
     }

   uint markerARGB = COLOR2RGB(InpKeyBarColor);
   markerCanvas.Erase(ARGB(0, 0, 0, 0));
   for(int inset = 0; inset < OPPORTUNITY_KEY_BAR_BORDER_WIDTH_PX; inset++)
      markerCanvas.Rectangle(inset, inset,
                             markerWidth - 1 - inset,
                             markerHeight - 1 - inset,
                             markerARGB);

   bool configured = true;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_CORNER, CORNER_LEFT_UPPER) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_BACK, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_SELECTED, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, false) && configured;
   configured = ObjectSetInteger(chartID, objectName, OBJPROP_ZORDER, 15) && configured;
   configured = ObjectSetString(chartID, objectName, OBJPROP_TOOLTIP,
                                opportunityKeyBar.role + " | " +
                                TimeToString(opportunityKeyBar.barTime, TIME_DATE|TIME_MINUTES) +
                                " | O=" + DoubleToString(opportunityKeyBar.openPrice, _Digits) +
                                " H=" + DoubleToString(opportunityKeyBar.highPrice, _Digits) +
                                " L=" + DoubleToString(opportunityKeyBar.lowPrice, _Digits) +
                                " C=" + DoubleToString(opportunityKeyBar.closePrice, _Digits)) && configured;
   if(!configured)
     {
      Print("[EA|FULL|ANNOT] ERROR key bar highlight property setup failed | name=",
            objectName, " | err=", GetLastError());
      markerCanvas.Destroy();
      return;
     }

   markerCanvas.Update(false);
  }

void RefreshOpportunityKeyBarMarker(long chartID)
  {
   string objectName = OpportunityObjectPrefix() + "KEY_BAR_FRAME";
   if(!opportunityChartViewVisible)
     {
      if(ObjectFind(chartID, objectName) >= 0)
        {
         DeleteOpportunityObjectWithResource(chartID, objectName);
         ChartRedraw(chartID);
        }
      return;
     }
   if(!opportunityKeyBar.active)
     {
      if(ObjectFind(chartID, objectName) >= 0)
        {
         DeleteOpportunityObjectWithResource(chartID, objectName);
         ChartRedraw(chartID);
        }
      return;
     }

   int markerLeft = 0;
   int markerTop = 0;
   int markerWidth = 0;
   int markerHeight = 0;
   bool geometryOK = ResolveOpportunityKeyBarMarkerGeometry(chartID,
                                                            markerLeft, markerTop,
                                                            markerWidth, markerHeight);
   if(!geometryOK)
     {
      if(ObjectFind(chartID, objectName) >= 0)
        {
         DeleteOpportunityObjectWithResource(chartID, objectName);
         ChartRedraw(chartID);
        }
      return;
     }

   bool rebuild = (ObjectFind(chartID, objectName) < 0);
   if(!rebuild)
     {
      ENUM_OBJECT objectType = (ENUM_OBJECT)ObjectGetInteger(chartID, objectName, OBJPROP_TYPE);
      int currentWidth = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XSIZE);
      int currentHeight = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YSIZE);
      rebuild = (objectType != OBJ_BITMAP_LABEL ||
                 currentWidth != markerWidth || currentHeight != markerHeight);
     }

   if(rebuild)
     {
      if(ObjectFind(chartID, objectName) >= 0)
         DeleteOpportunityObjectWithResource(chartID, objectName);
      DrawOpportunityKeyBar(chartID);
      ChartRedraw(chartID);
      return;
     }

   bool changed = false;
   int currentLeft = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XDISTANCE);
   int currentTop = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YDISTANCE);
   if(currentLeft != markerLeft)
     {
      ObjectSetInteger(chartID, objectName, OBJPROP_XDISTANCE, markerLeft);
      changed = true;
     }
   if(currentTop != markerTop)
     {
      ObjectSetInteger(chartID, objectName, OBJPROP_YDISTANCE, markerTop);
      changed = true;
     }
   if(changed) ChartRedraw(chartID);
  }

void DrawOpportunityAnnotations(long chartID)
  {
   DeleteOpportunityAnnotationObjects(chartID);
   if(!opportunityChartViewVisible)
     {
      ChartRedraw(chartID);
      return;
     }
   string prefix = OpportunityObjectPrefix();
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
      {
      CreateOpportunityStructureMarker(chartID, i);
      }

   for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
     {
      if(!opportunityLineAnchors[i].active) continue;
      string role = opportunityLineAnchors[i].role;
      color anchorColor = (StringFind(role, "UPPER_") == 0) ? clrTomato : clrDeepSkyBlue;
      string pointName = prefix + role + "_POINT";
      if(CreateOpportunityObject(chartID, pointName, OBJ_ARROW,
                                 opportunityLineAnchors[i].barTime, opportunityLineAnchors[i].price))
        {
         ConfigureOpportunityObject(chartID, pointName, anchorColor, STYLE_SOLID, 2);
         ObjectSetInteger(chartID, pointName, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(chartID, pointName, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetString(chartID, pointName, OBJPROP_TOOLTIP,
                         role + " | " + TimeToString(opportunityLineAnchors[i].barTime, TIME_DATE|TIME_MINUTES) +
                         " | " + DoubleToString(opportunityLineAnchors[i].price, _Digits));
        }
     }

   DrawOpportunityTrendLine(chartID, 0, 1, "UPPER", clrTomato);
   DrawOpportunityTrendLine(chartID, 2, 3, "LOWER", clrDeepSkyBlue);
   DrawOpportunityKeyBar(chartID);
   ChartRedraw(chartID);
  }

int FindOpportunityStructureLabelIndex(string objectName)
  {
   string prefix = OpportunityObjectPrefix();
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      if(objectName == prefix + opportunityStructures[i].role + "_LABEL") return i;
     }
   return -1;
  }

void SetOpportunityStructureEdit(long chartID, int structureIndex, string reason)
  {
   int previousIndex = opportunityEditStructureIndex;
   if(structureIndex < 0 || structureIndex >= ArraySize(opportunityStructures))
      opportunityEditStructureIndex = -1;
   else
      opportunityEditStructureIndex = structureIndex;

   opportunityAnnotationMode = "";
   opportunityEditStateTick = GetTickCount();
   opportunityLastStructureLabelClickTick = 0;
   opportunityLastStructureLabelClickName = "";
   DrawOpportunityAnnotations(chartID);
   UpdateOpportunityAnnotationPanel();

   string previousRole = (previousIndex >= 0 && previousIndex < ArraySize(opportunityStructures)) ?
                         opportunityStructures[previousIndex].role : "";
   string activeRole = (opportunityEditStructureIndex >= 0) ?
                       opportunityStructures[opportunityEditStructureIndex].role : "";
   Print("[EA|FULL|ANNOT] INFO structure edit mode | case=", OpportunityCaseId(),
         " | previous=", previousRole, " | active=", activeRole,
         " | reason=", reason);
  }

bool HandleOpportunityStructureLabelClick(long chartID, string objectName)
  {
   int structureIndex = FindOpportunityStructureLabelIndex(objectName);
   if(structureIndex < 0) return false;
   if(opportunityAnnotationReadOnly)
     {
      Print("[EA|FULL|ANNOT] WARN structure edit denied on read-only chart | role=",
            opportunityStructures[structureIndex].role);
      return true;
     }

   uint now = GetTickCount();
   bool doubleClick = (objectName == opportunityLastStructureLabelClickName &&
                       (now - opportunityLastStructureLabelClickTick) <=
                       OPPORTUNITY_STRUCTURE_DOUBLE_CLICK_MS);
   if(!doubleClick)
     {
      opportunityLastStructureLabelClickName = objectName;
      opportunityLastStructureLabelClickTick = now;
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|ANNOT] INFO structure label click armed | role=",
               opportunityStructures[structureIndex].role);
      return true;
     }

   if(opportunityEditStructureIndex == structureIndex)
      SetOpportunityStructureEdit(chartID, -1, "label_double_click_exit");
   else
      SetOpportunityStructureEdit(chartID, structureIndex, "label_double_click_enter");
   return true;
  }

bool HandleOpportunityStructureLabelDrag(long chartID, string objectName)
  {
   int structureIndex = FindOpportunityStructureLabelIndex(objectName);
   if(structureIndex < 0) return false;
   if(structureIndex != opportunityEditStructureIndex)
     {
      Print("[EA|FULL|ANNOT] WARN structure drag ignored outside edit mode | role=",
            opportunityStructures[structureIndex].role);
      DrawOpportunityAnnotations(chartID);
      return true;
     }

   opportunityEditStateTick = GetTickCount();

   ResetLastError();
   int markerLeft = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XDISTANCE);
   int markerTop = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YDISTANCE);
   int markerWidth = (int)ObjectGetInteger(chartID, objectName, OBJPROP_XSIZE);
   int markerHeight = (int)ObjectGetInteger(chartID, objectName, OBJPROP_YSIZE);
   int markerCenterX = markerLeft + markerWidth / 2;
   int markerCenterY = markerTop + markerHeight / 2;
   int subWindow = 0;
   datetime draggedCenterTime = 0;
   double draggedCenterPrice = 0.0;
   bool coordinatesOK = (markerWidth > 0 && markerHeight > 0 &&
                         ChartXYToTimePrice(chartID, markerCenterX, markerCenterY,
                                            subWindow, draggedCenterTime, draggedCenterPrice));
   if(!coordinatesOK || subWindow != 0 ||
      draggedCenterTime <= 0 || draggedCenterPrice <= 0.0)
     {
      Print("[EA|FULL|ANNOT] ERROR dragged marker coordinates unavailable | role=",
            opportunityStructures[structureIndex].role,
            " | left=", markerLeft, " | top=", markerTop,
            " | width=", markerWidth, " | height=", markerHeight,
            " | subwindow=", subWindow, " | err=", GetLastError());
      DrawOpportunityAnnotations(chartID);
      return true;
     }

   OpportunityStructureState previous = opportunityStructures[structureIndex];
   datetime newCenterTime = draggedCenterTime;
   double newCenterPrice = NormalizeDouble(draggedCenterPrice, _Digits);

   bool timeOrderOK = true;
   if(structureIndex > 0 && newCenterTime <= opportunityStructures[structureIndex - 1].centerTime)
      timeOrderOK = false;
   if(structureIndex + 1 < ArraySize(opportunityStructures) &&
      newCenterTime >= opportunityStructures[structureIndex + 1].centerTime)
      timeOrderOK = false;
   if(!timeOrderOK || newCenterPrice <= 0.0)
     {
      Print("[EA|FULL|ANNOT] WARN structure move rejected | role=", previous.role,
            " | requested_time=", TimeToString(newCenterTime, TIME_DATE|TIME_MINUTES),
            " | requested_price=", DoubleToString(newCenterPrice, _Digits),
            " | time_order_ok=", (int)timeOrderOK, " | restored=1");
      DrawOpportunityAnnotations(chartID);
      UpdateOpportunityAnnotationPanel();
      return true;
     }

   opportunityStructures[structureIndex].centerTime = newCenterTime;
   opportunityStructures[structureIndex].centerPrice = newCenterPrice;
   if(!RecalculateOpportunityStructure(chartID, structureIndex, false))
     {
      opportunityStructures[structureIndex] = previous;
      Print("[EA|FULL|ANNOT] ERROR structure move recalculation failed | role=", previous.role,
            " | requested_time=", TimeToString(newCenterTime, TIME_DATE|TIME_MINUTES),
            " | requested_price=", DoubleToString(newCenterPrice, _Digits),
            " | err=", GetLastError(), " | restored=1");
      DrawOpportunityAnnotations(chartID);
      UpdateOpportunityAnnotationPanel();
      return true;
     }

   bool saved = SaveOpportunityAnnotation(chartID);
   if(!saved)
     {
      opportunityStructures[structureIndex] = previous;
      bool restoreSaved = SaveOpportunityAnnotation(chartID);
      Print("[EA|FULL|ANNOT] ERROR structure move save failed | role=", previous.role,
            " | restored=1 | restore_saved=", (int)restoreSaved);
      DrawOpportunityAnnotations(chartID);
      UpdateOpportunityAnnotationPanel();
      return true;
     }

   DrawOpportunityAnnotations(chartID);
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO structure move result | case=", OpportunityCaseId(),
         " | role=", opportunityStructures[structureIndex].role,
         " | old_center=", TimeToString(previous.centerTime, TIME_DATE|TIME_MINUTES),
         "/", DoubleToString(previous.centerPrice, _Digits),
         " | new_center=", TimeToString(opportunityStructures[structureIndex].centerTime, TIME_DATE|TIME_MINUTES),
         "/", DoubleToString(opportunityStructures[structureIndex].centerPrice, _Digits),
         " | radius=", opportunityStructures[structureIndex].radiusBars,
         " | saved=", (int)saved);
   return true;
  }

string OpportunityFirstCsvField(string line)
  {
   int comma = StringFind(line, ",");
   if(comma < 0) return line;
   return StringSubstr(line, 0, comma);
  }

bool RewriteOpportunityCsv(string path, string header, string &newLines[])
  {
   string retainedLines[];
   int retainedCount = 0;
   int readHandle = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(readHandle != INVALID_HANDLE_VALUE)
     {
      while(!FileIsEnding(readHandle))
        {
         string line = FileReadString(readHandle);
         if(StringLen(line) == 0) continue;
         if(StringFind(line, "case_id,") == 0) continue;
         if(OpportunityFirstCsvField(line) == OpportunityCaseId()) continue;
         ArrayResize(retainedLines, retainedCount + 1);
         retainedLines[retainedCount++] = line;
        }
      FileClose(readHandle);
     }

   ResetLastError();
   int writeHandle = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(writeHandle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|ANNOT] ERROR archive open failed | path=", path,
            " | terminal_path=", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", path,
            " | err=", GetLastError());
      return false;
     }

   FileWriteString(writeHandle, header + "\r\n");
   for(int i = 0; i < retainedCount; i++)
      FileWriteString(writeHandle, retainedLines[i] + "\r\n");
   for(int i = 0; i < ArraySize(newLines); i++)
      FileWriteString(writeHandle, newLines[i] + "\r\n");
   FileFlush(writeHandle);
   FileClose(writeHandle);
   return true;
  }

string OpportunityTimeOrEmpty(datetime value)
  {
   if(value <= 0) return "";
   return TimeToString(value, TIME_DATE|TIME_MINUTES);
  }

string OpportunityCaseCsvHeader()
  {
   return "case_id,case_type,symbol,timeframe,status,formation_start,ready_time,pivot_count," +
          "upper_count,lower_count,time_order_ok,alternation_ok,progression_ok,upper_rising_ok," +
          "lower_rising_ok,parallel_ok,rule_status,future_outcome,updated_at,opportunity_level," +
          "accumulation_start,accumulation_end,accumulation_duration_hours,case_code," +
          "accumulation_h1_bars,standardity,standardity_confirmed";
  }

string BuildOpportunityCaseCsvLine(long chartID)
  {
   int timeOrderOK;
   int alternationOK;
   int progressionOK;
   int upperRisingOK;
   int lowerRisingOK;
   int parallelOK;
   string ruleStatus;
   EvaluateOpportunityRules(timeOrderOK, alternationOK, progressionOK,
                            upperRisingOK, lowerRisingOK, parallelOK, ruleStatus);

   int pivotCount = ArraySize(opportunityStructures);
   string status = (pivotCount >= 5) ? "READY_CANDIDATE" : "DRAFT";
   datetime formationStart = (pivotCount > 0) ? opportunityStructures[0].rangeStartTime : 0;
   datetime readyTime = (pivotCount >= 5) ? opportunityStructures[4].rangeEndTime : 0;
   string updatedAt = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   datetime accumulationStart = 0;
   datetime accumulationEnd = 0;
   long accumulationDurationSeconds = 0;
   int accumulationH1Bars = 0;
   GetCurrentOpportunityAccumulationRange(accumulationStart, accumulationEnd);
   string opportunityLevel = OpportunityLevelFromAccumulationRange(ChartSymbol(chartID),
                                                                    accumulationStart,
                                                                    accumulationEnd,
                                                                    accumulationDurationSeconds,
                                                                    accumulationH1Bars);
   double accumulationDurationHours = (double)accumulationDurationSeconds / 3600.0;
   string caseCode = BuildOpportunityCaseCode(OpportunityCaseId(), opportunityLevel);
   string standardity = OpportunityAnnotationWriteStandardity();
   int standardityConfirmed = (standardity == "STANDARD" ||
                               standardity == "NON_STANDARD") ? 1 : 0;
   int upperCount = CountOpportunityLineAnchors(0, 1);
   int lowerCount = CountOpportunityLineAnchors(2, 3);
   int channelUpperIndex = -1;
   int channelLowerIndex = -1;
   if(IsOpportunityGeometryChannelType(OpportunityCaseType()) &&
      ResolvePrimaryOpportunityChannelBoundaryIndexes(channelUpperIndex,
                                                       channelLowerIndex))
     {
      upperCount = opportunityChannelBoundaries[channelUpperIndex].touchCount;
      lowerCount = opportunityChannelBoundaries[channelLowerIndex].touchCount;
     }

   return OpportunityCaseId() + "," + OpportunityAnnotationWriteCaseType() + "," +
          OpportunityCsvSafe(ChartSymbol(chartID)) + "," + TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
          status + "," + OpportunityTimeOrEmpty(formationStart) + "," + OpportunityTimeOrEmpty(readyTime) + "," +
          IntegerToString(pivotCount) + "," + IntegerToString(upperCount) + "," +
          IntegerToString(lowerCount) + "," + OpportunityRuleValue(timeOrderOK) + "," +
           OpportunityRuleValue(alternationOK) + "," + OpportunityRuleValue(progressionOK) + "," +
           OpportunityRuleValue(upperRisingOK) + "," + OpportunityRuleValue(lowerRisingOK) + "," +
           OpportunityRuleValue(parallelOK) + "," + ruleStatus + "," + OpportunityCsvSafe(opportunityFutureOutcome) + "," + updatedAt + "," +
           opportunityLevel + "," + OpportunityTimeOrEmpty(accumulationStart) + "," +
           OpportunityTimeOrEmpty(accumulationEnd) + "," +
           DoubleToString(accumulationDurationHours, 3) + "," + caseCode + "," +
           IntegerToString(accumulationH1Bars) + "," + standardity + "," +
           IntegerToString(standardityConfirmed);
  }

bool SaveOpportunityCaseSnapshot(long chartID)
  {
   if(PR_IsPureReleaseCaseType(OpportunityCaseType()))
     {
      Print("[EA|FULL|PURE_RELEASE] ERROR case archive write blocked",
            " | case=", OpportunityCaseId(),
            " | type=", OpportunityCaseType(),
            " | archive_touched=0");
      return false;
     }
   string caseLines[];
   ArrayResize(caseLines, 1);
   caseLines[0] = BuildOpportunityCaseCsvLine(chartID);
   return RewriteOpportunityCsv(InpOpportunityCasesCsvPath,
                                OpportunityCaseCsvHeader(), caseLines);
  }

string BuildOpportunityStructureCsvLine(long chartID, int structureIndex, string updatedAt)
  {
   return OpportunityCaseId() + "," + OpportunityAnnotationWriteCaseType() + "," +
          "STRUCT," + opportunityStructures[structureIndex].role + "," +
          IntegerToString(opportunityStructures[structureIndex].actionSequence) + "," +
          OpportunityCsvSafe(ChartSymbol(chartID)) + "," + TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
          OpportunityTimeOrEmpty(opportunityStructures[structureIndex].centerTime) + "," +
          DoubleToString(opportunityStructures[structureIndex].centerPrice, _Digits) + "," +
          IntegerToString(opportunityStructures[structureIndex].centerBarShift) + "," +
          IntegerToString(opportunityStructures[structureIndex].radiusBars) + "," +
          OpportunityTimeOrEmpty(opportunityStructures[structureIndex].rangeStartTime) + "," +
          OpportunityTimeOrEmpty(opportunityStructures[structureIndex].rangeEndTime) + "," +
          DoubleToString(opportunityStructures[structureIndex].circleLow, _Digits) + "," +
          DoubleToString(opportunityStructures[structureIndex].circleHigh, _Digits) + "," +
          DoubleToString(opportunityStructures[structureIndex].zoneLow, _Digits) + "," +
          DoubleToString(opportunityStructures[structureIndex].zoneHigh, _Digits) + "," +
          OpportunityTimeOrEmpty(opportunityStructures[structureIndex].representativeTime) + "," +
          DoubleToString(opportunityStructures[structureIndex].representativePrice, _Digits) + "," +
          opportunityStructures[structureIndex].representativeType + "," +
          IntegerToString(opportunityStructures[structureIndex].representativeBarShift) + "," + updatedAt;
  }

string BuildOpportunityLineAnchorCsvLine(long chartID, int anchorIndex, string updatedAt)
  {
   return OpportunityCaseId() + "," + OpportunityAnnotationWriteCaseType() + "," +
          "LINE," + opportunityLineAnchors[anchorIndex].role + "," +
          IntegerToString(opportunityLineAnchors[anchorIndex].actionSequence) + "," +
          OpportunityCsvSafe(ChartSymbol(chartID)) + "," + TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
          OpportunityTimeOrEmpty(opportunityLineAnchors[anchorIndex].barTime) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          IntegerToString(opportunityLineAnchors[anchorIndex].barShift) + ",0," +
          OpportunityTimeOrEmpty(opportunityLineAnchors[anchorIndex].barTime) + "," +
          OpportunityTimeOrEmpty(opportunityLineAnchors[anchorIndex].barTime) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          OpportunityTimeOrEmpty(opportunityLineAnchors[anchorIndex].barTime) + "," +
          DoubleToString(opportunityLineAnchors[anchorIndex].price, _Digits) + "," +
          opportunityLineAnchors[anchorIndex].snapType + "," +
          IntegerToString(opportunityLineAnchors[anchorIndex].barShift) + "," + updatedAt;
  }

string BuildOpportunityKeyBarCsvLine(long chartID, string updatedAt)
  {
   return OpportunityCaseId() + "," + OpportunityAnnotationWriteCaseType() + "," +
          opportunityKeyBar.role + "," + IntegerToString(opportunityKeyBar.actionSequence) + "," +
          OpportunityCsvSafe(ChartSymbol(chartID)) + "," +
          TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)) + "," +
          OpportunityTimeOrEmpty(opportunityKeyBar.barTime) + "," +
          OpportunityTimeOrEmpty(opportunityKeyBar.confirmTime) + "," +
          OpportunityTimeOrEmpty(opportunityKeyBar.highlightStartTime) + "," +
          OpportunityTimeOrEmpty(opportunityKeyBar.highlightEndTime) + "," +
          DoubleToString(opportunityKeyBar.openPrice, _Digits) + "," +
          DoubleToString(opportunityKeyBar.highPrice, _Digits) + "," +
          DoubleToString(opportunityKeyBar.lowPrice, _Digits) + "," +
          DoubleToString(opportunityKeyBar.closePrice, _Digits) + "," +
          IntegerToString(opportunityKeyBar.barShift) + "," +
          opportunityKeyBar.direction + "," + updatedAt;
  }

bool SaveOpportunityKeyBar(long chartID)
  {
   if(PR_IsPureReleaseCaseType(OpportunityCaseType()))
     {
      Print("[EA|FULL|PURE_RELEASE] ERROR key bar archive write blocked",
            " | case=", OpportunityCaseId(),
            " | type=", OpportunityCaseType(),
            " | archive_touched=0");
      return false;
     }
   string keyBarLines[];
   string updatedAt = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   if(opportunityKeyBar.active)
     {
      ArrayResize(keyBarLines, 1);
      keyBarLines[0] = BuildOpportunityKeyBarCsvLine(chartID, updatedAt);
     }
   string keyBarHeader = "case_id,case_type,role,action_sequence,symbol,timeframe,bar_time,confirm_time,highlight_start_time,highlight_end_time,open,high,low,close,bar_shift,direction,updated_at";
   return RewriteOpportunityCsv(InpOpportunityKeyBarsCsvPath, keyBarHeader, keyBarLines);
  }

bool SaveOpportunityAnnotation(long chartID)
  {
   if(PR_IsPureReleaseCaseType(OpportunityCaseType()))
     {
      Print("[EA|FULL|PURE_RELEASE] ERROR annotation archive write blocked",
            " | case=", OpportunityCaseId(),
            " | type=", OpportunityCaseType(),
            " | archive_touched=0");
      return false;
     }
   string anchorLines[];
   int anchorLineCount = 0;
   string updatedAt = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      ArrayResize(anchorLines, anchorLineCount + 1);
      anchorLines[anchorLineCount++] = BuildOpportunityStructureCsvLine(chartID, i, updatedAt);
     }
   for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
     {
      if(!opportunityLineAnchors[i].active) continue;
      ArrayResize(anchorLines, anchorLineCount + 1);
      anchorLines[anchorLineCount++] = BuildOpportunityLineAnchorCsvLine(chartID, i, updatedAt);
     }

   string anchorHeader = "case_id,case_type,anchor_kind,anchor_role,action_sequence,symbol,timeframe,center_time,center_price,center_bar_shift,radius_bars,range_start_time,range_end_time,circle_low,circle_high,zone_low,zone_high,representative_time,representative_price,snap_type,representative_bar_shift,updated_at";
   bool casesSaved = SaveOpportunityCaseSnapshot(chartID);
   bool anchorsSaved = RewriteOpportunityCsv(InpOpportunityAnchorsCsvPath, anchorHeader, anchorLines);
   bool keyBarSaved = SaveOpportunityKeyBar(chartID);
   bool saved = (casesSaved && anchorsSaved && keyBarSaved);
   bool catalogAdded = false;
    if(saved && !opportunityCaseTypeCommitInProgress &&
       FindOpportunityCaseCatalogIndex(OpportunityCaseId()) < 0)
       catalogAdded = LoadOpportunityCaseCatalog(chartID);
    if(saved) SaveOpportunitySessionState(chartID, "annotation_saved");
    Print("[EA|FULL|ANNOT] INFO archive result | case=", OpportunityCaseId(),
         " | cases_saved=", (int)casesSaved, " | anchors_saved=", (int)anchorsSaved,
         " | key_bar_saved=", (int)keyBarSaved,
         " | anchors=", anchorLineCount,
         " | key_bar_active=", (int)opportunityKeyBar.active,
         " | catalog_added=", (int)catalogAdded);
   return saved;
  }

void LoadOpportunityFutureOutcome()
  {
   opportunityFutureOutcome = "";
   int handle = FileOpen(InpOpportunityCasesCsvPath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE) return;

   ushort separator = StringGetCharacter(",", 0);
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;
      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount >= 18) opportunityFutureOutcome = fields[17];
     }
   FileClose(handle);
  }

bool LoadOpportunityKeyBar(long chartID, int &maxSequence)
  {
   ResetLastError();
   int handle = FileOpen(InpOpportunityKeyBarsCsvPath,
                         FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      if(GV_DEBUG_FULL)
         Print("[EA|FULL|ANNOT] INFO key bar archive unavailable; starting empty | path=",
               InpOpportunityKeyBarsCsvPath, " | err=", GetLastError());
      return false;
     }

   string expectedSymbol = ChartSymbol(chartID);
   string expectedTimeframe = TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID));
   ushort separator = StringGetCharacter(",", 0);
   int loadedRows = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount < 17) continue;
      int actionSequence = (int)StringToInteger(fields[3]);
      if(actionSequence <= opportunityKeyBar.actionSequence) continue;

      datetime barTime = StringToTime(fields[6]);
      datetime confirmTime = StringToTime(fields[7]);
      datetime highlightStartTime = StringToTime(fields[8]);
      datetime highlightEndTime = StringToTime(fields[9]);
      double openPrice = StringToDouble(fields[10]);
      double highPrice = StringToDouble(fields[11]);
      double lowPrice = StringToDouble(fields[12]);
      double closePrice = StringToDouble(fields[13]);
      if(actionSequence <= 0 || barTime <= 0 || confirmTime <= barTime ||
         highlightStartTime >= highlightEndTime || openPrice <= 0.0 ||
         highPrice < lowPrice || closePrice <= 0.0)
        {
         Print("[EA|FULL|ANNOT] ERROR invalid key bar archive row | case=", OpportunityCaseId(),
               " | sequence=", actionSequence,
               " | bar_time=", TimeToString(barTime, TIME_DATE|TIME_MINUTES),
               " | confirm_time=", TimeToString(confirmTime, TIME_DATE|TIME_MINUTES),
               " | ohlc=", DoubleToString(openPrice, _Digits), "/",
               DoubleToString(highPrice, _Digits), "/",
               DoubleToString(lowPrice, _Digits), "/",
               DoubleToString(closePrice, _Digits));
         continue;
        }

      opportunityKeyBar.role = fields[2];
      opportunityKeyBar.actionSequence = actionSequence;
      opportunityKeyBar.barTime = barTime;
      opportunityKeyBar.confirmTime = confirmTime;
      opportunityKeyBar.highlightStartTime = highlightStartTime;
      opportunityKeyBar.highlightEndTime = highlightEndTime;
      opportunityKeyBar.openPrice = openPrice;
      opportunityKeyBar.highPrice = highPrice;
      opportunityKeyBar.lowPrice = lowPrice;
      opportunityKeyBar.closePrice = closePrice;
      opportunityKeyBar.barShift = (int)StringToInteger(fields[14]);
      opportunityKeyBar.direction = fields[15];
      opportunityKeyBar.active = true;
      loadedRows++;

      if(StringLen(opportunityAnnotationNativeSymbol) == 0)
        {
         opportunityAnnotationNativeSymbol = fields[4];
         opportunityAnnotationNativeTimeframe = fields[5];
        }
      if(fields[4] != expectedSymbol || fields[5] != expectedTimeframe)
         opportunityAnnotationReadOnly = true;
      if(actionSequence > maxSequence) maxSequence = actionSequence;
     }
   FileClose(handle);

   Print("[EA|FULL|ANNOT] INFO key bar archive loaded | case=", OpportunityCaseId(),
         " | loaded_rows=", loadedRows,
         " | active=", (int)opportunityKeyBar.active,
         " | role=", opportunityKeyBar.role,
         " | time=", OpportunityTimeOrEmpty(opportunityKeyBar.barTime),
         " | sequence=", opportunityKeyBar.actionSequence);
   return opportunityKeyBar.active;
  }

bool LoadOpportunityAnnotation(long chartID)
  {
   LoadOpportunityFutureOutcome();
   ResetLastError();
   int handle = FileOpen(InpOpportunityAnchorsCsvPath, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|ANNOT] WARN anchor archive unavailable; starting empty | path=", InpOpportunityAnchorsCsvPath,
            " | err=", GetLastError());
      int maxSequence = 0;
      bool keyBarLoaded = LoadOpportunityKeyBar(chartID, maxSequence);
      opportunityNextActionSequence = maxSequence + 1;
      return keyBarLoaded;
     }

   string expectedSymbol = ChartSymbol(chartID);
   string expectedTimeframe = TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID));
   ushort separator = StringGetCharacter(",", 0);
   int loadedStructures = 0;
   int loadedLines = 0;
   int legacyStructures = 0;
   int maxSequence = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(OpportunityFirstCsvField(line) != OpportunityCaseId()) continue;

      string fields[];
      int fieldCount = StringSplit(line, separator, fields);
      if(fieldCount >= 22 && (fields[2] == "STRUCT" || fields[2] == "LINE"))
        {
         if(StringLen(opportunityAnnotationNativeSymbol) == 0)
           {
            opportunityAnnotationNativeSymbol = fields[5];
            opportunityAnnotationNativeTimeframe = fields[6];
           }
         if(fields[5] != expectedSymbol || fields[6] != expectedTimeframe)
            opportunityAnnotationReadOnly = true;
         int actionSequence = (int)StringToInteger(fields[4]);
         datetime centerTime = StringToTime(fields[7]);
         double centerPrice = StringToDouble(fields[8]);
         if(actionSequence <= 0 || centerTime <= 0 || centerPrice <= 0.0) continue;

         if(fields[2] == "STRUCT")
           {
            int structureIndex = ArraySize(opportunityStructures);
            ArrayResize(opportunityStructures, structureIndex + 1);
            opportunityStructures[structureIndex].role = fields[3];
            opportunityStructures[structureIndex].actionSequence = actionSequence;
            opportunityStructures[structureIndex].centerTime = centerTime;
            opportunityStructures[structureIndex].centerPrice = centerPrice;
            opportunityStructures[structureIndex].centerBarShift = (int)StringToInteger(fields[9]);
            opportunityStructures[structureIndex].radiusBars = ClampOpportunityStructureRadius((int)StringToInteger(fields[10]));
            opportunityStructures[structureIndex].rangeStartTime = StringToTime(fields[11]);
            opportunityStructures[structureIndex].rangeEndTime = StringToTime(fields[12]);
            opportunityStructures[structureIndex].circleLow = StringToDouble(fields[13]);
            opportunityStructures[structureIndex].circleHigh = StringToDouble(fields[14]);
            opportunityStructures[structureIndex].zoneLow = StringToDouble(fields[15]);
            opportunityStructures[structureIndex].zoneHigh = StringToDouble(fields[16]);
            opportunityStructures[structureIndex].representativeTime = StringToTime(fields[17]);
            opportunityStructures[structureIndex].representativePrice = StringToDouble(fields[18]);
            opportunityStructures[structureIndex].representativeType = fields[19];
            opportunityStructures[structureIndex].representativeBarShift = (int)StringToInteger(fields[20]);
            if(loadedStructures == 0)
               opportunityStructureRadiusBars = opportunityStructures[structureIndex].radiusBars;
            loadedStructures++;
           }
         else
           {
            int anchorIndex = FindOpportunityLineAnchorIndex(fields[3]);
            if(anchorIndex < 0 || actionSequence <= opportunityLineAnchors[anchorIndex].actionSequence) continue;
            opportunityLineAnchors[anchorIndex].barTime = centerTime;
            opportunityLineAnchors[anchorIndex].price = centerPrice;
            opportunityLineAnchors[anchorIndex].barShift = (int)StringToInteger(fields[9]);
            opportunityLineAnchors[anchorIndex].snapType = fields[19];
            opportunityLineAnchors[anchorIndex].actionSequence = actionSequence;
            opportunityLineAnchors[anchorIndex].active = true;
            loadedLines++;
           }
         if(actionSequence > maxSequence) maxSequence = actionSequence;
         continue;
        }

      if(fieldCount < 11) continue;
      if(StringLen(opportunityAnnotationNativeSymbol) == 0)
        {
         opportunityAnnotationNativeSymbol = fields[4];
         opportunityAnnotationNativeTimeframe = fields[5];
        }
      if(fields[4] != expectedSymbol || fields[5] != expectedTimeframe)
         opportunityAnnotationReadOnly = true;
      string legacyRole = fields[2];
      int legacySequence = (int)StringToInteger(fields[3]);
      datetime legacyTime = StringToTime(fields[6]);
      double legacyPrice = StringToDouble(fields[7]);
      if(legacySequence <= 0 || legacyTime <= 0 || legacyPrice <= 0.0) continue;

      if(StringGetCharacter(legacyRole, 0) == 'P')
        {
         int structureIndex = ArraySize(opportunityStructures);
         ArrayResize(opportunityStructures, structureIndex + 1);
         opportunityStructures[structureIndex].role = "S" + IntegerToString(structureIndex + 1);
         opportunityStructures[structureIndex].centerTime = legacyTime;
         opportunityStructures[structureIndex].centerPrice = legacyPrice;
         opportunityStructures[structureIndex].centerBarShift = (int)StringToInteger(fields[9]);
         opportunityStructures[structureIndex].radiusBars = opportunityStructureRadiusBars;
         opportunityStructures[structureIndex].representativeType = fields[8];
         opportunityStructures[structureIndex].actionSequence = legacySequence;
         if(!RecalculateOpportunityStructure(chartID, structureIndex, true))
           {
            ArrayResize(opportunityStructures, structureIndex);
            continue;
           }
         loadedStructures++;
         legacyStructures++;
        }
      else
        {
         int anchorIndex = FindOpportunityLineAnchorIndex(legacyRole);
         if(anchorIndex < 0 || legacySequence <= opportunityLineAnchors[anchorIndex].actionSequence) continue;
         opportunityLineAnchors[anchorIndex].barTime = legacyTime;
         opportunityLineAnchors[anchorIndex].price = legacyPrice;
         opportunityLineAnchors[anchorIndex].snapType = fields[8];
         opportunityLineAnchors[anchorIndex].barShift = (int)StringToInteger(fields[9]);
         opportunityLineAnchors[anchorIndex].actionSequence = legacySequence;
         opportunityLineAnchors[anchorIndex].active = true;
         loadedLines++;
        }
      if(legacySequence > maxSequence) maxSequence = legacySequence;
     }
   FileClose(handle);

   bool keyBarLoaded = LoadOpportunityKeyBar(chartID, maxSequence);
   RenumberOpportunityStructures();
   opportunityNextActionSequence = maxSequence + 1;
   Print("[EA|FULL|ANNOT] INFO archive loaded | case=", OpportunityCaseId(),
         " | structures=", loadedStructures, " | lines=", loadedLines,
         " | key_bar=", (int)keyBarLoaded,
         " | legacy_structures=", legacyStructures,
         " | radius=", opportunityStructureRadiusBars,
         " | native=", opportunityAnnotationNativeSymbol, "/", opportunityAnnotationNativeTimeframe,
         " | read_only=", (int)opportunityAnnotationReadOnly,
         " | next_sequence=", opportunityNextActionSequence,
         " | future_outcome_preserved=", (int)(StringLen(opportunityFutureOutcome) > 0));
   return (loadedStructures > 0 || loadedLines > 0 || keyBarLoaded);
  }

bool UndoOpportunityAnnotation(long chartID)
  {
   int structureTarget = -1;
   int lineTarget = -1;
   bool keyBarTarget = false;
   int highestSequence = -1;
   for(int i = 0; i < ArraySize(opportunityStructures); i++)
     {
      if(opportunityStructures[i].actionSequence > highestSequence)
        {
         highestSequence = opportunityStructures[i].actionSequence;
         structureTarget = i;
         lineTarget = -1;
         keyBarTarget = false;
        }
     }
   for(int i = 0; i < OPPORTUNITY_LINE_ANCHOR_COUNT; i++)
     {
      if(opportunityLineAnchors[i].active && opportunityLineAnchors[i].actionSequence > highestSequence)
        {
         highestSequence = opportunityLineAnchors[i].actionSequence;
         structureTarget = -1;
         lineTarget = i;
         keyBarTarget = false;
        }
     }

   if(opportunityKeyBar.active && opportunityKeyBar.actionSequence > highestSequence)
     {
      highestSequence = opportunityKeyBar.actionSequence;
      structureTarget = -1;
      lineTarget = -1;
      keyBarTarget = true;
     }

   if(structureTarget < 0 && lineTarget < 0 && !keyBarTarget)
     {
      Print("[EA|FULL|ANNOT] WARN undo ignored; case has no anchors | case=", OpportunityCaseId());
      UpdateOpportunityAnnotationPanel();
      return false;
     }

   string removedRole = "";
   if(structureTarget >= 0)
     {
      removedRole = opportunityStructures[structureTarget].role;
      int structureCount = ArraySize(opportunityStructures);
      for(int i = structureTarget; i < structureCount - 1; i++)
         opportunityStructures[i] = opportunityStructures[i + 1];
      ArrayResize(opportunityStructures, structureCount - 1);
      RenumberOpportunityStructures();
     }
   else if(lineTarget >= 0)
     {
      removedRole = opportunityLineAnchors[lineTarget].role;
      ResetOpportunityLineAnchor(lineTarget);
     }
   else
     {
      removedRole = opportunityKeyBar.role;
      ResetOpportunityKeyBar();
     }

   DrawOpportunityAnnotations(chartID);
   bool saved = SaveOpportunityAnnotation(chartID);
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO undo result | case=", OpportunityCaseId(),
         " | removed=", removedRole, " | saved=", (int)saved);
   return saved;
  }

void RestoreOpportunityChartView(long chartID, string reason)
  {
   if(opportunityChartViewVisible) return;
   opportunityChartViewVisible = true;
   DrawOpportunityAnnotations(chartID);
   int drawingsDrawn = DrawOpportunityDrawings(chartID);
   int regionLabelsDrawn = DrawOpportunityRegionLabels(chartID);
   UpdateOpportunityAnnotationPanel();
   Print("[EA|FULL|ANNOT] INFO chart view restored | case=", OpportunityCaseId(),
         " | reason=", reason,
         " | structures=", ArraySize(opportunityStructures),
         " | key_bar=", (int)opportunityKeyBar.active,
         " | drawings=", ArraySize(opportunityDrawings),
         " | drawings_drawn=", drawingsDrawn,
         " | regions=", ArraySize(opportunityRegions),
         " | region_labels=", regionLabelsDrawn,
         " | archive_touched=0 | view_visible=1");
  }

bool ClearOpportunityChartView(long chartID)
  {
   opportunityChartViewVisible = false;
   opportunityAnnotationMode = "";
   opportunityModeSelectedTick = 0;
   opportunityEditStructureIndex = -1;
   opportunityLastStructureLabelClickTick = 0;
   opportunityLastStructureLabelClickName = "";
   opportunityEditStateTick = GetTickCount();
   DeleteOpportunityRegionObjects(chartID);
   DeleteOpportunityDrawingObjects(chartID);
   DeleteOpportunityAnnotationObjects(chartID);
   UpdateOpportunityAnnotationPanel();
   ChartRedraw(chartID);
   Print("[EA|FULL|ANNOT] INFO chart clear result | case=", OpportunityCaseId(),
         " | structures_retained=", ArraySize(opportunityStructures),
         " | key_bar_retained=", (int)opportunityKeyBar.active,
         " | drawings_retained=", ArraySize(opportunityDrawings),
         " | regions_retained=", ArraySize(opportunityRegions),
         " | archive_touched=0 | view_visible=0");
   return true;
  }

string BuildNextOpportunityCaseId(long chartID, int year,
                                  ENUM_TIMEFRAMES timeframe)
  {
   string symbolToken = BuildFullSymbolForYear(year);
   int atIndex = StringFind(symbolToken, "@");
   if(atIndex > 0) symbolToken = StringSubstr(symbolToken, 0, atIndex);
   StringReplace(symbolToken, "_", "");
   StringReplace(symbolToken, "-", "");
   if(StringLen(symbolToken) == 0) symbolToken = "SYMBOL";

   if(PeriodSeconds(timeframe) <= 0) timeframe = InpFullTimeframe;
   int reservedSequence = 0;
   string sequenceReason = "";
   int sequenceError = 0;
   if(!CD_GetSequenceHighWater(InpOpportunityCaseSequencesCsvPath, year,
                               reservedSequence, sequenceReason,
                               sequenceError))
     {
      Print("[EA|FULL|CASE] ERROR sequence high-water unavailable",
            " | year=", year,
            " | path=", InpOpportunityCaseSequencesCsvPath,
            " | reason=", sequenceReason,
            " | err=", sequenceError,
            " | archive_touched=0");
      return "";
     }
   int maximumSequence = reservedSequence;
   string caseToken = "-CASE-";
   for(int i = 0; i < ArraySize(opportunityCaseCatalog); i++)
     {
      if(opportunityCaseCatalog[i].year != year) continue;
      int tokenPos = StringFind(opportunityCaseCatalog[i].caseId, caseToken);
      if(tokenPos < 0) continue;
      int archivedSequence = (int)StringToInteger(
         StringSubstr(opportunityCaseCatalog[i].caseId,
                      tokenPos + StringLen(caseToken)));
      if(archivedSequence > maximumSequence) maximumSequence = archivedSequence;
     }

   int sequence = maximumSequence + 1;
   string candidate = "";
   do
     {
      candidate = symbolToken + "-" + IntegerToString(year) + "-" +
                  TimeframeName(timeframe) + "-CASE-" + StringFormat("%03d", sequence);
      sequence++;
     }
   while(FindOpportunityCaseCatalogIndex(candidate) >= 0);
   return candidate;
  }

bool PrepareOpportunitySessionForYear(long chartID, int year, string targetCaseId,
                                      string reason)
  {
   HideOpportunityDetailsPanel(chartID);
   string targetSymbol = BuildFullSymbolForYear(year);
   int targetIndex = StringLen(targetCaseId) > 0 ?
                     FindOpportunityCaseCatalogIndex(targetCaseId) : -1;
   if(StringLen(targetCaseId) > 0 &&
      (targetIndex < 0 || opportunityCaseCatalog[targetIndex].year != year))
     {
      Print("[EA|FULL|YEAR] ERROR session prepare rejected | year=", year,
            " | target_case=", targetCaseId,
            " | catalog_index=", targetIndex,
            " | archive_touched=0");
      return false;
     }

   if(targetIndex >= 0)
     {
      OpportunityCaseCatalogEntry targetEntry = opportunityCaseCatalog[targetIndex];
      opportunityActiveCaseId = targetEntry.caseId;
      opportunityActiveCaseType = targetEntry.caseType;
      opportunityArchivedCaseType = targetEntry.caseType;
      opportunityCaseTypeDirty = false;
      opportunityActiveStandardity = targetEntry.standardity;
      opportunityArchivedStandardity = targetEntry.standardity;
      opportunityStandardityDirty = false;
      opportunityAnnotationNativeSymbol = targetEntry.symbol;
      opportunityAnnotationNativeTimeframe = targetEntry.timeframe;
     }
   else if(OpportunityCaseIdYear(OpportunityCaseId()) != year)
     {
       string newCaseId = BuildNextOpportunityCaseId(chartID, year,
                                                      InpFullTimeframe);
      if(StringLen(newCaseId) == 0 || FindOpportunityCaseCatalogIndex(newCaseId) >= 0)
        {
         Print("[EA|FULL|YEAR] ERROR draft id unavailable | year=", year,
               " | candidate=", newCaseId,
               " | archive_touched=0");
         return false;
        }
      opportunityActiveCaseId = OpportunityCsvSafe(newCaseId);
      opportunityActiveCaseType = "UNSELECTED";
      opportunityArchivedCaseType = "";
      opportunityCaseTypeDirty = false;
      opportunityCaseTypeCommitInProgress = false;
      opportunityActiveStandardity = "UNREVIEWED";
      opportunityArchivedStandardity = "UNREVIEWED";
      opportunityStandardityDirty = false;
      opportunityStandardityCommitInProgress = false;
      opportunityAnnotationNativeSymbol = targetSymbol;
      opportunityAnnotationNativeTimeframe = TimeframeName(InpFullTimeframe);
      ResetPureReleaseShadowState("year_new_draft");
     }

   if(StringLen(opportunityActiveCaseId) > 0)
      opportunityExplicitNoSelection = false;

   if(StringLen(opportunityAnnotationNativeSymbol) == 0)
      opportunityAnnotationNativeSymbol = targetSymbol;
   if(StringLen(opportunityAnnotationNativeTimeframe) == 0)
      opportunityAnnotationNativeTimeframe = TimeframeName(InpFullTimeframe);
   opportunityAnnotationReadOnly = false;
   opportunitySessionStateRestored = true;
   opportunitySessionWorkYear = year;
   Print("[EA|FULL|YEAR] INFO session prepared | reason=", reason,
         " | year=", year, " | symbol=", targetSymbol,
         " | case=", OpportunityCaseId(),
         " | type=", OpportunityCaseType(),
         " | archived_type=", opportunityArchivedCaseType,
         " | archive_touched=0");
   return true;
  }

bool StartNewOpportunityCase(long chartID)
  {
   HideOpportunityDetailsPanel(chartID);
   string previousCaseId = OpportunityCaseId();
   string previousCaseType = OpportunityCaseType();
   if(!LoadOpportunityCaseCatalog(chartID))
     {
      SetOpportunityCaseFeedback("新建失败 | 案例目录不可用",
                                 OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      Print("[EA|FULL|CASE] ERROR new draft rejected; catalog unavailable | previous=",
            previousCaseId, " | archive_touched=0");
      return false;
     }

   ENUM_TIMEFRAMES draftTimeframe =
      (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   if(PeriodSeconds(draftTimeframe) <= 0)
      draftTimeframe = InpFullTimeframe;
   string newCaseId = BuildNextOpportunityCaseId(chartID, fullWorkYear,
                                                  draftTimeframe);
   if(StringLen(newCaseId) == 0 || FindOpportunityCaseCatalogIndex(newCaseId) >= 0)
     {
      SetOpportunityCaseFeedback("新建失败 | 无法生成案例编号",
                                 OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      Print("[EA|FULL|CASE] ERROR new draft id unavailable | previous=",
            previousCaseId, " | candidate=", newCaseId,
            " | archive_touched=0");
      return false;
     }

   CloseOpportunityCaseMenu(chartID);
   CloseOpportunityTypeMenu(chartID);
   DeleteOpportunityRegionObjects(chartID);
   DeleteOpportunityDrawingObjects(chartID);
   DeleteOpportunityAnnotationObjects(chartID);
   ResetOpportunityAnnotationState();
   ResetPureReleaseShadowState("new_draft");

   opportunityActiveCaseId = OpportunityCsvSafe(newCaseId);
   opportunityActiveCaseType = "UNSELECTED";
   opportunityArchivedCaseType = "";
   opportunityCaseTypeDirty = false;
   opportunityCaseTypeCommitInProgress = false;
   opportunityActiveStandardity = "UNREVIEWED";
   opportunityArchivedStandardity = "UNREVIEWED";
   opportunityStandardityDirty = false;
   opportunityStandardityCommitInProgress = false;
   opportunityAnnotationNativeSymbol = FullSymbolName();
    opportunityAnnotationNativeTimeframe = TimeframeName(draftTimeframe);
    RefreshOpportunityAnnotationReadOnly(chartID);
    opportunityChartViewVisible = true;
    opportunityCaseSearchYear = fullWorkYear;
    opportunityCaseSearchCaseId = "";
    SaveOpportunitySessionState(chartID, "new_draft");
    UpdateOpportunityCaseSearchButtons();
    UpdateOpportunityAnnotationPanel();
   SetOpportunityCaseFeedback("新案例 | 请先选择机会类型",
                              OPPORTUNITY_CASE_FEEDBACK_SUCCESS_MS);
   ChartRedraw(chartID);
   Print("[EA|FULL|CASE] INFO new draft started | previous=", previousCaseId,
         " | previous_type=", previousCaseType,
         " | new=", OpportunityCaseId(),
         " | type=UNSELECTED",
         " | standardity=UNREVIEWED",
         " | native=", opportunityAnnotationNativeSymbol, "/",
         opportunityAnnotationNativeTimeframe,
         " | catalog_cases=", ArraySize(opportunityCaseCatalog),
         " | archive_touched=0 | view_visible=1");
   return true;
  }

void InitializeOpportunityAnnotation(long chartID)
  {
   bool restoredSession = opportunitySessionStateRestored;
   string restoredNativeSymbol = opportunityAnnotationNativeSymbol;
   string restoredNativeTimeframe = opportunityAnnotationNativeTimeframe;
   ResetOpportunityAnnotationState();
   if(opportunityExplicitNoSelection)
     {
      DeleteOpportunityRegionObjects(chartID);
      DeleteOpportunityDrawingObjects(chartID);
      DeleteOpportunityAnnotationObjects(chartID);
      opportunityAnnotationReadOnly = false;
      UpdateOpportunityAnnotationPanel();
      Print("[EA|FULL|ANNOT] INFO explicit no-selection initialized",
            " | work_year=", fullWorkYear,
            " | archive_touched=0 | view_visible=1");
      return;
     }
   if(restoredSession)
     {
      opportunityAnnotationNativeSymbol = restoredNativeSymbol;
      opportunityAnnotationNativeTimeframe = restoredNativeTimeframe;
      RefreshOpportunityAnnotationReadOnly(chartID);
     }

   bool unarchivedDraft = (restoredSession &&
                           FindOpportunityCaseCatalogIndex(OpportunityCaseId()) < 0);
    if(unarchivedDraft)
      {
       DeleteOpportunityRegionObjects(chartID);
       DeleteOpportunityDrawingObjects(chartID);
       DeleteOpportunityAnnotationObjects(chartID);
       string chartSymbol = ChartSymbol(chartID);
       ENUM_TIMEFRAMES chartTimeframe =
          (ENUM_TIMEFRAMES)ChartPeriod(chartID);
       if(PeriodSeconds(chartTimeframe) <= 0)
          chartTimeframe = InpFullTimeframe;
       string chartTimeframeName = TimeframeName(chartTimeframe);
       bool draftNeedsRebind =
          (opportunityAnnotationNativeSymbol != chartSymbol ||
           opportunityAnnotationNativeTimeframe != chartTimeframeName);
       if(draftNeedsRebind)
         {
          string previousCaseId = OpportunityCaseId();
          string previousNativeSymbol = opportunityAnnotationNativeSymbol;
          string previousNativeTimeframe = opportunityAnnotationNativeTimeframe;
          string reboundCaseId = BuildNextOpportunityCaseId(chartID,
                                                             fullWorkYear,
                                                             chartTimeframe);
          if(StringLen(reboundCaseId) > 0 &&
             FindOpportunityCaseCatalogIndex(reboundCaseId) < 0)
            {
             opportunityActiveCaseId = OpportunityCsvSafe(reboundCaseId);
             opportunityAnnotationNativeSymbol = chartSymbol;
             opportunityAnnotationNativeTimeframe = chartTimeframeName;
             opportunityAnnotationReadOnly = false;
             opportunitySessionWorkYear = fullWorkYear;
             Print("[EA|FULL|ANNOT] INFO draft timeframe rebound | previous=",
                   previousCaseId, " | new=", OpportunityCaseId(),
                   " | previous_native=", previousNativeSymbol, "/",
                   previousNativeTimeframe,
                   " | native=", opportunityAnnotationNativeSymbol, "/",
                   opportunityAnnotationNativeTimeframe,
                   " | archive_touched=0");
            }
          else
            {
             Print("[EA|FULL|ANNOT] ERROR draft timeframe rebound failed | case=",
                   previousCaseId, " | candidate=", reboundCaseId,
                   " | chart=", chartSymbol, "/", chartTimeframeName,
                   " | err=0 | archive_touched=0");
            }
         }
       if(StringLen(opportunityAnnotationNativeSymbol) == 0)
          opportunityAnnotationNativeSymbol = chartSymbol;
       if(StringLen(opportunityAnnotationNativeTimeframe) == 0)
          opportunityAnnotationNativeTimeframe = chartTimeframeName;
       RefreshOpportunityAnnotationReadOnly(chartID);
       UpdateOpportunityAnnotationPanel();
      SaveOpportunitySessionState(chartID, "draft_initialized");
      RunPureReleaseShadowPreflight(chartID, "draft_initialized");
      Print("[EA|FULL|ANNOT] INFO draft initialized | case=", OpportunityCaseId(),
            " | type=", OpportunityCaseType(),
            " | archived_type=", opportunityArchivedCaseType,
            " | type_dirty=", (int)opportunityCaseTypeDirty,
            " | standardity=", opportunityActiveStandardity,
            " | archived_standardity=", opportunityArchivedStandardity,
            " | standardity_dirty=", (int)opportunityStandardityDirty,
            " | native=", opportunityAnnotationNativeSymbol, "/",
            opportunityAnnotationNativeTimeframe,
            " | chart=", ChartSymbol(chartID), "/",
            TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID)),
            " | read_only=", (int)opportunityAnnotationReadOnly,
            " | archives_skipped=1 | types_verified=skipped",
            " | archive_touched=0 | view_visible=1");
      return;
     }

   bool loaded = LoadOpportunityAnnotation(chartID);
   bool drawingsLoaded = LoadOpportunityDrawings(chartID);
   bool regionsLoaded = LoadOpportunityRegions(chartID);
   bool regionsMigrated = false;
   if(!regionsLoaded && drawingsLoaded)
     {
      OpportunityRegionState migratedRegions[];
      if(BuildOpportunityRegionsFromDrawings(chartID, opportunityDrawings, migratedRegions))
        {
         bool migrationSaved = SaveOpportunityRegionSnapshot(chartID, migratedRegions);
         if(migrationSaved) regionsLoaded = LoadOpportunityRegions(chartID);
         regionsMigrated = (migrationSaved && regionsLoaded);
         Print("[EA|FULL|REGION] INFO archive migration result | case=", OpportunityCaseId(),
               " | saved=", (int)migrationSaved,
               " | loaded=", (int)regionsLoaded,
               " | regions=", ArraySize(opportunityRegions));
        }
     }
   if(StringLen(opportunityAnnotationNativeSymbol) == 0)
     {
      opportunityAnnotationNativeSymbol = ChartSymbol(chartID);
      opportunityAnnotationNativeTimeframe = TimeframeName((ENUM_TIMEFRAMES)ChartPeriod(chartID));
     }
   bool channelBoundariesLoaded = (drawingsLoaded && regionsLoaded) ?
                                  LoadOpportunityChannelBoundaries(chartID) : false;
   bool semanticsLoaded = (drawingsLoaded && regionsLoaded &&
                           channelBoundariesLoaded) ?
                          LoadOpportunityDrawingSemantics(chartID, true) : false;
   string validationType = (opportunityCaseTypeDirty &&
                            StringLen(opportunityArchivedCaseType) > 0) ?
                           opportunityArchivedCaseType : OpportunityCaseType();
   bool typesValidated = ValidateOpportunityCaseTypeArchives(validationType,
                                                               1,
                                                              ArraySize(opportunityStructures) +
                                                              CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1),
                                                              opportunityKeyBar.active ? 1 : 0,
                                                              ArraySize(opportunityDrawings),
                                                              ArraySize(opportunityRegions));
   LogOpportunityGeometrySemanticAdvice(chartID, opportunityDrawings,
                                         opportunityRegions, "initialization");
   DrawOpportunityAnnotations(chartID);
   int drawingsDrawn = DrawOpportunityDrawings(chartID);
    int regionLabelsDrawn = DrawOpportunityRegionLabels(chartID);
    UpdateOpportunityAnnotationPanel();
    SaveOpportunitySessionState(chartID, "initialized");
    Print("[EA|FULL|ANNOT] INFO initialized | case=", OpportunityCaseId(),
         " | type=", OpportunityCaseType(), " | loaded=", (int)loaded,
         " | standardity=", opportunityActiveStandardity,
         " | archived_standardity=", opportunityArchivedStandardity,
         " | standardity_dirty=", (int)opportunityStandardityDirty,
         " | native=", opportunityAnnotationNativeSymbol, "/", opportunityAnnotationNativeTimeframe,
         " | read_only=", (int)opportunityAnnotationReadOnly,
         " | cases_path=", InpOpportunityCasesCsvPath,
         " | anchors_path=", InpOpportunityAnchorsCsvPath,
          " | key_bars_path=", InpOpportunityKeyBarsCsvPath,
          " | key_bar_active=", (int)opportunityKeyBar.active,
           " | drawings_path=", InpOpportunityDrawingsCsvPath,
           " | drawings_loaded=", (int)drawingsLoaded,
           " | drawings_drawn=", drawingsDrawn,
           " | regions_path=", InpOpportunityRegionsCsvPath,
           " | regions_loaded=", (int)regionsLoaded,
           " | regions_migrated=", (int)regionsMigrated,
            " | regions=", ArraySize(opportunityRegions),
            " | channel_boundaries_path=", InpOpportunityChannelBoundariesCsvPath,
            " | channel_boundaries_loaded=", (int)channelBoundariesLoaded,
            " | channel_boundaries=", ArraySize(opportunityChannelBoundaries),
            " | semantics_path=", InpOpportunityDrawingSemanticsCsvPath,
            " | semantics_loaded=", (int)semanticsLoaded,
            " | semantics=", ArraySize(opportunityDrawingSemantics),
            " | region_labels=", regionLabelsDrawn,
            " | types_verified=", (int)typesValidated);
  }

bool LoadOpportunityCaseArchivesReadOnly(long chartID,
                                         OpportunityCaseCatalogEntry &entry,
                                         string &failureReason)
  {
   failureReason = "";
   ResetOpportunityAnnotationState();
   bool annotationsLoaded = LoadOpportunityAnnotation(chartID);
   bool drawingsLoaded = LoadOpportunityDrawings(chartID);
   bool regionsLoaded = LoadOpportunityRegions(chartID);
   if(StringLen(opportunityAnnotationNativeSymbol) == 0)
     {
      opportunityAnnotationNativeSymbol = entry.symbol;
      opportunityAnnotationNativeTimeframe = entry.timeframe;
     }
   bool channelBoundariesLoaded = (drawingsLoaded && regionsLoaded) ?
                                  LoadOpportunityChannelBoundaries(chartID) : false;
   bool semanticsLoaded = (drawingsLoaded && regionsLoaded &&
                           channelBoundariesLoaded) ?
                          LoadOpportunityDrawingSemantics(chartID, true) : false;

   int actualStructures = ArraySize(opportunityStructures);
   int actualLines = CountOpportunityLineAnchors(0, OPPORTUNITY_LINE_ANCHOR_COUNT - 1);
   int actualKeyBars = opportunityKeyBar.active ? 1 : 0;
   int actualDrawings = ArraySize(opportunityDrawings);
   int actualRegions = ArraySize(opportunityRegions);
   bool typesMatch = ValidateOpportunityCaseTypeArchives(entry.caseType,
                                                          1,
                                                          actualStructures + actualLines,
                                                          actualKeyBars,
                                                          actualDrawings,
                                                          actualRegions);
   bool countsMatch = (actualStructures == entry.structureCount &&
                       actualLines == entry.lineCount &&
                       actualKeyBars == entry.keyBarCount &&
                       actualDrawings == entry.drawingCount &&
                       actualRegions == entry.regionCount &&
                       typesMatch);
   if(!countsMatch)
     {
      if(!typesMatch)
         failureReason = "五档案机会类型不一致";
      else
         failureReason = StringFormat("数量校验失败 S%d/%d K%d/%d D%d/%d R%d/%d",
                                      actualStructures, entry.structureCount,
                                      actualKeyBars, entry.keyBarCount,
                                      actualDrawings, entry.drawingCount,
                                      actualRegions, entry.regionCount);
     }

   Print("[EA|FULL|CASE] INFO read-only archive validation | case=", OpportunityCaseId(),
         " | annotations_loaded=", (int)annotationsLoaded,
         " | drawings_loaded=", (int)drawingsLoaded,
         " | regions_loaded=", (int)regionsLoaded,
         " | channel_boundaries_loaded=", (int)channelBoundariesLoaded,
         " | channel_boundaries=", ArraySize(opportunityChannelBoundaries),
         " | semantics_loaded=", (int)semanticsLoaded,
         " | semantics=", ArraySize(opportunityDrawingSemantics),
         " | structures=", actualStructures, "/", entry.structureCount,
         " | lines=", actualLines, "/", entry.lineCount,
         " | key_bars=", actualKeyBars, "/", entry.keyBarCount,
         " | drawings=", actualDrawings, "/", entry.drawingCount,
         " | regions=", actualRegions, "/", entry.regionCount,
         " | types_verified=", (int)typesMatch,
          " | verified=", (int)countsMatch,
          " | archive_touched=0");
   if(countsMatch)
      LogOpportunityGeometrySemanticAdvice(chartID, opportunityDrawings,
                                            opportunityRegions, "case_switch");
   return countsMatch;
  }

bool FocusOpportunityCaseOnChart(long chartID, OpportunityCaseCatalogEntry &entry)
  {
   datetime rangeStart = entry.formationStart;
   datetime rangeEnd = entry.readyTime;
   string focusScope = "formation_ready";
   int accumulationIndex = -1;
   for(int i = 0; i < ArraySize(opportunityRegions); i++)
      if(opportunityRegions[i].role == "ACCUMULATION") accumulationIndex = i;
   if(accumulationIndex >= 0 &&
      opportunityRegions[accumulationIndex].startTime > 0 &&
      opportunityRegions[accumulationIndex].endTime >
      opportunityRegions[accumulationIndex].startTime)
     {
      rangeStart = opportunityRegions[accumulationIndex].startTime;
      rangeEnd = opportunityRegions[accumulationIndex].endTime;
      focusScope = "accumulation_r2";
     }
   else if(entry.regionCount == OPPORTUNITY_REGION_COUNT &&
           entry.regionStart > 0 && entry.regionEnd > entry.regionStart)
     {
      rangeStart = entry.regionStart;
      rangeEnd = entry.regionEnd;
      focusScope = "full_opportunity_fallback";
     }
   if(rangeStart <= 0) rangeStart = entry.sortTime;
   if(rangeEnd <= rangeStart) rangeEnd = rangeStart;
   if(rangeStart <= 0)
     {
      Print("[EA|FULL|CASE] ERROR focus range unavailable | case=", entry.caseId);
      return false;
     }

   string symbol = ChartSymbol(chartID);
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   int startShift = iBarShift(symbol, timeframe, rangeStart, false);
   int endShift = iBarShift(symbol, timeframe, rangeEnd, false);
   if(startShift < 0 || endShift < 0)
     {
      Print("[EA|FULL|CASE] ERROR focus boundary not found | case=", entry.caseId,
            " | scope=", focusScope,
            " | range=", TimeToString(rangeStart, TIME_DATE|TIME_MINUTES),
            "..", TimeToString(rangeEnd, TIME_DATE|TIME_MINUTES),
            " | shifts=", startShift, "/", endShift,
            " | chart=", symbol, "/", TimeframeName(timeframe));
      return false;
     }
   int targetShift = (startShift + endShift) / 2;
   datetime targetTime = iTime(symbol, timeframe, targetShift);
   if(targetTime <= 0)
     {
      Print("[EA|FULL|CASE] ERROR focus center bar unavailable | case=", entry.caseId,
            " | scope=", focusScope,
            " | target_shift=", targetShift,
            " | chart=", symbol, "/", TimeframeName(timeframe));
      return false;
     }

   int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
   if(visibleBars <= 0) visibleBars = 80;
   int position = -targetShift + MathMax(10, visibleBars / 2);
   ChartSetInteger(chartID, CHART_AUTOSCROLL, false);
   ResetLastError();
   bool navigated = ChartNavigate(chartID, CHART_END, position);
   int navigationError = navigated ? 0 : GetLastError();
   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   int desiredCenterX = chartWidth / 2;
   int rangeCenterX = -1;
   int pixelError = 0;
   int centeringPasses = 0;
   bool centerVerified = false;
   if(navigated && chartWidth > 0)
     {
      datetime startBarTime = iTime(symbol, timeframe, startShift);
      datetime endBarTime = iTime(symbol, timeframe, endShift);
      int boundaryBarSpan = MathAbs(startShift - endShift);
      ChartRedraw(chartID);

      for(int pass = 0; pass < 3; pass++)
        {
         double priceMin = ChartGetDouble(chartID, CHART_PRICE_MIN, 0);
         double priceMax = ChartGetDouble(chartID, CHART_PRICE_MAX, 0);
         double referencePrice = (priceMin + priceMax) / 2.0;
         int startX = 0;
         int startY = 0;
         int endX = 0;
         int endY = 0;
         ResetLastError();
         bool startOK = ChartTimePriceToXY(chartID, 0, startBarTime,
                                           referencePrice, startX, startY);
         bool endOK = ChartTimePriceToXY(chartID, 0, endBarTime,
                                         referencePrice, endX, endY);
         if(!startOK || !endOK || boundaryBarSpan <= 0)
           {
            Print("[EA|FULL|CASE] WARN focus pixel measurement failed | case=",
                  entry.caseId, " | pass=", pass,
                  " | start_ok=", (int)startOK, " | end_ok=", (int)endOK,
                  " | boundary_bar_span=", boundaryBarSpan,
                  " | err=", GetLastError());
            break;
           }

         rangeCenterX = (startX + endX) / 2;
         pixelError = rangeCenterX - desiredCenterX;
         double pixelsPerBar = (double)MathAbs(endX - startX) /
                               (double)boundaryBarSpan;
         int tolerancePx = MathMax(2, (int)MathCeil(pixelsPerBar / 2.0));
         if(MathAbs(pixelError) <= tolerancePx)
           {
            centerVerified = true;
            break;
           }
         if(pixelsPerBar <= 0.0) break;

         int correctionBars = (int)MathRound((double)pixelError / pixelsPerBar);
         if(correctionBars == 0) break;
         position += correctionBars;
         ResetLastError();
         bool corrected = ChartNavigate(chartID, CHART_END, position);
         if(!corrected)
           {
            navigationError = GetLastError();
            Print("[EA|FULL|CASE] WARN focus pixel correction failed | case=",
                  entry.caseId, " | pass=", pass,
                  " | correction_bars=", correctionBars,
                  " | position=", position,
                  " | err=", navigationError);
            break;
           }
         centeringPasses++;
         ChartRedraw(chartID);
        }
     }
   else if(navigated)
      ChartRedraw(chartID);
   Print("[EA|FULL|CASE] INFO chart focus | case=", entry.caseId,
         " | code=", entry.caseCode,
         " | opportunity_level=", entry.opportunityLevel,
         " | accumulation_duration_hours=",
         DoubleToString(entry.accumulationDurationHours, 1),
         " | accumulation_h1_bars=", entry.accumulationH1Bars,
         " | scope=", focusScope,
         " | range=", TimeToString(rangeStart, TIME_DATE|TIME_MINUTES),
         "..", TimeToString(rangeEnd, TIME_DATE|TIME_MINUTES),
         " | target=", TimeToString(targetTime, TIME_DATE|TIME_MINUTES),
         " | boundary_shifts=", startShift, "/", endShift,
         " | shift=", targetShift, " | visible_bars=", visibleBars,
         " | position=", position,
         " | chart_center_x=", desiredCenterX,
         " | range_center_x=", rangeCenterX,
         " | pixel_error=", pixelError,
         " | centering_passes=", centeringPasses,
         " | center_verified=", (int)centerVerified,
         " | navigated=", (int)navigated,
         " | err=", navigationError);
   return navigated;
  }

bool RedrawOpportunityCase(long chartID,
                           OpportunityCaseCatalogEntry &entry,
                           int &drawingsDrawn,
                           int &regionLabelsDrawn)
  {
   opportunityChartViewVisible = true;
   DrawOpportunityAnnotations(chartID);
   drawingsDrawn = DrawOpportunityDrawings(chartID);
   regionLabelsDrawn = DrawOpportunityRegionLabels(chartID);
   bool drawingsOK = (drawingsDrawn == entry.drawingCount);
   Print("[EA|FULL|CASE] INFO case redraw | case=", entry.caseId,
         " | structures=", ArraySize(opportunityStructures),
         " | key_bar=", (int)opportunityKeyBar.active,
         " | drawings=", drawingsDrawn, "/", entry.drawingCount,
         " | region_labels=", regionLabelsDrawn, "/", entry.regionCount,
         " | drawings_verified=", (int)drawingsOK,
         " | archive_touched=0");
   return drawingsOK;
  }

bool SwitchOpportunityCase(long chartID, int targetIndex)
  {
   if(!opportunityCaseCatalogReady || targetIndex < 0 ||
      targetIndex >= ArraySize(opportunityCaseCatalog))
     {
      Print("[EA|FULL|CASE] ERROR switch rejected | target_index=", targetIndex,
            " | catalog_ready=", (int)opportunityCaseCatalogReady,
            " | cases=", ArraySize(opportunityCaseCatalog));
      SetOpportunityCaseFeedback("案例加载失败 | 无效选项",
                                 OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
      return false;
     }

    HideOpportunityDetailsPanel(chartID);
    OpportunityCaseCatalogEntry targetEntry = opportunityCaseCatalog[targetIndex];
   string targetYearSymbol = BuildFullSymbolForYear(targetEntry.year);
   if(targetEntry.year != fullWorkYear || ChartSymbol(chartID) != targetYearSymbol)
     {
      Print("[EA|FULL|CASE] INFO cross-year switch delegated | case=",
            targetEntry.caseId, " | from_year=", fullWorkYear,
            " | to_year=", targetEntry.year,
            " | from_symbol=", ChartSymbol(chartID),
            " | to_symbol=", targetYearSymbol,
            " | archive_touched=0");
      return SwitchFullWorkYear(chartID, targetEntry.year,
                                "case_selector", targetEntry.caseId);
     }
   string oldCaseId = OpportunityCaseId();
   string oldCaseType = OpportunityCaseType();
    string oldArchivedCaseType = opportunityArchivedCaseType;
    bool oldCaseTypeDirty = opportunityCaseTypeDirty;
    string oldActiveStandardity = opportunityActiveStandardity;
    string oldArchivedStandardity = opportunityArchivedStandardity;
    bool oldStandardityDirty = opportunityStandardityDirty;
    string oldNativeSymbol = opportunityAnnotationNativeSymbol;
    string oldNativeTimeframe = opportunityAnnotationNativeTimeframe;
    bool oldReadOnly = opportunityAnnotationReadOnly;
   int oldIndex = FindOpportunityCaseCatalogIndex(oldCaseId);
   bool oldEntryAvailable = (oldIndex >= 0);
   OpportunityCaseCatalogEntry oldEntry;
   if(oldEntryAvailable) oldEntry = opportunityCaseCatalog[oldIndex];

   opportunityAnnotationMode = "";
   opportunityModeSelectedTick = 0;
   opportunityEditStructureIndex = -1;
   opportunityLastStructureLabelClickTick = 0;
   opportunityLastStructureLabelClickName = "";
   opportunityEditStateTick = GetTickCount();
   opportunitySaveFeedbackState = "";
   opportunitySaveFeedbackStatus = "";
   opportunitySaveFeedbackDurationMs = 0;
   opportunityCaseFeedbackStatus = "";
   opportunityCaseFeedbackDurationMs = 0;

   Print("[EA|FULL|CASE] INFO switch started | from=", oldCaseId,
         " | to=", targetEntry.caseId,
         " | force_reload=", (int)(oldCaseId == targetEntry.caseId),
         " | archive_touched=0");
   DeleteOpportunityRegionObjects(chartID);
   DeleteOpportunityDrawingObjects(chartID);
   DeleteOpportunityAnnotationObjects(chartID);

   opportunityActiveCaseId = targetEntry.caseId;
   opportunityActiveCaseType = targetEntry.caseType;
   opportunityArchivedCaseType = targetEntry.caseType;
   opportunityCaseTypeDirty = false;
   opportunityActiveStandardity = targetEntry.standardity;
   opportunityArchivedStandardity = targetEntry.standardity;
   opportunityStandardityDirty = false;
   string failureReason = "";
   bool loaded = LoadOpportunityCaseArchivesReadOnly(chartID, targetEntry, failureReason);
   bool focused = loaded && FocusOpportunityCaseOnChart(chartID, targetEntry);
   int drawingsDrawn = 0;
   int regionLabelsDrawn = 0;
   bool redrawn = focused && RedrawOpportunityCase(chartID, targetEntry,
                                                   drawingsDrawn, regionLabelsDrawn);
   if(loaded && focused && redrawn)
     {
      string successText = StringFormat("案例已加载 | S %d | K %d | D %d | 区间 %d",
                                        ArraySize(opportunityStructures),
                                        opportunityKeyBar.active ? 1 : 0,
                                        ArraySize(opportunityDrawings),
                                        ArraySize(opportunityRegions));
      SetOpportunityCaseFeedback(successText, OPPORTUNITY_CASE_FEEDBACK_SUCCESS_MS);
       Print("[EA|FULL|CASE] INFO switch result | case=", OpportunityCaseId(),
            " | loaded=1 | focused=1 | redrawn=1",
            " | structures=", ArraySize(opportunityStructures),
            " | key_bar=", (int)opportunityKeyBar.active,
             " | drawings=", ArraySize(opportunityDrawings),
             " | regions=", ArraySize(opportunityRegions),
             " | standardity=", opportunityActiveStandardity,
             " | archive_touched=0");
       SaveOpportunitySessionState(chartID, "case_switch_success");
       return true;
     }

   if(StringLen(failureReason) == 0)
     {
      if(!focused) failureReason = "图表定位失败";
      else if(!redrawn) failureReason = "绘图重建失败";
      else failureReason = "未知错误";
     }
   Print("[EA|FULL|CASE] ERROR switch failed; restoring previous case | target=",
         targetEntry.caseId, " | reason=", failureReason,
         " | archive_touched=0");
   DeleteOpportunityRegionObjects(chartID);
   DeleteOpportunityDrawingObjects(chartID);
   DeleteOpportunityAnnotationObjects(chartID);

   opportunityActiveCaseId = oldCaseId;
   opportunityActiveCaseType = oldCaseType;
   opportunityArchivedCaseType = oldArchivedCaseType;
   opportunityCaseTypeDirty = oldCaseTypeDirty;
   opportunityActiveStandardity = oldActiveStandardity;
   opportunityArchivedStandardity = oldArchivedStandardity;
   opportunityStandardityDirty = oldStandardityDirty;
   bool rollbackOK = false;
   if(oldEntryAvailable)
     {
      string rollbackReason = "";
      bool rollbackLoaded = LoadOpportunityCaseArchivesReadOnly(chartID, oldEntry, rollbackReason);
      bool rollbackFocused = rollbackLoaded && FocusOpportunityCaseOnChart(chartID, oldEntry);
      int rollbackDrawings = 0;
      int rollbackLabels = 0;
      bool rollbackRedrawn = rollbackFocused && RedrawOpportunityCase(chartID, oldEntry,
                                                                      rollbackDrawings,
                                                                      rollbackLabels);
      rollbackOK = (rollbackLoaded && rollbackFocused && rollbackRedrawn);
      Print("[EA|FULL|CASE] INFO rollback result | case=", oldCaseId,
            " | loaded=", (int)rollbackLoaded,
            " | focused=", (int)rollbackFocused,
            " | redrawn=", (int)rollbackRedrawn,
            " | reason=", rollbackReason,
            " | archive_touched=0");
     }
    else
      {
       ResetOpportunityAnnotationState();
       opportunityAnnotationNativeSymbol = oldNativeSymbol;
       opportunityAnnotationNativeTimeframe = oldNativeTimeframe;
       opportunityAnnotationReadOnly = oldReadOnly;
       Print("[EA|FULL|CASE] ERROR rollback catalog entry unavailable | case=", oldCaseId,
             " | archive_touched=0");
      }

   string failureStatus = rollbackOK ?
                          "案例加载失败 | 已恢复原案例" :
                          "案例加载失败 | 原案例恢复失败";
    SetOpportunityCaseFeedback(failureStatus, OPPORTUNITY_CASE_FEEDBACK_FAILURE_MS);
    SaveOpportunitySessionState(chartID, "case_switch_rollback");
    return false;
  }

void GoFullChartToStart(long chartID)
  {
   if(chartID == 0) return;

   string sym = ChartSymbol(chartID);
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   if(StringLen(sym) == 0) sym = FullSymbolName();
   if(tf <= 0) tf = InpFullTimeframe;

   int bars = Bars(sym, tf);
   if(bars <= 0)
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | GO START skipped: no bars | sym=", sym, " tf=", (int)tf);
      return;
     }

   datetime firstTime = iTime(sym, tf, bars - 1);
   ChartSetInteger(chartID, CHART_AUTOSCROLL, false);

   bool navOK = ChartNavigate(chartID, CHART_BEGIN, 0);
   if(!navOK) navOK = ChartNavigate(chartID, CHART_END, -(bars - 1));

   ChartRedraw(chartID);
   if(GV_DEBUG_FULL) Print("FULL-DBG | GO START | chart=", chartID, " bars=", bars, " first=", TimeToString(firstTime), " ok=", (int)navOK);
  }

bool ResolveZonePriceRange(string symbol, ENUM_TIMEFRAMES tf, datetime startTime, datetime endTime, double &zoneLow, double &zoneHigh)
  {
   int startShift = iBarShift(symbol, tf, startTime, false);
   int endShift = iBarShift(symbol, tf, endTime, false);
   if(startShift < 0 || endShift < 0) return false;

   int fromShift = MathMin(startShift, endShift);
   int toShift = MathMax(startShift, endShift);
   int count = toShift - fromShift + 1;
   if(count <= 0) return false;

   double highs[];
   double lows[];
   int gotHigh = CopyHigh(symbol, tf, fromShift, count, highs);
   int gotLow = CopyLow(symbol, tf, fromShift, count, lows);
   if(gotHigh <= 0 || gotLow <= 0) return false;

   int idxMax = ArrayMaximum(highs, 0, gotHigh);
   int idxMin = ArrayMinimum(lows, 0, gotLow);
   if(idxMax < 0 || idxMin < 0) return false;

   zoneHigh = highs[idxMax];
   zoneLow = lows[idxMin];
   return (zoneHigh > zoneLow);
  }

void ClearAccumulationZones(long chartID)
  {
   if(chartID == 0) return;

   int total = ObjectsTotal(chartID, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chartID, i, -1, -1);
      if(StringFind(name, ACC_OBJECT_PREFIX) == 0)
        {
         ObjectDelete(chartID, name);
        }
     }
  }

bool LoadAccumulationZones(long chartID)
  {
   if(chartID == 0) return false;

   ClearAccumulationZones(chartID);

   string path = InpAccumulationCsvPath;
   string fileName = path;
   int lastSep = -1;
   for(int i = StringLen(path) - 1; i >= 0; i--)
     {
      string ch = StringSubstr(path, i, 1);
      if(ch == "\\" || ch == "/")
        {
         lastSep = i;
         break;
        }
     }
   if(lastSep >= 0) fileName = StringSubstr(path, lastSep + 1);

   ResetLastError();
   int handle = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   int err1 = GetLastError();
   int err2 = 0;

   if(handle == INVALID_HANDLE_VALUE)
     {
      ResetLastError();
      handle = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
      err2 = GetLastError();
     }

   if(handle == INVALID_HANDLE_VALUE)
     {
      string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + fileName;
      string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + fileName;
      Print("ACC CSV open failed. Input=", path, " | err1=", err1, " err2=", err2, " | Common=", commonPath, " | Terminal=", terminalPath);
      return false;
     }

   string sym = ChartSymbol(chartID);
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   if(StringLen(sym) == 0) sym = FullSymbolName();
   if(tf <= 0) tf = InpFullTimeframe;

   int loaded = 0;
   int skipped = 0;
   int scanned = 0;

   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) == 0) continue;

      StringReplace(line, "\r", "");
      StringReplace(line, "\n", "");
      if(StringLen(line) == 0) continue;

      scanned++;
      string parts[];
      int n = StringSplit(line, ',', parts);
      if(n < 2)
        {
         skipped++;
         continue;
        }

      string firstLower = parts[0];
      StringToLower(firstLower);
      if(StringFind(firstLower, "zone_id") >= 0 || StringFind(firstLower, "window_start") >= 0)
        {
         continue;
        }

      datetime startTime = 0;
      datetime endTime = 0;
      double zoneLow = 0.0;
      double zoneHigh = 0.0;
      int passFlag = 1;

      if(n >= 13)
        {
         startTime = StringToTime(parts[3]);
         endTime = StringToTime(parts[4]);
         zoneLow = StringToDouble(parts[5]);
         zoneHigh = StringToDouble(parts[6]);
         passFlag = (int)StringToInteger(parts[10]);
        }
      else if(n >= 7)
        {
         startTime = StringToTime(parts[0]);
         endTime = StringToTime(parts[1]);
         passFlag = (int)StringToInteger(parts[5]);
        }
      else
        {
         startTime = StringToTime(parts[0]);
         endTime = StringToTime(parts[1]);
        }

      if(passFlag <= 0 || startTime <= 0 || endTime <= 0 || endTime <= startTime)
        {
         skipped++;
         continue;
        }

      if(zoneHigh <= zoneLow)
        {
         if(!ResolveZonePriceRange(sym, tf, startTime, endTime, zoneLow, zoneHigh))
           {
            skipped++;
            continue;
           }
        }

      string name = ACC_OBJECT_PREFIX + IntegerToString(loaded + 1);
      if(ObjectFind(chartID, name) >= 0) ObjectDelete(chartID, name);

      if(!ObjectCreate(chartID, name, OBJ_RECTANGLE, 0, startTime, zoneHigh, endTime, zoneLow))
        {
         skipped++;
         continue;
        }

      ObjectSetInteger(chartID, name, OBJPROP_COLOR, InpAccumulationZoneColor);
      ObjectSetInteger(chartID, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chartID, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(chartID, name, OBJPROP_FILL, true);
      ObjectSetInteger(chartID, name, OBJPROP_BACK, InpAccumulationDrawInBackground);
      ObjectSetInteger(chartID, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartID, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(chartID, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(chartID, name, OBJPROP_ZORDER, 10);

      loaded++;
      if(loaded >= InpAccumulationMaxZones) break;
     }

   FileClose(handle);
   ChartRedraw(chartID);

   Print("ACC labels loaded: ", loaded, " | scanned=", scanned, " | skipped=", skipped, " | chart=", chartID, " | file=", fileName);
   return (loaded > 0);
  }

string TimeframeName(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1: return "M1";
      case PERIOD_M2: return "M2";
      case PERIOD_M3: return "M3";
      case PERIOD_M4: return "M4";
      case PERIOD_M5: return "M5";
      case PERIOD_M6: return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H2: return "H2";
      case PERIOD_H3: return "H3";
      case PERIOD_H4: return "H4";
      case PERIOD_H6: return "H6";
      case PERIOD_H8: return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
     }
   return IntegerToString((int)tf);
  }

string FullViewportStateKey(long chartID, string field)
  {
   return GV_FULL_VIEWPORT_PREFIX + IntegerToString(chartID) + "_" + field;
  }

void ClearFullViewportState(long chartID)
  {
   GlobalVariableDel(FullViewportStateKey(chartID, "valid"));
   GlobalVariableDel(FullViewportStateKey(chartID, "year"));
   GlobalVariableDel(FullViewportStateKey(chartID, "period"));
   GlobalVariableDel(FullViewportStateKey(chartID, "time"));
   GlobalVariableDel(FullViewportStateKey(chartID, "x"));
   GlobalVariableDel(FullViewportStateKey(chartID, "captured"));
   GlobalVariableDel(FullViewportStateKey(chartID, "autoscroll"));
  }

bool CaptureFullChartViewport(long chartID)
  {
   if(chartID == 0) return false;

   string symbol = ChartSymbol(chartID);
   int year = ExtractFullSymbolYear(symbol);
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeight = (int)ChartGetInteger(chartID, CHART_HEIGHT_IN_PIXELS, 0);
   if(year <= 0 || symbol != BuildFullSymbolForYear(year) ||
      PeriodSeconds(timeframe) <= 0 || chartWidth <= 0 || chartHeight <= 0)
     {
      ClearFullViewportState(chartID);
      GlobalVariablesFlush();
      Print("[EA|FULL|VIEW] WARN viewport capture unavailable | chart=", chartID,
            " | symbol=", symbol, " | period=", TimeframeName(timeframe),
            " | size=", chartWidth, "x", chartHeight,
            " | archive_touched=0");
      return false;
     }

   int anchorX = chartWidth / 2;
   int anchorY = chartHeight / 2;
   int subWindow = 0;
   datetime anchorTime = 0;
   double anchorPrice = 0.0;
   ResetLastError();
   bool converted = ChartXYToTimePrice(chartID, anchorX, anchorY, subWindow,
                                       anchorTime, anchorPrice);
   int conversionError = converted ? 0 : GetLastError();
   if(!converted || anchorTime <= 0)
     {
      int firstVisible = (int)ChartGetInteger(chartID, CHART_FIRST_VISIBLE_BAR, 0);
      int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
      if(firstVisible >= 0 && visibleBars > 0)
        {
         int rightVisible = firstVisible - visibleBars + 1;
         if(rightVisible < 0) rightVisible = 0;
         int centerShift = rightVisible + visibleBars / 2;
         anchorTime = iTime(symbol, timeframe, centerShift);
        }
     }
   if(anchorTime <= 0)
     {
      int captureError = GetLastError();
      ClearFullViewportState(chartID);
      GlobalVariablesFlush();
      Print("[EA|FULL|VIEW] ERROR viewport capture failed | chart=", chartID,
            " | symbol=", symbol, " | period=", TimeframeName(timeframe),
            " | conversion_err=", conversionError,
            " | err=", captureError, " | archive_touched=0");
      return false;
     }

   bool autoScroll = (bool)ChartGetInteger(chartID, CHART_AUTOSCROLL, 0);
   ClearFullViewportState(chartID);
   ResetLastError();
   bool stored =
      GlobalVariableSet(FullViewportStateKey(chartID, "year"), (double)year) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "period"), (double)((int)timeframe)) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "time"), (double)anchorTime) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "x"), (double)anchorX) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "captured"), (double)TimeLocal()) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "autoscroll"), autoScroll ? 1.0 : 0.0) > 0 &&
      GlobalVariableSet(FullViewportStateKey(chartID, "valid"), 1.0) > 0;
   int storageError = stored ? 0 : GetLastError();
   GlobalVariablesFlush();
   if(!stored)
     {
      ClearFullViewportState(chartID);
      GlobalVariablesFlush();
      Print("[EA|FULL|VIEW] ERROR viewport snapshot store failed | chart=", chartID,
            " | symbol=", symbol, " | period=", TimeframeName(timeframe),
            " | err=", storageError, " | archive_touched=0");
      return false;
     }

   Print("[EA|FULL|VIEW] INFO viewport captured | chart=", chartID,
         " | symbol=", symbol, " | period=", TimeframeName(timeframe),
         " | anchor=", TimeToString(anchorTime, TIME_DATE|TIME_MINUTES),
         " | anchor_x=", anchorX, " | autoscroll=", (int)autoScroll,
         " | archive_touched=0");
   return true;
  }

bool RestoreFullChartViewport(long chartID)
  {
   if(chartID == 0) return false;

   string validKey = FullViewportStateKey(chartID, "valid");
   if(!GlobalVariableCheck(validKey)) return false;
   bool complete =
      GlobalVariableCheck(FullViewportStateKey(chartID, "year")) &&
      GlobalVariableCheck(FullViewportStateKey(chartID, "period")) &&
      GlobalVariableCheck(FullViewportStateKey(chartID, "time")) &&
      GlobalVariableCheck(FullViewportStateKey(chartID, "x")) &&
      GlobalVariableCheck(FullViewportStateKey(chartID, "captured")) &&
      GlobalVariableCheck(FullViewportStateKey(chartID, "autoscroll"));
   if(!complete)
     {
      ClearFullViewportState(chartID);
      GlobalVariablesFlush();
      Print("[EA|FULL|VIEW] WARN incomplete viewport snapshot discarded | chart=",
            chartID, " | archive_touched=0");
      return false;
     }

   int savedYear = (int)GlobalVariableGet(FullViewportStateKey(chartID, "year"));
   ENUM_TIMEFRAMES savedPeriod = (ENUM_TIMEFRAMES)((int)GlobalVariableGet(
                                      FullViewportStateKey(chartID, "period")));
   datetime anchorTime = (datetime)((long)GlobalVariableGet(
                                      FullViewportStateKey(chartID, "time")));
   int desiredX = (int)GlobalVariableGet(FullViewportStateKey(chartID, "x"));
   datetime capturedAt = (datetime)((long)GlobalVariableGet(
                                      FullViewportStateKey(chartID, "captured")));
   bool savedAutoScroll = (GlobalVariableGet(
                              FullViewportStateKey(chartID, "autoscroll")) > 0.5);
   ClearFullViewportState(chartID);
   GlobalVariablesFlush();

   string symbol = ChartSymbol(chartID);
   int currentYear = ExtractFullSymbolYear(symbol);
   ENUM_TIMEFRAMES currentPeriod = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   long ageSeconds = (long)TimeLocal() - (long)capturedAt;
   if(savedYear <= 0 || currentYear != savedYear ||
      symbol != BuildFullSymbolForYear(savedYear) ||
      PeriodSeconds(savedPeriod) <= 0 || PeriodSeconds(currentPeriod) <= 0 ||
      savedPeriod == currentPeriod || anchorTime <= 0 ||
      ageSeconds < 0 || ageSeconds > FULL_VIEWPORT_RESTORE_MAX_AGE_SECONDS)
     {
      Print("[EA|FULL|VIEW] INFO viewport restore skipped | chart=", chartID,
            " | saved_year=", savedYear, " | current_year=", currentYear,
            " | saved_period=", TimeframeName(savedPeriod),
            " | current_period=", TimeframeName(currentPeriod),
            " | age_seconds=", ageSeconds,
            " | archive_touched=0");
      return false;
     }

   int targetShift = iBarShift(symbol, currentPeriod, anchorTime, false);
   int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
   int chartWidth = (int)ChartGetInteger(chartID, CHART_WIDTH_IN_PIXELS, 0);
   if(targetShift < 0 || visibleBars <= 0 || chartWidth <= 0)
     {
      Print("[EA|FULL|VIEW] ERROR viewport restore target unavailable | chart=",
            chartID, " | symbol=", symbol,
            " | period=", TimeframeName(currentPeriod),
            " | anchor=", TimeToString(anchorTime, TIME_DATE|TIME_MINUTES),
            " | shift=", targetShift, " | visible_bars=", visibleBars,
            " | width=", chartWidth, " | err=", GetLastError(),
            " | archive_touched=0");
      return false;
     }
   if(desiredX < 0 || desiredX >= chartWidth) desiredX = chartWidth / 2;

   ResetLastError();
   bool autoScrollDisabled = ChartSetInteger(chartID, CHART_AUTOSCROLL, false);
   int autoScrollError = autoScrollDisabled ? 0 : GetLastError();
   int position = -targetShift + MathMax(10, visibleBars / 2);
   ResetLastError();
   bool navigated = ChartNavigate(chartID, CHART_END, position);
   int navigationError = navigated ? 0 : GetLastError();
   int actualX = -1;
   int pixelError = 0;
   int correctionPasses = 0;
   bool centerVerified = false;
   if(navigated)
     {
      ChartRedraw(chartID);
      for(int pass = 0; pass < FULL_VIEWPORT_RESTORE_MAX_PASSES; pass++)
        {
         double priceMin = ChartGetDouble(chartID, CHART_PRICE_MIN, 0);
         double priceMax = ChartGetDouble(chartID, CHART_PRICE_MAX, 0);
         double referencePrice = (priceMin + priceMax) / 2.0;
         int anchorY = 0;
         ResetLastError();
         bool anchorOK = ChartTimePriceToXY(chartID, 0, anchorTime,
                                            referencePrice, actualX, anchorY);
         if(!anchorOK)
           {
            navigationError = GetLastError();
            Print("[EA|FULL|VIEW] WARN viewport pixel measurement failed | chart=",
                  chartID, " | pass=", pass, " | err=", navigationError,
                  " | archive_touched=0");
            break;
           }

         pixelError = actualX - desiredX;
         int targetBarX = 0;
         int targetBarY = 0;
         int adjacentBarX = 0;
         int adjacentBarY = 0;
         datetime targetBarTime = iTime(symbol, currentPeriod, targetShift);
         datetime adjacentBarTime = targetShift > 0 ?
                                    iTime(symbol, currentPeriod, targetShift - 1) :
                                    iTime(symbol, currentPeriod, targetShift + 1);
         double pixelsPerBar = 0.0;
         if(targetBarTime > 0 && adjacentBarTime > 0 &&
            ChartTimePriceToXY(chartID, 0, targetBarTime, referencePrice,
                               targetBarX, targetBarY) &&
            ChartTimePriceToXY(chartID, 0, adjacentBarTime, referencePrice,
                               adjacentBarX, adjacentBarY))
            pixelsPerBar = (double)MathAbs(adjacentBarX - targetBarX);
         if(pixelsPerBar <= 0.0)
            pixelsPerBar = (double)chartWidth / (double)visibleBars;
         int tolerancePx = MathMax(2, (int)MathCeil(pixelsPerBar / 2.0));
         if(MathAbs(pixelError) <= tolerancePx)
           {
            centerVerified = true;
            break;
           }

         int correctionBars = (int)MathRound((double)pixelError / pixelsPerBar);
         if(correctionBars == 0) break;
         position += correctionBars;
         ResetLastError();
         bool corrected = ChartNavigate(chartID, CHART_END, position);
         if(!corrected)
           {
            navigationError = GetLastError();
            Print("[EA|FULL|VIEW] WARN viewport pixel correction failed | chart=",
                  chartID, " | pass=", pass,
                  " | correction_bars=", correctionBars,
                  " | position=", position, " | err=", navigationError,
                  " | archive_touched=0");
            break;
           }
         correctionPasses++;
         ChartRedraw(chartID);
        }
     }

   if(savedAutoScroll)
     {
      ResetLastError();
      if(!ChartSetInteger(chartID, CHART_AUTOSCROLL, true))
         Print("[EA|FULL|VIEW] WARN autoscroll restore failed | chart=", chartID,
               " | err=", GetLastError(), " | archive_touched=0");
     }
   ChartRedraw(chartID);
   Print("[EA|FULL|VIEW] ", navigated ? "INFO" : "ERROR",
         " viewport restore result | chart=", chartID,
         " | symbol=", symbol,
         " | from_period=", TimeframeName(savedPeriod),
         " | to_period=", TimeframeName(currentPeriod),
         " | anchor=", TimeToString(anchorTime, TIME_DATE|TIME_MINUTES),
         " | desired_x=", desiredX, " | actual_x=", actualX,
         " | pixel_error=", pixelError,
         " | correction_passes=", correctionPasses,
         " | center_verified=", (int)centerVerified,
         " | navigated=", (int)navigated,
         " | autoscroll_disabled=", (int)autoScrollDisabled,
         " | autoscroll_err=", autoScrollError,
         " | err=", navigationError, " | archive_touched=0");
   return navigated;
  }

string InferManualLabel(string objName, color objColor)
  {
   // Single-label annotation mode: every manual rectangle means a standard opportunity.
   return "Y";
  }

bool ExportManualRectangles(long chartID)
  {
   if(chartID == 0) return false;

   string path = InpManualBoxesCsvPath;
   string fileName = path;
   int lastSep = -1;
   for(int i = StringLen(path) - 1; i >= 0; i--)
     {
      string ch = StringSubstr(path, i, 1);
      if(ch == "\\" || ch == "/")
        {
         lastSep = i;
         break;
        }
     }
   if(lastSep >= 0) fileName = StringSubstr(path, lastSep + 1);

   int handle = INVALID_HANDLE_VALUE;
   int err1 = 0;
   int err2 = 0;

   ResetLastError();
   if(lastSep < 0)
      handle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   else
      handle = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI);
   err1 = GetLastError();

   if(handle == INVALID_HANDLE_VALUE)
     {
      ResetLastError();
      if(lastSep < 0)
         handle = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI);
      else
         handle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      err2 = GetLastError();
     }

   if(handle == INVALID_HANDLE_VALUE)
     {
      string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + fileName;
      string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + fileName;
      Print("MANUAL EXPORT failed. Input=", path, " | err1=", err1, " err2=", err2, " | Common=", commonPath, " | Terminal=", terminalPath);
      return false;
     }

   string sym = ChartSymbol(chartID);
   if(StringLen(sym) == 0) sym = FullSymbolName();
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   string tfName = TimeframeName(tf);

   FileWriteString(handle, "box_id,label,object_name,symbol,timeframe,time_start,time_end,price_low,price_high,color\n");

   int total = ObjectsTotal(chartID, -1, -1);
   int exported = 0;
   int skipped = 0;

   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(chartID, i, -1, -1);
      if(StringFind(name, ACC_OBJECT_PREFIX) == 0)
        {
         skipped++;
         continue;
        }

      if((int)ObjectGetInteger(chartID, name, OBJPROP_TYPE) != OBJ_RECTANGLE)
         continue;

      datetime t1 = (datetime)ObjectGetInteger(chartID, name, OBJPROP_TIME, 0);
      datetime t2 = (datetime)ObjectGetInteger(chartID, name, OBJPROP_TIME, 1);
      double p1 = ObjectGetDouble(chartID, name, OBJPROP_PRICE, 0);
      double p2 = ObjectGetDouble(chartID, name, OBJPROP_PRICE, 1);
      if(t1 <= 0 || t2 <= 0)
        {
         skipped++;
         continue;
        }

      datetime startTime = (t1 <= t2) ? t1 : t2;
      datetime endTime = (t1 <= t2) ? t2 : t1;
      if(endTime <= startTime)
        {
         skipped++;
         continue;
        }

      double low = MathMin(p1, p2);
      double high = MathMax(p1, p2);
      if(high <= low)
        {
         skipped++;
         continue;
        }

      color objColor = (color)ObjectGetInteger(chartID, name, OBJPROP_COLOR);
      string label = InferManualLabel(name, objColor);
      string safeName = name;
      StringReplace(safeName, ",", "_");

      string line = IntegerToString(exported + 1) + "," + label + "," + safeName + "," + sym + "," + tfName + "," +
                    TimeToString(startTime, TIME_DATE|TIME_MINUTES) + "," + TimeToString(endTime, TIME_DATE|TIME_MINUTES) + "," +
                    DoubleToString(low, _Digits) + "," + DoubleToString(high, _Digits) + "," + IntegerToString((int)objColor) + "\n";
      FileWriteString(handle, line);
      exported++;
     }

   FileClose(handle);
   Print("MANUAL boxes exported: ", exported, " | skipped=", skipped, " | chart=", chartID, " | file=", fileName);
   return (exported > 0);
  }

void CreateManualBoxAtViewport(long chartID)
  {
   if(chartID == 0) return;

   string sym = ChartSymbol(chartID);
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
   if(StringLen(sym) == 0) sym = FullSymbolName();
   if(tf <= 0) tf = InpFullTimeframe;

   int firstVisible = (int)ChartGetInteger(chartID, CHART_FIRST_VISIBLE_BAR, 0);
   int visibleBars = (int)ChartGetInteger(chartID, CHART_VISIBLE_BARS, 0);
   if(firstVisible < 0) firstVisible = 200;
   if(visibleBars <= 0) visibleBars = 200;

   int rightVisible = firstVisible - visibleBars + 1;
   if(rightVisible < 0) rightVisible = 0;
   int centerShift = rightVisible + visibleBars / 2;

   int barsPerDay = MathMax(1, (int)(86400 / PeriodSeconds(tf)));
   int halfWindow = MathMax(8, (barsPerDay * 3) / 4); // ~1.5 day default span
   int startShift = centerShift + halfWindow;
   int endShift = MathMax(0, centerShift - halfWindow);

   datetime tStart = iTime(sym, tf, startShift);
   datetime tEnd = iTime(sym, tf, endShift);
   if(tStart <= 0 || tEnd <= 0 || tEnd <= tStart)
     {
      int fallback = barsPerDay;
      tStart = iTime(sym, tf, fallback * 2);
      tEnd = iTime(sym, tf, fallback);
      if(tStart <= 0 || tEnd <= 0 || tEnd <= tStart)
         return;
     }

   double pMin = ChartGetDouble(chartID, CHART_PRICE_MIN, 0);
   double pMax = ChartGetDouble(chartID, CHART_PRICE_MAX, 0);
   if(pMax <= pMin)
     {
      pMin = iLow(sym, tf, centerShift);
      pMax = iHigh(sym, tf, centerShift);
      if(pMax <= pMin) return;
     }

   double span = pMax - pMin;
   double low = pMin + span * 0.35;
   double high = pMin + span * 0.65;

   string name = "MANUAL_BOX_" + IntegerToString((int)GetTickCount());
   if(ObjectFind(chartID, name) >= 0)
      name = name + "_" + IntegerToString((int)MathRand());

   if(!ObjectCreate(chartID, name, OBJ_RECTANGLE, 0, tStart, high, tEnd, low))
     {
      Print("MANUAL box create failed | err=", GetLastError());
      return;
     }

   ObjectSetInteger(chartID, name, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(chartID, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(chartID, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chartID, name, OBJPROP_FILL, false);
   ObjectSetInteger(chartID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTED, true);
   ObjectSetInteger(chartID, name, OBJPROP_HIDDEN, false);
   Print("MANUAL box created: ", name);
  }

int FillManualRectangles(long chartID)
  {
   if(chartID == 0) return 0;

   int total = ObjectsTotal(chartID, -1, -1);
   int filled = 0;
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(chartID, i, -1, -1);
      if(StringFind(name, ACC_OBJECT_PREFIX) == 0)
         continue;

      if((int)ObjectGetInteger(chartID, name, OBJPROP_TYPE) != OBJ_RECTANGLE)
         continue;

      ObjectSetInteger(chartID, name, OBJPROP_FILL, true);
      ObjectSetInteger(chartID, name, OBJPROP_BACK, false);
      ObjectSetInteger(chartID, name, OBJPROP_COLOR, C'255,90,90');
      ObjectSetInteger(chartID, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chartID, name, OBJPROP_WIDTH, 1);
      filled++;
     }
   return filled;
  }

void CreateControlPanel()
  {
   // Try to load saved position from Terminal Global Variables
   if(GlobalVariableCheck("EnergyUI_X")) ui_base_x = (int)GlobalVariableGet("EnergyUI_X");
   if(GlobalVariableCheck("EnergyUI_Y")) ui_base_y = (int)GlobalVariableGet("EnergyUI_Y");

   Print("馃帹 Creating UI at X=", ui_base_x, " Y=", ui_base_y);

   // 1. Background Panel (Standard)
   CreateRectLabel("ui_bg", ui_base_x, ui_base_y, 260, 90, C'50,50,50', BORDER_FLAT);

   // 2. Play/Pause/Start Button (Consolidated)
   // Initial State: PAUSED or START depending on connection
   CreateButton("btn_play_pause", ui_base_x + 10, ui_base_y + 45, 70, 30, "START", clrGreen);


   // Full-history loader (runs in this EA; updates the FULL chart if it exists)
   CreateButton(OBJ_BTN_FULL_LOAD_MAIN, ui_base_x + 10, ui_base_y + 20, 70, 18, "FULL LOAD", clrDarkSlateGray);
   // 3. Slider Track (Bottom Right) - Shortened
   // x=90, width=100 (end at 190)
   CreateRectLabel("slider_track", ui_base_x + 90, ui_base_y + 58, 100, 4, clrGray, BORDER_SUNKEN);

   // 4. Slider Knob (Default Position)
   CreateButton("slider_knob", ui_base_x + 90, ui_base_y + 50, 20, 20, "", clrWhite); // Init at start

   // 5. Speed Label
   CreateLabel("lbl_speed", ui_base_x + 90, ui_base_y + 35, "Speed: 3.0s", clrWhite, 10);

   // 6. Batch Controls
   // Label: at x+170 (above right part of slider)
   CreateLabel("lbl_batch", ui_base_x + 170, ui_base_y + 35, "(x1)", clrYellow, 10);

   // Buttons: at x+200, size 15x20
   CreateButton("btn_batch_down", ui_base_x + 200, ui_base_y + 50, 15, 20, "-", C'80,80,80');
   CreateButton("btn_batch_up",   ui_base_x + 215, ui_base_y + 50, 15, 20, "+", C'80,80,80');

   // --- Restore Speed Preference ---
   if(GlobalVariableCheck("Energy_Speed"))
     {
      currentSpeed = GlobalVariableGet("Energy_Speed");
      Print("馃捑 Restored Speed Preference: ", currentSpeed, "s");

      // Calculate knob position from speed (Track 100, Knob 20)
      double pct = (currentSpeed - 0.5) / 2.5;
      if(pct < 0) pct = 0;
      if(pct > 1) pct = 1;

      // Knob X = base + 90 + (pct * 80)
      int knob_x = ui_base_x + 90 + (int)(pct * 80.0);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);

      UpdateSpeedLabel(currentSpeed);
     }

   // --- Restore Batch Preference ---
   if(GlobalVariableCheck("Energy_BatchSize"))
   {
      batchSize = (int)GlobalVariableGet("Energy_BatchSize");
      if(batchSize < 1) batchSize = 1;
      if(batchSize > 10) batchSize = 10;
      Print("馃捑 Restored Batch Preference: x", batchSize);
      UpdateBatchLabel();
   }

   UpdateUIState();
   ChartRedraw(0);
  }

void UpdateUIState()
{
   bool connected = (hPipe != INVALID_HANDLE_VALUE);


   // FULL LOAD button is always visible (online/offline)
   ObjectSetInteger(0, OBJ_BTN_FULL_LOAD_MAIN, OBJPROP_XDISTANCE, ui_base_x + 10);
   ObjectSetInteger(0, OBJ_BTN_FULL_LOAD_MAIN, OBJPROP_YDISTANCE, ui_base_y + 20);
   if(connected)
   {
      // Show Controls
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_XDISTANCE, ui_base_x + 10);
      ObjectSetInteger(0, "slider_track", OBJPROP_XDISTANCE, ui_base_x + 90);
      ObjectSetInteger(0, "lbl_speed", OBJPROP_XDISTANCE, ui_base_x + 90);

      // Batch Controls
      ObjectSetInteger(0, "lbl_batch", OBJPROP_XDISTANCE, ui_base_x + 170);
      ObjectSetInteger(0, "lbl_batch", OBJPROP_YDISTANCE, ui_base_y + 35);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_XDISTANCE, ui_base_x + 200);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_YDISTANCE, ui_base_y + 50);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_XDISTANCE, ui_base_x + 215);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_YDISTANCE, ui_base_y + 50);

      // Always Force-Update Knob Position based on current speed
      // This ensures it appears correctly after initialization, timeframe change, or reconnect
      double pct = (currentSpeed - 0.5) / 2.5;
      if(pct < 0) pct = 0;
      if(pct > 1) pct = 1;

      // Track 100, Knob 20
      int knob_x = ui_base_x + 90 + (int)(pct * 80.0);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, knob_x);

      // Restore Button State
       if(isPaused)
       {
          // If we have history (GlobalVariable), it means we are RESUMING
          if(GlobalVariableCheck("Energy_IsPaused"))
          {
             ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "RESUME");
          }
          else
          {
             ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "START");
          }
          ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGreen);
       }
       else
       {
          ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "PAUSE");
          ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrRed);
       }
   }
   else
   {
      // Disconnected / Offline State
      // Show "START" button (which acts as Connect/Launch)
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_XDISTANCE, ui_base_x + 10);
      ObjectSetString(0, "btn_play_pause", OBJPROP_TEXT, "START"); // Re-Launch
      ObjectSetInteger(0, "btn_play_pause", OBJPROP_BGCOLOR, clrGray); // Gray to indicate offline/ready

      // Hide Slider when offline
      ObjectSetInteger(0, "slider_track", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "slider_knob", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "lbl_speed", OBJPROP_XDISTANCE, -1000);

      // Hide Batch when offline
      ObjectSetInteger(0, "lbl_batch", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "btn_batch_down", OBJPROP_XDISTANCE, -1000);
      ObjectSetInteger(0, "btn_batch_up", OBJPROP_XDISTANCE, -1000);
   }
   ChartRedraw(0);
}

void ShiftControlPanel(int dx, int dy)
  {
   ShiftObj("ui_bg", dx, dy);

   // Removed btn_launch

   ShiftObj("btn_play_pause", dx, dy);
   ShiftObj(OBJ_BTN_FULL_LOAD_MAIN, dx, dy);
   ShiftObj("slider_track", dx, dy);
   ShiftObj("slider_knob", dx, dy);
   ShiftObj("lbl_speed", dx, dy);
  }

void ShiftObj(string name, int dx, int dy)
  {
   long x = ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
   long y = ObjectGetInteger(0, name, OBJPROP_YDISTANCE);

   // If off-screen, keep it off-screen but update "virtual" position?
   // No, if it's -1000, adding dx doesn't matter much.
   // But when we Restore in UpdateUIState, we use ui_base_x.
   // So UpdateUIState relies on ui_base_x being correct.
   // ShiftControlPanel updates ui_base_x in OnChartEvent.
   // So we just need to shift the objects that are currently visible.
   // Or just shift everything.

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + dx);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + dy);
  }

void DestroyControlPanel()
  {
   ObjectDelete(0, "ui_bg");
   // ObjectDelete(0, "btn_launch"); // REMOVED
   ObjectDelete(0, "btn_play_pause");
   ObjectDelete(0, OBJ_BTN_FULL_LOAD_MAIN);
   ObjectDelete(0, "slider_track");
   ObjectDelete(0, "slider_knob");
   ObjectDelete(0, "lbl_speed");
   ObjectDelete(0, "lbl_batch");
   ObjectDelete(0, "btn_batch_down");
   ObjectDelete(0, "btn_batch_up");

   // Cleanup legacy labels
   ObjectDelete(0, "PythonMsg");

   ChartRedraw(0);
  }

void UpdateSpeedLabel(double speed)
  {
   string text = StringFormat("Speed: %.1fs", speed);
   ObjectSetString(0, "lbl_speed", OBJPROP_TEXT, text);
   Print("UI Event: Speed Changed to ", text);
  }
void UpdateBatchLabel()
  {
   string text = StringFormat("(x%d)", batchSize);
   ObjectSetString(0, "lbl_batch", OBJPROP_TEXT, text);
   Print("UI Event: Batch Changed to ", text);
  }

void ClickFlash(string name)
  {
   if(ObjectFind(0, name) < 0) return;

   ObjectSetInteger(0, name, OBJPROP_STATE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ChartRedraw(0);
   Sleep(70);

   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ChartRedraw(0);
  }

// --- UI Helpers ---
void CreateButton(string name, int x, int y, int w, int h, string text, color bg)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
  }

void CreateEdit(string name, int x, int y, int w, int h, string text)
  {
   if(ObjectFind(0, name) < 0)
     {
      ResetLastError();
      if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
        {
         Print("[EA|FULL|CASE] ERROR direct search input creation failed | object=",
               name, " | err=", GetLastError());
         return;
        }
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Microsoft YaHei");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
  }

void CreateRectLabel(string name, int x, int y, int w, int h, color bg, int border)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
  }

void CreateLabel(string name, int x, int y, string text, color col, int size)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
    if(isFullChartInstance)
      {
       if(fullControlPanelRaisePending)
         {
          fullControlPanelRaisePending = false;
          RaiseFullControlPanelToFront(ChartID());
         }
       RefreshOpportunityStructureSaveFeedback();
       RefreshOpportunityCaseFeedback();
       return;
     }

   if(hPipe != INVALID_HANDLE_VALUE)
     {
      ReadPipeCommand();
     }
   else
     {
      ConnectPipe();
     }
  }

// --- Custom Symbol Logic ---

void CreateCustomSymbol()
  {
   EnsureCustomSymbol(InpSymbolName);
  }

bool EnsureCustomSymbol(string symbol)
  {
   if(SymbolSelect(symbol, true))
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | EnsureCustomSymbol exists | symbol=", symbol);
      return true;
     }

   if(!SymbolSelect(InpBaseSymbol, true))
     {
      Print("Error: Base symbol ", InpBaseSymbol, " not found!");
      if(GV_DEBUG_FULL) Print("FULL-DBG | Base symbol select failed | err=", GetLastError());
      return false;
     }

   if(!CustomSymbolCreate(symbol, "Custom", InpBaseSymbol))
     {
      Print("Error creating custom symbol: ", GetLastError());
      return false;
     }

   // Insert a dummy bar so the chart is valid
   MqlRates rates[];
   ArrayResize(rates, 1);
   rates[0].time = D'2024.01.01 00:00';
   rates[0].open = 1.10000;
   rates[0].high = 1.10050;
   rates[0].low = 1.09950;
   rates[0].close = 1.10000;
   rates[0].tick_volume = 1;
   rates[0].spread = 10;
   rates[0].real_volume = 0;

   bool cr_ok = CustomRatesReplace(symbol, 0, D'2099.12.31', rates);
   if(!cr_ok) Print("FULL-DBG | CustomRatesReplace failed | err=", GetLastError());
   else if(GV_DEBUG_FULL) Print("FULL-DBG | Dummy bar inserted | symbol=", symbol);
   SymbolSelect(symbol, true);
   return true;
  }
string FullSymbolName()
  {
   if(StringLen(fullRuntimeSymbol) > 0) return fullRuntimeSymbol;
   return InpFullSymbolName;
  }

int ExtractFullSymbolYear(string symbol)
  {
   int suffixPos = StringFind(InpFullSymbolName, "_FULL");
   if(suffixPos < 4) return 0;
   string prefix = StringSubstr(InpFullSymbolName, 0, suffixPos - 4);
   string suffix = StringSubstr(InpFullSymbolName, suffixPos);
   int yearPos = StringLen(prefix);
   if(StringLen(symbol) != yearPos + 4 + StringLen(suffix)) return 0;
   if(StringSubstr(symbol, 0, yearPos) != prefix ||
      StringSubstr(symbol, yearPos + 4) != suffix) return 0;
   string yearText = StringSubstr(symbol, yearPos, 4);
   for(int i = 0; i < 4; i++)
     {
      ushort character = StringGetCharacter(yearText, i);
      if(character < '0' || character > '9') return 0;
     }
   int year = (int)StringToInteger(yearText);
   return (year >= 1900 && year <= 2100) ? year : 0;
  }

string BuildFullSymbolForYear(int year)
  {
   int suffixPos = StringFind(InpFullSymbolName, "_FULL");
   if(suffixPos < 4) return InpFullSymbolName;
   string prefix = StringSubstr(InpFullSymbolName, 0, suffixPos - 4);
   string suffix = StringSubstr(InpFullSymbolName, suffixPos);
   return prefix + IntegerToString(year) + suffix;
  }

bool IsManagedFullSymbol(string symbol)
  {
   return (ExtractFullSymbolYear(symbol) > 0);
  }

void ConfigureFullRuntime(int year)
  {
   if(year <= 0) year = InpFullStartYear;
   fullWorkYear = year;
   fullRuntimeSymbol = BuildFullSymbolForYear(year);
   GV_FULL_LOADED = "Energy_FullLoaded_" + fullRuntimeSymbol;
  }

int ResolvePersistedFullWorkYear(int chartYear)
  {
   int startYear = InpFullStartYear;
   int endYear = InpFullEndYear;
   if(startYear > endYear)
     {
      int swapYear = startYear;
      startYear = endYear;
      endYear = swapYear;
     }
   if(opportunitySessionWorkYear >= startYear &&
      opportunitySessionWorkYear <= endYear)
      return opportunitySessionWorkYear;
   if(GlobalVariableCheck(GV_FULL_WORK_YEAR))
     {
      int storedYear = (int)GlobalVariableGet(GV_FULL_WORK_YEAR);
      if(storedYear >= startYear && storedYear <= endYear) return storedYear;
      Print("[EA|FULL|YEAR] WARN persisted year ignored | stored=", storedYear,
            " | allowed=", startYear, "..", endYear,
            " | err=0 | archive_touched=0");
     }
   if(chartYear >= startYear && chartYear <= endYear) return chartYear;
   return startYear;
  }

bool EnsureFullYearHistory(int year)
  {
   int startYear = InpFullStartYear;
   int endYear = InpFullEndYear;
   if(startYear > endYear)
     {
      int swapYear = startYear;
      startYear = endYear;
      endYear = swapYear;
     }
   if(year < startYear || year > endYear)
     {
      Print("[EA|FULL|YEAR] ERROR history rejected | year=", year,
            " | allowed=", startYear, "..", endYear,
            " | err=0 | archive_touched=0");
      return false;
     }

   ConfigureFullRuntime(year);
   string csvPath = BuildYearCsvPath(InpFullCsvPath, year);
   string openedName = "";
   int csvHandle = OpenFullCsvFile(csvPath, openedName);
   if(csvHandle == INVALID_HANDLE_VALUE)
     {
      Print("[EA|FULL|YEAR] ERROR CSV unavailable | year=", year,
            " | path=", csvPath, " | symbol=", FullSymbolName(),
            " | err=", GetLastError(), " | archive_touched=0");
      return false;
     }
   long csvBytes = (long)FileSize(csvHandle);
   FileClose(csvHandle);

   if(!EnsureFullSymbol())
     {
      Print("[EA|FULL|YEAR] ERROR custom symbol unavailable | year=", year,
            " | symbol=", FullSymbolName(), " | err=", GetLastError(),
            " | archive_touched=0");
      return false;
     }
   int existingBars = Bars(FullSymbolName(), PERIOD_M1);
   if(!InpFullForceReload && existingBars > 1000)
     {
      GlobalVariableSet(GV_FULL_LOADED, TimeCurrent());
      GlobalVariablesFlush();
      Print("[EA|FULL|YEAR] INFO history ready | year=", year,
            " | symbol=", FullSymbolName(), " | csv=", openedName,
            " | csv_bytes=", csvBytes, " | m1_bars=", existingBars,
            " | loaded_now=0 | archive_touched=0");
      return true;
     }

   bool loaded = LoadFullHistory();
   int loadedBars = Bars(FullSymbolName(), PERIOD_M1);
   bool verified = (loaded && loadedBars > 1000);
   Print("[EA|FULL|YEAR] INFO history ready | year=", year,
         " | symbol=", FullSymbolName(), " | csv=", openedName,
         " | csv_bytes=", csvBytes, " | m1_bars=", loadedBars,
         " | loaded_now=1 | verified=", (int)verified,
         " | archive_touched=0");
   return verified;
  }

bool SwitchFullWorkYear(long chartID, int targetYear, string reason,
                        string targetCaseId)
  {
   HideOpportunityDetailsPanel(chartID);
   int oldWorkYear = fullWorkYear;
   string oldRuntimeSymbol = fullRuntimeSymbol;
   string oldLoadedKey = GV_FULL_LOADED;
   bool oldYearGlobalPresent = GlobalVariableCheck(GV_FULL_WORK_YEAR);
   double oldYearGlobalValue = oldYearGlobalPresent ?
                               GlobalVariableGet(GV_FULL_WORK_YEAR) : 0.0;
   string oldCaseId = opportunityActiveCaseId;
   string oldActiveType = opportunityActiveCaseType;
   string oldArchivedType = opportunityArchivedCaseType;
   bool oldTypeDirty = opportunityCaseTypeDirty;
   string oldActiveStandardity = opportunityActiveStandardity;
   string oldArchivedStandardity = opportunityArchivedStandardity;
   bool oldStandardityDirty = opportunityStandardityDirty;
   string oldNativeSymbol = opportunityAnnotationNativeSymbol;
   string oldNativeTimeframe = opportunityAnnotationNativeTimeframe;
   bool oldReadOnly = opportunityAnnotationReadOnly;
   bool oldSessionRestored = opportunitySessionStateRestored;
   int oldSessionWorkYear = opportunitySessionWorkYear;

   Print("[EA|FULL|YEAR] INFO switch started | reason=", reason,
         " | from_year=", oldWorkYear, " | to_year=", targetYear,
         " | from_symbol=", ChartSymbol(chartID),
         " | to_symbol=", BuildFullSymbolForYear(targetYear),
         " | target_case=", targetCaseId,
         " | archive_touched=0");

   if(!EnsureFullYearHistory(targetYear) ||
      !PrepareOpportunitySessionForYear(chartID, targetYear, targetCaseId, reason) ||
      !SaveOpportunitySessionState(chartID, "year_switch_" + reason))
     {
      fullWorkYear = oldWorkYear;
      fullRuntimeSymbol = oldRuntimeSymbol;
      GV_FULL_LOADED = oldLoadedKey;
      opportunityActiveCaseId = oldCaseId;
      opportunityActiveCaseType = oldActiveType;
      opportunityArchivedCaseType = oldArchivedType;
      opportunityCaseTypeDirty = oldTypeDirty;
      opportunityActiveStandardity = oldActiveStandardity;
      opportunityArchivedStandardity = oldArchivedStandardity;
      opportunityStandardityDirty = oldStandardityDirty;
      opportunityAnnotationNativeSymbol = oldNativeSymbol;
      opportunityAnnotationNativeTimeframe = oldNativeTimeframe;
      opportunityAnnotationReadOnly = oldReadOnly;
      opportunitySessionStateRestored = oldSessionRestored;
      opportunitySessionWorkYear = oldSessionWorkYear;
      if(oldYearGlobalPresent)
         GlobalVariableSet(GV_FULL_WORK_YEAR, oldYearGlobalValue);
      else
         GlobalVariableDel(GV_FULL_WORK_YEAR);
      GlobalVariablesFlush();
      SaveOpportunitySessionState(chartID, "year_switch_rollback");
      Print("[EA|FULL|YEAR] ERROR switch preparation failed | reason=", reason,
            " | restored_year=", oldWorkYear,
            " | err=", GetLastError(), " | archive_touched=0");
      return false;
     }

   GlobalVariableSet(GV_FULL_WORK_YEAR, targetYear);
   GlobalVariablesFlush();
   string targetSymbol = FullSymbolName();
   ResetLastError();
   bool switched = ChartSetSymbolPeriod(chartID, targetSymbol, InpFullTimeframe);
   int switchError = GetLastError();
   if(!switched)
     {
      fullWorkYear = oldWorkYear;
      fullRuntimeSymbol = oldRuntimeSymbol;
      GV_FULL_LOADED = oldLoadedKey;
      opportunityActiveCaseId = oldCaseId;
      opportunityActiveCaseType = oldActiveType;
      opportunityArchivedCaseType = oldArchivedType;
      opportunityCaseTypeDirty = oldTypeDirty;
      opportunityActiveStandardity = oldActiveStandardity;
      opportunityArchivedStandardity = oldArchivedStandardity;
      opportunityStandardityDirty = oldStandardityDirty;
      opportunityAnnotationNativeSymbol = oldNativeSymbol;
      opportunityAnnotationNativeTimeframe = oldNativeTimeframe;
      opportunityAnnotationReadOnly = oldReadOnly;
      opportunitySessionStateRestored = oldSessionRestored;
      opportunitySessionWorkYear = oldSessionWorkYear;
      if(oldYearGlobalPresent)
         GlobalVariableSet(GV_FULL_WORK_YEAR, oldYearGlobalValue);
      else
         GlobalVariableDel(GV_FULL_WORK_YEAR);
      GlobalVariablesFlush();
      SaveOpportunitySessionState(chartID, "year_switch_chart_rollback");
      Print("[EA|FULL|YEAR] ERROR chart switch failed | reason=", reason,
            " | target_year=", targetYear, " | target_symbol=", targetSymbol,
            " | err=", switchError, " | archive_touched=0");
      return false;
     }

   UpdateFullWorkYearButton();
   Print("[EA|FULL|YEAR] INFO switch result | reason=", reason,
         " | year=", targetYear, " | symbol=", targetSymbol,
         " | case=", OpportunityCaseId(),
         " | chart_period=", TimeframeName(InpFullTimeframe),
         " | switched=1 | archive_touched=0");
   return true;
  }

bool EnsureFullSymbol()
  {
   return EnsureCustomSymbol(FullSymbolName());
  }

long GetFullChartID()
  {
   long currChart = ChartFirst();
   while(currChart != -1)
     {
       if(ChartSymbol(currChart) == FullSymbolName())
        {
         return currChart;
        }
      currChart = ChartNext(currChart);
     }
   return 0;
  }

string ExtractFileName(string path)
  {
   string fileName = path;
   int lastSep = -1;
   for(int i = StringLen(path) - 1; i >= 0; i--)
     {
      string ch = StringSubstr(path, i, 1);
      if(ch == "\\" || ch == "/")
        {
         lastSep = i;
         break;
        }
     }
   if(lastSep >= 0) fileName = StringSubstr(path, lastSep + 1);
   return fileName;
  }

string ExtractDirectoryName(string path)
  {
   int lastSep = -1;
   for(int i = StringLen(path) - 1; i >= 0; i--)
     {
      string ch = StringSubstr(path, i, 1);
      if(ch == "\\" || ch == "/")
        {
         lastSep = i;
         break;
        }
     }
   if(lastSep < 0) return "";
   return StringSubstr(path, 0, lastSep);
  }

string BuildYearCsvPath(string samplePath, int year)
  {
   string dir = ExtractDirectoryName(samplePath);
   string fileName = ExtractFileName(samplePath);

   int dot = -1;
   for(int i = StringLen(fileName) - 1; i >= 0; i--)
     {
      if(StringSubstr(fileName, i, 1) == ".")
        {
         dot = i;
         break;
        }
     }

   int endPos = (dot >= 0) ? dot : StringLen(fileName);
   int under = -1;
   for(int j = endPos - 1; j >= 0; j--)
     {
      if(StringSubstr(fileName, j, 1) == "_")
        {
         under = j;
         break;
        }
     }

   string yearFile;
   if(under >= 0)
     {
      string prefix = StringSubstr(fileName, 0, under + 1);
      string suffix = (dot >= 0) ? StringSubstr(fileName, dot) : ".csv";
      yearFile = prefix + IntegerToString(year) + suffix;
     }
   else
     {
      yearFile = "EURUSD_" + IntegerToString(year) + ".csv";
     }

   if(StringLen(dir) == 0) return yearFile;
   return dir + "\\" + yearFile;
  }

int OpenFullCsvFile(string path, string &openedName)
  {
   string fileName = ExtractFileName(path);
   openedName = path;

   ResetLastError();
   int handle = FileOpen(path, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   int err1 = GetLastError();
   if(handle != INVALID_HANDLE_VALUE)
      return handle;

   ResetLastError();
   handle = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
   int err2 = GetLastError();
   if(handle != INVALID_HANDLE_VALUE)
     {
      openedName = fileName;
      return handle;
     }

   if(GV_DEBUG_FULL) Print("FULL-DBG | CSV OPEN FAILED | path=", path, " err1=", err1, " err2=", err2);
   return INVALID_HANDLE_VALUE;
  }

bool ParseCsvRateLine(string line, MqlRates &rate)
  {
   if(StringLen(line) == 0) return false;

   StringReplace(line, "\r", "");
   StringReplace(line, "\n", "");
   if(StringLen(line) == 0) return false;

   string parts[];
   int n = StringSplit(line, ',', parts);
   if(n < 6) return false;

   string firstLower = parts[0];
      StringToLower(firstLower);
   if(StringFind(firstLower, "time") >= 0 || StringFind(firstLower, "date") >= 0)
      return false;

   datetime t;
   int base = 0;
   if(n >= 8)
     {
      t = StringToTime(parts[0] + " " + parts[1]);
      base = 2;
     }
   else
     {
      t = StringToTime(parts[0]);
      base = 1;
     }

   if(t <= 0) return false;
   if(n <= base + 4) return false;

   string s_open = parts[base];
   string s_high = parts[base + 1];
   string s_low  = parts[base + 2];
   string s_close = parts[base + 3];
   string s_tick = parts[base + 4];
   string s_real = (n > base + 5) ? parts[base + 5] : "0";
   string s_spread = (n > base + 6) ? parts[base + 6] : "10";

   StringReplace(s_open, ",", ".");
   StringReplace(s_high, ",", ".");
   StringReplace(s_low, ",", ".");
   StringReplace(s_close, ",", ".");

   rate.time = t;
   rate.open = StringToDouble(s_open);
   rate.high = StringToDouble(s_high);
   rate.low = StringToDouble(s_low);
   rate.close = StringToDouble(s_close);
   rate.tick_volume = (long)StringToInteger(s_tick);
   rate.real_volume = (long)StringToInteger(s_real);
   rate.spread = (int)StringToInteger(s_spread);
   return true;
  }

bool FlushFullHistoryRates(MqlRates &rates[], int count, int &chunkCount, int total)
  {
   if(count <= 0) return true;

   int oldSize = ArraySize(rates);
   if(oldSize != count) ArrayResize(rates, count);

   ResetLastError();
   bool upOk = CustomRatesUpdate(FullSymbolName(), rates);
   int err = GetLastError();
   chunkCount++;

   if(GV_DEBUG_FULL && (chunkCount % 10 == 0 || !upOk))
      Print("FULL-DBG | Chunk update #", chunkCount, " ok=", (int)upOk, " total=", total, " err=", err);
   if(!upOk)
      Print("FULL-DBG | Chunk update failed | err=", err);

   if(oldSize != count) ArrayResize(rates, oldSize);
   return upOk;
  }

bool LoadFullHistoryCsvFile(string csvPath, MqlRates &rates[], int &idx, int &total, int &chunkCount)
  {
   string openedName = "";
   int handle = OpenFullCsvFile(csvPath, openedName);
   if(handle == INVALID_HANDLE_VALUE)
      return false;

   if(GV_DEBUG_FULL) Print("FULL-DBG | CSV OPEN OK | file=", openedName, " size=", (int)FileSize(handle));

   int fileBars = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      MqlRates rate;
      if(!ParseCsvRateLine(line, rate)) continue;

      rates[idx] = rate;
      idx++;
      total++;
      fileBars++;

      if(idx >= ArraySize(rates))
        {
         FlushFullHistoryRates(rates, idx, chunkCount, total);
         idx = 0;
        }
     }

   FileClose(handle);
   Print("Loaded CSV bars: ", fileBars, " | ", csvPath);
   return (fileBars > 0);
  }

bool LoadFullHistory()
  {
   string fullSymbol = FullSymbolName();
   string csvPath = BuildYearCsvPath(InpFullCsvPath, fullWorkYear);
   if(GV_DEBUG_FULL) Print("FULL-DBG | LoadFullHistory ENTER | Symbol=", fullSymbol,
                           " TF=", (int)InpFullTimeframe,
                           " | year=", fullWorkYear,
                           " | csv=", csvPath);

   if(!EnsureFullSymbol())
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | EnsureFullSymbol failed");
      return false;
     }

   long fullChart = isFullChartInstance ? ChartID() : GetFullChartID();
   if(fullChart == 0 && InpEnableFullChart)
      fullChart = ChartOpen(fullSymbol, InpFullTimeframe);
   if(fullChart == 0)
      fullChart = ChartID();

   UpdateFullModeLabel(fullChart, "FULL MODE ACTIVE | LOADING CSV");
   if(GV_DEBUG_FULL) Print("FULL-DBG | LOADING CSV | path=", csvPath,
                           " | yearly_symbol=1 | legacy_all_years_input=",
                           (int)InpFullLoadAllYears);

   if(!InpFullForceReload)
     {
      int existingBars = Bars(fullSymbol, PERIOD_M1);
      if(existingBars > 1000)
        {
         UpdateFullModeLabel(fullChart, "FULL MODE ACTIVE | ALREADY LOADED");
          if(GV_DEBUG_FULL) Print("FULL-DBG | SKIP existingBars=", existingBars);
          Print("Full history already loaded (bars=", existingBars, "). Skipping.");
          GlobalVariableSet(GV_FULL_LOADED, TimeCurrent());
          GlobalVariablesFlush();
          return true;
        }
     }

   ResetLastError();
   bool delOk = CustomRatesDelete(fullSymbol, 0, D'2099.12.31');
   if(GV_DEBUG_FULL) Print("FULL-DBG | CustomRatesDelete=", (int)delOk, " err=", GetLastError());

   const int CHUNK_SIZE = 5000;
   MqlRates rates[];
   ArrayResize(rates, CHUNK_SIZE);

   int idx = 0;
   int total = 0;
   int chunkCount = 0;
   int filesLoaded = 0;

   UpdateFullModeLabel(fullChart,
                       StringFormat("FULL MODE ACTIVE | LOADING %d", fullWorkYear));
   if(LoadFullHistoryCsvFile(csvPath, rates, idx, total, chunkCount))
      filesLoaded++;

   if(idx > 0)
      FlushFullHistoryRates(rates, idx, chunkCount, total);

   SymbolSelect(fullSymbol, true);

   if(fullChart != 0 && ChartSymbol(fullChart) == fullSymbol)
     {
      ChartRedraw(fullChart);
      GoFullChartToStart(fullChart);
     }

   if(total <= 0)
     {
      string fileName = ExtractFileName(csvPath);
      string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + fileName;
      string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + fileName;
      UpdateFullModeLabel(fullChart, "FULL MODE ACTIVE | CSV OPEN FAILED");
      Print("No full-history bars loaded. Check yearly CSV. year=", fullWorkYear,
            " | symbol=", fullSymbol, " | csv=", csvPath,
            " | Terminal=", terminalPath, " | Common=", commonPath);
      return false;
     }

   UpdateFullModeLabel(fullChart, StringFormat("FULL MODE ACTIVE | LOADED %d bars / %d files", total, filesLoaded));
   if(GV_DEBUG_FULL) Print("FULL-DBG | LOADED bars=", total, " files=", filesLoaded,
                           " | year=", fullWorkYear, " | symbol=", fullSymbol);
   Print("Loaded full history bars: ", total, " files: ", filesLoaded,
         " year: ", fullWorkYear, " symbol: ", fullSymbol);
   GlobalVariableSet(GV_FULL_LOADED, TimeCurrent());
   GlobalVariablesFlush();
   return true;
  }
void ShowFullModeLabel(long chartID)
{
   UpdateFullModeLabel(chartID, "FULL MODE ACTIVE");
}
void UpdateFullModeLabel(long chartID, string text)
{
   string name = "FullModeMsg";

   if(chartID == 0)
      return;

   if(!InpShowFullModeLabel)
     {
      ObjectDelete(chartID, name);
      return;
     }

   if(ObjectFind(chartID, name) < 0)
   {
      ObjectCreate(chartID, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetString(chartID, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chartID, name, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chartID, name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(chartID, name, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(chartID, name, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(chartID, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartID, name, OBJPROP_BACK, false);
   ObjectSetInteger(chartID, name, OBJPROP_ZORDER, 1000);
   ObjectSetInteger(chartID, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ChartRedraw(chartID);
}
int CloseAllChartsExcept(long keepChartID)
{
   int closed = 0;
   int failed = 0;
   long currChart = ChartFirst();
   while(currChart != -1)
   {
      long nextChart = ChartNext(currChart);
      if(currChart != keepChartID)
      {
         string symbol = ChartSymbol(currChart);
         ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(currChart);
         ResetLastError();
         bool closeOk = ChartClose(currChart);
         int err = GetLastError();
         if(closeOk)
         {
            closed++;
            Print("[EA|FULL|CHARTS] INFO close chart=", currChart, " symbol=", symbol, " tf=", (int)timeframe);
         }
         else
         {
            failed++;
            Print("[EA|FULL|CHARTS] ERROR close failed chart=", currChart, " symbol=", symbol, " tf=", (int)timeframe, " err=", err);
         }
      }
      currChart = nextChart;
   }
   Print("[EA|FULL|CHARTS] INFO result keep=", keepChartID, " closed=", closed, " failed=", failed);
   return closed;
}

void CloseExistingChart(string symbol)
{
   long currChart = ChartFirst();
   while(currChart != -1)
   {
      if(ChartSymbol(currChart) == symbol)
      {
         Print("Closing old chart: ", currChart);
         ChartClose(currChart);
         currChart = ChartFirst();
         continue;
      }
      currChart = ChartNext(currChart);
   }
}

// Helper to find the Replay Chart ID dynamically
long GetReplayChartID()
{
   long currChart = ChartFirst();
   while(currChart != -1)
   {
      if(ChartSymbol(currChart) == InpSymbolName)
      {
         return currChart;
      }
      currChart = ChartNext(currChart);
   }
   return 0; // Not found
}


// Apply chart colors directly (safe alternative to templates, which may carry indicators/EAs/objects)
void ApplyColorTheme(long chartID)
{
   if(!InpColorsEnabled) return;
   if(chartID == 0) return;

   // Visual settings
   ChartSetInteger(chartID, CHART_SHOW_GRID, InpShowGrid ? 1 : 0);

   // Colors
   ChartSetInteger(chartID, CHART_COLOR_BACKGROUND, InpColorBackground);
   ChartSetInteger(chartID, CHART_COLOR_FOREGROUND, InpColorForeground);
   ChartSetInteger(chartID, CHART_COLOR_GRID, InpColorGrid);
   ChartSetInteger(chartID, CHART_COLOR_CANDLE_BULL, InpColorBullCandle);
   ChartSetInteger(chartID, CHART_COLOR_CANDLE_BEAR, InpColorBearCandle);
   ChartSetInteger(chartID, CHART_COLOR_CHART_UP, InpColorChartUp);
   ChartSetInteger(chartID, CHART_COLOR_CHART_DOWN, InpColorChartDown);
   ChartSetInteger(chartID, CHART_COLOR_BID, InpColorBid);
   ChartSetInteger(chartID, CHART_COLOR_ASK, InpColorAsk);
   ChartSetInteger(chartID, CHART_COLOR_STOP_LEVEL, InpColorStopLevels);

   ChartRedraw(chartID);
   if(GV_DEBUG_FULL) Print("FULL-DBG | ApplyColorTheme | chart=", chartID);
}

// Apply ONLY the color-related chart properties from a template (does not detach this EA).
bool ApplyTemplateColorsToChart(long chartID)
{
   if(chartID == 0) return false;
   if(StringLen(InpTemplateName) == 0) return false;

   // Build a stable key for caching colors per template name.
   string tplKey = InpTemplateName;
   StringReplace(tplKey, "\\", "_");
   StringReplace(tplKey, "/", "_");
   StringReplace(tplKey, ":", "_");
   StringReplace(tplKey, " ", "_");
   StringReplace(tplKey, ".", "_");
   string base = "Energy_TplColors_" + tplKey;

   if(InpTemplateForceReapply)
     {
      GlobalVariableDel(base + "_ready");
     }

   // If cached, apply directly.
   if(GlobalVariableCheck(base + "_ready"))
     {
      long showGrid = (long)GlobalVariableGet(base + "_grid");
      long bg  = (long)GlobalVariableGet(base + "_bg");
      long fg  = (long)GlobalVariableGet(base + "_fg");
      long grid= (long)GlobalVariableGet(base + "_gridc");
      long bull= (long)GlobalVariableGet(base + "_bull");
      long bear= (long)GlobalVariableGet(base + "_bear");
      long up  = (long)GlobalVariableGet(base + "_up");
      long dn  = (long)GlobalVariableGet(base + "_dn");
      long bid = (long)GlobalVariableGet(base + "_bid");
      long ask = (long)GlobalVariableGet(base + "_ask");
      long stp = (long)GlobalVariableGet(base + "_stp");

      ChartSetInteger(chartID, CHART_SHOW_GRID, showGrid);
      ChartSetInteger(chartID, CHART_COLOR_BACKGROUND, bg);
      ChartSetInteger(chartID, CHART_COLOR_FOREGROUND, fg);
      ChartSetInteger(chartID, CHART_COLOR_GRID, grid);
      ChartSetInteger(chartID, CHART_COLOR_CANDLE_BULL, bull);
      ChartSetInteger(chartID, CHART_COLOR_CANDLE_BEAR, bear);
      ChartSetInteger(chartID, CHART_COLOR_CHART_UP, up);
      ChartSetInteger(chartID, CHART_COLOR_CHART_DOWN, dn);
      ChartSetInteger(chartID, CHART_COLOR_BID, bid);
      ChartSetInteger(chartID, CHART_COLOR_ASK, ask);
      ChartSetInteger(chartID, CHART_COLOR_STOP_LEVEL, stp);
      ChartRedraw(chartID);
      if(GV_DEBUG_FULL) Print("FULL-DBG | Applied cached template COLORS | chart=", chartID, " tpl=", InpTemplateName);
      return true;
     }

   // Capture colors by applying the template to a temporary chart (safe because EA is not attached there).
   string sym = ChartSymbol(chartID);
   int tf = (int)ChartPeriod(chartID);
   if(StringLen(sym) == 0) sym = _Symbol;
   if(tf <= 0) tf = (int)_Period;

   long tmp = ChartOpen(sym, (ENUM_TIMEFRAMES)tf);
   if(tmp == 0)
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | Capture template colors FAILED: ChartOpen tmp=0 | sym=", sym, " tf=", tf);
      return false;
     }

   bool applied = false;
   if(StringLen(InpTemplateAltPath) > 0 && FileIsExist(InpTemplateAltPath))
     {
      applied = ChartApplyTemplate(tmp, InpTemplateAltPath);
     }
   if(!applied)
     {
      string tplDefaultPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\" + InpTemplateName;
      if(FileIsExist(tplDefaultPath)) applied = ChartApplyTemplate(tmp, tplDefaultPath);
     }
   if(!applied)
     {
      applied = ChartApplyTemplate(tmp, InpTemplateName);
     }

   if(!applied)
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | Capture template colors FAILED: apply template | tpl=", InpTemplateName);
      ChartClose(tmp);
      return false;
     }

   long showGrid = ChartGetInteger(tmp, CHART_SHOW_GRID);
   long bg  = ChartGetInteger(tmp, CHART_COLOR_BACKGROUND);
   long fg  = ChartGetInteger(tmp, CHART_COLOR_FOREGROUND);
   long grid= ChartGetInteger(tmp, CHART_COLOR_GRID);
   long bull= ChartGetInteger(tmp, CHART_COLOR_CANDLE_BULL);
   long bear= ChartGetInteger(tmp, CHART_COLOR_CANDLE_BEAR);
   long up  = ChartGetInteger(tmp, CHART_COLOR_CHART_UP);
   long dn  = ChartGetInteger(tmp, CHART_COLOR_CHART_DOWN);
   long bid = ChartGetInteger(tmp, CHART_COLOR_BID);
   long ask = ChartGetInteger(tmp, CHART_COLOR_ASK);
   long stp = ChartGetInteger(tmp, CHART_COLOR_STOP_LEVEL);

   ChartClose(tmp);

   GlobalVariableSet(base + "_ready", (double)TimeCurrent());
   GlobalVariableSet(base + "_grid", (double)showGrid);
   GlobalVariableSet(base + "_bg", (double)bg);
   GlobalVariableSet(base + "_fg", (double)fg);
   GlobalVariableSet(base + "_gridc", (double)grid);
   GlobalVariableSet(base + "_bull", (double)bull);
   GlobalVariableSet(base + "_bear", (double)bear);
   GlobalVariableSet(base + "_up", (double)up);
   GlobalVariableSet(base + "_dn", (double)dn);
   GlobalVariableSet(base + "_bid", (double)bid);
   GlobalVariableSet(base + "_ask", (double)ask);
   GlobalVariableSet(base + "_stp", (double)stp);
   GlobalVariablesFlush();

   // Apply now
   ChartSetInteger(chartID, CHART_SHOW_GRID, showGrid);
   ChartSetInteger(chartID, CHART_COLOR_BACKGROUND, bg);
   ChartSetInteger(chartID, CHART_COLOR_FOREGROUND, fg);
   ChartSetInteger(chartID, CHART_COLOR_GRID, grid);
   ChartSetInteger(chartID, CHART_COLOR_CANDLE_BULL, bull);
   ChartSetInteger(chartID, CHART_COLOR_CANDLE_BEAR, bear);
   ChartSetInteger(chartID, CHART_COLOR_CHART_UP, up);
   ChartSetInteger(chartID, CHART_COLOR_CHART_DOWN, dn);
   ChartSetInteger(chartID, CHART_COLOR_BID, bid);
   ChartSetInteger(chartID, CHART_COLOR_ASK, ask);
   ChartSetInteger(chartID, CHART_COLOR_STOP_LEVEL, stp);
   ChartRedraw(chartID);
   if(GV_DEBUG_FULL) Print("FULL-DBG | Captured+Applied template COLORS | chart=", chartID, " tpl=", InpTemplateName);
   return true;
}


// Apply template once per chart to avoid infinite init loops (ChartApplyTemplate restarts EAs)
bool ApplyTemplateOnce(long chartID)
{
   if(chartID == 0) return false;
   string tplKey = InpTemplateName;
   StringReplace(tplKey, "\\", "_");
   StringReplace(tplKey, "/", "_");
   StringReplace(tplKey, ":", "_");
   StringReplace(tplKey, " ", "_");
   StringReplace(tplKey, ".", "_");
   string sym = ChartSymbol(chartID);
   int tf = (int)ChartPeriod(chartID);
   // Sanitize symbol for global-variable key (stable even if chartID changes)
   StringReplace(sym, "@", "_");
   StringReplace(sym, "#", "_");
   StringReplace(sym, " ", "_");
   StringReplace(sym, ":", "_");
   StringReplace(sym, "/", "_");
   StringReplace(sym, "\\", "_");
   StringReplace(sym, ".", "_");
   string key = "Energy_TplApplied_" + sym + "_" + IntegerToString(tf) + "_" + tplKey;

   if(InpTemplateForceReapply)
     {
      GlobalVariableDel(key);
     }

   if(GlobalVariableCheck(key))
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | Template already applied, skip | chart=", chartID, " key=", key);
      return false;
     }

   // Mark BEFORE applying; ApplyTemplate will restart this EA instance.
   GlobalVariableSet(key, (double)TimeCurrent());
   GlobalVariablesFlush();
   if(GV_DEBUG_FULL) Print("FULL-DBG | Applying template ONCE | chart=", chartID, " name=", InpTemplateName);
   ApplyTemplateToChart(chartID);
   return true;
}

// Apply template to a chart with robust path resolution
void ApplyTemplateToChart(long chartID)
{
   if(chartID == 0) { Print("Template apply skipped: invalid chartID"); return; }

   // Default templates directory inside terminal data path
   string tplDefaultPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\" + InpTemplateName;
   bool applied = false;

   // Try alternative absolute path first (project path)
   if(StringLen(InpTemplateAltPath) > 0 && FileIsExist(InpTemplateAltPath))
   {
      applied = ChartApplyTemplate(chartID, InpTemplateAltPath);
      if(applied) { Print("Applied template from alt path: ", InpTemplateAltPath); ChartRedraw(chartID); return; }
   }

   // Fallback to default templates directory
   if(FileIsExist(tplDefaultPath))
   {
      applied = ChartApplyTemplate(chartID, tplDefaultPath);
      if(applied) { Print("Applied template from default path: ", tplDefaultPath); ChartRedraw(chartID); return; }
   }

   // Last resort: try by name (some terminals resolve by name)
   applied = ChartApplyTemplate(chartID, InpTemplateName);
   if(applied) { Print("Applied template by name: ", InpTemplateName); ChartRedraw(chartID); return; }

   Print("Unable to apply template: ", InpTemplateName);
}

bool AutoAttachEAOnFullChart(long chartID)
{
   if(chartID == 0) return false;
   if(!InpFullAutoAttachEA) return false;

   // If FULL EA panel already exists, this chart is likely already running EA.
   if(ObjectFind(chartID, OBJ_FULL_BTN_HOME) >= 0)
      return true;

   string tplName = InpFullEATemplateName;
   if(StringLen(tplName) == 0) tplName = InpTemplateName;
   if(StringLen(tplName) == 0)
     {
      if(GV_DEBUG_FULL) Print("FULL-DBG | AutoAttach skipped: template name is empty");
      return false;
     }

   bool applied = false;

   if(StringLen(InpFullEATemplateAltPath) > 0 && FileIsExist(InpFullEATemplateAltPath))
      applied = ChartApplyTemplate(chartID, InpFullEATemplateAltPath);

   if(!applied)
     {
      string tplDefaultPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\" + tplName;
      if(FileIsExist(tplDefaultPath))
         applied = ChartApplyTemplate(chartID, tplDefaultPath);
     }

   if(!applied)
      applied = ChartApplyTemplate(chartID, tplName);

   if(GV_DEBUG_FULL) Print("FULL-DBG | AutoAttach FULL EA | chart=", chartID, " tpl=", tplName, " ok=", (int)applied);
   return applied;
}

// --- Pipe Logic (Unchanged) ---

void ConnectPipe()
  {
   hPipe = CreateFileW(pipeName, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, 0, 0);
   if(hPipe != INVALID_HANDLE_VALUE)
     {
      Print("Successfully connected to Python Pipe!");
      // ShowLabel(0, "Python: Connected (Launcher)"); // REMOVED
      UpdateUIState();

      // Sync State immediately upon connection
      // Whether we are PAUSED or PLAYING, tell Python to match our state.
      if(isPaused)
      {
         SendCommand("PAUSE");
      }
      else
      {
         Print("馃攧 Restoring PLAY state...");
         SendCommand("RESUME");
      }

      // NEW: Proactively send STATUS on connection!
      // This helps Python sync immediately without needing to ask/retry.
      // FIX: Use PERIOD_M1 to get granular timestamp (minute precision) instead of PERIOD_H1
      datetime lastTime = iTime(InpSymbolName, PERIOD_M1, 0);
      string timeStr = TimeToString(lastTime);
      Print("馃敆 Connected. Sending Initial Status: ", timeStr);
      SendCommand("STATUS|" + timeStr);

      // Also sync Speed
      Print("馃敆 Syncing Initial Speed: ", currentSpeed);
      SendCommand("SPEED|" + DoubleToString(currentSpeed, 2));

      // Also sync Batch
      Print("馃敆 Syncing Initial Batch: x", batchSize);
      SendCommand("BATCH|" + IntegerToString(batchSize));
     }
  }

void ReadPipeCommand()
  {
   uchar buffer[1024];
   uint bytesRead = 0;
   uint bytesAvail = 0;

   if(!PeekNamedPipe(hPipe, 0, 0, 0, bytesAvail, 0))
     {
      // Pipe broken or disconnected
      CloseHandle(hPipe);
      hPipe = INVALID_HANDLE_VALUE;
      UpdateUIState();
      return;
     }

   if(bytesAvail > 0)
     {
      Print("Pipe has data: ", bytesAvail, " bytes"); // DEBUG
      if(ReadFile(hPipe, buffer, 1024, bytesRead, 0))
        {
         string chunk = CharArrayToString(buffer, 0, bytesRead);
         rx_buffer += chunk;

         string lines[];
         int count = StringSplit(rx_buffer, '\n', lines);
         if(count > 0)
           {
            // Keep the last (possibly incomplete) line in buffer
            rx_buffer = lines[count - 1];
            for(int i = 0; i < count - 1; i++)
              {
               string line = lines[i];
               StringReplace(line, "\r", "");
               StringTrimLeft(line);
               StringTrimRight(line);

               if(StringLen(line) > 0)
                 {
                  Print("Pipe Read: ", line); // DEBUG
                  ProcessCommand(line);
                 }
              }
           }
        }
     }
  }

void ProcessCommand(string message)
  {
   Print("Received raw: ", message);

   // Find target chart
   long targetChart = GetReplayChartID();
   if(targetChart == 0)
   {
      // Print("鈿狅笍 Replay chart not found! Sending command to Launcher instead."); // Reduce noise
      targetChart = 0; // Fallback to current chart
   }

   string parts[];
   int count = StringSplit(message, '|', parts);

   if(count >= 2)
     {
      string cmd = parts[0];
      string data = parts[1];

      if(cmd == "MSG")
      {
         // ShowLabel(targetChart, data); // REMOVED: Redundant
         Print("MSG: ", data);
      }
      else if(cmd == "VLINE")
        {
         datetime dt = StringToTime(data);
         CreateVLine(targetChart, dt);
         // ShowLabel(targetChart, "VLine at " + data); // REMOVED
         JumpToTime(targetChart, dt);
        }
      else if(cmd == "SET_RANGE")
        {
         if(count >= 3)
           {
            string startStr = parts[1];
            string endStr = parts[2];
            datetime startDt = StringToTime(startStr);
            datetime endDt = StringToTime(endStr);

            // Set period on target chart
            ChartSetSymbolPeriod(targetChart, InpSymbolName, InpReplayTimeframe);

            CreateRangeMarker(targetChart, startDt, endDt);
            // ShowLabel(targetChart, "Range Set: " + startStr + " to " + endStr); // REMOVED
            JumpToTime(targetChart, startDt);
           }
        }
      else if(cmd == "ADD_BAR")
        {
         AddBarToChart(data);
        }
      else if(cmd == "QUERY_STATUS")
        {
         // Get last bar time of the custom symbol
         // FIX: Use PERIOD_M1 to get granular timestamp (minute precision) instead of PERIOD_H1
         datetime lastTime = iTime(InpSymbolName, PERIOD_M1, 0);

         // If no history exists (or initial dummy bar), we should probably indicate that.
         // But for now, returning the dummy bar time is fine, Python will check if it exists in CSV.
         // However, if the Python script was restarted, it wants to know the LAST REAL BAR.
         // If MT5 was restarted, the history is persisted on disk by MT5.

         // TimeToString default is yyyy.mm.dd hh:mi
         string timeStr = TimeToString(lastTime);
         Print("馃搮 Sync Request Received. Last Bar: ", timeStr);
         SendCommand("STATUS|" + timeStr);
        }
     }
  }

//Helper to show label
void ShowLabel(long chartID, string text)
{
   ObjectCreate(chartID, "PythonMsg", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(chartID, "PythonMsg", OBJPROP_TEXT, "Python: " + text);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_XDISTANCE, 50);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(chartID, "PythonMsg", OBJPROP_FONTSIZE, 20);
   ChartRedraw(chartID);
}

void SendCommand(string cmd)
{
   if(hPipe == INVALID_HANDLE_VALUE) return;

   uchar buffer[];
   StringToCharArray(cmd, buffer);

   uint bytesWritten = 0;
   if(!WriteFile(hPipe, buffer, ArraySize(buffer)-1, bytesWritten, 0)) // -1 to skip null terminator? Python strip() handles it.
   {
      Print("鉂?Failed to send command: ", cmd);
   }
   else
   {
      // Print("馃摛 Sent: ", cmd); // Debug
   }
}

// Helper to draw VLine
void CreateVLine(long chartID, datetime time)
{
   string name = "Py_VLine_" + TimeToString(time);
   ObjectCreate(chartID, name, OBJ_VLINE, 0, time, 0);
   ObjectSetInteger(chartID, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(chartID, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(chartID, name, OBJPROP_SELECTABLE, true);
   Print("Created VLine at ", time, " on Chart ", chartID);
}

// Helper to draw Range Markers (Start/End)
void CreateRangeMarker(long chartID, datetime start, datetime end)
{
   string nameStart = "Range_Start";
   ObjectCreate(chartID, nameStart, OBJ_VLINE, 0, start, 0);
   ObjectSetInteger(chartID, nameStart, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartID, nameStart, OBJPROP_WIDTH, 3);
   ObjectSetInteger(chartID, nameStart, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(chartID, nameStart, OBJPROP_TEXT, "Replay Start");

   string nameEnd = "Range_End";
   ObjectCreate(chartID, nameEnd, OBJ_VLINE, 0, end, 0);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_WIDTH, 3);
   ObjectSetInteger(chartID, nameEnd, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetString(chartID, nameEnd, OBJPROP_TEXT, "Replay End");
}

// Helper to Jump to Time
void JumpToTime(long chartID, datetime time)
{
   ChartSetInteger(chartID, CHART_AUTOSCROLL, false);

   // Use Symbol() of the target chart, not _Symbol (which is Launcher's symbol)
   string sym = ChartSymbol(chartID);
   ENUM_TIMEFRAMES per = ChartPeriod(chartID);

   int barIndex = iBarShift(sym, per, time);
   Print("Navigating to Time: ", time, " | BarIndex: ", barIndex, " on ", sym);

   if(barIndex != -1)
   {
      ChartNavigate(chartID, CHART_END, -barIndex + 20);
      ChartRedraw(0);
   }
   else
   {
      Print("鉂?Time not found in history: ", time);
      ShowLabel(chartID, "Error: Time not found");
   }
}

// Helper to Add Bar
void AddBarToChart(string data)
{
   string parts[];
   int count = StringSplit(data, ',', parts);

   if(count < 6)
   {
      Print("鉂?Invalid ADD_BAR data: ", data);
      return;
   }

   MqlRates rates[];
   ArrayResize(rates, 1);

   rates[0].time = StringToTime(parts[0]);
   rates[0].open = StringToDouble(parts[1]);
   rates[0].high = StringToDouble(parts[2]);
   rates[0].low = StringToDouble(parts[3]);
   rates[0].close = StringToDouble(parts[4]);
   rates[0].tick_volume = StringToInteger(parts[5]);
   rates[0].spread = 10;
   rates[0].real_volume = 0;

   int written = CustomRatesUpdate(InpSymbolName, rates);
   if(written > 0)
   {
      Print("鉁?Added Bar: ", parts[0], " | Close: ", rates[0].close);
      // Force chart refresh
      long chartID = GetReplayChartID();
      if(chartID != 0)
      {
         // ChartSetInteger(chartID, CHART_AUTOSCROLL, true); // Optional: Force scroll
         ChartRedraw(chartID);
      }
   }
   else
   {
      Print("鉂?Failed to add bar: ", GetLastError());
   }
}
