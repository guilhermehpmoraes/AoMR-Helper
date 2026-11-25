namespace AoMR.Helper;

internal sealed class CalibrationForm : Form
{
    private readonly Bitmap _frame;
    private readonly HudReader _reader = new();
    private readonly ZoneCanvas _canvas;
    private readonly ComboBox _field = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 150 };
    private readonly Label _status = new() { AutoSize = true, MaximumSize = new Size(940, 0) };
    internal HudProfile Profile { get; }

    internal CalibrationForm(Bitmap frame, HudProfile? previous)
    {
        _frame = frame;
        Profile = new(frame.Size, previous?.Resolution == frame.Size ? new(previous.Zones) : new());
        Text = "Calibrar leitura do AoMR";
        ClientSize = new Size(980, 660);
        MinimumSize = new Size(650, 450);
        StartPosition = FormStartPosition.CenterParent;
        Font = new Font("Segoe UI", 10);
        foreach (var field in Enum.GetValues<HudField>()) _field.Items.Add(NameOf(field));
        _field.SelectedIndex = 0;
        _canvas = new ZoneCanvas(frame, Profile.Zones) { Dock = DockStyle.Fill };
        _field.SelectedIndexChanged += (_, _) => _canvas.Field = (HudField)_field.SelectedIndex;

        var header = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 76, Padding = new Padding(12), AutoScroll = true };
        var clear = new Button { Text = "Limpar área", AutoSize = true };
        clear.Click += (_, _) => { Profile.Zones.Remove(_canvas.Field); _canvas.Invalidate(); };
        var save = new Button { Text = "Salvar calibração", AutoSize = true };
        save.Click += (_, _) =>
        {
            if (Profile.Zones.Count == 0)
            {
                _status.Text = "Marque pelo menos um campo.";
                return;
            }
            DialogResult = DialogResult.OK;
            Close();
        };
        var test = new Button { Text = "Testar leitura", AutoSize = true };
        test.Click += async (_, _) =>
        {
            test.Enabled = false;
            save.Enabled = false;
            try
            {
                using var copy = new Bitmap(_frame);
                var read = await _reader.ReadAsync(copy, new Dictionary<HudField, Zone>(Profile.Zones));
                if (!IsDisposed) _status.Text = read.HasValues ? MainForm.FormatHud(read) : "Nenhum valor reconhecido nas áreas selecionadas.";
            }
            catch (Exception error) { if (!IsDisposed) _status.Text = $"Falha na leitura. {error.Message}"; }
            finally { if (!IsDisposed) { test.Enabled = true; save.Enabled = true; } }
        };
        header.Controls.AddRange([_field, clear, test, save]);
        header.SetFlowBreak(save, true);
        header.Controls.Add(_status);
        _status.Text = "Escolha um campo e arraste em volta do valor, deixando o ícone de fora. Inclua a barra de população inteira.";
        Controls.Add(_canvas);
        Controls.Add(header);
    }

    private static string NameOf(HudField field) => field switch
    {
        HudField.Food => "Comida",
        HudField.Wood => "Madeira",
        HudField.Gold => "Ouro",
        HudField.Favor => "Favor",
        HudField.Population => "População",
        HudField.Age => "Era",
        _ => "Aldeões",
    };

    private sealed class ZoneCanvas(Bitmap frame, Dictionary<HudField, Zone> zones) : Control
    {
        private Point? _start;
        private Point _end;
        private HudField _field;
        [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
        internal HudField Field { get => _field; set { _field = value; Invalidate(); } }

        private Rectangle ImageArea
        {
            get
            {
                var scale = Math.Min((double)Width / frame.Width, (double)Height / frame.Height);
                int width = (int)(frame.Width * scale), height = (int)(frame.Height * scale);
                return new Rectangle((Width - width) / 2, (Height - height) / 2, width, height);
            }
        }

        protected override void OnPaint(PaintEventArgs args)
        {
            var image = ImageArea;
            args.Graphics.Clear(Color.FromArgb(24, 27, 25));
            if (image.Width == 0 || image.Height == 0) return;
            args.Graphics.DrawImage(frame, image);
            using var active = new Pen(Color.Gold, 2);
            using var inactive = new Pen(Color.PaleGreen);
            foreach (var (field, zone) in zones)
            {
                var outline = zone.At(image.Size);
                if (outline.IsEmpty) continue;
                outline.Offset(image.Location);
                args.Graphics.DrawRectangle(field == Field ? active : inactive, outline);
            }
            if (_start is Point start)
                args.Graphics.DrawRectangle(active, Rectangle.Intersect(image, Between(start, _end)));
        }

        protected override void OnMouseDown(MouseEventArgs args)
        {
            if (args.Button != MouseButtons.Left || !ImageArea.Contains(args.Location)) return;
            _start = _end = args.Location;
            Capture = true;
        }

        protected override void OnMouseMove(MouseEventArgs args)
        {
            if (_start is null) return;
            _end = args.Location;
            Invalidate();
        }

        protected override void OnMouseUp(MouseEventArgs args)
        {
            if (_start is not Point start) return;
            var image = ImageArea;
            var area = Rectangle.Intersect(image, Between(start, args.Location));
            if (area.Width >= 4 && area.Height >= 4)
            {
                area.Offset(-image.X, -image.Y);
                zones[Field] = Zone.From(area, image.Size);
            }
            _start = null;
            Capture = false;
            Invalidate();
        }

        private static Rectangle Between(Point a, Point b) => Rectangle.FromLTRB(
            Math.Min(a.X, b.X), Math.Min(a.Y, b.Y), Math.Max(a.X, b.X), Math.Max(a.Y, b.Y));
    }
}
