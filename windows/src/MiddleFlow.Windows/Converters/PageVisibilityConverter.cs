using System.Globalization;
using System.Windows;
using System.Windows.Data;
using MiddleFlow.Windows.ViewModels;

namespace MiddleFlow.Windows.Converters;

public sealed class PageVisibilityConverter : IValueConverter
{
    public object Convert(
        object value,
        Type targetType,
        object parameter,
        CultureInfo culture)
    {
        return value is PageKey current &&
               parameter is string requested &&
               Enum.TryParse<PageKey>(requested, out var page) &&
               current == page
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    public object ConvertBack(
        object value,
        Type targetType,
        object parameter,
        CultureInfo culture)
    {
        return Binding.DoNothing;
    }
}
