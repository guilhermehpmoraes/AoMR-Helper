# AoMR Helper

Aplicativo Windows para acompanhar partidas terrestres de Gaia no Age of Mythology: Retold.

## Gaia Autoplay

Mod local para escaramuças terrestres solo e salas privadas. A conta e o slot continuam sendo do jogador humano. O bot coleta, constrói, avança de era, treina tropas, defende a base e ataca alvos avistados.

1. Rode `./autoplay/Install-GaiaAutoplay.ps1` no PowerShell. A instalação padrão usa o perfil Steam encontrado em `Games/Age of Mythology Retold`. Para outra instalação, informe `-GameDirectory` e `-GameProfile`.
2. Ative **Gaia Autoplay** no gerenciador de mods e reinicie o AoMR. Selecione **Gaia** e permita a **Prioridade do aldeão**. Deixe a fila automática de aldeões do jogo desativada para o bot decidir quando o Centro da Cidade deve treinar ou avançar de era.
3. A partida começa sob controle manual. Selecione um **Centro Urbano** de Gaia. No painel inferior esquerdo, clique em **Gaia Autoplay**, no espaço que era do ícone de fazenda, à direita do botão de gado. Clique de novo para desligar. O comando funciona desde a Era I e aparece no painel do jogador.
4. Ao desligar, o bot encerra seus planos no próximo ciclo de IA. Unidades e tecnologias enfileiradas continuam na fila. A exploração dos Oráculos volta a funcionar normalmente.

A **Prioridade do aldeão** e a opção de fazendas automáticas continuam sendo controles do jogo. Se a prioridade já estiver configurada quando o bot iniciar, ele usa a distribuição escolhida pelo jogador. Alterar a prioridade durante o autoplay também devolve ao jogador o ajuste da coleta.

O bot usa o nível de microgerenciamento que a IA oficial usa no Titã enquanto está ligado. Ele manda o gado capturado ao Centro Urbano acessível mais próximo e reserva uma construção separada para Mansões, contando também a população na fila.

Na abertura, o bot dá um plano de exploração a cada Oráculo livre, prioriza o Templo e junta a comida para avançar por Oceano. Os Oráculos param perto de áreas inexploradas para gerar Favor. No meio da partida, o bot reserva recursos para Theia e Atlas quando tem defesa e a base está segura. Sob ataque, volta a priorizar tropas. Também expande para assentamentos seguros e ajusta a produção conforme o inimigo avistado. No fim, usa comércio, cerco e heróis. Com recursos e proteção suficientes, tenta concluir o Portão do Titã e a Maravilha e atacar as construções que restarem.

### Equipes, 2x4 e todos contra todos

1. Em cada PC, extraia o mesmo pacote, execute o instalador, ative o mod e reinicie o AoMR. Use a mesma versão do jogo nos dois PCs.
2. Crie uma **sala privada** em **Multijogador → Hospedar**. Selecione o mapa personalizado **Gaia Autoplay**. O mapa usa o gerador de Alfheim da instalação do jogo.
3. Coloque **Gaia no slot 1** para o jogador que quer usar o bot. Em **Equipes**, ponha seu amigo no mesmo time e preencha o outro time com uma ou quatro IAs. Em **Todos contra todos**, configure cada participante para jogar por conta própria.
4. O slot 1 começa sob controle manual. As decisões de ataque consideram os defensores avistados e as tropas aliadas próximas. Quando a sua base estiver segura, o bot pode ajudar um aliado sob ataque.

### Roadmap

1. **Pilotar em sala privada.** Instalar a mesma versão do mod em dois PCs, confirmar a entrada na sala e observar se a partida permanece sincronizada do início ao fim com o autoplay no slot 1.
2. **Avaliar um aplicativo externo depois do piloto.** Explorar leitura da tela e uso de mouse e teclado para controlar a própria vaga em uma sala padrão, sem instalar mods no jogo dos participantes.

## Usar na partida

1. Abra `dist/AoMR Helper.exe`. O executável usa o .NET Desktop Runtime 10 x64.
2. Entre numa partida com a barra de recursos no topo central. O aplicativo procura a barra enquanto o jogo estiver em primeiro plano. Quando encontrar, aparece **HUD ao vivo · automático**. O painel pode ficar num segundo monitor ou por cima do jogo em modo janela com **Fixar janela**. Posicione o painel longe da barra de recursos.
3. Confira **Era atual**. O helper identifica o medalhão da era mesmo quando aberto no meio da partida. Se ele estiver encoberto, você pode informar a era em **Partida**.
4. Use **Faça agora** para seguir a ordem. Em **Prioridade personalizada**, copie os pontos de comida, madeira e ouro para o preset **Personalizado** do jogo. Os três valores somam 20 pontos. O saldo lido do HUD ajusta a coleta para avanços de era e para as unidades recomendadas, usando seus custos-base. Use **Partida** para registrar aldeões, tropas, ameaças, construções, pesquisas, passagens abertas e assentamentos.
5. Se você usa um HUD em outra posição e a detecção automática não o encontrar, **Ajustar HUD** permite marcar os campos. Também é possível abrir uma imagem da mesma resolução pela opção **Usar imagem**. Teste a leitura antes de salvar.

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
