
pipeline {
    agent any

    environment {
        IMAGE_NAME = "localhost:5000/rollback-app"
        CONTAINER_NAME = "jenkins-rollback-app"
        APP_PORT = "8085"
        REGISTRY_URL = "localhost:5000"
    }

    stages {

        stage('Prepare Versions') {
            steps {
                script {
                    env.PREVIOUS_TAG = "v${env.BUILD_NUMBER}"
                    env.NEW_TAG = "v${env.BUILD_NUMBER.toInteger() + 1}"

                    echo "Previous Version: ${env.PREVIOUS_TAG}"
                    echo "New Version: ${env.NEW_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    docker build -t %IMAGE_NAME%:%NEW_TAG% -f app\\Dockerfile app
                '''
            }
        }

        stage('Push Image to Private Registry') {
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

                        docker push %IMAGE_NAME%:%NEW_TAG%
                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        stage('Deploy and Health Check') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'registry-creds',
                            usernameVariable: 'REGISTRY_USER',
                            passwordVariable: 'REGISTRY_PASS'
                        )
                    ]) {
                        try {
                            bat '''
                                @echo off

                                echo Logging into Private Registry...
                                echo %REGISTRY_PASS% | docker login %REGISTRY_URL% -u "%REGISTRY_USER%" --password-stdin
                                if errorlevel 1 exit /b 1

                                echo Pulling new image...
                                docker pull %IMAGE_NAME%:%NEW_TAG%
                                if errorlevel 1 exit /b 1

                                echo Removing old container...
                                docker rm -f %CONTAINER_NAME% 2>NUL

                                echo Deploying new version...
                                docker run -d --restart unless-stopped --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%NEW_TAG%
                                if errorlevel 1 exit /b 1
                            '''

                            bat '''
                                @echo off
                                echo Waiting for application...
                                powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                            '''

                            bat '''
                                @echo off
                                echo Checking application health...

                                powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version %NEW_TAG%') { exit 1 }"
                                if errorlevel 1 exit /b 1
                            '''

                            echo "Deployment successful: ${env.NEW_TAG}"

                        } catch (Exception deploymentError) {

                            echo "NEW DEPLOYMENT FAILED!"
                            echo "Starting automatic rollback..."

                            bat '''
                                @echo off

                                echo Removing faulty container...
                                docker rm -f %CONTAINER_NAME% 2>NUL

                                echo Pulling previous working image...
                                docker pull %IMAGE_NAME%:%PREVIOUS_TAG%
                                if errorlevel 1 exit /b 1

                                echo Restoring previous version...
                                docker run -d --restart unless-stopped --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%PREVIOUS_TAG%
                                if errorlevel 1 exit /b 1
                            '''

                            bat '''
                                @echo off

                                echo Waiting for rollback application...
                                powershell -NoProfile -Command "Start-Sleep -Seconds 10"

                                echo Verifying rollback...
                                powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version %PREVIOUS_TAG%') { exit 1 }"
                                if errorlevel 1 exit /b 1
                            '''

                            echo "ROLLBACK SUCCESSFUL: ${env.PREVIOUS_TAG}"

                            error("New deployment failed. Previous version restored successfully.")
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            bat '''
                @echo off
                docker logout %REGISTRY_URL%
            '''
        }

        success {
            echo "PIPELINE SUCCESSFUL - NEW VERSION DEPLOYED!"
        }

        failure {
            echo "PIPELINE FAILED - CHECK DEPLOYMENT OR ROLLBACK LOGS."
        }
    }
}
