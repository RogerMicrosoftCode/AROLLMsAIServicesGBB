## Introduction

Labels are a useful way to select which nodes that an application will run on. These nodes are created by machines which are defined by the MachineSets we worked with in previous sections of this workshop. An example of this would be running a memory intensive application only on a specific node type.

While you can directly add a label to a node, it is not recommended because nodes can be recreated, which would cause the label to disappear. Therefore we need to label the MachineSet itself. An important caveat to this process is that only **new machines** created by the MachineSet will get the label. This means you will need to either scale the MachineSet down to zero then back up to create new machines with the label, or you can label the existing machines directly.

## Set a label for the Machinset for ARO

1. Just like the last section, let's pick a MachineSet to add our label. To do so, run the following command:

    Change the # of your user in the name of the MachineSet

    ```bash
    NAME_MACHINESET=machineset.machine.openshift.io/arofundamentals-pcq8d-worker-eastus1-user#
    LABEL_USER=user#
    echo ${NAME_MACHINESET}
    ```

1. Now, let's patch the MachineSet with our new label. Change the number of your **user**!! To do so, run the following command:

    ```bash
    oc -n openshift-machine-api patch ${NAME_MACHINESET} \
      --type=merge -p '{"spec":{"template":{"spec":{"metadata":
      {"labels":{"tier":"user#"}}}}}}'
    ```

1. As you'll remember, the existing machines won't get this label, but all new machines will. While we could just scale this MachineSet down to zero and back up again, that could disrupt our workloads. Instead, let's just loop through and add the label to all of our nodes in that MachineSet. To do so, run the following command:

    ```bash
    MACHINES=$(oc -n openshift-machine-api get machines -o name -l "machine.openshift.io/cluster-api-machineset=$(echo $NAME_MACHINESET | cut -d / -f2 )" | xargs)
    oc label -n openshift-machine-api ${MACHINES} tier=${LABEL_USER}
    NODES=$(echo $MACHINES | sed 's/machine.machine.openshift.io/node/g')
    oc label ${NODES} tier=${LABEL_USER}
    ```

    !!! info

        Just like MachineSets, machines do not automatically label their existing child resources, this means we need to relabel them ourselves to avoid having to recreate them.

1. Now, let's verify the nodes are properly labeled. To do so, run the following command:

    ```bash
    oc get nodes --selector='tier=user#' -o name
    ```

    Your output will look something like this:

    ```{.text .no-copy}
    node/arofundamentals-pcq8d-worker-eastus1-user1-hh77s
    ```

    Pending that your output shows one or more node(s), this demonstrates that our MachineSet and associated nodes are properly annotated!

## Deploy an app to the labeled nodes

Now that we've successfully labeled our nodes, let's deploy a workload to demonstrate app placement using `nodeSelector`. This should force our app to only our labeled nodes.

1. First, let's create a namespace (also known as a project in OpenShift). To do so, run the following command:

    ```bash
    oc new-project nodeselector-ex-${LABEL_USER}
    ```

1. Next, let's deploy our application and associated resources that will target our labeled nodes. To do so, run the following command:

    ```yaml
    cat << EOF | oc create -f -
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: nodeselector-app-${LABEL_USER}
      namespace: nodeselector-ex-${LABEL_USER}
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nodeselector-app-${LABEL_USER}
      template:
        metadata:
          labels:
            app: nodeselector-app-${LABEL_USER}
        spec:
          nodeSelector:
            tier: ${LABEL_USER}
          containers:
            - name: hello-openshift
              image: "docker.io/openshift/hello-openshift"
              ports:
                - containerPort: 8080
                  protocol: TCP
                - containerPort: 8888
                  protocol: TCP
    EOF
    ```

1. Now, let's validate that the application has been deployed to one of the labeled nodes. To do so, run the following command:

    ```bash
    oc get nodes --selector='tier=user#' -o name
    ```

    Your output will look something like this (look for the final string to match, in this example `gkhgf`)

    ```{.text .no-copy}
    node/arofundamentals-pcq8d-worker-eastus1-user1-hh77s
    ```


1. Next create a `service` using the `oc expose` command

    ```bash
    oc expose deployment nodeselector-app-${LABEL_USER}
    ```

1. Expose the newly created `service` with a `route`

    ```bash
    oc create route edge --service=nodeselector-app-${LABEL_USER}
    ```

1.  Fetch the URL for the newly created `route`

    ```bash
    oc get routes/nodeselector-app-${LABEL_USER} -o json | jq -r '.spec.host'
    ```

    Then visit the URL presented in a new tab in your web browser (using HTTPS). For example, your output will look something similar to:

    ```{.text .no-copy}
    nodeselector-app-user1-nodeselector-ex-user1.apps.klld49u7afcd98cbc8.eastus.aroapp.io
    ```

1. In the above case, you'd visit `https://nodeselector-app-user1-nodeselector-ex-user1.apps.klld49u7afcd98cbc8.eastus.aroapp.io` in your browser.

    !!!note
        The application is exposed over the default ingress using a predetermined URL and trusted TLS certificate. This is done using the OpenShift `Route` resource which is an extension to the Kubernetes `Ingress` resource.

Congratulations! You've successfully demonstrated the ability to label nodes and target those nodes using `nodeSelector`.