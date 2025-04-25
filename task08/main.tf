data "template_file" "deployment" {
  template = file("${path.module}/k8s-manifests/deployment.yaml.tftpl")

  vars = {
    acr_login_server = module.acr.login_server
    app_image_name   = "redis-flask-app"
    image_tag        = "v1"
  }
}


data "azurerm_client_config" "current" {}


data "template_file" "secret_provider" {
  template = file("${path.module}/k8s-manifests/secret-provider.yaml.tftpl")

  vars = {
    aks_kv_access_identity_id  = module.aks.kubelet_identity_id
    kv_name                    = module.keyvault.name
    tenant_id                  = data.azurerm_client_config.current.tenant_id
    redis_url_secret_name      = azurerm_key_vault_secret.redis_hostname.value
    redis_password_secret_name = azurerm_key_vault_secret.redis_primary_key.value
  }
}



resource "kubectl_manifest" "deployment" {

  yaml_body  = data.template_file.deployment.rendered
  depends_on = [module.aks]

}

resource "kubectl_manifest" "secret_provider" {
  yaml_body  = data.template_file.secret_provider.rendered
  depends_on = [kubectl_manifest.secret_provider, module.acr]
}

resource "kubectl_manifest" "service" {
  yaml_body = file("${path.module}/k8s-manifests/service.yaml")

  # wait_for {
  #   field {
  #     key        = "status.loadBalancer.ingress.[0].ip"
  #     value      = "^(\\d+(\\.|$)){4}"
  #     value_type = "regex"
  #   }
  # }
  depends_on = [kubectl_manifest.deployment]
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags = {
    tag = "Resource Group"
  }
}

module "aci" {

  source               = "./modules/aci"
  container_group_name = local.aci_name
  # key_vault_id         = module.keyvault.id
  dns_name_label      = local.aci_name
  location            = var.location
  redis_hostname      = azurerm_key_vault_secret.redis_hostname.value
  redis_primary_key   = azurerm_key_vault_secret.redis_primary_key.value
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    tag = "Azure Container Instance"
  }
}


module "acr" {

  source = "./modules/acr"

  container_registry_name = local.acr_name
  resource_group_name     = azurerm_resource_group.rg.name
  os_type                 = "Linux"
  sku                     = "Basic"
  registrytask_name       = "example-task"
  git_pat                 = var.git_pat
  location                = var.location
  depends_on = [
    module.redis,
    module.keyvault
  ]
}


module "aks" {
  source = "./modules/aks"

  aks_name            = local.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "cmtr-64aed6d7"
  node_count          = 2
  vm_size             = "Standard_D2s_v3"
  kubernetes_version  = "1.30.6"

  acr_id       = module.acr.acr_id
  key_vault_id = module.keyvault.id

  tags = {
    tag = "Azure Kubernetes Service"
  }
}

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.keyvault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    tag = "Key Vault"
  }
}

module "redis" {

  source              = "./modules/redis"
  location            = azurerm_resource_group.rg.location
  name                = local.redis_name
  resource_group_name = local.rg_name
  key_vault_id        = module.keyvault.id
}


resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = module.redis.hostname
  key_vault_id = module.keyvault.id
  depends_on   = [module.keyvault, module.redis]
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = module.redis.primary_key
  key_vault_id = module.keyvault.id
  depends_on   = [module.keyvault, module.redis]
}
