# Changelog

Histórico de versões do fork klsh do ox_inventory. A versão do fork fica em `klsh_version` no `fxmanifest.lua`; o campo `version` continua sendo a versão do original que serve de base.

Cada versão traz **tudo o que mudou desde a versão anterior**, sempre nestas quatro seções:

- **Adicionado:** o que passou a existir.
- **Removido:** o que deixou de existir ou de funcionar como antes.
- **Ajuste:** mudança de comportamento em algo que já existia.
- **Bugs consertados:** só defeitos relatados de fora (jogadores, donos de servidor, issues). Correções feitas durante o desenvolvimento de uma funcionalidade nova não entram aqui.

Seção sem itens aparece como "Nada nesta versão".

## 0.22.1 (2026-11-17)

Mudanças desde a 0.18.1.

### Adicionado

**Arremesso de itens**
- Menu de contexto → **Arremessar**: o inventário fecha e o item vai para a mão. Segurar o botão esquerdo carrega a força (com barra na tela), soltar joga; botão direito ou Backspace cancela.
- **Tecla para o item na mão** (padrão `G`, configurável por jogador): arremessa a arma equipada, com a munição que ela tem.
- O item vira um drop onde cair. Qualquer item dentro do peso máximo pode ser arremessado (5 kg por padrão); item mais pesado vai menos longe.
- **Alvos:** item que cai junto de uma lixeira ou da boca de um porta-malas aberto e destrancado tem chance de entrar direto, menor quanto maior a distância e o peso. Errou ou não coube: cai ao lado, com aviso.
- **De dentro do veículo:** qualquer banco, desde que haja uma abertura ao lado (vidro abaixado ou quebrado, porta aberta ou arrancada). Em moto, bicicleta e quadriciclo a direção é livre.
- Config em `data/throw.lua`: tecla, peso máximo, intervalo, tempo de carga, alcance, raio e chance dos alvos, arremesso de dentro do veículo.
- `exports.ox_inventory:SetThrowBonus(source, valor)`: soma chance de acertar o alvo para um jogador (ponto de entrada para sistemas de perícia).
- Campo `klshThrow = true` no hook `swapItems` quando o item foi arremessado.

**Morte, limpeza e confisco**
- `ConfiscateInventory(source, { discard = { ... } })`: lista opcional de itens destruídos na hora do confisco em vez de guardados para a devolução. Vale para o inventário, o colete, a mochila vestida e o conteúdo de mochilas e bolsas confiscadas.
- `/takeinv <id> [itens]` aceita a lista de descarte.
- Mochila vestida (com o conteúdo) e colete passam a ser guardados no confisco e devolvidos por `ReturnInventory`.

**Drops**
- Item largado ou arremessado a até 1,5 m de um drop que tenha espaço entra nesse drop, em vez de criar outro ao lado (`drop.merge` em `data/grid.lua`).

### Removido

Nada nesta versão.

### Ajuste

- `ClearInventory` em jogador (por exemplo, no respawn do hospital) passa a destruir também a mochila vestida, com o conteúdo, e o colete; a roupa continua no corpo. Itens listados em `keep` são mantidos.
- `ConfiscateInventory` devolve `true` quando confisca e `false`, sem alterar nada, quando o personagem já tem um confisco esperando devolução (antes o segundo confisco sobrescrevia o primeiro).
- `ReturnInventory` devolve mochila e colete ao slot de equipamento; com o slot ocupado, vão para o inventário.
- `CreateDropFromPlayer` põe mochila e colete num drop próprio ao lado.
- Scripts de prisão que copiam a lista de itens e chamam `ClearInventory` fazem o preso perder mochila e colete: devem usar `ConfiscateInventory` e `ReturnInventory`.
- Largar um item num drop aberto que não tem espaço para ele cria um drop novo ao lado, em vez de só recusar.
- No hook `swapItems`, ao largar um item junto de um drop com espaço, `toInventory` é o id desse drop (antes era sempre `'newdrop'`).
- O campo `repository` do `fxmanifest.lua` aponta para o repositório do fork.

### Bugs consertados

Nada nesta versão.

## 0.18.1 (2026-11-16)

Primeira versão pública. A comparação é com o `overextended/ox_inventory` no commit `ca61e6d` (2.48.1+).

### Adicionado

**Inventário em grade**
- Cada item ocupa largura × altura em células (`size` no item) e pode ser girado com **R** durante o arrasto.
- Limite de pilha por item (`maxStack`); acima do limite abre outra pilha.
- Vale para jogador (8 × 5), mochilas, baús, porta-malas, porta-luvas, lixeiras, containers, evidências, chão e revista.
- Realce do destino ao arrastar: verde (cabe ou empilha), amarelo (troca), vermelho (não cabe).
- Soltar um item sobre outro troca os dois quando cada um cabe no lugar do outro.
- **Carteira:** dinheiro e dinheiro sujo ficam em dois slots próprios do jogador, fora da grade; sempre cabem e podem ser levados na revista.
- Inventários já existentes são convertidos na primeira carga, sem apagar nada (o que não couber fica em linhas extras que só podem ser esvaziadas).
- Tamanho do porta-malas e do porta-luvas por classe de veículo e por modelo (`data/vehicles.lua`).
- Baús aceitam `slots = { largura, altura }` em `data/stashes.lua`, `RegisterStash` e `CreateTemporaryStash`.

