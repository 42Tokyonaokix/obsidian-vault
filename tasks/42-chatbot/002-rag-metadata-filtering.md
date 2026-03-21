---
title: "RAG メタデータフィルタリング: ユーザー契約情報に基づく検索結果の絞り込み"
date: 2026-03-21
project: 42-chatbot
status: todo
progress: 0/7
priority: high
tags: [rag, metadata, filtering, contract]
---

## 概要

現状のRAGはユーザーが誰であるかに関わらず同じ検索結果を返す。しかし実際にはユーザーごとに契約している約款が異なり（低圧/高圧/特別高圧、地域別託送約款など）、関係のない約款の情報が返されると混乱や誤解を招く。

本タスクでは、ユーザーの契約情報（DGM API の `ContractInfo.plan_type`）から電圧種別を導出し、RAG検索時にチャンクの `metadata.voltage_type` でフィルタリングすることで、そのユーザーの契約に適した約款・文書だけを優先的に返せるようにする。既存の `voltage_filter`（クエリテキストから電圧種別を推測する方式）を、契約情報ベースに拡張する形で実装する。加えて、地域託送約款についても `metadata.area` でフィルタリングし、ユーザーの契約地域に適した託送約款のみを返す。地域情報が API から取得できない場合は、チャット UI 上でユーザーに地域を選択してもらうフォールバックを設ける。

### 背景・前提

- チャンクの YAML メタデータには既に `voltage_type`（低圧/高圧特別高圧）と `area`（地域託送約款）が付与済み → チャンク側の準備は完了
- `ContractInfo` モデルには `voltage_type` フィールドが存在しない → `plan_type` からのマッピングロジックが必要
- 既存の `voltage_filter` はクエリテキストからの regex 推測で動作 → 契約情報がある場合はそちらを優先すべき
- 現在の本番検索戦略は `AdvancedRAGStrategy` と推定 → まずはこの戦略のみに実装（YAGNI）
- `SingleReactOrchestrator` はコンストラクタでツールを生成・グラフをコンパイル済み → リクエストごとの `tenant_id` をツールに渡す設計が鍵

## タスク

- [ ] ST-1: plan_type → voltage_type マッピング関数の実装
- [ ] ST-2: AdvancedRAGStrategy の SQL にメタデータフィルタ条件を追加
- [ ] ST-3: knowledge_search ツールへの契約コンテキスト注入
- [ ] ST-4: 既存 voltage_filter との統合
- [ ] ST-5: area フィルタの追加（託送約款対応）— 必須
- [ ] ST-5b: area 未取得時の UI 地域選択フォールバック
- [ ] ST-6: 統合テストとフィルタリングログ記録

---

## サブタスク詳細

### ST-1: plan_type → voltage_type マッピング関数の実装

**意図**: DGM API が返す `ContractInfo` には `plan_type: str` しかなく、RAG チャンクのメタデータで使われている `voltage_type`（低圧/高圧/特別高圧/高圧特別高圧）との対応関係が定義されていない。この変換ロジックがなければ、契約情報を取得しても検索フィルタに活用できない。全体の基盤となるサブタスク。

**詳細**:
- DGM API の実レスポンスを確認し、`plan_type` が取りうる値の一覧を把握する
- `plan_type` の各値を `voltage_type`（低圧/高圧/特別高圧/高圧特別高圧）にマッピングする関数を作成
- マッピングテーブルは定数辞書として管理し、将来のプラン追加に備えて可読性を確保
- 未知の `plan_type` が来た場合は `None` を返す（フィルタなしにフォールバック）
- 単体テスト必須: 全既知 plan_type のマッピング + 未知値の None 返却

**対象ファイル**: `src/app/services/dgm_api/` 配下に新モジュール追加

**依存**: なし（最初に着手可能）

---

### ST-2: AdvancedRAGStrategy の SQL にメタデータフィルタ条件を追加

