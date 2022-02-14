set script_dir=%~dp0%
set max_checkpoint=3
set script_dir=%script_dir:~0,-1%
set salt_minion=salt-minion
set vault_local_prod_path=C:\vault\prod
set vault_local_prod_bin_path=%vault_local_prod_path%\head\bin
set service_manager_head_script=%vault_local_prod_bin_path%\ssm.exe
set checkpoint_file_name=%salt_minion%-checkpoint
set fallback_script_name=salt-fallback.bat

sc query state=all | find "SERVICE_NAME: %salt_minion%"

if "%errorlevel%" == "0" (
	set service_exists="1"
) else (
	set service_exists="0")

if %service_exists% == "0" (
	exit
)

for /f "delims=" %%i in ('%service_manager_head_script% get %salt_minion% imagepath') do set "active_service_manager=%%i"
for %%i in ("%active_service_manager%") do set active_bin_dir=%%~dpi
set active_bin_dir=%active_bin_dir:~0,-1%

for %%i in ("%active_bin_dir%") do set active_salt_tag_dir=%%~dpi
set active_salt_tag_dir=%active_salt_tag_dir:~0,-1%

set checkpoint_file=%active_salt_tag_dir%\config\%checkpoint_file_name%
set fallback_script=%active_salt_tag_dir%\%fallback_script_name%

for /f "delims=" %%i in ('%service_manager_head_script% status %salt_minion%') do set "service_status=%%i"
echo "service_status %service_status%"

if %service_status% == SERVICE_RUNNING (
	set is_minion_running="1"
) else (
	set is_minion_running="0")

set restart_only="0"
if not exist "%checkpoint_file%" set restart_only="1"
if not exist "%fallback_script%" set restart_only="1"

if %restart_only% == 1 (
	if %is_minion_running% == "1" (
		exit
	)
	%service_manager_head_script% start %salt_minion%
)
pause

for /f "tokens=* delims=" %%i in (%checkpoint_file%) do set "checkpoint_num=%%i"
echo "Checkpoint num = %checkpoint_num%"
set /a max_checkpoint=%max_checkpoint%-1

if %checkpoint_num% gtr %max_checkpoint% (
	echo "Removing checkpoint_file: %checkpoint_file%"
	rename "%checkpoint_file%" "%checkpoint_file_name%.bkp"
	pause
	exit
)

set /a neg_max_checkpoint=%max_checkpoint%*-1
echo "Negative max checkpoint: %neg_max_checkpoint%"

if %checkpoint_num% lss %neg_max_checkpoint% (
	echo "Running fallback_script: %fallback_script%"
	call %fallback_script%
	%service_manager_head_script% restart %salt_minion%
	rename %fallback_script% %fallback_script_name%.bkp
	pause
	exit
)

if not %is_minion_running% == "1" (
	echo "Starting service: %salt_minion%"
	%service_manager_head_script% start %salt_minion%
)

if %is_minion_running% == "1" (
	set /a new_checkpoint=%checkpoint_num%+1
) else (
	set /a new_checkpoint=%checkpoint_num%-1
)

echo "Setting checkpoint value to %new_checkpoint%"
echo %new_checkpoint% > %checkpoint_file%