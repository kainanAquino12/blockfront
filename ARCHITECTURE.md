# BLOCKFRONT — Arquitetura

Para detalhes técnicos mais longos (tabelas de armas, riscos de performance), veja também `docs/ARCHITECTURE.md`.

## Ferramentas

- Rojo 7.4.4, instalado via `rokit.toml`. Para gerar o place: `rojo build default.project.json -o build/BLOCKFRONT.rbxlx`.
- O plugin do Rojo está instalado no Studio do dono, então `rojo serve` também funciona.
- `default.project.json` define: `ReplicatedStorage.Shared` = `src/shared`, `ServerScriptService.Server` = `src/server`,
  `StarterPlayer.StarterPlayerScripts.Client` = `src/client`. Também define `Players.CharacterAutoLoads = false`,
  `Lighting.Technology = Future` e o Workspace com `StreamingEnabled = true`, `StreamingTargetRadius = 640` e `StreamingMinRadius = 160`.

## Pontos de entrada (um único script de cada lado)

- **Servidor:** `src/server/GameManager.server.luau`. Registra os grupos de colisão (Characters, Debris) e inicializa, nesta ordem:
  Remotes → TeamManager → DestructionManager → MapManager → RoundManager → CombatManager → LoadoutManager → DevToolsManager.
- **Cliente:** `src/client/ClientMain.client.luau`. Inicializa, nesta ordem: SettingsController → AudioController →
  DestructionEffects → CameraController → MovementController → ViewmodelController → CombatEffects → WeaponController →
  UIController → TeamSelectController → DevController.

Todo o resto são ModuleScripts com `init()`.

## Pastas

```
src/shared/Config/   GameConfig, MatchConfig, MaterialConfig (18 materiais), DestructionConfig, WeaponConfig, AudioConfig
src/shared/Modules/  Remotes, VoxelGrid, GreedyMesher, WeaponModels, WeaponMath
src/server/Managers/ Team, Destruction, Map, Round, Capture, Combat, Loadout, DevTools
src/server/Destruction/ VoxelStructure, PartPool
src/server/Combat/   Projectiles
src/server/Map/      MapLayout (layout do mapa), StructureKit (prédios voxel), PropKit (cenário estático)
src/client/Controllers/ Settings, Audio, DestructionEffects, Camera, Movement, Viewmodel,
                        CombatEffects, Weapon, UI, TeamSelect, Dev
```

## RemoteEvents (`src/shared/Modules/Remotes.luau`)

O servidor cria todos em `ReplicatedStorage.Remotes`:

| Evento | Direção | Uso |
|---|---|---|
| DestructionBatch | servidor → todos | células destruídas e explosões, agrupadas a cada 50 ms |
| DevExplosionRequest | cliente → servidor | teclas G e H (só no Studio) |
| WeaponFire | cliente → servidor | arma, origem, direção, alvo sugerido, semente dos chumbos |
| WeaponReload | cliente → servidor | pedido de recarga |
| CombatEvent | servidor → clientes | Shot, Rocket, ProjectileEnd, Throw, Swing, Hit, Damaged, Kill |
| TeamSelect | cliente → servidor | "Blue", "Red" ou "Auto" |
| LoadoutSelect | cliente → servidor | arma principal |

Não há RemoteFunctions.

## Estado compartilhado sem remotes

- `ReplicatedStorage.Match` (Configuration) guarda em atributos: State, TimeLeft, ScoreBlue, ScoreRed, Winner, ScoreToWin
  e `Cap_<A|B|C>_Value/_Owner/_State`.
- Atributos da Tool: WeaponId, Ammo, Reserve, Reloading e Slot. A munição oficial é a do servidor.
- Atributos do jogador: Primary (arma principal), Sensitivity (definido no cliente) e DevLookAt (gancho de teste, só no Studio).
- leaderstats: Abates e Mortes.

## Fluxos principais

1. **Entrada:** o jogador entra sem time e sem personagem, e o menu abre. Ao escolher, `TeamSelect` faz o TeamManager
   definir o time e chamar `LoadCharacter`. O LoadoutManager entrega 5 Tools com Slot de 1 a 5.
2. **Tiro:** a origem e a direção saem do centro da câmera, com dispersão. O cliente desenha o tiro e envia `WeaponFire`.
   O CombatManager valida, refaz o raycast, aplica o dano e danifica a estrutura. Depois manda `CombatEvent Shot` para todos.
3. **Destruição:** `DestructionManager.explode` aplica dano nas células do VoxelGrid e marca os chunks como sujos.
   No passo seguinte ele checa o apoio estrutural, faz o desmoronamento progressivo e remonta os chunks com o greedy mesher.
   Por fim envia o `DestructionBatch`, e o cliente cria os fragmentos.
4. **Partida:** o RoundManager passa por Waiting → Starting (5 s) → InProgress (600 s ou 600 pontos) → Ended (10 s).
   Depois disso ele reconstrói as estruturas, zera o placar e faz todos renascerem.
