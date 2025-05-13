terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Infos de l'utilisateur Terraform
data "azurerm_client_config" "current" {}

# Groupe de ressources
resource "azurerm_resource_group" "talendcicd_rg" {
  name     = "rg-talendcicd-dev"
  location = "France Central"
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }
}

# Réseau virtuel
resource "azurerm_virtual_network" "talendcicd_vnet" {
  name                = "vnet-talendcicd-dev"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.talendcicd_rg.location
  resource_group_name = azurerm_resource_group.talendcicd_rg.name
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }
}

# Sous-réseau
resource "azurerm_subnet" "talendcicd_subnet" {
  name                 = "snet-talendcicd-dev"
  resource_group_name  = azurerm_resource_group.talendcicd_rg.name
  virtual_network_name = azurerm_virtual_network.talendcicd_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

#IP publique
resource "azurerm_public_ip" "talendcicd_pip" {
  name                = "pip-talendcicd-dev"
  location            = azurerm_resource_group.talendcicd_rg.location
  resource_group_name = azurerm_resource_group.talendcicd_rg.name
  allocation_method   = "Static"
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }
}

# NSG
resource "azurerm_network_security_group" "talendcicd_nsg" {
  name                = "nsg-talendcicd-dev"
  location            = azurerm_resource_group.talendcicd_rg.location
  resource_group_name = azurerm_resource_group.talendcicd_rg.name
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Association NSG/Subnet
resource "azurerm_subnet_network_security_group_association" "talendcicd_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.talendcicd_subnet.id
  network_security_group_id = azurerm_network_security_group.talendcicd_nsg.id
}

# Interface réseau
resource "azurerm_network_interface" "talendcicd_nic" {
  name                = "nic-talendcicd-dev"
  location            = azurerm_resource_group.talendcicd_rg.location
  resource_group_name = azurerm_resource_group.talendcicd_rg.name
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.talendcicd_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.talendcicd_pip.id
  }
}





# VM Windows avec mot de passe depuis le Vault
resource "azurerm_windows_virtual_machine" "talendcicd_vm" {
  name                = "VM-TalendCICD"
  resource_group_name = azurerm_resource_group.talendcicd_rg.name
  location            = azurerm_resource_group.talendcicd_rg.location
  size                = "Standard_B2as_v2"
  admin_username      = "houssemdammak"
  admin_password      = var.vm_admin_password
  network_interface_ids = [
    azurerm_network_interface.talendcicd_nic.id,
  ]
  tags = {
    project     = "talend-cicd"
    environment = "dev"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
