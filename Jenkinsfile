pipeline {
    agent any

    stages {

        stage("build") {

            steps {
                echo 'build'
                sh '''
                uname -a
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

