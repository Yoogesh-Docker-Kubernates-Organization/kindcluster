# Initial Setup

> - Install <a href="https://kind.sigs.k8s.io/" target="_blank">KIND</a> and DOCKER (This application assumes that you have KIND and DOCKER already installed into you machine)
> - Open startCluster.sh that resides into this project and provide the <b>REPOSITORY_PATH</b> where all of your applications reside. Default REPOSITORY_PATH is <i>/Users/ysharma/Documents/Git/</i>
> - Open config.yaml and give proper host path for jenkins and mysql which tells where do you want to save the configuration into your local machine. Default storage path for jenkins is <i>/Users/ysharma/Documents/Kubernetes/storage/jenkins</i> whereas the default storage path for mysql is <i>/Users/ysharma/Documents/Kubernetes/storage/mysql</i>
> - springbootsecurity application has webApp.yaml that has <b>envTarget</b> field by-default set to <b>local</b>. Change that to <b>prod</b> if you want to use mysql database. Also set <b>run_prod_db="true"</b> at startCluster.sh to deply mysql into a cluster instead of running in-memory h2 database
> - Open a commandline window (type <strong>kind</strong> to verify KIND is available into your commandline) 
> - Go upto the <b>kindcluster</b> folder to start a cluster(You can do changes as per your requirement at <b>startCluster.sh</b> file as this will be the main file we will be running)

# Running a Cluster
  > <b>. ./startCluster.sh</b>

# Enable Istio
> - Get a latest binary and put into a classpath. The <b>istioctl</b> command should work after this
> - Traditionally the command <b>istioctl manifest apply --set profile=demo -y</b> should work fine if you are using cloud environment. however, it doesn't work on <strong>kind</strong> cluster as kind doesn't have external <strong>Loadbalancer</strong> running on it and hence it doesn't recognise the LoadBalanced <strong>istio ingress controller</strong>. So for workaround you should change the type to <b>NodePort</b> from <strong>Loadbalancer</strong> and for this we should modify the default istio file. Use below command to generate istio yaml file:

   > <b><i>istioctl profile dump demo > raw_settings.yaml</i></b>

> - The above step generates the raw istio yaml file. You can open the file and change the 
<b>Loadbalancer</b> to <b>Nodeport</b> and also mention the ports to <strong>config.yaml</strong> file
> - You can now use below command to e

   > <b><i>istioctl install -f raw_settings.yaml -y</i></b> </br>
   > <b><i>kubectl label namespace default istio-injection=enabled --overwrite</i></b>

> - Make sure Istio changes version to version. So you need to geneate new raw_settings.yaml every time the istioctl version changes. You cannot use old <b>raw_settings.yaml</b> for new version of <strong>Istio</strong> i.e. istioctl 

