# BLOCKFRONT — Arquitetura

## 1. Estrutura do projeto (Rojo)

```
src/shared  -> ReplicatedStorage.Shared
  Config/
    GameConfig.luau          equipes, respawn, DevTools, grupos de colisão
    MaterialConfig.luau      materiais destrutíveis (vida, aparência)
    DestructionConfig.luau   todos os limites de performance da destruição
  Modules/
    VoxelGrid.luau           dados das células (buffers), dano esférico, apoio estrutural
    GreedyMesher.luau        funde células iguais em poucas caixas
    Remotes.luau             lista oficial de RemoteEvents (criados pelo servidor)

src/server  -> ServerScriptService.Server
  GameManager.server.luau    ÚNICO Script do servidor; inicializa os managers
  Managers/
    TeamManager.luau         equipes Blue/Red, balanceamento, grupo de colisão dos personagens
    DestructionManager.luau  autoridade da destruição, passo agrupado, envio aos clientes
    MapManager.luau          campo de testes (piso, spawns, paredes voxel)
    DevToolsManager.luau     explosões de teste validadas (somente Studio)
  Destruction/
    VoxelStructure.luau      estrutura destrutível = VoxelGrid + chunks renderizados
    PartPool.luau            reaproveitamento das Parts dos chunks

src/client  -> StarterPlayer.StarterPlayerScripts.Client
  ClientMain.client.luau     ÚNICO LocalScript; inicializa os controllers
  Controllers/
    DestructionEffects.luau  explosões e fragmentos cúbicos (somente visual)
    DevController.luau       teclas G/H de teste (somente Studio)

Workspace (criado em runtime pelo MapManager)
  Map / SpawnPoints / DestructibleObjects / DebrisCache (cliente)
ReplicatedStorage.Remotes (criado em runtime por Remotes.init)
```

Próximos módulos, criados só quando a fase chegar (sem placeholders):
RoundManager + CapturePoints (Fase 1/4, modo Conquista), CombatManager + WeaponController
(Fase 3), UIController + MainHUD/Scoreboard/TeamSelection (Fase 5), CameraController.

## 2. Sistema voxel

**Fonte da verdade no servidor.** Cada construção é um `VoxelGrid`: dois buffers
(`materials` 1 byte/célula, `health` 2 bytes/célula). Uma parede de 24x14x2 ocupa ~2 KB.
Nenhum cliente altera células; ele só pede, e o servidor valida.

**Renderização por chunks com greedy meshing.** A grade é dividida em chunks de 8x8x8.
Cada chunk vira poucas Parts ancoradas: o `GreedyMesher` funde células vizinhas do mesmo
material em um paralelepípedo. Resultado no teste: 2.880 células representadas por 24 Parts.
Quando células são destruídas, só os chunks afetados são remontados, reaproveitando Parts
(`PartPool`).

**Por que as Parts ficam no servidor.** Replicação automática do Roblox: colisão e raycast
corretos no servidor (necessário para validar tiros na Fase 3), e quem entra no meio da
partida recebe o estado destruído sem código extra. Como as Parts são fundidas, o volume
replicado é pequeno.

**Dano e materiais.** Explosão = esfera com dano linear do centro (100%) até a borda
(`FalloffMin`, 35%). Cada célula tem vida do seu material (madeira 30, tijolo 60,
concreto 120, metal 300). Células que não morrem ficam danificadas, então impactos
repetidos acumulam.

**Desmoronamento progressivo.** Após dano, uma busca em largura a partir da camada de base
(y = 0) encontra células sem apoio. Elas entram numa fila e caem de baixo para cima,
60 por passo, gerando fragmentos que desabam.

**Sincronização agrupada.** A cada 50 ms o `DestructionManager` envia UMA mensagem
`DestructionBatch` com todas as explosões e células removidas no período, em buffers
compactos (u32 índice + u8 material). Acima de 300 células por estrutura a lista é
amostrada: o cliente só precisa dela para os fragmentos, a geometria já chega pela
replicação.

**Fragmentos só no cliente.** Pool fixo de 260 Parts criadas uma vez; teto de 220 ativos e 90
por mensagem; nada é criado a mais de 350 studs da câmera; vida de 2 a 3,5 s com fade.
Fragmentos não colidem entre si nem com personagens (grupos de colisão).

## 3. Riscos de performance e mitigação

| Risco | Mitigação atual | Atenção futura |
|---|---|---|
| Milhares de Parts físicas | Chunks fundidos (greedy meshing); fragmentos locais com teto | Medir número de Parts por mapa completo |
| Remontagem cara de chunks | Só chunks sujos, limite de 32 por passo, Parts reaproveitadas | Chunks menores se uma remontagem custar > 1 ms |
| Busca de apoio O(células da estrutura) | Feita no máximo 1x por passo por estrutura atingida | Para prédios grandes: restringir à região atingida ou dividir em estruturas menores |
| Rede: replicação de Parts + mensagens | Mensagem agrupada a cada 50 ms, buffers, amostragem | Monitorar KB/s com 16+ jogadores atirando |
| Explosões enormes / abuso | Limite de células examinadas por explosão; validação de tipo, NaN, distância e cadência | CombatManager deve validar arma, munição e linha de visão |
| Física dos fragmentos | Sem colisão entre fragmentos, vida curta, teto de ativos | Reduzir teto em dispositivos móveis |
| StreamingEnabled | Ligado; geometria destrutível é replicada normalmente | Definir ModelStreamingMode das estruturas no mapa grande |
| Memória | Buffers compactos (3 bytes/célula) | Mapa inteiro com ~200 mil células ≈ 600 KB, aceitável |

## 4. Como testar

1. `rojo build default.project.json -o build/BLOCKFRONT.rbxlx` e abrir no Studio
   (ou `rojo serve` e conectar o plugin do Rojo).
2. Play. Mire numa parede: **G** = explosão grande, **H** = impacto pequeno (perfura).
3. Atire na base da parede de tijolos para ver o resto desmoronar.

Resultados do teste de 14/11/2026: explosões destroem 224 a 232 células por parede,
o desmoronamento derrubou 292 células soltas, pedidos inválidos (NaN, preset inexistente,
tipo errado) foram ignorados, e o servidor ficou a 60 FPS com 0,2 ms de Heartbeat.
