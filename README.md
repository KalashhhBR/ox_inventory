<div align="center">

# ox_inventory · fork klsh

Inventário em grade, roupas como itens e mochilas de verdade para servidores **Qbox**.

Fork do [ox_inventory](https://github.com/overextended/ox_inventory) da Overextended. Mantém o nome do resource e os `exports` do original, para os outros scripts continuarem funcionando.

[Changelog](./CHANGELOG.md) · [Configuração](./CONFIG.md) · [Integração](./INTEGRATION.md) · [Licença](./LICENSE) · [Avisos legais](./NOTICE.md)

</div>

> **Estado:** em desenvolvimento. Use em produção por sua conta e sempre com backup do banco.
> **Base:** `overextended/ox_inventory` no commit `ca61e6d` (2.48.1+). A versão do fork fica em `klsh_version` no `fxmanifest.lua`.

## Sumário

- [O que muda em relação ao original](#o-que-muda-em-relação-ao-original)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Migrando de um ox_inventory já em uso](#migrando-de-um-ox_inventory-já-em-uso)
- [Configuração rápida](#configuração-rápida)
- [Para quem desenvolve outros scripts](#para-quem-desenvolve-outros-scripts)
- [Comandos](#comandos)
- [Versões e changelog](#versões-e-changelog)
- [Limitações conhecidas](#limitações-conhecidas)
- [Contribuindo e relatando bugs](#contribuindo-e-relatando-bugs)
- [Créditos e licença](#créditos-e-licença)

## O que muda em relação ao original

| Área | O que o fork faz |
|---|---|
| **Interface** | Tela em três zonas (o que você carrega, o personagem, o inventário aberto e o chão), com busca por inventário, peso em cada item, campo de quantidade, menu de contexto e avisos por cima da tela. |
| **Atalhos de arrastar** | Arrastar para fora larga no chão; arrastar para o personagem veste ou usa. |
| **Grade** | Cada item ocupa largura × altura e pode ser girado (tecla **R**). Limite de pilha por item. Vale para jogador, mochila, baús, porta-malas, porta-luvas, chão e revista. |
| **Carteira** | Dinheiro e dinheiro sujo ficam em dois slots próprios, fora da grade: sempre cabem. Podem ser arrastados, dados e arremessados. |
| **Roupas como itens** | 14 slots de equipamento. Vestir e tirar leva tempo, tem animação e é bloqueado em veículo e em combate. Roupa só serve no mesmo modelo de corpo. |
| **Mochilas** | Vestida, a mochila vira uma seção do inventário com capacidade própria e redução de peso configurável. |
| **Colete** | O item guarda a armadura restante: vestir aplica, tiro desgasta, tirar salva. |
| **Transferência** | Mover itens entre inventários leva tempo conforme o peso, com fila de ações. |
| **Chão** | O drop mais próximo aparece junto com o inventário secundário; com mais de um ao alcance, setas trocam o drop mostrado. |
| **Atalhos** | Cinco atalhos (teclas 1 a 5) que apontam para itens da grade. |
| **Revista** | Endpoint `SearchPlayer` para scripts de polícia, assalto e furto; quem revista vê e leva tudo. |
| **Loja de roupa** | O visual é escolhido no illenium-appearance; cada peça trocada é cobrada e vira item. |
| **Renomear** | Qualquer item pode ganhar um nome; o original continua visível no tooltip. |
| **Bolsa de estilo** | Guarda um visual inteiro e troca tudo de uma vez. |
| **Arremesso** | Qualquer item pode ser jogado, pelo menu ou por tecla para a arma na mão. Lixeira e porta-malas aberto têm chance de receber o item. |
| **Morte, limpeza e confisco** | A roupa fica; mochila vestida e colete acompanham o inventário. O confisco aceita uma lista de itens que o jogador perde de vez. |
| **Drops agrupados** | Item largado junto de um drop com espaço entra nele, em vez de espalhar drops pequenos. |

A lista completa, versão por versão, está no [CHANGELOG.md](./CHANGELOG.md). Toda mudança no código do original está marcada com `-- klsh:`.

## Requisitos

- Servidor FiveM com OneSync, artefato 6116 ou mais novo.
- [oxmysql](https://github.com/overextended/oxmysql) e [ox_lib](https://github.com/overextended/ox_lib).
- [qbx_core](https://github.com/Qbox-project/qbx_core) (desenvolvido e testado na 1.24).
- [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) (opcional; testado na 5.7). Sem ele, os itens e slots de roupa funcionam, mas o visual do personagem não muda.
- [Bun](https://bun.sh) para compilar a interface.

## Instalação

1. Faça backup da tabela `ox_inventory` e da coluna `inventory` da tabela `players`.
2. Copie esta pasta para `resources/[ox]/ox_inventory`, no lugar do original.
3. Compile a interface. O repositório não traz o build:
   ```
   cd web
   bun install
   bun run build
   ```
   O resultado fica em `web/build/` (`index.html`, `index.js`, `index.css`).
4. Ajuste os arquivos de `data/` para o seu servidor. Os que vêm aqui são exemplos: a lista de itens é a do original mais os itens do fork.
5. No illenium-appearance, ponha `Config.ClothingCost = 0`: quem cobra a roupa passa a ser o inventário.
6. Reinicie o servidor.

## Migrando de um ox_inventory já em uso

- **Inventários:** na primeira carga, cada inventário é convertido para a grade. Nada é apagado. O que não couber fica em linhas extras, que só podem ser esvaziadas e somem quando ficam vazias.
- **Dinheiro:** pilhas espalhadas de dinheiro do jogador são somadas na carteira.
- **Roupas:** o que cada personagem veste vira item equipado na primeira vez que ele abre o inventário.
- **Seus itens:** acrescente ao seu `data/items.lua` os itens do fork (`clothing_*`, `backpack_*`, `outfit_bag`) e, se quiser, `size` e `maxStack` nos demais. Item sem `size` ocupa 1 × 1.
- **Voltar atrás:** restaure os arquivos do original e o backup do banco.

## Configuração rápida

Toda a configuração de uma coisa fica junto dessa coisa. O passo a passo está no [CONFIG.md](./CONFIG.md).

| Quero mudar | Onde |
|---|---|
| Tamanho e limite de pilha de um item | `size` e `maxStack` no próprio item, em `data/items.lua` ou `data/weapons.lua` |
| Tamanho do inventário do jogador e do chão, padrões da grade | `data/grid.lua` |
| Mochilas (grade, peso, redução, visual) | `backpacks` em `data/equipment.lua` |
| Porta-malas e porta-luvas por classe ou modelo | `data/vehicles.lua` |
| Baús | `data/stashes.lua` (`slots = { largura, altura }`) |
| Tempo e preço de cada categoria de roupa | `categories` em `data/equipment.lua` |
| Tempo de transferência por peso | `transfer` em `data/equipment.lua` |
| Revista, renomear, loja de roupa, guarda-roupas, bolsa de estilo | `data/equipment.lua` |
| Arremesso (tecla, peso, alcance, alvos, de dentro do veículo) | `data/throw.lua` |
| Agrupar drops próximos | `drop.merge` em `data/grid.lua` |
| Textos, abas, cores e larguras da tela | seção "Interface" do [CONFIG.md](./CONFIG.md) |

## Para quem desenvolve outros scripts

Os `exports` do original continuam existindo. O [INTEGRATION.md](./INTEGRATION.md) lista o que muda de comportamento. O essencial:

- `AddItem` em jogador é **tudo ou nada**. Chamado por outro resource, o que não couber cai no chão por 15 minutos e a chamada retorna `true`.
- `CanCarryItem` considera o espaço na grade e o limite de pilha, além do peso.
- Itens dentro de mochilas e bolsas **não contam** para `GetItemCount`, `Search` e `RemoveItem` do jogador.
- Mover item pela interface pode levar até 3 segundos; `AddItem` e `RemoveItem` por export continuam instantâneos.
- Revista: `exports.ox_inventory:SearchPlayer(source, target, { notify = true, distance = 2.0 })`. O inventário confere só distância e instância; quem decide se pode revistar é o seu script.
- Prisão: use `ConfiscateInventory(source, { discard = { 'armour' } })` e `ReturnInventory(source)`. Quem copia a lista de itens e chama `ClearInventory` faz o preso perder mochila e colete.
- `ClearInventory` em jogador leva também a mochila vestida e o colete; a roupa fica.
- Arremesso: `exports.ox_inventory:SetThrowBonus(source, valor)` soma chance de acertar lixeira ou porta-malas.

## Comandos

| Comando | Quem | O que faz |
|---|---|---|
| `/searchplayer <id>` | admin | abre a revista de um jogador (para teste) |
| `/klsh_inventory_remigrate <id>` | admin | refaz a conversão das roupas vestidas em itens |
| `/takeinv <id> [itens]` | admin | confisca o inventário; os itens listados são destruídos em vez de guardados |
| tecla `G` (configurável) | jogador | arremessa a arma que está na mão |

Os comandos do original (`/giveitem`, `/clearinv`, `/takeinv`, `/returninv` e os demais) continuam valendo.

## Versões e changelog

- `version` no `fxmanifest.lua` é a versão do original usada como base.
- `klsh_version` é a versão do fork, em [SemVer](https://semver.org/lang/pt-BR/).
- Cada versão publicada tem uma entrada no [CHANGELOG.md](./CHANGELOG.md) com quatro seções: **Adicionado**, **Removido**, **Ajuste** e **Bugs consertados**.

## Limitações conhecidas

- Testado só em Qbox. Os bridges dos outros frameworks continuam no código, mas não foram testados com o fork.
- Outfits salvos e uniformes de emprego do illenium-appearance são desfeitos fora de loja: roupa só nasce de loja, criação de personagem e menu de admin.
- No arremesso, só quem joga vê o objeto no ar; os outros veem a animação e o item aparecer onde caiu.
- O ponto de queda do arremesso, o porta-malas aberto e o vidro aberto são informados pelo client; o servidor limita por distância, altura, trava e intervalo.
- Lixeiras do mapa que não existem em rede não recebem arremesso (nem abrem para revista) com `inventory:networkdumpsters` desligado.
- As abas Saúde, Crafting e Habilidades são reservadas: aparecem apagadas e ainda não fazem nada.
- O menu de contexto dos itens só abre nos bolsos e na carteira.
- A interface carrega as fontes do Google Fonts; sem acesso à internet no cliente, usa a fonte padrão do sistema.
- Teclas de outros resources (agachar, por exemplo) continuam valendo com o inventário aberto, a não ser que o resource confira `LocalPlayer.state.invOpen`.
- Atualizar a partir do original exige reaplicar à mão as partes que o fork reescreve (`swapItems`, `AddItem` e a interface).

## Contribuindo e relatando bugs

Bugs e sugestões do fork vão nas issues **deste** repositório; veja o [CONTRIBUTING.md](./CONTRIBUTING.md). Não abra issue no repositório da Overextended por causa de algo que só acontece aqui.

## Créditos e licença

Este projeto é uma obra derivada do **ox_inventory**, de [Linden](https://github.com/thelindat), [Luke](https://github.com/LukeWasTakenn), [Dunak](https://github.com/dunak-debug) e contribuidores da [Overextended](https://github.com/overextended). O código original está em https://github.com/overextended/ox_inventory. Se o inventário é útil para você, considere [apoiar os autores originais](https://ko-fi.com/thelindat).

Distribuído sob a [GPL-3.0](./LICENSE) ou posterior, como o original. Na prática:

- Você pode usar, modificar e redistribuir, inclusive comercialmente.
- Quem receber o resource tem de receber também o código-fonte completo e os mesmos direitos.
- Versões modificadas continuam sob a GPL-3.0 e têm de manter os créditos e os avisos de licença.
- Não é permitido distribuir com criptografia ou ofuscação que impeça o uso desses direitos.

Os avisos de direitos autorais do original e do fork estão no [NOTICE.md](./NOTICE.md).
