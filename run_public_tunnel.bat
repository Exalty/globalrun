@echo off
title GlobalRun Cloudflare Public Tunnel
echo ========================================================
echo   GlobalRun - Menyalakan Link Publik Cloudflare Tunnel
echo ========================================================
echo Pastikan backend Node.js (npm start) sudah menyala di port 5000.
echo.
"%~dp0cloudflared.exe" tunnel --url http://127.0.0.1:5000
pause
