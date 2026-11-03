using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using MiddleFlow.Core.Models;
using MiddleFlow.Core.Services;
using MiddleFlow.Windows.Services;
using MiddleFlow.Windows.Views;

namespace MiddleFlow.Windows.ViewModels;

public enum PageKey
{
    Overview,
    Gestures,
    Voice,
    Doubao,
    Apps,
    Permissions,
    Diagnostics,
    About
}

public sealed record NavigationPage(PageKey Key, string Title, string Glyph);

public enum VoicePhase
{
    Idle,
    Listening,
    Transcribing,
    Pasting
}

public enum VoiceMode
{
    None,
    Direct,
    Overlay
}

public sealed class MainViewModel : ObservableObject, IDisposable
{
    public const string ProductVersion = "2.0.0";
    public const string RepositoryUrl = "https://github.com/leicheng42/MiddleFlow";

    private readonly Dispatcher _dispatcher;
    private readonly SettingsStore _settingsStore;
    private readonly StartupService _startup;
    private readonly WindowTargetService _targets;
    private readonly KeyboardService _keyboard;
    private readonly ClipboardService _clipboard;
    private readonly GestureClassifier _gestures = new();
    private readonly TranscriptStabilizer _stabilizer = new();
    private MouseHookService? _hook;
    private TrayService? _tray;
    private MainWindow? _mainWindow;
    private VoiceTestWindow? _testWindow;
    private VoiceComposerWindow? _overlay;
    private WindowTarget? _voiceTarget;
    private MousePoint? _voiceClickPoint;
    private VoicePhase _phase;
    private VoiceMode _mode;
    private bool _hookInstalled;
    private bool _pendingReturn;
    private int _overlaySession;
    private int _pasteSession;
    private DispatcherTimer? _transcriptionTimer;
    private int _mappedClicks;
    private int _doubleClicks;
    private string _lastEvent = "等待启动";
    private string _hookError = string.Empty;
    private DoubaoStatus _doubaoStatus = DoubaoStatus.Missing("尚未检测");
    private PageKey _selectedPage = PageKey.Overview;
    private string _logTail = string.Empty;
    private string _startupError = string.Empty;
    private bool _disposed;

    public MainViewModel(
        AppPaths paths,
        DiagnosticsLog log,
        SettingsStore settingsStore,
        StartupService startup,
        Dispatcher dispatcher)
    {
        Paths = paths;
        Diagnostics = log;
        _settingsStore = settingsStore;
        _startup = startup;
        _dispatcher = dispatcher;
        _targets = new WindowTargetService();
        _keyboard = new KeyboardService();
        _clipboard = new ClipboardService();
        Settings = settingsStore.Load();
        Settings.Normalize();

        Pages = new ObservableCollection<NavigationPage>
        {
            new(PageKey.Overview, "概览", "\uE80F"),
            new(PageKey.Gestures, "手势", "\uE962"),
            new(PageKey.Voice, "语音", "\uE9D9"),
            new(PageKey.Doubao, "豆包输入法", "\uE765"),
            new(PageKey.Apps, "应用", "\uE8B7"),
            new(PageKey.Permissions, "权限与状态", "\uE72E"),
            new(PageKey.Diagnostics, "诊断", "\uE9D9"),
            new(PageKey.About, "关于", "\uE946")
        };

        RefreshDoubaoStatus();
        RefreshLog();

        PauseMappingCommand = new RelayCommand(PauseMapping);
        ResumeMappingCommand = new RelayCommand(ResumeMapping);
        OpenTestWindowCommand = new RelayCommand(ShowTestWindow);
        RefreshDoubaoCommand = new RelayCommand(RefreshDoubaoStatus);
        OpenDoubaoDownloadCommand = new RelayCommand(OpenDoubaoDownload);
        OpenKeyboardSettingsCommand = new RelayCommand(OpenKeyboardSettings);
        OpenDataFolderCommand = new RelayCommand(OpenDataFolder);
        RefreshLogCommand = new RelayCommand(RefreshLog);
        OpenLogCommand = new RelayCommand(OpenLog);
        ClearLogCommand = new RelayCommand(ClearLog);
        CopyDiagnosticsCommand = new RelayCommand(CopyDiagnostics);
        OpenStartupSettingsCommand = new RelayCommand(() => OpenSettingsUri("ms-settings:startupapps"));
        OpenPrivacySettingsCommand = new RelayCommand(() => OpenSettingsUri("ms-settings:privacy"));
        OpenRepositoryCommand = new RelayCommand(() => OpenUri(RepositoryUrl));
        OpenLicenseCommand = new RelayCommand(() => OpenUri(RepositoryUrl + "/blob/main/LICENSE"));
        ResetSettingsCommand = new RelayCommand(ResetSettings);
        ExitCommand = new RelayCommand(RequestExit);
    }

