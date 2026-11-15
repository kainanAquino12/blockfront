# BLOCKFRONT — Próximos passos (em ordem)

1. **Teste multijogador.** No Studio, use Test > Clients and Servers com 2 a 4 jogadores. Confira:
   - abate, feed e placar;
   - balanceamento de times;
   - tiros, fragmentos e sons vistos pelos outros;
   - captura disputada.
   Corrija o que falhar antes de qualquer coisa nova.
2. **Sessão de jogo com o dono**, com a janela em foco. Avalie:
   - sensação da câmera, recuo e sensibilidade;
   - FPS real;
   - sons (troque IDs em `WeaponConfig.Sounds` / `AudioConfig`);
   - poses das armas (`WeaponConfig.*.Viewmodel.Hip`).
3. **Braços do viewmodel melhores.** Por exemplo, antebraço + mão + manga em blocos e pose por arma.
4. **Segurança básica:**
   - tempo de espera na troca de time;
   - checagem simples de velocidade no servidor;
   - cancelar a recarga ao trocar de arma.
5. **Testar a subida nas torres.** Se não funcionar, troque os degraus por `TrussPart`, ou por escada voxel em zigue-zague.
6. **Desabamento mais convincente.** Por exemplo, exigir mais de uma ligação por coluna, ou dano estrutural acumulado.
   Antes, meça o custo de `findUnsupported` em prédios grandes.
7. **Desempenho:**
   - medir FPS e memória do cliente em foco;
   - testar várias explosões simultâneas com vários jogadores;
   - avaliar `ModelStreamingMode` das estruturas.
8. Mobile e gamepad (botões na tela), câmera de morte, menu de pausa e configurações.
9. Publicar no Roblox (o dono decide). Antes, reveja os direitos dos sons da Creator Store.

Regra do dono: não construir novidades antes de estabilizar o que existe e testar cada sistema.
