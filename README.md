# mri_Qtaxi 🚕

**mri_Qtaxi** é um script completo e avançado de Emprego de Taxista para servidores FiveM utilizando o framework QBOX Core (`qbx_core`). Construído com uma interface moderna e imersiva (MRI UI Kit), o sistema traz mecânicas de RPG como progressão de níveis, ranqueamento, aluguel de carros por tempo e um sistema dinâmico de geração de chamadas e interações com NPCs (incluindo áudio personalizado).

## 🌟 Principais Funcionalidades

*   **Progressão e Níveis (XP):** Faça corridas e ganhe XP. Subir de nível desbloqueia novas chamadas (mais longas e lucrativas) e aumenta o multiplicador de lucro da corrida.
*   **Central de Chamadas Dinâmica:** Um tablet interativo com abas modernas, onde o jogador pode puxar e aceitar rotas disponíveis em tempo real. O servidor controla um ciclo inteligente de rotação de chamadas (sem limite de tédio).
*   **Configurações de Geração:** Controle exato de quantas corridas ativas o servidor irá manter (`Config.MaxActiveCalls`) e o intervalo de rotação de chamadas (`Config.CallGenerateInterval`).
*   **Aluguel e Compra de Táxis:** Opção de alugar táxi por tempo com contador no HUD do jogador, ou opção de comprar na concessionária integrada e retirar livremente em qualquer ponto.
*   **Mecânica de Satisfação do Passageiro (Realismo):**
    *   Ao aceitar a corrida, o NPC entra no veículo.
    *   Excesso de velocidade e batidas irritam o passageiro. O nível de satisfação cai em tempo real.
    *   Menos satisfação significa menos pagamento final. Dirija com cuidado para receber gorjetas generosas!
*   **Vozes Personalizadas (Interações Sonoras):** 
    *   Quando você comete uma infração (corre ou bate), o NPC reage reclamando verbalmente com **áudios MP3 dinâmicos**!
    *   Pode ser configurado se a reação será de uma voz masculina ou feminina dependendo do NPC embarcado.
*   **Ranking Top Taxistas:** Interface que mostra os jogadores com mais XP e oferece Bônus salarial para os Top 3 globais.
*   **Acesso Remoto via Tablet:** Jogadores podem usar o item `tablet_taxi` de qualquer lugar para visualizar o dashboard e o ranking.
*   **Filtro Inteligente Anti-Glitch:** Quando o jogador acessa o tablet de fora da central, o sistema filtra e oculta automaticamente as chamadas que estiverem muito perto dele (raio configurável). Isso força o jogador a viajar pela cidade para iniciar corridas, evitando que ele pegue passageiros infinitamente no mesmo local (glitch de farm).
*   **Design Minimalista e Elegante:** Dark/Light modes, notificações animadas, e proteção contra o jogador "travar" durante a navegação.

## 🛠 Dependências

*   [qbx_core](https://github.com/Qbox-project/qbx_core)
*   [ox_lib](https://github.com/overextended/ox_lib)
*   [ox_target](https://github.com/overextended/ox_target)
*   [oxmysql](https://github.com/overextended/oxmysql)
*   *(Opcional)* mri_Qcarkeys ou sistema de chaves similar

## 📦 Instalação

1.  Faça o download e coloque a pasta `mri_Qtaxi` dentro do seu diretório de recursos (resources).
2.  Importe ou inicie o script uma vez. A tabela `mri_qtaxi_players` é **criada automaticamente** no seu banco de dados na primeira vez que o script for iniciado (`onResourceStart`).
3. Adicione `ensure mri_Qtaxi` no seu `server.cfg`.
4. Cadastre o item `tablet_taxi` no seu `ox_inventory/data/items.lua` conforme abaixo:
```lua
['tablet_taxi'] = {
    label = 'Tablet de Taxista',
    weight = 500,
    stack = false,
    close = true,
    description = 'Tablet de acesso remoto à central de chamadas da Taxi Co.'
},
```

## ⚙️ Configuração Básica (`config.lua`)

O sistema é altamente modular e pronto para edição rápida:

```lua
Config.CallGenerateInterval = 30 -- Tempo (segundos) para gerar uma nova corrida
Config.MaxActiveCalls       = 15 -- Limite máximo de corridas ativas no tablet

-- Penalidades
Config.MaxSafeSpeed        = 130    -- Limite de vel. sem tomar xingo do NPC
Config.ImpactConditionLoss = 0.5    -- Dano na satisfação por colisões

-- Como customizar os Áudios dos NPCs:
Config.Infractions = {
    speed = {
        male = {
            { text = "Para que essa pressa?", audio = "voice/pressa_m.mp3" },
        },
        female = {
            { text = "Vai devagar, Doido!", audio = "voice/vai_devagar.mp3" },
        }
    }
}
```

*Desenvolvido com o MRI UI Kit.*