    public AppPaths Paths { get; }
    public DiagnosticsLog Diagnostics { get; }
    public AppSettings Settings { get; }
    public ObservableCollection<NavigationPage> Pages { get; }

    public ICommand PauseMappingCommand { get; }
    public ICommand ResumeMappingCommand { get; }
    public ICommand OpenTestWindowCommand { get; }
    public ICommand RefreshDoubaoCommand { get; }
    public ICommand OpenDoubaoDownloadCommand { get; }
    public ICommand OpenKeyboardSettingsCommand { get; }
    public ICommand OpenDataFolderCommand { get; }
    public ICommand RefreshLogCommand { get; }
    public ICommand OpenLogCommand { get; }
    public ICommand ClearLogCommand { get; }
    public ICommand CopyDiagnosticsCommand { get; }
    public ICommand OpenStartupSettingsCommand { get; }
    public ICommand OpenPrivacySettingsCommand { get; }
    public ICommand OpenRepositoryCommand { get; }
    public ICommand OpenLicenseCommand { get; }
    public ICommand ResetSettingsCommand { get; }
    public ICommand ExitCommand { get; }

    public PageKey SelectedPage
    {
        get => _selectedPage;
        set
        {
            if (SetProperty(ref _selectedPage, value))
            {
                OnPropertyChanged(nameof(CurrentPageTitle));
                OnPropertyChanged(nameof(CurrentPageGlyph));
            }
        }
    }

    public string CurrentPageTitle =>
        Pages.FirstOrDefault(page => page.Key == SelectedPage)?.Title ?? "概览";

    public string CurrentPageGlyph =>
        Pages.FirstOrDefault(page => page.Key == SelectedPage)?.Glyph ?? "\uE80F";

    public bool MappingEnabled
    {
        get => Settings.MappingEnabled;
        set
        {
            if (Settings.MappingEnabled == value)
            {
                return;
            }
            Settings.MappingEnabled = value;
            ApplyMappingState();
            SaveSettings();
            OnPropertiesChanged(
                nameof(MappingEnabled),
                nameof(MappingStatusText),
                nameof(MappingStatusDetail));
        }
    }

