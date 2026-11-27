# UAServer Free 8.5.1

Портативний локальний вебсервер для Windows.

## Завантаження

- **Full — повний офлайн-архів:** https://github.com/portallcomua/uaserver/releases/latest/download/UAServer-Full.zip
- **Online — невеликий інсталятор:** https://github.com/portallcomua/uaserver/releases/latest/download/UAServer-Online.zip

## Відмінності

### Full
Містить UAServer та всі компоненти. Після розпакування сервер можна запускати без інтернету.

### Online
Містить невеликий EXE-інсталятор. Під час першого запуску завантажує Full-архів з останнього GitHub Release, пропонує вибрати папку встановлення (початковий шлях — `D:\UAServer`) та створює ярлик на робочому столі. Для першого встановлення потрібен інтернет.

## Компоненти

- PHP 8.5.1 (NTS x64)
- PHP 7.4.33 (NTS x64)
- MariaDB 12.1.2
- Nginx 1.30.8
- phpMyAdmin 5.2.3

Компоненти не зберігаються в Git-репозиторії. GitHub Actions автоматично завантажує їх з офіційних джерел, створює чисту базу даних та збирає обидва ZIP-архіви.

## Портативність

Після встановлення або розпакування можна перевірити роботу з папки на комп'ютері, а потім скопіювати всю папку UAServer на флешку та запустити `UAServer.exe` звідти. Не переносіть лише EXE — потрібна вся папка.

## Збірка

Workflow: [Build UAServer packages](https://github.com/portallcomua/uaserver/actions/workflows/release.yml)

Зміни у вихідному коді, папках `app`, `start`, `installer` або `logo.ico` запускають автоматичне збирання та публікацію релізу.
