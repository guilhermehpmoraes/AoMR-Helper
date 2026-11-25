using System.Text.Json.Nodes;

namespace AoMR.Helper;

internal sealed class MatchForm : Form
{
    private readonly Advisor _advisor;
    private readonly TabControl _tabs = new() { Dock = DockStyle.Fill };
    private readonly List<Action> _apply = [];
    private TableLayoutPanel _table = null!;

    internal MatchForm(Advisor advisor)
    {
        _advisor = advisor;
        Text = "Estado da partida";
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(595, 530);
        MinimumSize = new Size(530, 470);
        Font = new Font("Segoe UI", 10);

        Tab("Partida");
        Choice("age", "Era atual", [("1", "Arcaica"), ("2", "Clássica"), ("3", "Heroica"), ("4", "Mítica"), ("5", "Maravilha")]);
        Choice("advance", "Avanço de era", [("saving", "Juntando recursos"), ("ready", "Recursos suficientes"), ("researching", "Em andamento")]);
        Number("citizens", "Aldeões · valor manual", 300);
        Number("used", "População usada · valor manual");
        Number("cap", "Limite de população · valor manual");
        Choice("enemy", "Tropa inimiga predominante", [("unknown", "Desconhecida"), ("mixed", "Mista"), ("infantry", "Infantaria"), ("archers", "Arqueiros"), ("cavalry", "Cavalaria")]);
        Choice("strength", "Força inimiga avistada", [("unknown", "Desconhecida"), ("weaker", "Menor que a minha"), ("even", "Parecida"), ("stronger", "Maior que a minha")]);
        Number("enemyMyths", "Unidades míticas inimigas", 300);
        Check("pressure", "Minha base está sob ataque");
        Check("exposed", "Economia inimiga exposta");
        Check("fortified", "Quero atacar uma posição fortificada");
        Choice("walls", "Entradas da base", [("unknown", "Ainda não avaliei"), ("open", "Abertas perto de recursos"), ("raids", "Já usadas em incursões"), ("covered", "Protegidas")]);

        Tab("Economia");
        Choice("food", "Comida segura", [("hunt", "Caça disponível"), ("other", "Outras fontes"), ("low", "Fontes acabando ou inseguras"), ("farms", "Fazendas sustentam a coleta")]);
        Choice("shortage", "Recurso que está faltando", [("none", "Nenhum em especial"), ("food", "Comida"), ("wood", "Madeira"), ("gold", "Ouro")]);
        Number("manors", "Casas em uso ou em obra", 99);
        Number("centers", "Centros da Cidade prontos", 99, 1);
        Choice("expansion", "Próximo assentamento", [("unknown", "Procurando ou contestado"), ("secure", "Seguro, juntando recursos"), ("ready", "Seguro e com recursos"), ("building", "Centro em construção")]);
        Choice("housing", "Como ampliar a população", [("manor", "Ainda posso construir casas"), ("tc", "Casas no limite, posso pegar assentamento"), ("capped", "Sem como aumentar agora")]);
        Choice("queues", "Filas militares com recursos sobrando", [("normal", "Produção acompanha"), ("military", "Quartel militar ocupado"), ("counter", "Quartel de contra-ataque ocupado")]);
        Check("housingPending", "Aumento de população em obra");
        Check("farmPending", "Já plantei a próxima leva de fazendas");
        Check("titanAllowed", "O modo permite Titã");

        Tab("Exército");
        Number("readyArmy", "Total de tropas de combate prontas", 300);
        Number("readySiege", "Destroyers ou cerco prontos", 300);
        Number("heroes", "Heróis de combate prontos", 300);
        Number("murmillo", "Murmillo · prontos e na fila", 300);
        Number("katapeltes", "Katapeltes · prontos e na fila", 300);
        Number("turma", "Turma · prontos e na fila", 300);
        Number("cheiro", "Cheiroballista · prontos e na fila", 300);
        Number("destroyer", "Destroyer · prontos e na fila", 300);
        Number("otherArmy", "Outras tropas · prontas e na fila", 300);
        Number("otherSiege", "Outras unidades de cerco · prontas e na fila", 300);

        Tab("Construções e pesquisas");
        foreach (var (key, name) in advisor.Checkpoints)
            Check(key, name!.GetValue<string>(), _advisor.Done);

        var footer = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 48, FlowDirection = FlowDirection.RightToLeft, Padding = new Padding(8) };
        var save = new Button { Text = "Aplicar", AutoSize = true };
        save.Click += (_, _) =>
        {
            var previousCenters = _advisor.State["centers"]!.GetValue<int>();
            var previousCap = _advisor.State["cap"]?.GetValue<int>();
            foreach (var action in _apply) action();
            if (previousCenters != _advisor.State["centers"]!.GetValue<int>()) _advisor.Done["expansionQueue"] = false;
            if (previousCap is int cap && _advisor.State["cap"]?.GetValue<int>() > cap) _advisor.State["housingPending"] = false;
            DialogResult = DialogResult.OK;
            Close();
        };
        var cancel = new Button { Text = "Cancelar", AutoSize = true, DialogResult = DialogResult.Cancel };
        footer.Controls.AddRange([save, cancel]);
        Controls.Add(_tabs);
        Controls.Add(footer);
        AcceptButton = save;
        CancelButton = cancel;
    }

    private void Tab(string name)
    {
        var page = new TabPage(name) { Padding = new Padding(8), AutoScroll = true };
        _table = new TableLayoutPanel { AutoSize = true, Dock = DockStyle.Top, ColumnCount = 2, Padding = new Padding(4) };
        _table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 49));
        _table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 51));
        page.Controls.Add(_table);
        _tabs.TabPages.Add(page);
    }

    private void Choice(string key, string name, (string Value, string Label)[] options)
    {
        var select = new ComboBox { Dock = DockStyle.Top, DropDownStyle = ComboBoxStyle.DropDownList, AccessibleName = name };
        select.Items.AddRange(options.Select(option => (object)option.Label).ToArray());
        var current = _advisor.State[key]?.ToString();
        select.SelectedIndex = Math.Max(0, Array.FindIndex(options, option => option.Value == current));
        AddLabelAndControl(name, select);
        _apply.Add(() =>
        {
            var value = options[select.SelectedIndex].Value;
            if (key == "age") _advisor.SetAge(int.Parse(value));
            else _advisor.State[key] = value;
        });
    }

    private void Number(string key, string name, int max = 1000, int min = 0)
    {
        var value = _advisor.State[key]?.GetValue<int>();
        int? defaultValue = key is "readyArmy" or "used" or "cap" ? null : min;
        var input = new TextBox { Dock = DockStyle.Top, Text = value?.ToString() ?? "", AccessibleName = name };
        AddLabelAndControl(name, input);
        _apply.Add(() => _advisor.State[key] = int.TryParse(input.Text, out int number) ? Math.Clamp(number, min, max) : defaultValue);
    }

    private void Check(string key, string name, JsonObject? values = null)
    {
        var target = values ?? _advisor.State;
        var check = new CheckBox { Text = name, Checked = target[key]?.GetValue<bool>() ?? false, AutoSize = true };
        _table.Controls.Add(check, 0, _table.RowCount++);
        _table.SetColumnSpan(check, 2);
        _apply.Add(() => target[key] = check.Checked);
    }

    private void AddLabelAndControl(string text, Control control)
    {
        var label = new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(3, 6, 3, 4) };
        int row = _table.RowCount++;
        _table.Controls.Add(label, 0, row);
        _table.Controls.Add(control, 1, row);
    }

}
