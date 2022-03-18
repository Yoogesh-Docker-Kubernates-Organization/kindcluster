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
start_cluster=true
enable_istio=false

#image creation variables
create_webapp_image=true
create_jrni_image=false
create_api_gateway_image=false
create_mfe_image=false
create_jenkins_image=false

# deployment variables
deploy_webapp_image=true
deploy_jrni_image=false
deploy_api_gateway_image=false
deploy_mfe_image=false
deploy_jenkins_image=false

# database
run_prod_db=true
use_mongo=true

#------------- Istio related configuration  : Start -----------------#
enable_kiali=true
enable_grafana=false

#tracer [only one can be applied at a time]
enable_jaeger=false
enable_zipkin=false

#canery releases [only one can be applied at a time]
enableCaneryWithLoadBalancer=false   # This will redirect 60% trafic to riskey version whereas 40% traffic to the current prod version (safe version). Drawback of this approach is that it doesn't have session stickeyness and hence we cannot control which version the request should go to
enableCaneryWithStickey=false        # Unlike above, here the single user can stick with the same version depending on which version he/she got first. For this he needs to pass "my-access-token=${randomValue}" from mod-header
enableCaneryWithHeaderparam=false    # This is a sophiscicated version of enableCaneryWithLoadBalancer where we can decide whether to do a loadbalancer or send all 100% traffic to just one version and this can be decided by the header param we passed
enableFaultInjection=false            # This will always redirects testers to the canery version (riskey version) only the header parameter "x-istio-header=canery" is set. However this riskey page will only be loaded after 20 sec delay. BTW if we don't use header param, it will always fallback to safe version

#circuit breaker
enableCircuitBreaker=true
#------------- Istio related configuration  : End -----------------#


# Constants
CLUSTER=${REPOSITORY}kindcluster
SPRING_BOOT_SECURITY_PARENT=${REPOSITORY}springbootsecurity-parent
SPRING_BOOT_SECURITY=${SPRING_BOOT_SECURITY_PARENT}/springbootsecurity
JRNI=${REPOSITORY}springbootsecurity-parent/jrni
MY_ACCOUNT=${REPOSITORY}my-account
REACT_MFE=${REPOSITORY}reactmfe

# Setting some values dynamically
##################################
enableIstioCanery=false
enable_prometheus=false
if ${enable_istio} eq true
then
    if ${enableCaneryWithHeaderparam} eq true || ${enableCaneryWithLoadBalancer} eq true || ${enableFaultInjection} eq true || ${enableCaneryWithStickey} eq true
    then
       if ${deploy_webapp_image} eq true
       then
           enableIstioCanery=true
       fi
    fi

    if ${enable_kiali} eq true || ${enable_grafana} eq true 
    then
       enable_prometheus=true
    fi
fi


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

      # Addons
      if ${enable_prometheus} eq true
      then
         kubectl apply -f ${CLUSTER}/addons/prometheus.yaml
      fi
      if ${enable_kiali} eq true
      then
          kubectl apply -f ${CLUSTER}/addons/kiali.yaml
      fi
      if ${enable_grafana} eq true
      then
         kubectl apply -f ${CLUSTER}/addons/grafana.yaml
      fi

      #At a time only one can be activated as both points the service 'tracer'
      if ${enable_jaeger} eq true
      then
         kubectl apply -f ${CLUSTER}/addons/jaeger.yaml 
      else if ${enable_zipkin} eq true
      then
         kubectl apply -f ${CLUSTER}/addons/extras/zipkin.yaml
      fi
      fi
   else
      # Deploy the Kubernetes supported ingress NGINX controller to work as a reverse proxy and load balancer
      # Additionally, we can also use AWS and GCE load balancer controllers
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   fi
fi


