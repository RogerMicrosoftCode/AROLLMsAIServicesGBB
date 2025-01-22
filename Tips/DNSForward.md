Para configurar el reenvío de DNS en un clúster de Red Hat OpenShift en Azure, deberá modificar el operador de DNS. Esta modificación permitirá que los pods de aplicación que se ejecutan dentro del clúster resuelvan los nombres hospedados en un servidor DNS privado fuera de dicho clúster. Estos pasos se documentaron para OpenShift 4.3 en este vínculo.
Por ejemplo, si quiere reenviar todas las solicitudes DNS para que un servidor DNS 192.168.100.10 resuelva a *.example.com, puede editar la configuración del operador al ejecutar el siguiente comando:
Bash

Copiar
oc edit dns.operator/default
Se iniciará un editor y podrá reemplazar spec: {} por:
YAML

Copiar
spec:
 servers:
 - forwardPlugin:
     upstreams:
     - 192.168.100.10
   name: example-dns
   zones:
   - example.com
Guarde el archivo y salga de su editor.


Link RedHat
https://docs.openshift.com/container-platform/4.3/networking/dns-operator.html

View the default DNS
Every new OpenShift Container Platform installation has a dns.operator named default.

Procedure
Use the oc describe command to view the default dns:


$ oc describe dns.operator/default
Example output

Name:         default
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  operator.openshift.io/v1
Kind:         DNS
...
Status:
  Cluster Domain:  cluster.local 
  Cluster IP:      172.30.0.10 
...
The Cluster Domain field is the base DNS domain used to construct fully qualified Pod and Service domain names.
The Cluster IP is the address pods query for name resolution. The IP is defined as the 10th address in the Service CIDR range.
To find the Service CIDR of your cluster, use the oc get command:


$ oc get networks.config/cluster -o jsonpath='{$.status.serviceNetwork}'
Example output

[172.30.0.0/16]
Using DNS forwarding
You can use DNS forwarding to override the forwarding configuration identified in etc/resolv.conf on a per-zone basis by specifying which name server should be used for a given zone.

Procedure
Modify the DNS Operator object named default:


$ oc edit dns.operator/default
This allows the Operator to create and update the ConfigMap named dns-default with additional server configuration blocks based on Server. If none of the servers has a zone that matches the query, then name resolution falls back to the name servers that are specified in /etc/resolv.conf.

Sample DNS

apiVersion: operator.openshift.io/v1
kind: DNS
metadata:
  name: default
spec:
  servers:
  - name: foo-server 
    zones: 
      - foo.com
    forwardPlugin:
      upstreams: 
        - 1.1.1.1
        - 2.2.2.2:5353
  - name: bar-server
    zones:
      - bar.com
      - example.com
    forwardPlugin:
      upstreams:
        - 3.3.3.3
        - 4.4.4.4:5454

        name must comply with the rfc6335 service name syntax.
        zones must conform to the definition of a subdomain in rfc1123. The cluster domain, cluster.local, is an invalid subdomain for zones.
        A maximum of 15 upstreams is allowed per forwardPlugin.

        View the ConfigMap:


$ oc get configmap/dns-default -n openshift-dns -o yaml
Sample DNS ConfigMap based on previous sample DNS

apiVersion: v1
data:
  Corefile: |
    foo.com:5353 {
        forward . 1.1.1.1 2.2.2.2:5353
    }
    bar.com:5353 example.com:5353 {
        forward . 3.3.3.3 4.4.4.4:5454 
    }
    .:5353 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            policy sequential
        }
        cache 30
        reload
    }
kind: ConfigMap
metadata:
  labels:
    dns.operator.openshift.io/owning-dns: default
  name: dns-default
  namespace: openshift-dns

  DNS Operator status
You can inspect the status and view the details of the DNS Operator using the oc describe command.

Procedure
View the status of the DNS Operator:


$ oc describe clusteroperators/dns
DNS Operator logs
You can view DNS Operator logs by using the oc logs command.

Procedure
View the logs of the DNS Operator:


$ oc logs -n openshift-dns-operator deployment/dns-operator -c dns-operator