defmodule AwsSsoConfigGenerator.AuthorizationCode.Html do
  def html() do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>AWS SSO Config Generator</title>
        <style>
            body {
                font-family: 'Courier New', monospace;
                margin: 0;
                padding: 20px;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                transition: background-color 0.3s, color 0.3s;
            }

            /* Light mode (default) */
            body {
                background-color: #ffffff;
                color: #333333;
            }

            /* Dark mode */
            @media (prefers-color-scheme: dark) {
                body {
                    background-color: #1e1e1e;
                    color: #cccccc;
                }
            }

            .ascii-container {
                text-align: center;
                white-space: pre;
                font-size: 12px;
                line-height: 1.1;
                display: inline-block;
                transform-origin: center;
                color: orange;
            }

            .message {
                margin-top: 40px;
                text-align: center;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            }

            .status {
                font-size: 24px;
                font-weight: bold;
                margin-bottom: 10px;
            }

            .description {
                font-size: 18px;
                margin-bottom: 10px;
            }

            .instruction {
                font-size: 16px;
                opacity: 0.8;
            }

            .github-link {
                margin-top: 20px;
            }

            .github-link a {
                color: inherit;
                text-decoration: underline;
                font-size: 14px;
            }

            .github-link a:hover {
                opacity: 0.8;
            }
        </style>
    </head>
    <body>
        <div class="ascii-container">
     █████╗ ██╗    ██╗███████╗      ███████╗███████╗ ██████╗        ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗        ██████╗ ███████╗███╗   ██╗███████╗██████╗  █████╗ ████████╗ ██████╗ ██████╗
    ██╔══██╗██║    ██║██╔════╝      ██╔════╝██╔════╝██╔═══██╗      ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝       ██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗
    ███████║██║ █╗ ██║███████╗█████╗███████╗███████╗██║   ██║█████╗██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗█████╗██║  ███╗█████╗  ██╔██╗ ██║█████╗  ██████╔╝███████║   ██║   ██║   ██║██████╔╝
    ██╔══██║██║███╗██║╚════██║╚════╝╚════██║╚════██║██║   ██║╚════╝██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║╚════╝██║   ██║██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗██╔══██║   ██║   ██║   ██║██╔══██╗
    ██║  ██║╚███╔███╔╝███████║      ███████║███████║╚██████╔╝      ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝      ╚██████╔╝███████╗██║ ╚████║███████╗██║  ██║██║  ██║   ██║   ╚██████╔╝██║  ██║
    ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝      ╚══════╝╚══════╝ ╚═════╝        ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝        ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
        </div>

        <div class="message">
            <div class="status">✅ Request approved</div>
            <div class="description">aws-sso-config-generator has been given requested permissions</div>
            <div class="instruction">You can close this window and start using the AWS CLI.</div>
            <div class="github-link">
                <a href="https://github.com/djgoku/aws-sso-config-generator" target="_blank">https://github.com/djgoku/aws-sso-config-generator</a>
            </div>
        </div>

        <script>
            function scaleAsciiArt() {
                const container = document.querySelector('.ascii-container');
                const containerWidth = container.scrollWidth;
                const containerHeight = container.scrollHeight;
                const viewportWidth = window.innerWidth * 0.9; // 90% of viewport
                const viewportHeight = window.innerHeight * 0.8; // 80% of viewport

                const scaleX = viewportWidth / containerWidth;
                const scaleY = viewportHeight / containerHeight;
                const scale = Math.min(scaleX, scaleY, 1); // Don't scale up beyond 100%

                container.style.transform = `scale(${scale})`;
            }

            // Scale on load and resize
            window.addEventListener('load', scaleAsciiArt);
            window.addEventListener('resize', scaleAsciiArt);
        </script>
    </body>
    </html>
    """
  end
end
