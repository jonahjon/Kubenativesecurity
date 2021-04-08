#!/usr/bin/env bash

#Generate valid CA
openssl genrsa -passout pass:1234 -des3 -out ca.key 4096
openssl req -passin pass:1234 -new -x509 -days 365 -key ca.key -out ca.crt -subj  "/C=SP/ST=USA/L=Ornavasso/O=Test/OU=Test/CN=Root CA"

#Generate valid Server Key/Cert
openssl genrsa -passout pass:1234 -des3 -out server.key 4096
openssl req -passin pass:1234 -new -key server.key -out server.csr -subj  "/C=SP/ST=USA/L=Ornavasso/O=Test/OU=Server/CN=falco-grpc.prow-monitoring.svc.cluster.local"
openssl x509 -req -passin pass:1234 -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt

#Remove passphrase from the Server Key
openssl rsa -passin pass:1234 -in server.key -out server.key

#Generate valid Client Key/Cert 
openssl genrsa -passout pass:1234 -des3 -out client.key 4096
openssl req -passin pass:1234 -new -key client.key -out client.csr -subj  "/C=SP/ST=USA/L=Ornavasso/O=Test/OU=Client/CN=falco-grpc.prow-monitoring.svc.cluster.local"
openssl x509 -passin pass:1234 -req -days 365 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt

#Remove passphrase from Client Key 
openssl rsa -passin pass:1234 -in client.key -out client.key

#Install falco with mutualTLS and outputs enabled
helm install falco \
  --set-file certs.server.key=server.key,certs.server.crt=server.crt,certs.ca.crt=ca.crt \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true \

#Install Falco
helm install falco \
  --set falco.jsonOutput=true \
  --set falco.jsonIncludeOutputProperty=true \
  --set falco.httpOutput.enabled=true \
  --set falco.httpOutput.url="http://falcosidekick:2801/" \
  falcosecurity/falco

#Install falco-exporter
helm install falco-exporter \
  --set-file certs.ca.crt=ca.crt,certs.client.key=client.key,certs.client.crt=client.crt \
  falcosecurity/falco-exporter

#Install falco-sidekick
helm install falcosidekick \
  --set webui.enabled=true \
  --set webui.image.tag="v1.0.0" \
  --set config.aws.cloudwatchlogs.loggroup="k8s-meetup-falco-alerts" \
  --set config.aws.region="us-west-2" \
  falcosecurity/falcosidekick 

#Create events
k apply -f events-generator/

#port forward
kubectl -n prow-monitoring port-forward prometheus-prow-1 9090
kubectl port-forward svc/falcosidekick-ui 2802:2802 --namespace prow-monitoring

#Cleanup
helm delete falco
helm delete falcosidekick
helm delete falco-exporter
k delete -f events-generator/
rm -rf *.key
rm -rf *.csr
rm -rf *.crt


