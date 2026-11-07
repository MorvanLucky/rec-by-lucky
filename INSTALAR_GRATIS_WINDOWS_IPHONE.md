# Instalar Rec by Lucky sem pagar — Windows + iPhone 15 Pro Max

Você já tem GitHub e uma conta Apple comum. **Não assine Apple Developer** nem contrate APIs para esta edição.

## A. Produzir o IPA gratuitamente no GitHub
1. No Windows, extraia o ZIP em uma pasta `Morvan`.
2. Instale o [GitHub Desktop](https://desktop.github.com/) ou o [Git para Windows](https://git-scm.com/downloads/win).
3. Crie um repositório Git a partir da pasta do projeto e publique no GitHub como **PÚBLICO**. A pasta `.github/workflows` deve estar presente. Você está publicando **código-fonte**, não suas gravações.
   - No GitHub Desktop: File → Add local repository (ou Create repository se não houver `.git`), depois Publish repository; desmarque `Keep this code private`.
4. Abra o repositório na Web → **Actions** → **Gerar IPA gratuito - Morvan** → **Run workflow**.
5. Ao terminar **com sucesso**, abra a execução, desça até **Artifacts**, baixe `Morvan-IPA-para-AltStore` e extraia o ZIP de artefato. Dentro está `Morvan-gratis-unsigned.ipa`.
6. Se o workflow falhar, abra os logs da etapa vermelha. **Não considere a instalação concluída** até que o build e o teste sejam aprovados.

GitHub Actions usa executores macOS padrão, gratuitos em repositórios públicos, sujeitos às políticas/limites de uso da plataforma. Repositórios privados têm cotas e possível cobrança; evite-os se a condição for custo zero.

## B. Instalar o IPA gratuitamente a partir do Windows
1. Baixe **AltStore Classic / AltServer** do site oficial: https://altstore.io/ .
2. Siga o guia do projeto AltStore para Windows: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows . Instale os componentes Apple para Windows recomendados pelo AltStore.
3. Conecte o iPhone desbloqueado por cabo, selecione **Confiar neste computador** e use o AltServer para instalar o **AltStore Classic** no aparelho.
4. No iPhone, ative **Modo de Desenvolvedor** quando solicitado: Ajustes → Privacidade e Segurança → Modo de Desenvolvedor. Siga as instruções de reinício. Autorize o perfil da sua conta Apple se necessário (Ajustes → Geral → VPN e Gerenciamento de Dispositivos).
5. Copie `Morvan-gratis-unsigned.ipa` para o iPhone (pelo Arquivos/iCloud Drive ou cabo) e abra pelo AltStore Classic (**My Apps → +**, selecione o `.ipa`). O AltStore assina e instala usando sua própria conta Apple.
6. Abra **Morvan**, permita Face ID e, no primeiro reconhecimento de fala, autorize Reconhecimento de Fala.

**É obrigatório renovar pelo AltStore/AltServer a assinatura a cada 7 dias.** Com seu Windows na mesma rede/USB, abra AltServer e use Refresh All antes de expirar. O limite da Apple ID gratuita é de até três apps de desenvolvimento ativos por aparelho; AltStore ocupa uma vaga.

## C. Verificar transcrição gratuita
1. Grave um M4A curto de teste (com autorização).
2. Importe em Morvan → escolha origem, contato, telefone e data.
3. Confirme **Guardar áudio** desligado e toque em **Transcrever offline e salvar**.
4. Se aparecer aviso de pt-BR offline indisponível: não haverá envio externo; você pode colar/digitar o texto manualmente.
5. Abra a conversa, edite/busque/exclua áudio/exporte TXT. Para resumo, use iOS 26+ e Apple Intelligence habilitada.

## O que não existe
- Nenhuma chave OpenAI, conta Apple Developer paga, hospedagem ou backend para configurar.
- Nenhum acesso automático às chamadas WhatsApp/Meet/Telefone.
- Nenhuma garantia de que uma gravação de tela inclua áudio de chamada.
- Nenhum IPA já compilado ou instalado: o IPA será gerado após **você executar o workflow** no seu GitHub.

**Segurança:** nunca publique senhas, gravações ou dados pessoais no repositório; não mande sua senha Apple para terceiros.
