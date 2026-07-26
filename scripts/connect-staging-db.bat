@echo off
setlocal EnableExtensions

title Shuli Staging DB - SSM Tunnel

echo.
echo ========================================
echo   Connecting to Shuli Staging DB...
echo ========================================
echo.

where aws >nul 2>nul
if errorlevel 1 (
    echo ERROR: AWS CLI is not installed or not in your PATH.
    echo.
    echo Install AWS CLI v2:
    echo   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    echo.
    echo Then configure your profile:
    echo   aws configure
    echo   Region: eu-north-1
    echo.
    echo You also need the Session Manager plugin:
    echo   https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
    echo.
    pause
    exit /b 1
)

echo Tunnel: localhost:5432 --^> shuli-staging-db (PostgreSQL 5432^)
echo.
echo Keep this window OPEN while using pgAdmin or DBeaver.
echo Press Ctrl+C to disconnect the tunnel.
echo.

aws ssm start-session ^
  --target i-069242cd0301a2c7e ^
  --region eu-north-1 ^
  --document-name AWS-StartPortForwardingSessionToRemoteHost ^
  --parameters host="shuli-staging-db.cn6uwqem6nuu.eu-north-1.rds.amazonaws.com",portNumber="5432",localPortNumber="5432"

if errorlevel 1 (
    echo.
    echo The tunnel session ended or failed.
    echo Check: AWS credentials, IAM permissions, and Session Manager plugin.
    echo.
    pause
    exit /b 1
)

endlocal
