@echo off
setlocal enabledelayedexpansion

:: 引数を受取ります
set /p RC=<csv\fileWait

:: ログファイル
set SCRIPT_NAME=%~n0
set LOG_PATH=log
set LOG=%LOG_PATH%\%SCRIPT_NAME%.log

:: ログを記録
echo 日付: %DATE% %TIME% > "%LOG%"
echo ホスト名: %COMPUTERNAME% >> "%LOG%"
echo 数値を受取り、その数値を返します。 >> "%LOG%"
echo 受取値: %RC% >> "%LOG%"
echo 返却値: %RC% >> "%LOG%"

exit /b %RC%