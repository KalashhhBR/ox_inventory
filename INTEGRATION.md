# ox_inventory (fork klsh): integração com outros resources

O que muda para quem chama `exports.ox_inventory` ou escuta os hooks. O que não está aqui funciona
como no ox_inventory original. Configuração: ver `CONFIG.md`.

## Regras que mudaram

| Assunto | Comportamento no fork |
|---|---|
| `AddItem` em jogador | Reparte por `maxStack` (pode criar várias pilhas) e é tudo ou nada **dentro do inventário**. Chamado por outro resource, o que não couber vai para um drop no chão ao lado do jogador (público, 15 min) e a chamada retorna `true`. Terceiro retorno: `{ dropId, count }` quando algo caiu |
| `AddItem` de dinheiro e documentos | Nunca caem: dinheiro vai para a carteira (sempre cabe); itens de `neverDrop` falham com `false, 'inventory_full'` |
| `AddItem` em baú, porta-malas, drop | Tudo ou nada; sem espaço retorna `false, 'inventory_full'` |
| `AddItem` com `slot` | O slot pedido é ignorado em inventário com grade: o server escolhe o lugar |
| `CanCarryItem` | Considera peso, espaço real na grade e limite de pilha. **Pergunte antes de cobrar ou consumir** |
| `GetEmptySlot`, `GetSlotForItem` | Retornam um identificador livre só se houver espaço na grade |
| `GetItemCount`, `Search`, `GetItem` | Só enxergam o inventário principal. Itens na mochila vestida e roupas vestidas **não contam** |
| `ClearInventory` | Leva também mochila (com conteúdo) e colete; a roupa fica |
| `ConfiscateInventory` / `ReturnInventory` | Guardam e devolvem os itens nas mesmas posições da grade |
| Mover item pela tela | Entre inventários diferentes pode levar até 3 s (tempo por peso). `AddItem`/`RemoveItem` por export continuam instantâneos |
| "Dar" item a outro jogador | Leva no mínimo 1 s, com animação nos dois; recusa se o outro não tiver espaço |
| Item `armour` | É o colete (slot de equipamento), não é mais consumível. A armadura fica em `metadata.armour` |
| Convar `inventory:slots` | Não vale mais: o tamanho vem de `data/grid.lua` |
| Roupa pelo illenium-appearance | O fork também escuta `illenium-appearance:server:saveAppearance`: peça que mudou é cobrada em loja de roupa e vira item; fora de loja a mudança é desfeita (admin com `/pedmenu` é exceção). Outfits e uniformes não vestem mais ninguém |

## Dados do slot

```lua
{ name, label, count, weight, slot, metadata, stack, close,
  x = 3, y = 1, rotated = true }   -- posição na grade (canto superior esquerdo, a partir de 1)
```

- `slot` é só o **identificador** do item dentro do inventário. Não diz onde ele está na tela e não
  muda quando o item é movido ou girado no mesmo inventário.
- Itens da carteira (dinheiro no jogador) não têm `x`/`y`.
- `SetSlot` em inventário com grade dá uma posição livre ao item novo.

## Tipos de inventário e ids novos

| Tipo | Id | O que é |
|---|---|---|
| `equipment` | `equip:<owner>` | roupas, colete e mochila vestidos (14 slots, um por categoria, sem grade) |
| `backpack` (só no `swapItems`) | id do container da mochila | mochila vestida |
| `ground` (só no `swapItems`) | id do drop | seção "Chão" com outro inventário aberto |

## Hooks

- `swapItems`: `fromType`/`toType` podem ser `equipment`; `toSlot` é um identificador (ou o número do
  slot, quando o destino está vazio); o payload do client também leva `toX`, `toY`, `rotated`. Mover ou
  girar dentro do mesmo inventário **não dispara** o hook. `action` continua `move`, `stack`, `swap`,
  `give`.
- `openInventory` não dispara para os inventários vinculados (equipamento, mochila vestida, chão).
- `createItem`, `buyItem`, `craftItem`: como no original.

## Exports e eventos novos

| Nome | Lado | Uso |
|---|---|---|
| `exports.ox_inventory:SearchPlayer(source, target, options?)` | server | **revista**: abre na tela de `source` o inventário, a carteira, as roupas e a mochila de `target`. Ver abaixo |
| `ox_inventory:klsh:playerSearched (source, target)` | evento de server | uma revista começou |
| `exports.ox_inventory:GetEquipment(inv)` | server | tabela dos itens vestidos |
| `RegisterStash(name, label, slots, ...)` | server | `slots` aceita `{ largura, altura }` |
| `ox_inventory:klsh:itemOverflow (source, dropId, itemName, count)` | evento de server | algo entregue ao jogador caiu no chão |
| Campos de item `size = { l, a }` e `maxStack` | `data/items.lua`, `data/weapons.lua` | tamanho na grade e limite de pilha |

## Revista

```lua
-- server
local ok, reason = exports.ox_inventory:SearchPlayer(source, target, {
    notify = true,     -- opcional; false = o alvo não é avisado (ex.: furto)
    distance = 2.0,    -- opcional; metros
})
```

