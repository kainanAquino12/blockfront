# BLOCKFRONT V4: auditoria e plano técnico

Direção: **LARGE SCALE URBAN VOXEL WARFARE**. Sistema novo: **STRUCTURAL INTEGRITY & PHYSICS COLLAPSE**.
Base: commit `89780f2` (V3). Antes de qualquer mudança estrutural será criada a tag `pre-v4`.

---

## Fase 1: auditoria do estado atual

### 1. Escala e mapa

| Item | Hoje | Problema |
|---|---|---|
| Personagem | R15 padrão, cerca de 5 studs de altura, olho a 1,55 do HumanoidRootPart | É a referência. Está correto. |
| Voxel | 1 stud (`DestructionConfig.VoxelSize`) | OK. Mantido. |
| Andar | 7 studs (laje 1 + pé-direito 6), porta 6 de altura | Pé-direito apertado para 5 studs de personagem: parece casa de boneca. |
| Prédios | 12 a 20 studs de lado, 1 a 6 andares, cerca de 40 estruturas | São caixas pequenas e parecidas. O maior tem 18x18. Nenhum tem escala de "prédio comercial". |
| Ruas | avenida de 18 studs, mapa de 232 x 600 | Estreito para a escala desejada. Quarteirões curtos. |
| Props | árvores cúbicas, carros coloridos, canteiros, contêineres, bancos (`PropKit`) | É o que dá o ar de "brinquedo" na sua imagem. |
| Interiores | `Partition = true` cria uma divisória, mais a escada até o teto | Quase vazios: sem corredor, sala, núcleo de escada ou pilares. |

### 2. Viewmodel (braços grandes)

O código atual (`ViewmodelController`) **não tem hierarquia de braço**:
- O antebraço é uma barra solta, desenhada no espaço da câmera a partir da mão, com comprimento fixo (0,62) e direção fixa para baixo (`FOREARM_DIR_R/L`).
- A arma é um Model escalado com `ScaleTo(0.32 a 0.42)` e posto a 1,0 a 1,35 studs do olho.
- O braço **não** recebe a mesma escala da arma. A 1 stud da câmera, uma barra de 0,62 cobre metade da altura da tela. É por isso que, no seu print, ela parece um "cabo azul" saindo da tela.
- O pivô de cada arma é a `Handle`, mas a mão esquerda é posicionada por um offset por arma. Não existe ombro nem cotovelo, então não há como o braço "dobrar".
- A manga ainda usa a cor do time (escurecida), o que destaca ainda mais.

**Correção proposta.** Criar um rig de braço próprio (ombro → braço → antebraço → mão) com IK de 2 ossos:
- os ombros ficam fixos no espaço da câmera, fora da tela;
- as mãos ficam nos encaixes da arma (`GripR` e `GripL`);
- o cotovelo é calculado.

Tudo fica em **uma escala única** do viewmodel, a arma volta a ter tamanho real e a distância da câmera passa a ser consistente entre as armas. As mangas terão cor de uniforme (verde-oliva ou cinza), com braçadeira da cor do time.

### 3. Destruição (por que o prédio "some")

