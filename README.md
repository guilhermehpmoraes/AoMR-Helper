# AoMR Helper

Aplicativo Windows para acompanhar partidas terrestres de Gaia no Age of Mythology: Retold.

## Usar na partida

1. Abra `dist/AoMR Helper.exe`. O executável usa o .NET Desktop Runtime 10 x64.
2. Entre numa partida. Clique em **Calibrar HUD** e volte ao jogo durante a contagem. Se preferir, abra uma captura da mesma resolução pela opção **Usar imagem**.
3. Selecione cada campo e arraste um retângulo em volta do valor exibido. Comece por comida, madeira, ouro e população. Você pode marcar favor, era e aldeões quando estiverem visíveis. Para população, inclua os dois números e a barra. Use **Testar leitura** antes de salvar.
4. Volte ao AoMR. A leitura acompanha o jogo em primeiro plano. O painel pode ficar num segundo monitor ou por cima do jogo em modo janela com **Fixar janela**. Posicione o painel longe das áreas calibradas. Recalibre se alterar a resolução, a escala ou a posição do HUD.
5. Use **Faça agora** para seguir a ordem e **Prioridade personalizada** para copiar a distribuição no jogo. O saldo lido do HUD ajusta a coleta para avanços de era e para as unidades recomendadas, usando seus custos-base. Use **Partida** para registrar tropas, ameaças, construções, pesquisas, passagens abertas e assentamentos. Se o jogo não exibir uma contagem de aldeões ou a era, preencha o campo manual.

As imagens da janela são processadas localmente pelo OCR do Windows. O perfil do HUD é guardado em `%LOCALAPPDATA%/AoMR Helper/hud.json`. A sessão de partida fica em memória. As metas de tropas e timings são regras iniciais para Gaia.

## Compilar

Com o .NET SDK 10 x64, execute a partir da raiz do projeto:

```powershell
dotnet publish desktop/AoMR.Helper.csproj -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -p:DebugType=None -o dist
```

## Referências

- [Panteão atlante de Age of Mythology: Retold](https://www.ageofempires.com/games/aom/civilizations/atlanteans/)
- [Ajustes oficiais a Gaia, Turma e Cheiroballista](https://www.ageofempires.com/news/age-of-mythology-retold-update-18-9036/)
- [Alteração oficial do custo da Era Mítica](https://www.ageofempires.com/news/age-of-mythology-retold-update-17-64528/)
- [Abertura de Gaia publicada por Léonce e Godschalk](https://aomguides.com/guides/community-dod-gaia-10-hero-citizens-051e54)
