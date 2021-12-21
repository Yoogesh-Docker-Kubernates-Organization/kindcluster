# INITIAL SETUP

> - Install <a href="https://kind.sigs.k8s.io/" target="_blank">KIND</a> and DOCKER (This application assumes that you have KIND and DOCKER already installed into you machine)
> - Open startCluster.sh that resides into this project and provide the <b>REPOSITORY_PATH</b> where all of your applications reside. Default REPOSITORY_PATH is <i>/Users/ysharma/Documents/Git/</i>
> - Open config.yaml and give proper host path for jenkins and mysql which tells where do you want to save the configuration into your local machine. Default storage path for jenkins is <i>/Users/ysharma/Documents/Kubernetes/storage/jenkins</i> whereas the default storage path for mysql is <i>/Users/ysharma/Documents/Kubernetes/storage/mysql</i>
> - springbootsecurity application has webApp.yaml that has <b>envTarget</b> field by-default set to <b>local</b>. Change that to <b>prod</b> if you want to use mysql database. Also set <b>run_prod_db="false"</b> at startCluster.sh to deply mysql into a cluster instead of running in-memory h2 database
> - Open a commandline window (type <strong>kind</strong> to verify KIND is available into your commandline) 
> - Go upto the <b>kindcluster</b> (You can do changes as per you wish at <b>startCluster.sh</b> file as this will be the main file we will be running)

# RUNNING A CLUSTER
  > <b>. ./startCluster.sh</b>
