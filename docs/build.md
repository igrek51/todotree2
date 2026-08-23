# Build Instructions

## Environment Setup
Ensure you have the Flutter SDK installed and configured for your target platform (Android, Linux, or Web).

## Makefile Commands
The project uses a `Makefile` to simplify common tasks:

- **Run on Linux**: `make run-linux`
- **Build for Web**: `make build-web`
- **Build Android APK**: `make build-apk`
- **Run Tests**: `flutter test`
- **Static Analysis**: `flutter analyze`

## Local ignored files for Android signing

-   `android/.keystore.properties`

    ```
    storeFile=upload-keystore.jks
    keyAlias=upload
    storePassword=***
    keyPassword=***
    ```

-   `android/app/upload-keystore.jks` - Upload Key Store
