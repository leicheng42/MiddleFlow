using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using MiddleFlow.Windows.ViewModels;

namespace MiddleFlow.Windows.Services;

public sealed class TrayService : IDisposable
{
    private readonly MainViewModel _viewModel;
    private NotifyIcon? _notifyIcon;
    private Icon? _icon;
    private ToolStripMenuItem? _mappingItem;
    private bool _disposed;

    public TrayService(MainViewModel viewModel)
    {
        _viewModel = viewModel;
    }

    public void Initialize()
    {
        if (_notifyIcon is not null)
        {
            return;
        }

        _icon = LoadApplicationIcon();
        var menu = new ContextMenuStrip
        {
            ShowImageMargin = false,
            Font = new Font("Segoe UI", 9.5f)
        };
        menu.Opening += (_, _) => RefreshMenu();

        var openItem = new ToolStripMenuItem("打开 MiddleFlow");
        openItem.Click += (_, _) => _viewModel.ShowSettings();
        menu.Items.Add(openItem);

        var testItem = new ToolStripMenuItem("打开语音测试窗口");
        testItem.Click += (_, _) => _viewModel.ShowTestWindow();
        menu.Items.Add(testItem);

        menu.Items.Add(new ToolStripSeparator());

        _mappingItem = new ToolStripMenuItem("暂停中键映射");
        _mappingItem.Click += (_, _) =>
        {
            _viewModel.MappingEnabled = !_viewModel.MappingEnabled;
            RefreshMenu();
        };
        menu.Items.Add(_mappingItem);

        menu.Items.Add(new ToolStripSeparator());

        var exitItem = new ToolStripMenuItem("退出 MiddleFlow");
        exitItem.Click += (_, _) => _viewModel.RequestExit();
        menu.Items.Add(exitItem);

        _notifyIcon = new NotifyIcon
        {
            Icon = _icon,
            Text = "MiddleFlow",
            Visible = true,
            ContextMenuStrip = menu
        };
        _notifyIcon.DoubleClick += (_, _) => _viewModel.ShowSettings();
        RefreshMenu();
    }

    public void ShowInfo(string title, string message)
    {
        if (!_viewModel.ShowTrayNotifications || _notifyIcon is null)
        {
            return;
        }
        _notifyIcon.BalloonTipTitle = title;
        _notifyIcon.BalloonTipText = message;
        _notifyIcon.BalloonTipIcon = ToolTipIcon.Info;
        _notifyIcon.ShowBalloonTip(2600);
    }

    public void ShowError(string title, string message)
    {
        if (_notifyIcon is null)
        {
            return;
        }
        _notifyIcon.BalloonTipTitle = title;
        _notifyIcon.BalloonTipText = message;
        _notifyIcon.BalloonTipIcon = ToolTipIcon.Warning;
        _notifyIcon.ShowBalloonTip(3200);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;
        if (_notifyIcon is not null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.ContextMenuStrip?.Dispose();
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }
        _icon?.Dispose();
        _icon = null;
    }

    private void RefreshMenu()
    {
        if (_mappingItem is null)
        {
            return;
        }
        _mappingItem.Text = _viewModel.MappingEnabled
            ? "暂停中键映射"
            : "启用中键映射";
        _mappingItem.Checked = _viewModel.MappingEnabled;
    }

    private static Icon LoadApplicationIcon()
    {
        foreach (var candidate in ApplicationIconCandidates())
        {
            try
            {
                if (!File.Exists(candidate))
                {
                    continue;
                }
                var extracted = Icon.ExtractAssociatedIcon(candidate);
                if (extracted is not null)
                {
                    return extracted;
                }
            }
            catch
            {
            }
        }
        return CreateFallbackIcon();
    }

    private static IEnumerable<string> ApplicationIconCandidates()
    {
        if (!string.IsNullOrWhiteSpace(Environment.ProcessPath) &&
            Path.GetFileName(Environment.ProcessPath)
                .Contains("MiddleFlow", StringComparison.OrdinalIgnoreCase))
        {
            yield return Environment.ProcessPath;
        }
        yield return Path.Combine(AppContext.BaseDirectory, "MiddleFlow.exe");
    }

    private static Icon CreateFallbackIcon()
    {
        using var bitmap = new Bitmap(32, 32, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var background = new SolidBrush(Color.FromArgb(242, 106, 61));
        using var path = RoundedRectangle(new RectangleF(2, 2, 28, 28), 8);
        graphics.FillPath(background, path);

        using var white = new SolidBrush(Color.White);
        var heights = new[] { 8, 16, 22, 12, 18, 9 };
        for (var index = 0; index < heights.Length; index++)
        {
            var height = heights[index];
            graphics.FillRectangle(
                white,
                7 + index * 3.1f,
                16 - height / 2f,
                1.7f,
                height);
        }

        var handle = bitmap.GetHicon();
        try
        {
            using var source = Icon.FromHandle(handle);
            return (Icon)source.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    private static GraphicsPath RoundedRectangle(RectangleF rectangle, float radius)
    {
        var diameter = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    [DllImport("user32.dll")]
    private static extern bool DestroyIcon(IntPtr handle);
}
