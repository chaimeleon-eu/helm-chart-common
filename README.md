
## How to design a workstation Helm chart for the CHAIMELEON platform

This is a guide to create a Helm chart for deploying a workstation in the CHAIMELEON platform. 

### Images

The container images used in the chart also must accomplish certain conditions.
The design guide for creating images for CHAIMELEON platform is in the root path of the workstation images project:
https://github.com/chaimeleon-eu/workstation-images

### The `_chaimeleonCommonHelpers.tpl`

We have write this helpers file as a library of common functions that you can use in your charts for CHAIMELEON platform.
It makes you write less lines in the templates of your charts and also you don't have to know about common paths and configurations required, for example for mounting the common volumes (like the datalake).

To use it just copy the file into the "templates" directory of your chart:  
`wget https://github.com/chaimeleon-eu/helm-chart-common/blob/main/_chaimeleonCommonHelpers.tpl`  
or  
`git clone https://github.com/chaimeleon-eu/helm-chart-common.git`  
NOTE: if you use this second method it is recommended to add `templates/ChaimeleonCommon/.git` in your `.helmignore` file.

It can be just in the "templates" directory, beside your `_helpers.tpl` (if you have one) or in a subdirectory.
All the functions defined in it have the prefix `chaimeleon.`, and they can be used with `include`. You will see it in the next chapters of this guide.

### CHAIMELEON user 

The main process of any container must be run by the user with uid 1000, gid 1000 and the supplemental groups defined in the "chaimeleon" configmap which is in the user's namespace.
The reason for this is that some volumes will be mounted in the container that have files permissions configured for these user ids. 
Also this volumes can be mounted in many different workstations and the user IDs must be the same in all of them to guaranty the user have the same rights on the same files. 
And of course the user can not be root because she/he only should be able to access her/his files and datasets.

The uid and gid are shared by all the users, they corresponds to an OS generic user (that we usually call "chaimeleon"), so the image designer can create that user and use it for setting the permissions on the container "native" files. 
The supplemental group is different for every user and the CHAIMELEON platform use it for setting the permissions on the volumes files (datalake, datasets, persistent-shared-home). Specifically, the supplemental group of a user is included in the ACL (Access Control List) of files and directories that the user must have access to.

As a result, any deployment, statefulset or pod created by the chart must include the section `securityContext` with this content:
```
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        supplementalGroups: [ {{ include "chaimeleon.ceph.gid" . }} ]
```

### Annotations in the deployment

There should be a template in the chart for creating a k8s deployment object. 
The deployment should have this annotations:
```
  annotations: 
    chaimeleon.eu/datasetsIDs: "{{ .Values.datasets_list }}"
    chaimeleon.eu/toolName: "{{ .Chart.Name }}"
    chaimeleon.eu/toolVersion: "{{ .Chart.Version }}"
```

This can be accomplished just calling the function defined in _chaimeleonCommonHelpers.tpl:
```
  annotations: 
    {{- include "chaimeleon.annotations" . | nindent 4 }}
```

This data will be readed by the k8s operator before creating the deployment to:
 - check if the user have access to datasets selected (in case of success, the access will be granted including the gid in the ACL of dataset directories)
 - notify the use of dataset (with the tool name and version) to the Tracer Service.

### Volumes declaration in the deployment

In `spec.template.spec.volumes` you can call again some functions defined in _chaimeleonCommonHelpers.tpl in order to write the volume declaration for the datalake, the home of the user, the shared folder and each dataset selected by the user:
```
      volumes:
        - name: datalake
          {{- include "chaimeleon.datalake.volume" . | nindent 10 }}
        - name: home
          {{- include "chaimeleon.persistent_home.volume" . | nindent 10 }}
        - name: shared-folder
          {{- include "chaimeleon.persistent_shared_folder.volume" . | nindent 10 }}
        
        {{- if .Values.datasets_list }}
        {{- range $datasetID := splitList "," .Values.datasets_list }}
        - name: "{{ $datasetID -}}"
          {{- include "chaimeleon.dataset.volume" (list $ $datasetID) | nindent 10 }}
        {{- end }}
        {{- end }}
```
In order to write that volume declarations a configmap and a secret in the user namespace are read to get some info needed. That configmap and secret are automatically created when the user and namespace are created, so you don't have to worry about it. 

### Mounting the volumes

In `spec.template.spec.containers[i].volumeMounts` you define the path were the volumes are mounted. 
We recommend to use the functions of _chaimeleonCommonHelpers.tpl that writes the common paths to have an homogeneous environment whatever the type of workstation the user select for his/her work session.
Also the container image usually have this directories already created.
```
        volumeMounts:
          - mountPath: "{{- include "chaimeleon.datalake.mount_point" . -}}"
            name: datalake
          - mountPath: "{{- include "chaimeleon.persistent_home.mount_point" . -}}"
            name: home
          - mountPath: "{{- include "chaimeleon.persistent_shared_folder.mount_point" . -}}"
            name: shared-folder
            
          {{- if .Values.datasets_list }}
          {{- range $datasetID := splitList "," .Values.datasets_list }}
          - mountPath: "{{- include "chaimeleon.datasets.mount_point" $ -}}/{{- $datasetID -}}"
            name: "{{ $datasetID -}}"
          {{- end }}
          {{- end }}
```

### The priorityClass and request of resources 

You can specify the priority class with:  
`spec.template.spec.priorityClassName: processing-applications`
This is the default and currently the unique for that type of deployments.

And finally you can specify the resources you expect to use for each container in `spec.template.spec.containers[i].resources`:
```
        resources:
          requests:
            memory: "4Gi"
            cpu: "1"
```
Or let the user set them with:
```
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

The priority class and resources request affect the quality of service, go [here](https://github.com/chaimeleon-eu/k8s-deployments/tree/master/extra-configurations#quality-of-service) if you want to know more.


### Anotations for the creation of Guacamole connection
...



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
