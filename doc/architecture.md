# Architecture Diagram — flutter_umami_analytics

Hexagonal architecture (ports & adapters). Domain is pure Dart, no Flutter/HTTP/DB imports. Infrastructure depends inward (on ports), never the reverse. Queue has 3 selectable modes (`disabled`, `inMemory`, `persisted`); multi-instance isolation via `instanceName`; REST API client is opt-in via `enableApi`.

```mermaid
flowchart LR
  subgraph App["Application layer"]
    FA["FlutterUmamiAnalytics<br/>(public facade)"]
  end

  subgraph Dom["Domain layer (pure Dart)"]
    direction TB
    Models["Models<br/>UmamiPayload · UmamiIdentifyPayload · QueuedEvent<br/>DeviceInfoData · FlutterUmamiConfig · UmamiQueueConfig"]
    Ports["Ports<br/>UmamiCollector · HttpClientPort · UmamiQueue<br/>DeviceInfoPort · DeviceIdPort · UmamiApiPort"]
    Utils["Utils<br/>instance_suffix · json_helpers · safe_async"]
    Logger["UmamiLogger<br/>(logging policy)"]
  end

  subgraph Inf["Infrastructure layer"]
    direction TB
    Factory["createUmamiAnalytics()<br/>(factory)"]
    TC["TrackingCollector"]
    UNO["UmamiNavigatorObserver"]
    DHC["DefaultHttpClient"]
    EB["EndpointBuilder<br/>(/api/* path builder)"]
    HH["HttpHeaders<br/>(HttpHeaderNames · HttpStatus · HttpContentType<br/>buildBaseHeaders · composeAuthHeaders)"]
    QF["createQueue()<br/>(queue_factory)"]
    IMQ["InMemoryQueue"]
    PQ["PersistedQueue"]
    NQ["NoopQueue"]
    UAC["UmamiApiClient"]
    DDIS["DefaultDeviceInfoService"]
    DIdS["DefaultDeviceIdService"]
    UAS["UserAgentService"]
    PD["PlatformDetector<br/>(PlatformKind enum)"]
  end

  subgraph Ext["External"]
    HTTP["http.Client"]
    UUID["uuid"]
    DB[("sqflite DB")]
    SS[("flutter_secure_storage")]
    FLUT["flutter SDK<br/>(PlatformDispatcher · WidgetsBinding · kIsWeb)"]
    DIO["dart:io (Platform)"]
    SRV["Umami Server"]
  end

  Factory --> FA
  Factory --> TC
  Factory --> DHC
  Factory --> QF
  Factory --> UAC
  Factory --> DIdS
  Factory --> DDIS

  FA -->|uses| Ports

  TC -->|implements| UmamiCollector
  UNO -->|uses port| UmamiCollector
  DHC -->|implements| HttpClientPort
  QF -->|returns| UmamiQueue
  IMQ -->|implements| UmamiQueue
  PQ -->|implements| UmamiQueue
  NQ -->|implements| UmamiQueue
  DDIS -->|implements| DeviceInfoPort
  DIdS -->|implements| DeviceIdPort
  UAC -->|implements| UmamiApiPort

  TC --> EB
  TC --> UUID
  DHC --> HH
  DHC --> HTTP
  HH --> UAS
  UAS --> PD
  DDIS --> PD
  DDIS --> FLUT
  DIdS --> SS
  DIdS --> UUID
  UAC --> EB
  UAC --> HH
  UAC --> HTTP
  PQ --> DB
  PD --> DIO
  PD --> FLUT
  HTTP --> SRV
  UAC --> SRV

  TC -.logs.-> Logger
  DHC -.logs.-> Logger
  UAC -.logs.-> Logger
  PQ -.logs.-> Logger
  UNO -.logs.-> Logger
```

Note: every adapter that holds a `UmamiLogger?` may emit logs (`TC`, `DHC`, `UAC`, `PQ`, `DDIS`, `DIdS`, `UNO`, `factory`); only the noisiest edges are drawn.

## Ports & Adapters Detail

```mermaid
flowchart LR
  subgraph Ports["Domain ports"]
    CP["UmamiCollector"]
    QP["UmamiQueue"]
    HCP["HttpClientPort"]
    DIP["DeviceInfoPort"]
    DIdP["DeviceIdPort"]
    AP["UmamiApiPort"]
  end

  subgraph Adapters["Infrastructure adapters"]
    TC["TrackingCollector"]
    IMQ["InMemoryQueue"]
    PQ["PersistedQueue"]
    NQ["NoopQueue"]
    DHC["DefaultHttpClient"]
    DDIS["DefaultDeviceInfoService"]
    DIdS["DefaultDeviceIdService"]
    UAC["UmamiApiClient"]
    UNO["UmamiNavigatorObserver"]
  end

  TC -.implements.-> CP
  IMQ -.implements.-> QP
  PQ -.implements.-> QP
  NQ -.implements.-> QP
  DHC -.implements.-> HCP
  DDIS -.implements.-> DIP
  DIdS -.implements.-> DIdP
  UAC -.implements.-> AP

  TC -->|depends on| HCP
  TC -->|depends on| QP
  TC -->|depends on| DIP
  UNO -->|depends on| CP
```

