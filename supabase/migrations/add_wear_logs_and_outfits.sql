-- 着用記録(wear_logs)とコーディネート(outfits / outfit_items)を追加する
-- Supabase の SQL Editor でこのファイルをそのまま実行する

-- ========== 着用記録 ==========
-- 1行 = ある服をある日に着た記録。同じ服を同じ日に2回は記録しない
create table public.wear_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  clothing_id bigint not null references public.clothes (id) on delete cascade,
  -- DBの current_date は UTC なので、日付はアプリ側(端末の日付)から送る
  worn_on date not null,
  created_at timestamptz not null default now(),
  unique (clothing_id, worn_on)
);

create index wear_logs_user_id_idx on public.wear_logs (user_id);

alter table public.wear_logs enable row level security;

create policy "着用記録の取得"
on public.wear_logs
for select
to authenticated
using (user_id = auth.uid());

-- 自分の服にだけ記録できる
create policy "着用記録の追加"
on public.wear_logs
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.clothes c
    where c.id = clothing_id and c.user_id = auth.uid()
  )
);

create policy "着用記録の削除"
on public.wear_logs
for delete
to authenticated
using (user_id = auth.uid());

-- ========== コーディネート ==========
create table public.outfits (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  -- AIの提案理由など(手動作成では空でよい)
  note text not null default '',
  created_at timestamptz not null default now()
);

alter table public.outfits enable row level security;

create policy "コーデの取得"
on public.outfits
for select
to authenticated
using (user_id = auth.uid());

create policy "コーデの追加"
on public.outfits
for insert
to authenticated
with check (user_id = auth.uid());

create policy "コーデの削除"
on public.outfits
for delete
to authenticated
using (user_id = auth.uid());

-- コーデに含まれる服(服やコーデを消すと自動で消える)
create table public.outfit_items (
  outfit_id bigint not null references public.outfits (id) on delete cascade,
  clothing_id bigint not null references public.clothes (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  primary key (outfit_id, clothing_id)
);

create index outfit_items_clothing_id_idx on public.outfit_items (clothing_id);

alter table public.outfit_items enable row level security;

create policy "コーデの服の取得"
on public.outfit_items
for select
to authenticated
using (user_id = auth.uid());

-- 自分のコーデに自分の服だけを入れられる
create policy "コーデの服の追加"
on public.outfit_items
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.outfits o
    where o.id = outfit_id and o.user_id = auth.uid()
  )
  and exists (
    select 1 from public.clothes c
    where c.id = clothing_id and c.user_id = auth.uid()
  )
);

create policy "コーデの服の削除"
on public.outfit_items
for delete
to authenticated
using (user_id = auth.uid());
