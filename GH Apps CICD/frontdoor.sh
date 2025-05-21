export AZ_USER="rooliva@microsoft.com"           
export AZ_RG="arogbbwestus3"                
export AZ_ARO="aroclustergbb"          
export AZ_LOCATION="weastus3"                 
export UNIQUE="$(openssl rand -hex 4)"      


export CUSTOM_DOMAIN="${AZ_USER}.apps.arolatamgbb.jaropro.net" 
export FRONTDOOR_NAME="${AZ_USER}-fd"          
export ENDPOINT_NAME="${AZ_USER}-endpoint"    
export ORIGIN_GROUP="${AZ_USER}-origins"       


export NAMESPACE="microsweeper-ex"            
export APP_SERVICE="microsweeper-appservices"   
export APP_DOMAIN="${AZ_USER00}.apps.arolatamgbb.jaropro.net" 