**意図**: 現在の `AdvancedRAGStrategy` は検索時にすべての APPROVED チャンクを対象にベクトル検索を行っている。ここに `metadata->>'voltage_type' = :vt` のような WHERE 条件を動的に追加することで、契約に無関係なチャンクを検索段階で除外し、検索精度とパフォーマンスの両方を改善する。

**詳細**:
- `advanced/strategy.py` 内の3つの検索パス（vector search / proposition search / keyword search）それぞれの SQL に、`metadata_filter` が渡された場合のみ WHERE 条件を追加する動的 SQL 構築
- **SQLインジェクション対策**: 必ずパラメータバインド（`:voltage_type`）を使用し、文字列結合による直接埋め込みは禁止
- `metadata_filter` が `None` の場合は既存動作を完全維持（後方互換性）
- フィルタ方式は**ハード除外**（WHERE句）を採用。検索後ソートではなく、検索対象自体を絞る。理由: 約款が異なるユーザーに他契約の情報が返ることは「優先度が低い」のではなく「返すべきでない」ため
- ただし `doc_type` が `general`（一般知識）のチャンクはフィルタ対象外とする（全ユーザー共通の情報は除外しない）

**対象ファイル**: `src/app/services/retrieval/advanced/strategy.py`

**依存**: ST-1（マッピング関数の型定義を参照）

---

### ST-3: knowledge_search ツールへの契約コンテキスト注入

**意図**: ST-1 でマッピング関数を、ST-2 で SQL フィルタを作っても、それらを繋ぐ「配線」がなければ動かない。ユーザーのリクエストから `tenant_id` を取得し、DGM API で契約情報を引き、voltage_type に変換し、retrieve() に渡すまでのパイプラインをここで構築する。

**設計方針: RunnableConfig 方式（選択肢B）を採用する理由**:
- `SingleReactOrchestrator` はコンストラクタ時にツールを生成しグラフをコンパイルする（app.state に1インスタンス）
- `tenant_id` はリクエストごとに異なる
- 選択肢A（ツール引数に tenant_id）: LLM が tenant_id を推測・改ざんするリスクがある
- 選択肢C（ツール再生成）: グラフ再コンパイルのコストが高い
- **選択肢B（RunnableConfig）**: LangGraph の `config["configurable"]` に `tenant_id` を格納し、ツール内で `get_config()` で取り出す。LLM に tenant_id を露出せず、改ざん不可能で最も安全

**詳細**:
- `single_react.py` の `astream()` で `config["configurable"]["tenant_id"] = tenant_id` を追加（1行変更）
- `knowledge_search.py` のクロージャ内で:
  1. `RunnableConfig` から `tenant_id` を取得
  2. `DGMApiCache` 経由で `ContractInfo` を取得（Redis キャッシュ活用、レイテンシは最小限）
  3. ST-1 のマッピング関数で `voltage_type` を導出
  4. `retrieve(query, metadata_filter={"voltage_type": vt})` に渡す
- `create_knowledge_search_tool()` に `dgm_client` / `dgm_cache` の依存注入を追加
- **フォールバック**: DGM API エラー / Circuit Open / キャッシュミス時は `metadata_filter=None` で検索続行。エラーにはしない。ログに `contract_filter_skipped=True, reason=...` を記録

**対象ファイル**: `src/app/services/agent/tools/knowledge_search.py`, `src/app/services/agent/single_react.py`

**依存**: ST-1, ST-2

---

### ST-4: 既存 voltage_filter との統合

**意図**: 現在の `AdvancedRAGStrategy` には Step 7 として `filter_by_voltage_type()` が存在し、クエリテキストから regex で電圧種別を推測してチャンクをソートしている。ST-2 で契約ベースのハード除外フィルタを追加した後、この既存フィルタと二重に適用すると意図しない挙動になる（既にハード除外した後にソートしても意味がない、あるいは矛盾する）。両者の優先関係を明確にする。

**詳細**:
- 契約情報から `voltage_type` が解決できた場合（`metadata_filter` が渡された場合）:
  - ST-2 の WHERE 句で既にハード除外済み → Step 7 の `detect_voltage_type()` + ソートはスキップ