`FlutterUmamiAnalytics` (facade) holds `UmamiCollector` and an optional `UmamiApiPort? apiClient`; it never touches HTTP or queue adapters directly.

## Tracking Flow

```mermaid
sequenceDiagram
  autonumber
  participant App as Flutter App
  participant Fac as createUmamiAnalytics
  participant FA as FlutterUmamiAnalytics
  participant TC as TrackingCollector
  participant DHC as DefaultHttpClient
  participant HH as HttpHeaders.buildBaseHeaders
  participant UAS as UserAgentService
  participant PD as PlatformDetector
  participant DIS as DefaultDeviceInfoService
  participant DIdS as DefaultDeviceIdService
  participant Q as UmamiQueue<br/>(inMemory/persisted/noop)
  participant UAC as UmamiApiClient
  participant SRV as Umami Server

  Note over App,SRV: Initialization
  App->>Fac: createUmamiAnalytics(config, ...)
  Fac->>DHC: DefaultHttpClient(client, logger, timeout)
  DHC->>HH: buildBaseHeaders()
  HH->>UAS: UserAgentService.defaultUserAgent
  UAS->>PD: PlatformDetector.detect()
  alt queue: parameter not provided
    Fac->>Q: createQueue(queueConfig, instanceName)
  else queue: parameter provided
    Fac->>Q: use injected UmamiQueue (caller-owned)
  end
  Fac->>TC: TrackingCollector(config, http, queue, ownsQueue, enqueueEnabled, flushPurgeTtl, deviceInfo)
  opt enableApi = true
    Fac->>UAC: UmamiApiClient(baseUrl, logger, client)
    opt apiUsername & apiPassword set
      UAC->>SRV: POST /api/auth/login
      alt login ok
        UAC->>UAC: store token, composeAuthHeaders()
      else login fails / throws
        UAC-->>Fac: null (graceful degradation)
      end
    end
  end
  opt recordFirstOpen = true
    Fac->>DIdS: deviceId ?? DefaultDeviceIdService(instanceName)
    DIdS->>SRV: read first-launch marker (secure storage)
    alt first launch
      Fac->>TC: trackEvent('first_open', url='/app/launch')
    end
  end
  Fac-->>App: FlutterUmamiAnalytics

  Note over App,SRV: trackPageView / trackEvent / identify
  App->>FA: trackPageView(url, title, ...)
  FA->>TC: trackPageView(...)
  TC->>DIS: gather() device info
  TC->>TC: build UmamiPayload (consume firstReferrer once)
  TC->>DHC: send(endpoint, body)
  DHC->>SRV: POST /api/send (UA, x-umami-cache?)
  alt HTTP 200
    SRV-->>DHC: 200 + x-umami-cache
    DHC-->>TC: true
    TC->>TC: _autoFlush() if queue.length > 0
    TC-->>FA: true
  else HTTP error / offline
    SRV-->>DHC: error / SocketException
    DHC-->>TC: false
    alt enqueueEnabled (policy: !disabled)
      TC->>Q: insert(jsonEncode(payload))
      Q-->>TC: ok (evict oldest if at capacity)
    end
    TC-->>FA: false (queued or dropped)
  end

  Note over App,TC: Automatic tracking (Navigator)
  App->>UNO: didPush / didReplace / didPop(route)
  UNO->>UNO: routeFilter? routeNameMapper?
  UNO->>TC: trackPageView(url: routeName)
```

## Flush Detail

`_doFlush()` is the heart of both manual `flush()` and `_autoFlush()` (re-entry guarded by `_flushing`):

```mermaid
sequenceDiagram
  autonumber
  participant TC as TrackingCollector
  participant Q as UmamiQueue
  participant DHC as DefaultHttpClient
  participant SRV as Umami Server

  opt flushPurgeTtl is set (policy: persisted eventTtl)
    TC->>Q: deleteExpired(flushPurgeTtl)
  end
  TC->>Q: getAll()
  Q-->>TC: List<QueuedEvent>
  par parallel per event
    TC->>DHC: send(endpoint, decodedPayload)
    DHC->>SRV: POST /api/send
    SRV-->>DHC: 200 / error
    DHC-->>TC: true / false
  end
  Note over TC: corrupt payload (decodedPayload == null)<br/>deleted immediately, no send
  loop only successful flushes
    TC->>Q: delete(event.id) (skip if id == null)
  end
```

