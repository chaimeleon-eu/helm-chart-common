
## How to design a workstation Helm chart for the CHAIMELEON platform

This is a guide to create a Helm chart for deploying a workstation in the CHAIMELEON platform. 
We recommend to take one of our charts as an example:
 - [helm-chart-desktop-tensorflow](https://github.com/chaimeleon-eu/helm-chart-desktop-tensorflow): if you want to create a chart of type desktop.
 - [helm-chart-jupyter-tensorflow](https://github.com/chaimeleon-eu/helm-chart-jupyter-tensorflow): if you want to create a chart of type web application.

### The `_chaimeleonCommonHelpers.tpl`

We have write this helpers file as a library of common functions that you can use in your charts for CHAIMELEON platform.
It makes you write less lines in the templates of your charts and also you don't have to know about common paths and configurations required.

To use it just copy the file into the "templates" directory of your chart:  
`cd templates && wget https://github.com/chaimeleon-eu/helm-chart-common/blob/main/_chaimeleonCommonHelpers.tpl`  
or clone:  
`cd templates && git submodule clone https://github.com/chaimeleon-eu/helm-chart-common.git`  
or add as a submodule (recommended):  
`cd templates && git submodule add -b "main" "git@github.com:chaimeleon-eu/helm-chart-common.git" "ChaimeleonCommon"`  
NOTE: if you use one of the last two methods, 
it is recommended to add `templates/ChaimeleonCommon/.git` and `templates/ChaimeleonCommon/README.md` in your `.helmignore` file.

It can be directly in the "templates" directory, beside your `_helpers.tpl` (if you have one) or in a subdirectory.  
All the functions defined in it have the prefix `chaimeleon.`, and they can be used with `include` 
(you will see in the next chapters of this guide).

### Images

First of all, the container images used in the chart must accomplish certain conditions, specifically those that mounts cephfs volumes.
Please check the 
[design guide for creating images for CHAIMELEON platform](https://github.com/chaimeleon-eu/workstation-images#how-to-design-a-workstation-image-for-the-chaimeleon-platform).

Once uploaded to the CHAIMELEON images repository, you will be able to use an image with:
```yaml
    image: "{{ include "chaimeleon.library-url" . }}/ubuntu-python-tensorflow-desktop:{{ .Chart.AppVersion }}"
```
Or if the container don't mount cephfs volumes you can use a non-customized image from dockerHub with:
```yaml
    image: {{ include "chaimeleon.dockerhub-proxy" . }}/library/postgres:alpine3.16
```

### Annotations in the deployment

There should be a template in the helm chart for creating a k8s deployment object. 
The deployment usually should have this annotations:
```yaml
  annotations: 
    chaimeleon.eu/toolName: "{{ .Chart.Name }}"
    chaimeleon.eu/toolVersion: "{{ .Chart.Version }}"
    
    chaimeleon.eu/datasetsIDs: "{{ .Values.datasets_list }}"
    chaimeleon.eu/datasetsMountPoint: "{{ include "chaimeleon.datasets.mount_point" . }}"
    
    chaimeleon.eu/persistentHomeMountPoint: "{{ include "chaimeleon.persistent_home.mount_point" . }}"
    chaimeleon.eu/persistentSharedFolderMountPoint: "{{ include "chaimeleon.persistent_shared_folder.mount_point" . }}"
    
    chaimeleon.eu/createGuacamoleConnection: "true"
```
All this annotations are optional except `toolName` and `toolVersion`.  
If you want to add all of them, as usually, you can just call this function:
```yaml
  annotations: 
    {{- include "chaimeleon.annotations" . | nindent 4 }}
```

If you don't want to mount datasets, don't add `chaimeleon.eu/datasetsIDs` or set the value to empty string `""`.  
If you don't want to mount the persistent-home, don't add `chaimeleon.eu/persistentHomeMountPoint`.  
If you don't want to mount the persistent-shared-folder, don't add `chaimeleon.eu/persistentSharedFolderMountPoint`.

If the image don't include a desktop and you don't want to create a guacamole connection, don't add `chaimeleon.eu/createGuacamoleConnection`.  
Otherwise you must include a secret in your helm chart, with the same name as the deployment and containing two entries: `container-user` and `container-password`.  
Example:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: "{{ include "desktop-tensorflow.fullname" . }}"
type: Opaque
stringData:
  container-user: "chaimeleon"
  container-password: "{{ include "utils.randomString" . }}"
```

More details in the [k8s operator README](https://github.com/chaimeleon-eu/k8s-chaimeleon-operator#known-annotations-in-deployments-and-jobs).

This annotations will be read by the k8s operator before creating the deployment in order to do some stuff:
 - Check if the user have access to datasets selected (in case of success, the access will be granted including the gid in the ACL of dataset directories).
 - Mount datalake, datasets, persistent-home and persistent-shared-folder in the container.
 - Notify the use of datasets (with the tool name and version) to the Tracer Service.
 - Create a connection in Guacamole to allow the user to connect to the remote desktop.

### How to show the values to be set by the user as a form

The current interface for launch applications in CHAIMELEON platform (Kubeapps) takes the file `values.schema.json` in the root dir of the chart 
to create a user friendly form with the values to configure the deployment.

We recommend to create this file including at least the field for the "dataset list". 
This is an example of the file `values.schema.json`:
```json
{
  "$schema": "http://json-schema.org/schema#",
  "type": "object",
  "properties": {
    "datasets_list": {
      "type": "string",
      "title": "Dataset list",
      "description": "A comma separated list of the datasets that will be available at the container. (It can be empty)",
      "form": true
    }
  }
}
```

### Automated by k8s operator
The following chapters contain details about certain aspects which are already solved by the k8s operator, 
so you don't have to worry about, don't have to add nothing in your chart, but they are kept for your information.

#### CHAIMELEON user and permissions (automatically added by the k8s operator, just FYI)

If there is any cephfs volume mounted, the main process of a container must be run by the user with **uid** 1000, **gid** 1000 
and a **supplemental group** assigned to the CHAIMELEON user when created.
The reason for that is that the cephfs volumes mounted in the container have file permissions configured for these user ids. 
Also this volumes can be mounted in many different workstations and the user IDs must be the same in all of them to ensure the user have the same rights on the same files. 
And of course the user can not be root because she/he only should be able to access her/his files and datasets.

The **uid** and **gid** are shared by all the users, they corresponds to an OS generic user (that we usually call "chaimeleon"), 
so the image designer can create that user and use it for setting the permissions on the container "native" files.  
The **supplemental group** is different for every user and the CHAIMELEON platform use it for setting the permissions on the files for him/her.
Specifically, the supplemental group of a user is included in the ACL (Access Control List) of files and directories that the user must have access to.

As a result, any deployment, statefulset or pod created by the chart will include the section `securityContext` with this content:
```yaml
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        supplementalGroups: [ <the CHAIMELEON user GID ]
```
But you don't need to add it in your helm chart, the k8s operator will do that. 

#### The priorityClass and request of resources (automatically added by the k8s operator)

You can specify the priority class with:  
`spec.template.spec.priorityClassName: processing-applications`.  
This is the default and currently the unique priority class defined for that type of deployments.

And finally you can specify the resources you expect to use for each container in `spec.template.spec.containers[i].resources`:
```yaml
        resources:
          requests:
            memory: "4Gi"
            cpu: "1"
```
Or let the user set them with:
```yaml
        resources:
          requests:
            memory: "{{ .Values.requests.memory }}"
            cpu: "{{ .Values.requests.cpu }}"
        {{- if .Values.requests.gpu }}
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1
        {{- end }}
```
The current maximum per user (actually per namespace) is defined [here](https://github.com/chaimeleon-eu/k8s-deployments/blob/master/extra-configurations/resource-quotas/chaimeleon-users.yml).

The priority class and resources request affect the quality of service, 
go [here](https://github.com/chaimeleon-eu/k8s-deployments/tree/master/extra-configurations#quality-of-service) if you want to know more.


## Build a Helm chart

```
helm package chartDirectory
```
This command generates a tgz package in the current directory which can be uploaded to any chart repository.

### Upload to the CHAIMELEON chart repository

The first time you must install the pluguin:
```
sudo helm plugin install https://github.com/chartmuseum/helm-push
```
And add the repo:
```
sudo helm repo add chaimeleon-library https://harbor.chaimeleon-eu.i3m.upv.es/chartrepo/chaimeleon-library
```

Upload using the ChartMuseum plugin:
```
helm cm-push --username=<username> --password=<userCliSecret> desktop-tensorflow-0.1.0.tgz chaimeleon-library
```