- 契約情報が取得できなかった場合（フォールバック時）:
  - 既存の `detect_voltage_type()`（クエリベース推測）をそのまま適用 → 従来通りの動作
- 実装はシンプルなフラグ分岐:
  ```python
  if metadata_filter and "voltage_type" in metadata_filter:
      # 契約ベースフィルタ適用済み → クエリベースフィルタをスキップ
      pass
  else:
      # フォールバック: 従来のクエリベース voltage_filter を適用
      results = filter_by_voltage_type(results, query)
  ```

**対象ファイル**: `src/app/services/retrieval/advanced/strategy.py`（Step 7 付近）, `src/app/services/retrieval/advanced/filters/voltage_filter.py`

**依存**: ST-2

---

### ST-5: area フィルタの追加（託送約款対応）— 必須

**意図**: 電気需給約款だけでなく、地域託送約款も重要なナレッジソースである（北海道電力、東北電力、東京電力、中部電力、北陸電力、関西電力、中国電力、四国電力、九州電力、沖縄電力）。これらのチャンクには既に `metadata.area` が付与済み。ユーザーの契約地域に応じた託送約款だけを返すことで、他地域の無関係な料金体系や制度情報が混入することを防ぐ。voltage_type フィルタと並んで必須のフィルタリング項目。

**詳細**:
- DGM API のレスポンスに地域情報（`area` または `supply_point_id` から地域推定可能なフィールド）が含まれるか確認
- **含まれる場合**: ST-1 のマッピング関数に地域導出ロジックを追加し、`metadata_filter` に `{"voltage_type": vt, "area": area}` を渡す
- **含まれない場合**: ST-5b（UI 地域選択フォールバック）で対応する。スキップは不可
- フィルタの SQL パターンは ST-2 と同じ（`metadata->>'area' = :area`）
- area フィルタは `doc_type` が地域託送約款のチャンクにのみ適用。電気需給約款や general ドキュメントには影響しない
- area の値一覧（チャンクメタデータとの整合性を確認）:
  - 北海道電力、東北電力、東京電力、中部電力、北陸電力、関西電力、中国電力、四国電力、九州電力、沖縄電力

**対象ファイル**: ST-1, ST-2 と同じファイル群

**依存**: ST-1, ST-2

---

### ST-5b: area 未取得時の UI 地域選択フォールバック

**意図**: DGM API から地域情報が取得できない場合でも、地域託送約款のフィルタリングは必須要件である。ユーザーに地域を選択してもらうことで、API に依存せずに area フィルタを適用可能にする。初回選択後はセッションに保持し、毎回聞き直さない設計にする。

**詳細**:

**バックエンド側**:
- チャットセッション（`ConversationCache` または `session_metadata`）に `selected_area: str | None` フィールドを追加
- `knowledge_search` ツールの契約コンテキスト解決フロー（ST-3）を拡張:
  1. DGM API から area が取得できた → そのまま使用
  2. DGM API から取得できない + セッションに `selected_area` がある → セッション値を使用
  3. どちらもない → `area_selection_required: true` をレスポンスに含め、フロントにプロンプトを促す
- area 選択を受け付ける API エンドポイントまたはチャットメッセージハンドラを追加:
  - `POST /api/v1/chat/area` or チャットメッセージ内のメタデータとして受け取る
  - 受け取った area をセッションに保存

**フロントエンド側（widget）**:
- チャットウィジェットに地域選択 UI を追加
  - サーバーから `area_selection_required: true` を受け取った場合に表示
  - ドロップダウンまたはボタンリスト形式（10地域から1つ選択）
  - 選択肢: 北海道電力 / 東北電力 / 東京電力 / 中部電力 / 北陸電力 / 関西電力 / 中国電力 / 四国電力 / 九州電力 / 沖縄電力
- 選択後、area をサーバーに送信しセッションに保存
- 以降のチャットでは再選択不要（セッション中は保持）
- 設定変更したい場合のための「地域を変更」ボタンも用意（ヘッダーまたはサイドバー）

