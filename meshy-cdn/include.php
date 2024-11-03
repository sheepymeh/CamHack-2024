<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$BASE_URL = 'https://api.meshy.ai';
$API_KEY = '';

if (empty($_GET['prompt']) || strlen($_GET['prompt']) < 4) {
	http_response_code(400);
	exit;
}
$prompt = $_GET['prompt'];

$hash = base64_encode(hash('sha224', $prompt, true));
$hash = rtrim(strtr($hash, '+/', '-_'), '=');
$file = "../meshy-files/$hash";
$lockfile = "$file.lock";