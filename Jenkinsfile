pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Deliberately remove health.html to test rollback'
        )
    }

    environment {
        IMAGE_NAME = 'ragavanb7/smart-campus-energy'
        K8S_DEPLOYMENT = 'smart-campus-energy'
        K8S_CONTAINER = 'energy-dashboard'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                archiveArtifacts artifacts:
                    'index.html,health.html,Dockerfile,deployment.yaml',
                    fingerprint: true
            }
        }

        stage('Validate Files') {
            steps {
                powershell '''
                    $files = @(
                        "index.html",
                        "health.html",
                        "Dockerfile",
                        "deployment.yaml"
                    )

                    foreach ($file in $files) {
                        if (!(Test-Path $file)) {
                            throw "Missing project file: $file"
                        }
                    }

                    Write-Host "All project files are present."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def faulty = params.FAULTY_RELEASE ? 'true' : 'false'
                    def imageTag = "${env.IMAGE_NAME}:build-${env.BUILD_NUMBER}"

                    withEnv([
                        "FAULT_ARG=${faulty}",
                        "BUILD_IMAGE_TAG=${imageTag}"
                    ]) {
                        powershell '''
                            docker build `
                              --build-arg FAULTY_RELEASE=$env:FAULT_ARG `
                              -t $env:BUILD_IMAGE_TAG .

                            if ($LASTEXITCODE -ne 0) {
                                throw "Docker build failed."
                            }
                        '''
                    }
                }
            }
        }

        stage('Test Healthy Image') {
            steps {
                script {
                    if (!params.FAULTY_RELEASE) {
                        withEnv([
                            "TEST_IMAGE=${env.IMAGE_NAME}:build-${env.BUILD_NUMBER}"
                        ]) {
                            powershell '''
                                $name = "energy-test-$env:BUILD_NUMBER"

                                try {
                                    docker run -d `
                                      --name $name `
                                      -p 18080:80 `
                                      $env:TEST_IMAGE

                                    if ($LASTEXITCODE -ne 0) {
                                        throw "Test container failed to start."
                                    }

                                    $healthy = $false

                                    for ($i = 0; $i -lt 12; $i++) {
                                        try {
                                            $response = Invoke-WebRequest `
                                              -Uri "http://localhost:18080/health.html" `
                                              -TimeoutSec 2

                                            if ($response.StatusCode -eq 200 `
                                                -and $response.Content -match "OK") {
                                                $healthy = $true
                                                break
                                            }
                                        }
                                        catch {
                                            Start-Sleep -Seconds 2
                                        }
                                    }

                                    if (!$healthy) {
                                        throw "Health endpoint test failed."
                                    }

                                    Write-Host "Health endpoint test passed."
                                }
                                finally {
                                    docker rm -f $name 2>$null | Out-Null
                                }
                            '''
                        }
                    } else {
                        echo 'Faulty release selected. Skipping the healthy-image gate so Kubernetes can test rollback.'
                    }
                }
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )
                ]) {
                    powershell '''
                        $env:DOCKERHUB_PASSWORD |
                          docker login `
                            --username $env:DOCKERHUB_USERNAME `
                            --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub login failed."
                        }

                        docker push "$env:IMAGE_NAME`:build-$env:BUILD_NUMBER"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Image push failed."
                        }

                        if ($env:FAULTY_RELEASE -ne "true") {
                            docker tag `
                              "$env:IMAGE_NAME`:build-$env:BUILD_NUMBER" `
                              "$env:IMAGE_NAME`:latest"

                            docker push "$env:IMAGE_NAME`:latest"

                            if ($LASTEXITCODE -ne 0) {
                                throw "Latest image push failed."
                            }
                        }

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy and Verify') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    script {
                        def imageTag =
                            "${env.IMAGE_NAME}:build-${env.BUILD_NUMBER}"

                        withEnv(["DEPLOY_IMAGE=${imageTag}"]) {
                            powershell '''
                                kubectl apply -f deployment.yaml

                                if ($LASTEXITCODE -ne 0) {
                                    throw "Kubernetes manifest failed."
                                }

                                kubectl set image `
                                  deployment/$env:K8S_DEPLOYMENT `
                                  $env:K8S_CONTAINER=$env:DEPLOY_IMAGE

                                if ($LASTEXITCODE -ne 0) {
                                    throw "Failed to update deployment image."
                                }
                            '''

                            try {
                                powershell '''
                                    kubectl rollout status `
                                      deployment/$env:K8S_DEPLOYMENT `
                                      --timeout=90s

                                    if ($LASTEXITCODE -ne 0) {
                                        throw "Deployment rollout failed."
                                    }

                                    kubectl get pods `
                                      -l app=smart-campus-energy

                                    kubectl get service `
                                      smart-campus-energy-service
                                '''

                                if (params.FAULTY_RELEASE) {
                                    echo 'WARNING: Faulty release unexpectedly passed rollout checks.'
                                    currentBuild.result = 'UNSTABLE'
                                } else {
                                    echo 'Deployment completed successfully.'
                                }
                            }
                            catch (err) {
                                echo "Deployment failed: ${err}"
                                echo 'Attempting automatic rollback.'

                                powershell '''
                                    kubectl rollout undo `
                                      deployment/$env:K8S_DEPLOYMENT

                                    if ($LASTEXITCODE -ne 0) {
                                        throw "Rollback command failed."
                                    }

                                    kubectl rollout status `
                                      deployment/$env:K8S_DEPLOYMENT `
                                      --timeout=90s

                                    if ($LASTEXITCODE -ne 0) {
                                        throw "Rollback did not become healthy."
                                    }

                                    kubectl get pods `
                                      -l app=smart-campus-energy
                                '''

                                currentBuild.result = 'UNSTABLE'

                                echo 'Rollback completed. The failed release was not marked as a successful deployment.'
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline execution finished. Review the console log.'
        }
    }
}