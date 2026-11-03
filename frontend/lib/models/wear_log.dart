// 着用記録(Supabase の wear_logs テーブル 1行 = ある服をある日に着た記録)
class WearLog {

  final int clothingId;

  // 着た日(時刻は使わない。端末のローカル日付)
  final DateTime wornOn;

  WearLog({
    required this.clothingId,
    required DateTime wornOn,
  }) : wornOn = dateOnly(wornOn);

  factory WearLog.fromMap(Map<String, dynamic> map) {
    return WearLog(
      clothingId: map['clothing_id'],
      wornOn: DateTime.parse(map['worn_on']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clothing_id': clothingId,
      'worn_on': dateKey(wornOn),
    };
  }
}

/// 時刻を切り捨てた日付(ローカル)
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Postgres の date 型に送る 'yyyy-MM-dd'
String dateKey(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
