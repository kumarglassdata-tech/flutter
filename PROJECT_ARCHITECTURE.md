# SmartGlass AI Companionship: Flutter Architecture & Developer Guide

This document provides a detailed architectural breakdown of the **SmartGlass Myna companion Flutter application**. Following clean design and senior engineering guidelines, the app is organized using a **Feature-First + Core Split** structure, separating shared infrastructural components from presentation layers.

---

## 1. Directory Structure

The `smartglass_flutter` project is organized as follows:

```
lib/
├── main.dart                  # App bootstrap, Provider initialization, and system bindings
├── core/                      # Shared infrastructure layer (independent of specific UI screens)
│   ├── config/                # Environment variables, defaults, and port configurations
│   ├── theme/                 # AppTheme class defining HSL color tokens, typography, and styling
│   ├── navigation/            # GoRouter configurations and navigation helper routines
│   ├── network/               # Standard HTTP client wrapper, route mappings, and interceptors
│   ├── models/                # Globally used schemas (UnifiedInput, EngineStatus, SessionState)
│   ├── providers/             # Global app state (SettingsProvider, AuthProvider, SessionProvider)
│   ├── services/              # Core device sensor wrappers (Camera, Audio, Location, MetaSDK)
│   ├── sources/               # Ingestion adapters to direct sensor feeds into the system
│   └── orchestrator/          # Pipeline coordinator sequencing execution of the 5 engines
└── features/                  # Presentation layers grouped by feature modules
    ├── auth/                  # Login and register pages
    ├── dashboard/             # FOP Control Dashboard and Meta Stream tabs
    │   ├── dashboard_screen.dart # Main screen holding TabController & TabBarView structure
    │   └── widgets/           # Extracted package-private components (modularized)
    ├── devices/               # BLE and Meta Smart Glasses pairing screen
    ├── diagnostics/           # Diagnostics and latency checks
    ├── engine_inspector/      # Structured JSON schema request/response visualizer
    ├── interested/            # Dedicated list for marked or focused products of interest
    ├── orders/                # E-commerce cart and completed order tracking list
    ├── profile/               # User profile screen
    └── settings/              # API URL configurations and toggles
```

---

## 2. Senior Architectural Design Patterns

### 1. Ingestion Sources (Adapter Pattern)
The app reads input streams from multiple physical contexts (Meta glasses SDK, Phone sensors, Laptop webcam, Video files, or Mocks). 
* **Abstractions**: `SourceAdapter` exposes three streams: `videoStream` (`VideoFrame`), `audioStream` (`AudioChunk`), and `locationStream` (`LocationData`).
* **Implementations**:
  * `MetaSourceAdapter`: Ingests inputs via native channel platform bridges from the Meta SDK.
  * `PhoneSourceAdapter`: Accesses the mobile device's camera, microphone, and GPS.
  * `LaptopSourceAdapter`: Reads browser/desktop hardware inputs.
  * `VideoUploadSourceAdapter`: Extracts video frames and audio chunks from a user-uploaded MP4 or JPEG.
  * `MockSourceAdapter`: Yields simulated looping test frames.
* **Controller**: `SourceManager` coordinates switching between these active adapters dynamically at runtime.

### 2. Pipeline / Command Pattern (Orchestrator)
Running a 5-stage inference pipeline involves multiple network endpoints that must execute sequentially, sharing state along the way.
* **Abstractions**: `PipelineStep` defines the execution contract: `Future<StepResult<T>> execute(I input, Map<String, dynamic> sharedState)`.
* **Implementations**:
  * `ContextEngineStep` (POST `/predict` on port `8501`)
  * `BehaviourIntentStep` (POST `/behavior` on port `8502`)
  * `GateCheckStep` (Local rule-based gate routing)
  * `InteractionSubsystemStep` (POST `/process` on port `8001`)
  * `EcomAdStep` (POST `/query` on port `5000`)
  * `SafetyMemoryStep` (POST `/store` / `/recall` on port `8505`)
* **Coordinator**: `PipelineCoordinator` chain-executes each step, records telemetry latency, sets status logs, and halts execution immediately if a critical network component fails.

### 3. Presentation Decoupling
To maintain single-responsibility principles, large complex dashboards are broken down into dedicated feature folders:
* Screen controllers are kept lightweight (e.g. `dashboard_screen.dart` serves as a routing and layout orchestrator).
* Leaf widgets are isolated inside `widgets/` folders (e.g., `ControlPanel`, `CameraPreviewCard`, `MetaStreamTab`, `ApiConnectivityPanel`) to make testing and hot-reload performant.

---

## 3. Resilience and Fault Tolerance

The client classes implement a three-tier resilience strategy:
1. **Exponential Backoff & Retry**: Failsafe attempts with backoff policies.
2. **Circuit Breaker Pattern**: Disconnects offline engines to avoid pipeline stalls.
3. **Graceful Mock Fallbacks**: Provides mock schemas if an engine is offline and `fallbackToMock` is enabled.
