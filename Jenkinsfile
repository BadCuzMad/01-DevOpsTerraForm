pipeline {
    agent any

    stages {

        stage("build") {

            steps {
                echo 'build'
                sh '''
                terraform init
                terraform fmt -check
                terraform plan -input=false
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

