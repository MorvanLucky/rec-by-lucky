# Rec by Lucky — Transcrição de Conversas (edição gratuita, Windows + iPhone)

## Objetivo
Aplicativo SwiftUI para **iPhone 15 Pro Max**. Transcreve **depois da importação manual** de arquivos de áudio ou vídeo. Não intercepta chamadas ou videochamadas de WhatsApp, Meet ou Telefone.

### Custo: zero, com limitações reais
- **Sem** Apple Developer pago, OpenAI API, tokens, servidor, domínio ou assinatura.
- Instalação via **GitHub Actions público (executores padrão gratuitos) + AltStore Classic no Windows**.
- O app deve ser **renovado a cada 7 dias** com Apple ID gratuito; mantenha AltServer disponível.
- O GitHub só recebe o **código-fonte**. Não coloque gravações, contatos, senhas ou dados pessoais no repositório.
- Reconhecimento de fala usa `Speech` da Apple com `requiresOnDeviceRecognition=true` para **pt-BR**, somente quando `supportsOnDeviceRecognition=true`. Não existe fallback externo. A disponibilidade offline **não é garantida** em todas as versões/dispositivos. O app avisa quando indisponível e permite colar transcrição manual.
- Resumo, decisões e tarefas: `FoundationModels` no dispositivo, somente iOS 26+ com Apple Intelligence ativada e disponível, até 12.000 caracteres por solicitação. Se indisponível, informa sem cobrir custos.
- **Identificação automática de falantes não está disponível** nessa edição; não são inventadas identidades.

## Funcionalidades
- Importar M4A, MP3, WAV, CAF; vídeos MP4/MOV/M4V (faixa de áudio extraída localmente; nenhum quadro de vídeo é enviado a qualquer serviço).
- Áudio importado limitado a 100 MB; arquivos incompatíveis com o decodificador iOS exigem conversão prévia (por exemplo, alguns formatos WhatsApp/Opus).
- Contato, telefone, data/hora e origem editáveis.
- Editar texto, buscar conversas, exportar TXT.
- Opção **Guardar áudio junto da transcrição** vem **desativada**.
- Apagar somente áudio guardado ou conversa inteira.
- Ao falhar, áudio temporário fica disponível para tentar novamente ou descartar. Gravação original importada permanece intacta.
- Face ID ou código do aparelho para abrir; armazenamento com proteção de arquivos e fora dos backups automáticos do app.

## Instalar
Veja [INSTALAR_GRATIS_WINDOWS_IPHONE.md](INSTALAR_GRATIS_WINDOWS_IPHONE.md).

## Fluxo gratuito
```
Arquivo no iPhone (gravado com autorização)
  → importação manual no Morvan
  → conversão local do vídeo para áudio (quando necessário)
  → reconhecimento pt-BR exclusivamente offline (se disponível)
  → salvar transcrição localmente
  → excluir áudio temporário (padrão) OU guardar áudio para ouvir e excluir depois
```

## Compilação e validação
`.github/workflows/verificar.yml` compila o app e executa os XCTest no simulador usando GitHub Actions.
`.github/workflows/gerar-ipa-gratis.yml` cria `Morvan-gratis-unsigned.ipa`, para ser **assinado no Windows com AltStore/AltServer e sua Apple ID**.

**O IPA produzido no GitHub é não assinado. Não é possível instalá-lo diretamente clicando nele no iPhone.**
Não forneça Apple ID/senha, chaves ou tokens em conversas ou issues. Configure somente no programa oficial no seu Windows.

### Validação local sem macOS
```bash
python3 scripts/verificar_projeto.py
```
Verifica estrutura e sintaxe Swift (se `swiftc` presente). **Não substitui** compilar/testar usando SDK iOS.

## Privacidade / provedor externo
Esta edição **não envia gravações ou transcrições a provedores de transcrição externos**.
Portanto não há retenção por OpenAI no fluxo desta edição. Remover dados do app não
remove cópias que o usuário tenha em outros aplicativos ou no arquivo original.

## Compatibilidade
Projeto com deployment target iOS 17 (importação e armazenamento).
Recursos de Apple Intelligence exigem iOS 26+, iPhone compatível e modelos preparados.

Nome exibido: **Rec by Lucky**. Os nomes técnicos do projeto Xcode, scheme e IPA continuam `Morvan` para compatibilidade.