- O inventário confere só a distância, a instância e se quem revista está com o inventário fechado.
  **Quem decide se a revista é permitida é o seu script** (algemado, rendido, morto, emprego).
- Quem revista pode tirar tudo: itens, dinheiro da carteira, roupas, colete e a mochila inteira, e
  também colocar. Tirar roupa e colete leva o tempo da categoria; o resto, o tempo por peso.
- Com `notify` ligado (padrão em `data/equipment.lua` → `search.notify`) o alvo recebe um aviso e o
  inventário dele fecha.
- Retorno `false` com `reason`: `invalid_target`, `inventory_open`, `too_far`.
- A revista fecha sozinha se os dois se afastarem além da distância.
- Tipos novos no `swapItems`: `otherequipment` e `otherbackpack` (roupas e mochila do alvo).
- Comando de admin para teste: `/searchplayer <id>`.

## Cuidados para quem escreve resources

- Entregar item: `if CanCarryItem(...) then cobrar; AddItem(...) end`. Não assuma que slot livre = cabe.
- Contar item do jogador: lembre que a mochila não entra na conta.
- Prisão: use `ConfiscateInventory` na entrada e `ReturnInventory` na saída.
- Não guarde número de slot entre chamadas esperando que seja uma posição.

## Bolsa de estilo (0.18.0)

- Item `outfit_bag`: container cujo id começa com `outfit-`; o conteúdo (até 12 roupas, slot = categoria)
  não conta para `exports.ox_inventory` do jogador, como em qualquer container.
- Evento de server `ox_inventory:klsh:outfitSwapped (source, slot)`: disparado depois que o jogador troca
  de roupa pela bolsa.
- Callback usado pelo client: `ox_inventory:klsh:useOutfitBag (slot)`.

## Morte, limpeza e confisco (0.19.0)

A roupa sempre fica no corpo. Mochila vestida e colete acompanham o resto do inventário:

| Chamada | Mochila vestida (e o conteúdo) | Colete |
|---|---|---|
| `ClearInventory(source)` | destruídos | destruído |
| `ClearInventory(source, keep)` | ficam se o nome do item estiver em `keep` | fica se estiver em `keep` |
| `ConfiscateInventory(source, options?)` | guardados | guardado |
| `ReturnInventory(source)` | voltam para o slot (ou para o inventário, se o slot estiver ocupado) | idem |
| `CreateDropFromPlayer(source)` | vão para um drop próprio ao lado | idem |

`ConfiscateInventory(source, options?)`:

```lua
-- everything is kept for the return, except the vest and the weapons listed
local success = exports.ox_inventory:ConfiscateInventory(source, {
    discard = { 'armour', 'WEAPON_PISTOL' },
})
```

- `options.discard` (opcional): nomes de itens **destruídos na hora do confisco** em vez de guardados. Vale para o inventário principal, o colete, a mochila vestida e o conteúdo de qualquer mochila ou bolsa confiscada. Sem `options`, tudo é guardado.
- Retorno: `true` quando confiscou; `false` quando já existe um confisco deste personagem esperando devolução (nada é alterado, para não sobrescrever o que está guardado). O original não tinha retorno e sobrescrevia.
- `ReturnInventory(source)` substitui o inventário atual pelo que foi guardado, como no original. O que o jogador tiver no momento da devolução é perdido; quem chama deve ler antes com `GetInventoryItems` o que quiser preservar.
- Registros no banco: `(owner, owner)` para o inventário (como no original) e `(owner, 'equip-confiscated')` para mochila e colete.

Scripts de prisão que copiam a lista de itens e chamam `ClearInventory` **perdem a mochila e o colete do preso** (eles não estão em `GetInventoryItems`). Use `ConfiscateInventory` e `ReturnInventory`.

## Arremesso (0.20.0)

- O item arremessado sai do inventário pelo mesmo caminho do "Soltar": o hook `swapItems` recebe
  `toInventory = 'newdrop'`, `toType = 'drop'`, `action = 'move'`, `dropId`, e o campo extra
  `klshThrow = true`. Retornar `false` cancela o arremesso.
- Callbacks usados pelo client: `ox_inventory:klsh:throwStart (slot, count)` e
  `ox_inventory:klsh:throwLand (coords)`. O ponto de queda vem do client e é limitado no server pelo
  alcance do peso arremessado e pela diferença de altura.

Alvos (0.21.0):

- Item que cai dentro de uma lixeira ou de um porta-malas aberto dispara o hook `swapItems` com
  `toInventory` = id do alvo (`dumpster<netid>` ou `trunk<placa>`), `toType` = `dumpster` ou `trunk`,
  `action = 'move'` e `klshThrow = true`.
- `exports.ox_inventory:SetThrowBonus(source, value)` (server): soma `value` (ex.: `0.10`) à chance de
  cair dentro para aquele jogador, até ele sair ou até nova chamada (`nil` ou `0` limpa). Ponto de
  entrada para sistemas de perícia.
- `ox_inventory:klsh:throwLand (coords, target?)` passou a receber o alvo que o client encontrou
  (`{ type, netid }`); o servidor confere entidade, modelo, distância, trava e instância.
