
pipeline {
    agent any

    environment {
        IMAGE_NAME = "localhost:5000/rollback-app"
        CONTAINER_NAME = "jenkins-rollback-app"
        APP_PORT = "8085"
        REGISTRY_URL = "localhost:5000"
        ROLLBACK_TAG = "rollback"
        INITIAL_TAG = "v8"
    }

    stages {

        stage('Prepare Version') {
            steps {
                script {
                    env.NEW_TAG = "v${env.BUILD_NUMBER.toInteger() + 1}"
                    echo "New Version: ${env.NEW_TAG}"
                }
            }
        }

        stage('Login and Initialize Rollback') {
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

                    script {
                        def result = bat(
                            returnStatus: true,
                            script: 'docker pull %IMAGE_NAME%:%ROLLBACK_TAG%'
                        )

                        if (result != 0) {
                            echo "Initializing rollback image from v8"

                            bat '''
                                docker pull %IMAGE_NAME%:%INITIAL_TAG%
                                if errorlevel 1 exit /b 1

                                docker tag %IMAGE_NAME%:%INITIAL_TAG% %IMAGE_NAME%:%ROLLBACK_TAG%

                                docker push %IMAGE_NAME%:%ROLLBACK_TAG%
                                if errorlevel 1 exit /b 1
                            '''
                        }
                    }
                }
            }
        }

        stage('Create Dockerfile and Build') {
            steps {
                script {
                    writeFile(
                        file: 'app/Dockerfile',
                        text: '''FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
'''
                    )
                }

                bat '''
                    @echo off
                    echo Building Docker image...

                    docker build -t %IMAGE_NAME%:%NEW_TAG% -f app\\Dockerfile app

                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Push Image') {
            steps {
                bat '''
                    @echo off
                    docker push %IMAGE_NAME%:%NEW_TAG%
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Deploy and Automatic Rollback') {
            steps {
                script {
                    try {

                        bat '''
                            @echo off

                            docker pull %IMAGE_NAME%:%NEW_TAG%
                            if errorlevel 1 exit /b 1

                            docker rm -f %CONTAINER_NAME% 2>NUL

                            docker run -d --restart unless-stopped --name %CONTAINER_NAME% -p %APP_PORT%:80 %IMAGE_NAME%:%NEW_TAG%

                            if errorlevel 1 exit /b 1
                        '''

                        bat '''
                            powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                        '''

                        echo "Checking new application health..."

                        bat '''
                            powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version' -or $r.Content -match 'faulty deployment') { exit 1 }"

                            if errorlevel 1 exit /b 1
                        '''

                        echo "NEW DEPLOYMENT SUCCESSFUL!"

                        // Update rollback image only after successful health check.

                        bat '''
                            docker tag %IMAGE_NAME%:%NEW_TAG% %IMAGE_NAME%:%ROLLBACK_TAG%
                            if errorlevel 1 exit /b 1

                            docker push %IMAGE_NAME%:%ROLLBACK_TAG%
                            if errorlevel 1 exit /b 1
                        '''

                        echo "Previous-version backup updated successfully."

                    } catch (Exception e) {

                        echo "NEW DEPLOYMENT FAILED!"
                        echo "STARTING AUTOMATIC ROLLBACK!"

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

                        echo "Verifying previous working version..."

                        bat '''
                            powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri 'http://localhost:8085/' -UseBasicParsing; if ($r.StatusCode -ne 200 -or $r.Content -notmatch 'Application Version' -or $r.Content -match 'faulty deployment') { exit 1 }"

                            if errorlevel 1 exit /b 1
                        '''

                        echo "AUTOMATIC ROLLBACK SUCCESSFUL!"

                        error("Deployment failed. Previous working version restored.")
                    }
                }
            }
        }
    }

    post {
        always {
            bat '''
                docker logout %REGISTRY_URL%
            '''
        }

        success {
            echo "PIPELINE SUCCESSFUL!"
        }

        failure {
            echo "PIPELINE FAILED. CHECK LOGS."
        }
    }
}
