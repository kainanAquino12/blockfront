# BLOCKFRONT — Visão geral

Jogo multiplayer de guerra para Roblox, **Time Azul contra Time Vermelho**, em **primeira pessoa**,
com **destruição voxel do cenário** como diferencial. Estética de blocos (voxel/low poly), cores
vibrantes, azul e vermelho como cores dos times. Inspiração conceitual: Teardown e Battlefield.
Identidade, mecânicas e código são originais.

## Estado em 15/11/2026

- Projeto Rojo + Git em `C:\Users\kaina\Documents\BLOCKFRONT` (branch `main`, sem remoto, 6 commits).
- Place gerado: `build/BLOCKFRONT.rbxlx`. É um arquivo local, ainda **não publicado** no Roblox.
- Cerca de 8.400 linhas de Luau em 38 arquivos (`src/`).
- Testado só no Roblox Studio com 1 jogador e bonecos de treino. **Nunca foi testado com 2 ou mais jogadores reais.**

## O que já existe

- Modo **Conquista** com 3 pontos de captura (A indústria, B praça, C fazenda), partida de 10 min ou 600 pontos.
- Mapa **"Front Bloco"** (600 × 780 studs) gerado por código: cidade, indústria, rio com pontes, campo e duas bases militares.
- Destruição voxel autoritativa no servidor: 124 estruturas, cerca de 92 mil células e 11,3 mil Parts.
- 9 armas: rifle, submetralhadora, metralhadora, sniper, escopeta, pistola, lança-foguetes, granada e marreta.
- Câmera FPS própria, ADS alinhado pela linha de visada, recuo, áudio espacial e HUD de combate.
- Menu de times (com arma principal e sensibilidade), placar no Tab, renascimento controlado pelo servidor.

## Projeto anterior

O jogo anterior (**Costa Alta**) foi abandonado a pedido do dono. O backup completo dele está em
`C:\Users\kaina\Documents\_Backups\CostaAlta_backup_20261114-1934.zip`, com o histórico Git. **Não apague esse backup.**
O projeto Roblox **"EVOLUÇÃO DE MONSTRUOS"** é outro jogo do dono e **não deve ser tocado**.

## Documentos

| Arquivo | Conteúdo |
|---|---|
| `ARCHITECTURE.md` | Estrutura de pastas, módulos e fluxos |
| `SYSTEMS_STATUS.md` | Cada sistema: implementado, testado ou não testado |
| `KNOWN_BUGS.md` | Bugs e limitações conhecidos |
| `DEVELOPMENT_LOG.md` | Histórico por commit e testes realizados |
| `NEXT_STEPS.md` | Próximas tarefas em ordem |
| `AI_HANDOFF.md` | Guia completo para a próxima IA continuar |
| `docs/ARCHITECTURE.md` | Documento técnico detalhado escrito durante o desenvolvimento |
