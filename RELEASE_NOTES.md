Сертификаты Минцифры работают только на [сайтах из списка](https://github.com/Maks-gaming/safe-ru-trust/blob/main/domains.txt), остальной интернет корню Минцифры не доверяет.

## Что скачать

| Система | Файл | Автообновление |
|---|---|---|
| Windows 10/11 | `safe-ru-trust-windows.zip` | ✅ |
| Linux | `safe-ru-trust-unix.tar.gz` | ✅ |
| macOS | `safe-ru-trust-unix.tar.gz` | ✅ |
| iPhone, iPad | `safe-ru-trust.mobileconfig` | ❌ |
| ChromeOS | `safe-ru-trust-root.crt` и `safe-ru-trust-cross.crt` | ❌ |
| Android | ничего, см. ниже | ❌ |

Файлы находятся в блоке **Assets** внизу этой страницы.

## Установка

**Windows.** Распакуй zip, запусти `install.bat`, разреши права администратора, перезапусти браузер. Установщик не подписан, поэтому Windows может предупредить о неизвестном издателе. Удаление: `uninstall.bat`.

**Linux.** Нужен certutil: `sudo apt install libnss3-tools` (Fedora: `nss-tools`, Arch: `nss`).

```sh
mkdir srt && tar xzf safe-ru-trust-unix.tar.gz -C srt && cd srt
./safe-ru-trust.sh install
```

Перезапусти браузер. Удаление: `~/.local/share/safe-ru-trust/safe-ru-trust.sh uninstall`.

**macOS.**

```sh
mkdir srt && tar xzf safe-ru-trust-unix.tar.gz -C srt && cd srt
sudo ./safe-ru-trust.sh install
```

Удаление: `sudo "/Library/Application Support/SafeRUTrust/safe-ru-trust.sh" uninstall`.

**iPhone, iPad.** Открой `safe-ru-trust.mobileconfig` в Safari и разреши загрузку. Затем «Настройки → Профиль загружен → Установить» и «Основные → Об этом устройстве → Доверие сертификатам», там включи Safe RU Trust. Новую версию ставь так же.

**ChromeOS.** «Настройки → Конфиденциальность → Управление сертификатами → Центры сертификации → Импорт». Для `safe-ru-trust-root.crt` включи доверие для сайтов, для `safe-ru-trust-cross.crt` **не** включай.

**Android.** На всю систему нельзя, файлы отсюда не ставь. Используй Яндекс Браузер, он сам доверяет сертификатам Минцифры. Другой вариант: Samsung Secure Folder (Knox) или рабочий профиль с официальным корнем Минцифры, тогда он действует только внутри профиля.

Подробности и проверка релиза: [README](https://github.com/Maks-gaming/safe-ru-trust#readme).
