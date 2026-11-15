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
