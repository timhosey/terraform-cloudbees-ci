provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "cloudbees_ci" {
  depends_on = [kubernetes_config_map.oc_casc_bundle, kubernetes_secret.oc_secrets]

  chart      = "cloudbees-core"
  name       = "cloudbees-ci"
  namespace  = var.ci_namespace
  repository = var.chart_repository
  values     = [lookup(local.values_files, var.platform)]
  version    = var.chart_version

  # Dynamically set values for Docker image overrides if the vars are set
  dynamic "set" {
    for_each = {for k, v in local.image_value_keys: k => v if v != ""}
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "kubernetes_namespace" "cloudbees_ci" {
  count = var.manage_namespace ? 1 : 0

  metadata {
    name = var.ci_namespace
  }
}

resource "kubernetes_config_map" "oc_casc_bundle" {
  depends_on = [kubernetes_namespace.cloudbees_ci]

  metadata {
    name      = var.oc_configmap_name
    namespace = var.ci_namespace
  }

  data = { for file in fileset(local.oc_bundle_dir, "*.{yml,yaml}") : file => file("${local.oc_bundle_dir}/${file}") }
}

# Optional `Secret` that would be mounted in the OC container for confidential variables in the CasC configuration
resource "kubernetes_secret" "oc_secrets" {
  depends_on = [kubernetes_namespace.cloudbees_ci]

  metadata {
    name      = var.oc_secret_name
    namespace = var.ci_namespace
  }

  data = fileexists(local.secrets_file) ? yamldecode(file(local.secrets_file)): {}
}

data "template_file" "ci_eks" {
  template = file("${path.module}/values/ci.eks.yaml")

  vars = {
    host_name         = var.host_name
    oc_configmap_name = var.oc_configmap_name
    oc_secret_name    = var.oc_secret_name
    oc_secret_path    = var.oc_secret_path
    storage_class     = var.storage_class != "" ? var.storage_class : "null"
  }
}

locals {
  image_value_keys = {
    "OperationsCenter.Image.dockerImage" = var.oc_image
    "Master.Image.dockerImage"           = var.controller_image
    "Agents.Image.dockerImage"           = var.agent_image
  }

  oc_bundle_dir = "${path.module}/oc-casc-bundle"
  secrets_file = "${path.module}/${var.secrets_file}"
  values_files = {
    eks = data.template_file.ci_eks.rendered
  }
}