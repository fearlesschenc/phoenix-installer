#!/usr/bin/env bash

# set -x: Print commands and their arguments as they are executed.
# set -e: Exit immediately if a command exits with a non-zero status.

# set -xe

# delete ks-install
kubectl delete deploy ks-installer -n kubesphere-system --ignore-not-found

# delete helm
for namespaces in kubesphere-system kubesphere-devops-system kubesphere-monitoring-system kubesphere-logging-system istio-system kube-federation-system kube-system openpitrix-system
do
  namespaces=`helm list -n $namespaces | grep -v NAME | awk '{print $1}' | sort -u`
  if [ -s namespaces ] ;
  then cat namespaces | xargs -L1 helm uninstall -n $namespaces;
  fi
done

# delete kubesphere deployment
kubectl delete deployment -n kubesphere-system `kubectl get deployment -n kubesphere-system -o jsonpath="{.items[*].metadata.name}"` --ignore-not-found

# delete monitor statefulset
kubectl delete statefulset -n kubesphere-monitoring-system `kubectl get statefulset -n kubesphere-monitoring-system -o jsonpath="{.items[*].metadata.name}"` --ignore-not-found

# delete pvc
pvcs="kubesphere-system|openpitrix-system|kubesphere-monitoring-system|kubesphere-devops-system|kubesphere-logging-system"
kubectl --no-headers=true get pvc --all-namespaces -o custom-columns=:metadata.namespace,:metadata.name | grep -E $pvcs | xargs -n2 kubectl delete pvc -n --ignore-not-found

# delete rolebindings
delete_role_bindings() {
  for rolebinding in `kubectl -n $1 get rolebindings -l iam.kubesphere.io/user-ref -o jsonpath="{.items[*].metadata.name}"`
  do
    kubectl -n $1 delete rolebinding $rolebinding --ignore-not-found
  done
}

# delete roles
delete_roles() {
  kubectl -n $1 delete role admin --ignore-not-found
  kubectl -n $1 delete role operator --ignore-not-found
  kubectl -n $1 delete role viewer --ignore-not-found
  for role in `kubectl -n $1 get roles -l iam.kubesphere.io/role-template -o jsonpath="{.items[*].metadata.name}"`
  do
    kubectl -n $1 delete role $role --ignore-not-found
  done
}

# remove useless labels and finalizers
for ns in `kubectl get ns -o jsonpath="{.items[*].metadata.name}"`
do
  kubectl label ns $ns kubesphere.io/workspace-
  kubectl label ns $ns kubesphere.io/namespace-
  kubectl patch ns $ns -p '{"metadata":{"finalizers":null,"ownerReferences":null}}'
  delete_role_bindings $ns
  delete_roles $ns
done

# delete workspaces
for ws in `kubectl get workspaces -o jsonpath="{.items[*].metadata.name}"`
do
  kubectl patch workspace $ws -p '{"metadata":{"finalizers":null}}' --type=merge
done
kubectl delete workspaces --all --ignore-not-found

# delete clusters
for cluster in `kubectl get clusters -o jsonpath="{.items[*].metadata.name}"`
do
  kubectl patch cluster $cluster -p '{"metadata":{"finalizers":null}}' --type=merge
done

# delete validatingwebhookconfigurations
for webhook in ks-events-admission-validate users.iam.kubesphere.io validating-webhook-configuration
do
  kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io $webhook --ignore-not-found
done

# delete mutatingwebhookconfigurations
for webhook in ks-events-admission-mutate logsidecar-injector-admission-mutate mutating-webhook-configuration
do
  kubectl delete mutatingwebhookconfigurations.admissionregistration.k8s.io $webhook --ignore-not-found
done

# delete users
for user in `kubectl get users -o jsonpath="{.items[*].metadata.name}"`
do
  kubectl patch user $user -p '{"metadata":{"finalizers":null}}' --type=merge
done
kubectl delete users --all --ignore-not-found

# delete crds
for crd in `kubectl get crds -o jsonpath="{.items[*].metadata.name}"`
do
  if [[ $crd == *kubesphere.io ]]; then kubectl delete crd $crd --ignore-not-found; fi
done

# delete relevance ns
for ns in kubesphere-system kubesphere-alerting-system kubesphere-controls-system kubesphere-devops-system kubesphere-logging-system kubesphere-monitoring-system openpitrix-system istio-system
do
  kubectl delete ns $ns --ignore-not-found
done