**Roupas como itens**
- Inventário de equipamento por personagem, com 14 slots: chapéu, máscara, óculos, orelhas, pescoço, torso, camiseta, luvas, colete, mochila, calça, sapatos, relógio e pulseira.
- Itens `clothing_*`, um por categoria; a peça (modelo de corpo, número e variante) fica no metadata.
- Vestir e tirar leva tempo por categoria, tem animação e é bloqueado em veículo, combate, mira, nado, queda, algemado e morto.
- Roupa só serve no modelo de corpo para o qual foi feita.
- O que o personagem já veste vira item na primeira vez que o inventário é aberto.
- Adaptador de aparência para illenium-appearance (ou só natives, ou nenhum).
- Roupa vestida não pesa; o tooltip mostra modelo, peça e variante.

**Mochilas**
- Itens `backpack_small`, `backpack_medium` e `backpack_large`, configuráveis em `data/equipment.lua` (grade, peso máximo, redução de peso, visual, whitelist e blacklist).
- Mochila vestida aparece como seção própria do inventário e pesa menos no inventário principal, conforme a redução do modelo.
- "Abrir" no menu de contexto para mexer numa mochila sem vestir.

**Colete**
- O item `armour` é vestido no slot de colete e guarda a armadura restante: vestir aplica, levar tiro desgasta, tirar salva o valor.

**Movimentação**
- Tempo de transferência por peso ao mover entre inventários diferentes, com progresso no item.
- Fila de ações: movimentos pedidos durante outro ficam em fila e rodam em ordem.
- A tecla do inventário só esconde a tela enquanto a fila roda; Esc e o X do item cancelam.
- Seção do chão abaixo do inventário secundário, com o drop mais próximo.
- "Dar" com tempo e animação nos dois jogadores.
- Cinco atalhos (teclas 1 a 5) que apontam para itens da grade, guardados por personagem.

**Revista**
- `exports.ox_inventory:SearchPlayer(source, target, { notify?, distance? })` para outros scripts abrirem a revista.
- Quem revista vê inventário, carteira, roupas, colete, mochila e o conteúdo dela, e pode levar tudo.
- Evento `ox_inventory:klsh:playerSearched` e comando de admin `/searchplayer <id>`.

**Loja de roupa e guarda-roupa**
- O visual é escolhido no illenium-appearance; cada peça trocada dentro de uma loja de roupa é cobrada (`price` por categoria) e vira item. Sem dinheiro para tudo, nada muda.
- Personagem novo nasce com as peças escolhidas na criação como itens.
- Guarda-roupa como baú pessoal (`klsh_wardrobe`) nos pontos de `wardrobes.coords`.

**Outros**
- Renomear itens pelo menu de contexto; o nome viaja com o item e o original aparece no tooltip.
- **Bolsa de estilo** (`outfit_bag`): guarda um visual de até 12 peças; "Usar" troca tudo o que o personagem veste pelo que está na bolsa.
- Entrega sem espaço: `AddItem` chamado por outro resource deixa o excedente num drop público por 15 minutos (evento `ox_inventory:klsh:itemOverflow`).
- Documentação: `CONFIG.md`, `INTEGRATION.md` e este changelog.
- Testes da geometria da grade fora do jogo (`tests/`).

### Removido

- Uso do `armour` como consumível (agora é o colete do slot de equipamento).
- Convar `inventory:slots` para o jogador: o tamanho vem de `data/grid.lua`.
- Checagem de versão contra os releases do original (`inventory:versioncheck` deixou de ter efeito).
- Workflow de release do original (`.github/workflows` e `.github/actions`), que depende de segredos da Overextended.
- Atualização otimista da interface em inventários com grade: todo movimento espera a resposta do servidor.
- Barra rápida lendo os cinco primeiros slots do inventário (substituída pelos atalhos).

### Ajuste

- `AddItem` em jogador passou a ser tudo ou nada e reparte a quantidade em pilhas conforme `maxStack`.
- `CanCarryItem`, `GetEmptySlot`, `GetSlotForItem` e `GetItemSlots` respondem pelo encaixe na grade e pelo limite de pilha.
- `slot` de um item passou a ser só um identificador; a posição fica em `x`, `y` e `rotated`. Hooks `swapItems` recebem também os tipos `equipment`, `backpack`, `ground`, `otherequipment` e `otherbackpack`.
- Itens dentro de mochilas e bolsas não contam para `GetItemCount`, `Search` e `RemoveItem` do jogador.
- Recarregar soma a munição de todas as pilhas do mesmo tipo.
- Crafting confere se o resultado cabe antes de consumir os ingredientes.
- Loja abre várias pilhas quando a compra passa do limite e escolhe a posição no servidor.
- "Usar" numa roupa veste a peça; "Usar" numa mochila veste; "Abrir" é uma ação separada.
- Mudança de roupa fora de loja (outfits, uniformes) é desfeita, exceto para quem tem a ACE `command.pedmenu`.
- Depois de cada troca, o visual é salvo no illenium-appearance para o login mostrar o que está equipado.
- Build da interface achatado em `web/build/index.{html,js,css}`.

### Bugs consertados

Nada nesta versão.