**UX フロー**:
```
ユーザーがチャット開始
  → 契約情報から area 取得を試みる
  → 取得できない場合、初回の knowledge_search 呼び出し時に:
    Bot: 「お住まいの地域を選択してください（託送約款の情報を正確にお伝えするために必要です）」
    [北海道] [東北] [東京] [中部] [北陸] [関西] [中国] [四国] [九州] [沖縄]
  → ユーザーが選択
  → セッションに保存、以降のチャットで area フィルタが自動適用
```

**対象ファイル**:
- バックエンド: `src/app/api/v1/chat.py`, `src/app/services/agent/tools/knowledge_search.py`, `src/app/memory/` or `src/app/services/cache/`
- フロントエンド: `widget/src/` 配下のチャットコンポーネント

**依存**: ST-5（area フィルタの SQL 実装が先）

---

### ST-6: 統合テストとフィルタリングログ記録

**意図**: メタデータフィルタリングのバグは「ユーザーに誤った約款情報を返す」という深刻な問題に直結する。契約ベースのフィルタが正しく動作すること、異常時に安全にフォールバックすることを、自動テストで保証する。また、本番でのフィルタ適用状況を可視化するためのログ記録を整備する。

**テストケース**:
- `plan_type → voltage_type` マッピングの網羅テスト（ST-1 の単体テスト拡張）
- 低圧契約ユーザーで検索した場合、結果に `voltage_type: 低圧` のチャンクのみ含まれること
- 高圧契約ユーザーで検索した場合、低圧チャンクが結果に含まれないこと
- `doc_type: general` のチャンクはフィルタに関わらず結果に含まれること
- DGM API エラー時にフォールバック（フィルタなし）で検索が正常完了すること
- `metadata_filter=None` で全戦略が従来通り動作すること（リグレッションテスト）
- 契約フィルタ適用時に既存 voltage_filter がスキップされること（ST-4 の検証）
- area フィルタ: 東京電力ユーザーに東京電力の託送約款のみ返ること
- area フィルタ: 託送約款以外のチャンク（電気需給約款、general）は area フィルタの影響を受けないこと
- area UI 選択: セッションに保存した area が後続の検索で正しく適用されること
- area UI 選択: DGM API から area 取得不可時に `area_selection_required` フラグが返ること

**ログ記録**:
- structlog で以下のフィールドを記録:
  - `contract_filter_applied: bool` — フィルタが適用されたか
  - `contract_filter_voltage_type: str | None` — 適用された voltage_type
  - `contract_filter_area: str | None` — 適用された area
  - `contract_filter_area_source: str | None` — area の取得元（"api" / "session" / None）
  - `contract_filter_skipped_reason: str | None` — スキップ理由（API エラー、未知 plan_type 等）
- 既存のリクエストログ（`src/app/core/logging.py`）に統合

**対象ファイル**: `tests/` 配下に新規テストファイル追加、`src/app/core/logging.py`

**依存**: ST-1〜ST-5b すべて完了後

---

## 依存関係グラフ

```
ST-1 (マッピング関数)
├──> ST-2 (SQL フィルタ) ──> ST-4 (voltage_filter 統合)
├──> ST-3 (コンテキスト注入) ← ST-2 も前提
└──> ST-5 (area フィルタ) ← ST-2 も前提
      └──> ST-5b (area UI 選択フォールバック) ← ST-3 も前提
すべて ──> ST-6 (テスト + ログ)
```

## 設計上の注意点

- **フィルタ対象は AdvancedRAGStrategy のみ**: 他の戦略（flat_vector, raptor, vkg, hybrid）への対応は需要確認後に別タスクで実施（YAGNI）
- **Protocol の `retrieve()` シグネチャは変更しない**: 戦略内部でフィルタを処理する方が破壊的変更を避けられる
- **ハード除外 vs ソフト優先**: 約款フィルタはハード除外（WHERE句）を採用。ユーザーの契約外の約款情報を返すことは誤解・トラブルの原因になるため
- **general ドキュメントは除外しない**: `doc_type: general` のチャンクはすべてのユーザーに共通して返す
