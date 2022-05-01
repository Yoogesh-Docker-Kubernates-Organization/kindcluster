{{- define "MyVolume" }}
volumes:
  - name: yoogesh-mysql-persistence
    {{- if .Values.cluster.kind }}
    hostPath:
      path: /mnt/data/mysql
      type: DirectoryOrCreate         
    {{- else }}
    # pointer to the configuration of HOW we want the mount to be implemented
    persistentVolumeClaim:
      claimName: yoogesh-pvc
    {{- end }}
{{- end }}