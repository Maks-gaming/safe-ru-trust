Сертификаты Минцифры работают только на [сайтах из списка](https://github.com/Maks-gaming/safe-ru-trust/blob/main/domains.txt), остальной интернет корню Минцифры не доверяет.

## Установка одной командой

**Windows 10/11**, в PowerShell (сама запросит права администратора):

```powershell
irm https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.ps1 | iex
```

**Linux**, без `sudo` (пароль спросит, только если надо доставить certutil):

```sh
curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.sh | sh
```

**macOS** (спросит пароль администратора):

```sh
curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.sh | sh
```

Команды сами скачают последний релиз и включат автообновление. После установки перезапусти браузер.

## Файлами и другие системы

| Система | Файл | Автообновление |
|---|---|---|
| Windows 10/11 | [`safe-ru-trust-windows.zip`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-windows.zip) | ✅ |
| Linux | [`safe-ru-trust-unix.tar.gz`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-unix.tar.gz) | ✅ |
| macOS | [`safe-ru-trust-unix.tar.gz`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-unix.tar.gz) | ✅ |
| iPhone, iPad | [`safe-ru-trust.mobileconfig`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust.mobileconfig) | ❌ |
| ChromeOS | [`safe-ru-trust-root.crt`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-root.crt) и [`safe-ru-trust-cross.crt`](https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-cross.crt) | ❌ |
| Android | ничего, см. ниже | ❌ |

Ссылки в таблице сразу скачивают файл последнего релиза. Все файлы этого релиза есть в блоке **Assets** ниже.

### Инструкции

**Windows.** Распакуй zip, запусти `install.bat`, разреши права администратора, перезапусти браузер. Установщик не подписан, поэтому Windows может предупредить о неизвестном издателе.

**Linux.** Нужен certutil: `sudo apt install libnss3-tools` (Fedora: `nss-tools`, Arch: `nss`).

```sh
mkdir srt && tar xzf safe-ru-trust-unix.tar.gz -C srt && cd srt
./safe-ru-trust.sh install
```

Перезапусти браузер.

**macOS.**

```sh
mkdir srt && tar xzf safe-ru-trust-unix.tar.gz -C srt && cd srt
sudo ./safe-ru-trust.sh install
```


**iPhone, iPad.** Открой `safe-ru-trust.mobileconfig` в Safari и разреши загрузку. Затем «Настройки → Профиль загружен → Установить» и «Основные → Об этом устройстве → Доверие сертификатам», там включи Safe RU Trust. Новую версию ставь так же.

**ChromeOS.** «Настройки → Конфиденциальность → Управление сертификатами → Центры сертификации → Импорт». Для `safe-ru-trust-root.crt` включи доверие для сайтов, для `safe-ru-trust-cross.crt` **не** включай.

**Android.** На всю систему нельзя, файлы отсюда не ставь. Используй Яндекс Браузер, он сам доверяет сертификатам Минцифры. Другой вариант: Samsung Secure Folder (Knox) или рабочий профиль с официальным корнем Минцифры, тогда он действует только внутри профиля.

## Удаление

**Windows**, в PowerShell:

```powershell
irm https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/remove.ps1 | iex
```

**Linux и macOS:**

```sh
curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.sh | sh -s uninstall
```

**iPhone, iPad.** «Настройки → Основные → VPN и управление устройством → Safe RU Trust → Удалить профиль».

**ChromeOS.** «Настройки → Конфиденциальность → Управление сертификатами → Центры сертификации»: удали Safe RU Trust и Russian Trusted Root CA.

**Android.** Если ставил официальный корень в отдельный профиль, удали его там или удали сам профиль.

Подробности и проверка релиза: [README](https://github.com/Maks-gaming/safe-ru-trust#readme).