# Mysql image
if ${run_prod_db} eq true
then
   if ${use_mongo} eq true
   then
      kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/mongo/mongo_kind.yaml
      echo "Sleeping 30 second for MONGO-DB startup 🌲 😴 🌲 🈯️ ✅ 💪🏽 👩🏻‍🦱 🧑🏾‍🦰"
      sleep 30
   else
      kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/mysql/mysql_kind.yaml
      echo "Sleeping 1 min 40 second for MY-SQL startup 🌲 😴 🌲 🈯️ ✅ 💪🏽 👩🏻‍🦱 🧑🏾‍🦰"
      sleep 100    
   fi
else
   echo "⛔️ ⛔️ ⛔️ sprintbootsecurity is set to connect with IN-MEMORY h2 database and this is not a production standard. You must set run_prod_db=true to use my-sql or MONGO_DB when deploying in production environment ⛔️ ⛔️ ⛔️"
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
   mvn -f ${SPRING_BOOT_SECURITY_PARENT}/pom.xml clean install
   docker image build -t yoogesh1983/springbootsecurity:latest ${SPRING_BOOT_SECURITY}/.
fi

# Jrni image creation
if ${create_jrni_image} eq true
then
   mvn -f ${JRNI}/pom.xml clean install
   docker image build -t yoogesh1983/jrni:latest ${JRNI}/.
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
  export ENV_TARGET=local
  export ENV_DATABASE=h2
  
  if ${run_prod_db} eq true
  then
     ENV_TARGET=prod
     if ${use_mongo} eq true
     then
       ENV_DATABASE=mongo
     else
       ENV_DATABASE=my-sql
     fi
  fi

  kind load docker-image yoogesh1983/springbootsecurity --name twm-digital
  kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/configmap/secretTree.yaml
  envsubst < ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/webapp/webApp.yaml | kubectl apply -f -
fi

# SpringBootSecurity canery deployment
if ${enableIstioCanery} eq true
then
      # As we are directly pulling the image from docker hub, we don't need below two lines
      #docker pull yoogesh1983/springbootsecurity:istio-risky
      #kind load docker-image yoogesh1983/springbootsecurity:istio-risky --name twm-digital
      kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/webapp.yaml
fi

# Jrni deployment
if ${deploy_jrni_image} eq true
then
  export ENV_TARGET=prod
  kind load docker-image yoogesh1983/jrni --name twm-digital
  envsubst < ${JRNI}/src/main/resources/devops/k8s_aws/webapp/webApp.yaml | kubectl apply -f -
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
           # Setting up fire-wall for istio-ingress controller
           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/gateway/istio-firewall.yaml

           # Montoring stack virtual service deployment
           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/gateway/istio-route-monitoring.yaml

           # Enable circuit breaker
           if ${enableCircuitBreaker} eq true
           then
              kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/circuitBreaking/istio_circuit_breaking.yaml
           fi

           # springbootapplcation virtual service deployment
           if ${deploy_webapp_image} eq true
           then
               if ${enableIstioCanery} eq true
               then
                     if ${enableCaneryWithStickey} eq true
                     then
                           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/destinationRule_stickey.yaml
                           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_stickey.yaml
                     else
                           kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/destinationRule.yaml
                           if ${enableCaneryWithLoadBalancer} eq true
                           then
                              kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_canery_loadbalancer.yaml
                           else if ${enableCaneryWithHeaderparam} eq true
                           then
                              kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_canery_headerParam.yaml
                           else if ${enableFaultInjection} eq true  
                           then
                              kubectl apply -f ${SPRING_BOOT_SECURITY}/src/main/resources/devops/k8s_aws/istio/canery/vs_fault_injection.yaml
                           fi
                           fi
                           fi
                     fi
               else
                 # No destinationRule is required when not using canery as we will not required to do Load balancer here since only one version of pod is running in this case
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
            echo "Cluster and sophisticated Istio ingress gate-way successfully started and is available at port 80..........👍 👍 👍"
   else
      #Nginex controller
      kubectl apply -f ${CLUSTER}/ingress.yaml
      echo "Cluster and plain kubernetes ingress controller successfully started and is available at port 32000 ..........👍 👍 👍"
   fi
   
else
  echo "Re-deployment of image is done successfully ..........👍 👍 👍"
fi

