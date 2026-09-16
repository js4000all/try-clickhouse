# ADR: ClickHouse + Auth Proxy 構成の採用可否

## Status

保留

## Context

マルチテナントの時系列データ基盤において、クライアントから任意クエリを受け付けつつ、認証結果に応じて参照可能な tenant を強制的に制限する必要がある。

また、検索結果には `metric` 等をキーとして可視化用属性を付与したい。可視化属性は将来的に追加・変更される可能性が高い。

候補の一つとして、ClickHouse の前段に Auth Proxy を配置し、認証結果を ClickHouse の query setting として渡す方式を試作した。

想定構成は以下。

```text
Client
  |
  | SQL + credential
  v
Auth Proxy
  |
  | credential -> tenant 解決
  | auth_tenant=<tenant> を付与
  v
ClickHouse
  |
  | Row Policy
  | enrichment
  v
telemetry data
```

Row Policy は以下の形とした。

```sql
CREATE ROW POLICY tenant_isolation
ON telemetry.meas
FOR SELECT
USING tenant = getSetting('auth_tenant')
TO query_proxy_user;
```

## Decision

ClickHouse + Auth Proxy 構成は現時点では採用せず、保留とする。

tenant isolation の実現方式としては非常に有望であり、技術的な成立性も確認できた。

一方、可視化属性を ClickHouse 側で enrichment する場合、属性構造が SQL schema に現れるため、属性追加時の migration を完全には避けられない。

スキーマがあることでクライアント側の実装が楽になるわけでもなく、
運用保守を簡素化するなら、可視化 metadata を migration なしで変更できる方が望ましいので、この点を解決できる方式との比較を継続する。

## Findings

Auth Proxy が認証結果に応じて `auth_tenant` を query setting として付与し、ClickHouse の Row Policy から `getSetting('auth_tenant')` を参照する方式は正常に動作した。

`auth_tenant=tenant-123` の場合、`tenant-123` のデータのみ参照できた。

クライアント SQL で別 tenant を明示的に指定しても Row Policy が追加条件として適用されるため、tenant 境界を越えることはできなかった。

また `auth_tenant` を指定しなかった場合は `UNKNOWN_SETTING` となり、クエリは失敗した。proxy の実装ミスによる tenant setting の付け忘れが fail-open にならない点は好ましい。

JOIN、subquery、VIEW を介した場合も `meas` に対する Row Policy は維持された。

このためアクセス制御については、

```text
認証             Auth Proxy
tenant境界       ClickHouse Row Policy
クエリ実行       ClickHouse
```

という責務分離が可能である。

## Enrichment Evaluation

可視化属性として、まず `metric -> display_name` の enrichment を試した。

通常テーブルとの JOIN、および VIEW による隠蔽は正常に動作した。

さらに、CSV を source とする ClickHouse Dictionary も試した。

```csv
metric,display_name
temperature,きおん
humidity,しつど
```

Dictionary lookup は正常に動作し、元ファイルを更新した後に、

```sql
SYSTEM RELOAD DICTIONARY telemetry.metric_dict;
```

を実行することで新しい内容を反映できた。

このため、CD 処理で属性ファイルを配置し、その後 Dictionary を reload する運用は可能である。

`file()` table function で CSV を直接 JOIN する方法も確認し、こちらはクエリごとに最新ファイルを参照することが分かった。

## Main Issue

Dictionary は属性 schema を DDL に定義する必要がある。

例えば、

```sql
CREATE DICTIONARY telemetry.metric_dict
(
    metric String,
    display_name String
)
```

という定義に対して、可視化属性を追加し、

```csv
metric,display_name,unit,color
```

とした場合、Dictionary の schema も変更する必要がある。

したがって、属性ファイルを変更するだけでは新しい属性を SQL の列として利用できない。

VIEW 側の変更は `*` の利用などで減らせる可能性があるが、Dictionary 自体の schema migration は避けられない。

JSON 1列に metadata を格納する案も検討したが、未知の JSON property を自動的に SQL 結果のトップレベル列へ展開することは難しい。

このため、

```text
metadata に属性追加
    ↓
DDL変更なし
    ↓
新しい属性が自動的に結果列として利用可能
```

という完全な schema-less enrichment は ClickHouse 単体では実現しにくい。

## Consequences

ClickHouse + Auth Proxy を採用した場合、以下の利点がある。

* tenant isolation を ClickHouse 自身に強制させられる
* proxy が SQL AST を解析・書換えする必要がない
* 任意 SQL を比較的そのまま許容できる
* Grafana 等の SQL client と直接接続しやすい
* JOIN、VIEW、Dictionary 等の ClickHouse 機能を利用できる
* tenant setting 欠落時に fail-closed となる

一方、以下の制約を受ける。

* enrichment の属性構造が schema-bound になる
* 可視化属性追加時に Dictionary 等の migration が必要になる
* metadata schema の変更と DB schema の変更が結び付く

## Alternatives

### Query API

Query API を内製し、認証・tenant 制約・enrichment を API 側で行う。

metadata を JSON や map として扱えば、属性追加時に DB migration を必要としない設計が可能である。

一方で、tenant 条件の強制やクエリ処理を API が担う必要があり、ClickHouse の Row Policy を利用する構成より責務が重くなる。

また Grafana 等から任意 SQL で直接接続する構成は取りにくい。

### ClickHouse Dictionary with JSON Metadata

Dictionary の値を固定の JSON 1列とし、その内部を schema-less にする。

Dictionary DDL の変更頻度は下げられるが、SQL client が個々の属性を通常の列として扱うには JSON extraction が必要となる。

今回求めている「属性追加だけで新しい結果列として自然に利用可能」という性質は満たさない。

## Notes from Prototype

試作では ClickHouse 25.8 を使用した。

検証ホストの CPU が古く AVX2 を持たないため、現行 26.x の公式 amd64 image は `Illegal instruction` で起動できなかった。

FILE source の Dictionary では相対パス指定に癖があり、

```text
/var/lib/clickhouse/user_files/dictionary/metric.csv
```

という絶対パス指定で正常動作した。

Docker 公式イメージの entrypoint が bind mount に対して `chown` を行うため、read-only mount を利用する際はコンテナを `clickhouse` ユーザー相当の UID/GID で起動する必要があった。

これらは採否を左右する主要因ではないが、実装時の注意事項として記録する。

## Revisit When

以下のいずれかが成立した場合、ClickHouse + Auth Proxy 案を再評価する。

* 可視化属性の schema migration を許容できる
* 可視化属性を固定 schema に整理できる
* JSON metadata のまま利用する方式がクライアント要件を満たす
* Query API を維持するコストが ClickHouse 側 migration のコストを上回る
