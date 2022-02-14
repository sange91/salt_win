set script_dir=%~dp0%
set force="%1%"
set script_dir=%script_dir:~0,-1%
set salt_minion=salt-minion
set vault_local_prod_path=C:\vault\prod
set vault_local_prod_bin_path=%vault_local_prod_path%\head\bin
set salt_install_dir=%vault_local_prod_path%\softwares\dev\saltstack
set minion_schedule_script_name=salt-minion-schedule.bat
set salt_minion_script_name=%salt_minion%.bat
set salt_miniond_script_name=%salt_minion%d.bat
set salt_envs_script_name=salt-envs.bat
set salt_fallback_script_name=salt-fallback.bat

for /f "delims=" %%i in ("%script_dir%") do set filename=%%~nxi

set salt_tag=%filename%
echo Salt Tag: %salt_tag%

set salt_install_root=%salt_install_dir%\%salt_tag%

if exist "%salt_install_root%" (
	set new_tag="0"
) else (
	set new_tag="1"
)

set config_dir=%script_dir%\config
set config_install_dir=%salt_install_root%\config
set log_install_dir=%salt_install_root%\logs
set minion_log_file=%log_install_dir%\minion.log
set service_manager=%salt_install_root%\bin\ssm.exe
set service_manager_head=%vault_local_prod_bin_path%\ssm.exe

sc query state=all | find "SERVICE_NAME: %salt_minion%"

if "%errorlevel%" == "0" (
	set service_exists="1"
) else (
	set service_exists="0")

if %service_exists% == "1" (
	if not %force% == "1" (
		exit
	)
	echo "Stopping service: %salt_minion%"
	%service_manager% stop %salt_minion%

)

:: Copying salt to local
echo "Copying salt from %script_dir% to %salt_install_root%"
rem xcopy /y /i /e %script_dir% %salt_install_root%

:: Creating env file.
set envs_script=%salt_install_root%\%salt_envs_script_name%
set salt_envs_head_script=%vault_local_prod_bin_path%\%salt_envs_script_name%

echo setx PYTHONPATH "" > %envs_script%

:: Copying envs script to head
copy /y %envs_script% %salt_envs_head_script%

:: Creating salt minion daemon.
set salt_miniond_script=%salt_install_root%\%salt_miniond_script_name%
set salt_miniond_head_script=%vault_local_prod_bin_path%\%salt_miniond_script_name%

echo call %salt_envs_head_script% > %salt_miniond_script%
echo %salt_install_root%\%salt_minion_script_name% -l debug -c "%config_install_dir%" --log-file "%minion_log_file%" %%* >> %salt_miniond_script%

:: Copying miniond script to head
copy /y %salt_miniond_script% %salt_miniond_head_script%

:: Removing the existing salt minion
if %service_exists% == "1" %service_manager% remove %salt_minion% confirm

:: Creating salt minion service.
%service_manager% install %salt_minion% %salt_miniond_head_script%
%service_manager% start %salt_minion%

:: Creating a salt-minion grains.
set salt_miniond_dir=%config_install_dir%\minion.d
if not exist "%salt_miniond_dir%" (
	mkdir "%salt_miniond_dir%"
)
set salt_minion_grains_conf="%salt_miniond_dir%\_salt_tag.conf"
echo grains: {salt_tag: "%salt_tag%"} > %salt_minion_grains_conf%


echo "Copying Salt Schedule Script"
set salt_minion_schedule_script="%salt_install_root%\%minion_schedule_script_name%"
set salt_minion_schedule_head_script="%vault_local_prod_bin_path%\%minion_schedule_script_name%"

copy /y %script_dir%\%minion_schedule_script_name% %salt_minion_schedule_script%
copy /y %script_dir%\%minion_schedule_script_name% %salt_minion_schedule_head_script%

echo "Copying Service Manager to head"
copy /y %service_manager% %service_manager_head%

:: Creating a fallback script.
rem if %new_tag% == "1" (
echo "Creating fallback script: %fallback_script%"
for /f %%i in ("%service_manager% get %salt-minion% imagepath") do set "orig_service_manager=%%i"

for %%i in ("%service_manager%") do set orig_bin_dir=%%~dpi
set orig_bin_dir=%orig_bin_dir:~0,-1%

for %%i in ("%orig_bin_dir%") do set orig_salt_tag_dir=%%~dpi
set orig_salt_tag_dir=%orig_salt_tag_dir:~0,-1%

set orig_salt_envs_script=%orig_salt_tag_dir%\%salt_envs_script_name%
set orig_miniond_script=%orig_salt_tag_dir%\%salt_miniond_script_name%
set orig_minion_schedule_script=%orig_salt_tag_dir%\%salt_miniond_script_name%

set fallback_script=%salt_install_root%\%salt_fallback_script_name%
echo copy /y %orig_salt_envs_script% %salt_envs_head_script% > %fallback_script%
echo copy /y %orig_miniond_script% %salt_miniond_head_script% >> %fallback_script%
echo copy /y %orig_minion_schedule_script% %salt_minion_schedule_head_script% >> %fallback_script%

rem echo "%service_manager%" stop %salt_minion% > %fallback_script%
rem echo "%service_manager%" remove %salt_minion% confirm >> %fallback_script%
rem echo "%orig_service_manager%" install %salt_minion% "%orig_miniond_script%" >> %fallback_script%

echo "Scheduling salt task."
set minion_task=salt\%salt_minion%
schtasks /query /tn %minion_task% >NUL 2>&1
if %errorlevel% == 0 schtasks /delete /f /tn %minion_task%

schtasks /create /ru "SYSTEM" /sc MINUTE /tn %minion_task% /tr %salt_minion_schedule_head_script%
rem )
