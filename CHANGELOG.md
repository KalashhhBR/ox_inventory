# Changelog

Histórico de versões do fork klsh do ox_inventory. A versão do fork fica em `klsh_version` no `fxmanifest.lua`; o campo `version` continua sendo a versão do original que serve de base.

Cada versão traz **tudo o que mudou desde a versão anterior**, sempre nestas quatro seções:

- **Adicionado:** o que passou a existir.
- **Removido:** o que deixou de existir ou de funcionar como antes.
- **Ajuste:** mudança de comportamento em algo que já existia.
- **Bugs consertados:** só defeitos relatados de fora (jogadores, donos de servidor, issues). Correções feitas durante o desenvolvimento de uma funcionalidade nova não entram aqui.

Seção sem itens aparece como "Nada nesta versão".

## 0.27.0 (2026-11-21)

Mudanças desde a 0.24.1.

### Adicionado

- **Fontes dentro do resource:** Inter, Rajdhani e Roboto vão junto com a interface (`web/build/*.woff2`); a tela não busca mais nada na internet.
- **Exports para scripts de loja e entrega** (detalhes no `INTEGRATION.md`):
  - `CanCarryItems`: responde se uma lista inteira de itens cabe, contando opcionalmente a mochila vestida.
  - `AddItemToPlayer`: entrega em bolsos e depois na mochila vestida, sem nunca jogar excedente no chão.
  - `SetAttachedInventory`: um inventário de outro script aparece junto do chão quando o jogador abre um porta-malas ou baú.
  - `SealInventory`: inventário de onde só sai item, com nome próprio quando é um drop.
  - `SetDropExpiry`: prazo fixo para um drop.
- Limitações das lixeiras e do menu de contexto documentadas no `CONFIG.md`.

### Removido

- Links do Google Fonts na interface.

### Ajuste

- A seção do chão ganha uma página a mais quando há um inventário anexado ao jogador.
- Um drop com nome próprio mostra esse nome no lugar de "Chão".

### Bugs consertados

Nada nesta versão.

## 0.24.1 (2026-11-18)

Mudanças desde a 0.22.1.

### Adicionado

**Interface nova**
- Tela redesenhada em três zonas: à esquerda o que o jogador carrega (bolsos e mochila vestida), no centro o personagem com os slots de roupa, os atalhos, a carteira e o campo de quantidade, e à direita o inventário aberto (porta-malas, baú, revista) com o chão embaixo.
- Barra de abas no topo. **Inventário** é a única ativa; Saúde, Crafting e Habilidades aparecem apagadas, reservadas para versões futuras.
- **Busca** em cada inventário da tela: o que não bate com o texto fica apagado.
- **Peso no item:** cada item mostra o peso total da pilha; o tooltip traz peso por unidade e peso total. O cabeçalho dos bolsos mostra o total carregado (bolsos mais mochila, já com a redução) sobre o máximo.
- **Campo Quantidade** no centro da tela: vale para arrastar, mover rápido, soltar no chão e para a carteira. Vazio significa tudo.
- **Dividir** pelo menu de contexto, com uma janela para escolher quanto separar.
- **Arrastar para fora dos inventários larga no chão.**
- **Arrastar para o personagem:** roupa, colete e mochila são vestidos (trocando com o que estiver no slot); os outros itens são usados.
- **Menu de contexto** (botão direito) no visual novo, com Usar, Vestir, Mover rápido, Dividir, Arremessar, Dar, Renomear e Soltar no chão.
- **Carteira arrastável e com menu próprio:** dinheiro e dinheiro sujo podem ser arrastados para outro inventário, para o chão, dados ou arremessados.
- **Navegação entre drops:** com mais de um drop ao alcance, setas no cabeçalho do chão trocam o drop mostrado.
- **Avisos dentro do inventário:** com a tela aberta, as notificações do ox_lib aparecem também por cima dela, no mesmo estilo.
- Rodapé com as teclas (girar, metade, mover rápido, usar, ações).
- Destaque vermelho ao tentar soltar parte de uma pilha em cima dela mesma.
- Chaves `ui_*` novas em `locales/` (abas, rótulos, dicas), mais `ui_decimal` e `ui_thousands` para os separadores dos números.
- Seção "Interface" no `CONFIG.md`.

### Removido

- O botão e a área "Soltar" da interface antiga: largar passa a ser arrastar para fora ou usar o menu.
- O "×" antes da quantidade no item.

### Ajuste

- Na revista, roupas e carteira do revistado ficam num bloco só, "Equipamento e carteira".
- A carteira ocupa dois slots quadrados (imagem e quantidade); sem dinheiro, o slot fica vazio.
- Cada inventário ocupa na tela a largura da própria grade. Quando a coluna passa da altura da tela, só o último inventário dela ganha rolagem.
- Tamanhos padrão para alinhar a tela: chão `10 × 5` (`drop` em `data/grid.lua`), mochila pequena `8 × 2` e média `8 × 4` (`backpacks` em `data/equipment.lua`). Quem já ajustou esses arquivos não precisa mudar; a grade só fica mais estreita que a coluna.
- Item largado num drop novo entra na primeira posição livre, e não na posição que tinha no inventário de origem.
- A interface é medida a partir de uma área 16:9 centralizada: em telas 5:4 e ultrawide ela não passa mais da largura.
- Fontes Inter e Rajdhani carregadas do Google Fonts em `web/index.html`.

### Bugs consertados

Nada nesta versão.

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
