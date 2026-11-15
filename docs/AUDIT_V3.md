# Auditoria V3: diagnóstico antes da reformulação visual e do FPS

Data: 15/11/2026. Fontes: a captura enviada pelo dono (5 telas), a leitura do código em `src/`
e os testes anteriores (`DEVELOPMENT_LOG.md`). Nada foi alterado no código nesta etapa.

## 1. Visual (o que a captura mostra)

| Problema | Causa no código |
|---|---|
| Aparência infantil, saturada | `MapManager.applyEnvironment`: ColorCorrection **Saturation +0,20**, Brightness 2,6, ExposureCompensation +0,1. Grama `Grass` (104,176,92) chapada em 600×780 studs. Árvores verde-limão (`PropKit.COLORS.Leaves`) |
| Prédios parecem "caixas com janelas furadas" | `StructureKit.building`: parede com 1 célula de espessura e janela 2×2 no mesmo plano da parede. Sem recuo, sacada, cornija, marquise, pilastra nem entrada destacada. Todos os prédios usam a mesma regra (janela a cada 4 células) |
| Repetição | Só 3 receitas: building, warehouse e garage. Variação apenas de cor do material e número de andares |
| Cidade "espalhada", gramados vazios | `MapLayout`: quarteirões com 2 a 3 prédios e muito espaço livre. Sem calçadas nas ruas secundárias, sem muros nem mobiliário entre prédios |
| Rio azul-vivo artificial | Terrain WaterColor (52,120,170) e transparência 0,6 |
| HUD com caixas grandes e cores fortes | `UIController`: placar com blocos sólidos azul/vermelho de 120×52. O menu de times usa cartões grandes e saturados |

## 2. Primeira pessoa (o que a captura mostra)

| Problema | Causa |
|---|---|
| Braços gigantes (barras azuis saindo do pé da tela) | `ViewmodelController`: "braço" é uma Part reta de 0,2 de espessura, do cotovelo fora da tela até a mão. A cor do time é chapada. Não há mão, antebraço e manga separados |
| Arma grande e apontando para o lado em hip fire | Pose `Hip` com rotação em Y de 4 a 14° e escala de 0,4 do modelo (o rifle tem cerca de 4,6 studs) |
| ADS: a traseira do rifle cobre metade da tela (tela inferior esquerda) | O alinhamento numérico está correto (alça a 0,00 do centro, testado), mas o modelo não tem alça vazada: a alça é um bloco sólido de 0,18×0,26 e o receptor e a coronha ficam na altura da linha de visada. Com AimDistance de 0,75, isso ocupa um ângulo enorme. **É um problema de modelo e pose, não de alinhamento** |
| Retículo "não aparece direito" | Retículo de 2 px × 9 px, branco com contorno 0,4. Fica quase invisível contra céu e chão claros. Ao mirar, as barras somem e sobra um ponto de 4 px |
| Fragmento flutuando no meio da tela (tela inferior direita) | Fragmento de impacto (`DestructionEffects.spawnFragment`) perto da câmera, sem filtro de distância mínima |

## 3. Arquitetura da câmera, ADS e mira (código)

- **Câmera:** há 2 escritores de `camera.CFrame`. O `CameraController` (RenderStep Camera) e o `TeamSelectController`
  (vista do menu, só sem personagem). Não chegam a conflitar hoje, mas a vista do menu deveria ser um modo do CameraController.
- **ADS:** o estado está espalhado em 4 lugares.
  - `WeaponController` tem `aimHeld` e chama `ViewmodelController.setAiming` em 6 pontos, inclusive em todo frame no RenderStepped.
  - `ViewmodelController` tem `aiming`/`aimAlpha` e empurra o FOV para a câmera.
  - `MovementController` recebe `setAiming` todo frame.
  - `UIController` lê `getAimAlpha`.
  - **Não há uma única fonte de verdade.** Proposta: criar `AimController`, dono do estado (Hip/ADS, alpha,
    regras de bloqueio por corrida e recarga). Os outros só leem.
- **FOV:** fixo em 80, sem ajuste nas configurações.
- **Disparo:** origem e direção já vêm do centro da câmera e o servidor valida. **Manter.**

## 4. Destruição

- Funciona e precisa continuar funcionando: VoxelGrid, chunks de 16, greedy mesher, desabamento e fragmentos.
- Fachadas com profundidade (janela recuada, sacada, cornija) **cabem no voxel**: basta a estrutura ter 2 a 3 células
  de espessura na fachada. Isso aumenta células e Parts, então o orçamento precisa ser medido. Hoje são 92 mil células em 11,3 mil Parts.

## 5. Plano proposto (etapas do pedido)

1. Backup (tag Git `pre-v3`).
2. Direção artística: paleta dessaturada (concreto, asfalto, tijolo, metal, madeira, terra, vegetação natural),
   materiais com variação de tom, iluminação de guerra urbana clara (sem saturação extra, contraste moderado,
   neblina leve para limitar linhas de visão longas).
3. Demonstração: reconstruir **um quarteirão central** com um novo kit arquitetônico. Fachada com 2 a 3 células de
   profundidade, janelas recuadas com peitoril e verga, sacadas, cornijas, entradas com marquise e pilastras, térreo
   comercial, telhado com equipamentos. Mostrar ao dono antes de expandir.
4. Expandir o padrão para o resto do mapa, com mais densidade e cobertura nas ruas.
5. Câmera: criar `AimController`, FOV configurável e viewmodel menor no canto inferior direito, com braços em blocos
   proporcionais (luva, antebraço e manga) e distância mínima da câmera.
6. Mira: remodelar alças vazadas (rifle, SMG, LMG, pistola), coronha abaixo da linha de visada e retículo com
   contorno e contraste fortes. Testar o ADS de cada arma com print.
7. HUD minimalista.
8. Validar a destruição nas construções novas (orçamento de Parts e células).
9. Testes no Studio.
