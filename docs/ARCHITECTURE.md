# BLOCKFRONT — Arquitetura

## 1. Estrutura do projeto (Rojo)

```
src/shared  -> ReplicatedStorage.Shared
  Config/
    GameConfig.luau          equipes, respawn, DevTools, grupos de colisão
    MatchConfig.luau         regras do modo Conquista (tempo, meta, área de captura)
    WeaponConfig.luau        estatísticas, sons e validação das armas
    MaterialConfig.luau      materiais destrutíveis (vida, aparência)
    DestructionConfig.luau   todos os limites de performance da destruição
  Modules/
    VoxelGrid.luau           dados das células (buffers), dano esférico, apoio estrutural
    GreedyMesher.luau        funde células iguais em poucas caixas
    Remotes.luau             lista oficial de RemoteEvents (criados pelo servidor)
    WeaponModels.luau        modelos das armas em blocos (sem assets externos)

src/server  -> ServerScriptService.Server
  GameManager.server.luau    ÚNICO Script do servidor; inicializa os managers
  Managers/
    TeamManager.luau         equipes, balanceamento, colete do time, Abates/Mortes
    RoundManager.luau        ciclo da partida (Waiting/Starting/InProgress/Ended), pontuação
    CaptureManager.luau      área de captura do modo Conquista
    CombatManager.luau       validação de disparos, dano, munição, recarga, abates
    LoadoutManager.luau      entrega das 4 armas a cada spawn
    DestructionManager.luau  autoridade da destruição, passo agrupado, envio aos clientes
    MapManager.luau          campo de testes (piso, spawns, paredes voxel)
    DevToolsManager.luau     explosões de teste validadas (somente Studio)
  Destruction/
    VoxelStructure.luau      estrutura destrutível = VoxelGrid + chunks renderizados
    PartPool.luau            reaproveitamento das Parts dos chunks
  Map/
    MapLayout.luau           layout do mapa "Vila Bloco" (lado azul; vermelho é espelhado)
    StructureKit.luau        prédios, muros, barreiras, sacos de areia, caixotes em voxel
    PropKit.luau             cenário estático: ruas, árvores, pedras, postes, bases, limites
  Combat/
    Projectiles.luau         foguetes (simulados por raycast) e granadas (física)

src/client  -> StarterPlayer.StarterPlayerScripts.Client
  ClientMain.client.luau     ÚNICO LocalScript; inicializa os controllers
  Controllers/
    DestructionEffects.luau  explosões e fragmentos cúbicos (somente visual)
    CameraController.luau    primeira pessoa travada, mira no centro da tela
    ViewmodelController.luau arma e braços em primeira pessoa (recuo, mira, recarga, golpe, arremesso)
    WeaponController.luau    entrada das armas, munição prevista, envio ao servidor
    CombatEffects.luau       traçantes, foguetes visuais, sons, golpe da marreta
    UIController.luau        HUD (placar, tempo, objetivo, vida, munição, feed, avisos)
    DevController.luau       teclas G/H de teste (somente Studio)

Workspace (criado em runtime pelo MapManager)
  Map / SpawnPoints / DestructibleObjects / DebrisCache (cliente)
ReplicatedStorage.Remotes (criado em runtime por Remotes.init)
```

Interface: TeamSelectController (menu de times ao entrar e na tecla M; o servidor recusa
desequilíbrio maior que 1 jogador) e placar próprio no Tab (UIController). O jogador só nasce
depois de escolher o time; nascimento e renascimento são feitos pelo TeamManager.

## Combate

O cliente envia só a intenção (`WeaponFire`: arma, origem, direção). O servidor confere fase da
partida, arma equipada, cadência, munição (contada no servidor, publicada em atributos da Tool),
origem perto da cabeça e direção válida, e só então faz o raycast/simulação e aplica dano.
Rifle aceita "favor do atirador" limitado: se o servidor não viu o alvo por latência, o tiro vale
quando o alvo está a até 4 studs da linha do disparo e nada bloqueia o caminho.
Explosões ferem menos (35%) quem está atrás de uma estrutura. Sem fogo amigo; dano próprio reduzido.

| Arma | Dano jogador | Dano estrutura | Alcance | Cadência | Munição |
|---|---|---|---|---|---|
| Rifle | 20 (cabeça x1,6) | 40, raio 0,9 | 400 | 0,1 s | 30 + 150, recarga 2 s |
| Lança-foguetes | 110 (centro) | 320, raio 8 | 600 | 1 s | 1 + 5, recarga 2,5 s |
| Granada | 95 (centro) | 240, raio 7 | arremesso | 1 s | 3 por vida, pavio 2,5 s |
| Marreta | 55 | 220, raio 2,4 | 8 | 0,75 s | — |

## Modo Conquista

Área circular no centro (raio 14). Uma equipe sozinha dentro move a captura (8 s com 1 jogador,
mais rápido com mais gente); as duas juntas = disputado. Dominar dá 1 ponto/s; abate dá 3.
Partida de 5 min ou até 250 pontos. No fim, o mapa destrutível é reconstruído e todos renascem.

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

## Primeira pessoa

O jogo é em primeira pessoa (`LockFirstPerson`, FOV 80). Cada cliente vê só o próprio
viewmodel: o mesmo modelo em blocos da Tool, em escala menor, preso à câmera, com braços na cor
do time. Os outros jogadores veem a Tool na mão do personagem. Botão direito mira (FOV 55,
dispersão do rifle cai para 25%). Posições de cada arma na tela: `WeaponConfig.Viewmodel`.

## Mapa "Vila Bloco"

300 x 340 studs, simétrico (o lado vermelho é o azul girado 180°). Três rotas: galpão de
2 andares à esquerda, avenida central com barreiras, casas à direita. Praça central com a área
de captura, cercada por quatro prédios de esquina. Bases com muros estáticos, letreiro e
bandeiras do time. 38 estruturas destrutíveis, cerca de 11,5 mil células em 1.274 Parts,
servidor a 60 FPS na montagem. Prédios de 2 andares têm escada interna e laje; se as paredes
caírem, o andar de cima desaba.
