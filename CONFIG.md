# ox_inventory (fork klsh): guia de configuração

Onde mexer para balancear e adaptar o inventário. Tudo fica em `data/`; depois de editar, reinicie o
resource (ou o servidor). Código e chaves em inglês; este guia em português.

Regra do fork: **a configuração de uma coisa fica junto dessa coisa.** Tamanho de item no item, de
mochila na mochila, de porta-malas na classe do veículo. `data/grid.lua` guarda só o que é geral.

## Mapa rápido

| Quero mudar | Arquivo | Chave |
|---|---|---|
| Tamanho do inventário do jogador | `data/grid.lua` | `player = { w, h }` |
| Tamanho do chão (drops) | `data/grid.lua` | `drop = { w, h }` |
| Peso máximo do jogador | `ox.cfg` do servidor | convar `inventory:weight` |
| Tamanho e pilha de um item | `data/items.lua` | `size`, `maxStack` no item |
| Tamanho de arma, acessório, munição | `data/weapons.lua` | `size`, `maxStack` no item |
| Mochilas (espaço, peso, redução) | `data/equipment.lua` | `backpacks` |
| Porta-malas e porta-luvas | `data/vehicles.lua` | `trunk`, `glovebox` |
| Baús fixos | `data/stashes.lua` | `slots`, `weight` |
| Carteira, excedente no chão, padrões | `data/grid.lua` | `wallet`, `overflowTime`, `neverDrop`, `default*` |
| Roupas: categorias e tempo de troca | `data/equipment.lua` | `categories` |
| Tempo de transferência por peso | `data/equipment.lua` | `transfer` |
| Colete | `data/equipment.lua` | `vest` |
| Seção "Chão" ao abrir outro inventário | `data/equipment.lua` | `groundDistance` |
| Revista (distância e aviso ao alvo) | `data/equipment.lua` | `search` |
| Loja de roupa (preço por peça, onde vale) | `data/equipment.lua` | `categories[...].price`, `shop` |
| Guarda-roupas pessoais | `data/equipment.lua` | `wardrobes` |
| Renomear itens (tamanho máximo do nome) | `data/equipment.lua` | `rename` |

## Grade

Todo inventário com grade tem largura × altura em células. Cada item ocupa `size` células e pode ser
girado 90° (tecla **R** enquanto arrasta).

```lua
-- data/grid.lua
enabled = true,          -- false volta para a tela de slots sem perder nada
forceUnit = false,       -- true faz todo item valer 1 x 1
player = { w = 8, h = 5 },
drop = { w = 8, h = 5 },
```

Diminuir uma grade não apaga nada: o que não couber fica em linhas extras no fim, de onde só dá para
tirar. Elas somem quando esvaziam.

### Itens

```lua
-- data/items.lua
['water'] = {
    label = 'Water',
    weight = 500,
    size = { 1, 2 },     -- largura, altura. Sem `size`: 1 x 1
    maxStack = 5,        -- máximo por pilha. false = sem limite. Sem `maxStack`: defaultStack (20)
```

- Armas ficam em `data/weapons.lua`, em `Weapons`; acessórios em `Components`; munição em `Ammo`.
- `maxStack` não vale para item que não empilha (`stack = false`, armas).
- Pilha que já existia acima do limite é mantida, só não cresce.
- Nenhum item pode ser maior que a grade do jogador nos dois sentidos (hoje 8 × 5).

### Mochilas

```lua
-- data/equipment.lua
backpacks = {
    backpack_medium = {
        grid = { 6, 5 },       -- espaço em células
        slots = 15,            -- só usado com a grade desligada
        maxWeight = 20000,     -- gramas que a mochila aguenta
        reduction = 0.3,       -- 0.3 = o conteúdo pesa 30% menos no inventário principal
        drawable = { mp_m_freemode_01 = { 45, 0 }, mp_f_freemode_01 = { 45, 0 } },
        -- whitelist = { 'water' }, blacklist = { 'WEAPON_RPG' },  (opcionais)
    },
```

Mochila nova: crie o item em `data/items.lua` (copie um `backpack_*`, com `stack = false`) e a entrada
aqui com o mesmo nome. O tamanho que a mochila ocupa como item é o `size` dela em `items.lua`.

### Veículos

