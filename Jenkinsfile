
pipeline {
    agent any

    environment {
        IMAGE = 'localhost:5000/rollback-app'
        CONTAINER = 'jenkins-rollback-app'
        REGISTRY_CREDENTIALS = 'registry-creds'
        APP_PORT = '8085'
    }

    stages {

        stage('Prepare Versions') {
            steps {
                script {
                    def previousTag = 'v1'

                    def containerExists = bat(
                        script: 'docker inspect %CONTAINER% >nul 2>&1',
                        returnStatus: true
                    ) == 0

                    if (containerExists) {
                        def currentImage = bat(
                            script: 'docker inspect --format="{{.Config.Image}}" %CONTAINER%',
                            returnStdout: true
                        ).trim()

                        def matcher = currentImage =~ /:(v\d+)$/

                        if (matcher.find()) {
                            previousTag = matcher.group(1)
                        }
                    }

                    def versionNumber = previousTag.replace('v', '').toInteger()
                    def newTag = "v${versionNumber + 1}"

                    env.PREVIOUS_TAG = previousTag
                    env.NEW_TAG = newTag

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
                        credentialsId: "${REGISTRY_CREDENTIALS}",
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASSWORD'
                    )
                ]) {
                    bat '''
                        docker login localhost:5000 -u "%REGISTRY_USER%" -p "%REGISTRY_PASSWORD%"
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
                    try {
                        withCredentials([
                            usernamePassword(
                                credentialsId: "${REGISTRY_CREDENTIALS}",
                                usernameVariable: 'REGISTRY_USER',
                                passwordVariable: 'REGISTRY_PASSWORD'
                            )
                        ]) {
                            bat '''
                                docker login localhost:5000 -u "%REGISTRY_USER%" -p "%REGISTRY_PASSWORD%"
                                if errorlevel 1 exit /b 1

                                docker pull %IMAGE%:%NEW_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%NEW_TAG%
                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 10 /nobreak

                                curl.exe -fsS http://localhost:%APP_PORT%/ -o healthcheck.html
                                if errorlevel 1 exit /b 1

                                findstr /i /c:"Application Version %NEW_TAG%" healthcheck.html
                                if errorlevel 1 exit /b 1

                                docker logout localhost:5000
                            '''
                        }

                        echo "Deployment Successful: ${env.NEW_TAG}"

                    } catch (Exception e) {

                        echo "Deployment Failed: ${env.NEW_TAG}"
                        echo "Starting Rollback to ${env.PREVIOUS_TAG}"

                        withCredentials([
                            usernamePassword(
                                credentialsId: "${REGISTRY_CREDENTIALS}",
                                usernameVariable: 'REGISTRY_USER',
                                passwordVariable: 'REGISTRY_PASSWORD'
                            )
                        ]) {
                            bat '''
                                docker login localhost:5000 -u "%REGISTRY_USER%" -p "%REGISTRY_PASSWORD%"
                                if errorlevel 1 exit /b 1

                                docker pull %IMAGE%:%PREVIOUS_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%PREVIOUS_TAG%
                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 10 /nobreak

                                curl.exe -fsS http://localhost:%APP_PORT%/ -o healthcheck.html
                                if errorlevel 1 exit /b 1

                                findstr /i /c:"Application Version %PREVIOUS_TAG%" healthcheck.html
                                if errorlevel 1 exit /b 1

                                docker logout localhost:5000
                            '''
                        }

                        echo "Rollback Successful: ${env.PREVIOUS_TAG}"
                        throw e
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed. Check deployment and rollback logs.'
        }
    }
}
