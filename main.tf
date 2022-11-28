# deklaration der ressourcen gruppe und location
locals {
  Ressource_Group_Name     = "christian-heimke-green-rg"
  Ressource_Group_Location = "West Europe"
}

# public ssh key
resource "azurerm_ssh_public_key" "sshkey" {
  name                = "christian"
  location            = local.Ressource_Group_Location
  resource_group_name = azurerm_resource_group.cicdproject.name
  public_key          = file("../sshkey.pub")
}

## resourcen gruppe erstellen
resource "azurerm_resource_group" "cicdproject" {
  name     = local.Ressource_Group_Name
  location = local.Ressource_Group_Location
}

# jenkins public ip
resource "azurerm_public_ip" "jenkins_public_ip" {
  name                = "jenkins-public-ip"
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name
  allocation_method   = "Dynamic"
}

# webserver public ip
resource "azurerm_public_ip" "webserver_public_ip" {
  name                = "webserver-public-ip"
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name
  allocation_method   = "Dynamic"
}

# eigenes netzwerk
resource "azurerm_virtual_network" "main" {
  name                = "cicidproject-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name
  depends_on = [
    azurerm_resource_group.cicdproject
  ]
}

# subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.cicdproject.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on = [
    azurerm_virtual_network.main
  ]
}

# netzwerk für den jenkins
resource "azurerm_network_interface" "jenkins" {
  name                = "jenkins-nic"
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name

  ip_configuration {
    name                          = "cicdprojectnetwork"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_public_ip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "cicdproject-nsg"
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name
}

resource "azurerm_network_security_rule" "sshd" {
  name                        = "sshd"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.cicdproject.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "web" {
  name                        = "web"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.cicdproject.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allout" {
  name                        = "allout"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.cicdproject.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}
# netzwerk für den webserver
resource "azurerm_network_interface" "webserver" {
  name                = "webserver-nic"
  location            = azurerm_resource_group.cicdproject.location
  resource_group_name = azurerm_resource_group.cicdproject.name

  ip_configuration {
    name                          = "cicdprojectnetwork"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webserver_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "webservernsg" {
  network_interface_id      = azurerm_network_interface.webserver.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "jenkinsnsg" {
  network_interface_id      = azurerm_network_interface.jenkins.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# jenkins vm mit netzwerk und ip
resource "azurerm_linux_virtual_machine" "jenkins" {
  name                  = "jenkins-vm"
  location              = azurerm_resource_group.cicdproject.location
  resource_group_name   = azurerm_resource_group.cicdproject.name
  network_interface_ids = [azurerm_network_interface.jenkins.id]
  size                  = "Standard_B1s"
  computer_name         = "jenkins"
  admin_username        = "techstarter"
  admin_password        = "techstarter2342!"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  os_disk {
    name                 = "jenkins-osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "techstarter"
    public_key = file("../sshkey.pub")
  }

  tags = {
    environment = "jenkins"
  }
}

# webserver vm mit netzwerk und ip
resource "azurerm_linux_virtual_machine" "webserver" {
  name                  = "webserver-vm"
  location              = azurerm_resource_group.cicdproject.location
  resource_group_name   = azurerm_resource_group.cicdproject.name
  network_interface_ids = [azurerm_network_interface.webserver.id]
  size                  = "Standard_B1s"
  computer_name         = "webserver"
  admin_username        = "techstarter"
  admin_password        = "techstarter2342!"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "webserver-osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "techstarter"
    public_key = file("../sshkey.pub")
  }

  tags = {
    environment = "jenkins"
  }
}
