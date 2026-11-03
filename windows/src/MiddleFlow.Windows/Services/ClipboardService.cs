using System.Collections.Specialized;
using System.Windows;
using System.Windows.Media.Imaging;

namespace MiddleFlow.Windows.Services;

public sealed class ClipboardSnapshot
{
    public string? Text { get; init; }
    public string? Html { get; init; }
    public string? Rtf { get; init; }
    public string[]? Files { get; init; }
    public BitmapSource? Image { get; init; }

    public bool IsEmpty =>
        Text is null && Html is null && Rtf is null &&
        (Files is null || Files.Length == 0) && Image is null;
}

public sealed class ClipboardService
{
    public ClipboardSnapshot Capture()
    {
        try
        {
            var data = Clipboard.GetDataObject();
            if (data is null)
            {
                return new ClipboardSnapshot();
            }

            BitmapSource? image = null;
            if (data.GetDataPresent(DataFormats.Bitmap))
            {
                if (data.GetData(DataFormats.Bitmap) is BitmapSource source)
                {
                    source.Freeze();
                    image = source;
                }
            }

            return new ClipboardSnapshot
            {
                Text = data.GetDataPresent(DataFormats.UnicodeText)
                    ? data.GetData(DataFormats.UnicodeText) as string
                    : null,
                Html = data.GetDataPresent(DataFormats.Html)
                    ? data.GetData(DataFormats.Html) as string
                    : null,
                Rtf = data.GetDataPresent(DataFormats.Rtf)
                    ? data.GetData(DataFormats.Rtf) as string
                    : null,
                Files = data.GetDataPresent(DataFormats.FileDrop)
                    ? data.GetData(DataFormats.FileDrop) as string[]
                    : null,
                Image = image
            };
        }
        catch
        {
            return new ClipboardSnapshot();
        }
    }

    public bool TrySetText(string text)
    {
        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                Clipboard.SetDataObject(text, true);
                return true;
            }
            catch
            {
                Thread.Sleep(25);
            }
        }
        return false;
    }

    public void RestoreIfCurrent(ClipboardSnapshot snapshot, string expectedText)
    {
        try
        {
            if (!Clipboard.ContainsText() ||
                !string.Equals(Clipboard.GetText(), expectedText, StringComparison.Ordinal))
            {
                return;
            }

            if (snapshot.IsEmpty)
            {
                Clipboard.Clear();
                return;
            }

            var data = new DataObject();
            if (!string.IsNullOrEmpty(snapshot.Text))
            {
                data.SetData(DataFormats.UnicodeText, snapshot.Text);
                data.SetData(DataFormats.Text, snapshot.Text);
            }
            if (!string.IsNullOrEmpty(snapshot.Html))
            {
                data.SetData(DataFormats.Html, snapshot.Html);
            }
            if (!string.IsNullOrEmpty(snapshot.Rtf))
            {
                data.SetData(DataFormats.Rtf, snapshot.Rtf);
            }
            if (snapshot.Files is { Length: > 0 })
            {
                var collection = new StringCollection();
                collection.AddRange(snapshot.Files);
                data.SetFileDropList(collection);
            }
            if (snapshot.Image is not null)
            {
                data.SetImage(snapshot.Image);
            }
            Clipboard.SetDataObject(data, true);
        }
        catch
        {
            // A busy clipboard should not interrupt the user's next action.
        }
    }
}
