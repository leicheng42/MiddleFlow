using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using MiddleFlow.Windows.Services;
using Color = System.Windows.Media.Color;

namespace MiddleFlow.Windows.Views;

public enum VoiceOverlayState
{
    Listening,
    Transcribing,
    Pasting,
    Error
}

public partial class VoiceComposerWindow : Window
{
    private bool _allowClose;
    private WindowTarget? _target;
    private string _compositionText = string.Empty;
    private string _textBeforeComposition = string.Empty;

    public VoiceComposerWindow()
    {
        InitializeComponent();
        TextCompositionManager.AddPreviewTextInputStartHandler(
            Editor,
            Editor_PreviewTextInputStart);
        TextCompositionManager.AddPreviewTextInputUpdateHandler(
            Editor,
            Editor_PreviewTextInputUpdate);
        TextCompositionManager.AddPreviewTextInputHandler(
            Editor,
            Editor_PreviewTextInput);
        Loaded += VoiceComposerWindow_Loaded;
        Closing += VoiceComposerWindow_Closing;
    }

    public event EventHandler<string>? TextChangedByUser;
    public event EventHandler? CommitRequested;
    public event EventHandler? CancelRequested;

    public string Text => TranscriptText;

    public string TranscriptText
    {
        get
        {
            if (string.IsNullOrEmpty(_compositionText))
            {
                return Editor.Text;
            }
            if (Editor.Text.Contains(_compositionText, StringComparison.Ordinal))
            {
                return Editor.Text;
            }
            return _textBeforeComposition + _compositionText;
        }
    }

    public WindowTarget? Target => _target;

    public void SetTarget(WindowTarget target)
    {
        _target = target;
        PositionNearTarget(target);
    }

    public void SetState(VoiceOverlayState state)
    {
        switch (state)
        {
            case VoiceOverlayState.Listening:
                StatusPill.Background = new SolidColorBrush(Color.FromRgb(0xEA, 0xF7, 0xF0));
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(0x2E, 0x9B, 0x70));
                StatusText.Foreground = new SolidColorBrush(Color.FromRgb(0x23, 0x76, 0x53));
                StatusText.Text = "正在听写";
                CommitButton.IsEnabled = true;
                Editor.IsReadOnly = false;
                break;
            case VoiceOverlayState.Transcribing:
                StatusPill.Background = new SolidColorBrush(Color.FromRgb(0xFF, 0xF6, 0xE7));
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(0xC4, 0x7A, 0x1D));
                StatusText.Foreground = new SolidColorBrush(Color.FromRgb(0x8B, 0x5A, 0x16));
                StatusText.Text = "正在整理文字";
                CommitButton.IsEnabled = false;
                Editor.IsReadOnly = true;
                break;
            case VoiceOverlayState.Pasting:
                StatusPill.Background = new SolidColorBrush(Color.FromRgb(0xFF, 0xF0, 0xE9));
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(0xF2, 0x6A, 0x3D));
                StatusText.Foreground = new SolidColorBrush(Color.FromRgb(0xB6, 0x48, 0x23));
                StatusText.Text = "正在粘贴";
                CommitButton.IsEnabled = false;
                Editor.IsReadOnly = true;
                break;
            case VoiceOverlayState.Error:
                StatusPill.Background = new SolidColorBrush(Color.FromRgb(0xFD, 0xEE, 0xEE));
                StatusDot.Fill = new SolidColorBrush(Color.FromRgb(0xC8, 0x4E, 0x4E));
                StatusText.Foreground = new SolidColorBrush(Color.FromRgb(0x9C, 0x35, 0x35));
                StatusText.Text = "需要重试";
                CommitButton.IsEnabled = true;
                Editor.IsReadOnly = false;
                break;
        }
    }

    public string CommitAndGetText()
    {
        // Moving focus away from the editor commits the IME composition in WPF.
        CommitButton.Focus();
        Dispatcher.Invoke(() => { }, DispatcherPriority.Input);
        Editor.Focus();
        return TranscriptText;
    }

    public void CloseWithoutCallback()
    {
        _allowClose = true;
        Close();
    }

    public void FocusEditor()
    {
        Editor.Focus();
        Keyboard.Focus(Editor);
        Editor.CaretIndex = Editor.Text.Length;
    }

    private void VoiceComposerWindow_Loaded(object sender, RoutedEventArgs e)
    {
        FocusEditor();
        if (_target is not null)
        {
            PositionNearTarget(_target);
        }
    }

    private void PositionNearTarget(WindowTarget target)
    {
        if (!IsLoaded || target.IsEmpty)
        {
            return;
        }
        var dpi = VisualTreeHelper.GetDpi(this);
        var point = new System.Windows.Point(
            (target.Bounds.Left + target.Bounds.Width / 2.0) / dpi.DpiScaleX,
            target.Bounds.Bottom / dpi.DpiScaleY + 18);
        var screen = System.Windows.Forms.Screen.FromPoint(
            new System.Drawing.Point(
                target.Bounds.Left + target.Bounds.Width / 2,
                target.Bounds.Bottom));
        var work = screen.WorkingArea;
        var width = ActualWidth > 0 ? ActualWidth : Width;
        var height = ActualHeight > 0 ? ActualHeight : Height;
        var left = Math.Clamp(point.X - width / 2, work.Left / dpi.DpiScaleX, (work.Right / dpi.DpiScaleX) - width);
        var top = Math.Clamp(point.Y, work.Top / dpi.DpiScaleY, (work.Bottom / dpi.DpiScaleY) - height);
        Left = left;
        Top = top;
    }

    private void Editor_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
    {
        Placeholder.Visibility = string.IsNullOrEmpty(Editor.Text)
            ? Visibility.Visible
            : Visibility.Collapsed;
        TextChangedByUser?.Invoke(this, TranscriptText);
    }

    private void Editor_PreviewTextInputStart(object sender, TextCompositionEventArgs e)
    {
        _textBeforeComposition = Editor.Text;
        _compositionText = e.Text ?? string.Empty;
        TextChangedByUser?.Invoke(this, TranscriptText);
    }

    private void Editor_PreviewTextInputUpdate(object sender, TextCompositionEventArgs e)
    {
        _compositionText = e.Text ?? string.Empty;
        TextChangedByUser?.Invoke(this, TranscriptText);
    }

    private void Editor_PreviewTextInput(object sender, TextCompositionEventArgs e)
    {
        _compositionText = e.Text ?? string.Empty;
        TextChangedByUser?.Invoke(this, TranscriptText);
    }

    private void Editor_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            CancelRequested?.Invoke(this, EventArgs.Empty);
        }
        else if (e.Key == Key.Enter && Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
        {
            e.Handled = true;
            CommitRequested?.Invoke(this, EventArgs.Empty);
        }
    }

    private void CommitButton_Click(object sender, RoutedEventArgs e)
    {
        CommitRequested?.Invoke(this, EventArgs.Empty);
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        CancelRequested?.Invoke(this, EventArgs.Empty);
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        CancelRequested?.Invoke(this, EventArgs.Empty);
    }

    private void VoiceComposerWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (!_allowClose)
        {
            e.Cancel = true;
            Dispatcher.BeginInvoke(
                DispatcherPriority.Input,
                new Action(() => CancelRequested?.Invoke(this, EventArgs.Empty)));
        }
    }
}
