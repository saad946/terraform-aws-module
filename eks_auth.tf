/*
locals {
  account_id = var.account_id

  eks_node_roles = [
    for role in var.workers_roles : {
      rolearn  = "arn:aws:iam::${local.account_id}:role/${role}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:nodes", "system:bootstrappers"]
    }
  ]
  aws_account_roles = [
    for role, groups in var.role_groups_mapping : {
      rolearn  = "arn:aws:iam::${local.account_id}:role/${role}"
      username = "${local.account_id}-${role}"
      groups   = groups
    }
  ]
  # Below sample roles, subject to adjust once RBAC will be finalized

  role_groups_mapping = merge(
    { for role in var.admin_sso_role_name : role => ["system:masters"] }
  )



  aws_auth_data = distinct(
    concat(
      local.eks_node_roles,
      local.aws_account_roles
    )
  )
  # once yamlencode became stable switch to: yamlencode(local.aws_auth_data)
  aws_auth_data_raw = <<-EOT
    %{for role in local.aws_auth_data}
    - rolearn: ${role.rolearn}
      username: ${role.username}
      %{if length(role.groups) > 0}
      groups: %{for group in role.groups}
        - ${group} %{endfor}
      %{endif}
    %{endfor}
    EOT
  # get rid of '\n' from raw - human friendly (yaml) values
  aws_auth_data_yaml = indent(0, local.aws_auth_data_raw)
}

resource "kubernetes_config_map" "this" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = local.aws_auth_data_yaml
    mapUsers = "" # obsolete - should not be in use - overriding to empty value
  }
}

# This cluster role bindng is not created by default.
# https://kubernetes.io/docs/reference/access-authn-authz/rbac/#default-roles-and-role-bindings
resource "kubernetes_cluster_role_binding" "cluster_viewer" {
  metadata {
    name = "cluster-viewer"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind = "Group"
    name = "cluster-viewer"
  }
}

# These cluster role bindings are needed to extend permissions beyond
# default cluster-viewer permissions
resource "kubernetes_cluster_role_binding" "cluster_viewer_crd" {
  metadata {
    name = "cluster-viewer-crd"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-viewer-crd"
  }
  subject {
    kind = "Group"
    name = "cluster-viewer"
  }
}
resource "kubernetes_cluster_role_binding" "cluster_viewer_built_in" {
  metadata {
    name = "cluster-viewer-built-in"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-viewer-built-in"
  }
  subject {
    kind = "Group"
    name = "cluster-viewer"
  }
}
resource "kubernetes_cluster_role_binding" "cluster_viewer_built_in_ungrouped" {
  metadata {
    name = "cluster-viewer-built-in-ungrouped"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-viewer-built-in-ungrouped"
  }
  subject {
    kind = "Group"
    name = "cluster-viewer"
  }
}
# The api_groups are obtained by
# kubectl api-resources
resource "kubernetes_cluster_role" "cluster_viewer_crd" {
  metadata {
    name = "cluster-viewer-crd"
  }
  rule {
    api_groups = [
      # CRD
      # cert-manager
      "acme.cert-manager.io",
      "cert-manager.io",
      # istio
      "authentication.istio.io",
      "config.istio.io",
      "coordination.k8s.io",
      "events.k8s.io",
      "networking.istio.io",
      "rbac.istio.io",
      "security.istio.io",
      # aws-vpc-cni
      "crd.k8s.amazonaws.com",
      # prometheus
      "monitoring.coreos.com",
    ]
    resources = ["*"]
    verbs     = ["get", "list", "watch"]
  }
}
# These api groups are not included in the default cluster-viewer
# permissions scope
resource "kubernetes_cluster_role" "cluster_viewer_built_in" {
  metadata {
    name = "cluster-viewer-built-in"
  }
  rule {
    api_groups = [
      # built-in types
      # admission webhooks
      "admissionregistration.k8s.io",
      # customresourcedefinitions
      "apiextensions.k8s.io",
      # policy - psp, pdb etc.
      "policy",
      # rbac - clusterrole, rolebindings etc.
      "rbac.authorization.k8s.io",
      # priority class
      "scheduling.k8s.io",
      # storage class
      "storage.k8s.io",
    ]
    resources = ["*"]
    verbs     = ["get", "list", "watch"]
  }
}
# A clusterrole for api_group "" because this group
# includes secrets so we have to specify the resources explicitly
resource "kubernetes_cluster_role" "cluster_viewer_built_in_ungrouped" {
  metadata {
    name = "cluster-viewer-built-in-ungrouped"
  }
  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "persistentvolumes",
*/
      "podtemplates",
    ]
    verbs = ["get", "list", "watch"]
  }
}