    public bool DoubleClickEnabled
    {
        get => Settings.DoubleClickEnabled;
        set
        {
            if (Settings.DoubleClickEnabled == value)
            {
                return;
            }
            Settings.DoubleClickEnabled = value;
            _gestures.Reset();
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public double DoubleClickIntervalMs
    {
        get => Settings.DoubleClickIntervalMs;
        set
        {
            var normalized = (int)Math.Clamp(Math.Round(value), 150, 600);
            if (Settings.DoubleClickIntervalMs == normalized)
            {
                return;
            }
            Settings.DoubleClickIntervalMs = normalized;
            _gestures.Reset();
            SaveSettings();
            OnPropertiesChanged(
                nameof(DoubleClickIntervalMs),
                nameof(DoubleClickIntervalLabel));
        }
    }

    public string DoubleClickIntervalLabel => $"{Settings.DoubleClickIntervalMs} ms";

    public bool OverlayEnabled
    {
        get => Settings.OverlayEnabled;
        set
        {
            if (Settings.OverlayEnabled == value)
            {
                return;
            }
            Settings.OverlayEnabled = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool DirectModeEnabled
    {
        get => Settings.DirectModeEnabled;
        set
        {
            if (Settings.DirectModeEnabled == value)
            {
                return;
            }
            Settings.DirectModeEnabled = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool AutoPaste
    {
        get => Settings.AutoPaste;
        set
        {
            if (Settings.AutoPaste == value)
            {
                return;
            }
            Settings.AutoPaste = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool PasteThenEnter
    {
        get => Settings.PasteThenEnter;
        set
        {
            if (Settings.PasteThenEnter == value)
            {
                return;
            }
            Settings.PasteThenEnter = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool RestoreClipboard
    {
        get => Settings.RestoreClipboard;
        set
        {
            if (Settings.RestoreClipboard == value)
            {
                return;
            }
            Settings.RestoreClipboard = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool StartAtLogin
    {
        get => Settings.StartAtLogin;
        set
        {
            if (Settings.StartAtLogin == value)
            {
                return;
            }
            if (!_startup.SetEnabled(value))
            {
                _startupError = "无法写入 Windows 启动项，请检查用户权限。";
                OnPropertyChanged(nameof(StartupError));
                OnPropertyChanged(nameof(StartAtLogin));
                return;
            }
            _startupError = string.Empty;
            Settings.StartAtLogin = value;
            SaveSettings();
            OnPropertiesChanged(nameof(StartAtLogin), nameof(StartupError));
        }
    }

    public string StartupError => _startupError;

    public bool ShowTrayNotifications
    {
        get => Settings.ShowTrayNotifications;
        set
        {
            if (Settings.ShowTrayNotifications == value)
            {
                return;
            }
            Settings.ShowTrayNotifications = value;
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public string CanvasAppPatterns
    {
        get => Settings.CanvasAppPatterns;
        set
        {
            if (Settings.CanvasAppPatterns == value)
            {
                return;
            }
            Settings.CanvasAppPatterns = value ?? string.Empty;
            Settings.Normalize();
            SaveSettings();
            OnPropertyChanged();
        }
    }

    public bool IsHookInstalled => _hookInstalled;
    public bool IsVoiceActive => _phase == VoicePhase.Listening;
    public bool IsTranscribing => _phase == VoicePhase.Transcribing;
    public bool IsPasting => _phase == VoicePhase.Pasting;
    public bool IsMappingActive => Settings.MappingEnabled && _hookInstalled;
    public string MappingStatusText => IsMappingActive ? "监听中" : "已暂停";
    public string MappingStatusDetail => IsMappingActive
        ? "中键事件已被 MiddleFlow 接管"
        : "中键保持普通行为";
    public string HookStatusText => _hookInstalled ? "已安装" : "未安装";
    public string HookStatusDetail => string.IsNullOrWhiteSpace(_hookError)
        ? "全局低层鼠标钩子"
        : _hookError;
    public string VoiceStatusText => _phase switch
    {
        VoicePhase.Listening => "正在听写",
        VoicePhase.Transcribing => "正在整理",
        VoicePhase.Pasting => "正在粘贴",
        _ => "待机"
    };
    public string VoiceModeText => _mode switch
    {
        VoiceMode.Overlay => "画布浮层",
        VoiceMode.Direct => "直接输入",
        _ => "待机"
    };
    public string LastEvent => _lastEvent;
    public int MappedClicks => _mappedClicks;
    public int DoubleClicks => _doubleClicks;
    public string LogTail => _logTail;
    public string SettingsPath => Paths.SettingsPath;
    public string DiagnosticsPath => Paths.DiagnosticsPath;
    public string DataDirectory => Paths.LocalRoot;
    public string AppVersion => $"v{ProductVersion}";
    public string ClipboardStatusText => Settings.AutoPaste
        ? "转写完成后自动粘贴"
        : "只复制，不自动粘贴";

    public DoubaoStatus DoubaoStatus => _doubaoStatus;
    public bool DoubaoReady => _doubaoStatus.IsReady;
    public bool DoubaoNeedsAttention => !_doubaoStatus.IsReady;
    public string DoubaoStateTitle => _doubaoStatus.Readiness switch
    {
        DoubaoReadiness.Ready => "已就绪",
        DoubaoReadiness.Missing => "未安装",
        DoubaoReadiness.InstalledNotRegistered => "需要注册",
        DoubaoReadiness.RegisteredNotSelected => "需要切换",
        _ => "未检测"
    };
    public string DoubaoStateDetail => _doubaoStatus.Message;
    public string DoubaoVersionText => string.IsNullOrWhiteSpace(_doubaoStatus.Version)
        ? "未检测到版本"
        : $"版本 {_doubaoStatus.Version}";
    public string DoubaoInstallPathText => string.IsNullOrWhiteSpace(_doubaoStatus.InstallPath)
        ? "未检测到安装目录"
        : _doubaoStatus.InstallPath!;

    public void Start(MainWindow mainWindow)
    {
        _mainWindow = mainWindow;
        var firstRun = !Settings.FirstRunCompleted;
        _tray = new TrayService(this);
        _tray.Initialize();
        StartHook();
        SyncStartupSetting();
        Settings.FirstRunCompleted = true;
        SaveSettings();
        Diagnostics.Write("APP_START", $"version={ProductVersion} mapping={Settings.MappingEnabled}");
        if (firstRun && Settings.ShowTrayNotifications)
        {
            _tray.ShowInfo("MiddleFlow 已启动", "中键映射已准备就绪。");
        }
        UpdateRuntime();
    }

    public void ShowSettings()
    {
        if (_mainWindow is null)
        {
            return;
        }
        _mainWindow.Show();
        if (_mainWindow.WindowState == WindowState.Minimized)
        {
            _mainWindow.WindowState = WindowState.Normal;
        }
        _mainWindow.Activate();
    }

    public void ShowTestWindow()
    {
        if (_testWindow is { IsVisible: true })
        {
            _testWindow.Activate();
            return;
        }
        _testWindow = new VoiceTestWindow(this);
        _testWindow.Closed += (_, _) => _testWindow = null;
        _testWindow.Show();
        _testWindow.Activate();
        Diagnostics.Write("TEST_WINDOW_OPENED");
    }

    public void PauseMapping()
    {
        MappingEnabled = false;
    }

    public void ResumeMapping()
    {
        MappingEnabled = true;
    }

    public void RefreshDoubaoStatus()
    {
        _doubaoStatus = DoubaoDetector.Detect();
        OnPropertiesChanged(
            nameof(DoubaoStatus),
            nameof(DoubaoReady),
            nameof(DoubaoNeedsAttention),
            nameof(DoubaoStateTitle),
            nameof(DoubaoStateDetail),
            nameof(DoubaoVersionText),
            nameof(DoubaoInstallPathText));
        Diagnostics.Write(
            "DOUBAO_CHECK",
            $"readiness={_doubaoStatus.Readiness} version={_doubaoStatus.Version ?? "unknown"}");
    }

    public void RefreshLog()
    {
        _logTail = Diagnostics.Tail();
        OnPropertyChanged(nameof(LogTail));
    }

    public void RequestExit()
    {
        Dispose();
        _mainWindow?.ForceClose();
        Application.Current.Shutdown();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;
        _pasteSession++;
        _overlaySession++;
        _transcriptionTimer?.Stop();
        _transcriptionTimer = null;
        _keyboard.ReleaseAll();
        CloseOverlayWithoutCallback();
        _hook?.Dispose();
        _hook = null;
        _hookInstalled = false;
        _tray?.Dispose();
        _tray = null;
        Diagnostics.Write("APP_STOP");
    }

    private void StartHook()
    {
        try
        {
            _hook = new MouseHookService(_dispatcher);
            _hook.Enabled = Settings.MappingEnabled;
            _hook.MiddleClick += OnMiddleClick;
            _hook.Start();
            _hookInstalled = true;
            _hookError = string.Empty;
            Diagnostics.Write("HOOK_INSTALLED");
        }
        catch (Exception ex)
        {
            _hookInstalled = false;
            _hookError = ex.Message;
            Diagnostics.Write("HOOK_INSTALL_FAILED", ex.Message);
            _tray?.ShowError("无法启动中键映射", ex.Message);
        }
        OnPropertiesChanged(
            nameof(IsHookInstalled),
            nameof(IsMappingActive),
            nameof(HookStatusText),
            nameof(HookStatusDetail),
            nameof(MappingStatusText),
            nameof(MappingStatusDetail));
    }

    private void ApplyMappingState()
    {
        if (_hook is not null)
        {
            _hook.Enabled = Settings.MappingEnabled;
        }
        if (!Settings.MappingEnabled)
        {
            _gestures.Reset();
            CancelVoice();
        }
        OnPropertiesChanged(
            nameof(IsMappingActive),
            nameof(MappingStatusText),
            nameof(MappingStatusDetail));
        UpdateRuntime();
    }

    private void OnMiddleClick(object? sender, MiddleClickEventArgs e)
    {
        if (!Settings.MappingEnabled || !_hookInstalled)
        {
            return;
        }

        if (_phase is VoicePhase.Transcribing or VoicePhase.Pasting)
        {
            Diagnostics.Write("CLICK_IGNORED_TRANSITION", _phase.ToString());
            return;
        }

        var gesture = Settings.DoubleClickEnabled
            ? _gestures.Register(Environment.TickCount64, Settings.DoubleClickIntervalMs)
            : MouseGestureKind.Single;
        if (!Settings.DoubleClickEnabled)
        {
            _gestures.Reset();
        }

        if (gesture == MouseGestureKind.Double)
        {
            _doubleClicks++;
            HandleDoubleClick(e);
        }
        else
        {
            _mappedClicks++;
            HandleSingleClick(e);
        }
        OnPropertiesChanged(nameof(MappedClicks), nameof(DoubleClicks));
        UpdateRuntime();
    }

    private void HandleSingleClick(MiddleClickEventArgs e)
    {
        if (_phase == VoicePhase.Listening)
        {
            if (_mode == VoiceMode.Overlay)
            {
                StopOverlayVoice(pendingReturn: false);
            }
            else
            {
                StopDirectVoice();
            }
            return;
        }

        if (_phase != VoicePhase.Idle)
        {
            return;
        }

        var target = _targets.Describe(e.ForegroundWindow);
        if (target.IsEmpty)
        {
            target = _targets.Foreground();
        }
        var canvas = Settings.OverlayEnabled &&
                     TargetPolicy.IsCanvasTarget(
                         target.ProcessName,
                         target.WindowTitle,
                         Settings.CanvasAppPatterns);
        if (canvas)
        {
            StartOverlayVoice(target, e.Point);
        }
        else if (Settings.DirectModeEnabled)
        {
            StartDirectVoice(target, e.Point);
        }
        else
        {
            SetLastEvent("当前目标未启用直接输入");
        }
    }

    private void HandleDoubleClick(MiddleClickEventArgs e)
    {
        if (_phase == VoicePhase.Listening)
        {
            if (_mode == VoiceMode.Overlay)
            {
                StopOverlayVoice(pendingReturn: true);
            }
            else
            {
                var target = _voiceTarget;
                _keyboard.ReleaseRightAlt();
                _phase = VoicePhase.Idle;
                _mode = VoiceMode.None;
                _voiceTarget = null;
                _voiceClickPoint = null;
                SetLastEvent("语音已停止，准备发送回车");
                _ = SendReturnAfterDirectAsync(target);
            }
            return;
        }

        if (_phase == VoicePhase.Idle && Settings.DoubleClickEnabled)
        {
            var target = _targets.Describe(e.ForegroundWindow);
            _ = SendReturnAfterDirectAsync(target, delayMs: 0);
            SetLastEvent("双击：已发送回车");
        }
    }

    private void StartDirectVoice(WindowTarget target, MousePoint point)
    {
        if (!_keyboard.PressRightAlt())
        {
            FailSession("无法发送右侧 Alt，请检查系统输入权限。");
            return;
        }
        _voiceTarget = target;
        _voiceClickPoint = point;
        _mode = VoiceMode.Direct;
        _phase = VoicePhase.Listening;
        _pendingReturn = false;
        SetLastEvent("直接输入：正在听写");
        Diagnostics.Write(
            "VOICE_START",
            $"mode=direct process={target.ProcessName} chars=0");
        UpdateRuntime();
    }

    private void StopDirectVoice()
    {
        _keyboard.ReleaseRightAlt();
        _phase = VoicePhase.Idle;
        _mode = VoiceMode.None;
        _voiceTarget = null;
        _voiceClickPoint = null;
        SetLastEvent("语音已停止");
        Diagnostics.Write("VOICE_STOP", "mode=direct");
        UpdateRuntime();
    }

    private void StartOverlayVoice(WindowTarget target, MousePoint point)
    {
        var window = new VoiceComposerWindow();
        window.SetTarget(target);
        window.SetState(VoiceOverlayState.Listening);
        window.TextChangedByUser += OnOverlayTextChanged;
        window.CommitRequested += OnOverlayCommitRequested;
        window.CancelRequested += OnOverlayCancelRequested;
        _overlay = window;
        _voiceTarget = target;
        _voiceClickPoint = point;
        _mode = VoiceMode.Overlay;
        _phase = VoicePhase.Listening;
        _pendingReturn = false;
        var session = ++_overlaySession;
        window.Show();
        window.Activate();
        window.FocusEditor();
        _dispatcher.BeginInvoke(
            DispatcherPriority.Input,
            new Action(() =>
            {
                if (_overlay != window || _phase != VoicePhase.Listening || session != _overlaySession)
                {
                    return;
                }
                window.FocusEditor();
                if (!_keyboard.PressRightAlt())
                {
                    FailSession("无法发送右侧 Alt，请检查系统输入权限。");
                }
            }));
        SetLastEvent("画布浮层：正在听写");
        Diagnostics.Write(
            "VOICE_START",
            $"mode=overlay process={target.ProcessName} chars=0");
        UpdateRuntime();
    }

    private void StopOverlayVoice(bool pendingReturn)
    {
        if (_overlay is null || _phase != VoicePhase.Listening)
        {
            return;
        }
        _keyboard.ReleaseRightAlt();
        _pendingReturn = pendingReturn;
        _phase = VoicePhase.Transcribing;
        _overlay.SetState(VoiceOverlayState.Transcribing);
        _stabilizer.Start(Environment.TickCount64);
        StartTranscriptionTimer();
        SetLastEvent(pendingReturn ? "正在整理并准备发送" : "正在整理文字");
        Diagnostics.Write("VOICE_STOP", $"mode=overlay return={pendingReturn}");
        UpdateRuntime();
    }

    private void OnOverlayTextChanged(object? sender, string text)
    {
        if (_phase == VoicePhase.Listening)
        {
            SetLastEvent("正在接收豆包转写");
        }
    }

    private void OnOverlayCommitRequested(object? sender, EventArgs e)
    {
        if (_phase == VoicePhase.Listening)
        {
            StopOverlayVoice(pendingReturn: false);
        }
    }

    private void OnOverlayCancelRequested(object? sender, EventArgs e)
    {
        CancelVoice();
    }

    private void StartTranscriptionTimer()
    {
        _transcriptionTimer?.Stop();
        var timer = new DispatcherTimer(
            DispatcherPriority.Background,
            _dispatcher)
        {
            Interval = TimeSpan.FromMilliseconds(65)
        };
        timer.Tick += (_, _) => EvaluateTranscription();
        _transcriptionTimer = timer;
        timer.Start();
    }

    private void EvaluateTranscription()
    {
        if (_phase != VoicePhase.Transcribing || _overlay is null)
        {
            _transcriptionTimer?.Stop();
            _transcriptionTimer = null;
            return;
        }

        var decision = _stabilizer.Evaluate(
            _overlay.TranscriptText,
            Environment.TickCount64);
        if (decision == TranscriptDecision.Ready)
        {
            _transcriptionTimer?.Stop();
            _transcriptionTimer = null;
            var text = _overlay.CommitAndGetText();
            _ = FinishOverlayPasteAsync(text, _pendingReturn);
        }
        else if (decision == TranscriptDecision.Empty)
        {
            _transcriptionTimer?.Stop();
            _transcriptionTimer = null;
            FailSession("没有收到文字，请重试。");
        }
    }

    private async Task FinishOverlayPasteAsync(string text, bool pendingReturn)
    {
        var overlay = _overlay;
        var target = _voiceTarget;
        var clickPoint = _voiceClickPoint;
        if (overlay is null || target is null || _phase != VoicePhase.Transcribing)
        {
            return;
        }

        text = text.Trim();
        if (text.Length == 0)
        {
            FailSession("没有收到文字，请重试。");
            return;
        }

        var snapshot = _clipboard.Capture();
        if (!_clipboard.TrySetText(text))
        {
            FailSession("剪贴板正忙，请稍后重试。");
            return;
        }

        _phase = VoicePhase.Pasting;
        overlay.SetState(VoiceOverlayState.Pasting);
        SetLastEvent("正在粘贴到目标应用");
        Diagnostics.Write("TRANSCRIPT_READY", $"chars={text.Length}");
        UpdateRuntime();

        overlay.CloseWithoutCallback();
        _overlay = null;
        _voiceTarget = null;
        var pasteSession = ++_pasteSession;

        if (!Settings.AutoPaste)
        {
            CompletePasteCycle(
                snapshot,
                text,
                "已复制，按 Ctrl+V 粘贴",
                restoreClipboard: false);
            return;
        }

        await Task.Delay(45);
        if (pasteSession != _pasteSession)
        {
            return;
        }
        _targets.Activate(target.Handle);
        await Task.Delay(35);
        if (clickPoint is not null)
        {
            _targets.ClickAt(clickPoint);
            await Task.Delay(35);
        }
        if (pasteSession != _pasteSession)
        {
            return;
        }

        if (!_keyboard.SendPaste())
        {
            CompletePasteCycle(
                snapshot,
                text,
                "粘贴未发送，内容已复制",
                restoreClipboard: false);
            return;
        }

        if (pendingReturn || Settings.PasteThenEnter)
        {
            await Task.Delay(90);
            if (pasteSession == _pasteSession)
            {
                _keyboard.SendReturn();
                SetLastEvent("已粘贴并发送回车");
            }
        }
        else
        {
            SetLastEvent("已粘贴到目标应用");
        }
        CompletePasteCycle(snapshot, text, null);
    }

    private void CompletePasteCycle(
        ClipboardSnapshot snapshot,
        string transcript,
        string? message,
        bool restoreClipboard = true)
    {
        _phase = VoicePhase.Idle;
        _mode = VoiceMode.None;
        _pendingReturn = false;
        _voiceClickPoint = null;
        if (!string.IsNullOrWhiteSpace(message))
        {
            SetLastEvent(message);
            _tray?.ShowInfo("MiddleFlow", message);
        }
        UpdateRuntime();
        if (restoreClipboard && Settings.RestoreClipboard)
        {
            _ = RestoreClipboardLaterAsync(snapshot, transcript);
        }
    }

    private async Task RestoreClipboardLaterAsync(
        ClipboardSnapshot snapshot,
        string transcript)
    {
        await Task.Delay(Settings.ClipboardRestoreDelayMs);
        _clipboard.RestoreIfCurrent(snapshot, transcript);
    }

    private async Task SendReturnAfterDirectAsync(
        WindowTarget? target,
        int delayMs = 300)
    {
        if (delayMs > 0)
        {
            await Task.Delay(delayMs);
        }
        if (_phase != VoicePhase.Idle)
        {
            return;
        }
        if (target is not null && !target.IsEmpty)
        {
            _targets.Activate(target.Handle);
            await Task.Delay(55);
        }
        if (_phase != VoicePhase.Idle)
        {
            return;
        }
        if (_keyboard.SendReturn())
        {
            SetLastEvent("已发送回车");
            Diagnostics.Write("RETURN_SENT", "mode=direct");
        }
        else
        {
            SetLastEvent("回车发送失败");
        }
    }

    private void FailSession(string message)
    {
        _pasteSession++;
        _transcriptionTimer?.Stop();
        _transcriptionTimer = null;
        _keyboard.ReleaseRightAlt();
        _phase = VoicePhase.Idle;
        _mode = VoiceMode.None;
        _pendingReturn = false;
        _voiceClickPoint = null;
        CloseOverlayWithoutCallback();
        SetLastEvent(message);
        Diagnostics.Write("SESSION_FAILED", message);
        _tray?.ShowError("MiddleFlow", message);
        UpdateRuntime();
    }

    private void CancelVoice()
    {
        _pasteSession++;
        _transcriptionTimer?.Stop();
        _transcriptionTimer = null;
        _keyboard.ReleaseRightAlt();
        _phase = VoicePhase.Idle;
        _mode = VoiceMode.None;
        _pendingReturn = false;
        _voiceClickPoint = null;
        CloseOverlayWithoutCallback();
        _voiceTarget = null;
        SetLastEvent("已取消本次语音");
        Diagnostics.Write("VOICE_CANCELLED");
        UpdateRuntime();
    }

    private void CloseOverlayWithoutCallback()
    {
        var overlay = _overlay;
        _overlay = null;
        overlay?.CloseWithoutCallback();
    }

    private void SetLastEvent(string message)
    {
        _lastEvent = message;
        OnPropertyChanged(nameof(LastEvent));
    }

    private void UpdateRuntime()
    {
        OnPropertiesChanged(
            nameof(IsVoiceActive),
            nameof(IsTranscribing),
            nameof(IsPasting),
            nameof(IsMappingActive),
            nameof(MappingStatusText),
            nameof(MappingStatusDetail),
            nameof(VoiceStatusText),
            nameof(VoiceModeText),
            nameof(ClipboardStatusText));
    }

    private void SaveSettings()
    {
        try
        {
            _settingsStore.Save(Settings);
        }
        catch (Exception ex)
        {
            SetLastEvent($"设置保存失败：{ex.Message}");
            Diagnostics.Write("SETTINGS_SAVE_FAILED", ex.Message);
        }
    }

    private void SyncStartupSetting()
    {
        if (Settings.StartAtLogin)
        {
            _startup.SetEnabled(true);
        }
        else
        {
            _startup.SetEnabled(false);
        }
    }

    private void OpenDoubaoDownload()
    {
        OpenUri(DoubaoDetector.DownloadUrl);
    }

    private void OpenKeyboardSettings()
    {
        if (!OpenSettingsUri("ms-settings:keyboard"))
        {
            OpenSettingsUri("ms-settings:language");
        }
    }

    private void OpenDataFolder()
    {
        Paths.EnsureCreated();
        OpenShell(Paths.LocalRoot);
    }

    private void OpenLog()
    {
        Paths.EnsureCreated();
        if (File.Exists(Paths.DiagnosticsPath))
        {
            OpenShell(Paths.DiagnosticsPath);
        }
        else
        {
            OpenDataFolder();
        }
    }

    private void ClearLog()
    {
        Diagnostics.Clear();
        RefreshLog();
    }

    private void CopyDiagnostics()
    {
        _clipboard.TrySetText(LogTail);
        _tray?.ShowInfo("MiddleFlow", "诊断信息已复制。");
    }

    private void ResetSettings()
    {
        var defaults = new AppSettings();
        defaults.Normalize();
        Settings.MappingEnabled = defaults.MappingEnabled;
        Settings.DoubleClickEnabled = defaults.DoubleClickEnabled;
        Settings.DoubleClickIntervalMs = defaults.DoubleClickIntervalMs;
        Settings.OverlayEnabled = defaults.OverlayEnabled;
        Settings.DirectModeEnabled = defaults.DirectModeEnabled;
        Settings.AutoPaste = defaults.AutoPaste;
        Settings.PasteThenEnter = defaults.PasteThenEnter;
        Settings.RestoreClipboard = defaults.RestoreClipboard;
        Settings.ClipboardRestoreDelayMs = defaults.ClipboardRestoreDelayMs;
        Settings.StartAtLogin = false;
        Settings.ShowTrayNotifications = defaults.ShowTrayNotifications;
        Settings.CanvasAppPatterns = defaults.CanvasAppPatterns;
        Settings.VoiceShortcut = defaults.VoiceShortcut;
        Settings.FirstRunCompleted = true;
        _startup.SetEnabled(false);
        SaveSettings();
        ApplyMappingState();
        OnPropertiesChanged(
            nameof(MappingEnabled),
            nameof(DoubleClickEnabled),
            nameof(DoubleClickIntervalMs),
            nameof(OverlayEnabled),
            nameof(DirectModeEnabled),
            nameof(AutoPaste),
            nameof(PasteThenEnter),
            nameof(RestoreClipboard),
            nameof(StartAtLogin),
            nameof(ShowTrayNotifications),
            nameof(CanvasAppPatterns),
            nameof(DoubleClickIntervalLabel),
            nameof(ClipboardStatusText));
    }

    private void OpenUri(string uri)
    {
        try
        {
            Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            SetLastEvent($"无法打开链接：{ex.Message}");
        }
    }

    private bool OpenSettingsUri(string uri)
    {
        try
        {
            Process.Start(new ProcessStartInfo(uri) { UseShellExecute = true });
            return true;
        }
        catch
        {
            return false;
        }
    }

    private void OpenShell(string path)
    {
        try
        {
            Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            SetLastEvent($"无法打开路径：{ex.Message}");
        }
    }
}
