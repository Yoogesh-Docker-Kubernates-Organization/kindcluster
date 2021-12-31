#!/bin/sh

################################# SETTING REPOSITORY PATH #########################
REPOSITORY="/Users/ysharma/Documents/Git/"

if [ -z "$1" ]
  then
    echo "No argument supplied. Default REPOSITORY is set to ${REPOSITORY}"
  else
    REPOSITORY=$1
    echo "REPOSITORY is set to ${REPOSITORY}"
fi
echo "Also DON'T forget to provide the extraMounts hostpath for Jenkins and mysql at config.yaml file to define storage path on your local....👀 👀 👀 👀"
#####################################################################################

# cluster variable
start_cluster="true"
enable_istio="true"

#image creation variables
create_webapp_image="false"
create_api_gateway_image="false"
create_mfe_image="false"
create_jenkins_image="false"

# deployment variables
deploy_webapp_image="true"
deploy_api_gateway_image="true"
deploy_mfe_image="true"
deploy_jenkins_image="false"

# database
run_prod_db="false"

# tracing (default will be jaeger if zipkin is not enabled manually)
enable_zipkin="false"

#canery releases
enableIstioCanery="true"
enableCaneryWithLoadBalancer="true"

# Constants
CLUSTER=${REPOSITORY}kindcluster
SPRING_BOOT_SECURITY=${REPOSITORY}springbootsecurity
MY_ACCOUNT=${REPOSITORY}my-account
REACT_MFE=${REPOSITORY}reactmfe


########################################################
# Start a kind cluster
########################################################
if ${start_cluster} eq true
then
   kind create cluster --name twm-digital --config ${CLUSTER}/config.yaml

   if ${enable_istio} eq true
   then
      # checkout the ReadMe page to see how to generate raw_settings.yaml
      istioctl install -f ${CLUSTER}/raw_settings.yaml -y
      kubectl label namespace default istio-injection=enabled --overwrite
      kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/gateway/istio-firewall.yaml

      # Addons
      kubectl apply -f ${CLUSTER}/addons/kiali.yaml
      kubectl apply -f ${CLUSTER}/addons/grafana.yaml
      kubectl apply -f ${CLUSTER}/addons/prometheus.yaml

      #At a time only one can be activated as both points the service 'tracer'
      if ${enable_zipkin} eq true
      then
         kubectl apply -f ${CLUSTER}/addons/extras/zipkin.yaml
      else
         kubectl apply -f ${CLUSTER}/addons/jaeger.yaml 
      fi
   else
      # Deploy the Kubernetes supported ingress NGINX controller to work as a reverse proxy and load balancer
      # Additionally, we can also use AWS and GCE load balancer controllers
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   fi
fi

# Mysql image
if [ ${run_prod_db} = true ]
then
   echo "⛔️ ⛔️ ⛔️ sprintbootsecurity is set to connect with MY-SQL server. Make sure you have set envTarget=prod in its webApp.yaml file...... ⛔️ ⛔️ ⛔️"
   kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/mysql/mysql_kind.yaml
   echo "Sleeping for 1 min 🌲 😴 🌲 🈯️ ✅ 💪🏽 👩🏻‍🦱 🧑🏾‍🦰"
   sleep 60
else
   echo "connecting to in-memory h2 database 🏪 🏞 🏡"
fi


########################################################
# Creating all required images into a cluster
########################################################
if ${create_jenkins_image} eq true
then
   docker image build -t myjenkins ${CLUSTER}/.
fi

# SpringbootSecurity image creation
if ${create_webapp_image} eq true
then
   mvn -f ${SPRING_BOOT_SECURITY}/pom.xml clean install
   docker image build -t yoogesh1983/springbootsecurity:latest ${SPRING_BOOT_SECURITY}/.
fi

# My-account image creation
if ${create_api_gateway_image} eq true
then
   docker image build -t yoogesh1983/my-account:latest ${MY_ACCOUNT}/.
fi

# reactmfe image creation
if ${create_mfe_image} eq true
then
   docker image build -t yoogesh1983/reactmfe:latest ${REACT_MFE}/.
fi


########################################################
# loading And deploying all required images into a cluster
########################################################

# Jenkins deployment
if ${deploy_jenkins_image} eq true
then
  kind load docker-image myjenkins --name twm-digital
  kubectl apply -f ${CLUSTER}/jenkins.yaml
fi

# SpringBootSecurity deployment
if ${deploy_webapp_image} eq true
then
  kind load docker-image yoogesh1983/springbootsecurity --name twm-digital
  kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/webapp/webApp.yaml
fi

if ${enableIstioCanery} eq true
then
  docker pull yoogesh1983/springbootsecurity:istio-risky
  kind load docker-image yoogesh1983/springbootsecurity:istio-risky --name twm-digital
  kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/webapp.yaml
fi

# my-account deployment
if ${deploy_api_gateway_image} eq true
then
  kind load docker-image yoogesh1983/my-account --name twm-digital
  kubectl apply -f ${MY_ACCOUNT}/devops/webApp.yaml
fi

# reactmfe deployment
if ${deploy_mfe_image} eq true
then
  kind load docker-image yoogesh1983/reactmfe --name twm-digital
  kubectl apply -f ${REACT_MFE}/MFE/resources/devops/k8s_aws/webApp.yaml
fi


if ${start_cluster} eq true
then
   if [ ${run_prod_db} = "false" ]
   then
      echo "Sleeping for 1 min 🌲 😴 🌲 🈯️ ✅ 💪🏽 👩🏻‍🦱 🧑🏾‍🦰"
      sleep 60
   fi
   
   if ${enable_istio} eq true
   then
           # Montoring stack virtual service deployment
           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/gateway/istio-route-monitoring.yaml

           # springbootapplcation virtual service deployment
           if ${deploy_webapp_image} eq true
           then
               if ${enableIstioCanery} eq true
               then
                 kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/destinationRule.yaml
                 if ${enableCaneryWithLoadBalancer} eq true
                 then
                    kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_canery_loadbalancer.yaml
                 else
                     if ${enableFaultInjection} eq true
                     then
                       kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/enableFaultInjection.yaml
                     else
                       kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_canery_headerParam.yaml
                     fi
                 fi
               else
                 kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/gateway/istio-route-webapp.yaml
               fi
            fi

            # my-account virtual service deployment
            if ${deploy_api_gateway_image} eq true
            then
              kubectl apply -f ${MY_ACCOUNT}/devops/istio-route-webapp.yaml
            fi

            # mfe virtual service deployment
            if ${deploy_mfe_image} eq true
            then
              kubectl apply -f ${REACT_MFE}/MFE/resources/devops/k8s_aws/istio-route-webapp.yaml
            fi
            echo "Cluster and sophisticated Istio ingress gate-way successfully started ..........👍 👍 👍"
   else
      #Nginex controller
      kubectl apply -f ${CLUSTER}/ingress.yaml
      echo "Cluster and plain kubernetes ingress controller successfully started ..........👍 👍 👍"
   fi
   
else
  echo "Re-deployment of image is done successfully ..........👍 👍 👍"
fi


