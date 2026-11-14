<?php
declare(strict_types=1);

$cfg['blowfish_secret'] = 'uaserver_secret_key_32_chars_long!!!'; 

$i = 0;
$i++;

/* АВТОМАТИЧНИЙ ВХІД (Магія тут) */
$cfg['Servers'][$i]['auth_type'] = 'config';    // Тип 'config' прибирає вікно логіна
$cfg['Servers'][$i]['user'] = 'root';           // Користувач за замовчуванням
$cfg['Servers'][$i]['password'] = '';           // Пароль порожній
$cfg['Servers'][$i]['AllowNoPassword'] = true;  // Дозвіл на порожній пароль
$cfg['Servers'][$i]['host'] = '127.0.0.1';
$cfg['Servers'][$i]['compress'] = false;

/* ФІКСИ ДЛЯ БРАУЗЕРІВ */
$cfg['CookieSecure'] = false;
$cfg['DefaultLang'] = 'uk';
