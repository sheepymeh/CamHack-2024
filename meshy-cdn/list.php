<?php
header('Content-Type: application/json');
$list = explode("\n", file_get_contents('../meshy-files/tracker'));
array_pop($list);
echo json_encode($list);