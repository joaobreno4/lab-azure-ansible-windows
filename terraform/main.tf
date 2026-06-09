terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true 
}

# 1. Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = "rg-lab-windows-ansible"
  location = "East US"
}

# 2. Rede Virtual e Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-lab"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. IP Público (Atualizado para a versão Standard)
resource "azurerm_public_ip" "pip" {
  name                = "pip-lab-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard" # <-- Correção aplicada aqui
}

# 4. Firewall (NSG) - Liberando as portas
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WinRM"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. Interface de Rede
resource "azurerm_network_interface" "nic" {
  name                = "nic-lab-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. A Máquina Virtual (Windows Server 2022)
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "vmlabwin01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s" 
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234Lab!" # Senha que usaremos no Ansible
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# 7. O Script PowerShell de Inicialização (WinRM)
resource "azurerm_virtual_machine_extension" "winrm_config" {
  name                 = "Enable-WinRM"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -Command \"Enable-PSRemoting -Force; Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true; Set-Item -Path WSMan:\\localhost\\Service\\AllowUnencrypted -Value $true; netsh advfirewall firewall add rule name='WinRM-HTTP' dir=in action=allow protocol=TCP localport=5985\""
    }
  SETTINGS
}

# 8. Output do IP Público
output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}
