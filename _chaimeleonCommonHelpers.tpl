{{/* vim: set filetype=mustache: */}}

{{- define "chaimeleon.annotations.tool_info" -}}
chaimeleon.eu/toolName: "{{ .Chart.Name }}"
chaimeleon.eu/toolVersion: "{{ .Chart.Version }}"
{{- end }}

{{- define "chaimeleon.annotations.mount_datasets" -}}
{{- if .Values.datasets_list }}
chaimeleon.eu/datasetsIDs: "{{ .Values.datasets_list }}"
chaimeleon.eu/datasetsMountPoint: "{{ include "chaimeleon.datasets.mount_point" . }}"
{{- end }}
{{- end }}

{{- define "chaimeleon.annotations.mount_persistent_home_and_shared" -}}
chaimeleon.eu/persistentHomeMountPoint: "{{ include "chaimeleon.persistent_home.mount_point" . }}"
chaimeleon.eu/persistentSharedFolderMountPoint: "{{ include "chaimeleon.persistent_shared_folder.mount_point" . }}"
{{- end }}

{{- define "chaimeleon.annotations.desktop_connection" -}}
chaimeleon.eu/createGuacamoleConnection: "true"
{{- end }}


{{/* Generate annotations for a deployment with graphical desktop and access to datasets. */}}
{{- define "chaimeleon.annotations" -}}
{{ include "chaimeleon.annotations.tool_info" . }}
{{- /* Enable the mounting of datasets:*/ -}}
{{ include "chaimeleon.annotations.mount_datasets" . }}
{{- /* Enable the mounting of persistent-home and persistent-shared-folder:*/ -}}
{{ include "chaimeleon.annotations.mount_persistent_home_and_shared" . }}
{{- /* Enable the creation of a connection in Guacamole in order to access to the remote desktop: */ -}}
{{ include "chaimeleon.annotations.desktop_connection" . }}
{{- end }}


{{- define "chaimeleon.datalake.mount_point" -}}
/mnt/datalake
{{- end }}

{{- define "chaimeleon.persistent_home.mount_point" -}}
/home/chaimeleon/persistent-home
{{- end }}

{{- define "chaimeleon.persistent_shared_folder.mount_point" -}}
/home/chaimeleon/persistent-shared-folder
{{- end }}

{{- define "chaimeleon.datasets.mount_point" -}}
/home/chaimeleon/datasets
{{- end }}


{{- define "chaimeleon.user.name" -}}
{{- $configmap := (lookup "v1" "ConfigMap" .Release.Namespace .Values.configmaps.chaimeleon) }}
{{- index $configmap "data" "user.name" -}}
{{- end }}

{{- define "chaimeleon.user.uid" -}}
1000
{{- end }}

{{- define "chaimeleon.group.name" -}}
{{- $configmap := (lookup "v1" "ConfigMap" .Release.Namespace .Values.configmaps.chaimeleon) }}
{{- index $configmap "data" "group.name" -}}
{{- end }}

{{- define "chaimeleon.group.gid" -}}
1000
{{- end }}


{{/* Obtain the host part of the URL of a web application to be deployed in Chaimeleon platform. */}}
{{- define "chaimeleon.host" -}}
chaimeleon-eu.i3m.upv.es
{{- end -}}

{{/* Obtain the path part of the URL of a web application to be deployed in Chaimeleon platform. 
{{- define "chaimeleon.user-path" -}}
{{- printf "%s/" .Release.Namespace -}}
{{- end -}}
*/}}

{{/* Obtain the Chaimeleon image library url. */}}
{{- define "chaimeleon.library-url" -}}
harbor.chaimeleon-eu.i3m.upv.es/chaimeleon-library
{{- end -}}

{{/* Obtain the Chaimeleon dockerhub proxy url. */}}
{{- define "chaimeleon.dockerhub-proxy" -}}
harbor.chaimeleon-eu.i3m.upv.es/dockerhub
{{- end -}}

{{/* Obtain the Chaimeleon guacamole service url. */}}
{{- define "chaimeleon.guacamole-url" -}}
https://chaimeleon-eu.i3m.upv.es/guacamole/
{{- end -}}

