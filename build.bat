CALL flutter build web  --release --web-renderer html
CALL del .\docs /F /Q
CALL mkdir .\docs
CALL copy .\build\web .\docs