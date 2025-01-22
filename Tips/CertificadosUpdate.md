Link de documentuntacion de comandos pas update de certificado.
https://docs.openshift.com/aro/4/welcome/index.html


Como manejar los Certificados

openssl pkcs12 -in INFILE.p12 -out OUTFILE.key -nodes -nocerts
openssl pkcs12 -in INFILE.p12 -out OUTFILE.crt -nokeys

Entidad CA Opensource
ejbca

*****Muy importante Debe tener el atributo de Nombre Alternativo Del sujeto Identico al WildCard*******



https://docs.openshift.com/container-platform/4.6/security/certificates/replacing-default-ingress-certificate.html



Ejemplo de Salida de comandos.

root@Debian:/home/rooliva# oc create configmap custom-ca --from-file=ca-bundle.crt=OUTFILE.crt -n openshift-config
configmap/custom-ca created

root@Debian:/home/rooliva# oc patch proxy/cluster --type=merge  --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'
proxy.config.openshift.io/cluster patched

root@Debian:/home/rooliva# oc create secret tls roger --cert=OUTFILE.crt --key=OUTFILE.key -n openshift-ingress
secret/roger created

root@Debian:/home/rooliva# oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "roger"}}}' -n openshift-ingress-operator
ingresscontroller.operator.openshift.io/default patched


Operator ingress
https://www.nginx.com/blog/getting-started-nginx-ingress-operator-red-hat-openshift/
https://github.com/nginxinc/nginx-ingress-operator/blob/master/docs/nginx-ingress-controller.md


Docker login authorize
https://docs.docker.com/engine/reference/commandline/login/#provide-a-password-using-stdin

Templates
https://docs.openshift.com/container-platform/4.1/openshift_images/using-templates.html#templates-overview_using-templates


Sizing OPENSHIFT 
https://docs.openshift.com/container-platform/4.6/scalability_and_performance/planning-your-environment-according-to-object-maximums.html#planning-your-environment-according-to-object-maximums
