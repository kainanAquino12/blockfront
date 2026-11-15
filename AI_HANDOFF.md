# BLOCKFRONT — Transferência para outra IA

Leia este arquivo inteiro antes de mexer em qualquer coisa. Tudo aqui foi conferido no código em 15/11/2026.
O dono (Lucas) escreve em português do Brasil. Responda em português.

---

## 1. O que é o BLOCKFRONT

Jogo multiplayer de guerra para Roblox: **Time Azul (Blue) contra Time Vermelho (Red)**, em **primeira pessoa**,
no modo **Conquista** (3 pontos de captura). O diferencial é a **destruição voxel**: paredes, prédios, pontes e
coberturas são feitos de células de 1 stud e quebram com tiros, foguetes, granadas e marreta.
Os fragmentos são cúbicos. O que é destruído continua destruído até o fim da partida.

## 2. Direção artística desejada pelo dono

- Low poly / estilizado, **tudo em blocos**, cores vibrantes, azul e vermelho como cores dos times.
- Nada de realismo militar. Deve ser divertido e parecer um produto acabado.
- Referências enviadas pelo dono (imagens, não estão no repositório):
  - uma folha com 9 armas em blocos: cinza-grafite com detalhes bege, oliva, amarelo e laranja;
  - uma cidade voxel ao pôr do sol, com prédios de tijolo, telhados verdes, rio, carros e explosões cúbicas.
- Os modelos das armas seguem a primeira imagem (`src/shared/Modules/WeaponModels.luau`).

## 3. Arquitetura atual

Rojo + Git em `C:\Users\kaina\Documents\BLOCKFRONT`. Detalhes em `ARCHITECTURE.md` e `docs/ARCHITECTURE.md`.
Resumo:

- Um Script no servidor (`GameManager.server.luau`) e um LocalScript no cliente (`ClientMain.client.luau`).
  O resto são módulos com `init()`. **Não crie outros Scripts ou LocalScripts.**
- **O servidor é a autoridade** sobre dano, munição, células voxel, times, pontuação e renascimento.
  O cliente só pede e prevê para responder rápido.
- Toda a configuração fica em `src/shared/Config/`. Os números de balanceamento estão lá, não no código.
- O mapa e as estruturas são **gerados por código** quando o servidor inicia (`MapManager`).
  No modo Edit o Workspace aparece vazio, a menos que a prévia tenha sido gerada (veja a seção 13).

## 4. Sistemas implementados e scripts responsáveis

| Funcionalidade | Arquivo(s) |
|---|---|
| Inicialização do servidor e grupos de colisão | `src/server/GameManager.server.luau` |
| Times, menu (servidor), balanceamento (no máx. 1 jogador a mais), renascimento (4 s), colete, leaderstats | `src/server/Managers/TeamManager.luau` |
| Ciclo da partida, pontuação, reconstrução do mapa entre partidas | `src/server/Managers/RoundManager.luau` |
| Pontos de captura A, B e C (mastro, letra, disco) | `src/server/Managers/CaptureManager.luau`, `MatchConfig.CapturePoints` |
| Combate: validação, raycast, chumbos, dano, abate, explosão | `src/server/Managers/CombatManager.luau` |
| Foguete (raycast por frame) e granada (física) | `src/server/Combat/Projectiles.luau` |
| Entrega das armas (slots 1 a 5) e escolha da principal | `src/server/Managers/LoadoutManager.luau` |
| Destruição voxel | `src/shared/Modules/VoxelGrid.luau`, `GreedyMesher.luau`, `src/server/Destruction/VoxelStructure.luau`, `PartPool.luau`, `src/server/Managers/DestructionManager.luau` |
| Mapa | `src/server/Managers/MapManager.luau`, `src/server/Map/MapLayout.luau`, `StructureKit.luau`, `PropKit.luau` |
| Teclas G/H, bonecos de treino, DevLookAt (só no Studio) | `DevToolsManager.luau`, `src/client/Controllers/DevController.luau` |
| Câmera FPS | `src/client/Controllers/CameraController.luau` |
| Corrida e velocidade | `MovementController.luau` |
| Arma em 1ª pessoa, ADS, animações | `ViewmodelController.luau` |
| Entrada das armas, disparo, recarga, troca, dispersão | `WeaponController.luau` |
| Traçantes, impactos, foguetes visuais, sons de combate | `CombatEffects.luau` |
| Áudio 3D, limites, grupo Distant | `AudioController.luau`, `src/shared/Config/AudioConfig.luau` |
| Fragmentos e efeito de explosão | `DestructionEffects.luau` |
| HUD, retículo, luneta, dano recebido, placar no Tab, feed | `UIController.luau` |
| Menu de times, arma principal, sensibilidade (tecla M) | `TeamSelectController.luau`, `SettingsController.luau` |
| Armas: estatísticas, poses, sons | `src/shared/Config/WeaponConfig.luau` |
| Modelos das armas | `src/shared/Modules/WeaponModels.luau` |
| Matemática compartilhada (dispersão, chumbos, material) | `src/shared/Modules/WeaponMath.luau` |

