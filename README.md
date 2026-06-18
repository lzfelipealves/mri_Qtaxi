# mri_Qtaxi 🚕

**mri_Qtaxi** é um script completo e avançado de Emprego de Taxista para servidores FiveM utilizando o framework QBOX Core (`qbx_core`). Construído com uma interface moderna e imersiva (MRI UI Kit), o sistema traz mecânicas de RPG como progressão de níveis, ranqueamento, aluguel de carros por tempo e sistema de posse de veículos.

## 🌟 Principais Funcionalidades

*   **Progressão e Níveis (XP):** Faça corridas e ganhe XP. Subir de nível desbloqueia novas chamadas (mais longas e lucrativas) e aumenta o multiplicador de gorjeta.
*   **Central de Chamadas:** Um tablet interativo onde você pode filtrar corridas por zonas da cidade (Centro, Aeroporto, etc.).
*   **Aluguel Dinâmico:** Não tem um carro? Alugue um táxi por 30 minutos, 1 hora ou 2 horas reais. Um timer fica ativo no seu HUD.
*   **Concessionária / Garagem de Táxis:** Invista na sua profissão e compre seu próprio veículo com dinheiro do banco. Táxis próprios podem ser retirados da sua "Garagem" gratuitamente sempre que quiser.
*   **Corridas Realistas com NPCs:** 
    *   Ao aceitar uma corrida, um Ped será gerado no ponto de partida aguardando por você.
    *   O NPC entrará no carro e o destino será marcado no GPS.
    *   **Satisfação do Passageiro:** Dirigir acima de 130 km/h ou bater o carro diminui a satisfação do cliente, o que reduz o pagamento final.
    *   **Gorjeta:** Seja rápido e dirija com segurança para ganhar uma taxa extra de gorjeta.
*   **Ranking:** Um Top 50 global com os melhores taxistas. Estar no Top 3 concede Bônus (+XP/Dinheiro) por mérito.
*   **Dark / Light Mode:** Interface com cores dinâmicas e opção de alterar para modo claro ou escuro.

## 🛠 Dependências

*   [qbx_core](https://github.com/Qbox-project/qbx_core)
*   [ox_lib](https://github.com/overextended/ox_lib)
*   [ox_target](https://github.com/overextended/ox_target)
*   [mri_Qcarkeys](https://github.com/mri) *(Ou o seu sistema de chaves adaptado)*

## 📦 Instalação

1.  Faça o download e coloque a pasta `mri_Qtaxi` dentro do seu diretório de recursos (resources).
2.  Importe ou inicie o script uma vez. A tabela `mri_qtaxi_players` é **criada automaticamente** no seu banco de dados na primeira vez que o script for iniciado (`onResourceStart`).
3.  Adicione `ensure mri_Qtaxi` no seu `server.cfg`.

## ⚙️ Configuração (`config.lua`)

O sistema é altamente modular:
- Modifique `Config.TaxiStands` para adicionar ou alterar a posição dos pontos de táxi pela cidade.
- Edite `Config.TaxiBuyOptions` para modificar quais carros estão à venda, preços e imagens da interface.
- Personalize `Config.Calls` e `Config.Waypoints` para criar rotas e pontos de coleta/desembarque diferentes.
- A cor principal da UI pode ser customizada nas convars ou diretamente na invocação da Interface.

---

*Desenvolvido com o MRI UI Kit.*
