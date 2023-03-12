pipeline {
    agent any

    stages {
        
        stage('Checking out git repo') {
			steps {
				checkout([$class: 'GitSCM', branches: [[name: '*/main']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '51f9ae74-588b-4dba-b0dd-f3acf714548c', url: 'https://github.com/BadCuzMad/01-DevOpsTerraForm.git']]])
			}
		}

        stage("build") {

            steps {
                echo 'build'
                sh '''
                ls -al
                '''
            }
        }

        stage("test") {

            steps {
                echo 'test'
            }
        }

        stage("deploy") {

            steps {
                echo 'deploy'
            }
        }
    }
}

