# BLOCKFRONT — Bugs e limitações conhecidos

Lista só o que foi observado ou pode ser verificado no código. Nada aqui foi inventado.

## Confirmados ou observados

1. **Braços do viewmodel ainda simples (V3: melhorados).** Agora são antebraço de comprimento fixo (0.62) + luva,
   manga na cor do time escurecida. Continuam sendo blocos; um modelo de mão/manga mais detalhado seria o próximo passo.
2. **Asset 203785492 ("Asset type does not match").** Aparece no Output ao entrar. Não está no código do projeto
   (grep em src/ não acha); provavelmente vem de um acessório do avatar do jogador de teste.
3. **Picos de renderização no cliente.** Chegaram a 25 ms durante 6 explosões seguidas (`Stats.RenderCPUFrameTime`).
   O FPS medido no Studio foi 15 mesmo sem explosões, porque o Studio estava fora de foco. **O FPS real não foi medido.**
4. **Prédios ficam de pé sobre os pilares de canto.** Isso acontece mesmo com o térreo destruído, porque o apoio é
   checado por conectividade (`VoxelGrid.findUnsupported`). É o comportamento do algoritmo, não um travamento,
   mas pode não ser o visual desejado.
5. **A prévia do mapa some ao reconstruir.** `rojo build` recria o `.rbxlx` sem o mapa. Para o mapa aparecer no
   modo Edit, rode em Edit:
   `local M = require(game.ServerScriptService.Server.Managers.MapManager); M.buildStatic(); M.buildDestructibles()`
   e salve.
6. **Código morto pequeno.** Em `UIController.buildCrosshair` sobrou `local _ = g`, sem efeito.
7. **Armas não testadas em ADS no V3:** SMG, LMG, sniper e escopeta (não estão no kit padrão do teste).
   Rifle, pistola e lança-foguetes foram testados com mouse real.

## Riscos e limitações (não testados)

- **Multijogador nunca testado** com 2 ou mais jogadores reais: abate, feed, balanceamento, replicação de tiros e fragmentos.
- **Troca de time sem tempo de espera.** `TeamManager.onTeamSelect` chama `LoadCharacter` na hora, então dá para
  renascer na base trocando de time sem limite.
- **Velocidade definida pelo cliente.** `MovementController` muda o WalkSpeed localmente e o servidor não valida.
- **Dano de explosão** usa a distância até o HumanoidRootPart. Atrás de estrutura, o dano cai para 35%.
- **Recarga continua após trocar de arma.** O servidor completa a recarga depois de ReloadTime mesmo se a Tool voltou para a mochila.
- **Sons escolhidos pelo nome** na Creator Store. Carregam, mas ninguém ouviu. Podem ser ruins ou ter direitos duvidosos.
  Para trocar: `WeaponConfig.Sounds` e `AudioConfig`.
- **Som de explosão duplicado (possível).** A instância `Explosion` do Roblox pode tocar o som padrão junto com o do AudioController. Não foi verificado.
- **Escada das torres (degraus espaçados) nunca testada.** Não se sabe se o Humanoid consegue subir.
- **Sem controles para celular ou gamepad.**
- **Sem câmera de morte.** A câmera fica parada até renascer.
- **Lighting.** Rodar a prévia do mapa em Edit aplica as configurações de iluminação no place salvo. Ao dar Play o servidor aplica de novo.

## Correções já feitas (para não repetir)

- V3: estado do ADS espalhado em 4 scripts → fonte única `AimController` (Viewmodel, Weapon, UI e Camera só leem dele).
- V3: alça de mira sólida tampava a massa → alças vazadas (anel) em Rifle/SMG/LMG e alça em U na pistola (`WeaponModels`).
- V3: partículas de acessórios do avatar (ex.: asas VFX) apareciam borradas na frente da câmera → `CameraController.hideEffect` desliga emissores do próprio personagem.
- V3: fragmento de impacto podia nascer colado na câmera → `DestructionEffects.spawnFragment` ignora posições a menos de 4 studs.

- O ADS falhava porque a câmera padrão do Roblox usava o botão direito. Foi substituída pela câmera própria Scriptable (`CameraController`).
- O ADS ficava desalinhado com poses manuais. Agora a pose é calculada pelo Attachment `Sight` de cada modelo.
- O retículo sumia ao mirar: era proposital e parecia bug. Agora vira um ponto e fica numa ScreenGui com DisplayOrder 50.
- O colete do time sumia porque a aparência do avatar troca as partes do corpo. Agora o colete é criado em `CharacterAppearanceLoaded`.
- O placar dava erro quando `ReplicatedStorage.Match` ainda não existia. Hoje usa `FindFirstChild`.
- `string.upper` não converte "ç". O HUD usa um `upper()` próprio.
- O PowerShell 5.1 com `Set-Content -Encoding utf8` grava BOM nos arquivos. Remova o BOM.
- A calçada atravessava os cruzamentos. Ela foi dividida em segmentos.
