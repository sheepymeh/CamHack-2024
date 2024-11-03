<?php

require 'include.php';

if (file_exists($file)) {
	header('Content-Description: File Transfer');
	header('Content-Type: application/octet-stream');
	header('Content-Disposition: attachment; filename="' . substr($prompt, 0, 24) . '.usdz"');
	header('Expires: 0');
	header('Cache-Control: must-revalidate');
	header('Pragma: public');
	header('Content-Length: ' . filesize($file));
	readfile($file);
}
elseif (file_exists($lockfile)) http_response_code(204);
else http_response_code(404);