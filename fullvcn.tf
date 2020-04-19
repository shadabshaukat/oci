// main.tf

// Provider Variables defined in env-vars
variable "tenancy_ocid" {} // Your tenancy's OCID
variable "user_ocid" {} // Your user's OCID
variable "fingerprint" {} // Fingerprint for the user key
variable "private_key_path" {} // private key is located on the server
variable "region" {} // region is used in OCI eg. eu-frankfurt-1. Here we are using single AD region ap-sydney-1


provider "oci" {
  # use auth when running TF from an oci Compute instance
  #auth             = "InstancePrincipal"
  version             = "~> 3.17"
  tenancy_ocid         = "${var.tenancy_ocid}"
  user_ocid          = "${var.user_ocid}"
  fingerprint          = "${var.fingerprint}"
  private_key_path     = "${var.private_key_path}"
  region             = "${var.region}"
}

#################### NETWORK (VCN) Setups ################
resource "oci_core_virtual_network" "Demo_VCN_TF" {
  cidr_block     = "10.10.0.0/16"
  dns_label      = "MyVCNtf"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Demo_VCN_TF"
}

resource "oci_core_default_security_list" "Demo-Sec-List-items" {
  #Required
  manage_default_resource_id = "${oci_core_virtual_network.Demo_VCN_TF.default_security_list_id}"
  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }
  // Allow repo webserver to pass scripts/rpms to Demo instances
  ingress_security_rules {
    protocol    = "6"
    source    = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      max    = "80"
      min     = "80"
    }
  }
  // Custom defined New Demo related ports
  ingress_security_rules {
    protocol    = "6"
    source    = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      max    = "33062"
      min     = "33060"
    }
  }
  // Defaul MySQL Demo port
  ingress_security_rules {
    protocol    = "6"
    source    = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      max    = "3306"
      min     = "3306"
    }
  }
  // Default Oracle Demo port
  ingress_security_rules {
    protocol    = "6"
    source    = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      max    = "1521"
      min     = "1521"
    }
  }
  // SSH access
  ingress_security_rules {
    #Required
    protocol    = "6"
    source    = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      max    = "22"
      min     = "20"
    }
  }
  // allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol    = "1"
    source    = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    icmp_options {
      type    = "3"
    }
  }
  ingress_security_rules {
    protocol    = "1"
    source    = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    icmp_options {
      type    = "3"
      code     = "4"
    }
  }
}

// Setting up a route table, Internet Gateway and NAT Gateway
resource "oci_core_internet_gateway" "Demo_VCN_TF_IG" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Demo_TF_IG"
  vcn_id         = "${oci_core_virtual_network.Demo_VCN_TF.id}"
}

resource "oci_core_nat_gateway" "Demo_VCN_TF_NG" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Demo_TF_NG"
  vcn_id         = "${oci_core_virtual_network.Demo_VCN_TF.id}"
}

// Default Public Route Table
resource "oci_core_default_route_table" "Demo_VCN_TF_PublicRouteTable" {
  manage_default_resource_id  = "${oci_core_virtual_network.Demo_VCN_TF.default_route_table_id}"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.Demo_VCN_TF_IG.id}"
  }
}

// Private Route Table
resource "oci_core_route_table" "Demo_VCN_TF_PrivRouteTable" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.Demo_VCN_TF.id}"
  display_name   = "Demo_VCN_TF_PrivRouteTable"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "${oci_core_nat_gateway.Demo_VCN_TF_NG.id}"
  }
}

// Define Public Subnet : A regional subnet will not specify an Availability Domain
resource "oci_core_subnet" "Demo-PublicSubnet" {
  cidr_block        = "10.10.10.0/24"
  display_name      = "Demo-Regional-PublicSubnet"
  dns_label         = "myregpublicsub"
  compartment_id    = "${var.compartment_ocid}"
  vcn_id            = "${oci_core_virtual_network.Demo_VCN_TF.id}"
  security_list_ids = ["${oci_core_virtual_network.Demo_VCN_TF.default_security_list_id}"]
  route_table_id    = "${oci_core_virtual_network.Demo_VCN_TF.default_route_table_id}"
  dhcp_options_id   = "${oci_core_virtual_network.Demo_VCN_TF.default_dhcp_options_id}"
}

// Define Private Subnet : A regional subnet will not specify an Availability Domain
resource "oci_core_subnet" "Demo-PrivSubnet" {
  cidr_block        = "10.10.11.0/24"
  display_name      = "Demo-Regional-PrivSubnet"
  dns_label         = "myregprivsub"
  compartment_id    = "${var.compartment_ocid}"
  vcn_id            = "${oci_core_virtual_network.Demo_VCN_TF.id}"
  security_list_ids = ["${oci_core_virtual_network.Demo_VCN_TF.default_security_list_id}"]
  route_table_id    = "${oci_core_virtual_network.Demo_VCN_TF.default_route_table_id}"
  prohibit_public_ip_on_vnic = "true"
  dhcp_options_id   = "${oci_core_virtual_network.Demo_VCN_TF.default_dhcp_options_id}"
}

// Attach Private Subnet to Private Route Table
resource "oci_core_route_table_attachment" "Demo_route_table_attachment" {
  subnet_id        = "${oci_core_subnet.Demo-PrivSubnet.id}"
  route_table_id ="${oci_core_route_table.Demo_VCN_TF_PrivRouteTable.id}"
}

#################### COMPUTE Public Instance Setup ################
resource "oci_core_instance" "Public-WebServer" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "ilMx:AP-SYDNEY-1-AD-1"
  display_name        = "PublicWebServer"
  shape               = "${var.instance_shape}"
  count               = 1

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.Demo-PublicSubnet.id}"
    display_name     = "publicvnic"
    assign_public_ip = true
    private_ip       = "10.10.10.10"
    hostname_label   = "PublicWebServer"
  }

// Instance OCID , you can get Image OCID from here for each regions: https://docs.cloud.oracle.com/en-us/iaas/images/image/9cb2bf56-ff04-4dba-902e-d744ff55cd38/
  source_details {
    source_id = "ocid1.image.oc1.ap-sydney-1.aaaaaaaaal5geapcq"
    source_type = "image"
  }

// Public SSH key
  metadata {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwoGpfY/PExMGZUXBT7XOQ+ModkkhjCC+/Yp3SLCeWKys+xQ=="
    user_data = "${base64encode(file("bootstrap.sh"))}"
  }
}
