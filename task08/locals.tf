locals {
  common_tags = {
    Creator = "raavi_sourav@epam.com"
  }

  rg_name           = "${var.name_pattern}-rg"
  acr_name          = "cmtr64aed6d7mod8cr"
  redis_name        = "${var.name_pattern}-redis"
  keyvault_name     = "${var.name_pattern}-kv"
  aci_name          = "${var.name_pattern}-ci"
  aks_name          = "${var.name_pattern}-aks"
  docker_image_name = "cmtr-64aed6d7-mod8-app"
}
