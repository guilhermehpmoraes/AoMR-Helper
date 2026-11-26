using System.Text.Json.Nodes;
using Jint;

namespace AoMR.Helper;

internal sealed class Advisor
{
    private readonly Engine _engine = new();
    internal JsonObject State { get; private set; } = new();
    internal JsonObject Checkpoints { get; }
    internal JsonObject Done => State["done"]!.AsObject();
    internal bool AgeKnown { get; private set; }

    internal Advisor()
    {
        using var stream = typeof(Advisor).Assembly.GetManifestResourceStream("GaiaAdvisor.js")!;
        using var reader = new StreamReader(stream);
        _engine.Execute(reader.ReadToEnd());
        _engine.Execute("""
            function getAdvice(json) {
                return JSON.stringify(GaiaAdvisor.recommend(JSON.parse(json)));
            }
            """);
        Checkpoints = Evaluate("""
            JSON.stringify(Object.assign({}, GaiaAdvisor.buildings,
              Object.fromEntries(GaiaAdvisor.upgrades.map(([key, name]) => [key, name]))))
            """);
        Reset();
    }

    internal void Reset()
    {
        State = Evaluate("JSON.stringify(GaiaAdvisor.initial)");
        AgeKnown = false;
    }

    internal JsonObject Recommend(HudReading? hud)
    {
        var observed = State.DeepClone().AsObject();
        if (hud is not null)
        {
            if (hud.Food is int food) observed["stockFood"] = food;
            if (hud.Wood is int wood) observed["stockWood"] = wood;
            if (hud.Gold is int gold) observed["stockGold"] = gold;
            if (hud.Used is int used) observed["used"] = used;
            if (hud.Cap is int cap) observed["cap"] = cap;
            if (hud.Citizens is int citizens) observed["citizens"] = citizens;
        }
        return JsonNode.Parse(_engine.Invoke("getAdvice", observed.ToJsonString()).AsString())!.AsObject();
    }

    internal void SetAge(int age)
    {
        AgeKnown = true;
        if (State["age"]!.GetValue<int>() == age) return;
        State["age"] = age;
        State["advance"] = "saving";
        Done["infantryTech"] = false;
        Done["rangedTech"] = false;
    }

    internal void ObserveAge(int age)
    {
        if (!AgeKnown || age >= State["age"]!.GetValue<int>()) SetAge(age);
    }

    internal void Mark(string key)
    {
        switch (key)
        {
            case "manor":
                State["manors"] = State["manors"]!.GetValue<int>() + 1;
                State["housingPending"] = true;
                break;
            case "startCenter":
                State["expansion"] = "building";
                break;
            case "closeWalls":
                State["walls"] = "covered";
                break;
            case "advance":
                State["advance"] = "researching";
                break;
            case "queues":
                State["queues"] = "normal";
                break;
            case "farmPending":
                State[key] = true;
                break;
            default:
                Done[key] = true;
                break;
        }
    }

    private JsonObject Evaluate(string expression) =>
        JsonNode.Parse(_engine.Evaluate(expression).AsString())!.AsObject();
}
