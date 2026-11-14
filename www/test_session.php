<?php
echo "Поточна папка: " . __DIR__ . "<br>";
echo "Папка PHP: " . getcwd() . "<br>";
echo "session.save_path: " . ini_get('session.save_path') . "<br>";
echo "Папка існує? " . (is_dir(ini_get('session.save_path')) ? "✅ Так" : "❌ Ні") . "<br>";
echo "Права на запис? " . (is_writable(ini_get('session.save_path')) ? "✅ Так" : "❌ Ні") . "<br>";
?>