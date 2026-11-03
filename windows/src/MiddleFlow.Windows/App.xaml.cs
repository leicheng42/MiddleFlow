using System.Threading;
using System.Windows;
using System.Windows.Threading;
using MiddleFlow.Core.Models;
using MiddleFlow.Core.Services;
using MiddleFlow.Windows.Services;
using MiddleFlow.Windows.ViewModels;

namespace MiddleFlow.Windows;

public partial class App : Application
{
    private Mutex? _singleInstance;
    private MainViewModel? _viewModel;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _singleInstance = new Mutex(
            initiallyOwned: true,
            name: @"Local\MiddleFlow.Windows",
            createdNew: out var createdNew);
        if (!createdNew)
        {
            MessageBox.Show(
                "MiddleFlow 已经在运行，请从系统托盘打开设置。",
                "MiddleFlow",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            Shutdown();
            return;
        }

        DispatcherUnhandledException += OnDispatcherUnhandledException;

        var paths = new AppPaths();
        paths.EnsureCreated();
        var diagnostics = new DiagnosticsLog(paths.DiagnosticsPath, paths.DiagnosticsArchivePath);
        var settingsStore = new SettingsStore(paths.SettingsPath);
        var startup = new StartupService();
        _viewModel = new MainViewModel(
            paths,
            diagnostics,
            settingsStore,
            startup,
            Dispatcher);
        var window = new MainWindow(_viewModel);
        MainWindow = window;
        window.Show();
        _viewModel.Start(window);

        if (e.Args.Any(argument =>
                string.Equals(argument, "--background", StringComparison.OrdinalIgnoreCase)))
        {
            window.Hide();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _viewModel?.Dispose();
        if (_singleInstance is not null)
        {
            try
            {
                _singleInstance.ReleaseMutex();
            }
            catch
            {
            }
            _singleInstance.Dispose();
            _singleInstance = null;
        }
        base.OnExit(e);
    }

    private void OnDispatcherUnhandledException(
        object sender,
        DispatcherUnhandledExceptionEventArgs e)
    {
        _viewModel?.Diagnostics.Write("UNHANDLED_EXCEPTION", e.Exception.GetType().Name);
        MessageBox.Show(
            "MiddleFlow 遇到一个未处理错误，已记录到诊断日志。\n\n" + e.Exception.Message,
            "MiddleFlow",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }
}
