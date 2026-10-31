# Sentry Android Gradle plugin: instrumentation depends on configuration cache reuse

The Sentry Android Gradle plugin decides which instrumentation to apply from the Sentry SDK versions it reads in a `configuration.incoming.afterResolve` hook (`SentryModulesCollector.kt`). That hook runs only when Gradle resolves the runtime classpath during configuration. When Gradle reuses the configuration cache, the hook never runs, `SentryModulesService.sentryModules` stays empty, and `SpanAddingClassVisitorFactory` enables no instrumentation. Any class instrumented in that build, such as the `Application` after an edit, ships without app-start or logcat instrumentation. The module versions are not task inputs either, so the build cache stores that uninstrumented output under the same key and serves it to later builds with a fresh configuration.

## Reproduction

Needs a JDK 17 or later and the Android SDK (`ANDROID_HOME`, or `sdk.dir` in `local.properties`).

```sh
./reproduce.sh
```

It builds `:app:assembleDebug` four times, deleting `app/build` before each, and prints the Sentry calls in `App.class` (`App.onCreate` calls `Log.w`) and the integrations the plugin wrote to the merged manifest:

```
1. Fresh configuration, stores the configuration cache
  Calculating task graph as no cached configuration is available for tasks: :app:assembleDebug
  Configuration cache entry stored.
  > Task :app:transformDebugClassesWithAsm
  Sentry calls in App.class: 3
    io/sentry/android/core/performance/AppStartMetrics.onApplicationCreate:(Landroid/app/Application;)V
    io/sentry/android/core/SentryLogcatAdapter.w:(Ljava/lang/String;Ljava/lang/String;)I
    io/sentry/android/core/performance/AppStartMetrics.onApplicationPostCreate:(Landroid/app/Application;)V
  Integrations the manifest lists: AppStartInstrumentation,DatabaseInstrumentation,FileIOInstrumentation,LogcatInstrumentation

2. Same command, reuses the configuration cache
  Configuration cache entry reused.
  > Task :app:transformDebugClassesWithAsm
  Sentry calls in App.class: 0
  Integrations the manifest lists: AppStartInstrumentation,DatabaseInstrumentation,FileIOInstrumentation,LogcatInstrumentation

3. Fresh configuration, transform output from the build cache that step 2 filled
  > Task :app:transformDebugClassesWithAsm FROM-CACHE
  Sentry calls in App.class: 0
  Integrations the manifest lists: AppStartInstrumentation,DatabaseInstrumentation,FileIOInstrumentation,LogcatInstrumentation

4. Fresh configuration, no caches
  > Task :app:transformDebugClassesWithAsm
  Sentry calls in App.class: 3
    io/sentry/android/core/performance/AppStartMetrics.onApplicationCreate:(Landroid/app/Application;)V
    io/sentry/android/core/SentryLogcatAdapter.w:(Ljava/lang/String;Ljava/lang/String;)I
    io/sentry/android/core/performance/AppStartMetrics.onApplicationPostCreate:(Landroid/app/Application;)V
  Integrations the manifest lists: AppStartInstrumentation,DatabaseInstrumentation,FileIOInstrumentation,LogcatInstrumentation
```

Editing `App.java` instead of deleting `app/build` gives the same result as step 2: the configuration cache is reused and the edited class has no Sentry calls.

## Expected

Every build instruments `App` the same way: `AppStartMetrics.onApplicationCreate`, `SentryLogcatAdapter.w` and `AppStartMetrics.onApplicationPostCreate`, as in steps 1 and 4 and as the manifest's integration list says.

## Actual

- Step 2: with a reused configuration cache, the transform runs with `sentryModules` empty, so `isAppStartInstrEnabled()`, `isLogcatInstrEnabled()` and the other checks in `SentryModulesService` return false and `App` is not instrumented.
- Step 3: a build with a fresh configuration takes that uninstrumented output from the build cache, because `sentryModules` is not part of the transform's inputs (`SpanAddingParameters.sentryModulesService` is `@Internal`).
- In every step the manifest lists `AppStartInstrumentation` and `LogcatInstrumentation`, whether or not the code was instrumented.

Where it goes wrong, at 6.25.0:

- `plugin-build/src/main/kotlin/io/sentry/android/gradle/util/SentryModulesCollector.kt`: `collectModules` sets `sentryModulesService.get().sentryModules` only inside `configuration.incoming.afterResolve`.
- `plugin-build/src/main/kotlin/io/sentry/android/gradle/instrumentation/SpanAddingClassVisitorFactory.kt`: the `instrumentable` getter reads `sentryModulesService.get().sentryModules` at execution time.

## Environment

- Sentry Android Gradle plugin 6.25.0
- Sentry Android SDK (`sentry-android-core`) 8.62.0
- Android Gradle plugin 9.5.0
- Gradle 9.8.2
- JDK 25.0.2 (Temurin)
- macOS 27.2 (arm64)
