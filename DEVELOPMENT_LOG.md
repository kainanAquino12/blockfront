# BLOCKFRONT — Registro de desenvolvimento

Tudo aconteceu entre 14 e 15/11/2026, com o Claude trabalhando no PC do dono via Studio MCP e Rojo.

## Commits (`git log`)

| Commit | Conteúdo |
|---|---|
| 3f9d39f | Fundação: estrutura Rojo, VoxelGrid, greedy mesher, DestructionManager, fragmentos, paredes de teste, teclas G/H |
| 02232cb | Partida Conquista (1 ponto), 4 armas em blocos, CombatManager validado, HUD, colete do time |
| 7a5d55b | Primeira pessoa com viewmodel, armas detalhadas, mapa "Vila Bloco" e iluminação |
| afac433 | Menu de times, renascimento pelo servidor, placar no Tab |
| ffff538 | Mapa "Front Bloco" 600×780, 3 pontos de captura, StructureKit e PropKit novos, 9 materiais novos |
| 7118975 | Câmera FPS própria, ADS pela linha de visada, 9 armas, recuo, áudio espacial, HUD de combate, bonecos de treino |

Depois do último commit, o place foi salvo com a prévia do mapa (arquivo gerado, fora do Git).

## Testes realizados de verdade (Studio, 1 jogador)

- **Unidade:** VoxelGrid (dano, apoio estrutural) e GreedyMesher (uma parede cheia vira 1 caixa).
- **Protótipo:** 4 explosões em 3 paredes destruíram 224 a 232 células cada. O corte da base derrubou 292 células.
  Pedidos inválidos (NaN, tipo errado, preset inexistente) foram recusados.
- **Combate:** cadência (spam recusado), arma não equipada recusada, origem a 50 studs recusada, munição e recarga funcionando.
- **Captura:** 8 s para dominar e +1 ponto por segundo (versão de 1 ponto).
- **Granada:** dano próprio de 22 (versão anterior).
- **Sons:** 29 IDs carregam com sucesso e duração maior que 0.
- **Mapa Front Bloco:** 124 estruturas, 92.347 células, 11.346 Parts voxel. Servidor a 60 FPS, Heartbeat de 0,21 a 0,35 ms.
- **Explosões:** 5 num prédio destruíram 222 células. Com 6 seguidas, a renderização do cliente chegou a 25 ms no pico.
- **Mira:** pela API, a alça ficou a (0, 0, -0,55) da câmera, ou seja, centralizada. Com cliques reais (user_mouse_input)
  e mirando com o botão direito, 3 tiros acertaram a cabeça do boneco a 137 studs.
- **Pelo remoto:** 3 tiros de rifle na cabeça mataram o boneco a 73 studs.
- **Armas vistas por print:** rifle sem mirar e mirando, luneta da sniper, escopeta, pistola, lança-foguetes, menu e placar.
- **Output:** sem erros de script nas últimas execuções. Aparece só "ContentId 203785492" do próprio Roblox, não do jogo.

## Não testado

Multijogador real, sensação de câmera e recuo, qualidade dos sons, FPS com a janela em foco, escada das torres,
SMG e metralhadora em jogo, mobile e gamepad.


## 2026-11-15 — V3: reconstrução visual e FPS ("stylized military voxel")

Backup: tag git `pre-v3`. Diagnóstico em `docs/AUDIT_V3.md`. Prints em `docs/prints_v3/`.

- Arte: paleta dessaturada (`MaterialConfig`, `PropKit`, cores dos times), materiais novos Stone/Awning/DarkMetal,
  iluminação de fim de tarde com ColorCorrection Saturation -0.12 (`MapManager.applyEnvironment`), calçamento urbano.
- Arquitetura: `StructureKit.facadeBuilding` (pilares, cornijas, base, peitoris, marquises, toldos de loja, sacadas
  com guarda-corpo) aplicado a todos os prédios via `MapLayout.B`.
- Câmera: FOV configurável 70–100 no menu (`SettingsController.getFov/setFov`, linha nova em `TeamSelectController`).
- Viewmodel: armas menores e no canto inferior direito (poses em `WeaponConfig`), antebraço proporcional + luva.
- Mira: `AimController` novo (fonte única do ADS); alças vazadas; retículo 10x3 com contorno forte que some no ADS.
- HUD: painéis escuros translúcidos, placar menor com faixa da cor do time, pílulas A/B/C menores, painéis de vida/arma compactos.
- Testado no Studio: ADS do rifle/pistola/RPG com mouse real, destruição por foguete em fachada nova,
  Output sem erros de script, 60 FPS de física, ~18 mil Parts em jogo.

Arquivos modificados: ClientMain, AimController (novo), CameraController, DestructionEffects, SettingsController,
TeamSelectController, UIController, ViewmodelController, WeaponController, MapManager, MapLayout, PropKit,
StructureKit, GameConfig, MaterialConfig, WeaponConfig, WeaponModels.


