@echo off

SET /P PGHOST= Please enter host address:

SET /P PGPORT=Please enter host port no:

SET /P PGUSER= Please enter host username:

SET /P P1=Please enter password for server1:


SET /P RHOST= Please enter remote address:

SET /P RPORT=Please enter remote port no:

SET /P RUSER= Please enter remote username:

SET /P P2=Please enter password for server2:

set FILELOG=log.txt

set BACKUPDIR=C:/pgbackup/

if not exist %BACKUPDIR% mkdir "%BACKUPDIR%" || echo ERROR #%errorlevel%-Failed to make backup directory. && exit /b %errorlevel%

for /f "tokens=1-3 delims=- " %%i in ("%date%") do (

    set dow=%%i

    set month=%%j

    set year=%%k

)

set BACKUPDIRDATE=%BACKUPDIR%%dow%.%month%.%year%

for /f "tokens=1-3 delims=: " %%i in ("%time%") do (

    set hh=%%i

    set mm=%%j

    set s=%%k

)

for /f "tokens=1-2 delims=. " %%i in ("%s%") do (
	
	set ss=%%i
	
)

set BACKUPDIRTIME=%BACKUPDIRDATE%.%hh%hr%mm%min%ss%sec

if exist dbs.lst del dbs.lst 

if exist dbslinux.lst del dbslinux.lst

SET PGPASSWORD=%P1%&& psql -h %PGHOST% -U %PGUSER% -p %PGPORT% -c "SELECT datname FROM pg_database WHERE datistemplate=false" -o "dbs.lst"  || echo ERROR #%errorlevel%-Failed to make a list of databases of %PGHOST% && exit /b %errorlevel%

SET PGPASSWORD=%P2%&& psql -h %RHOST% -U %RUSER% -p %RPORT% -c "SELECT datname FROM pg_database WHERE datistemplate=false" -o "dbslinux.lst"  || echo ERROR #%errorlevel%-Failed to make a list of databases of %RHOST%&& exit /b %errorlevel%

if exist bfile.sql del bfile.sql

set /a i=0

setlocal EnableDelayedExpansion

set total_db =0

set "cmd=findstr /R /N "^^" dbs.lst | find /C ":""  || echo ERROR #%errorlevel%-Could not find dbs.lst&& exit /b %errorlevel%

for /f %%a in ('!cmd!') do set total_db=%%a  || echo ERROR #%errorlevel%-Could not count number of databases && exit /b %errorlevel%

set /a total_db-=4

if !total_db!==0 (

	echo No databases to transfer
	exit /b
)

for /f "eol=( skip=2" %%a IN (dbs.lst) DO ( 
	
	IF NOT %%a==postgres (
		
		for /f "eol=( skip=2" %%b IN (dbslinux.lst) DO (
		
		if %%a==%%b (
	
			SET PGPASSWORD=%P2%&& psql -h %RHOST% -U %RUSER% -p %RPORT% -c "SELECT pid, pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%%a' AND pid <> pg_backend_pid()" ||  echo ERROR #%errorlevel%-Failed to establish connection with %RHOST%%. && exit /b %errorlevel%
			
			SET PGPASSWORD=%P2%&& psql -h %RHOST% -U %RUSER% -p %RPORT% -c "DROP DATABASE "%%b"" ||  echo ERROR #%errorlevel%-Failed to drop database %%a. && exit /b %errorlevel%
		
		)
	)
	
    echo Backup started: %date% %time%

    echo DATABASE NAME: %%a
	
    SET PGPASSWORD=%P2%&& psql -h %RHOST% -U %RUSER% -p %RPORT% -c "SELECT pid, pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%%a' AND pid <> pg_backend_pid()" ||  echo ERROR #%errorlevel%-Failed to establish connection with %RHOST%%. && exit /b %errorlevel%
			
    SET PGPASSWORD=%P2%&& psql -h %RHOST% -U %RUSER% -p %RPORT% -c "CREATE DATABASE %%a;"  || echo ERROR #%errorlevel%-Failed to create database %%a. && exit /b %errorlevel%
	
	
    SET PGPASSWORD=%P1%&& pg_dump -h %PGHOST% -U %PGUSER% -p %PGPORT% %%a >bfile.sql ||  echo ERROR #%errorlevel%-Failed to dump database %%a. && exit /b %errorlevel%

    SET PGPASSWORD=%P2%&& psql -h %RHOST% -p %RPORT% -U %RUSER% -d %%a -1 -f bfile.sql ||  echo ERROR #%errorlevel%-Failed to backup database %%a. && exit /b %errorlevel%
	
    if exist bfile.sql del bfile.sql
	
    echo End of backup %BASELOG%
   
    )>>%BACKUPDIRTIME%%FILELOG%
   
    for /f %%a in ('copy /Z "%~dpf0" nul') do set "CR=%%a"
   
		set /a i+=1
		
		call :show_progress !i! !total_db! 
		
)

echo Backup done.

exit /b

:show_progress

    setlocal EnableDelayedExpansion

    set current_step=%1

    set total_steps=%2

    set /a "progress=(current_step * 100) / total_steps" 

    set /p ".=_Progress: !progress!%%!CR!" <nul  

    if !progress! equ 100 echo. ||  echo ERROR #%errorlevel%-Failed to display progress meter. && exit /b %errorlevel%

exit /b