<h1 align="center">
  <br>
  🏡 Aluguel Sítio Tureba
  <br>
</h1>

<p align="center">
  Aplicativo Android para gerenciamento de reservas e controle financeiro do sítio.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
</p>

---

## 📱 Sobre o projeto

O **Aluguel Sítio** é um app mobile desenvolvido para facilitar o controle de reservas de um sítio para aluguel. Com ele é possível cadastrar locatários, acompanhar o calendário de ocupação, controlar pagamentos e visualizar um resumo financeiro por período.

---

## ✨ Funcionalidades

- 📅 **Calendário visual** com dias ocupados destacados em vermelho
- ✅ **Status em tempo real** — exibe se o sítio está disponível ou ocupado hoje
- ➕ **Cadastro de reservas** com nome, telefone, e-mail, datas e valor
- 💰 **Controle de pagamento** — pagamento pendente, entrada paga ou pago total
- 🔍 **Busca por nome** do locatário
- 📆 **Filtro por mês e ano** nas listagens
- 📊 **Resumo financeiro** com total recebido, a receber e quantidade de reservas
- ✏️ **Edição e exclusão** de reservas com confirmação
- 📞 **Atalho para ligar** diretamente para o locatário

---

## 🛠️ Tecnologias

| Tecnologia | Uso |
|---|---|
| [Flutter](https://flutter.dev) | Framework principal |
| [Firebase Firestore](https://firebase.google.com/products/firestore) | Banco de dados em nuvem em tempo real |
| [table_calendar](https://pub.dev/packages/table_calendar) | Calendário interativo |
| [intl](https://pub.dev/packages/intl) | Formatação de datas e valores monetários |
| [url_launcher](https://pub.dev/packages/url_launcher) | Atalho para o discador telefônico |

---

## 🚀 Como executar

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado
- Conta no [Firebase](https://firebase.google.com) com projeto configurado
- Android Studio ou VS Code

### Passo a passo

```bash
# Clone o repositório
git clone https://github.com/Victorlqz12/ProjetoReservas.git

# Entre na pasta do projeto
cd ProjetoReservas

# Instale as dependências
flutter pub get

# Execute o app
flutter run
```

> ⚠️ **Atenção:** É necessário adicionar o arquivo `google-services.json` na pasta `android/app/` com as credenciais do seu projeto Firebase. Este arquivo não está incluso no repositório por segurança.

---

## 🔒 Segurança

- `google-services.json` está no `.gitignore` e **nunca** é enviado ao repositório
- As regras do Firestore exigem autenticação para leitura e escrita
- Chaves de API restritas via Google Cloud Console

---

## 📂 Estrutura do projeto

```
lib/
├── main.dart                       # Inicialização do app e Firebase
├── models/
│   └── reserva.dart                # Modelo de dados da reserva
├── services/
│   └── firestore_service.dart      # Comunicação com o Firestore
└── screens/
    ├── home_screen.dart             # Tela principal com calendário e listagens
    ├── form_reserva_screen.dart     # Formulário de criação/edição
    └── detalhe_reserva_screen.dart  # Detalhes da reserva
```

---

## 👨‍💻 Autor

Feito por **Victor** — [github.com/Victorlqz12](https://github.com/Victorlqz12)