```lua
-- data/vehicles.lua
trunk = {
    [0] = {{ 6, 4 }, 168000},     -- Compact: 6 x 4 células, 168 kg
    [2] = {{ 10, 6 }, 408000},    -- SUV
    models = {
        [`xa21`] = {{ 4, 3 }, 10000},   -- este modelo ignora a classe
    },
},
```

- O número entre colchetes é a classe do veículo no GTA (0 Compact, 1 Sedan, 2 SUV, 3 Coupe, 4 Muscle,
  5 Sports Classic, 6 Sports, 7 Super, 8 Motorcycle, 9 Offroad, 10 Industrial, 11 Utility, 12 Van,
  14 Boat, 15 Helicopter, 16 Plane, 17 Service, 18 Emergency, 19 Military, 20 Commercial).
- Primeiro valor: `{ largura, altura }`. Segundo: peso máximo em gramas.
- `models` vale mais que a classe. Use o nome do modelo entre crases.
- `glovebox` funciona igual.
- Classe sem linha = veículo sem aquele compartimento. `Storage` no topo do arquivo desliga
  porta-malas ou porta-luvas por modelo.
- Um número no lugar do tamanho ainda funciona e significa slots (ver "Só slots" abaixo).

### Baús

```lua
-- data/stashes.lua
{ name = 'police_locker', label = 'Armário', slots = { 8, 6 }, weight = 100000, ... }
```

De outro resource:

```lua
exports.ox_inventory:RegisterStash('meu_bau', 'Meu baú', { 8, 6 }, 100000)
```

`slots` aceita `{ largura, altura }` ou um número.

### Só slots

Inventário que informa só um número de slots (baús de outros resources, lixeiras, evidências) vira
grade assim: largura `width` (10, ou o próprio número se for menor) e altura `slots ÷ largura`
arredondado para cima, nunca abaixo de `minHeight` do tipo.

```lua
-- data/grid.lua
width = 10,
minHeight = { stash = 4, trunk = 4, glovebox = 2, dumpster = 3, container = 1, policeevidence = 5, temp = 4, default = 3 },
overrides = {
    -- ['nome_do_bau'] = { w = 6, h = 4 },   -- por nome do inventário
    -- dumpster = { w = 6, h = 3 },          -- ou por tipo inteiro
},
```

### Carteira e excedente

```lua
-- data/grid.lua
wallet = { 'money', 'black_money' },   -- no jogador ficam fora da grade, sempre cabem
overflowTime = 900,                     -- segundos que o excedente fica no chão
neverDrop = { 'id_card', ... },         -- sem espaço a entrega falha em vez de cair
defaultSize = { 1, 1 },
defaultStack = 20,
```

- Fora do jogador (baú, mochila, chão) dinheiro é um item 1 × 1 sem limite de pilha.
- Item entregue por outro resource, por `/giveitem` ou pelo crafting sem espaço: o que não couber vai
  para o chão ao lado do jogador, para qualquer um pegar, por `overflowTime`.

## Roupas, mochila vestida e colete

```lua
-- data/equipment.lua
categories = {
    { name = 'top', type = 'component', id = 11, duration = 4000, items = { 'clothing_top' } },
```

- `duration`: tempo em ms para vestir ou tirar. `testMode = true` divide por 10 (só para teste).
- `items`: itens aceitos no slot. Peça nova: crie o item em `data/items.lua` e inclua o nome aqui.
- `type`/`id`: componente ou prop do ped no GTA. Não mude sem saber o que é.
- `models`: modelos de ped que vestem roupa e o visual "sem roupa" de cada categoria.
- `appearance`: `'auto'`, `'illenium'`, `'natives'` ou `'none'`.
- `vest`: visual do colete por modelo e intervalo de leitura da armadura.
- `anim`: animação da troca.

## Renomear itens

```lua
-- data/equipment.lua
rename = { maxLength = 30 },
```

Menu de contexto → Renomear, em qualquer item menos dinheiro. O nome fica no item (`metadata.label`) e
o tooltip sempre mostra o item original. Nome vazio volta ao original. Com um valor no campo de
quantidade, só essa parte da pilha é renomeada e vira uma pilha separada.

