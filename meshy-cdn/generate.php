<?php

require 'include.php';

function http_get($url, $headers) {
	return file_get_contents($url, false, stream_context_create([
		'http' => [
			'method' => 'GET',
			'header' => $headers
		]
	]));
}

function http_post($url, $headers, $data) {
	return file_get_contents($url, false, stream_context_create([
		'http' => [
			'method' => 'POST',
			'header' => $headers,
			'content' => json_encode($data)
		]
	]));
}

function get_meshy_api($endpoint) {
	global $BASE_URL, $API_KEY;
	return json_decode(http_get("$BASE_URL/$endpoint", [
		"Authorization: Bearer $API_KEY"
	]), true);
}

function post_meshy_api($endpoint, $body) {
	global $BASE_URL, $API_KEY;
	return json_decode(http_post("$BASE_URL/$endpoint", [
		'Content-Type: application/json',
		"Authorization: Bearer $API_KEY"
	], $body), true);
}

if (!file_exists($file) && !file_exists($lockfile)) {
	file_put_contents($lockfile, '');

	set_time_limit(500);
	ob_start();
	http_response_code(201);
	header('Connection: close');
	header('Content-Length: '. ob_get_length());
	ob_end_flush();
	@ob_flush();
	flush();

	$previewId = post_meshy_api('v2/text-to-3d', [
		'mode' => 'preview',
		'prompt' => $prompt,
		'art_style' => 'realistic',
		'negative_prompt' => 'low quality, low resolution, low poly, ugly',
		'ai_model' => 'meshy-3-turbo',
		// 'topology' => 'triangle',
		// 'target_polycount' => 10000
	])['result'];

	while (true) {
		sleep(5);
		$status = get_meshy_api("v2/text-to-3d/$previewId");
		if ($status['status'] == 'SUCCEEDED') break;
	}

	$texturedId = post_meshy_api('v2/text-to-3d', [
		'mode' => 'refine',
		'preview_task_id' => $previewId
	])['result'];

	while (true) {
		sleep(5);
		$progress = get_meshy_api("v2/text-to-3d/$texturedId")['status'];
		if ($status['status'] == 'SUCCEEDED') break;
	}

	file_put_contents(
		$file,
		http_get($status['model_urls']['usdz'], [])
	);
	unlink($lockfile);
}
else http_response_code(201);