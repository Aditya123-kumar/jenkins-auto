
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        IMAGE_NAME = "localhost:5000/rollback-app"
        REGISTRY_URL = "localhost:5000"
        CONTAINER_NAME = "jenkins-rollback-app"
        APP_PORT = "8085"
        APP_VERSION = "v4"
        ROLLBACK_TAG = "rollback"
    }

    stages {

        stage('Validate V4 Source') {
            steps {
                bat '''
                    @echo off

                    if not exist app\\index.html exit /b 1
                    if not exist app\\Dockerfile exit /b 1

                    findstr /C:"Application Version V4" app\\index.html
                    if errorlevel 1 exit /b 1

                    findstr /C:"Status: HEALTHY" app\\index.html
                    if errorlevel 1 exit /b 1

                    echo V4 source validation successful.
                '''
            }
        }

        stage('Login to Private Registry') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )
                ]) {
                    bat '''
                        @echo off

                        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$env:REGISTRY_PASS | docker login $env:REGISTRY_URL --username $env:REGISTRY_USER --password-stdin; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"

                        if errorlevel 1 exit /b 1

                        echo Registry login successful.
                    '''
                }
            }
        }

        stage('Backup Previous Healthy V4') {
            steps {
                bat '''
                    @echo off

                    docker pull %IMAGE_NAME%:%APP_VERSION%
                    if errorlevel 1 exit /b 1

                    docker tag %IMAGE_NAME%:%APP_VERSION% %IMAGE_NAME%:%ROLLBACK_TAG%
                    if errorlevel 1 exit /b 1

                    docker push %IMAGE_NAME%:%ROLLBACK_TAG%
                    if errorlevel 1 exit /b 1

                    echo Previous healthy V4 backup completed.
                '''
            }
        }

        stage('Build V4 Image') {
            steps {
                bat '''
                    @echo off

                    docker build -t %IMAGE_NAME%:%APP_VERSION% -f app\\Dockerfile app

                    if errorlevel 1 exit /b 1

                    echo V4 Docker image built successfully.
                '''
            }
        }

        stage('Push V4 Image') {
            steps {
                bat '''
                    @echo off

                    docker push %IMAGE_NAME%:%APP_VERSION%

                    if errorlevel 1 exit /b 1

                    echo V4 image pushed successfully.
                '''
            }
        }

        stage('Deploy V4 and Automatic Rollback') {
            steps {
                bat '''
                    @echo off

                    echo Pulling V4 image...

                    docker pull %IMAGE_NAME%:%APP_VERSION%
                    if errorlevel 1 exit /b 1

                    echo Removing previous application container...

                    docker rm -f %CONTAINER_NAME% >NUL 2>&1

                    echo Starting V4 application...

                    docker run -d --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%APP_VERSION%

                    if errorlevel 1 goto rollback

                    timeout /t 10 /nobreak >NUL

                    echo Checking V4 application health...

                    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version V4' -or $r.Content -notmatch 'Status: HEALTHY') { exit 1 }; Write-Host 'V4 health check passed.'; exit 0 } catch { Write-Host $_; exit 1 }"

                    if not errorlevel 1 goto healthy

                    :rollback

                    echo V4 deployment failed. Starting automatic rollback...

                    docker rm -f %CONTAINER_NAME% >NUL 2>&1

                    docker pull %IMAGE_NAME%:%ROLLBACK_TAG%
                    if errorlevel 1 exit /b 1

                    docker run -d --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%ROLLBACK_TAG%
                    if errorlevel 1 exit /b 1

                    timeout /t 10 /nobreak >NUL

                    echo Checking rollback application health...

                    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version V4' -or $r.Content -notmatch 'Status: HEALTHY') { exit 1 }; Write-Host 'Rollback health check passed.'; exit 0 } catch { Write-Host $_; exit 1 }"

                    if errorlevel 1 exit /b 1

                    echo AUTOMATIC ROLLBACK SUCCESSFUL.
                    exit /b 1

                    :healthy

                    echo V4 DEPLOYED SUCCESSFULLY.
                '''
            }
        }
    }

    post {
        always {
            bat '''
                @echo off
                docker logout %REGISTRY_URL% >NUL 2>&1
            '''
        }

        success {
            echo 'SUCCESS: V4 application deployed and healthy.'
        }

        failure {
            echo 'PIPELINE FAILED - CHECK JENKINS CONSOLE LOG.'
        }
    }
}
