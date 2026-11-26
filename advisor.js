/* global module */
const GaiaAdvisor = (() => {
  const buildings = {
    autoqueue: 'Autoqueue de aldeões ativada',
    expansionQueue: 'Autoqueue revisada no último Centro da Cidade',
    forest: 'Floresta de Gaia usada na abertura',
    scout: 'Oráculos posicionados',
    guild: 'Guilda Econômica',
    temple: 'Templo',
    military: 'Quartel Militar',
    counter: 'Quartel de Contra-Ataque',
    armory: 'Arsenal',
    market: 'Mercado',
    palace: 'Palácio',
    titan: 'Portão do Titã concluído',
    infantryTech: 'Melhoria de linha da infantaria da era atual',
    rangedTech: 'Melhoria de linha das unidades à distância da era atual',
  };

  const units = {
    murmillo: ['Murmillo', 'Quartel Militar', 'military', 2, [55, 0, 30]],
    katapeltes: ['Katapeltes', 'Quartel de Contra-Ataque', 'counter', 2, [60, 0, 35]],
    turma: ['Turma', 'Quartel de Contra-Ataque', 'counter', 2, [0, 45, 40]],
    cheiro: ['Cheiroballista', 'Quartel de Contra-Ataque', 'counter', 4, [0, 115, 100]],
    destroyer: ['Destroyer', 'Palácio', 'palace', 3, [70, 0, 60]],
  };

  const upgrades = [
    ['axe', 'Hand Axe', 'madeira', 1],
    ['pick', 'Pickaxe', 'ouro', 1],
    ['saw', 'Bow Saw', 'madeira', 2, 'axe'],
    ['shaft', 'Shaft Mine', 'ouro', 2, 'pick'],
    ['plow', 'Plow', 'fazendas', 1],
    ['carpenters', 'Carpenters', 'madeira', 3, 'saw'],
    ['quarry', 'Quarry', 'ouro', 3, 'shaft'],
    ['irrigation', 'Irrigation', 'fazendas', 2, 'plow'],
    ['flood', 'Flood Control', 'fazendas', 3, 'irrigation'],
    ['survival', 'Survival Equipment', 'segurança dos aldeões e caça', 1],
    ['husbandry', 'Husbandry', 'coleta de animais de criação', 1],
  ];

  const initial = {
    age: 1, advance: 'saving', citizens: 2, used: null, cap: null,
    food: 'hunt', shortage: 'none', manors: 0, housing: 'manor',
    centers: 1, expansion: 'unknown', walls: 'unknown',
    housingPending: false, farmPending: false, queues: 'normal',
    enemy: 'unknown', strength: 'unknown', enemyMyths: 0,
    pressure: false, exposed: false, fortified: false,
    murmillo: 0, katapeltes: 0, turma: 0, cheiro: 0, destroyer: 0,
    heroes: 0, otherArmy: 0, otherSiege: 0, readyArmy: null, readySiege: 0,
    titanAllowed: true, done: {},
  };

  const ageCosts = { 1: [400, 0, 0], 2: [800, 0, 500], 3: [1200, 0, 1200] };
  const priorityBudget = 20;
  const resources = ['comida', 'madeira', 'ouro'];
  const stock = s => [s.stockFood, s.stockWood, s.stockGold];
  const deficits = (costs, bank) => costs.map((cost, index) =>
    Number.isFinite(bank[index]) ? Math.max(0, cost - bank[index]) : 0);
  const describeDeficit = missing => missing.flatMap((amount, index) =>
    amount > 0 ? [`${amount} de ${resources[index]}`] : []).join(' e ');

  const action = (title, reason, mark, goal) => ({ title, reason, mark, goal });
  const at = (s, key) => Boolean(s.done[key]);
  const staffing = (total, weights) => {
    const exact = weights.map(weight => total * weight / 100);
    const result = exact.map(Math.floor);
    const order = exact.map((value, index) => [value - result[index], index])
      .sort((a, b) => b[0] - a[0]);
    let remaining = total - result.reduce((a, b) => a + b, 0);
    for (const [, index] of order) {
      if (remaining-- <= 0) break;
      result[index]++;
    }
    return result;
  };

  function armyPlan(s) {
    if (s.age === 1) return [];
    const scale = [0, 0, 1, 2, 4, 5][s.age];
    const compositions = {
      unknown: [['murmillo', 5]],
      mixed: [['murmillo', 5], ['turma', 2]],
      infantry: [['murmillo', 4], ['cheiro', 2]],
      archers: [['turma', 5], ['murmillo', 3]],
      cavalry: [['katapeltes', 5], ['murmillo', 3]],
    };
    const plan = compositions[s.enemy].map(([key, count]) => ({
      key, name: units[key][0], building: units[key][1], target: Math.ceil(count * scale),
      current: s[key],
    }));
    if (s.age >= 3 && s.fortified && s.otherSiege === 0) {
      plan.push({ key: 'destroyer', name: units.destroyer[0], building: units.destroyer[1],
        target: s.age === 3 ? 2 : 3, current: s.destroyer });
    }
    return plan;
  }

  function tactics(s, antiMyth) {
    if (s.pressure) return action('Defenda a base', 'Recolha os aldeões ameaçados e lute perto do Centro da Cidade. Reavalie a saída depois de repelir o ataque.');
    if (s.age === 1) return action('Explore o mapa', 'Use os Oráculos para ver a aproximação inimiga enquanto prepara a primeira produção militar.');
    if (s.readyArmy === null) return action('Informe quantas tropas estão prontas', 'Preencha o campo em Seu exército para avaliar uma saída com as tropas que já podem lutar.');
    if (s.readyArmy < 5) return action('Monte o primeiro grupo', 'Junte pelo menos cinco unidades de combate antes de planejar uma saída.');
    if (s.strength === 'stronger') return action('Evite a batalha direta', 'Reforce seu exército e use a visão dos Oráculos para antecipar o próximo movimento inimigo.');
    if (s.heroes < antiMyth) return action('Prepare heróis antes da luta', 'Você viu unidades míticas. Leve heróis de combate suficientes para enfrentá-las.');
    if (s.strength === 'unknown') return action('Atualize a visão do inimigo', 'Confirme onde está o exército inimigo e por onde você pode recuar.');
    if (s.exposed) return action('Ataque a economia exposta', 'Pressione uma mina de ouro ou fonte de comida. Recue se o exército inimigo chegar em força.');
    if (s.fortified && s.readySiege < 2) return action('Prepare unidades contra prédios', 'Fique fora do alcance das defesas. A partir da Heroica, use Destroyers do Palácio para abrir caminho.');
    if (s.strength === 'weaker') return action(s.fortified ? 'Pressione com o grupo de cerco' : 'Pressione e tome espaço', 'Mantenha os reforços chegando e uma rota de retirada. Pare se perder a vantagem.');
    return action('Mantenha a pressão sem se comprometer', 'Controle o mapa e procure uma economia exposta ou espere reforços antes de aceitar uma batalha equilibrada.');
  }

  function capacity(s, free) {
    if (s.housingPending || s.expansion === 'building') return null;
    if (s.housing === 'manor') return action('Construa uma casa atlante (Manor)', `Você tem ${free} vagas. Abra espaço antes de travar as filas.`, 'manor');
    if (s.housing === 'tc' && s.age >= 2 && !s.pressure && s.strength !== 'stronger') {
      if (s.expansion === 'ready') return startCenter();
      if (s.expansion === 'secure') return savingCenter();
      return action('Localize um assentamento que você possa defender', 'As casas chegaram ao limite. Use os Oráculos para conferir a rota e o terreno antes de mandar aldeões.');
    }
    return action('Libere espaço para reforços', 'Reavalie a fila de aldeões se a economia já comporta seu exército. Aguarde espaço para recompor com unidades que respondam ao inimigo.');
  }

  function startCenter() {
    return action('Construa um Centro da Cidade', 'Pegue o assentamento seguro que você registrou. Ele amplia a população e abre outra fila de aldeões. Proteja os construtores com o exército.', 'startCenter', 'center');
  }

  function savingCenter() {
    return action('Junte recursos para o próximo Centro da Cidade', 'Reserve madeira e ouro. Marque o assentamento como pronto quando puder pagar a obra e ainda sustentar a defesa.', undefined, 'center');
  }

  function train(s, entry, free) {
    const [name, building, need, population, costs] = units[entry.key];
    if (!at(s, need)) return action(`Construa ${building}`, `Você precisa dessa construção para treinar ${name}.`, need);
    const count = Math.min(entry.target - entry.current, Math.floor(free / population));
    if (count < 1) return capacity(s, free) ?? action('Aguarde a construção de população', `Faltam vagas para treinar ${name}.`);
    if (!s.pressure && s.queues === need && s.shortage === 'none')
      return action(`Construa mais um ${building}`, 'A fila atual está ocupada e sobram recursos. Divida a produção entre os prédios.', 'queues');
    const bank = stock(s);
    const balance = costs.map((cost, index) =>
      cost > 0 && Number.isFinite(bank[index]) ? Math.floor(bank[index] / cost) : Infinity);
    const batch = Math.min(count, 5, ...balance);
    if (batch < 1) {
      const missing = deficits(costs, bank);
      return { ...action(`Junte recursos para treinar ${name}`,
        `O HUD mostra que faltam ${describeDeficit(missing)} para a próxima unidade em ${building}.`, undefined, 'training'),
        missing };
    }
    return { ...action(`Treine ${batch} × ${name}`, `Use ${building}. A meta do grupo é ${entry.target}.`),
      training: { key: entry.key, count: batch } };
  }

  function nextAction(s, plan, total, free, antiMyth, attack) {
    const missing = plan.find(entry => entry.current < entry.target);
    const promotable = Math.max(0, (s.readyArmy ?? s.heroes) - s.heroes);
    const hero = action(`Promova ${Math.min(antiMyth - s.heroes, promotable)} unidade(s) de combate a herói`, 'A promoção responde às unidades míticas avistadas. Confira o favor disponível e use heróis à distância contra alvos aéreos.');
    const canPromote = s.heroes < antiMyth && promotable > 0;
    if (s.pressure && canPromote) return hero;
    if (s.pressure && (s.age === 1 || !missing || s.strength === 'stronger')) return attack;
    if (free <= (s.age === 1 ? 4 : 8) && !s.housingPending && s.expansion !== 'building' && s.housing !== 'capped' && (!s.pressure || free < 2))
      return capacity(s, free);
    if (!at(s, 'autoqueue') && !s.pressure && s.age === 1)
      return action('Ative a Autoqueue de aldeões no Centro da Cidade', 'Depois, aplique a prioridade personalizada mostrada abaixo.', 'autoqueue');
    if (!at(s, 'guild') && !s.pressure)
      return action('Construa a Guilda Econômica', 'Use um aldeão. Assim que terminar, mande-o de volta à coleta.', 'guild');
    if (s.age === 1) {
      if (s.advance === 'researching')
        return action('Prepare a produção militar', 'Redistribua a coleta para madeira e ouro e use os Oráculos para ver de onde pode vir o ataque. Atualize a era quando concluir.');
      if (!at(s, 'forest')) return action('Crie a Floresta de Gaia perto da base', 'Use-a para abastecer suas primeiras construções.', 'forest');
      if (!at(s, 'scout')) return action('Espalhe os Oráculos', 'Veja os acessos à base e deixe os Oráculos parados em pontos separados para gerar favor.', 'scout');
      if (!at(s, 'temple') && s.citizens >= 5 && s.manors === 0 && s.used === null && !s.housingPending && s.housing === 'manor')
        return action('Construa a primeira casa atlante (Manor)', 'Antecipe o aumento de população antes de avançar. Preencha a população para receber alertas mais precisos.', 'manor');
      if (!at(s, 'temple') && (s.citizens >= 5 || s.advance === 'ready'))
        return action('Construa o Templo', 'O Templo libera o avanço à Era Clássica.', 'temple');
      if (s.advance === 'ready' && at(s, 'temple'))
        return action('Avance para a Era Clássica', 'Oceano é a rota inicial sugerida. Marque o avanço assim que iniciar a pesquisa.', 'advance');
      const tech = upgrades.slice(0, 2).find(([key]) => !at(s, key));
      if (tech && !at(s, 'temple') && s.citizens >= 3 && s.shortage === 'none') return research(tech);
      if (s.citizens < 5 && !at(s, 'temple'))
        return action('Suba para 5 aldeões com a Autoqueue', 'Mantenha a coleta. Enquanto os aldeões saem, use os Oráculos para reconhecer o mapa e atualize a contagem.');
      return action('Junte recursos para a Era Clássica', 'Mantenha a coleta de comida e reserve os recursos do Templo. Marque quando tiver o necessário para avançar.', undefined, 'ageUp');
    }
    if (canPromote) return hero;
    if (s.pressure && missing) return train(s, missing, free);
    if (s.food === 'low' && !s.farmPending)
      return action('Construa 2 fazendas perto da base', 'Transfira parte dos aldeões da comida. Amplie aos poucos enquanto a caça e outras fontes seguras acabam.', 'farmPending');
    if (s.walls === 'raids' || (s.walls === 'open' && (s.enemy === 'cavalry' || s.age >= 3) && s.readyArmy >= 5))
      return action('Mure as passagens que expõem sua economia', 'Feche os trechos curtos perto da madeira e do ouro. Use o terreno para economizar e deixe um portão para reforços e retirada.', 'closeWalls', 'walls');
    if (s.centers > 1 && !at(s, 'expansionQueue') && !(s.housing === 'capped' && free < 8))
      return action('Revise a Autoqueue do novo Centro da Cidade', 'Ative a fila de aldeões se ainda houver vagas e comida para sustentar a economia e o exército.', 'expansionQueue');
    const canTrain = missing && free >= units[missing.key][3];
    if (canTrain && (total < (s.age === 2 ? 5 : 8) || s.strength === 'stronger'))
      return train(s, missing, free);
    const canExpand = s.readyArmy >= 5 && ['even', 'weaker'].includes(s.strength) &&
      (s.centers === 1 ? s.citizens >= 10 : s.age >= 3 && s.citizens >= 22 && s.centers === 2);
    if (canExpand && s.expansion === 'ready') return startCenter();
    const prerequisite = s.age === 2 && !at(s, 'armory') && !at(s, 'market') ? 'armory'
      : s.age === 3 && !at(s, 'palace') ? 'palace' : null;
    if (prerequisite && s.advance !== 'researching') return action(`Construa o ${buildings[prerequisite]}`,
      prerequisite === 'armory' ? 'O Arsenal abre o avanço à Heroica e melhorias militares. Um Mercado pronto também libera o avanço.' : 'O Palácio abre o avanço à Mítica e treina Destroyers.', prerequisite);
    if (s.age < 4 && s.advance === 'ready') return action(`Avance para a Era ${s.age === 2 ? 'Heroica' : 'Mítica'}`, 'Mantenha reforços suficientes para defender durante a transição.', 'advance');
    if (s.age < 4 && s.advance === 'researching') return action('Organize os reforços durante a transição', 'Mantenha os aldeões trabalhando e atualize a era quando o avanço terminar.');
    if (s.age === 4 && s.advance === 'ready' && s.strength !== 'stronger')
      return action('Construa a Maravilha', 'Escolha uma área defendida e proteja a obra com o exército. Atualize a era quando terminar.', 'advance');
    if (canExpand && s.expansion === 'secure' && s.advance !== 'researching') return savingCenter();
    if (canTrain) return train(s, missing, free);
    const line = s.enemy === 'archers' || s.enemy === 'infantry' ? 'rangedTech' : 'infantryTech';
    if (!at(s, line) && total >= 5 && s.shortage === 'none') return action(
      line === 'rangedTech' ? 'Pesquise a próxima melhoria da sua tropa à distância' : 'Pesquise a próxima melhoria da sua infantaria',
      'Confira a melhoria de linha no prédio que treina suas unidades. Se já estiver no máximo disponível, marque como feita.', line);
    const tech = upgrades.find(([key, , resource, age, previous]) => s.age >= age && !at(s, key) &&
      (!previous || at(s, previous)) && (resource !== 'fazendas' || s.age >= 4 || s.food === 'farms' || s.farmPending));
    if (tech && (s.shortage === 'none' || s.age >= 4)) return research(tech);
    if (s.age < 4 && s.advance === 'saving')
      return action(`Reserve recursos para a Era ${s.age === 2 ? 'Heroica' : 'Mítica'}`, 'Continue repondo perdas. Evite gastar a reserva com construções ou pesquisas sem uso imediato.', undefined, 'ageUp');
    if (s.age >= 4 && s.titanAllowed && !at(s, 'titan') && s.advance !== 'researching')
      return action('Desbloqueie e construa o Portão do Titã', 'Se o modo permitir e houver recursos de sobra, pesquise o desbloqueio e proteja a obra. Marque a conclusão no painel.', 'titan');
    if (s.age >= 4 && s.shortage === 'gold' && !at(s, 'market'))
      return action('Construa um Mercado para preparar o comércio', 'Planeje uma rota segura de caravanas para complementar o ouro.', 'market');
    if (missing && s.strength !== 'weaker') return train(s, missing, free);
    return attack;
  }

  function research([key, name, resource]) {
    return action(`Pesquise ${name} na Guilda Econômica`, `Benefício para ${resource}. Se faltar recurso, selecione o gargalo para ajustar a coleta.`, key, 'research');
  }

  function economy(s, next, free) {
    let percentages = s.centers > 1 ? [50, 25, 25] : [45, 30, 25];
    let reason = s.centers > 1 ? 'Sustente a comida das filas de aldeões e mantenha recursos para reforços.' : 'Distribuição para sustentar aldeões, produção e reforços.';
    if (s.age === 1) {
      if (s.citizens <= 2) percentages = [100, 0, 0];
      else if (s.citizens === 3) percentages = [67, 33, 0];
      else if (s.citizens === 4) percentages = [50, 25, 25];
      else percentages = at(s, 'temple') ? [75, 10, 15] : [60, 20, 20];
      reason = 'Concentre a abertura em comida e desloque aldeões para pagar as primeiras construções.';
    }
    if (s.age > 1 && s.pressure) {
      percentages = s.enemy === 'archers' || s.enemy === 'infantry' ? [30, 40, 30] : [50, 20, 30];
      reason = 'Use as fontes protegidas para financiar os reforços.';
    } else if (next.goal === 'center') {
      percentages = [30, 35, 35];
      reason = 'Acumule madeira e ouro para o Centro da Cidade, mantendo comida para a fila atual.';
    } else if (next.goal === 'walls') {
      percentages = [40, 20, 40];
      reason = 'Reserve ouro para fechar os acessos sem parar a fila de aldeões.';
    } else if (['farmPending', 'manor', 'military', 'counter', 'queues'].includes(next.mark)) {
      percentages = [40, 45, 15];
      reason = 'A próxima construção pede mais madeira.';
    } else if (['temple', 'armory', 'palace', 'market'].includes(next.mark)) {
      percentages = [35, 35, 30];
      reason = 'Prepare madeira e ouro para o próximo prédio e mantenha a fila de aldeões.';
    } else if (next.mark === 'expansionQueue') {
      percentages = [55, 25, 20];
      reason = 'Reforce a comida para sustentar a produção em mais de um Centro da Cidade.';
    } else if (s.age < 4 && (next.mark === 'advance' || next.goal === 'ageUp')) {
      percentages = s.age === 1 ? [80, 10, 10] : s.age === 2 ? [55, 15, 30] : [50, 15, 35];
      reason = s.age === 1 ? 'Priorize comida para chegar à Clássica.' : 'Dê prioridade à comida e ao ouro para financiar o avanço.';
    } else if (s.age < 4 && s.advance === 'researching' && !next.training) {
      percentages = [40, 35, 25];
      reason = 'Acumule madeira e ouro durante o avanço para montar a produção da próxima era.';
    } else if (s.age === 4 && (next.mark === 'advance' || s.advance === 'researching')) {
      percentages = [34, 33, 33];
      reason = 'Divida a coleta para financiar a Maravilha e manter a defesa.';
    } else if (next.training) {
      const key = next.training.key;
      percentages = key === 'cheiro' ? [25, 40, 35] : key === 'turma' ? [35, 35, 30] : [55, 15, 30];
      reason = `Financie a leva de ${units[key][0]} e mantenha comida para os aldeões.`;
    } else if (next.goal === 'research' && s.age > 1) {
      percentages = [40, 25, 35];
      reason = 'Reserve ouro para a próxima pesquisa econômica.';
    } else if (s.age > 1 && ['archers', 'infantry'].includes(s.enemy)) {
      percentages = [35, 35, 30];
      reason = 'Reserve mais madeira e ouro para unidades do Quartel de Contra-Ataque.';
    }
    const resource = ['food', 'wood', 'gold'].indexOf(s.shortage);
    if (resource >= 0) {
      percentages = percentages.map((weight, index) => weight * 0.8 + (index === resource ? 20 : 0));
      percentages = staffing(100, percentages);
      reason = `Ajuste temporário para cobrir a falta de ${['comida', 'madeira', 'ouro'][resource]}.`;
    } else {
      const missing = next.missing ?? (next.goal === 'ageUp' && ageCosts[s.age] ? deficits(ageCosts[s.age], stock(s)) : []);
      const totalMissing = missing.reduce((sum, amount) => sum + amount, 0);
      if (totalMissing > 0) {
        percentages = staffing(100, missing.map((amount, index) => [25, 10, 10][index] + 55 * amount / totalMissing));
        const objective = next.goal === 'ageUp' ? 'o avanço' : 'a próxima unidade';
        reason = `O HUD ainda mostra falta de ${describeDeficit(missing)} para ${objective}.`;
      }
    }
    if (free < 3 && s.housing === 'capped' && s.age >= 3)
      reason += ' Se a economia já sustenta os reforços, considere pausar a Autoqueue para parar de disputar vagas com o exército.';
    const points = staffing(priorityBudget, percentages);
    return { points, reason };
  }

  function recommend(s) {
    const costs = ageCosts[s.age];
    const bank = stock(s);
    if (s.advance === 'saving' && costs && costs.every((cost, index) => cost === 0 || bank[index] >= cost))
      s = { ...s, advance: 'ready' };
    const free = s.used === null || s.cap === null ? Infinity : Math.max(0, s.cap - s.used);
    const total = Object.keys(units).reduce((sum, key) => sum + s[key], s.otherArmy + s.otherSiege);
    const antiMyth = s.age > 1 ? Math.min(12, Math.ceil(s.enemyMyths * 1.5)) : 0;
    const plan = armyPlan(s);
    const attack = tactics(s, antiMyth);
    const next = nextAction(s, plan, total, free, antiMyth, attack);
    return { next, plan, attack, antiMyth, total, free, economy: economy(s, next, free) };
  }

  return { initial, buildings, units, upgrades, recommend };
})();

if (typeof module !== 'undefined') module.exports = GaiaAdvisor;
