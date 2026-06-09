# Network Scaffold

Update `api_config.dart` with your DNS/base URL and then point each route in `api_routes.dart` to your real backend paths.

Suggested flow:

1. `capture` or `session` receives the unified mobile/web input.
2. `vision` processes frame data.
3. `speech` processes audio.
4. `reasoning` combines previous outputs.
5. `recommendations` produces final app-facing results.