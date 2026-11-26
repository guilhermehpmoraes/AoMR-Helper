using System.Text.Json.Nodes;

namespace AoMR.Helper;

internal sealed class MainForm : Form
{
    private static readonly Color Ink = Color.FromArgb(239, 240, 232);
    private static readonly Color Muted = Color.FromArgb(180, 195, 185);
    private static readonly Color Accent = Color.FromArgb(238, 199, 131);
    private readonly Advisor _advisor = new();
    private readonly HudReader _reader;
    private readonly AutomaticHud _automaticHud;
    private readonly System.Windows.Forms.Timer _timer = new() { Interval = 1250 };
    private readonly Label _status = Readout("Aguardando leitura", Muted);
    private readonly Label _hud = Readout("", Muted);
    private readonly Label _age = Readout("", Ink, 10, FontStyle.Bold);
    private readonly Label _action = Readout("", Accent, 18, FontStyle.Bold);
    private readonly Label _reason = Readout("", Ink);
    private readonly Label _economy = Readout("", Accent, 12, FontStyle.Bold);
    private readonly Label _economyReason = Readout("", Ink);
    private readonly Label _army = Readout("", Ink);
    private readonly Label _attack = Readout("", Ink);
    private readonly Button _mark = Button("Registrar ação");
    private readonly Button _completed = Button("Centro concluído");
    private readonly Button _calibration = Button("Ajustar HUD");
    private HudProfile? _profile = HudProfile.Load();
    private HudReading? _observed;
    private bool _reading, _calibrating;
    private int? _candidateAge;
    private Action? _markAction;

