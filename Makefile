.PHONY: build run android test web linux

devices:
	flutter devices

run: run-linux

run-flutter:
	flutter run

run-linux:
	flutter run --device-id linux

run-linux-kickstart:
	flutter run --device-id linux --dart-define=KICKSTART=1

run-chrome:
	flutter run --device-id chrome --web-renderer html

run-android-debug:
	flutter run --device-id 192.168.0.22:5555

run-android:
	flutter run --device-id "moto g54 5G" --release

run-android-1:
	flutter run --device-id "2201117TY" --release

release: run-android

dart-fix-dry:
	dart fix --dry-run

dart-fix:
	dart fix --apply

doctor:
	flutter doctor

build-apk:
	flutter build apk --release

icon:
	flutter pub run flutter_launcher_icons

clean:
	flutter clean