- Cada estrutura é um `VoxelGrid` (buffers de material e vida). Explosões tiram vida das células.
- `VoxelGrid.findUnsupported` faz um flood-fill em 6 direções a partir da camada `y == 0`. Toda célula que não encosta no chão por algum caminho é marcada.
- `DestructionManager` apaga essas células, 60 por passo, de baixo para cima. O cliente cria fragmentos que desaparecem em 2 a 3,5 s.
- **Resultado:** o bloco solto é apagado e vira poeira que some. Não existe corpo físico caindo, nem peso, resistência, carga ou tipo de elemento.
- Problema inverso: **uma única coluna de células segura um prédio inteiro**, porque só se testa conectividade (já listado em KNOWN_BUGS #4).
- Hoje não há diferença entre parede decorativa e pilar.

O que se aproveita: VoxelGrid em buffers, GreedyMesher por chunk de 16, envio agrupado a cada 50 ms, autoridade do servidor e pool de fragmentos do cliente.

---

## Plano técnico

### Arquitetura: grafo estrutural sobre os voxels

```
Prédio
├─ VoxelGrid            (como hoje: material + vida por célula)
├─ elementId por célula (buffer u16 novo: a qual elemento a célula pertence)
└─ StructuralGraph
     Elemento { tipo, material, células, massa, resistência, capacidade, integridade, conexões[] }
     tipos: Foundation · Column · Beam · Slab · Wall(portante) · Wall(divisória) · Roof · Stair
```

- **O gerador cria elementos, não caixas.** A construção é descrita como elementos (pilar em x,z, viga entre pilares, laje do andar N, etc.). Cada um escreve suas células no grid e se registra no grafo, já com as conexões.
- **Integridade:** células vivas / células iniciais. Um elemento estrutural **falha** abaixo de um limite (pilar 45%, viga 40%, laje 30%). Uma divisória nunca sustenta nada, então tirá-la não derruba nada.
- **Sustentação (a cada mudança, só no prédio afetado):**
  1. Faz um BFS no grafo a partir das fundações, passando só por elementos que não falharam. O que não é alcançado vira uma **ilha solta**.
  2. Para o que continua apoiado, calcula a carga de cima para baixo: cada elemento soma o próprio peso mais o que apoia e distribui essa carga para os apoios abaixo, proporcionalmente.
  3. Se a carga passar de `capacidade × integridade`, o elemento entra em estado **instável**: range e cede depois de 0,3 a 1 s, e então falha. Isso dispara uma nova checagem, e é isso que faz o **colapso em etapas**.
  4. **Vão máximo:** uma laje ou viga mais longe que `MaxSpan[material]` do apoio mais próximo cede. Isso evita "laje flutuando sobre um pilar só".
- **Impactos pequenos não derrubam nada:** só explosão ou dano acumulado num elemento estrutural mexe no grafo. Tiro de rifle só tira células.

### Colapso físico (o prédio não some mais)

- **Ilha solta → corpos rígidos:**
  - As células da ilha são agrupadas em blocos de até 6x6x6 com o GreedyMesher.
  - Cada bloco vira um Model de Parts soldadas, sem âncora, com dono de rede = servidor.
  - O impulso inicial vem da explosão. A gravidade e as colisões são do motor do Roblox.
- **Limites:**
  - no máximo 40 corpos ativos;
  - no máximo 12 Parts por corpo;
  - só simula a menos de N studs de algum jogador (fora disso, cai "teleportado" para o chão);
  - pool de Parts no servidor (já existe o `PartPool`).
- **Assentou → vira entulho:**
  - Um corpo parado por 1,5 s é ancorado e vira **entulho persistente**: continua lá, serve de cobertura e dá para subir.
  - Quando o orçamento de entulho estoura, o entulho mais antigo e mais longe dos jogadores é removido aos poucos.
- **Queda sobre outros elementos:** um corpo que bate com energia alta numa estrutura causa dano no ponto de contato. Isso pode quebrar uma laje de baixo ou o prédio vizinho, com limite de cascata por segundo.
- **Fragmentos do cliente** continuam só visuais (poeira e lascas), mas duram mais e não substituem o colapso.

### Rede e multiplayer

- O servidor é dono do estado do grid, do grafo e dos corpos. O cliente nunca decide o que caiu.
- O grid continua sendo replicado pelas mensagens agrupadas atuais. Os corpos rígidos replicam pela física do Roblox (dono = servidor, sem mudança de dono).
- Quem entra no meio da partida recebe o estado atual (as Parts reconstruídas já estão no workspace; o entulho é Part ancorada).

### Prédio demonstrativo (Fases 3 a 6)

**"Edifício Central":** comercial de 6 andares em estrutura de concreto armado, numa área de teste separada (não mexe no mapa atual até a aprovação).

| | |
|---|---|
| Planta | cerca de 40 x 28 studs, malha de pilares a cada 8 studs |
| Andar | 9 studs (laje 1 + pé-direito 8); térreo com pé-direito duplo (lobby) |
| Estrutura | fundação, pilares 2x2, vigas de borda e internas, lajes, núcleo de escada e de elevador em concreto |
| Fachada | pano de vidro recuado entre pilares nos andares de escritório, brises metálicos, sacadas numa face, marquise na entrada, cornija |
| Cobertura | platibanda, casa de máquinas, caixa d'água, dutos |
| Interior | lobby, corredor central, salas com divisórias de gesso (frágeis), portas 4x7, escada em U em todos os andares, sem móveis em excesso: só balcões e mesas que servem de cobertura |
| Células | estimativa de 25 a 35 mil células vivas. Hoje o mapa inteiro tem 118 mil. |

**Testes que vou fazer, com print e medição** (por comando de DevTools que destrói um elemento pelo nome):
1. parede;
2. pilar;
3. viga;
4. laje;
5. andar sem apoio;
6. colapso parcial;
7. colapso grande;
8. destroços batendo no chão e no vizinho.

Também vou medir FPS, tempo de Heartbeat do servidor, Parts e corpos ativos, e rodar um teste local com 2 jogadores (servidor + 2 clientes no Studio).

### Ordem de execução

| Fase | Entrega | Arquivos principais |
|---|---|---|
| 2 | Rig de braço com IK, escala única, poses revisadas, ADS conferido em todas as armas | `ViewmodelController`, `WeaponModels` (GripL/GripR), `WeaponConfig` |
| 3 | Edifício Central: estrutura e fachada | `Map/BuildingKit.luau` (novo, gera elementos), `MaterialConfig` (massa/resistência) |
| 4 | Interior completo | `BuildingKit` |
| 5 | `StructuralGraph.luau` (novo) e integração no `DestructionManager` | `Destruction/StructuralGraph`, `VoxelStructure`, `DestructionManager` |
| 6 | `CollapseBodies.luau` (novo): corpos rígidos, entulho e cascata | `Destruction/CollapseBodies` |
| 7 | Teste com 2 clientes e ajuste dos limites | `DestructionConfig` |
| 8 | *(só depois da sua aprovação)* novo mapa em escala grande usando o padrão aprovado; remoção de árvores e carros de brinquedo | `MapLayout`, `PropKit` |

Fica de fora até a Fase 8: redesenhar o mapa todo e trocar props.
