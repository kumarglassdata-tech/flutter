import 'dart:async';

class PipelineResult<T> {
  final bool isSuccess;
  final T? output;
  final String? errorMessage;

  const PipelineResult.success(this.output)
      : isSuccess = true,
        errorMessage = null;

  const PipelineResult.failure(this.errorMessage)
      : isSuccess = false,
        output = null;
}

abstract class PipelineStep<TInput, TOutput> {
  final String name;

  const PipelineStep(this.name);

  Future<PipelineResult<TOutput>> execute(
    TInput input,
    Map<String, dynamic> sharedState,
  );
}
