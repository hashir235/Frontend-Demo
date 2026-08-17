$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:8080/')
$listener.Start()
try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.AbsolutePath
    $statusCode = 200
    $body = '{}'

    switch ($path) {
      '/api/auth/me' {
        $body = '{"user":{"id":"emulator-check","fullName":"Codex QA","email":"qa@example.com"},"expiresAt":"2027-03-10T00:00:00.000Z"}'
      }
      '/api/auth/logout' {
        $body = '{}'
      }
      default {
        $statusCode = 404
        $body = '{"error":"Not found"}'
      }
    }

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($body)
    $response.StatusCode = $statusCode
    $response.ContentType = 'application/json'
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
  }
} finally {
  if ($listener.IsListening) {
    $listener.Stop()
  }
  $listener.Close()
}