## 2026-11-15 — V4: STRUCTURAL INTEGRITY & PHYSICS COLLAPSE + Edifício Central

Backup: tag `pre-v4`. Plano e resultados em `docs/AUDIT_V4.md`. Prints em `docs/prints_v4/`.

- Viewmodel: braço com IK de 2 ossos (ombro fixo fora da tela, mão na arma, cotovelo calculado); mangas de uniforme, braçadeira do time.
- Novo `BuildingKit` (construção por elementos) e prédio demonstrativo `EdificioCentral` (6 andares, área de demo em x=420).
- Novo `StructuralGraph`: elementos com massa, carga de projeto, capacidade, integridade; carga desce pela ordem (altura, nível);
  elemento pendurado ou sobrecarregado fica instável e rompe depois de 0,35 a 0,9 s (colapso progressivo).
- Novo `CollapseBodies`: o que perde apoio vira corpo rígido (blocos de 7 a 12 células), cai, causa dano onde bate,
  vira entulho persistente; limpeza do entulho mais antigo acima de 1.800 Parts.
- `DestructionManager`: integra grafo e corpos; o desmoronamento antigo (células apagadas de baixo para cima) foi substituído
  pelos corpos físicos em TODAS as estruturas; `destroyElement`, `findStructure`, tempos de passo nas estatísticas.
- DevTools: `ServerStorage.DevStructure` (teleport, breakName, elements, stats, explode).
- Materiais novos: ReinforcedConcrete, Gypsum, TintedGlass, FacadePanel.

Arquivos novos: `shared/Config/StructuralConfig.luau`, `server/Destruction/StructuralGraph.luau`,
`server/Destruction/CollapseBodies.luau`, `server/Map/BuildingKit.luau`, `server/Map/Buildings/EdificioCentral.luau`.
Arquivos modificados: `ViewmodelController`, `WeaponConfig` (poses), `MaterialConfig`, `GameConfig` (DemoArea),
`DestructionManager`, `MapManager`, `DevToolsManager`.


## 2026-11-15 — V5: Open World Battlefield

Plano e resultados: `docs/MAPA_V5.md`. Prints: `docs/prints_v5/`.

- Mapa refeito: 640 x 880, Terrain com relevo (`TerrainGen`), sem árvores cúbicas, carros ou casinhas.
- 5 construções monumentais por elementos estruturais: 2 Torres Comerciais (10 andares), Edifício Administrativo,
  Complexo Industrial, QG Militar; pontes destrutíveis sobre a vala.
- Pontos A/B/C movidos para (-240, 0), (-20, 0), (234, 0) com a altura do chão; spawns no platô +12.
- `BuildingKit.flipZ` (espelhamento único usado pelo MapManager) e `BuildingKit:stairCore` (núcleo de escada reutilizável).
- `StructuralGraph`: viga/laje também se apoiam lateralmente em fundação (pontes).
- Área de demonstração isolada desligada (`GameConfig.DemoArea.Enabled = false`).

Arquivos novos: `server/Map/TerrainGen.luau`, `server/Map/Buildings/{EdificioAdministrativo,ComplexoIndustrial,QGMilitar,Ponte}.luau`.
Reescritos: `server/Map/MapLayout.luau`. Modificados: `MapManager` (buildGround, ctx.struct com elementos), `BuildingKit`,
`EdificioCentral` (andares por parâmetro), `StructuralGraph`, `MatchConfig` (pontos), `GameConfig`, `DevToolsManager`.


## 2026-11-15 — V6: expansão do mapa

Detalhes em `docs/MAPA_V5.md` (seção V6). Prints em `docs/prints_v6/`.
Novos: `Buildings/EdificioResidencial.luau` (com opções Floors/Wall/Damaged), `Buildings/Porto.luau`, `BuildingKit.swapXZ`.
Modificados: `TerrainGen` (x ±480, canal com água, porto, subúrbio, crateras, estradas), `MapLayout` (expansão, entulho, fumaça),
`MapManager` (iluminação de zona de guerra, pastas por distrito), `UIController` (espera o Match por até 120 s:
o servidor leva ~5 s para gerar o terreno grande).


## 2026-11-16 — V7: mundo mais completo

Detalhes em `docs/MAPA_V5.md` (seção V7). Novos: `Buildings/Secundarias.luau` (centro comercial, posto, oficina,
depósito, parque de tanques, celeiro), `WorldProps.luau` (postes, semáforos, placas, fiação, bueiros, geradores,
tubulações, contêineres, veículos destruídos, árvores, arbustos, rochas). `MapLayout`: buildCityBlocks, buildIndustry,
buildPeriphery; entulho/fumaça em RuinsAndDebris. `MapManager`: distritos atualizados.