## 5. Câmera, armas, ADS e retículo

- **Câmera (`CameraController`)**
  - `CameraType = Scriptable`, controlada no RenderStep com prioridade Camera.
  - Yaw e pitch vêm de `GetMouseDelta`, multiplicados pela sensibilidade (atributo `Sensitivity`, 0,2 a 3,0) e pela sensibilidade de mira da arma.
  - O olho fica em HumanoidRootPart + (0; 1,55; 0), com suavização vertical.
  - Balanço ao andar, mergulho ao aterrissar e inclinação lateral.
  - **Recuo real:** `addRecoil` sobe o pitch e ele volta sozinho conforme o `Recovery` da arma, depois de 0,08 s sem atirar.
  - FOV: 80; +6 correndo; `AimFov` da arma no ADS.
  - O personagem gira com o yaw e fica invisível localmente (`LocalTransparencyModifier`).
  - `setEnabled(false)` quando o menu está aberto. `lookAt(pos)` aponta a câmera.
- **Por que câmera própria:** a câmera padrão do Roblox em primeira pessoa usava o botão direito para girar e
  atrapalhava o ADS. **Não volte para `LockFirstPerson`.**
- **ADS (`ViewmodelController`)**
  - Cada modelo tem um Attachment `Sight`.
  - Ao equipar, calcula-se `aimPose = CFrame.new(-s.X, -s.Y, -AimDistance - s.Z)`, com `s` = posição do Sight no espaço do Handle já escalado.
  - Assim a linha de visada fica **exatamente** no centro da tela (medido: x = 0, y = 0).
  - A pose Hip vem de `WeaponConfig.*.Viewmodel.Hip`.
  - Com a sniper (`Scope = true`) e o aimAlpha acima de 0,9, o modelo some e o HUD desenha a luneta.
- **Disparo (`WeaponController.fire`)**
  1. Origem = posição da câmera; direção = LookVector + dispersão.
     Dispersão = Hip→Aim pelo aimAlpha + Move × fator de movimento + Bloom.
  2. A escopeta gera uma semente; `WeaponMath.pelletDirections` produz as mesmas direções no cliente e no servidor.
  3. O cliente faz raycast, desenha traçante e impacto, e envia `WeaponFire(id, origin, dir, claimed, seed)`.
  4. O servidor (`CombatManager.onFire`) valida:
     - tipos e valores finitos;
     - origem a até 10 studs da cabeça;
     - Tool equipada com o WeaponId correto;
     - cadência (FireInterval × 0,8);
     - munição.
     Depois refaz o raycast. Há um "favor do atirador" limitado: o alvo sugerido vale se estiver a até 4 studs da linha do tiro e sem obstáculo.
  - O cliente nunca define dano nem ponto final de impacto.
- **Retículo (`UIController.updateCombatUI`)**
  - Fica na ScreenGui "CombatOverlay" com DisplayOrder 50.
  - Distância das barras = tan(dispersão) / tan(FOV/2) × meia altura da tela + 4 px.
  - Ao mirar, as barras somem e o ponto central fica vermelho. Some com o menu aberto e com a luneta.
  - Também há barra de recarga, marcador de acerto e setas de dano.
- **Teclas:** botão esquerdo atira; direito mira; R recarrega; 1-5 ou roda trocam de arma; Shift corre; M abre o menu; Tab mostra o placar.
  O hotbar padrão do Roblox está desligado.

## 6. Destruição voxel

- **Dados:** cada estrutura é um `VoxelGrid` com buffers: material (u8, 0 = vazio) e vida (u16).
  O índice é `x + sx*(y + sy*z)`. Os materiais estão em `MaterialConfig`: 18 tipos com vida, por exemplo vidro 5,
  madeira 30, tijolo 60, concreto 120 e metal 300.
