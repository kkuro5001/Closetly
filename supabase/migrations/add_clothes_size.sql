-- 服のサイズ(任意項目)を追加する。
-- 服の種類によって表記が違う(S/M/L、靴の25.5、パンツのW30など)ため自由入力のtextにし、
-- 既存の行はサイズ未設定(null)のままにする。
-- RLSは既存の行単位ポリシー(服の取得/追加/更新/削除)がそのまま適用されるので追加不要。
alter table public.clothes add column if not exists size text;
