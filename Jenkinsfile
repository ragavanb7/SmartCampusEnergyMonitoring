
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Enable to test a faulty release and rollback'
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
                checkout scm
                echo 'Source code checked out successfully.'
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

                    Write-Host 'All required files are present.'
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
                        throw 'Docker is unavailable to Jenkins.'
                    }

                    Write-Host 'Docker client and server are available.'
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                powershell '''
                    $ErrorActionPreference = 'Stop'
                    $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                    $faulty = 'false'

                    if ($env:FAULTY_RELEASE -eq 'true') {
                        $faulty = 'true'
                    }

                    docker build --build-arg "FAULTY_RELEASE=$faulty" -t "${env:IMAGE_NAME}:latest" .

                    if ($LASTEXITCODE -ne 0) {
                        throw 'Docker image build failed.'
                    }

                    Write-Host "Built image: $env:IMAGE_NAME`:latest"
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

                    docker run -d --name $testName energy-health-test-image

                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not start the health test container.'
                    }

                    try {
                        $healthy = $false

                        for ($i = 0; $i -lt 15; $i++) {
                            Start-Sleep -Seconds 2

                            $response = docker exec $testName wget -q -O - http://127.0.0.1/health.html 2>$null
                            $result = ($response -join '').Trim()

                            if ($LASTEXITCODE -eq 0 -and $result -eq 'OK') {
                                $healthy = $true
                                break
                            }

                            Write-Host "Waiting for health endpoint: attempt $($i + 1)"
                        }

                        if (-not $healthy) {
                            docker logs $testName
                            throw 'Health endpoint test failed.'
                        }

                        Write-Host 'SUCCESS: Health endpoint returned OK.'
                    }
                    finally {
                        docker rm -f $testName 2>$null | Out-Null
                    }
                '''
            }
        }

        stage('Login and Push Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    powershell '''
                        $ErrorActionPreference = 'Stop'
                        $env:PATH = "$env:DOCKER_PATH;$env:PATH"

                        $env:DOCKERHUB_TOKEN | docker login -u $env:DOCKERHUB_USER --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw 'Docker Hub login failed. Check dockerhub-creds.'
                        }

                        docker push "${env:IMAGE_NAME}:latest"

                        if ($LASTEXITCODE -ne 0) {
                            throw 'Docker image push failed.'
                        }

                        Write-Host 'Docker image pushed successfully.'
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig-file',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    powershell '''
                        $ErrorActionPreference = 'Stop'
                        $env:PATH = "$env:DOCKER_PATH;$env:PATH"
                        $env:KUBECONFIG = $env:KUBECONFIG_FILE

                        kubectl get nodes

                        if ($LASTEXITCODE -ne 0) {
                            throw 'Cannot connect to Kubernetes. Check kubeconfig-file.'
                        }

                        kubectl apply -f deployment.yaml

                        if ($LASTEXITCODE -ne 0) {
                            throw 'Applying deployment.yaml failed.'
                        }

                        kubectl rollout status "deployment/$env:K8S_DEPLOYMENT" --timeout=120s

                        if ($LASTEXITCODE -ne 0) {
                            Write-Host 'Deployment rollout failed. Attempting rollback.'
                            kubectl rollout undo "deployment/$env:K8S_DEPLOYMENT"
                            throw 'Deployment rollout failed.'
                        }

                        Write-Host 'Deployment rollout succeeded.'

                        kubectl get deployments
                        kubectl get pods
                        kubectl get services

                        if ($LASTEXITCODE -ne 0) {
                            throw 'Could not retrieve Kubernetes resources.'
                        }
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Smart Campus Energy Monitoring pipeline completed.'
        }

        failure {
            echo 'FAILURE: Check the first failed stage in Console Output.'
        }

        always {
            echo 'Smart Campus Energy Monitoring pipeline finished.'
        }
    }
}
