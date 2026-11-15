# BLOCKFRONT V5: Open World Battlefield

Direção: **LARGE SCALE STYLIZED VOXEL WARFARE**. Imagem do plano: `docs/mapa_v5_plano.png`.

## Fase 1: auditoria

| Item | Hoje | Decisão |
|---|---|---|
| Área | 600 x 780 studs, chão de Parts planas e rio reto (`MapManager.buildGround`) | **Refazer.** Terreno do Roblox (Terrain) com relevo gerado por código. |
| Composição | cerca de 40 prédios pequenos (12 a 20 studs) e casas, num `MapLayout` de "cidade" | **Refazer.** São 5 construções monumentais e poucas secundárias. |
| Props | árvores cúbicas, carros coloridos, semáforos, bancos, canteiros (`PropKit`) | **Não usar** no mapa novo. O código fica, sem chamadas. |
| Espelhamento | o lado azul é descrito e espelhado em z = 0 para o vermelho (`MapManager.makeContext`) | **Reaproveitar**, porque garante equilíbrio entre os times. |
| Destruição | VoxelGrid, GreedyMesher, StructuralGraph, CollapseBodies, BuildingKit | **Reaproveitar.** É a base das construções novas. |
| Prédio demo | Edifício Central (42x30, 6 andares, 765 elementos) | **Reaproveitar** como base da Torre Comercial (mais andares). |
| Pontos A/B/C | em y = 0. A captura aceita jogador entre -4 e +14 de altura do ponto | **Ajustar** a altura de cada ponto ao terreno. |
| Rodada | `RoundManager` reconstrói as estruturas a cada partida | **Manter.** Medir o tempo de reconstrução com prédios grandes. |
| Streaming | `StreamingEnabled` já ligado (raio 640) | **Manter** e conferir nos testes. |
| Iluminação/paleta | dessaturada desde o V3 | **Manter.** As cores do Terrain ficam mais sóbrias (grama oliva, terra, rocha). |

## Fase 2: distribuição do mapa (640 x 880 studs)

Azul ao sul, vermelho ao norte. O mapa é espelhado em z = 0, então nenhum time leva vantagem de terreno.
A, B e C ficam na linha do meio, à mesma distância das duas bases.

| Região | Onde | Relevo | Combate |
|---|---|---|---|
| **Bases** | z = ±360 | platô +10, com rampas descendo para o campo | proteção do renascimento |
| **Campos e colinas** | entre as bases e o centro | colinas suaves (+3 a +9), com crateras | média e longa distância, cobertura natural |
| **Vala (riacho seco)** | z = ±185, de leste a oeste | depressão de -5 | rota coberta; 3 pontes por lado (avenida, estrada industrial e estrada do morro) |
| **Centro urbano (B)** | x -150..75 | plano +2 (fundações estáveis) | curta distância, dentro e entre prédios grandes |
| **Zona industrial (A)** | x < -150 | pátio plano 0 | galpão enorme, pátio de contêineres, áreas amplas |
| **Cume leste (C)** | x > 110 | sobe até +20, com platô no topo | ponto alto de observação; estrada inclinada em zigue-zague |

### As 5 construções monumentais

1. **Torres Comerciais Norte e Sul** (par espelhado, flanqueando a praça B): 10 andares, 42x30. A estrutura vem do Edifício Central, com pano de vidro, sacadas, lobby, escritórios e escada em U. Não há cobertura acessível pela escada.
2. **Edifício Administrativo** (a leste da praça, sobre o eixo): 6 andares, 36 x 80. Tem colunata na entrada, pátio interno (átrio) aberto, alas com corredores e duas escadas.
3. **Complexo Industrial** (A): nave de fábrica de 90 x 60 com pórticos de aço (pilares e treliças), fechamento em chapa e passarelas metálicas internas. Tem anexo de escritórios de 4 andares e silos.
4. **QG Militar** (C, no topo do cume): fortaleza de concreto com 3 níveis, paredes grossas, torre de observação, muros e trincheiras escavadas no terreno.

Secundárias, poucas: guarita e muros nas bases, 3 pontes por lado sobre a vala, um posto em ruínas e uma casa de fazenda em cada campo, e barricadas leves.

### Rotas

Cada objetivo tem pelo menos 3 caminhos:
- **A:** estrada industrial, beira da vala e travessia pelo centro.
- **B:** avenida central, ruas laterais do centro e passagem por dentro das torres.
- **C:** estrada do morro, encosta sul direta e encosta norte.

### Ordem de construção

3. Terreno (relevo, vala, platôs, estradas inclinadas, cores).
4. Torre Comercial (Edifício Central ampliado) já no lugar definitivo.
5. Destruição testada no mapa novo (com relevo e rodada reiniciando).
6. Administrativo, Complexo Industrial e QG Militar.
7. Otimização: Parts, tempo de reconstrução da rodada, streaming, colapso grande e o máximo de teste multiplayer possível.


---

## Estado em 2026-11-15 (fases 1 a 6 feitas, 7 parcial)

| Fase | Situação | Arquivos |
|---|---|---|
| 3 Terreno | Feito: Terrain do Roblox com colinas (ruído + 3 colinas de observação), vala com 7 de profundidade, cume até +26, platôs, estradas que seguem o relevo e trincheiras no cume. Gera em ~0,4 s no Edit e ~2,8 s no servidor | `server/Map/TerrainGen.luau` |
| 4 Prédio principal | Feito: Torre Comercial de 10 andares (Edifício Central parametrizado), uma de cada lado da praça B, de frente para ela | `Buildings/EdificioCentral.luau` (`build({Floors})`), `BuildingKit.flipZ` |
| 5 Destruição no mapa | Feito: todas as construções novas são BuildingKit com grafo estrutural; testado no Administrativo e no Industrial | — |
| 6 Demais construções | Feito: Edifício Administrativo (átrio, pórtico, 2 escadas), Complexo Industrial (pórticos e tesouras de aço, ponte rolante, mezanino, anexo de 4 andares, silos), QG Militar (9 quadras, pátio, seteiras, 2 escadas, terraço ameado), 2 pontes por lado | `Buildings/EdificioAdministrativo.luau`, `ComplexoIndustrial.luau`, `QGMilitar.luau`, `Ponte.luau`, `BuildingKit:stairCore` |
| 7 Otimização | Parcial (ver abaixo) | — |

### Números medidos (Studio)

- Mapa inteiro: ~9.000 Parts nas estruturas, ~9.550 Parts no workspace em jogo. Montagem das estruturas: 0,5 s.
- Colapso no Administrativo (6 pilares do térreo + colunata): 136 de 1.318 elementos caíram, 222 corpos, 329 Parts de entulho;
  o prédio perdeu o miolo do térreo e ficou de pé. Heartbeat do servidor: médio 24 ms, pior 70 ms (Play Solo).
- Industrial: derrubar os 2 pilares de aço de um pórtico derrubou a tesoura e o telhado daquele vão (24 elementos, 72 corpos).
- Nenhum aviso de "elemento sem apoio no projeto" nas construções do mapa.

### Pendências

- Teste com 2 ou mais jogadores (só foi possível Play Solo pela integração).
- Percorrer as escadas de todos os prédios com o personagem.
- QG Militar e pontes: o colapso não foi testado individualmente.
- Vegetação/veículos no estilo novo: nenhum colocado (por decisão, o mapa ficou limpo).
