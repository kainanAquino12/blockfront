# BLOCKFRONT — Estado dos sistemas (15/11/2026)

Legenda:
- **OK-T**: implementado e testado no Studio.
- **OK**: implementado, sem teste específico.
- **NT**: implementado, mas o teste depende de algo que não deu para fazer (multijogador, ouvir sons, FPS com a janela em foco).

| Sistema | Arquivos | Estado | Evidência / observação |
|---|---|---|---|
| Voxel: dano esférico, materiais, remoção | VoxelGrid, VoxelStructure, DestructionManager | OK-T | Explosões destruíram de 222 a 493 células nos testes |
| Desmoronamento progressivo | VoxelGrid.findUnsupported, DestructionManager | OK-T | No mapa antigo, 292 células desabaram ao cortar a base de um muro. Prédios com pilares de canto ficam de pé |
| Greedy meshing por chunks de 16 | GreedyMesher, VoxelStructure | OK-T | 92 mil células em 11,3 mil Parts |
| Fragmentos no cliente (pool) | DestructionEffects | OK-T | Pool de 260 Parts, até 220 ativos ao mesmo tempo |
| Envio agrupado da destruição | DestructionManager | OK-T | Mensagens a cada 50 ms, amostradas a 300 células por estrutura |
| Mapa Front Bloco | MapLayout, StructureKit, PropKit, MapManager | OK-T | 124 estruturas. Servidor a 60 FPS e Heartbeat de 0,2 a 0,35 ms |
| Prévia do mapa no editor | (feito via MCP, sem código novo) | OK-T | Gerada em modo Edit e salva no `.rbxlx` |
| Times, menu, balanceamento | TeamManager, TeamSelectController | OK-T (1 jogador) | Entrar, trocar de time e renascer testados. Balanceamento com 2+ jogadores: NT |
| Renascimento em 4 s | TeamManager | OK-T | Testado matando o próprio personagem |
| Partida Conquista e 3 pontos | RoundManager, CaptureManager | OK-T (versão de 1 ponto) / OK (3 pontos) | Captura e pontuação testadas no ponto único antigo. Com A/B/C, só o HUD foi visto |
| Combate validado no servidor | CombatManager | OK-T | Cadência, munição, origem distante e arma errada recusadas. Tiros na cabeça no boneco |
| Abates, placar, feed | CombatManager, TeamManager, UIController | NT | Precisa de 2 jogadores reais. Os bonecos não contam abate |
| 9 armas e escolha de principal | WeaponConfig, WeaponModels, LoadoutManager | OK-T (parcial) | Rifle, sniper, escopeta, pistola e lança-foguetes testados. SMG e metralhadora só configuradas |
| Escopeta com chumbos (semente) | WeaponMath, Weapon/CombatManager | OK-T | Disparo sem erro. A dispersão não foi medida |
| Foguete e granada | Projectiles, CombatManager | OK-T | Foguete destruiu sacos de areia. Granada causou dano próprio (versão anterior) |
| Câmera FPS própria | CameraController | OK-T | Scriptable, FOV 80/62. A sensação ao jogar: NT |
| ADS pela linha de visada | ViewmodelController | OK-T | Alça a 0,00 do centro. 3 cliques reais: 3 tiros na cabeça a 137 studs |
| Retículo dinâmico, luneta | UIController | OK-T | Prints confirmam |
| Recuo, balanço, aterrissagem, corrida | Camera/Movement/Viewmodel | OK | Sem erro. A sensação: NT |
| Áudio espacial (29 IDs) | AudioController, AudioConfig, WeaponConfig | NT | Todos carregam (PreloadAsync). Ninguém ouviu |
| HUD: dano recebido, vinheta, recarga | UIController | OK | O dano recebido precisa de outro jogador ou de explosão própria |
| Ferramentas de teste | DevToolsManager, DevController | OK-T | Bonecos e DevLookAt usados nos testes |
| Mobile e gamepad | — | **Não existe** | O controle das armas só usa mouse e teclado |
| Publicação no Roblox | — | **Não feito** | O place é só local |
