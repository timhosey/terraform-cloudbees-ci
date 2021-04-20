ci:
  OperationsCenter:
    Platform: aws
    HostName: ${host_name}
    Protocol: ${protocol}
    ServiceType: ClusterIP

  Hibernation:
    Enabled: ${hibernation_enabled}

  Agents:
    Enabled: true
    SeparateNamespace:
      Enabled: true
      Create: true

cd:
  ingress:
    host: ${host_name}
  dois:
    credentials:
      adminPassword: ${admin_password}
  flowCredentials:
    adminPassword: ${admin_password}