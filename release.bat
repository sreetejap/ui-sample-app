@echo off

: : Invoke the run function and passes all arguments intercepted from cli
goto :run %*

: : A platform independent way to install a package, accepts any number of
: : arguments all of which are assumed to be name variations of a package that
: : should be tried, will only error if none of the arguments represent a valid
: : package name.
:install_package
    start "" /wait /b choco upgrade all -y
    for %%y in %* 
        do gsudo choco install %%y && %errorlevel% && break 
exit /b 0

: : Install all npm packages in opt/nodejs for microservice projects
: : TODO: Loop through multiple layer folders
:install_npm-packages
    REM if where npm
    if exist opt/nodejs (
        echo "Found directory opt/nodejs, installing npm packages"
        cd opt/nodejs
        if exist package.json (
            start "" /wait /b npm install --legacy-peer-deps
            echo "Finished installing npm packages"
        ) else (
            echo "No package.json defined, nothing to install."
        )   
        cd ..
        cd ..
    ) else (
        echo Found filesystem object opt/nodejs but it's not a directory
    )
        
    
            
    REM else
    REM     echo npm not found
    REM     echo Installing npm...
    REM     call :install_package npm
exit /b 0

: : Checkout & pull the git branch based on the specified environment
: : Accepts 1 argument of type string for the branch name
: : @param {String} Environment - Required
:git_checkout_branch
    : : if exist git (
    echo "Switching to %1 branch"
    start "" /wait /b git checkout %1
    start "" /wait /b git pull
    : : ) else (
    : :     echo "Unable to locate git, trying to install it..."
    : :     call :install_package git
    : : )     
exit /b 0

: : Checkout, merge & tag the specified git branch from the lower level branch
: : Accepts 1 argument of type string for the branch name
: : @param {String} environment - Required
: : @param {String} version - Required
:git_tag_and_merge
    REM if where git
    echo "Switching to %1 branch"

    start "" /wait /b git checkout %1

    start "" /wait /b git pull origin %1

    if "%1" equ "staging" (
        echo "Merging dev branch into %1."
			
		start "" /wait /b git checkout dev

		start "" /wait /b git pull origin dev

		start "" /wait /b git checkout %1
			
		start "" /wait /b git pull origin %1

		start "" /wait /b git merge dev

		echo "Merge from dev to %1 completed."

		start "" /wait /b git tag %2

		start "" /wait /b git push origin %1 --tags

		echo "Tagged the latest commit of %1."
    ) else (
        if "%1" equ "prod" (
            start "" /wait /b git checkout staging

			start "" /wait /b git pull origin staging

			start "" /wait /b git checkout %1
			
			start "" /wait /b git pull origin %1

			start "" /wait /b git merge staging

			echo "Merge from staging to %1 completed."

			start "" /wait /b git tag %2

			start "" /wait /b git push origin %1 --tags

			echo "Tagged the latest commit of %1."
        ) else (
            echo "%1 is not a staging or prod branch, nothing to do here, manual git branch mgmt reccomended."
        )            
    )  
            
    REM else
    REM     echo Unable to locate git, trying to install it...
    REM     call :install_package git
exit /b 0

: : Create a Github release using it's cli tool: gh
: : Accepts 1 argument of type string for the branch name
: : @param {String} environment - Required
: : @param {String} version - Required
:gh_release
    REM if where gh
    echo "Creating a Github %1 release."
    set /p _message=Please enter the release summary:
    if "%_message%" equ "" (
        echo "No summary was entered, exiting process."
    ) else (
        if "%1" equ "staging" (
            start "" /wait /b gh release create %2 -t "%2" -n "%message%" -p
        ) else (
            if "%1" equ "prod" (
                start "" /wait /b gh release create %2 -t "%2" -n "%message%"
            ) else (
                echo "%1 is not a staging or prod branch, nothing to do here, manual Github release mgmt reccomended."
            )       
        )           
    )
    echo "Github %1 release created for version %2."    
    REM else
    REM     echo Unable to locate gh, trying to install it.
    REM     call :install_package gh
exit /b 0

: : Re-initializes terraform in the project's root directory with the specified environment
: : @param {String} environment - Required
:terraform_apply
    REM if where terraform
    echo "removing .terraform directory"

    start "" /wait /b rd /s /q .terraform

    echo "Running Terraform init."

    start "" /wait /b terraform init --backend-config=config/%1.txt

    start "" /wait /b terraform workspace select %1

    call :install_npm_packages

    echo "Running terraform apply."

    start "" /wait /b terraform apply

    echo "Terraform apply completed for %1 environment."
    REM else
    REM     echo Unable to locate terraform, trying to install it...
    REM     call :install_package terraform
exit /b 0

: : Main invokation function to release a project
: : Accepts 3 arguments via cli
: : @param {String} environment - Required
: : @param {String} version - Required
: : @param {Enum} type [ui || svc || ifs] - Required
:run
    set "_result=false"
    if "%1" equ "" set "_result=true"
    if "%2" equ "" set "_result=true"
    if "%3" equ "" set "_result=true"
    if "%_result%" equ "true" (
        echo "Some options are missing, try again with the following options:" 
        echo "environment, version, type (ui || svc || ifs)" 
        echo "Example usage: release.bat staging 1.0.0-rc1 ui"
        goto:eof
    ) else (
        if "%1" equ "prod" ( set /a "_exp1=1" ) else ( set /a "_exp1=0")
        if "%1" equ "staging" ( set /a "_exp2=1" ) else ( set /a "_exp2=0")
        set /a "_env=_exp1 | _exp2"
        if "%_env%" equ "1" (
            echo Starting release of v%2 to %1 environment for a %3 project
            call :git_checkout_branch %1
            if "%3" equ "ifs" set "_project=non-ui"
            if "%3" equ "svc" set "_project=non-ui"
            if "%_project%" equ "non-ui" call :terraform_apply %1
            call :git_tag_and_merge %1 %2
            call :gh_release %1 %2
            echo Release cycle completed.
        ) else (
            echo "No environment specified, defaulting to the dev environment & ignoring the version spec."
        )
    ) 
exit /b 0


