import '../domain/behavior_result.dart';
import '../dtos/behavior_dto.dart';

class BehaviorMapper {
  static BehaviorResult fromDto(BehaviorResponseDto dto) {
    return BehaviorResult(
      state: _parseState(dto.behavioralState),
      confidence: dto.stateConfidence ?? 0.0,
      relevanceScore: dto.relevanceScore ?? 0.0,
    );
  }

  static BehavioralState _parseState(String? stateStr) {
    if (stateStr == null) return BehavioralState.unknown;
    switch (stateStr.toLowerCase()) {
      case 'passive_observation':
      case 'passiveobservation':
      case 'passive_browsing':
      case 'passivebrowsing':
      case 'passive':
        return BehavioralState.passiveBrowsing;
      case 'product_interest':
      case 'productinterest':
        return BehavioralState.productInterest;
      case 'comparison':
        return BehavioralState.comparison;
      case 'purchase_consideration':
      case 'purchaseconsideration':
        return BehavioralState.purchaseConsideration;
      case 'assistance_seeking':
      case 'assistanceseeking':
        return BehavioralState.assistanceSeeking;
      default:
        return BehavioralState.unknown;
    }
  }
}