- **Visual:** chunks de 16³. `GreedyMesher` funde células iguais em caixas. Cada caixa vira uma Part ancorada **no servidor**,
  replicada pelo Roblox; isso dá colisão e raycast corretos no servidor e deixa quem entra no meio da partida com o estado atual.
  As Parts são reaproveitadas pelo `PartPool`.
- **Explosão:** `DestructionManager.explode(pos, raio, dano, kind)`. O dano cai linearmente até 35% na borda e vira
  dano nas células dentro da esfera. Os chunks atingidos são marcados como sujos.
- **Passo (a cada 50 ms):**
  1. `findUnsupported` faz uma BFS a partir da camada y = 0; o que não se liga a ela entra na fila de desabamento.
  2. São removidas até 60 células por passo, de baixo para cima.
  3. São remontados até 10 chunks por passo.
  4. Uma mensagem `DestructionBatch` vai para todos (buffers, amostragem de 300 células por estrutura).
- **Cliente:** `DestructionEffects` cria fragmentos do pool (260 Parts, até 220 ativos, a até 350 studs, vida de 2 a 3,5 s).
  Os fragmentos não colidem entre si nem com personagens.
- **Mapa espelhado:** o MapLayout descreve só o lado azul. O MapManager reflete no plano z = 0: o canto da estrutura é
  refletido e o preenchimento é invertido em z. Para o cenário, `mirrorPropCF` preserva a "frente".

## 7. Multiplayer

- O servidor é autoritativo, como descrito acima. A geometria destruída chega aos clientes pela replicação normal das Parts.
  Os efeitos chegam por remotes agrupados.
- Os tiros dos outros chegam por `CombatEvent Shot`; o cliente que atirou ignora o próprio evento.
- StreamingEnabled está ligado. Sem personagem, o cliente pede streaming de uma área (`RequestStreamAroundAsync`) para a vista do menu.
- Sem fogo amigo. O dano da própria explosão é multiplicado por 0,5.
- **Nunca foi testado com 2 ou mais jogadores reais.** Veja `NEXT_STEPS.md`, item 1.

## 8. Alterações recentes (último commit 7118975 e depois)

- Câmera própria, ADS pela linha de visada, retículo dinâmico, luneta.
- 5 armas novas (SMG, LMG, Sniper, Shotgun, Pistol) com modelos, configuração, animações (carregador, telha, ferrolho) e recuo.
- 29 IDs de som, AudioController 3D, impactos por material, explosão perto e longe.
- Bonecos de treino e `DevLookAt` para testes no Studio.
- Mapa Front Bloco (commit anterior).
- **Depois do commit:** o place `build/BLOCKFRONT.rbxlx` foi salvo com a prévia do mapa (está fora do Git, em `/build/`).
  Foi instalada a skill `roblox-studio` em `~/.claude/skills` (fora do projeto). Ela junta a documentação de 4 pacotes
  públicos de skills Roblox. Os scripts desses pacotes não foram instalados.

## 9. Bugs que ainda existem

Lista completa em `KNOWN_BUGS.md`. Os principais:
- multijogador nunca testado;
- braços do viewmodel simples;
- picos de 25 ms no render após explosões;
- prédios ficam de pé sobre os pilares de canto;
- troca de time sem tempo de espera;
- WalkSpeed definido pelo cliente;
- sons que ninguém ouviu;
- escada das torres nunca testada.

## 10. Tentativas de correção já feitas

Veja o final de `KNOWN_BUGS.md`:
- ADS e câmera padrão: resolvido com a câmera própria;
- poses manuais de ADS: resolvido com o Attachment Sight;
- retículo sumindo: virou ponto;
- colete do time: criado em CharacterAppearanceLoaded;
- placar sem Match: FindFirstChild;
- "ç" no HUD: `upper()` próprio;
- BOM do PowerShell: removido;
- calçadas atravessando os cruzamentos: divididas em segmentos.

Os ajustes visuais das poses foram feitos com prints do Studio.

## 11. Próximas tarefas

Siga `NEXT_STEPS.md` na ordem. A primeira é o teste multijogador.

## 12. Não modifique sem auditoria prévia

Estes arquivos sustentam sistemas que foram testados e que dependem uns dos outros.
Leia, entenda e teste antes e depois de mexer:

- `src/shared/Modules/VoxelGrid.luau`, `GreedyMesher.luau`, `src/server/Destruction/VoxelStructure.luau`,
  `src/server/Managers/DestructionManager.luau`: formato dos buffers, índices, chunks, protocolo do `DestructionBatch`.
  O cliente (`DestructionEffects.emitCells`) decodifica o mesmo formato.
- `src/shared/Modules/WeaponMath.luau`: precisa gerar as mesmas direções no cliente e no servidor.
- `src/server/Managers/CombatManager.luau`: validação anti-trapaça e ordem dos argumentos de `WeaponFire`.
- `src/client/Controllers/CameraController.luau` e `ViewmodelController.luau`: o alinhamento do ADS depende da prioridade
  de RenderStep (câmera = Camera, viewmodel = Camera+1) e do Attachment `Sight` em `WeaponModels`.
- `src/shared/Modules/Remotes.luau`: lista oficial de eventos.
- `src/server/Managers/MapManager.luau`: a reflexão do mapa (`makeContext`, `mirrorPropCF`).
- `default.project.json`: o mapeamento Rojo.
- Fora do projeto: **não apague** `C:\Users\kaina\Documents\_Backups\CostaAlta_backup_*.zip`.
  **Não toque** no jogo "EVOLUÇÃO DE MONSTRUOS".

## 13. Fluxo de trabalho que funciona

1. Edite em `src/`.
2. Rode `rojo build default.project.json -o build/BLOCKFRONT.rbxlx`.
3. Feche só a janela do Studio do BLOCKFRONT e abra o `.rbxlx` de novo.
4. Para o mapa aparecer em Edit, rode no datamodel Edit:
   `local M = require(game.ServerScriptService.Server.Managers.MapManager); M.buildStatic(); M.buildDestructibles()`
   e salve (Ctrl+S, ou `save_place` no MCP).
5. Testes via Studio MCP:
   - `start_stop_play`;
   - no cliente: `Remotes.TeamSelect:FireServer("Blue")` (sem isso não há personagem);
   - `LoadoutSelect:FireServer("Sniper")` e depois matar o personagem para trocar de arma;
   - apontar a câmera com `player:SetAttribute("DevLookAt", pos)`;
   - cliques reais com `user_mouse_input`; teclas com `user_keyboard_input`.
   - O `require` no command bar cria outra cópia do módulo, então teste pelos RemoteEvents e pelas Instances, não pelo módulo.
   - Para prints com a câmera livre: um BindToRenderStep temporário com CameraType Scriptable.
6. **Cuidados:**
   - o FPS no Studio fora de foco cai para cerca de 15;
   - o PowerShell 5.1 grava BOM em `Set-Content -Encoding utf8`;
   - o dono às vezes joga a sessão de teste ao mesmo tempo: não controle o personagem dele sem avisar.
7. Commits em português, terminando com a linha de coautoria.

---

## Mensagem de transferência

> Você está assumindo o BLOCKFRONT, um FPS Roblox de Azul contra Vermelho com destruição voxel, já funcional em 1 jogador:
> mapa grande com 3 pontos, 9 armas, câmera FPS própria com ADS alinhado, destruição autoritativa e HUD completo.
> **Não reconstrua nada.** Antes de qualquer mudança: (1) leia este arquivo, `SYSTEMS_STATUS.md` e `KNOWN_BUGS.md`;
> (2) gere o place com Rojo e faça um Play no Studio para confirmar que o Output está limpo;
> (3) faça o teste multijogador (Test > Clients and Servers) e corrija o que aparecer.
> Mude números de jogo nos arquivos de `src/shared/Config/`, não no código.
> Os arquivos da seção 12 só devem ser alterados depois de entender o formato dos dados e testar.
> Trabalhe em passos pequenos, teste cada sistema, faça commit a cada etapa estável,
> e diga ao dono só o que você realmente testou.


## Atualização V3 (2026-11-15)

- ADS tem **uma** fonte de verdade: `src/client/Controllers/AimController.luau`. Não volte a guardar estado de mira em outros scripts.
- Prédios novos devem usar `B{...}` em `MapLayout` (que chama `StructureKit.facadeBuilding`), não `StructureKit.building` direto.
- FOV do jogador: atributo `FieldOfView` (padrão 80) via `SettingsController`.
- Ver `DEVELOPMENT_LOG.md` (entrada V3) para a lista de arquivos e `KNOWN_BUGS.md` para o que falta testar.
