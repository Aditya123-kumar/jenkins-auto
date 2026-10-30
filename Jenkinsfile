
pipeline {
    agent any

    environment {
        IMAGE = "localhost:5000/rollback-app"
        CONTAINER_NAME = "jenkins-rollback-app"
    }

    stages {

        stage('Prepare Versions') {
            steps {
                script {
                    // First Jenkins build creates V2
                    env.NEW_TAG = "v${env.BUILD_NUMBER.toInteger() + 1}"

                    def exists = bat(
                        script: '@echo off\r\ndocker inspect jenkins-rollback-app >NUL 2>&1',
                        returnStatus: true
                    )

                    if (exists == 0) {
                        env.PREVIOUS_IMAGE = bat(
                            script: '@echo off\r\ndocker inspect --format "{{.Config.Image}}" jenkins-rollback-app',
                            returnStdout: true
                        ).trim()

                        env.PREVIOUS_TAG =
                            env.PREVIOUS_IMAGE.substring(
                                env.PREVIOUS_IMAGE.lastIndexOf(':') + 1
                            )
                    } else {
                        env.PREVIOUS_TAG = "v1"
                    }

                    echo "Previous Version: ${env.PREVIOUS_TAG}"
                    echo "New Version: ${env.NEW_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    docker build -t %IMAGE%:%NEW_TAG% .
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Push to Private Registry') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASSWORD'
                    )
                ]) {
                    bat '''
                        @echo off

                        powershell -NoProfile -Command "$env:REGISTRY_PASSWORD | docker login localhost:5000 --username $env:REGISTRY_USER --password-stdin"
                        if errorlevel 1 exit /b 1

                        docker push %IMAGE%:%NEW_TAG%
                        if errorlevel 1 exit /b 1

                        docker logout localhost:5000
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
                            passwordVariable: 'REGISTRY_PASSWORD'
                        )
                    ]) {

                        bat '''
                            @echo off

                            powershell -NoProfile -Command "$env:REGISTRY_PASSWORD | docker login localhost:5000 --username $env:REGISTRY_USER --password-stdin"
                            if errorlevel 1 exit /b 1
                        '''

                        try {
                            bat '''
                                @echo off

                                echo Deploying new version: %NEW_TAG%

                                docker pull %IMAGE%:%NEW_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%NEW_TAG%

                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 8 /nobreak >NUL

                                curl.exe -fsS http://localhost:8085/ | findstr /I /C:"Application Version %NEW_TAG%"
                                if errorlevel 1 exit /b 1
                            '''

                            echo "Deployment Successful: ${env.NEW_TAG}"

                        } catch (Exception e) {

                            echo "Deployment Failed!"
                            echo "Starting Automatic Rollback..."

                            bat '''
                                @echo off

                                echo Restoring previous version: %PREVIOUS_TAG%

                                docker pull %IMAGE%:%PREVIOUS_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%PREVIOUS_TAG%

                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 8 /nobreak >NUL

                                curl.exe -fsS http://localhost:8085/ | findstr /I /C:"Application Version %PREVIOUS_TAG%"
                                if errorlevel 1 exit /b 1
                            '''

                            echo "Rollback Successful: ${env.PREVIOUS_TAG}"

                            error("Deployment Failed - Previous Version Restored")

                        } finally {
                            bat 'docker logout localhost:5000'
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline Completed Successfully!'
        }

        failure {
            echo 'CI/CD Pipeline Failed. Check Console Output.'
        }
    }
}
s