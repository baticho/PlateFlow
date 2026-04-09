include .env
export

# Mobile — production backend (reads MOBILE_API_BASE_URL from .env)
run-mobile:
	cd mobile && flutter run --dart-define=API_BASE_URL=$(MOBILE_API_BASE_URL)

build-mobile-apk:
	cd mobile && flutter build apk --dart-define=API_BASE_URL=$(MOBILE_API_BASE_URL)

build-mobile-appbundle:
	cd mobile && flutter build appbundle --dart-define=API_BASE_URL=$(MOBILE_API_BASE_URL)

# Mobile — local dev (Android emulator host IP)
run-mobile-local:
	cd mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8005

# Mobile — local dev with dev mode auto-login
run-mobile-local-dev:
	cd mobile && flutter run \
		--dart-define=API_BASE_URL=http://10.0.2.2:8005 \
		--dart-define=DEV_MODE=true
