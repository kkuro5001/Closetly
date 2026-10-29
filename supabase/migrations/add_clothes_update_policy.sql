-- 既存の本番DBに服の更新(編集機能)用のRLSポリシーを追加する
create policy "服の更新"
on public.clothes
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
