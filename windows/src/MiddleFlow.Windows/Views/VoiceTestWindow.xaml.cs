using System.Windows;
using System.Windows.Controls;
using MiddleFlow.Windows.ViewModels;

namespace MiddleFlow.Windows.Views;

public partial class VoiceTestWindow : Window
{
    public VoiceTestWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        Loaded += (_, _) => FocusTestBox();
        Activated += (_, _) => FocusTestBox();
    }

    private void FocusButton_Click(object sender, RoutedEventArgs e)
    {
        FocusTestBox();
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private void TestBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        Placeholder.Visibility = string.IsNullOrEmpty(TestBox.Text)
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void FocusTestBox()
    {
        TestBox.Focus();
        TestBox.CaretIndex = TestBox.Text.Length;
    }
}
