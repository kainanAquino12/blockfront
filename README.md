# BLOCKFRONT

Jogo multiplayer de guerra (Blue vs Red) para Roblox, com destruição voxel do cenário.

- Arquitetura e riscos de performance: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Ferramentas: `rokit install` (Rojo 7.4.4)
- Gerar o place: `rojo build default.project.json -o build/BLOCKFRONT.rbxlx`
- Sincronizar com o Studio: `rojo serve` + plugin do Rojo

## Fases

1. Fundação: estrutura, equipes, spawn (feito); gerenciamento de partidas (pendente)
2. Destruição: parede voxel, dano, explosão, remoção de células, sync (protótipo feito)
3. Combate: rifle, projéteis, granada, lança-foguetes, marreta
4. Mapa: arena, construções destrutíveis, bases, objetivos (modo Conquista)
5. Interface: HUD, placar, temporizador, menu
6. Otimização: testes multiplayer e de destruição em larga escala
