# Giro — controle de estoque para pequenos negócios

Aplicativo de estoque **offline**, feito em **Flutter** para **Windows e Android**. O mesmo código roda no balcão do mercado e no celular de quem faz a conferência no depósito.

O diferencial: o núcleo é único e o **segmento** escolhido no primeiro uso configura o que o negócio precisa. Mercado, padaria, distribuidora de bebidas e logística usam o mesmo app, sem telas duplicadas.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-local-003B57?logo=sqlite&logoColor=white)
![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-green)
![Android APK](https://github.com/almeida-joaomarcos/giro-estoque/actions/workflows/android.yml/badge.svg)

---

## 📲 Baixar e instalar (Android)

A versão mais recente está em **[Releases](https://github.com/almeida-joaomarcos/giro-estoque/releases/latest)**.

1. Baixe o `app-release.apk`.
2. Autorize a instalação de fontes desconhecidas quando o Android pedir.
3. Se o Play Protect avisar, escolha "instalar mesmo assim" — o APK é assinado com chave de desenvolvimento.

Requisitos: Android 7.0 ou superior. Funciona 100% offline.

---

## Por que ele existe

Sistemas de estoque costumam ser caros, cheios de recursos que o pequeno comércio não usa e dependentes de internet. O Giro faz o básico muito bem:

- funciona **sem internet**;
- os dados ficam no dispositivo (SQLite);
- **saldo calculado pelas movimentações**, nunca digitado à mão — o que evita o estoque "mágico" que não fecha;
- serve para **qualquer ramo**, porque lote, validade e múltiplos locais são opcionais.

## Funcionalidades

- **Onboarding por segmento**: mercado, padaria, bebidas ou logística — já cria unidades, categorias e recursos do ramo.
- **Produtos** com SKU, código de barras, categoria, unidade, custo, preço e estoque mínimo.
- **Movimentações**: entrada, saída, perda, ajuste de inventário e transferência entre locais.
- **Saldo por produto** e alerta de estoque baixo/zerado.
- **Painel** com valor em estoque, itens em alerta e movimentos do dia.
- **Relatórios** de valor por categoria, produtos de maior valor e itens a repor.
- **Histórico** por produto, com motivo, local e data.
- **CSV**: exportação do estoque e importação de planilha.
- **Backup e restauração** do banco em um clique.
- **Layout adaptativo**: navegação lateral no desktop, barra inferior no celular.

## Como o "qualquer ramo" funciona

O app não tem uma tela por segmento. Tem **capacidades ligáveis**:

| Segmento | Lote | Validade | Múltiplos locais |
| --- | --- | --- | --- |
| Mercado | — | ✅ | — |
| Padaria | ✅ | ✅ | — |
| Bebidas | ✅ | ✅ | ✅ |
| Logística | ✅ | — | ✅ |

Trocar o segmento nos Ajustes reconfigura esses recursos sem apagar produtos ou histórico.

## Arquitetura

```
lib/
├── main.dart                 # inicializa banco e controller
├── app.dart                  # MaterialApp + onboarding/shell
├── core/
│   ├── db/app_database.dart  # SQLite (sqflite + FFI no desktop)
│   ├── theme/app_theme.dart  # Material 3
│   └── utils/                # formatadores, dados de exemplo
├── domain/models/            # Product, StockMovement, Segment, ...
├── data/
│   └── inventory_repository.dart  # todo o SQL fica aqui
├── state/
│   └── inventory_controller.dart  # ChangeNotifier + regras
└── features/
    ├── onboarding/
    ├── shell/
    ├── dashboard/
    ├── products/
    ├── movements/
    ├── reports/
    └── settings/
```

Decisões que valem citar em entrevista:

1. **Saldo derivado.** A tabela `products` não guarda quantidade. O saldo é `SUM` das movimentações — impossível divergir do histórico.
2. **Transferência como duas linhas.** Saída na origem e entrada no destino, o que mantém o saldo por local correto e auditável.
3. **Ajuste como delta.** O usuário informa a quantidade contada; o app calcula a diferença e grava só o delta.
4. **Repositório único.** Nenhum widget escreve SQL. Isso permitiu testar as regras com banco em memória.
5. **SQLite com `sqflite_common_ffi`** no Windows e plugin nativo no Android — mesmo código de acesso.

## Como rodar

Pré-requisitos:

- Flutter 3.24 ou superior
- Android Studio + SDK (para Android)
- Visual Studio Build Tools com C++ (para Windows)

```bash
git clone https://github.com/almeida-joaomarcos/giro-estoque.git
cd giro-estoque
flutter pub get
flutter run -d windows   # ou: flutter run -d android
```

### Testes

```bash
flutter test
```

Os testes cobrem o cálculo de saldo, transferências, busca, configuração, formatação e as regras de sinal das movimentações.

### Build

```bash
flutter build windows --release
flutter build apk --release
```

## Banco de dados

```sql
business_config (id, business_name, segment, currency, tracks_batch,
                 tracks_expiry, multi_location, created_at)
locations       (id, name, is_default)
products        (id, name, sku, barcode, category, unit, cost_price,
                 sale_price, min_stock, active, created_at, updated_at)
movements       (id, product_id, type, quantity, unit_cost, location_id,
                 target_location_id, reason, note, batch_code,
                 expiry_date, created_at)
```

## Roadmap

- [x] MVP desktop + mobile com SQLite local
- [x] Onboarding por segmento
- [x] Movimentações, saldo, relatórios e CSV
- [ ] Leitor de código de barras pela câmera
- [ ] Lote e validade na interface (o banco já suporta)
- [ ] Multiusuário com API em Java/Spring Boot + PostgreSQL
- [ ] Sincronização offline-first
- [ ] Instalador Windows assinado e publicação na Play Store

## Status

Projeto em desenvolvimento ativo, criado como portfólio e como produto para pequenos comércios. A versão atual é a base funcional do MVP.

## Licença

MIT — veja [LICENSE](LICENSE).