`Future.wait` fans out sends in parallel; only events whose send returned `true` are deleted. Events with `decodedPayload == null` (undecodable JSON) are also deleted and skipped. Failed events remain in the queue for the next flush/restart.

## Queue State Machine

```mermaid
stateDiagram-v2
  [*] --> ConfigCheck: track*() called

  state "config.enabled?" as ConfigCheck
  ConfigCheck --> Disabled: false
  ConfigCheck --> SendTry: true

  Disabled --> StatusOk: return false (no-op)

  SendTry --> Success: HTTP 200<br/>store x-umami-cache
  SendTry --> Failure: HTTP != 200<br/>or SocketException<br/>or HttpException

  Failure --> CheckQueue: enqueueEnabled?
  CheckQueue --> StatusEnqueued: false → drop event
  CheckQueue --> QueueInsert: true (inMemory / persisted / custom)

  state "insert(payload)" as QueueInsert
  QueueInsert --> AtCapacity: size >= maxSize
  QueueInsert --> Saved: size < maxSize

  state "evictOldest()" as AtCapacity
  AtCapacity --> Saved: drop oldest, append new

  Saved --> AutoFlush: trigger flush
  Saved --> StatusEnqueued: return false

  Success --> AutoFlush: drain pending<br/>(length > 0)

  state "flush() / _autoFlush()" as AutoFlush
  state "analytics.flush()" as FlushManual
  AutoFlush --> PruneAndDrain
  FlushManual --> PruneAndDrain

  state "processQueue()" as PruneAndDrain
  PruneAndDrain --> PruneTtl: flushPurgeTtl set? deleteExpired(flushPurgeTtl)
  PruneTtl --> Iterate: getAll()
  PruneAndDrain --> Iterate: getAll()
  Iterate --> ParallelSend: Future.wait over events
  ParallelSend --> DiscardCorrupt: decodedPayload == null
  ParallelSend --> DeleteSent: 200 OK
  ParallelSend --> Keep: error (retain for retry)
  DiscardCorrupt --> Sweep
  DeleteSent --> Sweep: delete(event.id)
  Keep --> Sweep
  Sweep --> [*]: drained

  Success --> StatusOk: return true
  StatusOk --> [*]
  StatusEnqueued --> [*]

  note right of QueueInsert
    InMemoryQueue & PersistedQueue:
    evict oldest in-place before insert.
    NoopQueue: no-op (queueConfig = disabled).
    Custom UmamiQueue: honors the port contract;
    TTL purge only when the factory-derived
    flushPurgeTtl is non-null.
  end note

  note right of Keep
    Event remains in queue for
    next flush / restart.
  end note
```

## External Dependencies

```mermaid
flowchart LR
  subgraph Pkg["pubspec dependencies"]
    H["http ^1.2.0"]
    U["uuid ^4.2.0"]
    SQ["sqflite ^2.4.1"]
    P["path ^1.9.0"]
    FSS["flutter_secure_storage ^9.2.0"]
    FLUT["flutter (sdk)"]
  end

  subgraph SDK["dart:io / dart:convert (no pkg)"]
    DIO["dart:io Platform"]
    DC["dart:convert"]
  end

  subgraph UsedBy["Used by"]
    TC["TrackingCollector"] --> U
    TC --> DC
    DHC["DefaultHttpClient"] --> H
    DHC --> DC
    DHC --> DIO
    UAC["UmamiApiClient"] --> H
    UAC --> DC
    DIdS["DefaultDeviceIdService"] --> U
    DIdS --> FSS
    PQ["PersistedQueue"] --> SQ
    PQ --> P
    UAS["UserAgentService"] --> PD["PlatformDetector"]
    PD --> DIO
    PD --> FLUT
    DDIS["DefaultDeviceInfoService"] --> PD
    DDIS --> FLUT
  end
```

`EndpointBuilder`, `HttpHeaders`, `instance_suffix`, `json_helpers`, and `safe_async` are pure-Dart helpers with no external package dependency.

## Multi-instance Isolation

`instanceName` flows through `instanceSuffix()` (`_<name>` when non-empty, otherwise `''`) into two places:

- `DefaultDeviceIdService` — secure-storage keys per instance:
  - device id: `umami_device_id_<name>`
  - first-launch marker: `umami_first_launch_<name>`
- `PersistedQueue` — database filename suffix: `umami_queue_<name>.db`. Table name (`queued_events`) and schema are shared; only the file differs.

`InMemoryQueue` and `NoopQueue` are instance-agnostic. `DefaultHttpClient` and `UmamiApiClient` share the same `http.Client` only when the user passes one via the `httpClient` parameter of `createUmamiAnalytics()`; otherwise each creates and owns its own `http.Client` instance (closed on `dispose()`).
