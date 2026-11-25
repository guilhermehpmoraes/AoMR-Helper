using System.Drawing.Drawing2D;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.RegularExpressions;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;

namespace AoMR.Helper;

internal enum HudField { Food, Wood, Gold, Favor, Population, Age, Citizens }

internal record HudReading(int? Food, int? Wood, int? Gold, int? Favor, int? Used, int? Cap, int? Age, int? Citizens)
{
    internal bool HasValues => Food.HasValue || Wood.HasValue || Gold.HasValue || Favor.HasValue ||
        Used.HasValue || Age.HasValue || Citizens.HasValue;
}

internal record Zone(double X, double Y, double Width, double Height)
{
    internal Rectangle At(Size size) => Rectangle.Intersect(new Rectangle(Point.Empty, size),
        Rectangle.Round(new RectangleF((float)(X * size.Width), (float)(Y * size.Height),
            (float)(Width * size.Width), (float)(Height * size.Height))));

    internal static Zone From(Rectangle area, Size size) =>
        new((double)area.X / size.Width, (double)area.Y / size.Height,
            (double)area.Width / size.Width, (double)area.Height / size.Height);
}

internal sealed record HudProfile(Size Resolution, Dictionary<HudField, Zone> Zones)
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AoMR Helper", "hud.json");

    internal static HudProfile? Load()
    {
        try
        {
            return File.Exists(FilePath) ? JsonSerializer.Deserialize<HudProfile>(File.ReadAllText(FilePath)) : null;
        }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    internal void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(this));
    }
}

internal static partial class HudCapture
{
    [LibraryImport("user32.dll")] private static partial nint GetForegroundWindow();
    [LibraryImport("user32.dll")] private static partial uint GetWindowThreadProcessId(nint window, out uint processId);
    [LibraryImport("user32.dll")] private static partial int GetClientRect(nint window, out NativeRect rect);
    [LibraryImport("user32.dll")] private static partial int ClientToScreen(nint window, ref NativePoint point);
    [StructLayout(LayoutKind.Sequential)] private struct NativeRect { internal int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct NativePoint { internal int X, Y; }

    internal static Bitmap? Grab()
    {
        var window = GetForegroundWindow();
        if (window == 0) return null;
        GetWindowThreadProcessId(window, out uint processId);
        string name;
        try
        {
            using var process = System.Diagnostics.Process.GetProcessById((int)processId);
            name = process.ProcessName;
        }
        catch (ArgumentException) { return null; }
        if (!name.StartsWith("AoMRT", StringComparison.OrdinalIgnoreCase)) return null;

        var origin = new NativePoint();
        if (GetClientRect(window, out var bounds) == 0 || ClientToScreen(window, ref origin) == 0)
            return null;
        var size = new Size(bounds.Right - bounds.Left, bounds.Bottom - bounds.Top);
        if (size.Width < 320 || size.Height < 200) return null;
        var bitmap = new Bitmap(size.Width, size.Height);
        try
        {
            using var graphics = Graphics.FromImage(bitmap);
            graphics.CopyFromScreen(origin.X, origin.Y, 0, 0, size);
            return bitmap;
        }
        catch
        {
            bitmap.Dispose();
            throw;
        }
    }
}

internal sealed partial class HudReader
{
    private OcrEngine? _engine;

    internal async Task<HudReading> ReadAsync(Bitmap frame, IReadOnlyDictionary<HudField, Zone> zones)
    {
        _engine ??= OcrEngine.TryCreateFromUserProfileLanguages() ??
            OcrEngine.AvailableRecognizerLanguages.Select(OcrEngine.TryCreateFromLanguage).FirstOrDefault(engine => engine is not null)
            ?? throw new InvalidOperationException("Instale um idioma com OCR nos ajustes de idioma do Windows.");
        var text = new Dictionary<HudField, string>();
        foreach (var (field, zone) in zones)
        {
            var area = zone.At(frame.Size);
            if (area.Width < 5 || area.Height < 5) continue;
            using var resized = new Bitmap(area.Width * 3, area.Height * 3);
            using (var g = Graphics.FromImage(resized))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(frame, new Rectangle(Point.Empty, resized.Size), area, GraphicsUnit.Pixel);
            }
            using var png = new MemoryStream();
            resized.Save(png, System.Drawing.Imaging.ImageFormat.Png);
            using var input = new InMemoryRandomAccessStream();
            using (var writer = new DataWriter(input.GetOutputStreamAt(0)))
            {
                writer.WriteBytes(png.ToArray());
                await writer.StoreAsync();
                writer.DetachStream().Dispose();
            }
            input.Seek(0);
            var decoder = await BitmapDecoder.CreateAsync(input);
            using var software = await decoder.GetSoftwareBitmapAsync(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Ignore);
            text[field] = (await _engine.RecognizeAsync(software)).Text;
        }
        return Parse(text);
    }

    internal static HudReading Parse(IReadOnlyDictionary<HudField, string> text)
    {
        string Read(HudField field) => text.TryGetValue(field, out var value) ? value : "";
        var population = NormalizeDigits(Read(HudField.Population)).Split('/');
        int? used = null, cap = null;
        if (population.Length == 2 && Number(population[0], 1200) is int u &&
            Number(population[1], 1000) is int c && c > 0 && u <= c + 40)
            (used, cap) = (u, c);
        return new HudReading(Number(Read(HudField.Food)), Number(Read(HudField.Wood)),
            Number(Read(HudField.Gold)), Number(Read(HudField.Favor)), used, cap,
            Age(Read(HudField.Age)), Number(Read(HudField.Citizens), 300));
    }

    private static string NormalizeDigits(string text) => text.Trim().ToUpperInvariant()
        .Replace('O', '0').Replace('I', '1').Replace('L', '1').Replace('|', '1').Replace('\u2044', '/');

    private static int? Number(string text, int limit = 999999)
    {
        text = NormalizeDigits(text);
        if (!NumberText().IsMatch(text)) return null;
        var digits = string.Concat(text.Where(char.IsAsciiDigit));
        return int.TryParse(digits, NumberStyles.None, CultureInfo.InvariantCulture, out int value) && value <= limit
            ? value : null;
    }

    private static int? Age(string text)
    {
        var normalized = string.Concat(text.ToLowerInvariant().Normalize(System.Text.NormalizationForm.FormD)
            .Where(character => CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark));
        var age = normalized.Trim();
        if (age.Contains("arcaic") || age.Contains("archaic")) return 1;
        if (age.Contains("classic")) return 2;
        if (age.Contains("heroic")) return 3;
        if (age.Contains("mitic") || age.Contains("mythic")) return 4;
        if (age.Contains("maravilha") || age.Contains("wonder")) return 5;
        return age switch { "i" or "1" => 1, "ii" or "2" => 2, "iii" or "3" => 3, "iv" or "4" => 4, "v" or "5" => 5, _ => null };
    }

    [GeneratedRegex(@"^(?:[0-9]+|[0-9]{1,3}(?:[.,\s][0-9]{3})+)$", RegexOptions.CultureInvariant)]
    private static partial Regex NumberText();
}
