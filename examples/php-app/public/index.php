<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Example PHP Application</title>
    <script src="/dist/bundle.js" defer></script>
</head>
<body>
    <div class="container">
        <h1>🚀 PHP Web Application</h1>
        <p>This is an example PHP application with compiled frontend assets.</p>
        
        <div class="info">
            <h2>Application Info</h2>
            <ul>
                <li><strong>PHP Version:</strong> <?= phpversion() ?></li>
                <li><strong>Server Time:</strong> <?= date('Y-m-d H:i:s') ?></li>
                <li><strong>Environment:</strong> <?= getenv('APP_ENV') ?: 'production' ?></li>
            </ul>
        </div>

        <div class="architecture">
            <h2>Architecture</h2>
            <p>This application runs with:</p>
            <ul>
                <li>✅ PHP-FPM (FastCGI Process Manager)</li>
                <li>✅ Nginx reverse proxy</li>
                <li>✅ Pre-compiled frontend assets (Webpack)</li>
                <li>✅ Multi-stage Docker build</li>
            </ul>
        </div>
    </div>

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 800px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }
        
        h1 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 2.5em;
        }
        
        h2 {
            color: #764ba2;
            margin: 30px 0 15px 0;
            font-size: 1.5em;
        }
        
        p {
            color: #555;
            line-height: 1.6;
            margin-bottom: 20px;
        }
        
        .info, .architecture {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        
        ul {
            list-style: none;
            padding-left: 0;
        }
        
        li {
            padding: 8px 0;
            color: #333;
        }
        
        li strong {
            color: #667eea;
        }
    </style>
</body>
</html>
