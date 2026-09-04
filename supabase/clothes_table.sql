-- 服のメタデータ（カテゴリ・色・季節・画像パス）をSupabaseで管理するテーブル
create table public.clothes (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  image_path text not null,
  category text not null,
  color text not null,
  season text not null,
  created_at timestamptz not null default now()
);

alter table public.clothes enable row level security;

create policy "服の取得"
on public.clothes
for select
to authenticated
using (user_id = auth.uid());

create policy "服の追加"
on public.clothes
for insert
to authenticated
with check (user_id = auth.uid());
