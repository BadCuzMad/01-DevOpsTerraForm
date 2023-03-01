pipeline {
    agent any

    stages {

        stage("build") {

            steps {
                echo 'build'
            }
        }

        stage("test") {

            steps {
                echo 'test'
                sh '''
                aws --version
                '''
            }
        }

        stage("deploy") {

            steps {
                echo 'deploy'
            }
        }
    }
}

