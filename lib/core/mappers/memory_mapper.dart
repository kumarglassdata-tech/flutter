import '../domain/memory_result.dart';
import '../dtos/memory_dto.dart';

class MemoryMapper {
  static MemoryResult fromDto(MemoryResponseDto dto) {
    return MemoryResult(
      memoryId: dto.memoryId ?? '',
      status: dto.status ?? 'unknown',
      summary: dto.summary ?? '',
    );
  }
}
