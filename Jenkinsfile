
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

                        echo %REGISTRY_PASS% | docker login %REGISTRY_URL% -u "%REGISTRY_USER%" --password-stdin

                        if errorlevel 1 exit /b 1
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

                    echo Healthy V4 backup saved.
                '''
            }
        }

        stage('Build V4 Image') {
            steps {
                bat '''
                    @echo off

                    docker build -t %IMAGE_NAME%:%APP_VERSION% -f app\\Dockerfile app

                    if errorlevel 1 exit /b 1

                    echo V4 image built successfully.
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
                script {
                    try {

                        echo "Deploying V4 application..."

                        bat '''
                            @echo off

                            docker pull %IMAGE_NAME%:%APP_VERSION%
                            if errorlevel 1 exit /b 1

                            docker rm -f %CONTAINER_NAME% 2>NUL

                            docker run -d --restart unless-stopped --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%APP_VERSION%

                            if errorlevel 1 exit /b 1
                        '''

                        bat '''
                            powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                        '''

                        echo "Checking V4 application health..."

                        bat '''
                            @echo off

                            powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $r=Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version V4' -or $r.Content -notmatch 'Status: HEALTHY') { exit 1 }"

                            if errorlevel 1 exit /b 1
                        '''

                        echo "V4 DEPLOYMENT SUCCESSFUL!"
                        echo "Application is healthy on port 8085."

                    } catch (Exception e) {

                        echo "V4 DEPLOYMENT FAILED!"
                        echo "STARTING AUTOMATIC ROLLBACK..."

                        bat '''
                            @echo off

                            docker rm -f %CONTAINER_NAME% 2>NUL

                            docker pull %IMAGE_NAME%:%ROLLBACK_TAG%
                            if errorlevel 1 exit /b 1

                            docker run -d --restart unless-stopped --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%ROLLBACK_TAG%

                            if errorlevel 1 exit /b 1
                        '''

                        bat '''
                            powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                        '''

                        echo "Verifying restored application..."

                        bat '''
                            @echo off

                            powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $r=Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version V4' -or $r.Content -notmatch 'Status: HEALTHY') { exit 1 }"

                            if errorlevel 1 exit /b 1
                        '''

                        echo "AUTOMATIC ROLLBACK SUCCESSFUL!"

                        error("V4 deployment failed. Previous healthy V4 restored.")
                    }
                }
            }
        }
    }

    post {
        always {
            bat '''
                @echo off
                docker logout %REGISTRY_URL% >NUL 2>&1
                exit /b 0
            '''
        }

        success {
            echo "PIPELINE SUCCESSFUL - V4 IS RUNNING!"
        }

        failure {
            echo "PIPELINE FAILED - CHECK JENKINS CONSOLE LOG."
        }
    }
}
