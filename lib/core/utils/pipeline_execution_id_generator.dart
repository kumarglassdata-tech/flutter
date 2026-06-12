import 'dart:math';

class PipelineExecutionIdGenerator {
  static String generate() {
    final now = DateTime.now().toUtc();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final randomHash = String.fromCharCodes(Iterable.generate(
      4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));

    return 'run_${dateStr}_${timeStr}_$randomHash';
  }
}
