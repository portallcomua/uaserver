<?php
// https://uaserver.pp.ua/api/generate_key.php
function generateLicense($email, $orderId) {
    $secret = "YOUR_SECRET_KEY";
    $data = $email . $orderId . date('Y-m-d');
    $hash = hash_hmac('sha256', $data, $secret);
    return substr($hash, 0, 16) . '-' . substr($hash, 16, 16);
}
?>