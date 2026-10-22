
pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Simulate a faulty release to test rollback'
        )
    }

    environment {
        IMAGE_NAME = 'ragavanb7/smart-campus-energy'
        K8S_DEPLOYMENT = 'smart-campus-energy'
        K8S_CONTAINER = 'energy-dashboard'
        DOCKER_PATH = 'C:\\Users\\ragav\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Source code checked out by Jenkins SCM.'
            }
        }

        stage('Validate Files') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'

                    $requiredFiles = @(
                        'index.html',
                        'health.html',
                        'Dockerfile',
                        'deployment.yaml',
                        'Jenkinsfile'
                    )

                    foreach ($file in $requiredFiles) {
                        if (-not (Test-Path $file)) {
                            throw "Required file missing: $file"
                        }
                        Write-Host "Found: $file"
                    }
                '''
            }
        }

        stage('Check Docker') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                    docker version
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Docker is not available to the Jenkins service.'
                    }
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                    if ("$env:FAULTY_RELEASE" -eq 'true') {
                        docker build --build-arg FAULTY_RELEASE=true -t "$env:IMAGE_NAME`:latest" .
                    } else {
                        docker build --build-arg FAULTY_RELEASE=false -t "$env:IMAGE_NAME`:latest" .
                    }

                    if ($LASTEXITCODE -ne 0) {
                        throw 'Docker image build failed.'
                    }
                '''
            }
        }

        stage('Test Healthy Image') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                    $testName = 'energy-health-test'
                    docker rm -f $testName 2>$null | Out-Null

                    docker build --build-arg FAULTY_RELEASE=false -t energy-health-test-image .
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not build the healthy test image.'
                    }

                    docker run -d --name $testName -p 18080:80 energy-health-test-image
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not start the health test container.'
                    }

                    try {
                        $healthy = $false

                        for ($i = 0; $i -lt 10; $i++) {
                            Start-Sleep -Seconds 2
                            try {
                                $response = Invoke-WebRequest -Uri 'http://localhost:18080/health.html' -UseBasicParsing
                                if ($response.StatusCode -eq 200 -and $response.Content.Trim() -eq 'OK') {
                                    $healthy = $true
                                    break
                                }
                            } catch {
                                Write-Host 'Waiting for health endpoint...'
                            }
                        }

                        if (-not $healthy) {
                            throw 'Health endpoint test failed.'
                        }

                        Write-Host 'Health endpoint returned OK.'
                    }
                    finally {
                        docker rm -f $testName 2>$null | Out-Null
                    }
                '''
            }
        }

        stage('Login and Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_TOKEN'
                )]) {
                    powershell '''
                        $ErrorActionPreference = 'Stop'
                        $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                        $env:DOCKERHUB_TOKEN | docker login -u $env:DOCKERHUB_USER --password-stdin
                        if ($LASTEXITCODE -ne 0) {
                            throw 'Docker Hub login failed. Check dockerhub-creds.'
                        }

                        docker push "$env:IMAGE_NAME`:latest"
                        if ($LASTEXITCODE -ne 0) {
                            throw 'Docker image push failed.'
                        }

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(
                    credentialsId: 'kubeconfig-file',
                    variable: 'KUBECONFIG_FILE'
                )]) {
                    powershell '''
                        $ErrorActionPreference = 'Stop'
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE
                        $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                        kubectl apply -f deployment.yaml
                        if ($LASTEXITCODE -ne 0) {
                            throw 'Kubernetes manifest apply failed.'
                        }

                        kubectl rollout status deployment/$env:K8S_DEPLOYMENT --timeout=120s
                        if ($LASTEXITCODE -ne 0) {
                            Write-Host 'Deployment rollout failed; attempting rollback.'
                            kubectl rollout undo deployment/$env:K8S_DEPLOYMENT
                            throw 'Deployment rollout failed.'
                        }

                        kubectl get deployments
                        kubectl get pods
                        kubectl get services
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review the first error in Console Output.'
        }
        always {
            echo 'Smart Campus Energy Monitoring pipeline finished.'
        }
    }
}
