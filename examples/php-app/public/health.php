<?php
// Simple health check endpoint for Kubernetes probes
header('Content-Type: application/json');
http_response_code(200);

echo json_encode([
    'status' => 'healthy',
    'timestamp' => time(),
    'php_version' => phpversion()
]);
