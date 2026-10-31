#!/bin/sh
# Builds the app four times and counts the Sentry calls the plugin put into App.class each time.
set -eu
cd "$(dirname "$0")"

class=app/build/intermediates/classes/debug/transformDebugClassesWithAsm/dirs/com/example/repro/App.class

build() {
  echo
  echo "$1"
  shift
  rm -rf app/build
  ./gradlew --console=plain "$@" :app:assembleDebug >build.log 2>&1 || { cat build.log; exit 1; }
  grep -E '^(Configuration cache entry|Calculating task graph)' build.log | sed 's/^/  /'
  grep ':app:transformDebugClassesWithAsm' build.log | sed 's/^/  /'
  echo "  Sentry calls in App.class: $(javap -c -p "$class" | grep -c 'io/sentry' || true)"
  javap -c -p "$class" | grep -o 'io/sentry[^ ]*' | sed 's/^/    /' || true
  echo "  Integrations the manifest lists: $(grep -rho 'gradle-plugin-integrations" android:value="[^"]*' app/build/intermediates/merged_manifests | cut -d'"' -f3 | sort -u)"
}

rm -rf .gradle/configuration-cache .gradle/build-cache

build "1. Fresh configuration, stores the configuration cache" --configuration-cache --no-build-cache
build "2. Same command, reuses the configuration cache" --configuration-cache --build-cache
build "3. Fresh configuration, transform output from the build cache that step 2 filled" --no-configuration-cache --build-cache
build "4. Fresh configuration, no caches" --no-configuration-cache --no-build-cache