    internal MainForm()
    {
        _reader = new HudReader();
        _automaticHud = new AutomaticHud(_reader);
        Text = "AoMR Helper · Gaia";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(435, 500);
        ClientSize = new Size(530, 720);
        Font = new Font("Segoe UI", 10);
        ForeColor = Ink;
        BackColor = Color.FromArgb(23, 28, 25);

        var content = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill, AutoScroll = true, FlowDirection = FlowDirection.TopDown,
            WrapContents = false, Padding = new Padding(14),
        };
        var tools = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, AutoSize = true, WrapContents = true };
        var observations = Button("Partida");
        observations.Click += (_, _) =>
        {
            using var settings = new MatchForm(_advisor);
            if (settings.ShowDialog(this) == DialogResult.OK) RefreshAdvice();
        };
        _calibration.Click += async (_, _) => await Calibrate();
        var file = Button("Usar imagem");
        file.Click += (_, _) =>
        {
            using var picker = new OpenFileDialog { Filter = "Imagens|*.png;*.jpg;*.jpeg;*.bmp" };
            if (picker.ShowDialog(this) != DialogResult.OK) return;
            try
            {
                using var image = new Bitmap(picker.FileName);
                ShowCalibration(image);
            }
            catch (Exception error) { _status.Text = $"Não foi possível abrir a imagem. {error.Message}"; }
        };
        var pin = new CheckBox { Text = "Fixar janela", AutoSize = true, Padding = new Padding(3, 5, 0, 0) };
        pin.CheckedChanged += (_, _) => TopMost = pin.Checked;
        var reset = Button("Nova partida");
        reset.Click += (_, _) =>
        {
            if (MessageBox.Show(this, "Reiniciar o acompanhamento da partida?", Text,
                    MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            _advisor.Reset();
            _observed = null;
            _candidateAge = null;
            _hud.Text = "";
            RefreshAdvice();
        };
        tools.Controls.AddRange([observations, _calibration, file, pin, reset]);
        _mark.Click += (_, _) => { _markAction?.Invoke(); RefreshAdvice(); };
        _completed.Click += (_, _) =>
        {
            var state = _advisor.State;
            state["centers"] = state["centers"]!.GetValue<int>() + 1;
            state["expansion"] = "unknown";
            _advisor.Done["expansionQueue"] = false;
            RefreshAdvice();
        };

        content.Controls.AddRange([
            Readout("AoMR Helper", Ink, 24, FontStyle.Bold),
            tools, _status, _hud, _age,
            Heading("FAÇA AGORA"), _action, _reason, _mark, _completed,
            Heading("PRIORIDADE PERSONALIZADA · 20 PONTOS"), _economy, _economyReason,
            Heading("COMPOSIÇÃO DO EXÉRCITO"), _army,
            Heading("QUANDO ATACAR"), _attack,
        ]);
        Controls.Add(content);
        content.Resize += (_, _) =>
        {
            int width = Math.Max(295, content.ClientSize.Width - 50);
            foreach (var label in content.Controls.OfType<Label>())
                label.MaximumSize = new Size(width, 0);
            tools.MaximumSize = new Size(width, 0);
        };
        _timer.Tick += async (_, _) => await ReadFrame();
        FormClosed += (_, _) => _timer.Dispose();
        _status.Text = "Aguardando a janela do jogo para ler o HUD automaticamente.";
        RefreshAdvice();
        _timer.Start();
    }

    private async Task ReadFrame()
    {
        if (_reading || _calibrating || IsDisposed) return;
        _reading = true;
        try
        {
            using var frame = HudCapture.Grab();
            if (frame is null)
            {
                _candidateAge = null;
                _status.Text = _observed is null ? "Aguardando a janela do AoMR." : "Leitura pausada · última amostra abaixo.";
                return;
            }
            var read = await _automaticHud.ScanAsync(frame);
            var automatic = read is not null;
            if (read is null && _profile?.Resolution == frame.Size)
                read = await _reader.ReadAsync(frame, _profile.Zones);
            if (IsDisposed || _calibrating) return;
            if (read is null || !read.HasValues)
            {
                _status.Text = "Procurando a barra de recursos. Deixe a partida visível com o HUD no topo.";
                InvalidateHud();
                return;
            }
            if (_observed?.Cap is int previous && read.Cap > previous)
                _advisor.State["housingPending"] = false;
            if (read.Age is int age && age == _candidateAge) _advisor.ObserveAge(age);
            _candidateAge = read.Age;
            _observed = read;
            _status.Text = $"HUD ao vivo · {(automatic ? "automático" : "layout personalizado")} · {DateTime.Now:HH:mm:ss}";
            _hud.Text = FormatHud(read with { Age = null });
            RefreshAdvice();
        }
        catch (Exception error)
        {
            if (!IsDisposed)
            {
                _status.Text = $"Leitura indisponível. {error.Message}";
                InvalidateHud();
            }
        }
        finally { _reading = false; }
    }

    private void InvalidateHud()
    {
        _candidateAge = null;
        if (_observed is null) return;
        _observed = null;
        _hud.Text = "";
        RefreshAdvice();
    }

    private async Task Calibrate()
    {
        _calibration.Enabled = false;
        _calibrating = true;
        try
        {
            for (int second = 4; second > 0; second--)
            {
                _status.Text = $"Volte à partida. Captura em {second} s.";
                await Task.Delay(1000);
                if (IsDisposed) return;
            }
            using var frame = HudCapture.Grab();
            if (frame is null)
            {
                _status.Text = "Não encontrei o AoMR em primeiro plano no momento da captura.";
                return;
            }
            ShowCalibration(frame);
        }
        catch (Exception error) { if (!IsDisposed) _status.Text = $"Captura indisponível. {error.Message}"; }
        finally
        {
            _calibrating = false;
            if (!IsDisposed) _calibration.Enabled = true;
        }
    }

    private void ShowCalibration(Bitmap frame)
    {
        bool wasCalibrating = _calibrating;
        _calibrating = true;
        try
        {
            using var form = new CalibrationForm(frame, _profile);
            if (form.ShowDialog(this) != DialogResult.OK) return;
            form.Profile.Save();
            _profile = form.Profile;
            InvalidateHud();
            _status.Text = "Calibração salva. Volte à partida para iniciar a leitura.";
        }
        finally { _calibrating = wasCalibrating; }
    }

    private void RefreshAdvice()
    {
        if (!_advisor.AgeKnown)
        {
            _age.Text = "Era atual · aguardando confirmação";
            _action.Text = "Identificando a era da partida";
            _reason.Text = "Com a barra do jogo visível, o helper procura o medalhão da era. Você também pode informar a era em Partida.";
            _economy.Text = "Aguardando a era";
            _economyReason.Text = _army.Text = _attack.Text = "";
            _markAction = null;
            _mark.Visible = _completed.Visible = false;
            return;
        }

        string[] ages = ["I · Arcaica", "II · Clássica", "III · Heroica", "IV · Mítica", "V · Maravilha"];
        _age.Text = $"Era atual · {ages[_advisor.State["age"]!.GetValue<int>() - 1]}";
        var result = _advisor.Recommend(_observed);
        var next = result["next"]!;
        var economics = result["economy"]!;
        var attack = result["attack"]!;
        _action.Text = TextOf(next, "title");
        _reason.Text = TextOf(next, "reason");
        _economy.Text = string.Join("  ·  ", new[] { "Comida", "Madeira", "Ouro" }.Select((name, index) =>
            $"{name} {economics["points"]![index]}"));
        _economyReason.Text = TextOf(economics, "reason");
        var lines = result["plan"]!.AsArray().Select(unit =>
            $"{unit!["name"]}  {unit["current"]}/{unit["target"]}  ·  {unit["building"]}");
        _army.Text = string.Join(Environment.NewLine, lines);
        if (_army.Text.Length == 0) _army.Text = "Explore com Oráculos. Produção militar a partir da Clássica.";
        if (result["antiMyth"]!.GetValue<int>() > 0)
            _army.Text += $"{Environment.NewLine}Heróis de combate  {_advisor.State["heroes"]}/{result["antiMyth"]}";
        _attack.Text = $"{TextOf(attack, "title")}{Environment.NewLine}{TextOf(attack, "reason")}";

        _markAction = null;
        if (next["mark"] is JsonNode mark)
        {
            var key = mark.GetValue<string>();
            _mark.Text = key switch
            {
                "advance" or "manor" or "startCenter" => "Marcar como iniciado",
                "closeWalls" => "Marcar entradas protegidas",
                _ => "Marcar como feito",
            };
            _markAction = () => _advisor.Mark(key);
        }
        else if (next["training"] is JsonNode training)
        {
            var key = TextOf(training, "key");
            var count = training["count"]!.GetValue<int>();
            _mark.Text = "Registrar tropas enfileiradas";
            _markAction = () => _advisor.State[key] = _advisor.State[key]!.GetValue<int>() + count;
        }
        _mark.Visible = _markAction is not null;
        _completed.Visible = _advisor.State["expansion"]!.GetValue<string>() == "building";
    }

    internal static string FormatHud(HudReading hud)
    {
        var fields = new List<string>();
        if (hud.Food is int food) fields.Add($"Comida {food}");
        if (hud.Wood is int wood) fields.Add($"Madeira {wood}");
        if (hud.Gold is int gold) fields.Add($"Ouro {gold}");
        if (hud.Favor is int favor) fields.Add($"Favor {favor}");
        if (hud.Used is int used) fields.Add($"Pop. {used}/{hud.Cap}");
        if (hud.Age is int age) fields.Add($"Era {age}");
        if (hud.Citizens is int citizens) fields.Add($"Aldeões {citizens}");
        return string.Join("  ·  ", fields);
    }

    private static string TextOf(JsonNode value, string key) => value[key]!.GetValue<string>();
    private static Label Heading(string text) => Readout(text, Muted, 9, FontStyle.Bold, 14);
    private static Label Readout(string text, Color color, int points = 10, FontStyle style = FontStyle.Regular, int top = 4) =>
        new() { AutoSize = true, Text = text, ForeColor = color, MaximumSize = new Size(470, 0),
            Font = new Font("Segoe UI", points, style), Margin = new Padding(3, top, 3, 3) };
    private static Button Button(string text) => new() { Text = text, AutoSize = true, FlatStyle = FlatStyle.Flat };
}