Roupas mostram no tooltip o modelo (masculino ou feminino), a peça e a variante. O texto de cada modelo
vem dos locales: chave `ui_model_<nome do modelo>` (ex.: `ui_model_mp_m_freemode_01`).

## Loja de roupa e guarda-roupa

```lua
-- data/equipment.lua
shop = { stores = 'illenium', radius = 12.0 },
wardrobes = { coords = {}, size = { 8, 6 }, maxWeight = 100000 },
categories = {
    { name = 'top', ..., price = 150, items = { 'clothing_top' } },
```

- O jogador escolhe o visual na loja do illenium-appearance. Ao confirmar, cada peça que mudou é
  cobrada pelo `price` da categoria e vira item no slot; a peça antiga vai para o inventário (ou para o
  chão, sem espaço). Tirar uma peça na loja não custa nada. Sem dinheiro para tudo, nada muda.
- `stores = 'illenium'` lê as lojas do tipo `clothing` do `shared/config.lua` do illenium. Para usar
  outra fonte, troque por uma lista: `stores = { vec3(x, y, z), ... }`. `radius` é a distância da loja
  em que a compra vale.
- Categoria sem `price` não é vendida (colete, mochila, luvas).
- Mudança de roupa fora de loja (outfits, uniformes, `changeOutfit`) é desfeita. Exceção: admin com
  acesso ao `/pedmenu`, que nunca paga (nem dentro de loja) e ganha as peças com registro no log.
- Personagem novo: as roupas escolhidas na criação viram itens no primeiro contato.
- **No illenium** (`shared/config.lua`): deixe `Config.ClothingCost = 0`, senão ele cobra a taxa dele
  além do preço por peça.
- `wardrobes.coords`: lista de `vec3`. Em cada ponto, **E** abre um baú pessoal (um por personagem,
  o mesmo em todos os pontos). Vazio por padrão.

## Tempo de transferência

```lua
-- data/equipment.lua
transfer = { minWeight = 500, msPerKg = 200, max = 3000, giveMin = 1000 },   -- false desliga
groundDistance = 2.0,                                         -- false tira a seção "Chão"
hideDistance = 2.0,                                           -- ver "Tecla do inventário" abaixo
```

Vale ao mover entre inventários diferentes. Abaixo de `minWeight` gramas é instantâneo.
`giveMin` é o tempo mínimo (ms) do "Dar" para outro jogador, que usa a mesma regra de peso e toca
a animação de entrega nos dois.

**Tecla do inventário com movimentos em andamento:** a tecla só esconde a tela e a fila continua;
apertar de novo mostra. Esc e o X do item cancelam. Com baú, porta-malas, chão ou revista abertos,
andar mais de `hideDistance` metros do ponto em que a tela foi escondida fecha o inventário e
cancela o que faltava. Só com o próprio inventário, mochila e roupas não há limite.

## Revista

```lua
-- data/equipment.lua
search = { distance = 2.0, notify = true },
```

Outros scripts abrem a revista com `exports.ox_inventory:SearchPlayer(source, target, opções)`; ver
`INTEGRATION.md`. `notify = false` aqui desliga o aviso ao alvo para todas as revistas.

## Atalhos (teclas 1 a 5)

Sem configuração: o jogador arrasta um item do inventário para um dos cinco slots "Atalhos". Fica
salvo por personagem no PC do jogador. Botão direito limpa.

## Para outros resources

Lista completa em `INTEGRATION.md`. Resumo:

- `exports.ox_inventory:AddItem` em jogador: reparte por `maxStack`; o que não couber cai no chão e a
  chamada retorna `true`. Terceiro retorno: `{ dropId, count }` quando algo caiu.
- `CanCarryItem` responde pelo espaço real na grade e pelo limite de pilha. Pergunte antes de cobrar.
- Itens dentro da mochila não contam para `GetItemCount`, `Search` e afins.
- `slot` é só o identificador do item. A posição fica em `x`, `y`, `rotated` no dado do slot.
- Evento de server `ox_inventory:klsh:itemOverflow (source, dropId, itemName, count)`.

## Voltar atrás

- Tela de slots: `enabled = false` em `data/grid.lua`.
- Sem seção do chão: `groundDistance = false`. Sem tempo de transferência: `transfer = false`.
- Arquivos originais do upstream: pasta de backup do servidor (fora do resource).

