namespace AoMR.Helper;

internal sealed class AutomaticHud(HudReader reader)
{
    // The default PC HUD is anchored to the top center. These rectangles
    // describe the text only, relative to that anchor at 1080p.
    private static readonly Dictionary<HudField, Rectangle> Layout = new()
    {
        [HudField.Food] = new(-366, 7, 85, 25),
        [HudField.Wood] = new(-202, 7, 85, 25),
        [HudField.Gold] = new(-39, 7, 85, 25),
        [HudField.Favor] = new(124, 7, 85, 25),
        [HudField.Population] = new(258, 7, 98, 25),
        [HudField.Age] = new(-27, 62, 54, 47),
    };
    private static readonly double[] Scales = [1, .9, 1.1, .8, 1.2, .75, 1.25, 1.35, .65, 1.5];
    private Size _size;
    private Dictionary<HudField, Zone>? _detected;
    private int _nextScale;

    internal async Task<HudReading?> ScanAsync(Bitmap frame)
    {
        if (_size != frame.Size)
        {
            _size = frame.Size;
            _detected = null;
            _nextScale = 0;
        }

        if (_detected is not null)
        {
            var reading = await reader.ReadAsync(frame, _detected, resourceBar: true);
            if (IsResourceBar(reading)) return WithAge(reading, frame, _detected);
            _detected = null;
        }

        // Bound the work per frame while a menu is open or the UI scale changes.
        for (int attempt = 0; attempt < 2; attempt++)
        {
            var zones = Regions(frame.Size, Scales[_nextScale]);
            _nextScale = (_nextScale + 1) % Scales.Length;
            if (!zones.TryGetValue(HudField.Population, out var population)) continue;
            var check = await reader.ReadAsync(frame, new Dictionary<HudField, Zone> { [HudField.Population] = population }, resourceBar: true);
            if (!check.Cap.HasValue) continue;
            var reading = await reader.ReadAsync(frame, zones, resourceBar: true);
            if (!IsResourceBar(reading)) continue;
            _detected = zones;
            return WithAge(reading, frame, zones);
        }

        return null;
    }

    private static Dictionary<HudField, Zone> Regions(Size size, double uiScale)
    {
        var scale = size.Height / 1080.0 * uiScale;
        var bounds = new Rectangle(Point.Empty, size);
        var zones = new Dictionary<HudField, Zone>();
        foreach (var (field, relative) in Layout)
        {
            var area = Rectangle.Round(new RectangleF((float)(size.Width / 2.0 + relative.X * scale),
                (float)(relative.Y * scale), (float)(relative.Width * scale), (float)(relative.Height * scale)));
            if (bounds.Contains(area)) zones[field] = Zone.From(area, size);
        }
        return zones;
    }

    private static bool IsResourceBar(HudReading reading) =>
        reading.Cap.HasValue && reading.Food.HasValue && reading.Wood.HasValue &&
        reading.Gold.HasValue;

    private static HudReading WithAge(HudReading reading, Bitmap frame, Dictionary<HudField, Zone> zones) =>
        zones.TryGetValue(HudField.Age, out var badge)
            ? reading with { Age = AgeBadge.Read(frame, badge.At(frame.Size)) }
            : reading;
}

internal static class AgeBadge
{
    // Normalized red and green averages from the game's bronze, silver,
    // gold, green, and blue age badges. The blue share is the remainder.
    private static readonly (double Red, double Green)[] Colors =
        [(.506, .314), (.345, .331), (.463, .368), (.257, .555), (.220, .306)];

    internal static int? Read(Bitmap frame, Rectangle badge)
    {
        if (badge.Width < 12 || badge.Height < 12) return null;
        long red = 0, green = 0, blue = 0;
        int bright = 0, dark = 0;
        for (int y = badge.Top; y < badge.Bottom; y++)
        {
            for (int x = badge.Left; x < badge.Right; x++)
            {
                var pixel = frame.GetPixel(x, y);
                red += pixel.R;
                green += pixel.G;
                blue += pixel.B;
                int intensity = (pixel.R + pixel.G + pixel.B) / 3;
                if (intensity > 170) bright++;
                if (intensity < 105) dark++;
            }
        }
        int pixels = badge.Width * badge.Height;
        if (bright < pixels * .025 || dark < pixels * .1) return null;
        double total = red + green + blue;
        var candidates = Colors.Select((color, index) =>
        {
            double r = red / total - color.Red, g = green / total - color.Green;
            return (Age: index + 1, Distance: Math.Sqrt(r * r + g * g + (r + g) * (r + g)));
        }).OrderBy(candidate => candidate.Distance).ToArray();
        return candidates[0].Distance < .065 && candidates[1].Distance - candidates[0].Distance > .025
            ? candidates[0].Age : null;
    }
}
