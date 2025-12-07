const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Routes
app.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Example Node.js Application</title>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Node.js Web Application</h1>
            <p>This is an example Node.js application running in Kubernetes.</p>
            
            <div class="info">
                <h2>Application Info</h2>
                <ul>
                    <li><strong>Node Version:</strong> ${process.version}</li>
                    <li><strong>Environment:</strong> ${process.env.NODE_ENV || 'development'}</li>
                    <li><strong>Platform:</strong> ${process.platform}</li>
                    <li><strong>Uptime:</strong> ${Math.floor(process.uptime())} seconds</li>
                </ul>
            </div>

            <div class="architecture">
                <h2>Architecture</h2>
                <p>This application demonstrates:</p>
                <ul>
                    <li>✅ Express.js web server</li>
                    <li>✅ Multi-stage Docker build</li>
                    <li>✅ Production-optimized dependencies</li>
                    <li>✅ Non-root container user</li>
                    <li>✅ Health check endpoints</li>
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
  `);
});

// Health check endpoint for Kubernetes liveness probe
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
    // Add any readiness checks here (database connection, etc.)
    res.status(200).json({
        status: 'ready',
        timestamp: new Date().toISOString()
    });
});

// API endpoint example
app.get('/api/info', (req, res) => {
    res.json({
        app: 'example-node-app',
        version: '1.0.0',
        node: process.version,
        environment: process.env.NODE_ENV || 'development'
    });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});