## Bolsa de estilo

```lua
-- data/equipment.lua
outfitBag = { item = 'outfit_bag', duration = 8000 },   -- false desliga
```

- O item fica em `data/items.lua` (`outfit_bag`: peso, tamanho na grade, imagem).
- **Usar** (menu, alt+clique, atalho 1 a 5) fecha o inventário e, depois de `duration` ms, troca tudo o que
  o personagem veste pelo que está na bolsa. Colete e mochila não entram.
- **Abrir** (menu de contexto) mostra os 12 slots à direita. Cada slot só aceita a categoria dele, e todas
  as peças têm de ser do mesmo modelo de corpo.
- **Venda:** é um item comum. Para vender, acrescente em uma loja de `data/shops.lua`:
  `{ name = 'outfit_bag', price = 500 }` (hoje na loja `General`, as 24/7).

## Drops no chão

```lua
-- data/grid.lua
drop = { w = 8, h = 5, merge = 1.5 },
```

- `w`, `h`: tamanho da grade de cada drop.
- `merge`: item largado ou arremessado a até esses metros de um drop que já existe **e que tem espaço
  para ele** entra nesse drop, em vez de criar outro ao lado. Sem espaço, cria um drop novo. `false`
  desliga (sempre um drop novo).

## Morte, limpeza e prisão

Não há config no inventário: a regra é fixa (a roupa fica; mochila vestida e colete vão junto). O que cada
script faz é escolha dele:

- **Morte / respawn:** quem chama `ClearInventory` decide (no `qbx_ambulancejob`, `wipeInvOnRespawn`).
- **Prisão:** quem chama `ConfiscateInventory` pode passar `{ discard = { 'armour' } }` para o preso perder
  certos itens de vez. Ver `INTEGRATION.md`.
- **Admin:** `/takeinv <id> [itens a descartar]`, `/returninv <id>`, `/clearinv <id>`.

## Arremesso

```lua
-- data/throw.lua
enabled = true,
key = 'G',              -- tecla padrão para arremessar o que está na mão (false = sem tecla padrão)
maxWeight = 5000,       -- gramas; acima disso não dá para arremessar
cooldown = 1500,        -- ms entre arremessos
chargeTime = 1200,      -- ms segurando o botão para a força máxima
minCharge = 0.25,       -- parte do alcance de um toque rápido
range = { light = 18.0, heavy = 6.0 },  -- metros na força máxima: item leve e item no peso máximo
prop = `prop_paper_bag_small`,          -- objeto para itens sem modelo próprio
```

- **Menu de contexto → Arremessar:** fecha o inventário e põe o item na mão. Segurar o botão esquerdo
  carrega a força, soltar joga; botão direito ou Backspace cancela. O campo de quantidade vale como no "Soltar".
- **Tecla (padrão G):** arremessa a arma que está na mão. Cada jogador pode trocar a tecla nas
  configurações do FiveM (a tecla padrão só vale para quem ainda não tem a tecla registrada).
- O item vira um drop onde cair. Qualquer item dentro do peso pode ser arremessado.

Alvos e veículo (`data/throw.lua`):

```lua
targets = {
    targetRadius = 2.5,   -- metros da lixeira, ou da boca do porta-malas, em que o item tem de cair
    trunkRadius = 7.0,    -- metros do centro do veículo que o servidor aceita
    chance = { base = 0.85, perMeter = 0.04, perKg = 0.06, min = 0.05 },
},                        -- targets = false desliga os alvos
fromVehicle = true,       -- de dentro do veículo, com vidro ou porta abertos ao lado do banco
```

- **Chance de cair dentro** = `base` − `perMeter` × metros arremessados − `perKg` × quilos, nunca abaixo
  de `min`. Exemplo: garrafa de 500 g a 5 m = 62%; rifle de 4 kg a 5 m = 41%.
- **Porta-malas:** precisa estar aberto e destrancado. **Lixeira:** as mesmas que podem ser revistadas.
- Errou ou não coube: o item vira um drop ao lado.
- **De dentro do veículo:** qualquer banco, desde que haja uma abertura ao lado: vidro abaixado ou
  quebrado, porta aberta, porta arrancada ou veículo sem porta (moto, buggy). O item sai por esse lado.
