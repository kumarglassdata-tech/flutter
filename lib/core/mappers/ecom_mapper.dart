import '../domain/ecom_result.dart';
import '../dtos/ecom_dto.dart';

class EcomMapper {
  static EcomResult fromDto(EcomResponseDto dto) {
    return EcomResult(
      productUrl: dto.productUrl ?? '',
      price: dto.price ?? '',
    );
  }
}
